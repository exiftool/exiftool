#------------------------------------------------------------------------------
# File:         QuickTime.pm
#
# Description:  Read QuickTime and MP4 meta information
#
# Revisions:    10/04/2005 - P. Harvey Created
#               12/19/2005 - P. Harvey Added MP4 support
#               09/22/2006 - P. Harvey Added M4A support
#               07/27/2010 - P. Harvey Updated to 2010-05-03 QuickTime spec
#
# References:
#
#   1) http://developer.apple.com/mac/library/documentation/QuickTime/QTFF/QTFFChap1/qtff1.html
#   2) http://search.cpan.org/dist/MP4-Info-1.04/
#   3) http://www.geocities.com/xhelmboyx/quicktime/formats/mp4-layout.txt
#   4) http://wiki.multimedia.cx/index.php?title=Apple_QuickTime
#   5) ISO 14496-12 (http://read.pudn.com/downloads64/ebook/226547/ISO_base_media_file_format.pdf)
#   6) ISO 14496-16 (http://www.iec-normen.de/previewpdf/info_isoiec14496-16%7Bed2.0%7Den.pdf)
#   7) http://atomicparsley.sourceforge.net/mpeg-4files.html
#   8) http://wiki.multimedia.cx/index.php?title=QuickTime_container
#   9) http://www.adobe.com/devnet/xmp/pdfs/XMPSpecificationPart3.pdf (Oct 2008)
#   10) http://code.google.com/p/mp4v2/wiki/iTunesMetadata
#   11) http://www.canieti.com.mx/assets/files/1011/IEC_100_1384_DC.pdf
#   12) QuickTime file format specification 2010-05-03
#   13) http://www.adobe.com/devnet/flv/pdf/video_file_format_spec_v10.pdf
#   14) http://standards.iso.org/ittf/PubliclyAvailableStandards/c051533_ISO_IEC_14496-12_2008.zip
#   15) http://getid3.sourceforge.net/source/module.audio-video.quicktime.phps
#   16) http://qtra.apple.com/atoms.html
#   17) http://www.etsi.org/deliver/etsi_ts/126200_126299/126244/10.01.00_60/ts_126244v100100p.pdf
#   18) https://github.com/appsec-labs/iNalyzer/blob/master/scinfo.m
#   19) http://nah6.com/~itsme/cvs-xdadevtools/iphone/tools/decodesinf.pl
#   20) https://developer.apple.com/legacy/library/documentation/quicktime/reference/QT7-1_Update_Reference/QT7-1_Update_Reference.pdf
#   21) Francois Bonzon private communication
#   22) https://developer.apple.com/library/mac/documentation/QuickTime/QTFF/Metadata/Metadata.html
#   23) http://atomicparsley.sourceforge.net/mpeg-4files.html
#   24) https://github.com/sergiomb2/libmp4v2/wiki/iTunesMetadata
#   25) https://cconcolato.github.io/mp4ra/atoms.html
#   26) https://github.com/SamsungVR/android_upload_sdk/blob/master/SDKLib/src/main/java/com/samsung/msca/samsungvr/sdk/UserVideo.java
#   27) https://exiftool.org/forum/index.php?topic=11517.0
#   28) https://docs.mp3tag.de/mapping/
#------------------------------------------------------------------------------

package Image::ExifTool::QuickTime;

use strict;
use vars qw($VERSION $AUTOLOAD %stringEncoding %avType);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::GPS;

$VERSION = '3.12';

sub ProcessMOV($$;$);
sub ProcessKeys($$$);
sub ProcessMetaKeys($$$);
sub ProcessMetaData($$$);
sub ProcessEncodingParams($$$);
sub ProcessSampleDesc($$$);
sub ProcessHybrid($$$);
sub ProcessRights($$$);
sub ProcessNextbase($$$);
sub Process_mrlh($$$);
sub Process_mrlv($$$);
sub Process_mrld($$$);
# ++vvvvvvvvvvvv++ (in QuickTimeStream.pl)
sub Process_mebx($$$);
sub Process_3gf($$$);
sub Process_gps0($$$);
sub Process_gsen($$$);
sub Process_gdat($$$);
sub Process_nbmt($$$);
sub ProcessKenwood($$$);
sub ProcessRIFFTrailer($$$);
sub ProcessTTAD($$$);
sub ProcessNMEA($$$);
sub ProcessGPSLog($$$);
sub ProcessGarminGPS($$$);
sub SaveMetaKeys($$$);
# ++^^^^^^^^^^^^++
sub ParseItemLocation($$);
sub ParseContentDescribes($$);
sub ParseItemInfoEntry($$);
sub ParseItemPropAssoc($$);
sub FixWrongFormat($);
sub GetMatrixStructure($$);
sub ConvertISO6709($);
sub ConvInvISO6709($);
sub ConvertChapterList($);
sub PrintChapter($);
sub PrintGPSCoordinates($);
sub PrintInvGPSCoordinates($);
sub UnpackLang($;$);
sub WriteKeys($$$);
sub WriteQuickTime($$$);
sub WriteMOV($$);
sub WriteNextbase($$$);
sub GetLangInfo($$);
sub CheckQTValue($$$);

# MIME types for all entries in the ftypLookup with file extensions
# (defaults to 'video/mp4' if not found in this lookup)
my %mimeLookup = (
   '3G2' => 'video/3gpp2',
   '3GP' => 'video/3gpp',
    AAX  => 'audio/vnd.audible.aax',
    DVB  => 'video/vnd.dvb.file',
    F4A  => 'audio/mp4',
    F4B  => 'audio/mp4',
    JP2  => 'image/jp2',
    JPM  => 'image/jpm',
    JPX  => 'image/jpx',
    M4A  => 'audio/mp4',
    M4B  => 'audio/mp4',
    M4P  => 'audio/mp4',
    M4V  => 'video/x-m4v',
    MOV  => 'video/quicktime',
    MQV  => 'video/quicktime',
    HEIC => 'image/heic',
    HEVC => 'image/heic-sequence',
    HEICS=> 'image/heic-sequence',
    HEIF => 'image/heif',
    HEIFS=> 'image/heif-sequence',
    AVIF => 'image/avif', #PH (NC)
    CRX  => 'video/x-canon-crx',    # (will get overridden)
);

# look up file type from ftyp atom type, with MIME type in comment if known
# (ref http://www.ftyps.com/)
my %ftypLookup = (
    '3g2a' => '3GPP2 Media (.3G2) compliant with 3GPP2 C.S0050-0 V1.0', # video/3gpp2
    '3g2b' => '3GPP2 Media (.3G2) compliant with 3GPP2 C.S0050-A V1.0.0', # video/3gpp2
    '3g2c' => '3GPP2 Media (.3G2) compliant with 3GPP2 C.S0050-B v1.0', # video/3gpp2
    '3ge6' => '3GPP (.3GP) Release 6 MBMS Extended Presentations', # video/3gpp
    '3ge7' => '3GPP (.3GP) Release 7 MBMS Extended Presentations', # video/3gpp
    '3gg6' => '3GPP Release 6 General Profile', # video/3gpp
    '3gp1' => '3GPP Media (.3GP) Release 1 (probably non-existent)', # video/3gpp
    '3gp2' => '3GPP Media (.3GP) Release 2 (probably non-existent)', # video/3gpp
    '3gp3' => '3GPP Media (.3GP) Release 3 (probably non-existent)', # video/3gpp
    '3gp4' => '3GPP Media (.3GP) Release 4', # video/3gpp
    '3gp5' => '3GPP Media (.3GP) Release 5', # video/3gpp
    '3gp6' => '3GPP Media (.3GP) Release 6 Basic Profile', # video/3gpp
    '3gp6' => '3GPP Media (.3GP) Release 6 Progressive Download', # video/3gpp
    '3gp6' => '3GPP Media (.3GP) Release 6 Streaming Servers', # video/3gpp
    '3gs7' => '3GPP Media (.3GP) Release 7 Streaming Servers', # video/3gpp
    'aax ' => 'Audible Enhanced Audiobook (.AAX)', #PH
    'avc1' => 'MP4 Base w/ AVC ext [ISO 14496-12:2005]', # video/mp4
    'CAEP' => 'Canon Digital Camera',
    'caqv' => 'Casio Digital Camera',
    'CDes' => 'Convergent Design',
    'da0a' => 'DMB MAF w/ MPEG Layer II aud, MOT slides, DLS, JPG/PNG/MNG images',
    'da0b' => 'DMB MAF, extending DA0A, with 3GPP timed text, DID, TVA, REL, IPMP',
    'da1a' => 'DMB MAF audio with ER-BSAC audio, JPG/PNG/MNG images',
    'da1b' => 'DMB MAF, extending da1a, with 3GPP timed text, DID, TVA, REL, IPMP',
    'da2a' => 'DMB MAF aud w/ HE-AAC v2 aud, MOT slides, DLS, JPG/PNG/MNG images',
    'da2b' => 'DMB MAF, extending da2a, with 3GPP timed text, DID, TVA, REL, IPMP',
    'da3a' => 'DMB MAF aud with HE-AAC aud, JPG/PNG/MNG images',
    'da3b' => 'DMB MAF, extending da3a w/ BIFS, 3GPP timed text, DID, TVA, REL, IPMP',
    'dmb1' => 'DMB MAF supporting all the components defined in the specification',
    'dmpf' => 'Digital Media Project', # various
    'drc1' => 'Dirac (wavelet compression), encapsulated in ISO base media (MP4)',
    'dv1a' => 'DMB MAF vid w/ AVC vid, ER-BSAC aud, BIFS, JPG/PNG/MNG images, TS',
    'dv1b' => 'DMB MAF, extending dv1a, with 3GPP timed text, DID, TVA, REL, IPMP',
    'dv2a' => 'DMB MAF vid w/ AVC vid, HE-AAC v2 aud, BIFS, JPG/PNG/MNG images, TS',
    'dv2b' => 'DMB MAF, extending dv2a, with 3GPP timed text, DID, TVA, REL, IPMP',
    'dv3a' => 'DMB MAF vid w/ AVC vid, HE-AAC aud, BIFS, JPG/PNG/MNG images, TS',
    'dv3b' => 'DMB MAF, extending dv3a, with 3GPP timed text, DID, TVA, REL, IPMP',
    'dvr1' => 'DVB (.DVB) over RTP', # video/vnd.dvb.file
    'dvt1' => 'DVB (.DVB) over MPEG-2 Transport Stream', # video/vnd.dvb.file
    'F4A ' => 'Audio for Adobe Flash Player 9+ (.F4A)', # audio/mp4
    'F4B ' => 'Audio Book for Adobe Flash Player 9+ (.F4B)', # audio/mp4
    'F4P ' => 'Protected Video for Adobe Flash Player 9+ (.F4P)', # video/mp4
    'F4V ' => 'Video for Adobe Flash Player 9+ (.F4V)', # video/mp4
    'isc2' => 'ISMACryp 2.0 Encrypted File', # ?/enc-isoff-generic
    'iso2' => 'MP4 Base Media v2 [ISO 14496-12:2005]', # video/mp4 (or audio)
    'iso3' => 'MP4 Base Media v3', # video/mp4 (or audio)
    'iso4' => 'MP4 Base Media v4', # video/mp4 (or audio)
    'iso5' => 'MP4 Base Media v5', # video/mp4 (or audio)
    'iso6' => 'MP4 Base Media v6', # video/mp4 (or audio)
    'iso7' => 'MP4 Base Media v7', # video/mp4 (or audio)
    'iso8' => 'MP4 Base Media v8', # video/mp4 (or audio)
    'iso9' => 'MP4 Base Media v9', # video/mp4 (or audio)
    'isom' => 'MP4 Base Media v1 [IS0 14496-12:2003]', # video/mp4 (or audio)
    'JP2 ' => 'JPEG 2000 Image (.JP2) [ISO 15444-1 ?]', # image/jp2
    'JP20' => 'Unknown, from GPAC samples (prob non-existent)',
    'jpm ' => 'JPEG 2000 Compound Image (.JPM) [ISO 15444-6]', # image/jpm
    'jpx ' => 'JPEG 2000 with extensions (.JPX) [ISO 15444-2]', # image/jpx
    'KDDI' => '3GPP2 EZmovie for KDDI 3G cellphones', # video/3gpp2
    #LCAG  => (found in CompatibleBrands of Leica MOV videos)
    'M4A ' => 'Apple iTunes AAC-LC (.M4A) Audio', # audio/x-m4a
    'M4B ' => 'Apple iTunes AAC-LC (.M4B) Audio Book', # audio/mp4
    'M4P ' => 'Apple iTunes AAC-LC (.M4P) AES Protected Audio', # audio/mp4
    'M4V ' => 'Apple iTunes Video (.M4V) Video', # video/x-m4v
    'M4VH' => 'Apple TV (.M4V)', # video/x-m4v
    'M4VP' => 'Apple iPhone (.M4V)', # video/x-m4v
    'mj2s' => 'Motion JPEG 2000 [ISO 15444-3] Simple Profile', # video/mj2
    'mjp2' => 'Motion JPEG 2000 [ISO 15444-3] General Profile', # video/mj2
    'mmp4' => 'MPEG-4/3GPP Mobile Profile (.MP4/3GP) (for NTT)', # video/mp4
    'mp21' => 'MPEG-21 [ISO/IEC 21000-9]', # various
    'mp41' => 'MP4 v1 [ISO 14496-1:ch13]', # video/mp4
    'mp42' => 'MP4 v2 [ISO 14496-14]', # video/mp4
    'mp71' => 'MP4 w/ MPEG-7 Metadata [per ISO 14496-12]', # various
    'MPPI' => 'Photo Player, MAF [ISO/IEC 23000-3]', # various
    'mqt ' => 'Sony / Mobile QuickTime (.MQV) US Patent 7,477,830 (Sony Corp)', # video/quicktime
    'MSNV' => 'MPEG-4 (.MP4) for SonyPSP', # audio/mp4
    'NDAS' => 'MP4 v2 [ISO 14496-14] Nero Digital AAC Audio', # audio/mp4
    'NDSC' => 'MPEG-4 (.MP4) Nero Cinema Profile', # video/mp4
    'NDSH' => 'MPEG-4 (.MP4) Nero HDTV Profile', # video/mp4
    'NDSM' => 'MPEG-4 (.MP4) Nero Mobile Profile', # video/mp4
    'NDSP' => 'MPEG-4 (.MP4) Nero Portable Profile', # video/mp4
    'NDSS' => 'MPEG-4 (.MP4) Nero Standard Profile', # video/mp4
    'NDXC' => 'H.264/MPEG-4 AVC (.MP4) Nero Cinema Profile', # video/mp4
    'NDXH' => 'H.264/MPEG-4 AVC (.MP4) Nero HDTV Profile', # video/mp4
    'NDXM' => 'H.264/MPEG-4 AVC (.MP4) Nero Mobile Profile', # video/mp4
    'NDXP' => 'H.264/MPEG-4 AVC (.MP4) Nero Portable Profile', # video/mp4
    'NDXS' => 'H.264/MPEG-4 AVC (.MP4) Nero Standard Profile', # video/mp4
    'odcf' => 'OMA DCF DRM Format 2.0 (OMA-TS-DRM-DCF-V2_0-20060303-A)', # various
    'opf2' => 'OMA PDCF DRM Format 2.1 (OMA-TS-DRM-DCF-V2_1-20070724-C)',
    'opx2' => 'OMA PDCF DRM + XBS extensions (OMA-TS-DRM_XBS-V1_0-20070529-C)',
    'pana' => 'Panasonic Digital Camera',
    'qt  ' => 'Apple QuickTime (.MOV/QT)', # video/quicktime
    'ROSS' => 'Ross Video',
    'sdv ' => 'SD Memory Card Video', # various?
    'ssc1' => 'Samsung stereoscopic, single stream',
    'ssc2' => 'Samsung stereoscopic, dual stream',
    'XAVC' => 'Sony XAVC', #PH
    'heic' => 'High Efficiency Image Format HEVC still image (.HEIC)', # image/heic
    'hevc' => 'High Efficiency Image Format HEVC sequence (.HEICS)', # image/heic-sequence
    'mif1' => 'High Efficiency Image Format still image (.HEIF)', # image/heif
    'msf1' => 'High Efficiency Image Format sequence (.HEIFS)', # image/heif-sequence
    'heix' => 'High Efficiency Image Format still image (.HEIF)', # image/heif (ref PH, Canon 1DXmkIII)
    'avif' => 'AV1 Image File Format (.AVIF)', # image/avif
    'crx ' => 'Canon Raw (.CRX)', #PH (CR3 or CRM; use Canon CompressorVersion to decide)
);

# use extension to determine file type
my %useExt = ( GLV => 'MP4' );

# information for int32u date/time tags (time zero is Jan 1, 1904)
my %timeInfo = (
    Notes => q{
        converted from UTC to local time if the QuickTimeUTC option is set.  This
        tag is part of a binary data structure so it may not be deleted -- instead
        the value is set to zero if the tag is deleted individually
    },
    Shift => 'Time',
    Writable => 1,
    Permanent => 1,
    DelValue => 0,
    # It is not uncommon for brain-dead software to use the wrong time zero, it should be
    # Jan 1, 1904, so assume a time zero of Jan 1, 1970 if the date is before this
    # Note: This value will be in UTC if generated by a system that is aware of the time zone
    # (also note: this code is duplicated for the CreateDate tag)
    RawConv => q{
        if ($val) {
            my $offset = (66 * 365 + 17) * 24 * 3600;
            if ($val >= $offset or $$self{OPTIONS}{QuickTimeUTC}) {
                $val -= $offset;
            } elsif (not $$self{IsWriting}) {
                $self->Warn('Patched incorrect time zero for QuickTime date/time tag',1);
            }
        } else {
            undef $val if $self->Options('StrictDate');
        }
        return $val;
    },
    RawConvInv => q{
        if ($val and $$self{FileType} eq 'CR3' and not $self->Options('QuickTimeUTC')) {
            # convert to UTC
            my $offset = (66 * 365 + 17) * 24 * 3600;
            $val = ConvertUnixTime($val - $offset);
            $val = GetUnixTime($val, 1) + $offset;
        }
        return $val;
    },
    # (all CR3 files store UTC times - PH)
    ValueConv => 'ConvertUnixTime($val, $self->Options("QuickTimeUTC") || $$self{FileType} eq "CR3")',
    ValueConvInv => q{
        $val = GetUnixTime($val, $self->Options("QuickTimeUTC"));
        return undef unless defined $val;
        return $val unless $val;
        return $val + (66 * 365 + 17) * 24 * 3600;
    },
    PrintConv => '$self->ConvertDateTime($val)',
    PrintConvInv => q{
        return $val if $val eq '0000:00:00 00:00:00';
        return $self->InverseDateTime($val);
    }
    # (can't put Groups here because they aren't constant!)
);
# properties for ISO 8601 format date/time tags
my %iso8601Date = (
    Shift => 'Time',
    ValueConv => q{
        require Image::ExifTool::XMP;
        $val =  Image::ExifTool::XMP::ConvertXMPDate($val);
        $val =~ s/([-+]\d{2})(\d{2})$/$1:$2/; # add colon to timezone if necessary
        return $val;
    },
    ValueConvInv => q{
        require Image::ExifTool::XMP;
        my $tmp = Image::ExifTool::XMP::FormatXMPDate($val);
        ($val = $tmp) =~ s/([-+]\d{2}):(\d{2})$/$1$2/ if defined $tmp; # remove time zone colon
        return $val;
    },
    PrintConv => '$self->ConvertDateTime($val)',
    PrintConvInv => '$self->InverseDateTime($val,1)', # (add time zone if it didn't exist)
);
# information for duration tags
my %durationInfo = (
    ValueConv => '$$self{TimeScale} ? $val / $$self{TimeScale} : $val',
    PrintConv => '$$self{TimeScale} ? ConvertDuration($val) : $val',
);
# handle unknown tags
my %unknownInfo = (
    Unknown => 1,
    ValueConv => '$val =~ /^([\x20-\x7e]*)\0*$/ ? $1 : \$val',
);

# multi-language text with 6-byte header
my %langText = ( IText => 6 );

# parsing for most of the 3gp udta language text boxes
my %langText3gp = (
    Notes => 'used in 3gp videos',
    Avoid => 1,
    IText => 6,
);

# 4-character Vendor ID codes (ref PH)
my %vendorID = (
    appl => 'Apple',
    fe20 => 'Olympus (fe20)', # (FE200)
    FFMP => 'FFmpeg',
   'GIC '=> 'General Imaging Co.',
    kdak => 'Kodak',
    KMPI => 'Konica-Minolta',
    leic => 'Leica',
    mino => 'Minolta',
    niko => 'Nikon',
    NIKO => 'Nikon',
    olym => 'Olympus',
    pana => 'Panasonic',
    pent => 'Pentax',
    pr01 => 'Olympus (pr01)', # (FE100,FE110,FE115)
    sany => 'Sanyo',
   'SMI '=> 'Sorenson Media Inc.',
    ZORA => 'Zoran Corporation',
   'AR.D'=> 'Parrot AR.Drone',
   ' KD '=> 'Kodak', # (FZ201)
);

# QuickTime data atom encodings for string types (ref 12)
%stringEncoding = (
    1 => 'UTF8',
    2 => 'UTF16',
    3 => 'ShiftJIS',
    4 => 'UTF8',
    5 => 'UTF16',
);

# media types for which we have separate Keys tables (AudioKeys, VideoKeys)
%avType = (
    soun => 'Audio',
    vide => 'Video',
);

# path to Keys/ItemList/UserData tags stored in tracks
my %trackPath = (
    'MOV-Movie-Track-Meta-ItemList' => 'Keys',
    'MOV-Movie-Track-UserData-Meta-ItemList' => 'ItemList',
    'MOV-Movie-Track-UserData' => 'UserData',
);

my %graphicsMode = (
    # (ref http://homepage.mac.com/vanhoek/MovieGuts%20docs/64.html)
    0x00 => 'srcCopy',
    0x01 => 'srcOr',
    0x02 => 'srcXor',
    0x03 => 'srcBic',
    0x04 => 'notSrcCopy',
    0x05 => 'notSrcOr',
    0x06 => 'notSrcXor',
    0x07 => 'notSrcBic',
    0x08 => 'patCopy',
    0x09 => 'patOr',
    0x0a => 'patXor',
    0x0b => 'patBic',
    0x0c => 'notPatCopy',
    0x0d => 'notPatOr',
    0x0e => 'notPatXor',
    0x0f => 'notPatBic',
    0x20 => 'blend',
    0x21 => 'addPin',
    0x22 => 'addOver',
    0x23 => 'subPin',
    0x24 => 'transparent',
    0x25 => 'addMax',
    0x26 => 'subOver',
    0x27 => 'addMin',
    0x31 => 'grayishTextOr',
    0x32 => 'hilite',
    0x40 => 'ditherCopy',
    # the following ref ISO/IEC 15444-3
    0x100 => 'Alpha',
    0x101 => 'White Alpha',
    0x102 => 'Pre-multiplied Black Alpha',
    0x110 => 'Component Alpha',
);

my %channelLabel = (
    0xFFFFFFFF => 'Unknown',
    0 => 'Unused',
    100 => 'UseCoordinates',
    1 => 'Left',
    2 => 'Right',
    3 => 'Center',
    4 => 'LFEScreen',
    5 => 'LeftSurround',
    6 => 'RightSurround',
    7 => 'LeftCenter',
    8 => 'RightCenter',
    9 => 'CenterSurround',
    10 => 'LeftSurroundDirect',
    11 => 'RightSurroundDirect',
    12 => 'TopCenterSurround',
    13 => 'VerticalHeightLeft',
    14 => 'VerticalHeightCenter',
    15 => 'VerticalHeightRight',
    16 => 'TopBackLeft',
    17 => 'TopBackCenter',
    18 => 'TopBackRight',
    33 => 'RearSurroundLeft',
    34 => 'RearSurroundRight',
    35 => 'LeftWide',
    36 => 'RightWide',
    37 => 'LFE2',
    38 => 'LeftTotal',
    39 => 'RightTotal',
    40 => 'HearingImpaired',
    41 => 'Narration',
    42 => 'Mono',
    43 => 'DialogCentricMix',
    44 => 'CenterSurroundDirect',
    45 => 'Haptic',
    200 => 'Ambisonic_W',
    201 => 'Ambisonic_X',
    202 => 'Ambisonic_Y',
    203 => 'Ambisonic_Z',
    204 => 'MS_Mid',
    205 => 'MS_Side',
    206 => 'XY_X',
    207 => 'XY_Y',
    301 => 'HeadphonesLeft',
    302 => 'HeadphonesRight',
    304 => 'ClickTrack',
    305 => 'ForeignLanguage',
    400 => 'Discrete',
    0x10000 => 'Discrete_0',
    0x10001 => 'Discrete_1',
    0x10002 => 'Discrete_2',
    0x10003 => 'Discrete_3',
    0x10004 => 'Discrete_4',
    0x10005 => 'Discrete_5',
    0x10006 => 'Discrete_6',
    0x10007 => 'Discrete_7',
    0x10008 => 'Discrete_8',
    0x10009 => 'Discrete_9',
    0x1000a => 'Discrete_10',
    0x1000b => 'Discrete_11',
    0x1000c => 'Discrete_12',
    0x1000d => 'Discrete_13',
    0x1000e => 'Discrete_14',
    0x1000f => 'Discrete_15',
    0x1ffff => 'Discrete_65535',
);

my %qtFlags = ( #12
    0 => 'undef',       22 => 'unsigned int',   71 => 'float[2] size',
    1 => 'UTF-8',       23 => 'float',          72 => 'float[4] rect',
    2 => 'UTF-16',      24 => 'double',         74 => 'int64s',
    3 => 'ShiftJIS',    27 => 'BMP',            75 => 'int8u',
    4 => 'UTF-8 sort',  28 => 'QT atom',        76 => 'int16u',
    5 => 'UTF-16 sort', 65 => 'int8s',          77 => 'int32u',
    13 => 'JPEG',       66 => 'int16s',         78 => 'int64u',
    14 => 'PNG',        67 => 'int32s',         79 => 'double[3][3]',
    21 => 'signed int', 70 => 'float[2] point',
);

# properties which don't get inherited from the parent
my %dontInherit = (
    ispe => 1,  # size of parent may be different
    hvcC => 1,  # (likely redundant)
);

# tags that may be duplicated and directories that may contain duplicate tags
# (used only to avoid warnings when Validate-ing)
my %dupTagOK = ( mdat => 1, trak => 1, free => 1, infe => 1, sgpd => 1, dimg => 1, CCDT => 1,
                 sbgp => 1, csgm => 1, uuid => 1, cdsc => 1, maxr => 1, '----' => 1 );
my %dupDirOK = ( ipco => 1, '----' => 1 );

# the usual atoms required to decode timed metadata with the ExtractEmbedded option
my %eeStd = ( stco => 'stbl', co64 => 'stbl', stsz => 'stbl', stz2 => 'stbl',
              stsc => 'stbl', stts => 'stbl' );

# atoms required for generating ImageDataHash
my %hashBox = ( vide => { %eeStd }, soun => { %eeStd } );

# boxes and their containers for the various handler types that we want to save
# when the ExtractEmbedded is enabled (currently only the 'gps ' container name is
# used, but others have been checked against all available sample files and may be
# useful in the future if the names are used for different boxes on other locations)
my %eeBox = (
    # (note: vide is only processed if specific atoms exist in the VideoSampleDesc)
    vide => { %eeStd, JPEG => 'stsd' },
    text => { %eeStd },
    meta => { %eeStd },
    sbtl => { %eeStd },
    data => { %eeStd },
    camm => { %eeStd }, # (Insta360)
    ctbx => { %eeStd }, # (GM cars)
    ''   => { 'gps ' => 'moov', 'GPS ' => 'main' }, # (no handler -- in top level 'moov' box, and main)
);
# boxes to save when ExtractEmbedded is set to 2 or higher
my %eeBox2 = (
    vide => { avcC => 'stsd' }, # (parses H264 video stream)
);

# image types in AVIF and HEIC files
my %isImageData = ( av01 => 1, avc1 => 1, hvc1 => 1, lhv1 => 1, hvt1 => 1 );

my %userDefined = (
    ALBUMARTISTSORT => 'AlbumArtistSort',
    ASIN => 'ASIN',
);

# QuickTime atoms
%Image::ExifTool::QuickTime::Main = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime, # (only needs to be defined for directories to process when writing)
    GROUPS => { 2 => 'Video' },
    meta => { # 'meta' is found here in my Sony ILCE-7S MP4 sample - PH
        Name => 'Meta',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Meta',
            Start => 4, # skip 4-byte version number header
        },
    },
    meco => { #ISO14496-12:2015
        Name => 'OtherMeta',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::OtherMeta' },
    },
    free => [
        {
            Name => 'KodakFree',
            # (found in Kodak M5370 MP4 videos)
            Condition => '$$valPt =~ /^\0\0\0.Seri/s',
            SubDirectory => { TagTable => 'Image::ExifTool::Kodak::Free' },
        },{
            Name => 'Pittasoft',
            # (Pittasoft Blackview dashcam MP4 videos)
            Condition => '$$valPt =~ /^\0\0..(cprt|sttm|ptnm|ptrh|thum|gps |3gf )/s',
            SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Pittasoft' },
        },{
            Name => 'ThumbnailImage',
            # (DJI Zenmuse XT2 thermal camera)
            Groups => { 2 => 'Preview' },
            Condition => '$$valPt =~ /^.{4}mdat\xff\xd8\xff/s',
            RawConv => q{
                my $len = unpack('N', $val);
                return undef if $len <= 8 or $len > length($val);
                return substr($val, 8, $len-8);
            },
            Binary => 1,
        },{
            Unknown => 1,
            Binary => 1,
        },
        # (also Samsung WB750 uncompressed thumbnail data starting with "SDIC\0")
    ],
    # fre1 - 4 bytes: "june" (Kodak PixPro SP360)
    frea => {
        Name => 'Kodak_frea',
        SubDirectory => { TagTable => 'Image::ExifTool::Kodak::frea' },
    },
    skip => [
        {
            Name => 'CanonSkip',
            Condition => '$$valPt =~ /^\0.{3}(CNDB|CNCV|CNMN|CNFV|CNTH|CNDM)/s',
            SubDirectory => { TagTable => 'Image::ExifTool::Canon::Skip' },
        },
        {
            Name => 'PreviewImage', # (found in  DuDuBell M1 dashcam MOV files)
            Groups => { 2 => 'Preview' },
            Condition => '$$valPt =~ /^.{12}\xff\xd8\xff/',
            Binary => 1,
            RawConv => q{
                my $len = Get32u(\$val, 8);
                return undef unless length($val) >= $len + 12;
                return substr($val, 12, $len);
            },
        },
        {
            Name => 'SkipInfo', # (found in 70mai Pro Plus+ MP4 videos)
            # (look for something that looks like a QuickTime atom header)
            Condition => '$$valPt =~ /^\0[\0-\x04]..[a-zA-Z ]{4}/s',
            SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::SkipInfo' },
        },
        {
            Name => 'LigoGPSInfo',
            Condition => '$$valPt =~ /^LIGOGPSINFO\0/ and $$self{OPTIONS}{ExtractEmbedded}',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::Stream',
                ProcessProc => 'Image::ExifTool::LigoGPS::ProcessLigoGPS',
            },
        },
        {
            Name => 'Skip',
            RawConv => q{
                if ($val =~ /^LIGOGPSINFO\0/) {
                    $self->Warn('Use the ExtractEmbedded option to decode timed GPS',3);
                    return undef;
                }
                return $val;
            },
            Unknown => 1,
            Binary => 1,
        },
    ],
    wide => { Unknown => 1, Binary => 1 },
    ftyp => { #MP4
        Name => 'FileType',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::FileType' },
    },
    pnot => {
        Name => 'Preview',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Preview' },
    },
    PICT => {
        Name => 'PreviewPICT',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
    pict => { #8
        Name => 'PreviewPICT',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
    # (note that moov is present for an HEIF sequence)
    moov => {
        Name => 'Movie',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Movie' },
    },
    moof => {
        Name => 'MovieFragment',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::MovieFragment' },
    },
    # mfra - movie fragment random access: contains tfra (track fragment random access), and
    #           mfro (movie fragment random access offset) (ref 5)
    mdat => { Name => 'MediaData', Unknown => 1, Binary => 1 },
    'mdat-size' => {
        Name => 'MediaDataSize',
        RawConv => '$$self{MediaDataSize} = $val',
        Notes => q{
            not a real tag ID, this tag represents the size of the 'mdat' data in bytes
            and is used in the AvgBitrate calculation
        },
    },
    'mdat-offset' => {
        Name  => 'MediaDataOffset',
        RawConv => '$$self{MediaDataOffset} = $val',
    },
    junk => { Unknown => 1, Binary => 1 }, #8
    uuid => [
        { #9 (MP4 files)
            Name => 'XMP',
            # *** this is where ExifTool writes XMP in MP4 videos (as per XMP spec) ***
            Condition => '$$valPt=~/^\xbe\x7a\xcf\xcb\x97\xa9\x42\xe8\x9c\x71\x99\x94\x91\xe3\xaf\xac/',
            WriteGroup => 'XMP',    # (write main XMP tags here)
            PreservePadding => 1,
            SubDirectory => {
                TagTable => 'Image::ExifTool::XMP::Main',
                Start => 16,
            },
        },
        { #11 (MP4 files)
            Name => 'UUID-PROF',
            Condition => '$$valPt=~/^PROF!\xd2\x4f\xce\xbb\x88\x69\x5c\xfa\xc9\xc7\x40/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::Profile',
                Start => 24, # uid(16) + version(1) + flags(3) + count(4)
            },
        },
        { #PH (Flip MP4 files)
            Name => 'UUID-Flip',
            Condition => '$$valPt=~/^\x4a\xb0\x3b\x0f\x61\x8d\x40\x75\x82\xb2\xd9\xfa\xce\xd3\x5f\xf5/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::Flip',
                Start => 16,
            },
        },
        # "\x98\x7f\xa3\xdf\x2a\x85\x43\xc0\x8f\x8f\xd9\x7c\x47\x1e\x8e\xea" - unknown data in Flip videos
        { #PH (Canon CR3)
            Name => 'UUID-Canon2',
            WriteLast => 1, # MUST come after mdat or DPP will drop mdat when writing!
            Condition => '$$valPt=~/^\x21\x0f\x16\x87\x91\x49\x11\xe4\x81\x11\x00\x24\x21\x31\xfc\xe4/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::uuid2',
                Start => 16,
            },
        },
        { # (ref https://github.com/JamesHeinrich/getID3/blob/master/getid3/module.audio-video.quicktime.php)
            Name => 'SensorData', # sensor data for the 360Fly
            Condition => '$$valPt=~/^\xef\xe1\x58\x9a\xbb\x77\x49\xef\x80\x95\x27\x75\x9e\xb1\xdc\x6f/ and $$self{OPTIONS}{ExtractEmbedded}',
            SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Tags360Fly' },
        },{
            Name => 'SensorData',
            Condition => '$$valPt=~/^\xef\xe1\x58\x9a\xbb\x77\x49\xef\x80\x95\x27\x75\x9e\xb1\xdc\x6f/',
            Notes => 'raw 360Fly sensor data without ExtractEmbedded option',
            RawConv => q{
                $self->Warn('Use the ExtractEmbedded option to decode timed SensorData',3);
                return \$val;
            },
        },
        { #https://c2pa.org/specifications/
            Name => 'JUMBF',
            Condition => '$$valPt=~/^\xd8\xfe\xc3\xd6\x1b\x0e\x48\x3c\x92\x97\x58\x28\x87\x7e\xc4\x81.{4}manifest\0/s',
            Deletable => 1,
            SubDirectory => {
                TagTable => 'Image::ExifTool::Jpeg2000::Main',
                DirName => 'JUMBF',
                # 16 bytes uuid
                # +4 bytes 0
                # +9 bytes "manifest\0"
                # +8 bytes absolute(!!!) offset to C2PA uuid "merkle\0" box
                # =37 bytes total
                Start => 37,
            },
        },
        { #https://c2pa.org/specifications/ (NC)
            Name => 'CBOR',
            Condition => '$$valPt=~/^\xd8\xfe\xc3\xd6\x1b\x0e\x48\x3c\x92\x97\x58\x28\x87\x7e\xc4\x81.{4}merkle\0/s',
            Deletable => 1, # (NC)
            SubDirectory => {
                TagTable => 'Image::ExifTool::CBOR::Main',
                # 16 bytes uuid
                # +4 bytes 0
                # +7 bytes "merkle\0"
                # =27 bytes total
                Start => 27,
            },
        },
        { #PH (Canon CR3)
            Name => 'PreviewImage',
            Condition => '$$valPt=~/^\xea\xf4\x2b\x5e\x1c\x98\x4b\x88\xb9\xfb\xb7\xdc\x40\x6e\x4d\x16.{32}/s',
            Groups => { 2 => 'Preview' },
            PreservePadding => 1,
            # 0x00 - undef[16]: UUID
            # 0x10 - int32u[2]: "0 1" (version and/or item count?)
            # 0x18 - int32u: PRVW atom size
            # 0x20 - int32u: 'PRVW'
            # 0x30 - int32u: 0
            # 0x34 - int16u: 1
            # 0x36 - int16u: image width
            # 0x38 - int16u: image height
            # 0x3a - int16u: 1
            # 0x3c - int32u: preview length
            RawConv => '$val = substr($val, 0x30); $self->ValidateImage(\$val, $tag)',
        },
        { #PH (Garmin MP4)
            Name => 'ThumbnailImage',
            Condition => '$$valPt=~/^\x11\x6e\x40\xdc\xb1\x86\x46\xe4\x84\x7c\xd9\xc0\xc3\x49\x10\x81.{8}\xff\xd8\xff/s',
            Groups => { 2 => 'Preview' },
            Binary => 1,
            # 0x00 - undef[16]: UUID
            # 0x10 - int32u[2]: ThumbnailLength
            # 0x14 - int16u[2]: width/height of image (160/120)
            RawConv => q{
                my $len = Get32u(\$val, 0x10);
                return undef unless length($val) >= $len + 0x18;
                return substr($val, 0x18, $len);
            },
        },
        # also seen 120-byte record in Garmin MP4's, starting like this (model name at byte 9):
        # 0000: 47 52 4d 4e 00 00 00 01 00 44 43 35 37 00 00 00 [GRMN.....DC57...]
        # 0000: 47 52 4d 4e 00 00 00 01 00 44 43 36 36 57 00 00 [GRMN.....DC66W..]
        # and this in Garmin, followed by 8 bytes of 0's:
        # 0000: db 11 98 3d 8f 65 43 8c bb b8 e1 ac 56 fe 6b 04
        { #8
            Name => 'UUID-Unknown',
            %unknownInfo,
        },
    ],
    _htc => {
        Name => 'HTCInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::HTCInfo' },
    },
    udta => [{
        Name => 'KenwoodData',
        Condition => '$$valPt =~ /^VIDEOUUUUUUUUUUUUUUUUUUUUUU/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Stream',
            ProcessProc => \&ProcessKenwood,
        },
    },{
        Name => 'LigoJSON',
        Condition => '$$valPt =~ /^LIGOGPSINFO \{/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Stream',
            ProcessProc => 'Image::ExifTool::LigoGPS::ProcessLigoJSON',
        },
    },{
        Name => 'FLIRData',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::UserData' },
    }],
    thum => { #PH
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
   'thm ' => { #PH (70mai A800)
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
    ardt => { #PH
        Name => 'ARDroneFile',
        ValueConv => 'length($val) > 4 ? substr($val,4) : $val', # remove length
    },
    prrt => { #PH
        Name => 'ARDroneTelemetry',
        Notes => q{
            telemetry information for each video frame: status1, status2, time, pitch,
            roll, yaw, speed, altitude
        },
        ValueConv => q{
            my $size = length $val;
            return \$val if $size < 12 or not $$self{OPTIONS}{Binary};
            my $len = Get16u(\$val, 2);
            my $str = '';
            SetByteOrder('II');
            my $pos = 12;
            while ($pos + $len <= $size) {
                my $s1 = Get16u(\$val, $pos);
                # s2: 7=take-off?, 3=moving, 4=hovering, 9=landing?, 2=landed
                my $s2 = Get16u(\$val, $pos + 2);
                $str .= "$s1 $s2";
                my $num = int(($len-4)/4);
                my ($i, $v);
                for ($i=0; $i<$num; ++$i) {
                    my $pt = $pos + 4 + $i * 4;
                    if ($i > 0 && $i < 4) {
                        $v = GetFloat(\$val, $pt); # pitch/roll/yaw
                    } else {
                        $v = Get32u(\$val, $pt);
                        # convert time to sec, and speed(NC)/altitude to metres
                        $v /= 1000 if $i <= 5;
                    }
                    $str .= " $v";
                }
                $str .= "\n";
                $pos += $len;
            }
            SetByteOrder('MM');
            return \$str;
        },
    },
    udat => { #PH (GPS NMEA-format log written by Datakam Player software)
        Name => 'GPSLog',
        Binary => 1,    # (actually ASCII, but very lengthy)
        Notes => 'parsed to extract GPS separately when ExtractEmbedded is used',
        RawConv => q{
            $val =~ s/\0+$//;   # remove trailing nulls
            if (length $val and $$self{OPTIONS}{ExtractEmbedded}) {
                my $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
                Image::ExifTool::QuickTime::ProcessGPSLog($self, { DataPt => \$val }, $tagTbl);
            }
            return $val;
        },
    },
    # meta - proprietary XML information written by some Flip cameras - PH
    # beam - 16 bytes found in an iPhone video
    IDIT => { #PH (written by DuDuBell M1, VSYS M6L dashcams)
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Format => 'string', # (removes trailing "\0")
        Shift => 'Time',
        Writable => 1,
        Permanent => 1,
        DelValue => '0000-00-00T00:00:00+0000',
        ValueConv => '$val=~tr/-/:/; $val',
        ValueConvInv => '$val=~s/(\d+):(\d+):/$1-$2-/; $val',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,1)', # (add time zone if it didn't exist)
    },
    gps0 => { #PH (DuDuBell M1, VSYS M6L)
        Name => 'GPSTrack',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Stream',
            ProcessProc => \&Process_gps0,
        },
    },
    gsen => { #PH (DuDuBell M1, VSYS M6L)
        Name => 'GSensor',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Stream',
            ProcessProc => \&Process_gsen,
        },
    },
    # gpsa - seen hex "01 20 00 00" (DuDuBell M1, VSYS M6L)
    # gsea - 20 bytes hex "05 00's..." (DuDuBell M1) "05 08 02 01 ..." (VSYS M6L)
    gdat => {   # Base64-encoded JSON-format timed GPS (Nextbase software)
        Name => 'GPSData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Stream',
            ProcessProc => \&Process_gdat,
        },
    },
    nbmt => { # (Nextbase)
        Name => 'NextbaseMeta',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Stream',
            ProcessProc => \&Process_nbmt,
        },
    },
   'GPS ' => {  # GPS data written by 70mai dashcam (parsed in QuickTimeStream.pl)
        Name => 'GPSDataList2',
        Unknown => 1,
        Binary => 1,
    },
    sefd => {
        Name => 'SamsungTrailer',
        SubDirectory => { TagTable => 'Image::ExifTool::Samsung::Trailer' },
    },
    # 'samn'? - seen in Vantrue N2S sample video
    mpvd => {
        Name => 'MotionPhotoVideo',
        Notes => 'MP4-format video saved in Samsung motion-photo HEIC images.',
        Binary => 1,
        # note that this may be written and/or deleted, but can't currently be added back again
        Writable => 1,
    },
    # '35AX'? - seen "AT" (Yada RoadCam Pro 4K dashcam)
    cust => 'CustomInfo', # 70mai A810
    SEAL => {
        Name => 'SEAL',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::SEAL' },
    },
);

# stuff seen in 'skip' atom (70mai Pro Plus+ MP4 videos)
%Image::ExifTool::QuickTime::SkipInfo = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    'ver ' => 'Version',
    # tima - int32u: seen 0x3c
    thma => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
);

# MPEG-4 'ftyp' atom
# (ref http://developer.apple.com/mac/library/documentation/QuickTime/QTFF/QTFFChap1/qtff1.html)
%Image::ExifTool::QuickTime::FileType = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    0 => {
        Name => 'MajorBrand',
        Format => 'undef[4]',
        PrintConv => \%ftypLookup,
    },
    1 => {
        Name => 'MinorVersion',
        Format => 'undef[4]',
        ValueConv => 'sprintf("%x.%x.%x", unpack("nCC", $val))',
    },
    2 => {
        Name => 'CompatibleBrands',
        Format => 'undef[$size-8]',
        List => 1, # (for documentation only)
        # ignore any entry with a null, and return others as a list
        ValueConv => 'my @a=($val=~/.{4}/sg); @a=grep(!/\0/,@a); \@a',
    },
);

# proprietary HTC atom (HTC One MP4 video)
%Image::ExifTool::QuickTime::HTCInfo = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    NOTES => 'Tags written by some HTC camera phones.',
    slmt => {
        Name => 'Unknown_slmt',
        Unknown => 1,
        Format => 'int32u', # (observed values: 4)
    },
);

# atoms used in QTIF files
%Image::ExifTool::QuickTime::ImageFile = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Image' },
    NOTES => 'Tags used in QTIF QuickTime Image Files.',
    idsc => {
        Name => 'ImageDescription',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::ImageDesc' },
    },
    idat => {
        Name => 'ImageData',
        Binary => 1,
    },
    iicc => {
        Name => 'ICC_Profile',
        SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::Main' },
    },
);

# image description data block
%Image::ExifTool::QuickTime::ImageDesc = (
    PROCESS_PROC => \&ProcessHybrid,
    VARS => { ID_LABEL => 'ID/Index' },
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int16u',
    2 => {
        Name => 'CompressorID',
        Format => 'string[4]',
# not very useful since this isn't a complete list and name is given below
#        # ref http://developer.apple.com/mac/library/documentation/QuickTime/QTFF/QTFFChap3/qtff3.html
#        PrintConv => {
#            cvid => 'Cinepak',
#            jpeg => 'JPEG',
#           'smc '=> 'Graphics',
#           'rle '=> 'Animation',
#            rpza => 'Apple Video',
#            kpcd => 'Kodak Photo CD',
#           'png '=> 'Portable Network Graphics',
#            mjpa => 'Motion-JPEG (format A)',
#            mjpb => 'Motion-JPEG (format B)',
#            SVQ1 => 'Sorenson video, version 1',
#            SVQ3 => 'Sorenson video, version 3',
#            mp4v => 'MPEG-4 video',
#           'dvc '=> 'NTSC DV-25 video',
#            dvcp => 'PAL DV-25 video',
#           'gif '=> 'Compuserve Graphics Interchange Format',
#            h263 => 'H.263 video',
#            tiff => 'Tagged Image File Format',
#           'raw '=> 'Uncompressed RGB',
#           '2vuY'=> "Uncompressed Y'CbCr, 3x8-bit 4:2:2 (2vuY)",
#           'yuv2'=> "Uncompressed Y'CbCr, 3x8-bit 4:2:2 (yuv2)",
#            v308 => "Uncompressed Y'CbCr, 8-bit 4:4:4",
#            v408 => "Uncompressed Y'CbCr, 8-bit 4:4:4:4",
#            v216 => "Uncompressed Y'CbCr, 10, 12, 14, or 16-bit 4:2:2",
#            v410 => "Uncompressed Y'CbCr, 10-bit 4:4:4",
#            v210 => "Uncompressed Y'CbCr, 10-bit 4:2:2",
#            hvc1 => 'HEVC', #PH
#        },
    },
    10 => {
        Name => 'VendorID',
        Format => 'string[4]',
        RawConv => 'length $val ? $val : undef',
        PrintConv => \%vendorID,
        SeparateTable => 'VendorID',
    },
  # 14 - ("Quality" in QuickTime docs) ??
    16 => 'SourceImageWidth',
    17 => 'SourceImageHeight',
    18 => { Name => 'XResolution',  Format => 'fixed32u' },
    20 => { Name => 'YResolution',  Format => 'fixed32u' },
  # 24 => 'FrameCount', # always 1 (what good is this?)
    25 => {
        Name => 'CompressorName',
        Format => 'string[32]',
        # (sometimes this is a Pascal string, and sometimes it is a C string)
        RawConv => q{
            $val=substr($val,1,ord($1)) if $val=~/^([\0-\x1f])/ and ord($1)<length($val);
            length $val ? $val : undef;
        },
    },
    41 => 'BitDepth',
#
# Observed offsets for child atoms of various CompressorID types:
#
#   CompressorID  Offset  Child atoms
#   -----------   ------  ----------------
#   avc1          86      avcC, btrt, colr, pasp, fiel, clap, svcC
#   mp4v          86      esds, pasp
#   s263          86      d263
#
    btrt => {
        Name => 'BitrateInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Bitrate' },
    },
    # Reference for fiel, colr, pasp, clap:
    # https://developer.apple.com/library/mac/technotes/tn2162/_index.html#//apple_ref/doc/uid/DTS40013070-CH1-TNTAG9
    fiel => {
        Name => 'VideoFieldOrder',
        ValueConv => 'join(" ", unpack("C*",$val))',
        PrintConv => [{
            1 => 'Progressive',
            2 => '2:1 Interlaced',
        }],
    },
    colr => {
        Name => 'ColorRepresentation',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::ColorRep' },
    },
    pasp => {
        Name => 'PixelAspectRatio',
        ValueConv => 'join(":", unpack("N*",$val))',
    },
    clap => {
        Name => 'CleanAperture',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::CleanAperture' },
    },
    avcC => {
        # (see http://thompsonng.blogspot.ca/2010/11/mp4-file-format-part-2.html)
        Name => 'AVCConfiguration',
        Unknown => 1,
        Binary => 1,
    },
    JPEG => { # (found in CR3 images; used as a flag to identify JpgFromRaw 'vide' stream)
        Name => 'JPEGInfo',
        # (4 bytes all zero)
        Unknown => 1,
        Binary => 1,
    },
    # hvcC - HEVC configuration
    # svcC - 7 bytes: 00 00 00 00 ff e0 00
    # esds - elementary stream descriptor
    # d263
    gama => { Name => 'Gamma', Format => 'fixed32u' },
    # mjqt - default quantization table for MJPEG
    # mjht - default Huffman table for MJPEG
    # csgm ? (seen in hevc video)
    CMP1 => { # Canon CR3
        Name => 'CMP1',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::CMP1' },
    },
    CDI1 => { # Canon CR3
        Name => 'CDI1',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Canon::CDI1',
            Start => 4,
        },
    },
    # JPEG - 4 bytes all 0 (Canon CR3)
    # free - (Canon CR3)
#
# spherical video v2 stuff (untested)
#
    st3d => {
        Name => 'Stereoscopic3D',
        Format => 'int8u',
        ValueConv => '$val =~ s/.* //; $val', # (remove leading version/flags bytes?)
        PrintConv => {
            0 => 'Monoscopic',
            1 => 'Stereoscopic Top-Bottom',
            2 => 'Stereoscopic Left-Right',
            3 => 'Stereoscopic Stereo-Custom',
            4 => 'Stereoscopic Right-Left',
        },
    },
    sv3d => {
        Name => 'SphericalVideo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::sv3d' },
    },
);

# 'sv3d' atom information (ref https://github.com/google/spatial-media/blob/master/docs/spherical-video-v2-rfc.md)
%Image::ExifTool::QuickTime::sv3d = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    NOTES => q{
        Tags defined by the Spherical Video V2 specification.  See
        L<https://github.com/google/spatial-media/blob/master/docs/spherical-video-v2-rfc.md>
        for the specification.
    },
    svhd => {
        Name => 'MetadataSource',
        Format => 'undef',
        ValueConv => '$val=~tr/\0//d; $val', # (remove version/flags? and terminator?)
    },
    proj => {
        Name => 'Projection',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::proj' },
    },
);

# 'proj' atom information (ref https://github.com/google/spatial-media/blob/master/docs/spherical-video-v2-rfc.md)
%Image::ExifTool::QuickTime::proj = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    prhd => {
        Name => 'ProjectionHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::prhd' },
    },
    cbmp => {
        Name => 'CubemapProj',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::cbmp' },
    },
    equi => {
        Name => 'EquirectangularProj',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::equi' },
    },
    # mshp - MeshProjection (P.I.T.A. to decode, for not much reward, see ref)
);

# 'prhd' atom information (ref https://github.com/google/spatial-media/blob/master/docs/spherical-video-v2-rfc.md)
%Image::ExifTool::QuickTime::prhd = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'fixed32s',
    # 0 - version (high 8 bits) / flags (low 24 bits)
    1 => 'PoseYawDegrees',
    2 => 'PosePitchDegrees',
    3 => 'PoseRollDegrees',
);

# 'cbmp' atom information (ref https://github.com/google/spatial-media/blob/master/docs/spherical-video-v2-rfc.md)
%Image::ExifTool::QuickTime::cbmp = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    # 0 - version (high 8 bits) / flags (low 24 bits)
    1 => 'Layout',
    2 => 'Padding',
);

# 'equi' atom information (ref https://github.com/google/spatial-media/blob/master/docs/spherical-video-v2-rfc.md)
%Image::ExifTool::QuickTime::equi = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u', # (actually 0.32 fixed point)
    # 0 - version (high 8 bits) / flags (low 24 bits)
    1 => { Name => 'ProjectionBoundsTop',   ValueConv => '$val / 4294967296' },
    2 => { Name => 'ProjectionBoundsBottom',ValueConv => '$val / 4294967296' },
    3 => { Name => 'ProjectionBoundsLeft',  ValueConv => '$val / 4294967296' },
    4 => { Name => 'ProjectionBoundsRight', ValueConv => '$val / 4294967296' },
);

# 'btrt' atom information (ref http://lists.freedesktop.org/archives/gstreamer-commits/2011-October/054459.html)
%Image::ExifTool::QuickTime::Bitrate = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    PRIORITY => 0, # often filled with zeros
    0 => 'BufferSize',
    1 => 'MaxBitrate',
    2 => 'AverageBitrate',
);

# 'clap' atom information (ref https://developer.apple.com/library/mac/technotes/tn2162/_index.html#//apple_ref/doc/uid/DTS40013070-CH1-TNTAG9)
%Image::ExifTool::QuickTime::CleanAperture = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'rational64s',
    0 => 'CleanApertureWidth',
    1 => 'CleanApertureHeight',
    2 => 'CleanApertureOffsetX',
    3 => 'CleanApertureOffsetY',
);

# preview data block
%Image::ExifTool::QuickTime::Preview = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int16u',
    0 => {
        Name => 'PreviewDate',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        %timeInfo,
    },
    2 => 'PreviewVersion',
    3 => {
        Name => 'PreviewAtomType',
        Format => 'string[4]',
    },
    5 => 'PreviewAtomIndex',
);

# movie atoms
%Image::ExifTool::QuickTime::Movie = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 2 => 'Video' },
    mvhd => {
        Name => 'MovieHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::MovieHeader' },
    },
    trak => {
        Name => 'Track',
        CanCreate => 0, # don't create this atom
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Track' },
    },
    udta => {
        Name => 'UserData',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::UserData' },
    },
    meta => { # 'meta' is found here in my EX-F1 MOV sample - PH
        Name => 'Meta',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Meta' },
    },
    iods => {
        Name => 'InitialObjectDescriptor',
        Flags => ['Binary','Unknown'],
    },
    uuid => [
        { #11 (MP4 files) (also found in QuickTime::Track)
            Name => 'UUID-USMT',
            Condition => '$$valPt=~/^USMT!\xd2\x4f\xce\xbb\x88\x69\x5c\xfa\xc9\xc7\x40/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::UserMedia',
                Start => 16,
            },
        },
        { #PH (Canon SX280)
            Name => 'UUID-Canon',
            Condition => '$$valPt=~/^\x85\xc0\xb6\x87\x82\x0f\x11\xe0\x81\x11\xf4\xce\x46\x2b\x6a\x48/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Canon::uuid',
                Start => 16,
            },
        },
        {
            Name => 'GarminGPS',
            Condition => q{
                $$valPt=~/^\x9b\x63\x0f\x8d\x63\x74\x40\xec\x82\x04\xbc\x5f\xf5\x09\x17\x28/ and
                $$self{OPTIONS}{ExtractEmbedded}
            },
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::Stream',
                ProcessProc => \&ProcessGarminGPS,
            },
        },
        {
            Name => 'GarminGPS',
            Condition => '$$valPt=~/^\x9b\x63\x0f\x8d\x63\x74\x40\xec\x82\x04\xbc\x5f\xf5\x09\x17\x28/',
            Notes => 'Garmin GPS sensor data',
            RawConv => q{
                $self->Warn('Use the ExtractEmbedded option to decode timed Garmin GPS',3);
                return \$val;
            },
        },
        {
            Name => 'UUID-Unknown',
            %unknownInfo,
        },
    ],
    cmov => {
        Name => 'CompressedMovie',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::CMovie' },
    },
    htka => { # (written by HTC One M8 in slow-motion 1280x720 video - PH)
        Name => 'HTCTrack',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Track' },
    },
   'gps ' => {  # GPS data written by Novatek cameras (parsed in QuickTimeStream.pl)
        Name => 'GPSDataList',
        Unknown => 1,
        Binary => 1,
    },
    meco => { #ISO14496-12:2015
        Name => 'OtherMeta',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::OtherMeta' },
    },
    # prfl - Profile (ref 12)
    # clip - clipping --> contains crgn (clip region) (ref 12)
    # mvex - movie extends --> contains mehd (movie extends header), trex (track extends) (ref 14)
    # ICAT - 4 bytes: "6350" (Nikon CoolPix S6900), "6500" (Panasonic FT7)
);

# (ref CFFMediaFormat-2_1.pdf)
%Image::ExifTool::QuickTime::MovieFragment = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 2 => 'Video' },
    mfhd => {
        Name => 'MovieFragmentHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::MovieFragHdr' },
    },
    traf => {
        Name => 'TrackFragment',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::TrackFragment' },
    },
    meta => { #ISO14496-12:2015
        Name => 'Meta',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Meta' },
    },
);

# (ref CFFMediaFormat-2_1.pdf)
%Image::ExifTool::QuickTime::MovieFragHdr = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    1 => 'MovieFragmentSequence',
);

# (ref CFFMediaFormat-2_1.pdf)
%Image::ExifTool::QuickTime::TrackFragment = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 2 => 'Video' },
    meta => { #ISO14496-12:2015
        Name => 'Meta',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Meta' },
    },
    # tfhd - track fragment header
    # edts - edits --> contains elst (edit list) (ref PH)
    # tfdt - track fragment base media decode time
    # trik - trick play box
    # trun - track fragment run box
    # avcn - AVC NAL unit storage box
    # secn - sample encryption box
    # saio - sample auxiliary information offsets box
    # sbgp - sample to group box
    # sgpd - sample group description box
    # sdtp - independent and disposable samples (ref 5)
    # subs - sub-sample information (ref 5)
);

# movie header data block
%Image::ExifTool::QuickTime::MovieHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    DATAMEMBER => [ 0, 1, 2, 3, 4 ],
    0 => {
        Name => 'MovieHeaderVersion',
        Format => 'int8u',
        RawConv => '$$self{MovieHeaderVersion} = $val',
    },
    1 => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        %timeInfo,
        RawConv => q{
            if ($val) {
                my $offset = (66 * 365 + 17) * 24 * 3600;
                if ($val >= $offset or $$self{OPTIONS}{QuickTimeUTC}) {
                    $val -= $offset;
                } elsif (not $$self{IsWriting}) {
                    $self->Warn('Patched incorrect time zero for QuickTime date/time tag',1);
                }
            } else {
                undef $val if $$self{OPTIONS}{StrictDate};
            }
            return $$self{CreateDate} = $val;
        },
        # this is int64u if MovieHeaderVersion == 1 (ref 13)
        Hook => '$$self{MovieHeaderVersion} and $format = "int64u", $varSize += 4',
    },
    2 => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        %timeInfo,
        # this is int64u if MovieHeaderVersion == 1 (ref 13)
        Hook => '$$self{MovieHeaderVersion} and $format = "int64u", $varSize += 4',
    },
    3 => {
        Name => 'TimeScale',
        RawConv => '$$self{TimeScale} = $val',
    },
    4 => {
        Name => 'Duration',
        %durationInfo,
        # this is int64u if MovieHeaderVersion == 1 (ref 13)
        Hook => '$$self{MovieHeaderVersion} and $format = "int64u", $varSize += 4',
        # (Note: this Duration seems to be the time of the key frame in
        #  the NRT Metadata track of iPhone live-photo MOV videos)
    },
    5 => {
        Name => 'PreferredRate',
        ValueConv => '$val / 0x10000',
    },
    6 => {
        Name => 'PreferredVolume',
        Format => 'int16u',
        ValueConv => '$val / 256',
        PrintConv => 'sprintf("%.2f%%", $val * 100)',
    },
    9 => {
        Name => 'MatrixStructure',
        Format => 'fixed32s[9]',
        # (the right column is fixed 2.30 instead of 16.16)
        ValueConv => q{
            my @a = split ' ',$val;
            $_ /= 0x4000 foreach @a[2,5,8];
            return "@a";
        },
    },
    18 => { Name => 'PreviewTime',      %durationInfo },
    19 => { Name => 'PreviewDuration',  %durationInfo },
    20 => { Name => 'PosterTime',       %durationInfo },
    21 => { Name => 'SelectionTime',    %durationInfo },
    22 => { Name => 'SelectionDuration',%durationInfo },
    23 => { Name => 'CurrentTime',      %durationInfo },
    24 => 'NextTrackID',
);

# track atoms
%Image::ExifTool::QuickTime::Track = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 1 => 'Track#', 2 => 'Video' },
    tkhd => {
        Name => 'TrackHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::TrackHeader' },
    },
    udta => {
        Name => 'UserData',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::UserData' },
    },
    mdia => { #MP4
        Name => 'Media',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Media' },
    },
    meta => { #PH (MOV)
        Name => 'Meta',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Meta' },
    },
    tref => {
        Name => 'TrackRef',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::TrackRef' },
    },
    tapt => {
        Name => 'TrackAperture',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::TrackAperture' },
    },
    uuid => [
        { #11 (MP4 files) (also found in QuickTime::Movie)
            Name => 'UUID-USMT',
            Condition => '$$valPt=~/^USMT!\xd2\x4f\xce\xbb\x88\x69\x5c\xfa\xc9\xc7\x40/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::UserMedia',
                Start => 16,
            },
        },
        { #https://github.com/google/spatial-media/blob/master/docs/spherical-video-rfc.md
            Name => 'SphericalVideoXML',
            # (this tag is readable/writable as a block through the Extra SphericalVideoXML tags)
            Condition => '$$valPt=~/^\xff\xcc\x82\x63\xf8\x55\x4a\x93\x88\x14\x58\x7a\x02\x52\x1f\xdd/',
            WriteGroup => 'GSpherical', # write only GSpherical XMP tags here
            MediaType => 'vide',        # only write in video tracks
            SubDirectory => {
                TagTable => 'Image::ExifTool::XMP::Main',
                Start => 16,
                ProcessProc => 'Image::ExifTool::XMP::ProcessGSpherical',
                WriteProc => 'Image::ExifTool::XMP::WriteGSpherical',
            },
        },
        {
            Name => 'UUID-Unknown',
            %unknownInfo,
        },
    ],
    meco => { #ISO14492-12:2015 pg 83
        Name => 'OtherMeta',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::OtherMeta' },
    },
    # edts - edits --> contains elst (edit list)
    # clip - clipping --> contains crgn (clip region)
    # matt - track matt --> contains kmat (compressed matt)
    # load - track loading settings
    # imap - track input map --> contains '  in' --> contains '  ty', obid
    # prfl - Profile (ref 12)
);

# track header data block
%Image::ExifTool::QuickTime::TrackHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 1 => 'Track#', 2 => 'Video' },
    FORMAT => 'int32u',
    DATAMEMBER => [ 0, 1, 2, 5, 7 ],
    0 => {
        Name => 'TrackHeaderVersion',
        Format => 'int8u',
        Priority => 0,
        RawConv => '$$self{TrackHeaderVersion} = $val',
    },
    1 => {
        Name => 'TrackCreateDate',
        Priority => 0,
        Groups => { 2 => 'Time' },
        %timeInfo,
        # this is int64u if TrackHeaderVersion == 1 (ref 13)
        Hook => '$$self{TrackHeaderVersion} and $format = "int64u", $varSize += 4',
    },
    2 => {
        Name => 'TrackModifyDate',
        Priority => 0,
        Groups => { 2 => 'Time' },
        %timeInfo,
        # this is int64u if TrackHeaderVersion == 1 (ref 13)
        Hook => '$$self{TrackHeaderVersion} and $format = "int64u", $varSize += 4',
    },
    3 => {
        Name => 'TrackID',
        Priority => 0,
    },
    5 => {
        Name => 'TrackDuration',
        Priority => 0,
        %durationInfo,
        # this is int64u if TrackHeaderVersion == 1 (ref 13)
        Hook => '$$self{TrackHeaderVersion} and $format = "int64u", $varSize += 4',
    },
    7 => { # (used only for writing MatrixStructure)
        Name => 'ImageSizeLookahead',
        Hidden => 1,
        Format => 'int32u[14]',
        RawConv => '$$self{ImageSizeLookahead} = $val; undef',
    },
    8 => {
        Name => 'TrackLayer',
        Format => 'int16u',
        Priority => 0,
    },
    9 => {
        Name => 'TrackVolume',
        Format => 'int16u',
        Priority => 0,
        ValueConv => '$val / 256',
        PrintConv => 'sprintf("%.2f%%", $val * 100)',
    },
    10 => {
        Name => 'MatrixStructure',
        Format => 'fixed32s[9]',
        Notes => 'writable for the video track via the Composite Rotation tag',
        Writable => 1,
        Protected => 1,
        Permanent => 1,
        # only set rotation if image size is non-zero
        RawConvInv => \&GetMatrixStructure,
        # (the right column is fixed 2.30 instead of 16.16)
        ValueConv => q{
            my @a = split ' ',$val;
            $_ /= 0x4000 foreach @a[2,5,8];
            return "@a";
        },
        ValueConvInv => q{
            my @a = split ' ',$val;
            $_ *= 0x4000 foreach @a[2,5,8];
            return "@a";
        },
    },
    19 => {
        Name => 'ImageWidth',
        Priority => 0,
        RawConv => \&FixWrongFormat,
    },
    20 => {
        Name => 'ImageHeight',
        Priority => 0,
        RawConv => \&FixWrongFormat,
    },
);

# user data atoms
%Image::ExifTool::QuickTime::UserData = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    CHECK_PROC => \&CheckQTValue,
    GROUPS => { 1 => 'UserData', 2 => 'Video' },
    WRITABLE => 1,
    PREFERRED => 1, # (preferred over Keys tags when writing)
    FORMAT => 'string',
    WRITE_GROUP => 'UserData',
    LANG_INFO => \&GetLangInfo,
    NOTES => q{
        Tag ID's beginning with the copyright symbol (hex 0xa9) are multi-language
        text.  Alternate language tags are accessed by adding a dash followed by a
        3-character ISO 639-2 language code to the tag name.  ExifTool will extract
        any multi-language user data tags found, even if they aren't in this table.
        Note when creating new tags,
        L<ItemList|Image::ExifTool::TagNames/QuickTime ItemList Tags> tags are
        preferred over these, so to create the tag when a same-named ItemList tag
        exists, either "UserData" must be specified (eg. C<-UserData:Artist=Monet>
        on the command line), or the PREFERRED level must be changed via
        L<the config file|../config.html#PREF>.
    },
    "\xa9cpy" => { Name => 'Copyright',  Groups => { 2 => 'Author' } },
    "\xa9day" => {
        Name => 'ContentCreateDate',
        Groups => { 2 => 'Time' },
        %iso8601Date,
    },
    "\xa9ART" => 'Artist', #PH (iTunes 8.0.2)
    "\xa9alb" => 'Album', #PH (iTunes 8.0.2)
    "\xa9arg" => 'Arranger', #12
    "\xa9ark" => 'ArrangerKeywords', #12
    "\xa9cmt" => 'Comment', #PH (iTunes 8.0.2)
    "\xa9cok" => 'ComposerKeywords', #12
    "\xa9com" => 'Composer', #12
    "\xa9dir" => 'Director', #12
    "\xa9ed1" => 'Edit1',
    "\xa9ed2" => 'Edit2',
    "\xa9ed3" => 'Edit3',
    "\xa9ed4" => 'Edit4',
    "\xa9ed5" => 'Edit5',
    "\xa9ed6" => 'Edit6',
    "\xa9ed7" => 'Edit7',
    "\xa9ed8" => 'Edit8',
    "\xa9ed9" => 'Edit9',
    "\xa9fmt" => 'Format',
    "\xa9gen" => 'Genre', #PH (iTunes 8.0.2)
    "\xa9grp" => 'Grouping', #PH (NC)
    "\xa9inf" => 'Information',
    "\xa9isr" => 'ISRCCode', #12
    "\xa9lab" => 'RecordLabelName', #12
    "\xa9lal" => 'RecordLabelURL', #12
    "\xa9lyr" => 'Lyrics', #PH (NC)
    "\xa9mak" => 'Make', #12
    "\xa9mal" => 'MakerURL', #12
    "\xa9mod" => 'Model', #PH
    "\xa9nam" => 'Title', #12
    "\xa9pdk" => 'ProducerKeywords', #12
    "\xa9phg" => 'RecordingCopyright', #12
    "\xa9prd" => 'Producer',
    "\xa9prf" => 'Performers',
    "\xa9prk" => 'PerformerKeywords', #12
    "\xa9prl" => 'PerformerURL',
    "\xa9req" => 'Requirements',
    "\xa9snk" => 'SubtitleKeywords', #12
    "\xa9snm" => 'Subtitle', #12
    "\xa9src" => 'SourceCredits', #12
    "\xa9swf" => 'SongWriter', #12
    "\xa9swk" => 'SongWriterKeywords', #12
    "\xa9swr" => 'SoftwareVersion', #12
    "\xa9too" => 'Encoder', #PH (NC)
    "\xa9trk" => 'Track', #PH (NC)
    "\xa9wrt" => { Name => 'Composer', Avoid => 1 }, # ("\xa9com" is preferred in UserData)
    "\xa9xyz" => { #PH (iPhone 3GS)
        Name => 'GPSCoordinates',
        Groups => { 2 => 'Location' },
        ValueConv => \&ConvertISO6709,
        ValueConvInv => \&ConvInvISO6709,
        PrintConv => \&PrintGPSCoordinates,
        PrintConvInv => \&PrintInvGPSCoordinates,
    },
    # \xa9 tags written by DJI Phantom 3: (ref PH)
    "\xa9xsp" => 'SpeedX', #PH (guess)
    "\xa9ysp" => 'SpeedY', #PH (guess)
    "\xa9zsp" => 'SpeedZ', #PH (guess)
    "\xa9fpt" => 'Pitch', #PH
    "\xa9fyw" => 'Yaw', #PH
    "\xa9frl" => 'Roll', #PH
    "\xa9gpt" => 'CameraPitch', #PH
    "\xa9gyw" => 'CameraYaw', #PH
    "\xa9grl" => 'CameraRoll', #PH
    "\xa9enc" => 'EncoderID', #PH (forum9271)
    # and the following entries don't have the proper 4-byte header for \xa9 tags:
    "\xa9dji" => { Name => 'UserData_dji', Format => 'undef', Binary => 1, Unknown => 1, Hidden => 1 },
    "\xa9res" => { Name => 'UserData_res', Format => 'undef', Binary => 1, Unknown => 1, Hidden => 1 },
    "\xa9uid" => { Name => 'UserData_uid', Format => 'undef', Binary => 1, Unknown => 1, Hidden => 1 },
    "\xa9mdl" => {
        Name => 'Model',
        Notes => 'non-standard-format DJI tag',
        Format => 'string',
        Avoid => 1,
    },
    # end DJI tags
    name => 'Name',
    WLOC => {
        Name => 'WindowLocation',
        Format => 'int16u',
    },
    LOOP => {
        Name => 'LoopStyle',
        Format => 'int32u',
        PrintConv => {
            1 => 'Normal',
            2 => 'Palindromic',
        },
    },
    SelO => {
        Name => 'PlaySelection',
        Format => 'int8u',
    },
    AllF => {
        Name => 'PlayAllFrames',
        Format => 'int8u',
    },
    meta => {
        Name => 'Meta',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Meta',
            Start => 4, # must skip 4-byte version number header
        },
    },
   'ptv '=> {
        Name => 'PrintToVideo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Video' },
    },
    hnti => {
        Name => 'HintInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::HintInfo' },
    },
    hinf => {
        Name => 'HintTrackInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::HintTrackInfo' },
    },
    hinv => 'HintVersion', #PH (guess)
    XMP_ => { #PH (Adobe CS3 Bridge)
        Name => 'XMP',
        WriteGroup => 'XMP',    # (write main tags here)
        # *** this is where ExifTool writes XMP in MOV videos (as per XMP spec) ***
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
    # the following are 3gp tags, references:
    # http://atomicparsley.sourceforge.net
    # http://www.3gpp.org/ftp/tsg_sa/WG4_CODEC/TSGS4_25/Docs/
    # (note that all %langText3gp tags are Avoid => 1)
    cprt => { Name => 'Copyright',  %langText3gp, Groups => { 2 => 'Author' } },
    auth => { Name => 'Author',     %langText3gp, Groups => { 2 => 'Author' } },
    titl => { Name => 'Title',      %langText3gp },
    dscp => { Name => 'Description',%langText3gp },
    perf => { Name => 'Performer',  %langText3gp },
    gnre => { Name => 'Genre',      %langText3gp },
    albm => { Name => 'Album',      %langText3gp },
    coll => { Name => 'CollectionName', %langText3gp }, #17
    rtng => {
        Name => 'Rating',
        Writable => 'undef',
        Avoid => 1,
        # (4-byte flags, 4-char entity, 4-char criteria, 2-byte lang, string)
        IText => 14, # (14 bytes before string)
        Notes => 'string in the form "Entity=XXXX Criteria=XXXX XXXXX", used in 3gp videos',
        ValueConv => '$val=~s/^(.{4})(.{4})/Entity=$1 Criteria=$2 /i; $val',
        ValueConvInv => '$val=~s/Entity=(.{4}) Criteria=(.{4}) ?/$1$2/i; $val',
    },
    clsf => {
        Name => 'Classification',
        Writable => 'undef',
        Avoid => 1,
        # (4-byte flags, 4-char entity, 2-byte index, 2-byte lang, string)
        IText => 12,
        Notes => 'string in the form "Entity=XXXX Index=### XXXXX", used in 3gp videos',
        ValueConv => '$val=~s/^(.{4})(.{2})/"Entity=$1 Index=".unpack("n",$2)." "/ie; $val',
        ValueConvInv => '$val=~s/Entity=(.{4}) Index=(\d+) ?/$1.pack("n",$2)/ie; $val',
    },
    kywd => {
        Name => 'Keywords',
        # (4 byte flags, 2-byte lang, 1-byte count, count x pascal strings, ref 17)
        # (but I have also seen a simple string written by iPhone, so don't make writable yet)
        Notes => "not writable because Apple doesn't follow the 3gp specification",
        RawConv => q{
            my $sep = $self->Options('ListSep');
            return join($sep, split /\0+/, $val) unless $val =~ /^\0/; # (iPhone)
            return '<err>' unless length $val >= 7;
            my $lang = Image::ExifTool::QuickTime::UnpackLang(Get16u(\$val, 4));
            $lang = $lang ? "($lang) " : '';
            my $num = Get8u(\$val, 6);
            my ($i, @vals);
            my $pos = 7;
            for ($i=0; $i<$num; ++$i) {
                last if $pos >= length $val;
                my $len = Get8u(\$val, $pos++);
                last if $pos + $len > length $val;
                my $v = substr($val, $pos, $len);
                $v = $self->Decode($v, 'UCS2') if $v =~ /^\xfe\xff/;
                push @vals, $v;
                $pos += $len;
            }
            return $lang . join($sep, @vals);
        },
    },
    loci => {
        Name => 'LocationInformation',
        Groups => { 2 => 'Location' },
        Writable => 'undef',
        IText => 6,
        Avoid => 1,
        NoDecode => 1, # (we'll decode the data ourself)
        Notes => q{
            string in the form "XXXXX Role=XXX Lat=XXX Lon=XXX Alt=XXX Body=XXX
            Notes=XXX", used in 3gp videos
        },
        # (4-byte flags, 2-byte lang, location string, 1-byte role, 4-byte fixed longitude,
        #  4-byte fixed latitude, 4-byte fixed altitude, body string, notes string)
        RawConv => q{
            my $str;
            if ($val =~ /^\xfe\xff/) {
                $val =~ s/^(\xfe\xff(.{2})*?)\0\0//s or return '<err>';
                $str = $self->Decode($1, 'UCS2');
            } else {
                $val =~ s/^(.*?)\0//s or return '<err>';
                $str = $self->Decode($1, 'UTF8');
            }
            $str = '(none)' unless length $str;
            return '<err>' if length $val < 13;
            my $role = Get8u(\$val, 0);
            my $lon = GetFixed32s(\$val, 1);
            my $lat = GetFixed32s(\$val, 5);
            my $alt = GetFixed32s(\$val, 9);
            my $roleStr = {0=>'shooting',1=>'real',2=>'fictional',3=>'reserved'}->{$role};
            $str .= ' Role=' . ($roleStr || "unknown($role)");
            $str .= sprintf(' Lat=%.5f Lon=%.5f Alt=%.2f', $lat, $lon, $alt);
            $val = substr($val, 13);
            if ($val =~ s/^(\xfe\xff(.{2})*?)\0\0//s) {
                $str .= ' Body=' . $self->Decode($1, 'UCS2');
            } elsif ($val =~ s/^(.*?)\0//s) {
                $str .= ' Body=' . $self->Decode($1, 'UTF8');
            }
            if ($val =~ s/^(\xfe\xff(.{2})*?)\0\0//s) {
                $str .= ' Notes=' . $self->Decode($1, 'UCS2');
            } elsif ($val =~ s/^(.*?)\0//s) {
                $str .= ' Notes=' . $self->Decode($1, 'UTF8');
            }
            return $str;
        },
        RawConvInv => q{
            my ($role, $lat, $lon, $alt, $body, $note);
            $lat = $1 if $val =~ s/ Lat=([-+]?[.\d]+)//i;
            $lon = $1 if $val =~ s/ Lon=([-+]?[.\d]+)//i;
            $alt = $1 if $val =~ s/ Alt=([-+]?[.\d]+)//i;
            $note = $val =~ s/ Notes=(.*)//i ? $1 : '';
            $body = $val =~ s/ Body=(.*)//i ? $1 : '';
            $role = $val =~ s/ Role=(.*)//i ? $1 : '';
            $val = '' if $val eq '(none)';
            $role = {shooting=>0,real=>1,fictional=>2}->{lc $role} || 0;
            return $self->Encode($val, 'UTF8') . "\0" . Set8u($role) .
                   SetFixed32s(defined $lon ? $lon : 999) .
                   SetFixed32s(defined $lat ? $lat : 999) .
                   SetFixed32s(defined $alt ? $alt : 0) .
                   $self->Encode($body) . "\0" .
                   $self->Encode($note) . "\0";
        },
    },
    yrrc => {
        Name => 'Year',
        Writable => 'undef',
        Groups => { 2 => 'Time' },
        Avoid => 1,
        Notes => 'used in 3gp videos',
        ValueConv => 'length($val) >= 6 ? unpack("x4n",$val) : "<err>"',
        ValueConvInv => 'pack("Nn",0,$val)',
    },
    urat => { #17
        Name => 'UserRating',
        Writable => 'undef',
        Notes => 'used in 3gp videos',
        Avoid => 1,
        ValueConv => q{
            return '<err>' unless length $val >= 8;
            unpack('x7C', $val);
        },
        ValueConvInv => 'pack("N2",0,$val)',
    },
    # tsel - TrackSelection (ref 17)
    # Apple tags (ref 16[dead] -- see ref 25 instead)
    angl => { Name => 'CameraAngle',  Format => 'string' }, # (NC)
    clfn => { Name => 'ClipFileName', Format => 'string' }, # (NC)
    clid => { Name => 'ClipID',       Format => 'string' }, # (NC)
    cmid => { Name => 'CameraID',     Format => 'string' }, # (NC)
    cmnm => { # (NC)
        Name => 'Model',
        Description => 'Camera Model Name',
        Avoid => 1,
        Format => 'string', # (necessary to remove the trailing NULL)
    },
    date => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Notes => q{
            Apple Photos has been reported to show a crazy date/time for some MP4 files
            containing this tag, but perhaps only if it is missing a time zone
        }, #forum10690/11125
        %iso8601Date,
    },
    manu => { # (SX280)
        Name => 'Make',
        Avoid => 1,
        # (with Canon there are 6 unknown bytes before the model: "\0\0\0\0\x15\xc7")
        RawConv => '$val=~s/^\0{4}..//s; $val=~s/\0.*//; $val',
    },
    modl => { # (Samsung GT-S8530, Canon SX280)
        Name => 'Model',
        Description => 'Camera Model Name',
        Avoid => 1,
        # (with Canon there are 6 unknown bytes before the model: "\0\0\0\0\x15\xc7")
        RawConv => '$val=~s/^\0{4}..//s; $val=~s/\0.*//; $val',
    },
    reel => { Name => 'ReelName',     Format => 'string' }, # (NC)
    scen => { Name => 'Scene',        Format => 'string' }, # (NC)
    shot => { Name => 'ShotName',     Format => 'string' }, # (NC)
    slno => { Name => 'SerialNumber', Format => 'string' }, # (NC)
    apmd => { Name => 'ApertureMode', Format => 'undef' }, #20
    kgtt => { #http://lists.ffmpeg.org/pipermail/ffmpeg-devel-irc/2012-June/000707.html
        # 'TrackType' will expand to 'Track#Type' when found inside a track
        Name => 'TrackType',
        # set flag to process this as international text
        # even though the tag ID doesn't start with 0xa9
        IText => 4, # IText with 4-byte header
    },
    chpl => { # (Nero chapter list)
        Name => 'ChapterList',
        ValueConv => \&ConvertChapterList,
        PrintConv => \&PrintChapter,
    },
    # ndrm - 7 bytes (0 0 0 1 0 0 0) Nero Digital Rights Management? (PH)
    # other non-Apple tags (ref 16)
    # hpix - HipixRichPicture (ref 16, HIPIX)
    # strk - sub-track information (ref 16, ISO)
#
# Manufacturer-specific metadata
#
    TAGS => [ #PH
        # these tags were initially discovered in a Pentax movie,
        # but similar information is found in videos from other manufacturers
        {
            Name => 'FujiFilmTags',
            Condition => '$$valPt =~ /^FUJIFILM DIGITAL CAMERA\0/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::FujiFilm::MOV',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'KodakTags',
            Condition => '$$valPt =~ /^EASTMAN KODAK COMPANY/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Kodak::MOV',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'KonicaMinoltaTags',
            Condition => '$$valPt =~ /^KONICA MINOLTA DIGITAL CAMERA/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Minolta::MOV1',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'MinoltaTags',
            Condition => '$$valPt =~ /^MINOLTA DIGITAL CAMERA/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Minolta::MOV2',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'NikonTags',
            Condition => '$$valPt =~ /^NIKON DIGITAL CAMERA\0/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Nikon::MOV',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'OlympusTags1',
            Condition => '$$valPt =~ /^OLYMPUS DIGITAL CAMERA\0.{9}\x01\0/s',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::MOV1',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'OlympusTags2',
            Condition => '$$valPt =~ /^OLYMPUS DIGITAL CAMERA(?!\0.{21}\x0a\0{3})/s',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::MOV2',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'OlympusTags3',
            Condition => '$$valPt =~ /^OLYMPUS DIGITAL CAMERA\0/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::MP4',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'OlympusTags4',
            Condition => '$$valPt =~ /^.{16}OLYM\0/s',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Olympus::MOV3',
                Start => 12,
            },
        },
        {
            Name => 'PentaxTags',
            Condition => '$$valPt =~ /^PENTAX DIGITAL CAMERA\0/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Pentax::MOV',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'SamsungTags',
            Condition => '$$valPt =~ /^SAMSUNG DIGITAL CAMERA\0/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Samsung::MP4',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'SanyoMOV',
            Condition => q{
                $$valPt =~ /^SANYO DIGITAL CAMERA\0/ and
                $$self{FileType} eq "MOV"
            },
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sanyo::MOV',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'SanyoMP4',
            Condition => q{
                $$valPt =~ /^SANYO DIGITAL CAMERA\0/ and
                $$self{FileType} eq "MP4"
            },
            SubDirectory => {
                TagTable => 'Image::ExifTool::Sanyo::MP4',
                ByteOrder => 'LittleEndian',
            },
        },
        {
            Name => 'UnknownTags',
            Unknown => 1,
            Binary => 1
        },
    ],
    # ---- Canon ----
    CNCV => { Name => 'CompressorVersion', Format => 'string' }, #PH (5D Mark II)
    CNMN => {
        Name => 'Model', #PH (EOS 550D)
        Description => 'Camera Model Name',
        Avoid => 1,
        Format => 'string', # (necessary to remove the trailing NULL)
    },
    CNFV => { Name => 'FirmwareVersion', Format => 'string' }, #PH (EOS 550D)
    CNTH => { #PH (PowerShot S95)
        Name => 'CanonCNTH',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::CNTH' },
    },
    CNOP => { #PH (7DmkII)
        Name => 'CanonCNOP',
        SubDirectory => { TagTable => 'Image::ExifTool::Canon::CNOP' },
    },
    # CNDB - 2112 bytes (550D)
    # CNDM - 4 bytes - 0xff,0xd8,0xff,0xd9 (S95)
    # CNDG - 10232 bytes, mostly zeros (N100)
    # ---- Casio ----
    QVMI => { #PH
        Name => 'CasioQVMI',
        # Casio stores standard EXIF-format information in MOV videos (eg. EX-S880)
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::Exif::ProcessExif, # (because ProcessMOV is default)
            DirName => 'IFD0',
            Multi => 0, # (no NextIFD pointer)
            Start => 10,
            ByteOrder => 'BigEndian',
        },
    },
    # ---- FujiFilm ----
    FFMV => { #PH (FinePix HS20EXR)
        Name => 'FujiFilmFFMV',
        SubDirectory => { TagTable => 'Image::ExifTool::FujiFilm::FFMV' },
    },
    MVTG => { #PH (FinePix HS20EXR)
        Name => 'FujiFilmMVTG',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::Exif::ProcessExif, # (because ProcessMOV is default)
            DirName => 'IFD0',
            Start => 16,
            Base => '$start',
            ByteOrder => 'LittleEndian',
        },
    },
    # ---- Garmin ---- (ref PH)
    uuid => [{
        Name => 'GarminSoftware', # (NC)
        Condition => '$$valPt =~ /^VIRBactioncamera/',
        RawConv => 'substr($val, 16)',
        RawConvInv => '"VIRBactioncamera$val"',
    },{
        Name => 'GarminModel', # (NC)
        Condition => '$$valPt =~ /^\xf7\x6c\xd7\x6a\x07\x5b\x4a\x1e\xb3\x1c\x0e\x7f\xab\x7e\x09\xd4/',
        Writable => 0,
        RawConv => q{
            return undef unless length($val) > 25;
            my $len = unpack('x24C', $val);
            return undef unless length($val) >= 25 + $len;
            return substr($val, 25, $len);
        },
    },{
        # have seen "28 f3 11 e2 b7 91 4f 6f 94 e2 4f 5d ea cb 3c 01" for RicohThetaZ1 accelerometer RADT data (not yet decoded)
        # also seen in Garmin MP4:
        # 51 0b 63 46 6c fd 4a 17 87 42 ea c9 ea ae b3 bd - seems to contain a duplicate of the trak atom
        # b3 e8 21 f4 fe 33 4e 10 8f 92 f5 e1 d4 36 c9 8a - 8 bytes of zeros
        Name => 'UUID-Unknown',
        Writable => 0,
        %unknownInfo,
    }],
    pmcc => {
        Name => 'GarminSettings',
        ValueConv => 'substr($val, 4)',
        ValueConvInv => '"\0\0\0\x01$val"',
    },
    # hmtp - 412 bytes: "\0\0\0\x01" then maybe "\0\0\0\x64" and the rest zeros
    # vrin - 12 bytes: "\0\0\0\x01" followed by 8 bytes of zero
    # ---- GoPro ---- (ref PH)
    GoPr => 'GoProType', # (Hero3+)
    FIRM => { Name => 'FirmwareVersion', Avoid => 1 }, # (Hero4)
    LENS => 'LensSerialNumber', # (Hero4)
    CAME => { # (Hero4)
        Name => 'SerialNumberHash',
        Description => 'Camera Serial Number Hash',
        ValueConv => 'unpack("H*",$val)',
        ValueConvInv => 'pack("H*",$val)',
    },
    # SETT? 12 bytes (Hero4)
    # MUID? 32 bytes (Hero4, starts with serial number hash)
    # HMMT? 404 bytes (Hero4, all zero)
    # BCID? 26 bytes (Hero5, all zero), 36 bytes GoPro Max
    # GUMI? 16 bytes (Hero5)
   "FOV\0" => 'FieldOfView', #forum8938 (Hero2) seen: "Wide"
    GPMF => {
        Name => 'GoProGPMF',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::GPMF' },
    },
    # free (all zero)
    "\xa9TSC" => 'StartTimeScale', # (Hero6)
    "\xa9TSZ" => 'StartTimeSampleSize', # (Hero6)
    "\xa9TIM" => 'StartTimecode', #PH (NC)
    # --- HTC ----
    htcb => {
        Name => 'HTCBinary',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::HTCBinary' },
    },
    # ---- Kodak ----
    DcMD => {
        Name => 'KodakDcMD',
        SubDirectory => { TagTable => 'Image::ExifTool::Kodak::DcMD' },
    },
    SNum => { Name => 'SerialNumber', Avoid => 1, Groups => { 2 => 'Camera' } },
    ptch => { Name => 'Pitch', Format => 'rational64s', Avoid => 1 }, # Units??
    _yaw => { Name => 'Yaw',   Format => 'rational64s', Avoid => 1 }, # Units??
    roll => { Name => 'Roll',  Format => 'rational64s', Avoid => 1 }, # Units??
    _cx_ => { Name => 'CX',    Format => 'rational64s', Unknown => 1 },
    _cy_ => { Name => 'CY',    Format => 'rational64s', Unknown => 1 },
    rads => { Name => 'Rads',  Format => 'rational64s', Unknown => 1 },
    lvlm => { Name => 'LevelMeter', Format => 'rational64s', Unknown => 1 }, # (guess, Kodak proprietary)
    Lvlm => { Name => 'LevelMeter', Format => 'rational64s', Unknown => 1 }, # (guess, Kodak proprietary)
    pose => { Name => 'pose', SubDirectory => { TagTable => 'Image::ExifTool::Kodak::pose' } },
    # AMBA => Ambarella AVC atom (unknown data written by Kodak Playsport video cam)
    # tmlp - 1 byte: 0 (PixPro SP360/4KVR360)
    # pivi - 72 bytes (PixPro SP360)
    # pive - 12 bytes (PixPro SP360)
    # loop - 4 bytes: 0 0 0 0 (PixPro 4KVR360)
    # m cm - 2 bytes: 0 0 (PixPro 4KVR360)
    # m ev - 2 bytes: 0 0 (PixPro SP360/4KVR360) (exposure comp?)
    # m vr - 2 bytes: 0 1 (PixPro 4KVR360) (virtual reality?)
    # m wb - 4 bytes: 0 0 0 0 (PixPro SP360/4KVR360) (white balance?)
    # mclr - 4 bytes: 0 0 0 0 (PixPro SP360/4KVR360)
    # mmtr - 4 bytes: 0,6 0 0 0 (PixPro SP360/4KVR360)
    # mflr - 4 bytes: 0 0 0 0 (PixPro SP360)
    # lvlm - 24 bytes (PixPro SP360)
    # Lvlm - 24 bytes (PixPro 4KVR360)
    # ufdm - 4 bytes: 0 0 0 1 (PixPro SP360)
    # mtdt - 1 byte: 0 (PixPro SP360/4KVR360)
    # gdta - 75240 bytes (PixPro SP360)
    # EIS1 - 4 bytes: 03 07 00 00 (PixPro 4KVR360)
    # EIS2 - 4 bytes: 04 97 00 00 (PixPro 4KVR360)
    # ---- LG ----
    adzc => { Name => 'Unknown_adzc', Unknown => 1, Hidden => 1, %langText }, # "false\0/","true\0/"
    adze => { Name => 'Unknown_adze', Unknown => 1, Hidden => 1, %langText }, # "false\0/"
    adzm => { Name => 'Unknown_adzm', Unknown => 1, Hidden => 1, %langText }, # "\x0e\x04/","\x10\x06"
    # ---- Microsoft ----
    Xtra => { #PH (microsoft)
        Name => 'MicrosoftXtra',
        WriteGroup => 'Microsoft',
        SubDirectory => {
            DirName => 'Microsoft',
            TagTable => 'Image::ExifTool::Microsoft::Xtra',
        },
    },
    # ---- Minolta ----
    MMA0 => { #PH (DiMage 7Hi)
        Name => 'MinoltaMMA0',
        SubDirectory => { TagTable => 'Image::ExifTool::Minolta::MMA' },
    },
    MMA1 => { #PH (Dimage A2)
        Name => 'MinoltaMMA1',
        SubDirectory => { TagTable => 'Image::ExifTool::Minolta::MMA' },
    },
    # ---- Nikon ----
    NCDT => { #PH
        Name => 'NikonNCDT',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::NCDT' },
    },
    # ---- Olympus ----
    scrn => { #PH (TG-810)
        Name => 'OlympusPreview',
        Condition => '$$valPt =~ /^.{4}\xff\xd8\xff\xdb/s',
        SubDirectory => { TagTable => 'Image::ExifTool::Olympus::scrn' },
    },
    # ---- Panasonic/Leica ----
    PANA => { #PH
        Name => 'PanasonicPANA',
        SubDirectory => { TagTable => 'Image::ExifTool::Panasonic::PANA' },
    },
    LEIC => { #PH
        Name => 'LeicaLEIC',
        SubDirectory => { TagTable => 'Image::ExifTool::Panasonic::PANA' },
    },
    # ---- Pentax ----
    thmb => [ # (apparently defined by 3gpp, ref 16)
        { #PH (Pentax Q)
            Name => 'MakerNotePentax5a',
            Condition => '$$valPt =~ /^PENTAX \0II/',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Pentax::Main',
                ProcessProc => \&Image::ExifTool::Exif::ProcessExif, # (because ProcessMOV is default)
                Start => 10,
                Base => '$start - 10',
                ByteOrder => 'LittleEndian',
            },
        },{ #PH (TG-810)
            Name => 'OlympusThumbnail',
            Condition => '$$valPt =~ /^.{4}\xff\xd8\xff\xdb/s',
            SubDirectory => { TagTable => 'Image::ExifTool::Olympus::thmb' },
        },{ #17 (format is in bytes 3-7)
            Name => 'ThumbnailImage',
            Condition => '$$valPt =~ /^.{8}\xff\xd8\xff[\xdb\xe0]/s',
            Groups => { 2 => 'Preview' },
            RawConv => 'substr($val, 8)',
            Binary => 1,
        },{ #17 (format is in bytes 3-7)
            Name => 'ThumbnailPNG',
            Condition => '$$valPt =~ /^.{8}\x89PNG\r\n\x1a\n/s',
            Groups => { 2 => 'Preview' },
            RawConv => 'substr($val, 8)',
            Binary => 1,
        },{
            Name => 'UnknownThumbnail',
            Groups => { 2 => 'Preview' },
            Binary => 1,
        },
    ],
    PENT => { #PH
        Name => 'PentaxPENT',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Pentax::PENT',
            ByteOrder => 'LittleEndian',
        },
    },
    PXTH => { #PH (Pentax K-01)
        Name => 'PentaxPreview',
        SubDirectory => { TagTable => 'Image::ExifTool::Pentax::PXTH' },
    },
    PXMN => [{ #PH (Pentax K-01)
        Name => 'MakerNotePentax5b',
        Condition => '$$valPt =~ /^PENTAX \0MM/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Pentax::Main',
            ProcessProc => \&Image::ExifTool::Exif::ProcessExif, # (because ProcessMOV is default)
            Start => 10,
            Base => '$start - 10',
            ByteOrder => 'BigEndian',
        },
    },{ #PH (Pentax 645Z)
        Name => 'MakerNotePentax5c',
        Condition => '$$valPt =~ /^PENTAX \0II/',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Pentax::Main',
            ProcessProc => \&Image::ExifTool::Exif::ProcessExif, # (because ProcessMOV is default)
            Start => 10,
            Base => '$start - 10',
            ByteOrder => 'LittleEndian',
        },
    },{
        Name => 'MakerNotePentaxUnknown',
        Binary => 1,
    }],
    # ---- Ricoh ----
    RICO => { #PH (G900SE)
        Name => 'RicohInfo',
        Condition => '$$valPt =~ /^\xff\xe1..Exif\0\0/s',
        SubDirectory => {
            TagTable => 'Image::ExifTool::JPEG::Main',
            ProcessProc => \&Image::ExifTool::ProcessJPEG,
        }
    },
    RTHU => { #PH (GR)
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        RawConv => '$self->ValidateImage(\$val, $tag)',
    },
    RMKN => { #PH (GR)
        Name => 'RicohRMKN',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF, # (because ProcessMOV is default)
        },
    },
    '@mak' => { Name => 'Make',     Avoid => 1 },
    '@mod' => { Name => 'Model',    Avoid => 1 },
    '@swr' => { Name => 'SoftwareVersion', Avoid => 1 },
    '@day' => {
        Name => 'ContentCreateDate',
        Notes => q{
            some stupid Ricoh programmer used the '@' symbol instead of the copyright
            symbol in these tag ID's for the Ricoh Theta Z1 and maybe other models
        },
        Groups => { 2 => 'Time' },
        Avoid => 1,
        # handle values in the form "2010-02-12T13:27:14-0800"
        %iso8601Date,
    },
    '@xyz' => { #PH (iPhone 3GS)
        Name => 'GPSCoordinates',
        Groups => { 2 => 'Location' },
        Avoid => 1,
        ValueConv => \&ConvertISO6709,
        ValueConvInv => \&ConvInvISO6709,
        PrintConv => \&PrintGPSCoordinates,
        PrintConvInv => \&PrintInvGPSCoordinates,
    },
    # RDT1 - pairs of int32u_BE, starting at byte 8: "458275 471846"
    # RDT2 - pairs of int32u_BE, starting at byte 8: "472276 468526"
    # RDT3 - pairs of int32u_BE, starting at byte 8: "876603 482191"
    # RDT4 - pairs of int32u_BE, starting at byte 8: "1955 484612"
    # RDT6 - empty
    # RDT7 - empty
    # RDT8 - empty
    # RDT9 - only 16-byte header?
    # the boxes below all have a similar header (little-endian):
    #  0 int32u - number of records
    #  4 int32u - sample rate (Hz)
    #  6 int16u - record length in bytes
    #  8 int16u - 0x0123 = little-endian, 0x3210 = big endian
    # 10 int16u[3] - all zeros
    # 16 - start of records (each record ends in an int64u timestamp "ts" in ns)
    RDTA => {
        Name => 'RicohRDTA',
        SubDirectory => { TagTable => 'Image::ExifTool::Ricoh::RDTA' },
    },
    RDTB => {
        Name => 'RicohRDTB',
        SubDirectory => { TagTable => 'Image::ExifTool::Ricoh::RDTB' },
    },
    RDTC => {
        Name => 'RicohRDTC',
        SubDirectory => { TagTable => 'Image::ExifTool::Ricoh::RDTC' },
    },
    # RDTD - int16s[3],ts: "353 -914 16354 0 775.829"
    RDTG => {
        Name => 'RicohRDTG',
        SubDirectory => { TagTable => 'Image::ExifTool::Ricoh::RDTG' },
    },
    # RDTI - float[4],ts: "0.00165951 0.005770059 0.06838259 0.1744695 775.862"
    RDTL => {
        Name => 'RicohRDTL',
        SubDirectory => { TagTable => 'Image::ExifTool::Ricoh::RDTL' },
    },
    # ---- Samsung ----
    vndr => 'Vendor', #PH (Samsung PL70)
    SDLN => 'PlayMode', #PH (NC, Samsung ST80 "SEQ_PLAY")
    INFO => {
        Name => 'SamsungINFO',
        SubDirectory => { TagTable => 'Image::ExifTool::Samsung::INFO' },
    },
   '@sec' => { #PH (Samsung WB30F)
        Name => 'SamsungSec',
        SubDirectory => { TagTable => 'Image::ExifTool::Samsung::sec' },
    },
    'smta' => { #PH (Samsung SM-C101)
        Name => 'SamsungSmta',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Samsung::smta',
            Start => 4,
        },
    },
    cver => 'CodeVersion', #PH (guess, Samsung MV900F)
    # ducp - 4 bytes all zero (Samsung ST96,WB750), 52 bytes all zero (Samsung WB30F)
    # edli - 52 bytes all zero (Samsung WB30F)
    # @etc - 4 bytes all zero (Samsung WB30F)
    # saut - 4 bytes all zero (Samsung SM-N900T)
    # smrd - string "TRUEBLUE" (Samsung SM-C101, etc)
    # ---- TomTom Bandit Action Cam ----
    TTMD => {
        Name => 'TomTomMetaData',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::TomTom' },
    },
    # ---- Samsung Gear 360 ----
    vrot => {
        Name => 'AccelerometerData',
        Notes => q{
            accelerometer readings for each frame of the video, expressed as sets of
            yaw, pitch and roll angles in degrees
        },
        Format => 'rational64s',
        ValueConv => '$val =~ s/^-?\d+ //; \$val', # (ignore leading version/size words)
    },
    # m360 - 8 bytes "0 0 0 0 0 0 0 1"
    # opax - 164 bytes unknown (center and affine arrays? ref 26)
    # opai - 32 bytes (maybe contains a serial number starting at byte 16? - PH) (rgb gains, degamma, gamma? ref 26)
    # intv - 16 bytes all zero
    # ---- Xiaomi ----
    mcvr => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
    # ---- Nextbase ----
    info => 'FirmwareVersion',
   'time' => {
        Name => 'TimeStamp',
        Format => 'int32u', # (followed by 4 unknown bytes 00 0d 00 00)
        Writable => 0,
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/ .*//; ConvertUnixTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    infi => {
        Name => 'CameraInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Nextbase' },
    },
    finm => {
        Name => 'OriginalFileName',
        Writable => 0,
    },
    # AMBA ? - (133 bytes)
    # nbpl ? - "FP-433-KC"
    nbpl => { Name => 'Unknown_nbpl', Unknown => 1, Hidden => 1 },
    # maca ? - b8 2d 28 15 f1 48
    # sern ? - 0d 69 42 74
    # nbid ? - 0d 69 42 74 65 df 72 65 03 de c0 fb 01 01 00 00
    # ---- Unknown ----
    # CDET - 128 bytes (unknown origin)
    # mtyp - 4 bytes all zero (some drone video)
    # kgrf - 8 bytes all zero ? (in udta inside trak atom)
    # kgcg - 128 bytes 0's and 1's
    # kgsi - 4 bytes "00 00 00 80"
    # FIEL - 18 bytes "FIEL\0\x01\0\0\0..."
#
# other 3rd-party tags
# (ref http://code.google.com/p/mp4parser/source/browse/trunk/isoparser/src/main/resources/isoparser-default.properties?r=814)
#
    ccid => 'ContentID',
    icnu => 'IconURI',
    infu => 'InfoURL',
    cdis => 'ContentDistributorID',
    albr => { Name => 'AlbumArtist', Groups => { 2 => 'Author' } },
    cvru => 'CoverURI',
    lrcu => 'LyricsURI',

    tags => {   # found in Audible .m4b audio books (ref PH)
        Name => 'Audible_tags',
        SubDirectory => { TagTable => 'Image::ExifTool::Audible::tags' },
    },
    # ludt - directory containing 'tlou' tag
);

# Unknown information stored in HTC One (M8) videos - PH
%Image::ExifTool::QuickTime::HTCBinary = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 1 => 'HTC', 2 => 'Video' },
    TAG_PREFIX => 'HTCBinary',
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    # 0 - values: 1
    # 1 - values: 0
    # 2 - values: 0
    # 3 - values: FileSize minus 12 (why?)
    # 4 - values: 12
);

# TomTom Bandit Action Cam metadata (ref PH)
%Image::ExifTool::QuickTime::TomTom = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    NOTES => 'Tags found in TomTom Bandit Action Cam MP4 videos.',
    TTAD => {
        Name => 'TomTomAD',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Stream',
            ProcessProc => \&Image::ExifTool::QuickTime::ProcessTTAD,
        },
    },
    TTHL => { Name => 'TomTomHL', Binary => 1, Unknown => 1 }, # (mostly zeros)
    # (TTID values are different for each video)
    TTID => { Name => 'TomTomID', ValueConv => 'unpack("x4H*",$val)' },
    TTVI => { Name => 'TomTomVI', Format => 'int32u', Unknown => 1 }, # seen: "0 1 61 508 508"
    # TTVD seen: "normal 720p 60fps 60fps 16/9 wide 1x"
    TTVD => { Name => 'TomTomVD', ValueConv => 'my @a = ($val =~ /[\x20-\x7e]+/g); "@a"', List => 1 },
);

# User-specific media data atoms (ref 11)
%Image::ExifTool::QuickTime::UserMedia = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    MTDT => {
        Name => 'MetaData',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::MetaData' },
    },
);

# User-specific media data atoms (ref 11)
%Image::ExifTool::QuickTime::MetaData = (
    PROCESS_PROC => \&ProcessMetaData,
    GROUPS => { 2 => 'Video' },
    TAG_PREFIX => 'MetaData',
    0x01 => 'Title',
    0x03 => {
        Name => 'ProductionDate',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        Writable => 1,
        Permanent => 1,
        DelValue => '0000/00/00 00:00:00',
        # translate from format "YYYY/mm/dd HH:MM:SS"
        ValueConv => '$val=~tr{/}{:}; $val',
        ValueConvInv => '$val=~s[^(\d{4}):(\d{2}):][$1/$2/]; $val',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    0x04 => 'Software',
    0x05 => 'Product',
    0x0a => {
        Name => 'TrackProperty',
        RawConv => 'my @a=unpack("Nnn",$val); "@a"',
        PrintConv => [
            { 0 => 'No presentation', BITMASK => { 0 => 'Main track' } },
            { 0 => 'No attributes',   BITMASK => { 15 => 'Read only' } },
            '"Priority $val"',
        ],
    },
    0x0b => {
        Name => 'TimeZone',
        Groups => { 2 => 'Time' },
        Writable => 1,
        Permanent => 1,
        DelValue => 0,
        RawConv => 'Get16s(\$val,0)',
        RawConvInv => 'Set16s($val)',
        PrintConv => 'TimeZoneString($val)',
        PrintConvInv => q{
            return undef unless $val =~ /^([-+])(\d{1,2}):?(\d{2})$/'
            my $tzmin = $2 * 60 + $3;
            $tzmin = -$tzmin if $1 eq '-';
            return $tzmin;
        }
    },
    0x0c => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        Writable => 1,
        Permanent => 1,
        DelValue => '0000/00/00 00:00:00',
        # translate from format "YYYY/mm/dd HH:MM:SS"
        ValueConv => '$val=~tr{/}{:}; $val',
        ValueConvInv => '$val=~s[^(\d{4}):(\d{2}):][$1/$2/]; $val',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
);

# compressed movie atoms (ref http://wiki.multimedia.cx/index.php?title=QuickTime_container#cmov)
%Image::ExifTool::QuickTime::CMovie = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    dcom => 'Compression',
    # cmvd - compressed moov atom data
);

# Profile atoms (ref 11)
%Image::ExifTool::QuickTime::Profile = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    FPRF => {
        Name => 'FileGlobalProfile',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::FileProf' },
    },
    APRF => {
        Name => 'AudioProfile',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::AudioProf' },
    },
    VPRF => {
        Name => 'VideoProfile',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::VideoProf' },
    },
    OLYM => { #PH
        Name => 'OlympusOLYM',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Olympus::OLYM',
            ByteOrder => 'BigEndian',
        },
    },
);

# FPRF atom information (ref 11)
%Image::ExifTool::QuickTime::FileProf = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    0 => { Name => 'FileProfileVersion', Unknown => 1 }, # unknown = uninteresting
    1 => {
        Name => 'FileFunctionFlags',
        PrintConv => { BITMASK => {
            28 => 'Fragmented',
            29 => 'Additional tracks',
            30 => 'Edited', # (main AV track is edited)
        }},
    },
    # 2 - reserved
);

# APRF atom information (ref 11)
%Image::ExifTool::QuickTime::AudioProf = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Audio' },
    FORMAT => 'int32u',
    0 => { Name => 'AudioProfileVersion', Unknown => 1 },
    1 => 'AudioTrackID',
    2 => {
        Name => 'AudioCodec',
        Format => 'undef[4]',
    },
    3 => {
        Name => 'AudioCodecInfo',
        Unknown => 1,
        PrintConv => 'sprintf("0x%.4x", $val)',
    },
    4 => {
        Name => 'AudioAttributes',
        PrintConv => { BITMASK => {
            0 => 'Encrypted',
            1 => 'Variable bitrate',
            2 => 'Dual mono',
        }},
    },
    5 => {
        Name => 'AudioAvgBitrate',
        ValueConv => '$val * 1000',
        PrintConv => 'ConvertBitrate($val)',
    },
    6 => {
        Name => 'AudioMaxBitrate',
        ValueConv => '$val * 1000',
        PrintConv => 'ConvertBitrate($val)',
    },
    7 => 'AudioSampleRate',
    8 => 'AudioChannels',
);

# VPRF atom information (ref 11)
%Image::ExifTool::QuickTime::VideoProf = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    0 => { Name => 'VideoProfileVersion', Unknown => 1 },
    1 => 'VideoTrackID',
    2 => {
        Name => 'VideoCodec',
        Format => 'undef[4]',
    },
    3 => {
        Name => 'VideoCodecInfo',
        Unknown => 1,
        PrintConv => 'sprintf("0x%.4x", $val)',
    },
    4 => {
        Name => 'VideoAttributes',
        PrintConv => { BITMASK => {
            0 => 'Encrypted',
            1 => 'Variable bitrate',
            2 => 'Variable frame rate',
            3 => 'Interlaced',
        }},
    },
    5 => {
        Name => 'VideoAvgBitrate',
        ValueConv => '$val * 1000',
        PrintConv => 'ConvertBitrate($val)',
    },
    6 => {
        Name => 'VideoMaxBitrate',
        ValueConv => '$val * 1000',
        PrintConv => 'ConvertBitrate($val)',
    },
    7 => {
        Name => 'VideoAvgFrameRate',
        Format => 'fixed32u',
        PrintConv => 'int($val * 1000 + 0.5) / 1000',
    },
    8 => {
        Name => 'VideoMaxFrameRate',
        Format => 'fixed32u',
        PrintConv => 'int($val * 1000 + 0.5) / 1000',
    },
    9 => {
        Name => 'VideoSize',
        Format => 'int16u[2]',
        PrintConv => '$val=~tr/ /x/; $val',
    },
    10 => {
        Name => 'PixelAspectRatio',
        Format => 'int16u[2]',
        PrintConv => '$val=~tr/ /:/; $val',
    },
);

# meta atoms
%Image::ExifTool::QuickTime::Meta = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 1 => 'Meta', 2 => 'Video' },
    ilst => {
        Name => 'ItemList',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::ItemList',
            HasData => 1, # process atoms as containers with 'data' elements
        },
    },
    # MP4 tags (ref 5)
    hdlr => {
        Name => 'Handler',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Handler' },
    },
    dinf => {
        Name => 'DataInfo', # (don't change this name -- used to recognize directory when writing)
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::DataInfo' },
    },
    ipmc => {
        Name => 'IPMPControl',
        Flags => ['Binary','Unknown'],
    },
    iloc => {
        Name => 'ItemLocation',
        RawConv => \&ParseItemLocation,
        WriteHook => \&ParseItemLocation,
        Notes => 'parsed, but not extracted as a tag',
    },
    ipro => {
        Name => 'ItemProtection',
        Flags => ['Binary','Unknown'],
    },
    iinf => [{
        Name => 'ItemInformation',
        Condition => '$$self{LastItemID} = -1; $$valPt =~ /^\0/', # (check for version 0)
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::ItemInfo',
            Start => 6, # (4-byte version/flags + 2-byte count)
        },
    },{
        Name => 'ItemInformation',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::ItemInfo',
            Start => 8, # (4-byte version/flags + 4-byte count)
        },
    }],
   'xml ' => {
        Name => 'XML',
        Flags => [ 'Binary', 'Protected' ],
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::XML',
            IgnoreProp => { NonRealTimeMeta => 1 }, # ignore container for Sony 'nrtm'
        },
    },
   'keys' => [{
        Name => 'AudioKeys',
        Condition => '$$self{MediaType} eq "soun"',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::AudioKeys' },
    },{
        Name => 'VideoKeys',
        Condition => '$$self{MediaType} eq "vide"',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::VideoKeys' },
    },{
        Name => 'Keys',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Keys' },
    }],
    bxml => {
        Name => 'BinaryXML',
        Flags => ['Binary','Unknown'],
    },
    pitm => [{
        Name => 'PrimaryItemReference',
        Condition => '$$valPt =~ /^\0/', # (version 0?)
        RawConv => '$$self{PrimaryItem} = unpack("x4n",$val)',
        WriteHook => sub { my ($val,$et) = @_; $$et{PrimaryItem} = unpack("x4n",$val); },
    },{
        Name => 'PrimaryItemReference',
        RawConv => '$$self{PrimaryItem} = unpack("x4N",$val)',
        WriteHook => sub { my ($val,$et) = @_; $$et{PrimaryItem} = unpack("x4N",$val); },
    }],
    free => { #PH
        Name => 'Free',
        Flags => ['Binary','Unknown'],
    },
    iprp => {
        Name => 'ItemProperties',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::ItemProp' },
    },
    iref => {
        Name => 'ItemReference',
        # the version is needed to parse some of the item references
        Condition => '$$self{ItemRefVersion} = ord($$valPt); 1',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::ItemRef',
            Start => 4,
        },
    },
    idat => {
        Name => 'MetaImageSize', #PH (NC)
        Format => 'int16u',
        # (don't know what the first two numbers are for)
        PrintConv => '$val =~ s/^(\d+) (\d+) (\d+) (\d+)/${3}x$4/; $val',
    },
    uuid => [
        { #PH (Canon R5/R6 HIF)
            Name => 'MetaVersion', # (NC)
            Condition => '$$valPt=~/^\x85\xc0\xb6\x87\x82\x0f\x11\xe0\x81\x11\xf4\xce\x46\x2b\x6a\x48/',
            RawConv => 'substr($val, 0x14)',
        },
        {
            Name => 'UUID-Unknown',
            %unknownInfo,
        },
    ],
    grpl => {
        Name => 'Unknown_grpl',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::grpl' },
    },
);

# unknown grpl container
%Image::ExifTool::QuickTime::grpl = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    # altr - seen "00 00 00 00 00 00 00 41 00 00 00 02 00 00 00 42 00 00 00 2e"
);

# additional metadata container (ref ISO14496-12:2015)
%Image::ExifTool::QuickTime::OtherMeta = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 2 => 'Video' },
    mere => {
        Name => 'MetaRelation',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::MetaRelation' },
    },
    meta => {
        Name => 'Meta',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Meta' },
    },
);

# metabox relation (ref ISO14496-12:2015)
%Image::ExifTool::QuickTime::MetaRelation = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FORMAT => 'int32u',
    # 0 => 'MetaRelationVersion',
    # 1 => 'FirstMetaboxHandlerType',
    # 2 => 'FirstMetaboxHandlerType',
    # 3 => { Name => 'MetaboxRelation', Format => 'int8u' },
);

%Image::ExifTool::QuickTime::ItemProp = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 2 => 'Image' },
    ipco => {
        Name => 'ItemPropertyContainer',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::ItemPropCont' },
    },
    ipma => {
        Name => 'ItemPropertyAssociation',
        RawConv => \&ParseItemPropAssoc,
        WriteHook => \&ParseItemPropAssoc,
        Notes => 'parsed, but not extracted as a tag',
    },
);

%Image::ExifTool::QuickTime::ItemPropCont = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    PERMANENT => 1, # (can't be deleted)
    GROUPS => { 2 => 'Image' },
    VARS => { START_INDEX => 1 },   # show verbose indices starting at 1
    colr => [{
        Name => 'ICC_Profile',
        Condition => '$$valPt =~ /^(prof|rICC)/',
        Permanent => 0, # (in QuickTime, this writes a zero-length box instead of deleting)
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
            Start => 4,
        },
    },{
        Name => 'ColorRepresentation',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::ColorRep' },
    }],
    irot => {
        Name => 'Rotation',
        Format => 'int8u',
        Writable => 'int8u',
        Protected => 1,
        PrintConv => {
            0 => 'Horizontal (Normal)',
            1 => 'Rotate 270 CW',
            2 => 'Rotate 180',
            3 => 'Rotate 90 CW',
        },
    },
    ispe => {
        Name => 'ImageSpatialExtent',
        Condition => '$$valPt =~ /^\0{4}/',     # (version/flags == 0/0)
        RawConv => q{
            my @dim = unpack("x4N*", $val);
            return undef if @dim < 2;
            unless ($$self{DOC_NUM}) {
                $self->FoundTag(ImageWidth => $dim[0]);
                $self->FoundTag(ImageHeight => $dim[1]);
            }
            return join ' ', @dim;
        },
        PrintConv => '$val =~ tr/ /x/; $val',
    },
    pixi => {
        Name => 'ImagePixelDepth',
        Condition => '$$valPt =~ /^\0{4}./s',   # (version/flags == 0/0 and count)
        RawConv => 'join " ", unpack("x5C*", $val)',
    },
    auxC => {
        Name => 'AuxiliaryImageType',
        Format => 'undef',
        RawConv => '$val = substr($val, 4); $val =~ s/\0.*//s; $val',
    },
    pasp => {
        Name => 'PixelAspectRatio',
        Format => 'int32u',
        Writable => 'int32u',
        Protected => 1,
    },
    rloc => {
        Name => 'RelativeLocation',
        Format => 'int32u',
        RawConv => '$val =~ s/^\S+\s+//; $val', # remove version/flags
    },
    clap => {
        Name => 'CleanAperture',
        Format => 'rational64s',
        Notes => '4 numbers: width, height, left and top',
    },
    hvcC => {
        Name => 'HEVCConfiguration',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::HEVCConfig' },
    },
    av1C => {
        Name => 'AV1Configuration',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::AV1Config' },
    },
    clli => {
        Name => 'ContentLightLevel',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::ContentLightLevel' },
    },
    # ref https://nokiatech.github.io/heif/technical.html
    # cclv - Content Color Volume
    # mdcv - Mastering Display Color Volume
    # rrtp - Required reference types
    # crtt - Creation time information
    # mdft - Modification time information
    # udes - User description
    # altt - Accessibility text
    # aebr - Auto exposure information
    # wbbr - White balance information
    # fobr - Focus information
    # afbr - Flash exposure information
    # dobr - Depth of field information
    # pano - Panorama information
    # iscl - Image Scaling
);

# ref https://aomediacodec.github.io/av1-spec/av1-spec.pdf
# (NOTE: conversions are the same as Image::ExifTool::ICC_Profile::ColorRep tags)
%Image::ExifTool::QuickTime::ColorRep = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FIRST_ENTRY => 0,
    0 => { Name => 'ColorProfiles', Format => 'undef[4]' },
    4 => {
        Name => 'ColorPrimaries',
        Format => 'int16u',
        PrintConv => {
            1 => 'BT.709',
            2 => 'Unspecified',
            4 => 'BT.470 System M (historical)',
            5 => 'BT.470 System B, G (historical)',
            6 => 'BT.601',
            7 => 'SMPTE 240',
            8 => 'Generic film (color filters using illuminant C)',
            9 => 'BT.2020, BT.2100',
            10 => 'SMPTE 428 (CIE 1931 XYZ)', #forum14766
            11 => 'SMPTE RP 431-2',
            12 => 'SMPTE EG 432-1',
            22 => 'EBU Tech. 3213-E',
        },
    },
    6 => {
        Name => 'TransferCharacteristics',
        Format => 'int16u',
        PrintConv => {
            0 => 'For future use (0)',
            1 => 'BT.709',
            2 => 'Unspecified',
            3 => 'For future use (3)',
            4 => 'BT.470 System M (historical)',    # Gamma 2.2? (ref forum14960)
            5 => 'BT.470 System B, G (historical)', # Gamma 2.8? (ref forum14960)
            6 => 'BT.601',
            7 => 'SMPTE 240 M',
            8 => 'Linear',
            9 => 'Logarithmic (100 : 1 range)',
            10 => 'Logarithmic (100 * Sqrt(10) : 1 range)',
            11 => 'IEC 61966-2-4',
            12 => 'BT.1361',
            13 => 'sRGB or sYCC',
            14 => 'BT.2020 10-bit systems',
            15 => 'BT.2020 12-bit systems',
            16 => 'SMPTE ST 2084, ITU BT.2100 PQ',
            17 => 'SMPTE ST 428',
            18 => 'BT.2100 HLG, ARIB STD-B67',
        },
    },
    8 => {
        Name => 'MatrixCoefficients',
        Format => 'int16u',
        PrintConv => {
            0 => 'Identity matrix',
            1 => 'BT.709',
            2 => 'Unspecified',
            3 => 'For future use (3)',
            4 => 'US FCC 73.628',
            5 => 'BT.470 System B, G (historical)',
            6 => 'BT.601',
            7 => 'SMPTE 240 M',
            8 => 'YCgCo',
            9 => 'BT.2020 non-constant luminance, BT.2100 YCbCr',
            10 => 'BT.2020 constant luminance',
            11 => 'SMPTE ST 2085 YDzDx',
            12 => 'Chromaticity-derived non-constant luminance',
            13 => 'Chromaticity-derived constant luminance',
            14 => 'BT.2100 ICtCp',
        },
    },
    10 => {
        Name => 'VideoFullRangeFlag',
        Mask => 0x80,
        PrintConv => { 0 => 'Limited', 1 => 'Full' },
    },
);

# HEVC configuration (ref https://github.com/MPEGGroup/isobmff/blob/master/IsoLib/libisomediafile/src/HEVCConfigAtom.c)
%Image::ExifTool::QuickTime::HEVCConfig = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FIRST_ENTRY => 0,
    0 => 'HEVCConfigurationVersion',
    1 => {
        Name => 'GeneralProfileSpace',
        Mask => 0xc0,
        PrintConv => { 0 => 'Conforming' },
    },
    1.1 => {
        Name => 'GeneralTierFlag',
        Mask => 0x20,
        PrintConv => {
            0 => 'Main Tier',
            1 => 'High Tier',
        },
    },
    1.2 => {
        Name => 'GeneralProfileIDC',
        Mask => 0x1f,
        PrintConv => {
            0 => 'No Profile',
            1 => 'Main',
            2 => 'Main 10',
            3 => 'Main Still Picture',
            4 => 'Format Range Extensions',
            5 => 'High Throughput',
            6 => 'Multiview Main',
            7 => 'Scalable Main',
            8 => '3D Main',
            9 => 'Screen Content Coding Extensions',
            10 => 'Scalable Format Range Extensions',
            11 => 'High Throughput Screen Content Coding Extensions',
        },
    },
    2 => {
        Name => 'GenProfileCompatibilityFlags',
        Format => 'int32u',
        PrintConv => { BITMASK => {
            31 => 'No Profile',             # (bit 0 in stream)
            30 => 'Main',                   # (bit 1 in stream)
            29 => 'Main 10',                # (bit 2 in stream)
            28 => 'Main Still Picture',     # (bit 3 in stream)
            27 => 'Format Range Extensions',# (...)
            26 => 'High Throughput',
            25 => 'Multiview Main',
            24 => 'Scalable Main',
            23 => '3D Main',
            22 => 'Screen Content Coding Extensions',
            21 => 'Scalable Format Range Extensions',
            20 => 'High Throughput Screen Content Coding Extensions',
        }},
    },
    6 => {
        Name => 'ConstraintIndicatorFlags',
        Format => 'int8u[6]',
    },
    12 => {
        Name => 'GeneralLevelIDC',
        PrintConv => 'sprintf("%d (level %.1f)", $val, $val/30)',
    },
    13 => {
        Name => 'MinSpatialSegmentationIDC',
        Format => 'int16u',
        Mask => 0x0fff,
    },
    15 => {
        Name => 'ParallelismType',
        Mask => 0x03,
    },
    16 => {
        Name => 'ChromaFormat',
        Mask => 0x03,
        PrintConv => {
            0 => 'Monochrome',
            1 => '4:2:0',
            2 => '4:2:2',
            3 => '4:4:4',
        },
    },
    17 => {
        Name => 'BitDepthLuma',
        Mask => 0x07,
        ValueConv => '$val + 8',
    },
    18 => {
        Name => 'BitDepthChroma',
        Mask => 0x07,
        ValueConv => '$val + 8',
    },
    19 => {
        Name => 'AverageFrameRate',
        Format => 'int16u',
        ValueConv => '$val / 256',
    },
    21 => {
        Name => 'ConstantFrameRate',
        Mask => 0xc0,
        PrintConv => {
            0 => 'Unknown',
            1 => 'Constant Frame Rate',
            2 => 'Each Temporal Layer is Constant Frame Rate',
        },
    },
    21.1 => {
        Name => 'NumTemporalLayers',
        Mask => 0x38,
    },
    21.2 => {
        Name => 'TemporalIDNested',
        Mask => 0x04,
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    #21.3 => {
    #    Name => 'NALUnitLengthSize',
    #    Mask => 0x03,
    #    ValueConv => '$val + 1',
    #    PrintConv => { 1 => '8-bit', 2 => '16-bit', 4 => '32-bit' },
    #},
    #22 => 'NumberOfNALUnitArrays',
    # (don't decode the NAL unit arrays)
);

# HEVC configuration (ref https://aomediacodec.github.io/av1-isobmff/#av1codecconfigurationbox)
%Image::ExifTool::QuickTime::AV1Config = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FIRST_ENTRY => 0,
    0 => {
        Name => 'AV1ConfigurationVersion',
        Mask => 0x7f,
    },
    1.0 => {
        Name => 'SeqProfile',
        Mask => 0xe0,
        Unknown => 1,
    },
    1.1 => {
        Name => 'SeqLevelIdx0',
        Mask => 0x1f,
        Unknown => 1,
    },
    2.0 => {
        Name => 'SeqTier0',
        Mask => 0x80,
        Unknown => 1,
    },
    2.1 => {
        Name => 'HighBitDepth',
        Mask => 0x40,
        Unknown => 1,
    },
    2.2 => {
        Name => 'TwelveBit',
        Mask => 0x20,
        Unknown => 1,
    },
    2.3 => {
        Name => 'ChromaFormat', # (Monochrome+SubSamplingX+SubSamplingY)
        Notes => 'bits: 0x04 = Monochrome, 0x02 = SubSamplingX, 0x01 = SubSamplingY',
        Mask => 0x1c,
        PrintConv => {
            0x00 => 'YUV 4:4:4',
            0x02 => 'YUV 4:2:2',
            0x03 => 'YUV 4:2:0',
            0x07 => 'Monochrome 4:0:0',
        },
    },
    2.4 => {
        Name => 'ChromaSamplePosition',
        Mask => 0x03,
        PrintConv => {
            0 => 'Unknown',
            1 => 'Vertical',
            2 => 'Colocated',
            3 => '(reserved)',
        },
    },
    3 => {
        Name => 'InitialDelaySamples',
        RawConv => '$val & 0x10 ? undef : ($val & 0x0f) + 1',
        Unknown => 1,
    },
);

# ref https://android.googlesource.com/platform/frameworks/av/+/master/media/libstagefright/MPEG4Writer.cpp
%Image::ExifTool::QuickTime::ContentLightLevel = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    FIRST_ENTRY => 0,
    FORMAT => 'int16u',
    0 => 'MaxContentLightLevel',
    1 => 'MaxPicAverageLightLevel',
);

%Image::ExifTool::QuickTime::ItemRef = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 2 => 'Image' },
    # (Note: ExifTool's ItemRefVersion may be used to test the iref version number)
    NOTES => q{
        The Item reference entries listed in the table below contain information about
        the associations between items in the file.  This information is used by
        ExifTool, but these entries are not extracted as tags.
    },
    dimg => {
        Name => 'DerivedImageRef',
        # also parse these for the ID of the primary 'tmap' item
        # (tone-mapped image in HDRGainMap HEIC by iPhone 15 and 16)
        RawConv => \&ParseContentDescribes,
        WriteHook => \&ParseContentDescribes,
    },
    thmb => { Name => 'ThumbnailRef',      RawConv => 'undef' },
    auxl => { Name => 'AuxiliaryImageRef', RawConv => 'undef' },
    cdsc => {
        Name => 'ContentDescribes',
        RawConv => \&ParseContentDescribes,
        WriteHook => \&ParseContentDescribes,
    },
);

%Image::ExifTool::QuickTime::ItemInfo = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 2 => 'Image' },
    # avc1 - AVC image
    # hvc1 - HEVC image
    # lhv1 - L-HEVC image
    # infe - ItemInformationEntry
    # infe types: avc1,hvc1,lhv1,Exif,xml1,iovl(overlay image),grid,mime,tmap,hvt1(tile image)
    # ('tmap' has something to do with the new gainmap written by iPhone 15 and 16)
    infe => {
        Name => 'ItemInfoEntry',
        RawConv => \&ParseItemInfoEntry,
        WriteHook => \&ParseItemInfoEntry,
        Notes => 'parsed, but not extracted as a tag',
    },
);

# track reference atoms
%Image::ExifTool::QuickTime::TrackRef = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 1 => 'Track#', 2 => 'Video' },
    chap => { Name => 'ChapterListTrackID', Format => 'int32u' },
    tmcd => { Name => 'TimeCode', Format => 'int32u' },
    mpod => { #PH (FLIR MP4)
        Name => 'ElementaryStreamTrack',
        Format => 'int32u',
        ValueConv => '$val =~ s/^1 //; $val',  # (why 2 numbers? -- ignore the first if "1")
    },
    # also: sync, scpt, ssrc, iTunesInfo
    cdsc => {
        Name => 'ContentDescribes',
        Format => 'int32u',
        PrintConv => '"Track $val"',
    },
    # cdep (Structural Dependency QT tag?)
    # fall - ? int32u, seen: 2
);

# track aperture mode dimensions atoms
# (ref https://developer.apple.com/library/mac/#documentation/QuickTime/QTFF/QTFFChap2/qtff2.html)
%Image::ExifTool::QuickTime::TrackAperture = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 1 => 'Track#', 2 => 'Video' },
    clef => {
        Name => 'CleanApertureDimensions',
        Format => 'fixed32u',
        Count => 3,
        ValueConv => '$val =~ s/^.*? //; $val', # remove flags word
        PrintConv => '$val =~ tr/ /x/; $val',
    },
    prof => {
        Name => 'ProductionApertureDimensions',
        Format => 'fixed32u',
        Count => 3,
        ValueConv => '$val =~ s/^.*? //; $val',
        PrintConv => '$val =~ tr/ /x/; $val',
    },
    enof => {
        Name => 'EncodedPixelsDimensions',
        Format => 'fixed32u',
        Count => 3,
        ValueConv => '$val =~ s/^.*? //; $val',
        PrintConv => '$val =~ tr/ /x/; $val',
    },
);

# item list atoms
# -> these atoms are unique, and contain one or more 'data' atoms
%Image::ExifTool::QuickTime::ItemList = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    CHECK_PROC => \&CheckQTValue,
    WRITABLE => 1,
    PREFERRED => 2, # (preferred over UserData and Keys tags when writing)
    FORMAT => 'string',
    GROUPS => { 1 => 'ItemList', 2 => 'Audio' },
    WRITE_GROUP => 'ItemList',
    LANG_INFO => \&GetLangInfo,
    NOTES => q{
        This is the preferred location for creating new QuickTime tags.  Tags in
        this table support alternate languages which are accessed by adding a
        3-character ISO 639-2 language code and an optional ISO 3166-1 alpha 2
        country code to the tag name (eg. "ItemList:Title-fra" or
        "ItemList::Title-fra-FR").  When creating a new Meta box to contain the
        ItemList directory, by default ExifTool adds an 'mdir' (Metadata) Handler
        box because Apple software may ignore ItemList tags otherwise, but the API
        L<QuickTimeHandler|../ExifTool.html#QuickTimeHandler> option may be set to 0 to avoid this.
    },
    # in this table, binary 1 and 2-byte "data"-type tags are interpreted as
    # int8u and int16u.  Multi-byte binary "data" tags are extracted as binary data.
    # (Note that the Preferred property is set to 0 for some tags to prevent them
    #  from being created when a same-named tag already exists in the table)
    "\xa9ART" => 'Artist',
    "\xa9alb" => 'Album',
    "\xa9aut" => { Name => 'Author', Avoid => 1, Groups => { 2 => 'Author' } }, #forum10091 ('auth' is preferred)
    "\xa9cmt" => 'Comment',
    "\xa9com" => { Name => 'Composer', Avoid => 1, }, # ("\xa9wrt" is preferred in ItemList)
    "\xa9day" => {
        Name => 'ContentCreateDate',
        Groups => { 2 => 'Time' },
        %iso8601Date,
    },
    "\xa9des" => 'Description', #4
    "\xa9enc" => 'EncodedBy', #10
    "\xa9gen" => 'Genre',
    "\xa9grp" => 'Grouping',
    "\xa9lyr" => 'Lyrics',
    "\xa9nam" => 'Title',
    "\xa9too" => 'Encoder',
    "\xa9trk" => 'Track',
    "\xa9wrt" => 'Composer',
#
# the following tags written by AtomicParsley 0.9.6
# (ref https://exiftool.org/forum/index.php?topic=11455.0)
#
    "\xa9st3" => 'Subtitle',
    "\xa9con" => 'Conductor',
    "\xa9sol" => 'Soloist',
    "\xa9arg" => 'Arranger',
    "\xa9ope" => 'OriginalArtist',
    "\xa9dir" => 'Director',
    "\xa9ard" => 'ArtDirector',
    "\xa9sne" => 'SoundEngineer',
    "\xa9prd" => 'Producer',
    "\xa9xpd" => 'ExecutiveProducer',
    sdes      => 'StoreDescription',
#
    '----' => {
        Name => 'iTunesInfo',
        Deletable => 1, # (deletable via 'iTunes' group)
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::iTunesInfo',
            DirName => 'iTunes', # (necessary for group 'iTunes' delete)
        },
    },
    aART => { Name => 'AlbumArtist', Groups => { 2 => 'Author' } },
    covr => { Name => 'CoverArt',    Groups => { 2 => 'Preview' }, Binary => 1 },
    cpil => { #10
        Name => 'Compilation',
        Format => 'int8u', #27 (ref 23 contradicts what AtomicParsley actually writes, which is int8s)
        Writable => 'int8s',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    disk => {
        Name => 'DiskNumber',
        Format => 'undef',  # (necessary to prevent decoding as string!)
        ValueConv => q{
            return \$val unless length($val) >= 6;
            my @a = unpack 'x2nn', $val;
            return $a[1] ? join(' of ', @a) : $a[0];
        },
        ValueConvInv => q{
            my @a = $val =~ /\d+/g;
            return undef if @a == 0 or @a > 2;
            push @a, 0 if @a == 1;
            return pack('n3', 0, @a);
        },
    },
    pgap => { #10
        Name => 'PlayGap',
        Format => 'int8u', #23
        Writable => 'int8s', #27
        PrintConv => {
            0 => 'Insert Gap',
            1 => 'No Gap',
        },
    },
    tmpo => {
        Name => 'BeatsPerMinute',
        # marked as boolean but really int16u in my sample
        # (but written as int16s by iTunes and AtomicParsley, ref forum11506)
        Format => 'int16u',
        Writable => 'int16s',
    },
    trkn => {
        Name => 'TrackNumber',
        Format => 'undef',  # (necessary to prevent decoding as string!)
        ValueConv => q{
            return \$val unless length($val) >= 6;
            my @a = unpack 'x2nn', $val;
            return $a[1] ? join(' of ', @a) : $a[0];
        },
        # (see forum11501 for discussion about the format used)
        ValueConvInv => q{
            my @a = $val =~ /\d+/g;
            return undef if @a == 0 or @a > 2;
            push @a, 0 if @a == 1;
            return pack('n4', 0, @a, 0);
        },
    },
#
# Note: it is possible that the tags below are not being decoded properly
# because I don't have samples to verify many of these - PH
#
    akID => { #10
        Name => 'AppleStoreAccountType',
        Format => 'int8u', #24
        Writable => 'int8s', #27
        PrintConv => {
            0 => 'iTunes',
            1 => 'AOL',
        },
    },
    albm => { Name => 'Album', Avoid => 1 }, #(ffmpeg source)
    apID => 'AppleStoreAccount',
    atID => {
        # (ref 10 called this AlbumTitleID or TVSeries)
        Name => 'ArtistID', #28 (or Track ID ref https://gist.github.com/maf654321/2b44c7b15d798f0c52ee)
        Format => 'int32u',
        Writable => 'int32s', #27
    },
    auth => { Name => 'Author', Groups => { 2 => 'Author' } },
    catg => 'Category', #7
    cnID => { #10
        Name => 'AppleStoreCatalogID',
        Format => 'int32u',
        Writable => 'int32s', #27
    },
    cmID => 'ComposerID', #28 (need sample to get format)
    cprt => { Name => 'Copyright', Groups => { 2 => 'Author' } },
    dscp => { Name => 'Description', Avoid => 1 },
    desc => { Name => 'Description', Avoid => 1 }, #7
    gnre => { #10
        Name => 'Genre',
        Avoid => 1,
        # (Note: see https://exiftool.org/forum/index.php?topic=11537.0)
        Format => 'undef',
        ValueConv => 'unpack("n",$val)',
        ValueConvInv => '$val =~ /^\d+$/ ? pack("n",$val) : undef',
        PrintConv => q{
            return $val unless $val =~ /^\d+$/;
            require Image::ExifTool::ID3;
            Image::ExifTool::ID3::PrintGenre($val - 1); # note the "- 1"
        },
        PrintConvInv => q{
            return $val if $val =~ /^[0-9]+$/;
            require Image::ExifTool::ID3;
            my $id = Image::ExifTool::ID3::GetGenreID($val);
            return unless defined $id and $id =~ /^\d+$/;
            return $id + 1;
        },
    },
    egid => 'EpisodeGlobalUniqueID', #7
    geID => { #10
        Name => 'GenreID',
        Format => 'int32u',
        Writable => 'int32s', #27
        SeparateTable => 1,
        # the following lookup is based on http://itunes.apple.com/WebObjects/MZStoreServices.woa/ws/genres
        # (see scripts/parse_genre to parse genre JSON file from above)
        PrintConv => { #21/PH
            2 => 'Music|Blues',
            3 => 'Music|Comedy',
            4 => "Music|Children's Music",
            5 => 'Music|Classical',
            6 => 'Music|Country',
            7 => 'Music|Electronic',
            8 => 'Music|Holiday',
            9 => 'Music|Classical|Opera',
            10 => 'Music|Singer/Songwriter',
            11 => 'Music|Jazz',
            12 => 'Music|Latino',
            13 => 'Music|New Age',
            14 => 'Music|Pop',
            15 => 'Music|R&B/Soul',
            16 => 'Music|Soundtrack',
            17 => 'Music|Dance',
            18 => 'Music|Hip-Hop/Rap',
            19 => 'Music|World',
            20 => 'Music|Alternative',
            21 => 'Music|Rock',
            22 => 'Music|Christian & Gospel',
            23 => 'Music|Vocal',
            24 => 'Music|Reggae',
            25 => 'Music|Easy Listening',
            26 => 'Podcasts',
            27 => 'Music|J-Pop',
            28 => 'Music|Enka',
            29 => 'Music|Anime',
            30 => 'Music|Kayokyoku',
            31 => 'Music Videos',
            32 => 'TV Shows',
            33 => 'Movies',
            34 => 'Music',
            35 => 'iPod Games',
            36 => 'App Store',
            37 => 'Tones',
            38 => 'Books',
            39 => 'Mac App Store',
            40 => 'Textbooks',
            50 => 'Music|Fitness & Workout',
            51 => 'Music|Pop|K-Pop',
            52 => 'Music|Karaoke',
            53 => 'Music|Instrumental',
            74 => 'Audiobooks|News',
            75 => 'Audiobooks|Programs & Performances',
            500 => 'Fitness Music',
            501 => 'Fitness Music|Pop',
            502 => 'Fitness Music|Dance',
            503 => 'Fitness Music|Hip-Hop',
            504 => 'Fitness Music|Rock',
            505 => 'Fitness Music|Alt/Indie',
            506 => 'Fitness Music|Latino',
            507 => 'Fitness Music|Country',
            508 => 'Fitness Music|World',
            509 => 'Fitness Music|New Age',
            510 => 'Fitness Music|Classical',
            1001 => 'Music|Alternative|College Rock',
            1002 => 'Music|Alternative|Goth Rock',
            1003 => 'Music|Alternative|Grunge',
            1004 => 'Music|Alternative|Indie Rock',
            1005 => 'Music|Alternative|New Wave',
            1006 => 'Music|Alternative|Punk',
            1007 => 'Music|Blues|Chicago Blues',
            1009 => 'Music|Blues|Classic Blues',
            1010 => 'Music|Blues|Contemporary Blues',
            1011 => 'Music|Blues|Country Blues',
            1012 => 'Music|Blues|Delta Blues',
            1013 => 'Music|Blues|Electric Blues',
            1014 => "Music|Children's Music|Lullabies",
            1015 => "Music|Children's Music|Sing-Along",
            1016 => "Music|Children's Music|Stories",
            1017 => 'Music|Classical|Avant-Garde',
            1018 => 'Music|Classical|Baroque Era',
            1019 => 'Music|Classical|Chamber Music',
            1020 => 'Music|Classical|Chant',
            1021 => 'Music|Classical|Choral',
            1022 => 'Music|Classical|Classical Crossover',
            1023 => 'Music|Classical|Early Music',
            1024 => 'Music|Classical|Impressionist',
            1025 => 'Music|Classical|Medieval Era',
            1026 => 'Music|Classical|Minimalism',
            1027 => 'Music|Classical|Modern Era',
            1028 => 'Music|Classical|Opera',
            1029 => 'Music|Classical|Orchestral',
            1030 => 'Music|Classical|Renaissance',
            1031 => 'Music|Classical|Romantic Era',
            1032 => 'Music|Classical|Wedding Music',
            1033 => 'Music|Country|Alternative Country',
            1034 => 'Music|Country|Americana',
            1035 => 'Music|Country|Bluegrass',
            1036 => 'Music|Country|Contemporary Bluegrass',
            1037 => 'Music|Country|Contemporary Country',
            1038 => 'Music|Country|Country Gospel',
            1039 => 'Music|Country|Honky Tonk',
            1040 => 'Music|Country|Outlaw Country',
            1041 => 'Music|Country|Traditional Bluegrass',
            1042 => 'Music|Country|Traditional Country',
            1043 => 'Music|Country|Urban Cowboy',
            1044 => 'Music|Dance|Breakbeat',
            1045 => 'Music|Dance|Exercise',
            1046 => 'Music|Dance|Garage',
            1047 => 'Music|Dance|Hardcore',
            1048 => 'Music|Dance|House',
            1049 => "Music|Dance|Jungle/Drum'n'bass",
            1050 => 'Music|Dance|Techno',
            1051 => 'Music|Dance|Trance',
            1052 => 'Music|Jazz|Big Band',
            1053 => 'Music|Jazz|Bop',
            1054 => 'Music|Easy Listening|Lounge',
            1055 => 'Music|Easy Listening|Swing',
            1056 => 'Music|Electronic|Ambient',
            1057 => 'Music|Electronic|Downtempo',
            1058 => 'Music|Electronic|Electronica',
            1060 => 'Music|Electronic|IDM/Experimental',
            1061 => 'Music|Electronic|Industrial',
            1062 => 'Music|Singer/Songwriter|Alternative Folk',
            1063 => 'Music|Singer/Songwriter|Contemporary Folk',
            1064 => 'Music|Singer/Songwriter|Contemporary Singer/Songwriter',
            1065 => 'Music|Singer/Songwriter|Folk-Rock',
            1066 => 'Music|Singer/Songwriter|New Acoustic',
            1067 => 'Music|Singer/Songwriter|Traditional Folk',
            1068 => 'Music|Hip-Hop/Rap|Alternative Rap',
            1069 => 'Music|Hip-Hop/Rap|Dirty South',
            1070 => 'Music|Hip-Hop/Rap|East Coast Rap',
            1071 => 'Music|Hip-Hop/Rap|Gangsta Rap',
            1072 => 'Music|Hip-Hop/Rap|Hardcore Rap',
            1073 => 'Music|Hip-Hop/Rap|Hip-Hop',
            1074 => 'Music|Hip-Hop/Rap|Latin Rap',
            1075 => 'Music|Hip-Hop/Rap|Old School Rap',
            1076 => 'Music|Hip-Hop/Rap|Rap',
            1077 => 'Music|Hip-Hop/Rap|Underground Rap',
            1078 => 'Music|Hip-Hop/Rap|West Coast Rap',
            1079 => 'Music|Holiday|Chanukah',
            1080 => 'Music|Holiday|Christmas',
            1081 => "Music|Holiday|Christmas: Children's",
            1082 => 'Music|Holiday|Christmas: Classic',
            1083 => 'Music|Holiday|Christmas: Classical',
            1084 => 'Music|Holiday|Christmas: Jazz',
            1085 => 'Music|Holiday|Christmas: Modern',
            1086 => 'Music|Holiday|Christmas: Pop',
            1087 => 'Music|Holiday|Christmas: R&B',
            1088 => 'Music|Holiday|Christmas: Religious',
            1089 => 'Music|Holiday|Christmas: Rock',
            1090 => 'Music|Holiday|Easter',
            1091 => 'Music|Holiday|Halloween',
            1092 => 'Music|Holiday|Holiday: Other',
            1093 => 'Music|Holiday|Thanksgiving',
            1094 => 'Music|Christian & Gospel|CCM',
            1095 => 'Music|Christian & Gospel|Christian Metal',
            1096 => 'Music|Christian & Gospel|Christian Pop',
            1097 => 'Music|Christian & Gospel|Christian Rap',
            1098 => 'Music|Christian & Gospel|Christian Rock',
            1099 => 'Music|Christian & Gospel|Classic Christian',
            1100 => 'Music|Christian & Gospel|Contemporary Gospel',
            1101 => 'Music|Christian & Gospel|Gospel',
            1103 => 'Music|Christian & Gospel|Praise & Worship',
            1104 => 'Music|Christian & Gospel|Southern Gospel',
            1105 => 'Music|Christian & Gospel|Traditional Gospel',
            1106 => 'Music|Jazz|Avant-Garde Jazz',
            1107 => 'Music|Jazz|Contemporary Jazz',
            1108 => 'Music|Jazz|Crossover Jazz',
            1109 => 'Music|Jazz|Dixieland',
            1110 => 'Music|Jazz|Fusion',
            1111 => 'Music|Jazz|Latin Jazz',
            1112 => 'Music|Jazz|Mainstream Jazz',
            1113 => 'Music|Jazz|Ragtime',
            1114 => 'Music|Jazz|Smooth Jazz',
            1115 => 'Music|Latino|Latin Jazz',
            1116 => 'Music|Latino|Contemporary Latin',
            1117 => 'Music|Latino|Pop Latino',
            1118 => 'Music|Latino|Raices', # (Ra&iacute;ces)
            1119 => 'Music|Latino|Urbano latino',
            1120 => 'Music|Latino|Baladas y Boleros',
            1121 => 'Music|Latino|Rock y Alternativo',
            1122 => 'Music|Brazilian',
            1123 => 'Music|Latino|Musica Mexicana', # (M&uacute;sica Mexicana)
            1124 => 'Music|Latino|Musica tropical', # (M&uacute;sica tropical)
            1125 => 'Music|New Age|Environmental',
            1126 => 'Music|New Age|Healing',
            1127 => 'Music|New Age|Meditation',
            1128 => 'Music|New Age|Nature',
            1129 => 'Music|New Age|Relaxation',
            1130 => 'Music|New Age|Travel',
            1131 => 'Music|Pop|Adult Contemporary',
            1132 => 'Music|Pop|Britpop',
            1133 => 'Music|Pop|Pop/Rock',
            1134 => 'Music|Pop|Soft Rock',
            1135 => 'Music|Pop|Teen Pop',
            1136 => 'Music|R&B/Soul|Contemporary R&B',
            1137 => 'Music|R&B/Soul|Disco',
            1138 => 'Music|R&B/Soul|Doo Wop',
            1139 => 'Music|R&B/Soul|Funk',
            1140 => 'Music|R&B/Soul|Motown',
            1141 => 'Music|R&B/Soul|Neo-Soul',
            1142 => 'Music|R&B/Soul|Quiet Storm',
            1143 => 'Music|R&B/Soul|Soul',
            1144 => 'Music|Rock|Adult Alternative',
            1145 => 'Music|Rock|American Trad Rock',
            1146 => 'Music|Rock|Arena Rock',
            1147 => 'Music|Rock|Blues-Rock',
            1148 => 'Music|Rock|British Invasion',
            1149 => 'Music|Rock|Death Metal/Black Metal',
            1150 => 'Music|Rock|Glam Rock',
            1151 => 'Music|Rock|Hair Metal',
            1152 => 'Music|Rock|Hard Rock',
            1153 => 'Music|Rock|Metal',
            1154 => 'Music|Rock|Jam Bands',
            1155 => 'Music|Rock|Prog-Rock/Art Rock',
            1156 => 'Music|Rock|Psychedelic',
            1157 => 'Music|Rock|Rock & Roll',
            1158 => 'Music|Rock|Rockabilly',
            1159 => 'Music|Rock|Roots Rock',
            1160 => 'Music|Rock|Singer/Songwriter',
            1161 => 'Music|Rock|Southern Rock',
            1162 => 'Music|Rock|Surf',
            1163 => 'Music|Rock|Tex-Mex',
            1165 => 'Music|Soundtrack|Foreign Cinema',
            1166 => 'Music|Soundtrack|Musicals',
            1167 => 'Music|Comedy|Novelty',
            1168 => 'Music|Soundtrack|Original Score',
            1169 => 'Music|Soundtrack|Soundtrack',
            1171 => 'Music|Comedy|Standup Comedy',
            1172 => 'Music|Soundtrack|TV Soundtrack',
            1173 => 'Music|Vocal|Standards',
            1174 => 'Music|Vocal|Traditional Pop',
            1175 => 'Music|Jazz|Vocal Jazz',
            1176 => 'Music|Vocal|Vocal Pop',
            1177 => 'Music|African|Afro-Beat',
            1178 => 'Music|African|Afro-Pop',
            1179 => 'Music|World|Cajun',
            1180 => 'Music|World|Celtic',
            1181 => 'Music|World|Celtic Folk',
            1182 => 'Music|World|Contemporary Celtic',
            1183 => 'Music|Reggae|Modern Dancehall',
            1184 => 'Music|World|Drinking Songs',
            1185 => 'Music|Indian|Indian Pop',
            1186 => 'Music|World|Japanese Pop',
            1187 => 'Music|World|Klezmer',
            1188 => 'Music|World|Polka',
            1189 => 'Music|World|Traditional Celtic',
            1190 => 'Music|World|Worldbeat',
            1191 => 'Music|World|Zydeco',
            1192 => 'Music|Reggae|Roots Reggae',
            1193 => 'Music|Reggae|Dub',
            1194 => 'Music|Reggae|Ska',
            1195 => 'Music|World|Caribbean',
            1196 => 'Music|World|South America',
            1197 => 'Music|Arabic',
            1198 => 'Music|World|North America',
            1199 => 'Music|World|Hawaii',
            1200 => 'Music|World|Australia',
            1201 => 'Music|World|Japan',
            1202 => 'Music|World|France',
            1203 => 'Music|African',
            1204 => 'Music|World|Asia',
            1205 => 'Music|World|Europe',
            1206 => 'Music|World|South Africa',
            1207 => 'Music|Jazz|Hard Bop',
            1208 => 'Music|Jazz|Trad Jazz',
            1209 => 'Music|Jazz|Cool Jazz',
            1210 => 'Music|Blues|Acoustic Blues',
            1211 => 'Music|Classical|High Classical',
            1220 => 'Music|Brazilian|Axe', # (Ax&eacute;)
            1221 => 'Music|Brazilian|Bossa Nova',
            1222 => 'Music|Brazilian|Choro',
            1223 => 'Music|Brazilian|Forro', # (Forr&oacute;)
            1224 => 'Music|Brazilian|Frevo',
            1225 => 'Music|Brazilian|MPB',
            1226 => 'Music|Brazilian|Pagode',
            1227 => 'Music|Brazilian|Samba',
            1228 => 'Music|Brazilian|Sertanejo',
            1229 => 'Music|Brazilian|Baile Funk',
            1230 => 'Music|Alternative|Chinese Alt',
            1231 => 'Music|Alternative|Korean Indie',
            1232 => 'Music|Chinese',
            1233 => 'Music|Chinese|Chinese Classical',
            1234 => 'Music|Chinese|Chinese Flute',
            1235 => 'Music|Chinese|Chinese Opera',
            1236 => 'Music|Chinese|Chinese Orchestral',
            1237 => 'Music|Chinese|Chinese Regional Folk',
            1238 => 'Music|Chinese|Chinese Strings',
            1239 => 'Music|Chinese|Taiwanese Folk',
            1240 => 'Music|Chinese|Tibetan Native Music',
            1241 => 'Music|Hip-Hop/Rap|Chinese Hip-Hop',
            1242 => 'Music|Hip-Hop/Rap|Korean Hip-Hop',
            1243 => 'Music|Korean',
            1244 => 'Music|Korean|Korean Classical',
            1245 => 'Music|Korean|Korean Trad Song',
            1246 => 'Music|Korean|Korean Trad Instrumental',
            1247 => 'Music|Korean|Korean Trad Theater',
            1248 => 'Music|Rock|Chinese Rock',
            1249 => 'Music|Rock|Korean Rock',
            1250 => 'Music|Pop|C-Pop',
            1251 => 'Music|Pop|Cantopop/HK-Pop',
            1252 => 'Music|Pop|Korean Folk-Pop',
            1253 => 'Music|Pop|Mandopop',
            1254 => 'Music|Pop|Tai-Pop',
            1255 => 'Music|Pop|Malaysian Pop',
            1256 => 'Music|Pop|Pinoy Pop',
            1257 => 'Music|Pop|Original Pilipino Music',
            1258 => 'Music|Pop|Manilla Sound',
            1259 => 'Music|Pop|Indo Pop',
            1260 => 'Music|Pop|Thai Pop',
            1261 => 'Music|Vocal|Trot',
            1262 => 'Music|Indian',
            1263 => 'Music|Indian|Bollywood',
            1264 => 'Music|Indian|Regional Indian|Tamil',
            1265 => 'Music|Indian|Regional Indian|Telugu',
            1266 => 'Music|Indian|Regional Indian',
            1267 => 'Music|Indian|Devotional & Spiritual',
            1268 => 'Music|Indian|Sufi',
            1269 => 'Music|Indian|Indian Classical',
            1270 => 'Music|Russian|Russian Chanson',
            1271 => 'Music|World|Dini',
            1272 => 'Music|Turkish|Halk',
            1273 => 'Music|Turkish|Sanat',
            1274 => 'Music|World|Dangdut',
            1275 => 'Music|World|Indonesian Religious',
            1276 => 'Music|World|Calypso',
            1277 => 'Music|World|Soca',
            1278 => 'Music|Indian|Ghazals',
            1279 => 'Music|Indian|Indian Folk',
            1280 => 'Music|Turkish|Arabesque',
            1281 => 'Music|African|Afrikaans',
            1282 => 'Music|World|Farsi',
            1283 => 'Music|World|Israeli',
            1284 => 'Music|Arabic|Khaleeji',
            1285 => 'Music|Arabic|North African',
            1286 => 'Music|Arabic|Arabic Pop',
            1287 => 'Music|Arabic|Islamic',
            1288 => 'Music|Soundtrack|Sound Effects',
            1289 => 'Music|Folk',
            1290 => 'Music|Orchestral',
            1291 => 'Music|Marching',
            1293 => 'Music|Pop|Oldies',
            1294 => 'Music|Country|Thai Country',
            1295 => 'Music|World|Flamenco',
            1296 => 'Music|World|Tango',
            1297 => 'Music|World|Fado',
            1298 => 'Music|World|Iberia',
            1299 => 'Music|Russian',
            1300 => 'Music|Turkish',
            1301 => 'Podcasts|Arts',
            1302 => 'Podcasts|Society & Culture|Personal Journals',
            1303 => 'Podcasts|Comedy',
            1304 => 'Podcasts|Education',
            1305 => 'Podcasts|Kids & Family',
            1306 => 'Podcasts|Arts|Food',
            1307 => 'Podcasts|Health',
            1309 => 'Podcasts|TV & Film',
            1310 => 'Podcasts|Music',
            1311 => 'Podcasts|News & Politics',
            1314 => 'Podcasts|Religion & Spirituality',
            1315 => 'Podcasts|Science & Medicine',
            1316 => 'Podcasts|Sports & Recreation',
            1318 => 'Podcasts|Technology',
            1320 => 'Podcasts|Society & Culture|Places & Travel',
            1321 => 'Podcasts|Business',
            1323 => 'Podcasts|Games & Hobbies',
            1324 => 'Podcasts|Society & Culture',
            1325 => 'Podcasts|Government & Organizations',
            1337 => 'Music Videos|Classical|Piano',
            1401 => 'Podcasts|Arts|Literature',
            1402 => 'Podcasts|Arts|Design',
            1404 => 'Podcasts|Games & Hobbies|Video Games',
            1405 => 'Podcasts|Arts|Performing Arts',
            1406 => 'Podcasts|Arts|Visual Arts',
            1410 => 'Podcasts|Business|Careers',
            1412 => 'Podcasts|Business|Investing',
            1413 => 'Podcasts|Business|Management & Marketing',
            1415 => 'Podcasts|Education|K-12',
            1416 => 'Podcasts|Education|Higher Education',
            1417 => 'Podcasts|Health|Fitness & Nutrition',
            1420 => 'Podcasts|Health|Self-Help',
            1421 => 'Podcasts|Health|Sexuality',
            1438 => 'Podcasts|Religion & Spirituality|Buddhism',
            1439 => 'Podcasts|Religion & Spirituality|Christianity',
            1440 => 'Podcasts|Religion & Spirituality|Islam',
            1441 => 'Podcasts|Religion & Spirituality|Judaism',
            1443 => 'Podcasts|Society & Culture|Philosophy',
            1444 => 'Podcasts|Religion & Spirituality|Spirituality',
            1446 => 'Podcasts|Technology|Gadgets',
            1448 => 'Podcasts|Technology|Tech News',
            1450 => 'Podcasts|Technology|Podcasting',
            1454 => 'Podcasts|Games & Hobbies|Automotive',
            1455 => 'Podcasts|Games & Hobbies|Aviation',
            1456 => 'Podcasts|Sports & Recreation|Outdoor',
            1459 => 'Podcasts|Arts|Fashion & Beauty',
            1460 => 'Podcasts|Games & Hobbies|Hobbies',
            1461 => 'Podcasts|Games & Hobbies|Other Games',
            1462 => 'Podcasts|Society & Culture|History',
            1463 => 'Podcasts|Religion & Spirituality|Hinduism',
            1464 => 'Podcasts|Religion & Spirituality|Other',
            1465 => 'Podcasts|Sports & Recreation|Professional',
            1466 => 'Podcasts|Sports & Recreation|College & High School',
            1467 => 'Podcasts|Sports & Recreation|Amateur',
            1468 => 'Podcasts|Education|Educational Technology',
            1469 => 'Podcasts|Education|Language Courses',
            1470 => 'Podcasts|Education|Training',
            1471 => 'Podcasts|Business|Business News',
            1472 => 'Podcasts|Business|Shopping',
            1473 => 'Podcasts|Government & Organizations|National',
            1474 => 'Podcasts|Government & Organizations|Regional',
            1475 => 'Podcasts|Government & Organizations|Local',
            1476 => 'Podcasts|Government & Organizations|Non-Profit',
            1477 => 'Podcasts|Science & Medicine|Natural Sciences',
            1478 => 'Podcasts|Science & Medicine|Medicine',
            1479 => 'Podcasts|Science & Medicine|Social Sciences',
            1480 => 'Podcasts|Technology|Software How-To',
            1481 => 'Podcasts|Health|Alternative Health',
            1482 => 'Podcasts|Arts|Books',
            1483 => 'Podcasts|Fiction',
            1484 => 'Podcasts|Fiction|Drama',
            1485 => 'Podcasts|Fiction|Science Fiction',
            1486 => 'Podcasts|Fiction|Comedy Fiction',
            1487 => 'Podcasts|History',
            1488 => 'Podcasts|True Crime',
            1489 => 'Podcasts|News',
            1490 => 'Podcasts|News|Business News',
            1491 => 'Podcasts|Business|Management',
            1492 => 'Podcasts|Business|Marketing',
            1493 => 'Podcasts|Business|Entrepreneurship',
            1494 => 'Podcasts|Business|Non-Profit',
            1495 => 'Podcasts|Comedy|Improv',
            1496 => 'Podcasts|Comedy|Comedy Interviews',
            1497 => 'Podcasts|Comedy|Stand-Up',
            1498 => 'Podcasts|Education|Language Learning',
            1499 => 'Podcasts|Education|How To',
            1500 => 'Podcasts|Education|Self-Improvement',
            1501 => 'Podcasts|Education|Courses',
            1502 => 'Podcasts|Leisure',
            1503 => 'Podcasts|Leisure|Automotive',
            1504 => 'Podcasts|Leisure|Aviation',
            1505 => 'Podcasts|Leisure|Hobbies',
            1506 => 'Podcasts|Leisure|Crafts',
            1507 => 'Podcasts|Leisure|Games',
            1508 => 'Podcasts|Leisure|Home & Garden',
            1509 => 'Podcasts|Leisure|Video Games',
            1510 => 'Podcasts|Leisure|Animation & Manga',
            1511 => 'Podcasts|Government',
            1512 => 'Podcasts|Health & Fitness',
            1513 => 'Podcasts|Health & Fitness|Alternative Health',
            1514 => 'Podcasts|Health & Fitness|Fitness',
            1515 => 'Podcasts|Health & Fitness|Nutrition',
            1516 => 'Podcasts|Health & Fitness|Sexuality',
            1517 => 'Podcasts|Health & Fitness|Mental Health',
            1518 => 'Podcasts|Health & Fitness|Medicine',
            1519 => 'Podcasts|Kids & Family|Education for Kids',
            1520 => 'Podcasts|Kids & Family|Stories for Kids',
            1521 => 'Podcasts|Kids & Family|Parenting',
            1522 => 'Podcasts|Kids & Family|Pets & Animals',
            1523 => 'Podcasts|Music|Music Commentary',
            1524 => 'Podcasts|Music|Music History',
            1525 => 'Podcasts|Music|Music Interviews',
            1526 => 'Podcasts|News|Daily News',
            1527 => 'Podcasts|News|Politics',
            1528 => 'Podcasts|News|Tech News',
            1529 => 'Podcasts|News|Sports News',
            1530 => 'Podcasts|News|News Commentary',
            1531 => 'Podcasts|News|Entertainment News',
            1532 => 'Podcasts|Religion & Spirituality|Religion',
            1533 => 'Podcasts|Science',
            1534 => 'Podcasts|Science|Natural Sciences',
            1535 => 'Podcasts|Science|Social Sciences',
            1536 => 'Podcasts|Science|Mathematics',
            1537 => 'Podcasts|Science|Nature',
            1538 => 'Podcasts|Science|Astronomy',
            1539 => 'Podcasts|Science|Chemistry',
            1540 => 'Podcasts|Science|Earth Sciences',
            1541 => 'Podcasts|Science|Life Sciences',
            1542 => 'Podcasts|Science|Physics',
            1543 => 'Podcasts|Society & Culture|Documentary',
            1544 => 'Podcasts|Society & Culture|Relationships',
            1545 => 'Podcasts|Sports',
            1546 => 'Podcasts|Sports|Soccer',
            1547 => 'Podcasts|Sports|Football',
            1548 => 'Podcasts|Sports|Basketball',
            1549 => 'Podcasts|Sports|Baseball',
            1550 => 'Podcasts|Sports|Hockey',
            1551 => 'Podcasts|Sports|Running',
            1552 => 'Podcasts|Sports|Rugby',
            1553 => 'Podcasts|Sports|Golf',
            1554 => 'Podcasts|Sports|Cricket',
            1555 => 'Podcasts|Sports|Wrestling',
            1556 => 'Podcasts|Sports|Tennis',
            1557 => 'Podcasts|Sports|Volleyball',
            1558 => 'Podcasts|Sports|Swimming',
            1559 => 'Podcasts|Sports|Wilderness',
            1560 => 'Podcasts|Sports|Fantasy Sports',
            1561 => 'Podcasts|TV & Film|TV Reviews',
            1562 => 'Podcasts|TV & Film|After Shows',
            1563 => 'Podcasts|TV & Film|Film Reviews',
            1564 => 'Podcasts|TV & Film|Film History',
            1565 => 'Podcasts|TV & Film|Film Interviews',
            1602 => 'Music Videos|Blues',
            1603 => 'Music Videos|Comedy',
            1604 => "Music Videos|Children's Music",
            1605 => 'Music Videos|Classical',
            1606 => 'Music Videos|Country',
            1607 => 'Music Videos|Electronic',
            1608 => 'Music Videos|Holiday',
            1609 => 'Music Videos|Classical|Opera',
            1610 => 'Music Videos|Singer/Songwriter',
            1611 => 'Music Videos|Jazz',
            1612 => 'Music Videos|Latin',
            1613 => 'Music Videos|New Age',
            1614 => 'Music Videos|Pop',
            1615 => 'Music Videos|R&B/Soul',
            1616 => 'Music Videos|Soundtrack',
            1617 => 'Music Videos|Dance',
            1618 => 'Music Videos|Hip-Hop/Rap',
            1619 => 'Music Videos|World',
            1620 => 'Music Videos|Alternative',
            1621 => 'Music Videos|Rock',
            1622 => 'Music Videos|Christian & Gospel',
            1623 => 'Music Videos|Vocal',
            1624 => 'Music Videos|Reggae',
            1625 => 'Music Videos|Easy Listening',
            1626 => 'Music Videos|Podcasts',
            1627 => 'Music Videos|J-Pop',
            1628 => 'Music Videos|Enka',
            1629 => 'Music Videos|Anime',
            1630 => 'Music Videos|Kayokyoku',
            1631 => 'Music Videos|Disney',
            1632 => 'Music Videos|French Pop',
            1633 => 'Music Videos|German Pop',
            1634 => 'Music Videos|German Folk',
            1635 => 'Music Videos|Alternative|Chinese Alt',
            1636 => 'Music Videos|Alternative|Korean Indie',
            1637 => 'Music Videos|Chinese',
            1638 => 'Music Videos|Chinese|Chinese Classical',
            1639 => 'Music Videos|Chinese|Chinese Flute',
            1640 => 'Music Videos|Chinese|Chinese Opera',
            1641 => 'Music Videos|Chinese|Chinese Orchestral',
            1642 => 'Music Videos|Chinese|Chinese Regional Folk',
            1643 => 'Music Videos|Chinese|Chinese Strings',
            1644 => 'Music Videos|Chinese|Taiwanese Folk',
            1645 => 'Music Videos|Chinese|Tibetan Native Music',
            1646 => 'Music Videos|Hip-Hop/Rap|Chinese Hip-Hop',
            1647 => 'Music Videos|Hip-Hop/Rap|Korean Hip-Hop',
            1648 => 'Music Videos|Korean',
            1649 => 'Music Videos|Korean|Korean Classical',
            1650 => 'Music Videos|Korean|Korean Trad Song',
            1651 => 'Music Videos|Korean|Korean Trad Instrumental',
            1652 => 'Music Videos|Korean|Korean Trad Theater',
            1653 => 'Music Videos|Rock|Chinese Rock',
            1654 => 'Music Videos|Rock|Korean Rock',
            1655 => 'Music Videos|Pop|C-Pop',
            1656 => 'Music Videos|Pop|Cantopop/HK-Pop',
            1657 => 'Music Videos|Pop|Korean Folk-Pop',
            1658 => 'Music Videos|Pop|Mandopop',
            1659 => 'Music Videos|Pop|Tai-Pop',
            1660 => 'Music Videos|Pop|Malaysian Pop',
            1661 => 'Music Videos|Pop|Pinoy Pop',
            1662 => 'Music Videos|Pop|Original Pilipino Music',
            1663 => 'Music Videos|Pop|Manilla Sound',
            1664 => 'Music Videos|Pop|Indo Pop',
            1665 => 'Music Videos|Pop|Thai Pop',
            1666 => 'Music Videos|Vocal|Trot',
            1671 => 'Music Videos|Brazilian',
            1672 => 'Music Videos|Brazilian|Axe', # (Ax&eacute;)
            1673 => 'Music Videos|Brazilian|Baile Funk',
            1674 => 'Music Videos|Brazilian|Bossa Nova',
            1675 => 'Music Videos|Brazilian|Choro',
            1676 => 'Music Videos|Brazilian|Forro',
            1677 => 'Music Videos|Brazilian|Frevo',
            1678 => 'Music Videos|Brazilian|MPB',
            1679 => 'Music Videos|Brazilian|Pagode',
            1680 => 'Music Videos|Brazilian|Samba',
            1681 => 'Music Videos|Brazilian|Sertanejo',
            1682 => 'Music Videos|Classical|High Classical',
            1683 => 'Music Videos|Fitness & Workout',
            1684 => 'Music Videos|Instrumental',
            1685 => 'Music Videos|Jazz|Big Band',
            1686 => 'Music Videos|Pop|K-Pop',
            1687 => 'Music Videos|Karaoke',
            1688 => 'Music Videos|Rock|Heavy Metal',
            1689 => 'Music Videos|Spoken Word',
            1690 => 'Music Videos|Indian',
            1691 => 'Music Videos|Indian|Bollywood',
            1692 => 'Music Videos|Indian|Regional Indian|Tamil',
            1693 => 'Music Videos|Indian|Regional Indian|Telugu',
            1694 => 'Music Videos|Indian|Regional Indian',
            1695 => 'Music Videos|Indian|Devotional & Spiritual',
            1696 => 'Music Videos|Indian|Sufi',
            1697 => 'Music Videos|Indian|Indian Classical',
            1698 => 'Music Videos|Russian|Russian Chanson',
            1699 => 'Music Videos|World|Dini',
            1700 => 'Music Videos|Turkish|Halk',
            1701 => 'Music Videos|Turkish|Sanat',
            1702 => 'Music Videos|World|Dangdut',
            1703 => 'Music Videos|World|Indonesian Religious',
            1704 => 'Music Videos|Indian|Indian Pop',
            1705 => 'Music Videos|World|Calypso',
            1706 => 'Music Videos|World|Soca',
            1707 => 'Music Videos|Indian|Ghazals',
            1708 => 'Music Videos|Indian|Indian Folk',
            1709 => 'Music Videos|Turkish|Arabesque',
            1710 => 'Music Videos|African|Afrikaans',
            1711 => 'Music Videos|World|Farsi',
            1712 => 'Music Videos|World|Israeli',
            1713 => 'Music Videos|Arabic',
            1714 => 'Music Videos|Arabic|Khaleeji',
            1715 => 'Music Videos|Arabic|North African',
            1716 => 'Music Videos|Arabic|Arabic Pop',
            1717 => 'Music Videos|Arabic|Islamic',
            1718 => 'Music Videos|Soundtrack|Sound Effects',
            1719 => 'Music Videos|Folk',
            1720 => 'Music Videos|Orchestral',
            1721 => 'Music Videos|Marching',
            1723 => 'Music Videos|Pop|Oldies',
            1724 => 'Music Videos|Country|Thai Country',
            1725 => 'Music Videos|World|Flamenco',
            1726 => 'Music Videos|World|Tango',
            1727 => 'Music Videos|World|Fado',
            1728 => 'Music Videos|World|Iberia',
            1729 => 'Music Videos|Russian',
            1730 => 'Music Videos|Turkish',
            1731 => 'Music Videos|Alternative|College Rock',
            1732 => 'Music Videos|Alternative|Goth Rock',
            1733 => 'Music Videos|Alternative|Grunge',
            1734 => 'Music Videos|Alternative|Indie Rock',
            1735 => 'Music Videos|Alternative|New Wave',
            1736 => 'Music Videos|Alternative|Punk',
            1737 => 'Music Videos|Blues|Acoustic Blues',
            1738 => 'Music Videos|Blues|Chicago Blues',
            1739 => 'Music Videos|Blues|Classic Blues',
            1740 => 'Music Videos|Blues|Contemporary Blues',
            1741 => 'Music Videos|Blues|Country Blues',
            1742 => 'Music Videos|Blues|Delta Blues',
            1743 => 'Music Videos|Blues|Electric Blues',
            1744 => "Music Videos|Children's Music|Lullabies",
            1745 => "Music Videos|Children's Music|Sing-Along",
            1746 => "Music Videos|Children's Music|Stories",
            1747 => 'Music Videos|Christian & Gospel|CCM',
            1748 => 'Music Videos|Christian & Gospel|Christian Metal',
            1749 => 'Music Videos|Christian & Gospel|Christian Pop',
            1750 => 'Music Videos|Christian & Gospel|Christian Rap',
            1751 => 'Music Videos|Christian & Gospel|Christian Rock',
            1752 => 'Music Videos|Christian & Gospel|Classic Christian',
            1753 => 'Music Videos|Christian & Gospel|Contemporary Gospel',
            1754 => 'Music Videos|Christian & Gospel|Gospel',
            1755 => 'Music Videos|Christian & Gospel|Praise & Worship',
            1756 => 'Music Videos|Christian & Gospel|Southern Gospel',
            1757 => 'Music Videos|Christian & Gospel|Traditional Gospel',
            1758 => 'Music Videos|Classical|Avant-Garde',
            1759 => 'Music Videos|Classical|Baroque Era',
            1760 => 'Music Videos|Classical|Chamber Music',
            1761 => 'Music Videos|Classical|Chant',
            1762 => 'Music Videos|Classical|Choral',
            1763 => 'Music Videos|Classical|Classical Crossover',
            1764 => 'Music Videos|Classical|Early Music',
            1765 => 'Music Videos|Classical|Impressionist',
            1766 => 'Music Videos|Classical|Medieval Era',
            1767 => 'Music Videos|Classical|Minimalism',
            1768 => 'Music Videos|Classical|Modern Era',
            1769 => 'Music Videos|Classical|Orchestral',
            1770 => 'Music Videos|Classical|Renaissance',
            1771 => 'Music Videos|Classical|Romantic Era',
            1772 => 'Music Videos|Classical|Wedding Music',
            1773 => 'Music Videos|Comedy|Novelty',
            1774 => 'Music Videos|Comedy|Standup Comedy',
            1775 => 'Music Videos|Country|Alternative Country',
            1776 => 'Music Videos|Country|Americana',
            1777 => 'Music Videos|Country|Bluegrass',
            1778 => 'Music Videos|Country|Contemporary Bluegrass',
            1779 => 'Music Videos|Country|Contemporary Country',
            1780 => 'Music Videos|Country|Country Gospel',
            1781 => 'Music Videos|Country|Honky Tonk',
            1782 => 'Music Videos|Country|Outlaw Country',
            1783 => 'Music Videos|Country|Traditional Bluegrass',
            1784 => 'Music Videos|Country|Traditional Country',
            1785 => 'Music Videos|Country|Urban Cowboy',
            1786 => 'Music Videos|Dance|Breakbeat',
            1787 => 'Music Videos|Dance|Exercise',
            1788 => 'Music Videos|Dance|Garage',
            1789 => 'Music Videos|Dance|Hardcore',
            1790 => 'Music Videos|Dance|House',
            1791 => "Music Videos|Dance|Jungle/Drum'n'bass",
            1792 => 'Music Videos|Dance|Techno',
            1793 => 'Music Videos|Dance|Trance',
            1794 => 'Music Videos|Easy Listening|Lounge',
            1795 => 'Music Videos|Easy Listening|Swing',
            1796 => 'Music Videos|Electronic|Ambient',
            1797 => 'Music Videos|Electronic|Downtempo',
            1798 => 'Music Videos|Electronic|Electronica',
            1799 => 'Music Videos|Electronic|IDM/Experimental',
            1800 => 'Music Videos|Electronic|Industrial',
            1801 => 'Music Videos|Hip-Hop/Rap|Alternative Rap',
            1802 => 'Music Videos|Hip-Hop/Rap|Dirty South',
            1803 => 'Music Videos|Hip-Hop/Rap|East Coast Rap',
            1804 => 'Music Videos|Hip-Hop/Rap|Gangsta Rap',
            1805 => 'Music Videos|Hip-Hop/Rap|Hardcore Rap',
            1806 => 'Music Videos|Hip-Hop/Rap|Hip-Hop',
            1807 => 'Music Videos|Hip-Hop/Rap|Latin Rap',
            1808 => 'Music Videos|Hip-Hop/Rap|Old School Rap',
            1809 => 'Music Videos|Hip-Hop/Rap|Rap',
            1810 => 'Music Videos|Hip-Hop/Rap|Underground Rap',
            1811 => 'Music Videos|Hip-Hop/Rap|West Coast Rap',
            1812 => 'Music Videos|Holiday|Chanukah',
            1813 => 'Music Videos|Holiday|Christmas',
            1814 => "Music Videos|Holiday|Christmas: Children's",
            1815 => 'Music Videos|Holiday|Christmas: Classic',
            1816 => 'Music Videos|Holiday|Christmas: Classical',
            1817 => 'Music Videos|Holiday|Christmas: Jazz',
            1818 => 'Music Videos|Holiday|Christmas: Modern',
            1819 => 'Music Videos|Holiday|Christmas: Pop',
            1820 => 'Music Videos|Holiday|Christmas: R&B',
            1821 => 'Music Videos|Holiday|Christmas: Religious',
            1822 => 'Music Videos|Holiday|Christmas: Rock',
            1823 => 'Music Videos|Holiday|Easter',
            1824 => 'Music Videos|Holiday|Halloween',
            1825 => 'Music Videos|Holiday|Thanksgiving',
            1826 => 'Music Videos|Jazz|Avant-Garde Jazz',
            1828 => 'Music Videos|Jazz|Bop',
            1829 => 'Music Videos|Jazz|Contemporary Jazz',
            1830 => 'Music Videos|Jazz|Cool Jazz',
            1831 => 'Music Videos|Jazz|Crossover Jazz',
            1832 => 'Music Videos|Jazz|Dixieland',
            1833 => 'Music Videos|Jazz|Fusion',
            1834 => 'Music Videos|Jazz|Hard Bop',
            1835 => 'Music Videos|Jazz|Latin Jazz',
            1836 => 'Music Videos|Jazz|Mainstream Jazz',
            1837 => 'Music Videos|Jazz|Ragtime',
            1838 => 'Music Videos|Jazz|Smooth Jazz',
            1839 => 'Music Videos|Jazz|Trad Jazz',
            1840 => 'Music Videos|Latin|Alternative & Rock in Spanish',
            1841 => 'Music Videos|Latin|Baladas y Boleros',
            1842 => 'Music Videos|Latin|Contemporary Latin',
            1843 => 'Music Videos|Latin|Latin Jazz',
            1844 => 'Music Videos|Latin|Latin Urban',
            1845 => 'Music Videos|Latin|Pop in Spanish',
            1846 => 'Music Videos|Latin|Raices',
            1847 => 'Music Videos|Latin|Musica Mexicana', # (M&uacute;sica Mexicana)
            1848 => 'Music Videos|Latin|Salsa y Tropical',
            1849 => 'Music Videos|New Age|Healing',
            1850 => 'Music Videos|New Age|Meditation',
            1851 => 'Music Videos|New Age|Nature',
            1852 => 'Music Videos|New Age|Relaxation',
            1853 => 'Music Videos|New Age|Travel',
            1854 => 'Music Videos|Pop|Adult Contemporary',
            1855 => 'Music Videos|Pop|Britpop',
            1856 => 'Music Videos|Pop|Pop/Rock',
            1857 => 'Music Videos|Pop|Soft Rock',
            1858 => 'Music Videos|Pop|Teen Pop',
            1859 => 'Music Videos|R&B/Soul|Contemporary R&B',
            1860 => 'Music Videos|R&B/Soul|Disco',
            1861 => 'Music Videos|R&B/Soul|Doo Wop',
            1862 => 'Music Videos|R&B/Soul|Funk',
            1863 => 'Music Videos|R&B/Soul|Motown',
            1864 => 'Music Videos|R&B/Soul|Neo-Soul',
            1865 => 'Music Videos|R&B/Soul|Soul',
            1866 => 'Music Videos|Reggae|Modern Dancehall',
            1867 => 'Music Videos|Reggae|Dub',
            1868 => 'Music Videos|Reggae|Roots Reggae',
            1869 => 'Music Videos|Reggae|Ska',
            1870 => 'Music Videos|Rock|Adult Alternative',
            1871 => 'Music Videos|Rock|American Trad Rock',
            1872 => 'Music Videos|Rock|Arena Rock',
            1873 => 'Music Videos|Rock|Blues-Rock',
            1874 => 'Music Videos|Rock|British Invasion',
            1875 => 'Music Videos|Rock|Death Metal/Black Metal',
            1876 => 'Music Videos|Rock|Glam Rock',
            1877 => 'Music Videos|Rock|Hair Metal',
            1878 => 'Music Videos|Rock|Hard Rock',
            1879 => 'Music Videos|Rock|Jam Bands',
            1880 => 'Music Videos|Rock|Prog-Rock/Art Rock',
            1881 => 'Music Videos|Rock|Psychedelic',
            1882 => 'Music Videos|Rock|Rock & Roll',
            1883 => 'Music Videos|Rock|Rockabilly',
            1884 => 'Music Videos|Rock|Roots Rock',
            1885 => 'Music Videos|Rock|Singer/Songwriter',
            1886 => 'Music Videos|Rock|Southern Rock',
            1887 => 'Music Videos|Rock|Surf',
            1888 => 'Music Videos|Rock|Tex-Mex',
            1889 => 'Music Videos|Singer/Songwriter|Alternative Folk',
            1890 => 'Music Videos|Singer/Songwriter|Contemporary Folk',
            1891 => 'Music Videos|Singer/Songwriter|Contemporary Singer/Songwriter',
            1892 => 'Music Videos|Singer/Songwriter|Folk-Rock',
            1893 => 'Music Videos|Singer/Songwriter|New Acoustic',
            1894 => 'Music Videos|Singer/Songwriter|Traditional Folk',
            1895 => 'Music Videos|Soundtrack|Foreign Cinema',
            1896 => 'Music Videos|Soundtrack|Musicals',
            1897 => 'Music Videos|Soundtrack|Original Score',
            1898 => 'Music Videos|Soundtrack|Soundtrack',
            1899 => 'Music Videos|Soundtrack|TV Soundtrack',
            1900 => 'Music Videos|Vocal|Standards',
            1901 => 'Music Videos|Vocal|Traditional Pop',
            1902 => 'Music Videos|Jazz|Vocal Jazz',
            1903 => 'Music Videos|Vocal|Vocal Pop',
            1904 => 'Music Videos|African',
            1905 => 'Music Videos|African|Afro-Beat',
            1906 => 'Music Videos|African|Afro-Pop',
            1907 => 'Music Videos|World|Asia',
            1908 => 'Music Videos|World|Australia',
            1909 => 'Music Videos|World|Cajun',
            1910 => 'Music Videos|World|Caribbean',
            1911 => 'Music Videos|World|Celtic',
            1912 => 'Music Videos|World|Celtic Folk',
            1913 => 'Music Videos|World|Contemporary Celtic',
            1914 => 'Music Videos|World|Europe',
            1915 => 'Music Videos|World|France',
            1916 => 'Music Videos|World|Hawaii',
            1917 => 'Music Videos|World|Japan',
            1918 => 'Music Videos|World|Klezmer',
            1919 => 'Music Videos|World|North America',
            1920 => 'Music Videos|World|Polka',
            1921 => 'Music Videos|World|South Africa',
            1922 => 'Music Videos|World|South America',
            1923 => 'Music Videos|World|Traditional Celtic',
            1924 => 'Music Videos|World|Worldbeat',
            1925 => 'Music Videos|World|Zydeco',
            1926 => 'Music Videos|Christian & Gospel',
            1928 => 'Music Videos|Classical|Art Song',
            1929 => 'Music Videos|Classical|Brass & Woodwinds',
            1930 => 'Music Videos|Classical|Solo Instrumental',
            1931 => 'Music Videos|Classical|Contemporary Era',
            1932 => 'Music Videos|Classical|Oratorio',
            1933 => 'Music Videos|Classical|Cantata',
            1934 => 'Music Videos|Classical|Electronic',
            1935 => 'Music Videos|Classical|Sacred',
            1936 => 'Music Videos|Classical|Guitar',
            1938 => 'Music Videos|Classical|Violin',
            1939 => 'Music Videos|Classical|Cello',
            1940 => 'Music Videos|Classical|Percussion',
            1941 => 'Music Videos|Electronic|Dubstep',
            1942 => 'Music Videos|Electronic|Bass',
            1943 => 'Music Videos|Hip-Hop/Rap|UK Hip-Hop',
            1944 => 'Music Videos|Reggae|Lovers Rock',
            1945 => 'Music Videos|Alternative|EMO',
            1946 => 'Music Videos|Alternative|Pop Punk',
            1947 => 'Music Videos|Alternative|Indie Pop',
            1948 => 'Music Videos|New Age|Yoga',
            1949 => 'Music Videos|Pop|Tribute',
            1950 => 'Music Videos|Pop|Shows',
            1951 => 'Music Videos|Cuban',
            1952 => 'Music Videos|Cuban|Mambo',
            1953 => 'Music Videos|Cuban|Chachacha',
            1954 => 'Music Videos|Cuban|Guajira',
            1955 => 'Music Videos|Cuban|Son',
            1956 => 'Music Videos|Cuban|Bolero',
            1957 => 'Music Videos|Cuban|Guaracha',
            1958 => 'Music Videos|Cuban|Timba',
            1959 => 'Music Videos|Soundtrack|Video Game',
            1960 => 'Music Videos|Indian|Regional Indian|Punjabi|Punjabi Pop',
            1961 => 'Music Videos|Indian|Regional Indian|Bengali|Rabindra Sangeet',
            1962 => 'Music Videos|Indian|Regional Indian|Malayalam',
            1963 => 'Music Videos|Indian|Regional Indian|Kannada',
            1964 => 'Music Videos|Indian|Regional Indian|Marathi',
            1965 => 'Music Videos|Indian|Regional Indian|Gujarati',
            1966 => 'Music Videos|Indian|Regional Indian|Assamese',
            1967 => 'Music Videos|Indian|Regional Indian|Bhojpuri',
            1968 => 'Music Videos|Indian|Regional Indian|Haryanvi',
            1969 => 'Music Videos|Indian|Regional Indian|Odia',
            1970 => 'Music Videos|Indian|Regional Indian|Rajasthani',
            1971 => 'Music Videos|Indian|Regional Indian|Urdu',
            1972 => 'Music Videos|Indian|Regional Indian|Punjabi',
            1973 => 'Music Videos|Indian|Regional Indian|Bengali',
            1974 => 'Music Videos|Indian|Indian Classical|Carnatic Classical',
            1975 => 'Music Videos|Indian|Indian Classical|Hindustani Classical',
            1976 => 'Music Videos|African|Afro House',
            1977 => 'Music Videos|African|Afro Soul',
            1978 => 'Music Videos|African|Afrobeats',
            1979 => 'Music Videos|African|Benga',
            1980 => 'Music Videos|African|Bongo-Flava',
            1981 => 'Music Videos|African|Coupe-Decale',
            1982 => 'Music Videos|African|Gqom',
            1983 => 'Music Videos|African|Highlife',
            1984 => 'Music Videos|African|Kuduro',
            1985 => 'Music Videos|African|Kizomba',
            1986 => 'Music Videos|African|Kwaito',
            1987 => 'Music Videos|African|Mbalax',
            1988 => 'Music Videos|African|Ndombolo',
            1989 => 'Music Videos|African|Shangaan Electro',
            1990 => 'Music Videos|African|Soukous',
            1991 => 'Music Videos|African|Taarab',
            1992 => 'Music Videos|African|Zouglou',
            1993 => 'Music Videos|Turkish|Ozgun',
            1994 => 'Music Videos|Turkish|Fantezi',
            1995 => 'Music Videos|Turkish|Religious',
            1996 => 'Music Videos|Pop|Turkish Pop',
            1997 => 'Music Videos|Rock|Turkish Rock',
            1998 => 'Music Videos|Alternative|Turkish Alternative',
            1999 => 'Music Videos|Hip-Hop/Rap|Turkish Hip-Hop/Rap',
            2000 => 'Music Videos|African|Maskandi',
            2001 => 'Music Videos|Russian|Russian Romance',
            2002 => 'Music Videos|Russian|Russian Bard',
            2003 => 'Music Videos|Russian|Russian Pop',
            2004 => 'Music Videos|Russian|Russian Rock',
            2005 => 'Music Videos|Russian|Russian Hip-Hop',
            2006 => 'Music Videos|Arabic|Levant',
            2007 => 'Music Videos|Arabic|Levant|Dabke',
            2008 => 'Music Videos|Arabic|Maghreb Rai',
            2009 => 'Music Videos|Arabic|Khaleeji|Khaleeji Jalsat',
            2010 => 'Music Videos|Arabic|Khaleeji|Khaleeji Shailat',
            2011 => 'Music Videos|Tarab',
            2012 => 'Music Videos|Tarab|Iraqi Tarab',
            2013 => 'Music Videos|Tarab|Egyptian Tarab',
            2014 => 'Music Videos|Tarab|Khaleeji Tarab',
            2015 => 'Music Videos|Pop|Levant Pop',
            2016 => 'Music Videos|Pop|Iraqi Pop',
            2017 => 'Music Videos|Pop|Egyptian Pop',
            2018 => 'Music Videos|Pop|Maghreb Pop',
            2019 => 'Music Videos|Pop|Khaleeji Pop',
            2020 => 'Music Videos|Hip-Hop/Rap|Levant Hip-Hop',
            2021 => 'Music Videos|Hip-Hop/Rap|Egyptian Hip-Hop',
            2022 => 'Music Videos|Hip-Hop/Rap|Maghreb Hip-Hop',
            2023 => 'Music Videos|Hip-Hop/Rap|Khaleeji Hip-Hop',
            2024 => 'Music Videos|Alternative|Indie Levant',
            2025 => 'Music Videos|Alternative|Indie Egyptian',
            2026 => 'Music Videos|Alternative|Indie Maghreb',
            2027 => 'Music Videos|Electronic|Levant Electronic',
            2028 => "Music Videos|Electronic|Electro-Cha'abi",
            2029 => 'Music Videos|Electronic|Maghreb Electronic',
            2030 => 'Music Videos|Folk|Iraqi Folk',
            2031 => 'Music Videos|Folk|Khaleeji Folk',
            2032 => 'Music Videos|Dance|Maghreb Dance',
            4000 => 'TV Shows|Comedy',
            4001 => 'TV Shows|Drama',
            4002 => 'TV Shows|Animation',
            4003 => 'TV Shows|Action & Adventure',
            4004 => 'TV Shows|Classics',
            4005 => 'TV Shows|Kids & Family',
            4006 => 'TV Shows|Nonfiction',
            4007 => 'TV Shows|Reality TV',
            4008 => 'TV Shows|Sci-Fi & Fantasy',
            4009 => 'TV Shows|Sports',
            4010 => 'TV Shows|Teens',
            4011 => 'TV Shows|Latino TV',
            4401 => 'Movies|Action & Adventure',
            4402 => 'Movies|Anime',
            4403 => 'Movies|Classics',
            4404 => 'Movies|Comedy',
            4405 => 'Movies|Documentary',
            4406 => 'Movies|Drama',
            4407 => 'Movies|Foreign',
            4408 => 'Movies|Horror',
            4409 => 'Movies|Independent',
            4410 => 'Movies|Kids & Family',
            4411 => 'Movies|Musicals',
            4412 => 'Movies|Romance',
            4413 => 'Movies|Sci-Fi & Fantasy',
            4414 => 'Movies|Short Films',
            4415 => 'Movies|Special Interest',
            4416 => 'Movies|Thriller',
            4417 => 'Movies|Sports',
            4418 => 'Movies|Western',
            4419 => 'Movies|Urban',
            4420 => 'Movies|Holiday',
            4421 => 'Movies|Made for TV',
            4422 => 'Movies|Concert Films',
            4423 => 'Movies|Music Documentaries',
            4424 => 'Movies|Music Feature Films',
            4425 => 'Movies|Japanese Cinema',
            4426 => 'Movies|Jidaigeki',
            4427 => 'Movies|Tokusatsu',
            4428 => 'Movies|Korean Cinema',
            4429 => 'Movies|Russian',
            4430 => 'Movies|Turkish',
            4431 => 'Movies|Bollywood',
            4432 => 'Movies|Regional Indian',
            4433 => 'Movies|Middle Eastern',
            4434 => 'Movies|African',
            6000 => 'App Store|Business',
            6001 => 'App Store|Weather',
            6002 => 'App Store|Utilities',
            6003 => 'App Store|Travel',
            6004 => 'App Store|Sports',
            6005 => 'App Store|Social Networking',
            6006 => 'App Store|Reference',
            6007 => 'App Store|Productivity',
            6008 => 'App Store|Photo & Video',
            6009 => 'App Store|News',
            6010 => 'App Store|Navigation',
            6011 => 'App Store|Music',
            6012 => 'App Store|Lifestyle',
            6013 => 'App Store|Health & Fitness',
            6014 => 'App Store|Games',
            6015 => 'App Store|Finance',
            6016 => 'App Store|Entertainment',
            6017 => 'App Store|Education',
            6018 => 'App Store|Books',
            6020 => 'App Store|Medical',
            6021 => 'App Store|Magazines & Newspapers',
            6022 => 'App Store|Catalogs',
            6023 => 'App Store|Food & Drink',
            6024 => 'App Store|Shopping',
            6025 => 'App Store|Stickers',
            6026 => 'App Store|Developer Tools',
            6027 => 'App Store|Graphics & Design',
            7001 => 'App Store|Games|Action',
            7002 => 'App Store|Games|Adventure',
            7003 => 'App Store|Games|Casual',
            7004 => 'App Store|Games|Board',
            7005 => 'App Store|Games|Card',
            7006 => 'App Store|Games|Casino',
            7007 => 'App Store|Games|Dice',
            7008 => 'App Store|Games|Educational',
            7009 => 'App Store|Games|Family',
            7011 => 'App Store|Games|Music',
            7012 => 'App Store|Games|Puzzle',
            7013 => 'App Store|Games|Racing',
            7014 => 'App Store|Games|Role Playing',
            7015 => 'App Store|Games|Simulation',
            7016 => 'App Store|Games|Sports',
            7017 => 'App Store|Games|Strategy',
            7018 => 'App Store|Games|Trivia',
            7019 => 'App Store|Games|Word',
            8001 => 'Tones|Ringtones|Alternative',
            8002 => 'Tones|Ringtones|Blues',
            8003 => "Tones|Ringtones|Children's Music",
            8004 => 'Tones|Ringtones|Classical',
            8005 => 'Tones|Ringtones|Comedy',
            8006 => 'Tones|Ringtones|Country',
            8007 => 'Tones|Ringtones|Dance',
            8008 => 'Tones|Ringtones|Electronic',
            8009 => 'Tones|Ringtones|Enka',
            8010 => 'Tones|Ringtones|French Pop',
            8011 => 'Tones|Ringtones|German Folk',
            8012 => 'Tones|Ringtones|German Pop',
            8013 => 'Tones|Ringtones|Hip-Hop/Rap',
            8014 => 'Tones|Ringtones|Holiday',
            8015 => 'Tones|Ringtones|Inspirational',
            8016 => 'Tones|Ringtones|J-Pop',
            8017 => 'Tones|Ringtones|Jazz',
            8018 => 'Tones|Ringtones|Kayokyoku',
            8019 => 'Tones|Ringtones|Latin',
            8020 => 'Tones|Ringtones|New Age',
            8021 => 'Tones|Ringtones|Classical|Opera',
            8022 => 'Tones|Ringtones|Pop',
            8023 => 'Tones|Ringtones|R&B/Soul',
            8024 => 'Tones|Ringtones|Reggae',
            8025 => 'Tones|Ringtones|Rock',
            8026 => 'Tones|Ringtones|Singer/Songwriter',
            8027 => 'Tones|Ringtones|Soundtrack',
            8028 => 'Tones|Ringtones|Spoken Word',
            8029 => 'Tones|Ringtones|Vocal',
            8030 => 'Tones|Ringtones|World',
            8050 => 'Tones|Alert Tones|Sound Effects',
            8051 => 'Tones|Alert Tones|Dialogue',
            8052 => 'Tones|Alert Tones|Music',
            8053 => 'Tones|Ringtones',
            8054 => 'Tones|Alert Tones',
            8055 => 'Tones|Ringtones|Alternative|Chinese Alt',
            8056 => 'Tones|Ringtones|Alternative|College Rock',
            8057 => 'Tones|Ringtones|Alternative|Goth Rock',
            8058 => 'Tones|Ringtones|Alternative|Grunge',
            8059 => 'Tones|Ringtones|Alternative|Indie Rock',
            8060 => 'Tones|Ringtones|Alternative|Korean Indie',
            8061 => 'Tones|Ringtones|Alternative|New Wave',
            8062 => 'Tones|Ringtones|Alternative|Punk',
            8063 => 'Tones|Ringtones|Anime',
            8064 => 'Tones|Ringtones|Arabic',
            8065 => 'Tones|Ringtones|Arabic|Arabic Pop',
            8066 => 'Tones|Ringtones|Arabic|Islamic',
            8067 => 'Tones|Ringtones|Arabic|Khaleeji',
            8068 => 'Tones|Ringtones|Arabic|North African',
            8069 => 'Tones|Ringtones|Blues|Acoustic Blues',
            8070 => 'Tones|Ringtones|Blues|Chicago Blues',
            8071 => 'Tones|Ringtones|Blues|Classic Blues',
            8072 => 'Tones|Ringtones|Blues|Contemporary Blues',
            8073 => 'Tones|Ringtones|Blues|Country Blues',
            8074 => 'Tones|Ringtones|Blues|Delta Blues',
            8075 => 'Tones|Ringtones|Blues|Electric Blues',
            8076 => 'Tones|Ringtones|Brazilian',
            8077 => 'Tones|Ringtones|Brazilian|Axe', # (Ax&eacute;)
            8078 => 'Tones|Ringtones|Brazilian|Baile Funk',
            8079 => 'Tones|Ringtones|Brazilian|Bossa Nova',
            8080 => 'Tones|Ringtones|Brazilian|Choro',
            8081 => 'Tones|Ringtones|Brazilian|Forro', # (Forr&oacute;)
            8082 => 'Tones|Ringtones|Brazilian|Frevo',
            8083 => 'Tones|Ringtones|Brazilian|MPB',
            8084 => 'Tones|Ringtones|Brazilian|Pagode',
            8085 => 'Tones|Ringtones|Brazilian|Samba',
            8086 => 'Tones|Ringtones|Brazilian|Sertanejo',
            8087 => "Tones|Ringtones|Children's Music|Lullabies",
            8088 => "Tones|Ringtones|Children's Music|Sing-Along",
            8089 => "Tones|Ringtones|Children's Music|Stories",
            8090 => 'Tones|Ringtones|Chinese',
            8091 => 'Tones|Ringtones|Chinese|Chinese Classical',
            8092 => 'Tones|Ringtones|Chinese|Chinese Flute',
            8093 => 'Tones|Ringtones|Chinese|Chinese Opera',
            8094 => 'Tones|Ringtones|Chinese|Chinese Orchestral',
            8095 => 'Tones|Ringtones|Chinese|Chinese Regional Folk',
            8096 => 'Tones|Ringtones|Chinese|Chinese Strings',
            8097 => 'Tones|Ringtones|Chinese|Taiwanese Folk',
            8098 => 'Tones|Ringtones|Chinese|Tibetan Native Music',
            8099 => 'Tones|Ringtones|Christian & Gospel',
            8100 => 'Tones|Ringtones|Christian & Gospel|CCM',
            8101 => 'Tones|Ringtones|Christian & Gospel|Christian Metal',
            8102 => 'Tones|Ringtones|Christian & Gospel|Christian Pop',
            8103 => 'Tones|Ringtones|Christian & Gospel|Christian Rap',
            8104 => 'Tones|Ringtones|Christian & Gospel|Christian Rock',
            8105 => 'Tones|Ringtones|Christian & Gospel|Classic Christian',
            8106 => 'Tones|Ringtones|Christian & Gospel|Contemporary Gospel',
            8107 => 'Tones|Ringtones|Christian & Gospel|Gospel',
            8108 => 'Tones|Ringtones|Christian & Gospel|Praise & Worship',
            8109 => 'Tones|Ringtones|Christian & Gospel|Southern Gospel',
            8110 => 'Tones|Ringtones|Christian & Gospel|Traditional Gospel',
            8111 => 'Tones|Ringtones|Classical|Avant-Garde',
            8112 => 'Tones|Ringtones|Classical|Baroque Era',
            8113 => 'Tones|Ringtones|Classical|Chamber Music',
            8114 => 'Tones|Ringtones|Classical|Chant',
            8115 => 'Tones|Ringtones|Classical|Choral',
            8116 => 'Tones|Ringtones|Classical|Classical Crossover',
            8117 => 'Tones|Ringtones|Classical|Early Music',
            8118 => 'Tones|Ringtones|Classical|High Classical',
            8119 => 'Tones|Ringtones|Classical|Impressionist',
            8120 => 'Tones|Ringtones|Classical|Medieval Era',
            8121 => 'Tones|Ringtones|Classical|Minimalism',
            8122 => 'Tones|Ringtones|Classical|Modern Era',
            8123 => 'Tones|Ringtones|Classical|Orchestral',
            8124 => 'Tones|Ringtones|Classical|Renaissance',
            8125 => 'Tones|Ringtones|Classical|Romantic Era',
            8126 => 'Tones|Ringtones|Classical|Wedding Music',
            8127 => 'Tones|Ringtones|Comedy|Novelty',
            8128 => 'Tones|Ringtones|Comedy|Standup Comedy',
            8129 => 'Tones|Ringtones|Country|Alternative Country',
            8130 => 'Tones|Ringtones|Country|Americana',
            8131 => 'Tones|Ringtones|Country|Bluegrass',
            8132 => 'Tones|Ringtones|Country|Contemporary Bluegrass',
            8133 => 'Tones|Ringtones|Country|Contemporary Country',
            8134 => 'Tones|Ringtones|Country|Country Gospel',
            8135 => 'Tones|Ringtones|Country|Honky Tonk',
            8136 => 'Tones|Ringtones|Country|Outlaw Country',
            8137 => 'Tones|Ringtones|Country|Thai Country',
            8138 => 'Tones|Ringtones|Country|Traditional Bluegrass',
            8139 => 'Tones|Ringtones|Country|Traditional Country',
            8140 => 'Tones|Ringtones|Country|Urban Cowboy',
            8141 => 'Tones|Ringtones|Dance|Breakbeat',
            8142 => 'Tones|Ringtones|Dance|Exercise',
            8143 => 'Tones|Ringtones|Dance|Garage',
            8144 => 'Tones|Ringtones|Dance|Hardcore',
            8145 => 'Tones|Ringtones|Dance|House',
            8146 => "Tones|Ringtones|Dance|Jungle/Drum'n'bass",
            8147 => 'Tones|Ringtones|Dance|Techno',
            8148 => 'Tones|Ringtones|Dance|Trance',
            8149 => 'Tones|Ringtones|Disney',
            8150 => 'Tones|Ringtones|Easy Listening',
            8151 => 'Tones|Ringtones|Easy Listening|Lounge',
            8152 => 'Tones|Ringtones|Easy Listening|Swing',
            8153 => 'Tones|Ringtones|Electronic|Ambient',
            8154 => 'Tones|Ringtones|Electronic|Downtempo',
            8155 => 'Tones|Ringtones|Electronic|Electronica',
            8156 => 'Tones|Ringtones|Electronic|IDM/Experimental',
            8157 => 'Tones|Ringtones|Electronic|Industrial',
            8158 => 'Tones|Ringtones|Fitness & Workout',
            8159 => 'Tones|Ringtones|Folk',
            8160 => 'Tones|Ringtones|Hip-Hop/Rap|Alternative Rap',
            8161 => 'Tones|Ringtones|Hip-Hop/Rap|Chinese Hip-Hop',
            8162 => 'Tones|Ringtones|Hip-Hop/Rap|Dirty South',
            8163 => 'Tones|Ringtones|Hip-Hop/Rap|East Coast Rap',
            8164 => 'Tones|Ringtones|Hip-Hop/Rap|Gangsta Rap',
            8165 => 'Tones|Ringtones|Hip-Hop/Rap|Hardcore Rap',
            8166 => 'Tones|Ringtones|Hip-Hop/Rap|Hip-Hop',
            8167 => 'Tones|Ringtones|Hip-Hop/Rap|Korean Hip-Hop',
            8168 => 'Tones|Ringtones|Hip-Hop/Rap|Latin Rap',
            8169 => 'Tones|Ringtones|Hip-Hop/Rap|Old School Rap',
            8170 => 'Tones|Ringtones|Hip-Hop/Rap|Rap',
            8171 => 'Tones|Ringtones|Hip-Hop/Rap|Underground Rap',
            8172 => 'Tones|Ringtones|Hip-Hop/Rap|West Coast Rap',
            8173 => 'Tones|Ringtones|Holiday|Chanukah',
            8174 => 'Tones|Ringtones|Holiday|Christmas',
            8175 => "Tones|Ringtones|Holiday|Christmas: Children's",
            8176 => 'Tones|Ringtones|Holiday|Christmas: Classic',
            8177 => 'Tones|Ringtones|Holiday|Christmas: Classical',
            8178 => 'Tones|Ringtones|Holiday|Christmas: Jazz',
            8179 => 'Tones|Ringtones|Holiday|Christmas: Modern',
            8180 => 'Tones|Ringtones|Holiday|Christmas: Pop',
            8181 => 'Tones|Ringtones|Holiday|Christmas: R&B',
            8182 => 'Tones|Ringtones|Holiday|Christmas: Religious',
            8183 => 'Tones|Ringtones|Holiday|Christmas: Rock',
            8184 => 'Tones|Ringtones|Holiday|Easter',
            8185 => 'Tones|Ringtones|Holiday|Halloween',
            8186 => 'Tones|Ringtones|Holiday|Thanksgiving',
            8187 => 'Tones|Ringtones|Indian',
            8188 => 'Tones|Ringtones|Indian|Bollywood',
            8189 => 'Tones|Ringtones|Indian|Devotional & Spiritual',
            8190 => 'Tones|Ringtones|Indian|Ghazals',
            8191 => 'Tones|Ringtones|Indian|Indian Classical',
            8192 => 'Tones|Ringtones|Indian|Indian Folk',
            8193 => 'Tones|Ringtones|Indian|Indian Pop',
            8194 => 'Tones|Ringtones|Indian|Regional Indian',
            8195 => 'Tones|Ringtones|Indian|Sufi',
            8196 => 'Tones|Ringtones|Indian|Regional Indian|Tamil',
            8197 => 'Tones|Ringtones|Indian|Regional Indian|Telugu',
            8198 => 'Tones|Ringtones|Instrumental',
            8199 => 'Tones|Ringtones|Jazz|Avant-Garde Jazz',
            8201 => 'Tones|Ringtones|Jazz|Big Band',
            8202 => 'Tones|Ringtones|Jazz|Bop',
            8203 => 'Tones|Ringtones|Jazz|Contemporary Jazz',
            8204 => 'Tones|Ringtones|Jazz|Cool Jazz',
            8205 => 'Tones|Ringtones|Jazz|Crossover Jazz',
            8206 => 'Tones|Ringtones|Jazz|Dixieland',
            8207 => 'Tones|Ringtones|Jazz|Fusion',
            8208 => 'Tones|Ringtones|Jazz|Hard Bop',
            8209 => 'Tones|Ringtones|Jazz|Latin Jazz',
            8210 => 'Tones|Ringtones|Jazz|Mainstream Jazz',
            8211 => 'Tones|Ringtones|Jazz|Ragtime',
            8212 => 'Tones|Ringtones|Jazz|Smooth Jazz',
            8213 => 'Tones|Ringtones|Jazz|Trad Jazz',
            8214 => 'Tones|Ringtones|Pop|K-Pop',
            8215 => 'Tones|Ringtones|Karaoke',
            8216 => 'Tones|Ringtones|Korean',
            8217 => 'Tones|Ringtones|Korean|Korean Classical',
            8218 => 'Tones|Ringtones|Korean|Korean Trad Instrumental',
            8219 => 'Tones|Ringtones|Korean|Korean Trad Song',
            8220 => 'Tones|Ringtones|Korean|Korean Trad Theater',
            8221 => 'Tones|Ringtones|Latin|Alternative & Rock in Spanish',
            8222 => 'Tones|Ringtones|Latin|Baladas y Boleros',
            8223 => 'Tones|Ringtones|Latin|Contemporary Latin',
            8224 => 'Tones|Ringtones|Latin|Latin Jazz',
            8225 => 'Tones|Ringtones|Latin|Latin Urban',
            8226 => 'Tones|Ringtones|Latin|Pop in Spanish',
            8227 => 'Tones|Ringtones|Latin|Raices',
            8228 => 'Tones|Ringtones|Latin|Musica Mexicana', # (M&uacute;sica Mexicana)
            8229 => 'Tones|Ringtones|Latin|Salsa y Tropical',
            8230 => 'Tones|Ringtones|Marching Bands',
            8231 => 'Tones|Ringtones|New Age|Healing',
            8232 => 'Tones|Ringtones|New Age|Meditation',
            8233 => 'Tones|Ringtones|New Age|Nature',
            8234 => 'Tones|Ringtones|New Age|Relaxation',
            8235 => 'Tones|Ringtones|New Age|Travel',
            8236 => 'Tones|Ringtones|Orchestral',
            8237 => 'Tones|Ringtones|Pop|Adult Contemporary',
            8238 => 'Tones|Ringtones|Pop|Britpop',
            8239 => 'Tones|Ringtones|Pop|C-Pop',
            8240 => 'Tones|Ringtones|Pop|Cantopop/HK-Pop',
            8241 => 'Tones|Ringtones|Pop|Indo Pop',
            8242 => 'Tones|Ringtones|Pop|Korean Folk-Pop',
            8243 => 'Tones|Ringtones|Pop|Malaysian Pop',
            8244 => 'Tones|Ringtones|Pop|Mandopop',
            8245 => 'Tones|Ringtones|Pop|Manilla Sound',
            8246 => 'Tones|Ringtones|Pop|Oldies',
            8247 => 'Tones|Ringtones|Pop|Original Pilipino Music',
            8248 => 'Tones|Ringtones|Pop|Pinoy Pop',
            8249 => 'Tones|Ringtones|Pop|Pop/Rock',
            8250 => 'Tones|Ringtones|Pop|Soft Rock',
            8251 => 'Tones|Ringtones|Pop|Tai-Pop',
            8252 => 'Tones|Ringtones|Pop|Teen Pop',
            8253 => 'Tones|Ringtones|Pop|Thai Pop',
            8254 => 'Tones|Ringtones|R&B/Soul|Contemporary R&B',
            8255 => 'Tones|Ringtones|R&B/Soul|Disco',
            8256 => 'Tones|Ringtones|R&B/Soul|Doo Wop',
            8257 => 'Tones|Ringtones|R&B/Soul|Funk',
            8258 => 'Tones|Ringtones|R&B/Soul|Motown',
            8259 => 'Tones|Ringtones|R&B/Soul|Neo-Soul',
            8260 => 'Tones|Ringtones|R&B/Soul|Soul',
            8261 => 'Tones|Ringtones|Reggae|Modern Dancehall',
            8262 => 'Tones|Ringtones|Reggae|Dub',
            8263 => 'Tones|Ringtones|Reggae|Roots Reggae',
            8264 => 'Tones|Ringtones|Reggae|Ska',
            8265 => 'Tones|Ringtones|Rock|Adult Alternative',
            8266 => 'Tones|Ringtones|Rock|American Trad Rock',
            8267 => 'Tones|Ringtones|Rock|Arena Rock',
            8268 => 'Tones|Ringtones|Rock|Blues-Rock',
            8269 => 'Tones|Ringtones|Rock|British Invasion',
            8270 => 'Tones|Ringtones|Rock|Chinese Rock',
            8271 => 'Tones|Ringtones|Rock|Death Metal/Black Metal',
            8272 => 'Tones|Ringtones|Rock|Glam Rock',
            8273 => 'Tones|Ringtones|Rock|Hair Metal',
            8274 => 'Tones|Ringtones|Rock|Hard Rock',
            8275 => 'Tones|Ringtones|Rock|Metal',
            8276 => 'Tones|Ringtones|Rock|Jam Bands',
            8277 => 'Tones|Ringtones|Rock|Korean Rock',
            8278 => 'Tones|Ringtones|Rock|Prog-Rock/Art Rock',
            8279 => 'Tones|Ringtones|Rock|Psychedelic',
            8280 => 'Tones|Ringtones|Rock|Rock & Roll',
            8281 => 'Tones|Ringtones|Rock|Rockabilly',
            8282 => 'Tones|Ringtones|Rock|Roots Rock',
            8283 => 'Tones|Ringtones|Rock|Singer/Songwriter',
            8284 => 'Tones|Ringtones|Rock|Southern Rock',
            8285 => 'Tones|Ringtones|Rock|Surf',
            8286 => 'Tones|Ringtones|Rock|Tex-Mex',
            8287 => 'Tones|Ringtones|Singer/Songwriter|Alternative Folk',
            8288 => 'Tones|Ringtones|Singer/Songwriter|Contemporary Folk',
            8289 => 'Tones|Ringtones|Singer/Songwriter|Contemporary Singer/Songwriter',
            8290 => 'Tones|Ringtones|Singer/Songwriter|Folk-Rock',
            8291 => 'Tones|Ringtones|Singer/Songwriter|New Acoustic',
            8292 => 'Tones|Ringtones|Singer/Songwriter|Traditional Folk',
            8293 => 'Tones|Ringtones|Soundtrack|Foreign Cinema',
            8294 => 'Tones|Ringtones|Soundtrack|Musicals',
            8295 => 'Tones|Ringtones|Soundtrack|Original Score',
            8296 => 'Tones|Ringtones|Soundtrack|Sound Effects',
            8297 => 'Tones|Ringtones|Soundtrack|Soundtrack',
            8298 => 'Tones|Ringtones|Soundtrack|TV Soundtrack',
            8299 => 'Tones|Ringtones|Vocal|Standards',
            8300 => 'Tones|Ringtones|Vocal|Traditional Pop',
            8301 => 'Tones|Ringtones|Vocal|Trot',
            8302 => 'Tones|Ringtones|Jazz|Vocal Jazz',
            8303 => 'Tones|Ringtones|Vocal|Vocal Pop',
            8304 => 'Tones|Ringtones|African',
            8305 => 'Tones|Ringtones|African|Afrikaans',
            8306 => 'Tones|Ringtones|African|Afro-Beat',
            8307 => 'Tones|Ringtones|African|Afro-Pop',
            8308 => 'Tones|Ringtones|Turkish|Arabesque',
            8309 => 'Tones|Ringtones|World|Asia',
            8310 => 'Tones|Ringtones|World|Australia',
            8311 => 'Tones|Ringtones|World|Cajun',
            8312 => 'Tones|Ringtones|World|Calypso',
            8313 => 'Tones|Ringtones|World|Caribbean',
            8314 => 'Tones|Ringtones|World|Celtic',
            8315 => 'Tones|Ringtones|World|Celtic Folk',
            8316 => 'Tones|Ringtones|World|Contemporary Celtic',
            8317 => 'Tones|Ringtones|World|Dangdut',
            8318 => 'Tones|Ringtones|World|Dini',
            8319 => 'Tones|Ringtones|World|Europe',
            8320 => 'Tones|Ringtones|World|Fado',
            8321 => 'Tones|Ringtones|World|Farsi',
            8322 => 'Tones|Ringtones|World|Flamenco',
            8323 => 'Tones|Ringtones|World|France',
            8324 => 'Tones|Ringtones|Turkish|Halk',
            8325 => 'Tones|Ringtones|World|Hawaii',
            8326 => 'Tones|Ringtones|World|Iberia',
            8327 => 'Tones|Ringtones|World|Indonesian Religious',
            8328 => 'Tones|Ringtones|World|Israeli',
            8329 => 'Tones|Ringtones|World|Japan',
            8330 => 'Tones|Ringtones|World|Klezmer',
            8331 => 'Tones|Ringtones|World|North America',
            8332 => 'Tones|Ringtones|World|Polka',
            8333 => 'Tones|Ringtones|Russian',
            8334 => 'Tones|Ringtones|Russian|Russian Chanson',
            8335 => 'Tones|Ringtones|Turkish|Sanat',
            8336 => 'Tones|Ringtones|World|Soca',
            8337 => 'Tones|Ringtones|World|South Africa',
            8338 => 'Tones|Ringtones|World|South America',
            8339 => 'Tones|Ringtones|World|Tango',
            8340 => 'Tones|Ringtones|World|Traditional Celtic',
            8341 => 'Tones|Ringtones|Turkish',
            8342 => 'Tones|Ringtones|World|Worldbeat',
            8343 => 'Tones|Ringtones|World|Zydeco',
            8345 => 'Tones|Ringtones|Classical|Art Song',
            8346 => 'Tones|Ringtones|Classical|Brass & Woodwinds',
            8347 => 'Tones|Ringtones|Classical|Solo Instrumental',
            8348 => 'Tones|Ringtones|Classical|Contemporary Era',
            8349 => 'Tones|Ringtones|Classical|Oratorio',
            8350 => 'Tones|Ringtones|Classical|Cantata',
            8351 => 'Tones|Ringtones|Classical|Electronic',
            8352 => 'Tones|Ringtones|Classical|Sacred',
            8353 => 'Tones|Ringtones|Classical|Guitar',
            8354 => 'Tones|Ringtones|Classical|Piano',
            8355 => 'Tones|Ringtones|Classical|Violin',
            8356 => 'Tones|Ringtones|Classical|Cello',
            8357 => 'Tones|Ringtones|Classical|Percussion',
            8358 => 'Tones|Ringtones|Electronic|Dubstep',
            8359 => 'Tones|Ringtones|Electronic|Bass',
            8360 => 'Tones|Ringtones|Hip-Hop/Rap|UK Hip Hop',
            8361 => 'Tones|Ringtones|Reggae|Lovers Rock',
            8362 => 'Tones|Ringtones|Alternative|EMO',
            8363 => 'Tones|Ringtones|Alternative|Pop Punk',
            8364 => 'Tones|Ringtones|Alternative|Indie Pop',
            8365 => 'Tones|Ringtones|New Age|Yoga',
            8366 => 'Tones|Ringtones|Pop|Tribute',
            8367 => 'Tones|Ringtones|Pop|Shows',
            8368 => 'Tones|Ringtones|Cuban',
            8369 => 'Tones|Ringtones|Cuban|Mambo',
            8370 => 'Tones|Ringtones|Cuban|Chachacha',
            8371 => 'Tones|Ringtones|Cuban|Guajira',
            8372 => 'Tones|Ringtones|Cuban|Son',
            8373 => 'Tones|Ringtones|Cuban|Bolero',
            8374 => 'Tones|Ringtones|Cuban|Guaracha',
            8375 => 'Tones|Ringtones|Cuban|Timba',
            8376 => 'Tones|Ringtones|Soundtrack|Video Game',
            8377 => 'Tones|Ringtones|Indian|Regional Indian|Punjabi|Punjabi Pop',
            8378 => 'Tones|Ringtones|Indian|Regional Indian|Bengali|Rabindra Sangeet',
            8379 => 'Tones|Ringtones|Indian|Regional Indian|Malayalam',
            8380 => 'Tones|Ringtones|Indian|Regional Indian|Kannada',
            8381 => 'Tones|Ringtones|Indian|Regional Indian|Marathi',
            8382 => 'Tones|Ringtones|Indian|Regional Indian|Gujarati',
            8383 => 'Tones|Ringtones|Indian|Regional Indian|Assamese',
            8384 => 'Tones|Ringtones|Indian|Regional Indian|Bhojpuri',
            8385 => 'Tones|Ringtones|Indian|Regional Indian|Haryanvi',
            8386 => 'Tones|Ringtones|Indian|Regional Indian|Odia',
            8387 => 'Tones|Ringtones|Indian|Regional Indian|Rajasthani',
            8388 => 'Tones|Ringtones|Indian|Regional Indian|Urdu',
            8389 => 'Tones|Ringtones|Indian|Regional Indian|Punjabi',
            8390 => 'Tones|Ringtones|Indian|Regional Indian|Bengali',
            8391 => 'Tones|Ringtones|Indian|Indian Classical|Carnatic Classical',
            8392 => 'Tones|Ringtones|Indian|Indian Classical|Hindustani Classical',
            8393 => 'Tones|Ringtones|African|Afro House',
            8394 => 'Tones|Ringtones|African|Afro Soul',
            8395 => 'Tones|Ringtones|African|Afrobeats',
            8396 => 'Tones|Ringtones|African|Benga',
            8397 => 'Tones|Ringtones|African|Bongo-Flava',
            8398 => 'Tones|Ringtones|African|Coupe-Decale',
            8399 => 'Tones|Ringtones|African|Gqom',
            8400 => 'Tones|Ringtones|African|Highlife',
            8401 => 'Tones|Ringtones|African|Kuduro',
            8402 => 'Tones|Ringtones|African|Kizomba',
            8403 => 'Tones|Ringtones|African|Kwaito',
            8404 => 'Tones|Ringtones|African|Mbalax',
            8405 => 'Tones|Ringtones|African|Ndombolo',
            8406 => 'Tones|Ringtones|African|Shangaan Electro',
            8407 => 'Tones|Ringtones|African|Soukous',
            8408 => 'Tones|Ringtones|African|Taarab',
            8409 => 'Tones|Ringtones|African|Zouglou',
            8410 => 'Tones|Ringtones|Turkish|Ozgun',
            8411 => 'Tones|Ringtones|Turkish|Fantezi',
            8412 => 'Tones|Ringtones|Turkish|Religious',
            8413 => 'Tones|Ringtones|Pop|Turkish Pop',
            8414 => 'Tones|Ringtones|Rock|Turkish Rock',
            8415 => 'Tones|Ringtones|Alternative|Turkish Alternative',
            8416 => 'Tones|Ringtones|Hip-Hop/Rap|Turkish Hip-Hop/Rap',
            8417 => 'Tones|Ringtones|African|Maskandi',
            8418 => 'Tones|Ringtones|Russian|Russian Romance',
            8419 => 'Tones|Ringtones|Russian|Russian Bard',
            8420 => 'Tones|Ringtones|Russian|Russian Pop',
            8421 => 'Tones|Ringtones|Russian|Russian Rock',
            8422 => 'Tones|Ringtones|Russian|Russian Hip-Hop',
            8423 => 'Tones|Ringtones|Arabic|Levant',
            8424 => 'Tones|Ringtones|Arabic|Levant|Dabke',
            8425 => 'Tones|Ringtones|Arabic|Maghreb Rai',
            8426 => 'Tones|Ringtones|Arabic|Khaleeji|Khaleeji Jalsat',
            8427 => 'Tones|Ringtones|Arabic|Khaleeji|Khaleeji Shailat',
            8428 => 'Tones|Ringtones|Tarab',
            8429 => 'Tones|Ringtones|Tarab|Iraqi Tarab',
            8430 => 'Tones|Ringtones|Tarab|Egyptian Tarab',
            8431 => 'Tones|Ringtones|Tarab|Khaleeji Tarab',
            8432 => 'Tones|Ringtones|Pop|Levant Pop',
            8433 => 'Tones|Ringtones|Pop|Iraqi Pop',
            8434 => 'Tones|Ringtones|Pop|Egyptian Pop',
            8435 => 'Tones|Ringtones|Pop|Maghreb Pop',
            8436 => 'Tones|Ringtones|Pop|Khaleeji Pop',
            8437 => 'Tones|Ringtones|Hip-Hop/Rap|Levant Hip-Hop',
            8438 => 'Tones|Ringtones|Hip-Hop/Rap|Egyptian Hip-Hop',
            8439 => 'Tones|Ringtones|Hip-Hop/Rap|Maghreb Hip-Hop',
            8440 => 'Tones|Ringtones|Hip-Hop/Rap|Khaleeji Hip-Hop',
            8441 => 'Tones|Ringtones|Alternative|Indie Levant',
            8442 => 'Tones|Ringtones|Alternative|Indie Egyptian',
            8443 => 'Tones|Ringtones|Alternative|Indie Maghreb',
            8444 => 'Tones|Ringtones|Electronic|Levant Electronic',
            8445 => "Tones|Ringtones|Electronic|Electro-Cha'abi",
            8446 => 'Tones|Ringtones|Electronic|Maghreb Electronic',
            8447 => 'Tones|Ringtones|Folk|Iraqi Folk',
            8448 => 'Tones|Ringtones|Folk|Khaleeji Folk',
            8449 => 'Tones|Ringtones|Dance|Maghreb Dance',
            9002 => 'Books|Nonfiction',
            9003 => 'Books|Romance',
            9004 => 'Books|Travel & Adventure',
            9007 => 'Books|Arts & Entertainment',
            9008 => 'Books|Biographies & Memoirs',
            9009 => 'Books|Business & Personal Finance',
            9010 => 'Books|Children & Teens',
            9012 => 'Books|Humor',
            9015 => 'Books|History',
            9018 => 'Books|Religion & Spirituality',
            9019 => 'Books|Science & Nature',
            9020 => 'Books|Sci-Fi & Fantasy',
            9024 => 'Books|Lifestyle & Home',
            9025 => 'Books|Self-Development',
            9026 => 'Books|Comics & Graphic Novels',
            9027 => 'Books|Computers & Internet',
            9028 => 'Books|Cookbooks, Food & Wine',
            9029 => 'Books|Professional & Technical',
            9030 => 'Books|Parenting',
            9031 => 'Books|Fiction & Literature',
            9032 => 'Books|Mysteries & Thrillers',
            9033 => 'Books|Reference',
            9034 => 'Books|Politics & Current Events',
            9035 => 'Books|Sports & Outdoors',
            10001 => 'Books|Lifestyle & Home|Antiques & Collectibles',
            10002 => 'Books|Arts & Entertainment|Art & Architecture',
            10003 => 'Books|Religion & Spirituality|Bibles',
            10004 => 'Books|Self-Development|Spirituality',
            10005 => 'Books|Business & Personal Finance|Industries & Professions',
            10006 => 'Books|Business & Personal Finance|Marketing & Sales',
            10007 => 'Books|Business & Personal Finance|Small Business & Entrepreneurship',
            10008 => 'Books|Business & Personal Finance|Personal Finance',
            10009 => 'Books|Business & Personal Finance|Reference',
            10010 => 'Books|Business & Personal Finance|Careers',
            10011 => 'Books|Business & Personal Finance|Economics',
            10012 => 'Books|Business & Personal Finance|Investing',
            10013 => 'Books|Business & Personal Finance|Finance',
            10014 => 'Books|Business & Personal Finance|Management & Leadership',
            10015 => 'Books|Comics & Graphic Novels|Graphic Novels',
            10016 => 'Books|Comics & Graphic Novels|Manga',
            10017 => 'Books|Computers & Internet|Computers',
            10018 => 'Books|Computers & Internet|Databases',
            10019 => 'Books|Computers & Internet|Digital Media',
            10020 => 'Books|Computers & Internet|Internet',
            10021 => 'Books|Computers & Internet|Network',
            10022 => 'Books|Computers & Internet|Operating Systems',
            10023 => 'Books|Computers & Internet|Programming',
            10024 => 'Books|Computers & Internet|Software',
            10025 => 'Books|Computers & Internet|System Administration',
            10026 => 'Books|Cookbooks, Food & Wine|Beverages',
            10027 => 'Books|Cookbooks, Food & Wine|Courses & Dishes',
            10028 => 'Books|Cookbooks, Food & Wine|Special Diet',
            10029 => 'Books|Cookbooks, Food & Wine|Special Occasions',
            10030 => 'Books|Cookbooks, Food & Wine|Methods',
            10031 => 'Books|Cookbooks, Food & Wine|Reference',
            10032 => 'Books|Cookbooks, Food & Wine|Regional & Ethnic',
            10033 => 'Books|Cookbooks, Food & Wine|Specific Ingredients',
            10034 => 'Books|Lifestyle & Home|Crafts & Hobbies',
            10035 => 'Books|Professional & Technical|Design',
            10036 => 'Books|Arts & Entertainment|Theater',
            10037 => 'Books|Professional & Technical|Education',
            10038 => 'Books|Nonfiction|Family & Relationships',
            10039 => 'Books|Fiction & Literature|Action & Adventure',
            10040 => 'Books|Fiction & Literature|African American',
            10041 => 'Books|Fiction & Literature|Religious',
            10042 => 'Books|Fiction & Literature|Classics',
            10043 => 'Books|Fiction & Literature|Erotica',
            10044 => 'Books|Sci-Fi & Fantasy|Fantasy',
            10045 => 'Books|Fiction & Literature|Gay',
            10046 => 'Books|Fiction & Literature|Ghost',
            10047 => 'Books|Fiction & Literature|Historical',
            10048 => 'Books|Fiction & Literature|Horror',
            10049 => 'Books|Fiction & Literature|Literary',
            10050 => 'Books|Mysteries & Thrillers|Hard-Boiled',
            10051 => 'Books|Mysteries & Thrillers|Historical',
            10052 => 'Books|Mysteries & Thrillers|Police Procedural',
            10053 => 'Books|Mysteries & Thrillers|Short Stories',
            10054 => 'Books|Mysteries & Thrillers|British Detectives',
            10055 => 'Books|Mysteries & Thrillers|Women Sleuths',
            10056 => 'Books|Romance|Erotic Romance',
            10057 => 'Books|Romance|Contemporary',
            10058 => 'Books|Romance|Paranormal',
            10059 => 'Books|Romance|Historical',
            10060 => 'Books|Romance|Short Stories',
            10061 => 'Books|Romance|Suspense',
            10062 => 'Books|Romance|Western',
            10063 => 'Books|Sci-Fi & Fantasy|Science Fiction',
            10064 => 'Books|Sci-Fi & Fantasy|Science Fiction & Literature',
            10065 => 'Books|Fiction & Literature|Short Stories',
            10066 => 'Books|Reference|Foreign Languages',
            10067 => 'Books|Arts & Entertainment|Games',
            10068 => 'Books|Lifestyle & Home|Gardening',
            10069 => 'Books|Self-Development|Health & Fitness',
            10070 => 'Books|History|Africa',
            10071 => 'Books|History|Americas',
            10072 => 'Books|History|Ancient',
            10073 => 'Books|History|Asia',
            10074 => 'Books|History|Australia & Oceania',
            10075 => 'Books|History|Europe',
            10076 => 'Books|History|Latin America',
            10077 => 'Books|History|Middle East',
            10078 => 'Books|History|Military',
            10079 => 'Books|History|United States',
            10080 => 'Books|History|World',
            10081 => "Books|Children & Teens|Children's Fiction",
            10082 => "Books|Children & Teens|Children's Nonfiction",
            10083 => 'Books|Professional & Technical|Law',
            10084 => 'Books|Fiction & Literature|Literary Criticism',
            10085 => 'Books|Science & Nature|Mathematics',
            10086 => 'Books|Professional & Technical|Medical',
            10087 => 'Books|Arts & Entertainment|Music',
            10088 => 'Books|Science & Nature|Nature',
            10089 => 'Books|Arts & Entertainment|Performing Arts',
            10090 => 'Books|Lifestyle & Home|Pets',
            10091 => 'Books|Nonfiction|Philosophy',
            10092 => 'Books|Arts & Entertainment|Photography',
            10093 => 'Books|Fiction & Literature|Poetry',
            10094 => 'Books|Self-Development|Psychology',
            10095 => 'Books|Reference|Almanacs & Yearbooks',
            10096 => 'Books|Reference|Atlases & Maps',
            10097 => 'Books|Reference|Catalogs & Directories',
            10098 => 'Books|Reference|Consumer Guides',
            10099 => 'Books|Reference|Dictionaries & Thesauruses',
            10100 => 'Books|Reference|Encyclopedias',
            10101 => 'Books|Reference|Etiquette',
            10102 => 'Books|Reference|Quotations',
            10103 => 'Books|Reference|Words & Language',
            10104 => 'Books|Reference|Writing',
            10105 => 'Books|Religion & Spirituality|Bible Studies',
            10106 => 'Books|Religion & Spirituality|Buddhism',
            10107 => 'Books|Religion & Spirituality|Christianity',
            10108 => 'Books|Religion & Spirituality|Hinduism',
            10109 => 'Books|Religion & Spirituality|Islam',
            10110 => 'Books|Religion & Spirituality|Judaism',
            10111 => 'Books|Science & Nature|Astronomy',
            10112 => 'Books|Science & Nature|Chemistry',
            10113 => 'Books|Science & Nature|Earth Sciences',
            10114 => 'Books|Science & Nature|Essays',
            10115 => 'Books|Science & Nature|History',
            10116 => 'Books|Science & Nature|Life Sciences',
            10117 => 'Books|Science & Nature|Physics',
            10118 => 'Books|Science & Nature|Reference',
            10119 => 'Books|Self-Development|Self-Improvement',
            10120 => 'Books|Nonfiction|Social Science',
            10121 => 'Books|Sports & Outdoors|Baseball',
            10122 => 'Books|Sports & Outdoors|Basketball',
            10123 => 'Books|Sports & Outdoors|Coaching',
            10124 => 'Books|Sports & Outdoors|Extreme Sports',
            10125 => 'Books|Sports & Outdoors|Football',
            10126 => 'Books|Sports & Outdoors|Golf',
            10127 => 'Books|Sports & Outdoors|Hockey',
            10128 => 'Books|Sports & Outdoors|Mountaineering',
            10129 => 'Books|Sports & Outdoors|Outdoors',
            10130 => 'Books|Sports & Outdoors|Racket Sports',
            10131 => 'Books|Sports & Outdoors|Reference',
            10132 => 'Books|Sports & Outdoors|Soccer',
            10133 => 'Books|Sports & Outdoors|Training',
            10134 => 'Books|Sports & Outdoors|Water Sports',
            10135 => 'Books|Sports & Outdoors|Winter Sports',
            10136 => 'Books|Reference|Study Aids',
            10137 => 'Books|Professional & Technical|Engineering',
            10138 => 'Books|Nonfiction|Transportation',
            10139 => 'Books|Travel & Adventure|Africa',
            10140 => 'Books|Travel & Adventure|Asia',
            10141 => 'Books|Travel & Adventure|Specialty Travel',
            10142 => 'Books|Travel & Adventure|Canada',
            10143 => 'Books|Travel & Adventure|Caribbean',
            10144 => 'Books|Travel & Adventure|Latin America',
            10145 => 'Books|Travel & Adventure|Essays & Memoirs',
            10146 => 'Books|Travel & Adventure|Europe',
            10147 => 'Books|Travel & Adventure|Middle East',
            10148 => 'Books|Travel & Adventure|United States',
            10149 => 'Books|Nonfiction|True Crime',
            11001 => 'Books|Sci-Fi & Fantasy|Fantasy|Contemporary',
            11002 => 'Books|Sci-Fi & Fantasy|Fantasy|Epic',
            11003 => 'Books|Sci-Fi & Fantasy|Fantasy|Historical',
            11004 => 'Books|Sci-Fi & Fantasy|Fantasy|Paranormal',
            11005 => 'Books|Sci-Fi & Fantasy|Fantasy|Short Stories',
            11006 => 'Books|Sci-Fi & Fantasy|Science Fiction & Literature|Adventure',
            11007 => 'Books|Sci-Fi & Fantasy|Science Fiction & Literature|High Tech',
            11008 => 'Books|Sci-Fi & Fantasy|Science Fiction & Literature|Short Stories',
            11009 => 'Books|Professional & Technical|Education|Language Arts & Disciplines',
            11010 => 'Books|Communications & Media',
            11011 => 'Books|Communications & Media|Broadcasting',
            11012 => 'Books|Communications & Media|Digital Media',
            11013 => 'Books|Communications & Media|Journalism',
            11014 => 'Books|Communications & Media|Photojournalism',
            11015 => 'Books|Communications & Media|Print',
            11016 => 'Books|Communications & Media|Speech',
            11017 => 'Books|Communications & Media|Writing',
            11018 => 'Books|Arts & Entertainment|Art & Architecture|Urban Planning',
            11019 => 'Books|Arts & Entertainment|Dance',
            11020 => 'Books|Arts & Entertainment|Fashion',
            11021 => 'Books|Arts & Entertainment|Film',
            11022 => 'Books|Arts & Entertainment|Interior Design',
            11023 => 'Books|Arts & Entertainment|Media Arts',
            11024 => 'Books|Arts & Entertainment|Radio',
            11025 => 'Books|Arts & Entertainment|TV',
            11026 => 'Books|Arts & Entertainment|Visual Arts',
            11027 => 'Books|Biographies & Memoirs|Arts & Entertainment',
            11028 => 'Books|Biographies & Memoirs|Business',
            11029 => 'Books|Biographies & Memoirs|Culinary',
            11030 => 'Books|Biographies & Memoirs|Gay & Lesbian',
            11031 => 'Books|Biographies & Memoirs|Historical',
            11032 => 'Books|Biographies & Memoirs|Literary',
            11033 => 'Books|Biographies & Memoirs|Media & Journalism',
            11034 => 'Books|Biographies & Memoirs|Military',
            11035 => 'Books|Biographies & Memoirs|Politics',
            11036 => 'Books|Biographies & Memoirs|Religious',
            11037 => 'Books|Biographies & Memoirs|Science & Technology',
            11038 => 'Books|Biographies & Memoirs|Sports',
            11039 => 'Books|Biographies & Memoirs|Women',
            11040 => 'Books|Romance|New Adult',
            11042 => 'Books|Romance|Romantic Comedy',
            11043 => 'Books|Romance|Gay & Lesbian',
            11044 => 'Books|Fiction & Literature|Essays',
            11045 => 'Books|Fiction & Literature|Anthologies',
            11046 => 'Books|Fiction & Literature|Comparative Literature',
            11047 => 'Books|Fiction & Literature|Drama',
            11049 => 'Books|Fiction & Literature|Fairy Tales, Myths & Fables',
            11050 => 'Books|Fiction & Literature|Family',
            11051 => 'Books|Comics & Graphic Novels|Manga|School Drama',
            11052 => 'Books|Comics & Graphic Novels|Manga|Human Drama',
            11053 => 'Books|Comics & Graphic Novels|Manga|Family Drama',
            11054 => 'Books|Sports & Outdoors|Boxing',
            11055 => 'Books|Sports & Outdoors|Cricket',
            11056 => 'Books|Sports & Outdoors|Cycling',
            11057 => 'Books|Sports & Outdoors|Equestrian',
            11058 => 'Books|Sports & Outdoors|Martial Arts & Self Defense',
            11059 => 'Books|Sports & Outdoors|Motor Sports',
            11060 => 'Books|Sports & Outdoors|Rugby',
            11061 => 'Books|Sports & Outdoors|Running',
            11062 => 'Books|Self-Development|Diet & Nutrition',
            11063 => 'Books|Science & Nature|Agriculture',
            11064 => 'Books|Science & Nature|Atmosphere',
            11065 => 'Books|Science & Nature|Biology',
            11066 => 'Books|Science & Nature|Ecology',
            11067 => 'Books|Science & Nature|Environment',
            11068 => 'Books|Science & Nature|Geography',
            11069 => 'Books|Science & Nature|Geology',
            11070 => 'Books|Nonfiction|Social Science|Anthropology',
            11071 => 'Books|Nonfiction|Social Science|Archaeology',
            11072 => 'Books|Nonfiction|Social Science|Civics',
            11073 => 'Books|Nonfiction|Social Science|Government',
            11074 => 'Books|Nonfiction|Social Science|Social Studies',
            11075 => 'Books|Nonfiction|Social Science|Social Welfare',
            11076 => 'Books|Nonfiction|Social Science|Society',
            11077 => 'Books|Nonfiction|Philosophy|Aesthetics',
            11078 => 'Books|Nonfiction|Philosophy|Epistemology',
            11079 => 'Books|Nonfiction|Philosophy|Ethics',
            11080 => 'Books|Nonfiction|Philosophy|Language',
            11081 => 'Books|Nonfiction|Philosophy|Logic',
            11082 => 'Books|Nonfiction|Philosophy|Metaphysics',
            11083 => 'Books|Nonfiction|Philosophy|Political',
            11084 => 'Books|Nonfiction|Philosophy|Religion',
            11085 => 'Books|Reference|Manuals',
            11086 => 'Books|Kids',
            11087 => 'Books|Kids|Animals',
            11088 => 'Books|Kids|Basic Concepts',
            11089 => 'Books|Kids|Basic Concepts|Alphabet',
            11090 => 'Books|Kids|Basic Concepts|Body',
            11091 => 'Books|Kids|Basic Concepts|Colors',
            11092 => 'Books|Kids|Basic Concepts|Counting & Numbers',
            11093 => 'Books|Kids|Basic Concepts|Date & Time',
            11094 => 'Books|Kids|Basic Concepts|General',
            11095 => 'Books|Kids|Basic Concepts|Money',
            11096 => 'Books|Kids|Basic Concepts|Opposites',
            11097 => 'Books|Kids|Basic Concepts|Seasons',
            11098 => 'Books|Kids|Basic Concepts|Senses & Sensation',
            11099 => 'Books|Kids|Basic Concepts|Size & Shape',
            11100 => 'Books|Kids|Basic Concepts|Sounds',
            11101 => 'Books|Kids|Basic Concepts|Words',
            11102 => 'Books|Kids|Biography',
            11103 => 'Books|Kids|Careers & Occupations',
            11104 => 'Books|Kids|Computers & Technology',
            11105 => 'Books|Kids|Cooking & Food',
            11106 => 'Books|Kids|Arts & Entertainment',
            11107 => 'Books|Kids|Arts & Entertainment|Art',
            11108 => 'Books|Kids|Arts & Entertainment|Crafts',
            11109 => 'Books|Kids|Arts & Entertainment|Music',
            11110 => 'Books|Kids|Arts & Entertainment|Performing Arts',
            11111 => 'Books|Kids|Family',
            11112 => 'Books|Kids|Fiction',
            11113 => 'Books|Kids|Fiction|Action & Adventure',
            11114 => 'Books|Kids|Fiction|Animals',
            11115 => 'Books|Kids|Fiction|Classics',
            11116 => 'Books|Kids|Fiction|Comics & Graphic Novels',
            11117 => 'Books|Kids|Fiction|Culture, Places & People',
            11118 => 'Books|Kids|Fiction|Family & Relationships',
            11119 => 'Books|Kids|Fiction|Fantasy',
            11120 => 'Books|Kids|Fiction|Fairy Tales, Myths & Fables',
            11121 => 'Books|Kids|Fiction|Favorite Characters',
            11122 => 'Books|Kids|Fiction|Historical',
            11123 => 'Books|Kids|Fiction|Holidays & Celebrations',
            11124 => 'Books|Kids|Fiction|Monsters & Ghosts',
            11125 => 'Books|Kids|Fiction|Mysteries',
            11126 => 'Books|Kids|Fiction|Nature',
            11127 => 'Books|Kids|Fiction|Religion',
            11128 => 'Books|Kids|Fiction|Sci-Fi',
            11129 => 'Books|Kids|Fiction|Social Issues',
            11130 => 'Books|Kids|Fiction|Sports & Recreation',
            11131 => 'Books|Kids|Fiction|Transportation',
            11132 => 'Books|Kids|Games & Activities',
            11133 => 'Books|Kids|General Nonfiction',
            11134 => 'Books|Kids|Health',
            11135 => 'Books|Kids|History',
            11136 => 'Books|Kids|Holidays & Celebrations',
            11137 => 'Books|Kids|Holidays & Celebrations|Birthdays',
            11138 => 'Books|Kids|Holidays & Celebrations|Christmas & Advent',
            11139 => 'Books|Kids|Holidays & Celebrations|Easter & Lent',
            11140 => 'Books|Kids|Holidays & Celebrations|General',
            11141 => 'Books|Kids|Holidays & Celebrations|Halloween',
            11142 => 'Books|Kids|Holidays & Celebrations|Hanukkah',
            11143 => 'Books|Kids|Holidays & Celebrations|Other',
            11144 => 'Books|Kids|Holidays & Celebrations|Passover',
            11145 => 'Books|Kids|Holidays & Celebrations|Patriotic Holidays',
            11146 => 'Books|Kids|Holidays & Celebrations|Ramadan',
            11147 => 'Books|Kids|Holidays & Celebrations|Thanksgiving',
            11148 => "Books|Kids|Holidays & Celebrations|Valentine's Day",
            11149 => 'Books|Kids|Humor',
            11150 => 'Books|Kids|Humor|Jokes & Riddles',
            11151 => 'Books|Kids|Poetry',
            11152 => 'Books|Kids|Learning to Read',
            11153 => 'Books|Kids|Learning to Read|Chapter Books',
            11154 => 'Books|Kids|Learning to Read|Early Readers',
            11155 => 'Books|Kids|Learning to Read|Intermediate Readers',
            11156 => 'Books|Kids|Nursery Rhymes',
            11157 => 'Books|Kids|Government',
            11158 => 'Books|Kids|Reference',
            11159 => 'Books|Kids|Religion',
            11160 => 'Books|Kids|Science & Nature',
            11161 => 'Books|Kids|Social Issues',
            11162 => 'Books|Kids|Social Studies',
            11163 => 'Books|Kids|Sports & Recreation',
            11164 => 'Books|Kids|Transportation',
            11165 => 'Books|Young Adult',
            11166 => 'Books|Young Adult|Animals',
            11167 => 'Books|Young Adult|Biography',
            11168 => 'Books|Young Adult|Careers & Occupations',
            11169 => 'Books|Young Adult|Computers & Technology',
            11170 => 'Books|Young Adult|Cooking & Food',
            11171 => 'Books|Young Adult|Arts & Entertainment',
            11172 => 'Books|Young Adult|Arts & Entertainment|Art',
            11173 => 'Books|Young Adult|Arts & Entertainment|Crafts',
            11174 => 'Books|Young Adult|Arts & Entertainment|Music',
            11175 => 'Books|Young Adult|Arts & Entertainment|Performing Arts',
            11176 => 'Books|Young Adult|Family',
            11177 => 'Books|Young Adult|Fiction',
            11178 => 'Books|Young Adult|Fiction|Action & Adventure',
            11179 => 'Books|Young Adult|Fiction|Animals',
            11180 => 'Books|Young Adult|Fiction|Classics',
            11181 => 'Books|Young Adult|Fiction|Comics & Graphic Novels',
            11182 => 'Books|Young Adult|Fiction|Culture, Places & People',
            11183 => 'Books|Young Adult|Fiction|Dystopian',
            11184 => 'Books|Young Adult|Fiction|Family & Relationships',
            11185 => 'Books|Young Adult|Fiction|Fantasy',
            11186 => 'Books|Young Adult|Fiction|Fairy Tales, Myths & Fables',
            11187 => 'Books|Young Adult|Fiction|Favorite Characters',
            11188 => 'Books|Young Adult|Fiction|Historical',
            11189 => 'Books|Young Adult|Fiction|Holidays & Celebrations',
            11190 => 'Books|Young Adult|Fiction|Horror, Monsters & Ghosts',
            11191 => 'Books|Young Adult|Fiction|Crime & Mystery',
            11192 => 'Books|Young Adult|Fiction|Nature',
            11193 => 'Books|Young Adult|Fiction|Religion',
            11194 => 'Books|Young Adult|Fiction|Romance',
            11195 => 'Books|Young Adult|Fiction|Sci-Fi',
            11196 => 'Books|Young Adult|Fiction|Coming of Age',
            11197 => 'Books|Young Adult|Fiction|Sports & Recreation',
            11198 => 'Books|Young Adult|Fiction|Transportation',
            11199 => 'Books|Young Adult|Games & Activities',
            11200 => 'Books|Young Adult|General Nonfiction',
            11201 => 'Books|Young Adult|Health',
            11202 => 'Books|Young Adult|History',
            11203 => 'Books|Young Adult|Holidays & Celebrations',
            11204 => 'Books|Young Adult|Holidays & Celebrations|Birthdays',
            11205 => 'Books|Young Adult|Holidays & Celebrations|Christmas & Advent',
            11206 => 'Books|Young Adult|Holidays & Celebrations|Easter & Lent',
            11207 => 'Books|Young Adult|Holidays & Celebrations|General',
            11208 => 'Books|Young Adult|Holidays & Celebrations|Halloween',
            11209 => 'Books|Young Adult|Holidays & Celebrations|Hanukkah',
            11210 => 'Books|Young Adult|Holidays & Celebrations|Other',
            11211 => 'Books|Young Adult|Holidays & Celebrations|Passover',
            11212 => 'Books|Young Adult|Holidays & Celebrations|Patriotic Holidays',
            11213 => 'Books|Young Adult|Holidays & Celebrations|Ramadan',
            11214 => 'Books|Young Adult|Holidays & Celebrations|Thanksgiving',
            11215 => "Books|Young Adult|Holidays & Celebrations|Valentine's Day",
            11216 => 'Books|Young Adult|Humor',
            11217 => 'Books|Young Adult|Humor|Jokes & Riddles',
            11218 => 'Books|Young Adult|Poetry',
            11219 => 'Books|Young Adult|Politics & Government',
            11220 => 'Books|Young Adult|Reference',
            11221 => 'Books|Young Adult|Religion',
            11222 => 'Books|Young Adult|Science & Nature',
            11223 => 'Books|Young Adult|Coming of Age',
            11224 => 'Books|Young Adult|Social Studies',
            11225 => 'Books|Young Adult|Sports & Recreation',
            11226 => 'Books|Young Adult|Transportation',
            11227 => 'Books|Communications & Media',
            11228 => 'Books|Military & Warfare',
            11229 => 'Books|Romance|Inspirational',
            11231 => 'Books|Romance|Holiday',
            11232 => 'Books|Romance|Wholesome',
            11233 => 'Books|Romance|Military',
            11234 => 'Books|Arts & Entertainment|Art History',
            11236 => 'Books|Arts & Entertainment|Design',
            11243 => 'Books|Business & Personal Finance|Accounting',
            11244 => 'Books|Business & Personal Finance|Hospitality',
            11245 => 'Books|Business & Personal Finance|Real Estate',
            11246 => 'Books|Humor|Jokes & Riddles',
            11247 => 'Books|Religion & Spirituality|Comparative Religion',
            11255 => 'Books|Cookbooks, Food & Wine|Culinary Arts',
            11259 => 'Books|Mysteries & Thrillers|Cozy',
            11260 => 'Books|Politics & Current Events|Current Events',
            11261 => 'Books|Politics & Current Events|Foreign Policy & International Relations',
            11262 => 'Books|Politics & Current Events|Local Government',
            11263 => 'Books|Politics & Current Events|National Government',
            11264 => 'Books|Politics & Current Events|Political Science',
            11265 => 'Books|Politics & Current Events|Public Administration',
            11266 => 'Books|Politics & Current Events|World Affairs',
            11273 => 'Books|Nonfiction|Family & Relationships|Family & Childcare',
            11274 => 'Books|Nonfiction|Family & Relationships|Love & Romance',
            11275 => 'Books|Sci-Fi & Fantasy|Fantasy|Urban',
            11276 => 'Books|Reference|Foreign Languages|Arabic',
            11277 => 'Books|Reference|Foreign Languages|Bilingual Editions',
            11278 => 'Books|Reference|Foreign Languages|African Languages',
            11279 => 'Books|Reference|Foreign Languages|Ancient Languages',
            11280 => 'Books|Reference|Foreign Languages|Chinese',
            11281 => 'Books|Reference|Foreign Languages|English',
            11282 => 'Books|Reference|Foreign Languages|French',
            11283 => 'Books|Reference|Foreign Languages|German',
            11284 => 'Books|Reference|Foreign Languages|Hebrew',
            11285 => 'Books|Reference|Foreign Languages|Hindi',
            11286 => 'Books|Reference|Foreign Languages|Italian',
            11287 => 'Books|Reference|Foreign Languages|Japanese',
            11288 => 'Books|Reference|Foreign Languages|Korean',
            11289 => 'Books|Reference|Foreign Languages|Linguistics',
            11290 => 'Books|Reference|Foreign Languages|Other Languages',
            11291 => 'Books|Reference|Foreign Languages|Portuguese',
            11292 => 'Books|Reference|Foreign Languages|Russian',
            11293 => 'Books|Reference|Foreign Languages|Spanish',
            11294 => 'Books|Reference|Foreign Languages|Speech Pathology',
            11295 => 'Books|Science & Nature|Mathematics|Advanced Mathematics',
            11296 => 'Books|Science & Nature|Mathematics|Algebra',
            11297 => 'Books|Science & Nature|Mathematics|Arithmetic',
            11298 => 'Books|Science & Nature|Mathematics|Calculus',
            11299 => 'Books|Science & Nature|Mathematics|Geometry',
            11300 => 'Books|Science & Nature|Mathematics|Statistics',
            11301 => 'Books|Professional & Technical|Medical|Veterinary',
            11302 => 'Books|Professional & Technical|Medical|Neuroscience',
            11303 => 'Books|Professional & Technical|Medical|Immunology',
            11304 => 'Books|Professional & Technical|Medical|Nursing',
            11305 => 'Books|Professional & Technical|Medical|Pharmacology & Toxicology',
            11306 => 'Books|Professional & Technical|Medical|Anatomy & Physiology',
            11307 => 'Books|Professional & Technical|Medical|Dentistry',
            11308 => 'Books|Professional & Technical|Medical|Emergency Medicine',
            11309 => 'Books|Professional & Technical|Medical|Genetics',
            11310 => 'Books|Professional & Technical|Medical|Psychiatry',
            11311 => 'Books|Professional & Technical|Medical|Radiology',
            11312 => 'Books|Professional & Technical|Medical|Alternative Medicine',
            11317 => 'Books|Nonfiction|Philosophy|Political Philosophy',
            11319 => 'Books|Nonfiction|Philosophy|Philosophy of Language',
            11320 => 'Books|Nonfiction|Philosophy|Philosophy of Religion',
            11327 => 'Books|Nonfiction|Social Science|Sociology',
            11329 => 'Books|Professional & Technical|Engineering|Aeronautics',
            11330 => 'Books|Professional & Technical|Engineering|Chemical & Petroleum Engineering',
            11331 => 'Books|Professional & Technical|Engineering|Civil Engineering',
            11332 => 'Books|Professional & Technical|Engineering|Computer Science',
            11333 => 'Books|Professional & Technical|Engineering|Electrical Engineering',
            11334 => 'Books|Professional & Technical|Engineering|Environmental Engineering',
            11335 => 'Books|Professional & Technical|Engineering|Mechanical Engineering',
            11336 => 'Books|Professional & Technical|Engineering|Power Resources',
            11337 => 'Books|Comics & Graphic Novels|Manga|Boys',
            11338 => 'Books|Comics & Graphic Novels|Manga|Men',
            11339 => 'Books|Comics & Graphic Novels|Manga|Girls',
            11340 => 'Books|Comics & Graphic Novels|Manga|Women',
            11341 => 'Books|Comics & Graphic Novels|Manga|Other',
            11342 => 'Books|Comics & Graphic Novels|Manga|Yaoi',
            11343 => 'Books|Comics & Graphic Novels|Manga|Comic Essays',
            12001 => 'Mac App Store|Business',
            12002 => 'Mac App Store|Developer Tools',
            12003 => 'Mac App Store|Education',
            12004 => 'Mac App Store|Entertainment',
            12005 => 'Mac App Store|Finance',
            12006 => 'Mac App Store|Games',
            12007 => 'Mac App Store|Health & Fitness',
            12008 => 'Mac App Store|Lifestyle',
            12010 => 'Mac App Store|Medical',
            12011 => 'Mac App Store|Music',
            12012 => 'Mac App Store|News',
            12013 => 'Mac App Store|Photography',
            12014 => 'Mac App Store|Productivity',
            12015 => 'Mac App Store|Reference',
            12016 => 'Mac App Store|Social Networking',
            12017 => 'Mac App Store|Sports',
            12018 => 'Mac App Store|Travel',
            12019 => 'Mac App Store|Utilities',
            12020 => 'Mac App Store|Video',
            12021 => 'Mac App Store|Weather',
            12022 => 'Mac App Store|Graphics & Design',
            12201 => 'Mac App Store|Games|Action',
            12202 => 'Mac App Store|Games|Adventure',
            12203 => 'Mac App Store|Games|Casual',
            12204 => 'Mac App Store|Games|Board',
            12205 => 'Mac App Store|Games|Card',
            12206 => 'Mac App Store|Games|Casino',
            12207 => 'Mac App Store|Games|Dice',
            12208 => 'Mac App Store|Games|Educational',
            12209 => 'Mac App Store|Games|Family',
            12210 => 'Mac App Store|Games|Kids',
            12211 => 'Mac App Store|Games|Music',
            12212 => 'Mac App Store|Games|Puzzle',
            12213 => 'Mac App Store|Games|Racing',
            12214 => 'Mac App Store|Games|Role Playing',
            12215 => 'Mac App Store|Games|Simulation',
            12216 => 'Mac App Store|Games|Sports',
            12217 => 'Mac App Store|Games|Strategy',
            12218 => 'Mac App Store|Games|Trivia',
            12219 => 'Mac App Store|Games|Word',
            13001 => 'App Store|Magazines & Newspapers|News & Politics',
            13002 => 'App Store|Magazines & Newspapers|Fashion & Style',
            13003 => 'App Store|Magazines & Newspapers|Home & Garden',
            13004 => 'App Store|Magazines & Newspapers|Outdoors & Nature',
            13005 => 'App Store|Magazines & Newspapers|Sports & Leisure',
            13006 => 'App Store|Magazines & Newspapers|Automotive',
            13007 => 'App Store|Magazines & Newspapers|Arts & Photography',
            13008 => 'App Store|Magazines & Newspapers|Brides & Weddings',
            13009 => 'App Store|Magazines & Newspapers|Business & Investing',
            13010 => "App Store|Magazines & Newspapers|Children's Magazines",
            13011 => 'App Store|Magazines & Newspapers|Computers & Internet',
            13012 => 'App Store|Magazines & Newspapers|Cooking, Food & Drink',
            13013 => 'App Store|Magazines & Newspapers|Crafts & Hobbies',
            13014 => 'App Store|Magazines & Newspapers|Electronics & Audio',
            13015 => 'App Store|Magazines & Newspapers|Entertainment',
            13017 => 'App Store|Magazines & Newspapers|Health, Mind & Body',
            13018 => 'App Store|Magazines & Newspapers|History',
            13019 => 'App Store|Magazines & Newspapers|Literary Magazines & Journals',
            13020 => "App Store|Magazines & Newspapers|Men's Interest",
            13021 => 'App Store|Magazines & Newspapers|Movies & Music',
            13023 => 'App Store|Magazines & Newspapers|Parenting & Family',
            13024 => 'App Store|Magazines & Newspapers|Pets',
            13025 => 'App Store|Magazines & Newspapers|Professional & Trade',
            13026 => 'App Store|Magazines & Newspapers|Regional News',
            13027 => 'App Store|Magazines & Newspapers|Science',
            13028 => 'App Store|Magazines & Newspapers|Teens',
            13029 => 'App Store|Magazines & Newspapers|Travel & Regional',
            13030 => "App Store|Magazines & Newspapers|Women's Interest",
            15000 => 'Textbooks|Arts & Entertainment',
            15001 => 'Textbooks|Arts & Entertainment|Art & Architecture',
            15002 => 'Textbooks|Arts & Entertainment|Art & Architecture|Urban Planning',
            15003 => 'Textbooks|Arts & Entertainment|Art History',
            15004 => 'Textbooks|Arts & Entertainment|Dance',
            15005 => 'Textbooks|Arts & Entertainment|Design',
            15006 => 'Textbooks|Arts & Entertainment|Fashion',
            15007 => 'Textbooks|Arts & Entertainment|Film',
            15008 => 'Textbooks|Arts & Entertainment|Games',
            15009 => 'Textbooks|Arts & Entertainment|Interior Design',
            15010 => 'Textbooks|Arts & Entertainment|Media Arts',
            15011 => 'Textbooks|Arts & Entertainment|Music',
            15012 => 'Textbooks|Arts & Entertainment|Performing Arts',
            15013 => 'Textbooks|Arts & Entertainment|Photography',
            15014 => 'Textbooks|Arts & Entertainment|Theater',
            15015 => 'Textbooks|Arts & Entertainment|TV',
            15016 => 'Textbooks|Arts & Entertainment|Visual Arts',
            15017 => 'Textbooks|Biographies & Memoirs',
            15018 => 'Textbooks|Business & Personal Finance',
            15019 => 'Textbooks|Business & Personal Finance|Accounting',
            15020 => 'Textbooks|Business & Personal Finance|Careers',
            15021 => 'Textbooks|Business & Personal Finance|Economics',
            15022 => 'Textbooks|Business & Personal Finance|Finance',
            15023 => 'Textbooks|Business & Personal Finance|Hospitality',
            15024 => 'Textbooks|Business & Personal Finance|Industries & Professions',
            15025 => 'Textbooks|Business & Personal Finance|Investing',
            15026 => 'Textbooks|Business & Personal Finance|Management & Leadership',
            15027 => 'Textbooks|Business & Personal Finance|Marketing & Sales',
            15028 => 'Textbooks|Business & Personal Finance|Personal Finance',
            15029 => 'Textbooks|Business & Personal Finance|Real Estate',
            15030 => 'Textbooks|Business & Personal Finance|Reference',
            15031 => 'Textbooks|Business & Personal Finance|Small Business & Entrepreneurship',
            15032 => 'Textbooks|Children & Teens',
            15033 => 'Textbooks|Children & Teens|Fiction',
            15034 => 'Textbooks|Children & Teens|Nonfiction',
            15035 => 'Textbooks|Comics & Graphic Novels',
            15036 => 'Textbooks|Comics & Graphic Novels|Graphic Novels',
            15037 => 'Textbooks|Comics & Graphic Novels|Manga',
            15038 => 'Textbooks|Communications & Media',
            15039 => 'Textbooks|Communications & Media|Broadcasting',
            15040 => 'Textbooks|Communications & Media|Digital Media',
            15041 => 'Textbooks|Communications & Media|Journalism',
            15042 => 'Textbooks|Communications & Media|Photojournalism',
            15043 => 'Textbooks|Communications & Media|Print',
            15044 => 'Textbooks|Communications & Media|Speech',
            15045 => 'Textbooks|Communications & Media|Writing',
            15046 => 'Textbooks|Computers & Internet',
            15047 => 'Textbooks|Computers & Internet|Computers',
            15048 => 'Textbooks|Computers & Internet|Databases',
            15049 => 'Textbooks|Computers & Internet|Digital Media',
            15050 => 'Textbooks|Computers & Internet|Internet',
            15051 => 'Textbooks|Computers & Internet|Network',
            15052 => 'Textbooks|Computers & Internet|Operating Systems',
            15053 => 'Textbooks|Computers & Internet|Programming',
            15054 => 'Textbooks|Computers & Internet|Software',
            15055 => 'Textbooks|Computers & Internet|System Administration',
            15056 => 'Textbooks|Cookbooks, Food & Wine',
            15057 => 'Textbooks|Cookbooks, Food & Wine|Beverages',
            15058 => 'Textbooks|Cookbooks, Food & Wine|Courses & Dishes',
            15059 => 'Textbooks|Cookbooks, Food & Wine|Culinary Arts',
            15060 => 'Textbooks|Cookbooks, Food & Wine|Methods',
            15061 => 'Textbooks|Cookbooks, Food & Wine|Reference',
            15062 => 'Textbooks|Cookbooks, Food & Wine|Regional & Ethnic',
            15063 => 'Textbooks|Cookbooks, Food & Wine|Special Diet',
            15064 => 'Textbooks|Cookbooks, Food & Wine|Special Occasions',
            15065 => 'Textbooks|Cookbooks, Food & Wine|Specific Ingredients',
            15066 => 'Textbooks|Engineering',
            15067 => 'Textbooks|Engineering|Aeronautics',
            15068 => 'Textbooks|Engineering|Chemical & Petroleum Engineering',
            15069 => 'Textbooks|Engineering|Civil Engineering',
            15070 => 'Textbooks|Engineering|Computer Science',
            15071 => 'Textbooks|Engineering|Electrical Engineering',
            15072 => 'Textbooks|Engineering|Environmental Engineering',
            15073 => 'Textbooks|Engineering|Mechanical Engineering',
            15074 => 'Textbooks|Engineering|Power Resources',
            15075 => 'Textbooks|Fiction & Literature',
            15076 => 'Textbooks|Fiction & Literature|Latino',
            15077 => 'Textbooks|Fiction & Literature|Action & Adventure',
            15078 => 'Textbooks|Fiction & Literature|African American',
            15079 => 'Textbooks|Fiction & Literature|Anthologies',
            15080 => 'Textbooks|Fiction & Literature|Classics',
            15081 => 'Textbooks|Fiction & Literature|Comparative Literature',
            15082 => 'Textbooks|Fiction & Literature|Erotica',
            15083 => 'Textbooks|Fiction & Literature|Gay',
            15084 => 'Textbooks|Fiction & Literature|Ghost',
            15085 => 'Textbooks|Fiction & Literature|Historical',
            15086 => 'Textbooks|Fiction & Literature|Horror',
            15087 => 'Textbooks|Fiction & Literature|Literary',
            15088 => 'Textbooks|Fiction & Literature|Literary Criticism',
            15089 => 'Textbooks|Fiction & Literature|Poetry',
            15090 => 'Textbooks|Fiction & Literature|Religious',
            15091 => 'Textbooks|Fiction & Literature|Short Stories',
            15092 => 'Textbooks|Health, Mind & Body',
            15093 => 'Textbooks|Health, Mind & Body|Fitness',
            15094 => 'Textbooks|Health, Mind & Body|Self-Improvement',
            15095 => 'Textbooks|History',
            15096 => 'Textbooks|History|Africa',
            15097 => 'Textbooks|History|Americas',
            15098 => 'Textbooks|History|Americas|Canada',
            15099 => 'Textbooks|History|Americas|Latin America',
            15100 => 'Textbooks|History|Americas|United States',
            15101 => 'Textbooks|History|Ancient',
            15102 => 'Textbooks|History|Asia',
            15103 => 'Textbooks|History|Australia & Oceania',
            15104 => 'Textbooks|History|Europe',
            15105 => 'Textbooks|History|Middle East',
            15106 => 'Textbooks|History|Military',
            15107 => 'Textbooks|History|World',
            15108 => 'Textbooks|Humor',
            15109 => 'Textbooks|Language Studies',
            15110 => 'Textbooks|Language Studies|African Languages',
            15111 => 'Textbooks|Language Studies|Ancient Languages',
            15112 => 'Textbooks|Language Studies|Arabic',
            15113 => 'Textbooks|Language Studies|Bilingual Editions',
            15114 => 'Textbooks|Language Studies|Chinese',
            15115 => 'Textbooks|Language Studies|English',
            15116 => 'Textbooks|Language Studies|French',
            15117 => 'Textbooks|Language Studies|German',
            15118 => 'Textbooks|Language Studies|Hebrew',
            15119 => 'Textbooks|Language Studies|Hindi',
            15120 => 'Textbooks|Language Studies|Indigenous Languages',
            15121 => 'Textbooks|Language Studies|Italian',
            15122 => 'Textbooks|Language Studies|Japanese',
            15123 => 'Textbooks|Language Studies|Korean',
            15124 => 'Textbooks|Language Studies|Linguistics',
            15125 => 'Textbooks|Language Studies|Other Language',
            15126 => 'Textbooks|Language Studies|Portuguese',
            15127 => 'Textbooks|Language Studies|Russian',
            15128 => 'Textbooks|Language Studies|Spanish',
            15129 => 'Textbooks|Language Studies|Speech Pathology',
            15130 => 'Textbooks|Lifestyle & Home',
            15131 => 'Textbooks|Lifestyle & Home|Antiques & Collectibles',
            15132 => 'Textbooks|Lifestyle & Home|Crafts & Hobbies',
            15133 => 'Textbooks|Lifestyle & Home|Gardening',
            15134 => 'Textbooks|Lifestyle & Home|Pets',
            15135 => 'Textbooks|Mathematics',
            15136 => 'Textbooks|Mathematics|Advanced Mathematics',
            15137 => 'Textbooks|Mathematics|Algebra',
            15138 => 'Textbooks|Mathematics|Arithmetic',
            15139 => 'Textbooks|Mathematics|Calculus',
            15140 => 'Textbooks|Mathematics|Geometry',
            15141 => 'Textbooks|Mathematics|Statistics',
            15142 => 'Textbooks|Medicine',
            15143 => 'Textbooks|Medicine|Anatomy & Physiology',
            15144 => 'Textbooks|Medicine|Dentistry',
            15145 => 'Textbooks|Medicine|Emergency Medicine',
            15146 => 'Textbooks|Medicine|Genetics',
            15147 => 'Textbooks|Medicine|Immunology',
            15148 => 'Textbooks|Medicine|Neuroscience',
            15149 => 'Textbooks|Medicine|Nursing',
            15150 => 'Textbooks|Medicine|Pharmacology & Toxicology',
            15151 => 'Textbooks|Medicine|Psychiatry',
            15152 => 'Textbooks|Medicine|Psychology',
            15153 => 'Textbooks|Medicine|Radiology',
            15154 => 'Textbooks|Medicine|Veterinary',
            15155 => 'Textbooks|Mysteries & Thrillers',
            15156 => 'Textbooks|Mysteries & Thrillers|British Detectives',
            15157 => 'Textbooks|Mysteries & Thrillers|Hard-Boiled',
            15158 => 'Textbooks|Mysteries & Thrillers|Historical',
            15159 => 'Textbooks|Mysteries & Thrillers|Police Procedural',
            15160 => 'Textbooks|Mysteries & Thrillers|Short Stories',
            15161 => 'Textbooks|Mysteries & Thrillers|Women Sleuths',
            15162 => 'Textbooks|Nonfiction',
            15163 => 'Textbooks|Nonfiction|Family & Relationships',
            15164 => 'Textbooks|Nonfiction|Transportation',
            15165 => 'Textbooks|Nonfiction|True Crime',
            15166 => 'Textbooks|Parenting',
            15167 => 'Textbooks|Philosophy',
            15168 => 'Textbooks|Philosophy|Aesthetics',
            15169 => 'Textbooks|Philosophy|Epistemology',
            15170 => 'Textbooks|Philosophy|Ethics',
            15171 => 'Textbooks|Philosophy|Philosophy of Language',
            15172 => 'Textbooks|Philosophy|Logic',
            15173 => 'Textbooks|Philosophy|Metaphysics',
            15174 => 'Textbooks|Philosophy|Political Philosophy',
            15175 => 'Textbooks|Philosophy|Philosophy of Religion',
            15176 => 'Textbooks|Politics & Current Events',
            15177 => 'Textbooks|Politics & Current Events|Current Events',
            15178 => 'Textbooks|Politics & Current Events|Foreign Policy & International Relations',
            15179 => 'Textbooks|Politics & Current Events|Local Governments',
            15180 => 'Textbooks|Politics & Current Events|National Governments',
            15181 => 'Textbooks|Politics & Current Events|Political Science',
            15182 => 'Textbooks|Politics & Current Events|Public Administration',
            15183 => 'Textbooks|Politics & Current Events|World Affairs',
            15184 => 'Textbooks|Professional & Technical',
            15185 => 'Textbooks|Professional & Technical|Design',
            15186 => 'Textbooks|Professional & Technical|Language Arts & Disciplines',
            15187 => 'Textbooks|Professional & Technical|Engineering',
            15188 => 'Textbooks|Professional & Technical|Law',
            15189 => 'Textbooks|Professional & Technical|Medical',
            15190 => 'Textbooks|Reference',
            15191 => 'Textbooks|Reference|Almanacs & Yearbooks',
            15192 => 'Textbooks|Reference|Atlases & Maps',
            15193 => 'Textbooks|Reference|Catalogs & Directories',
            15194 => 'Textbooks|Reference|Consumer Guides',
            15195 => 'Textbooks|Reference|Dictionaries & Thesauruses',
            15196 => 'Textbooks|Reference|Encyclopedias',
            15197 => 'Textbooks|Reference|Etiquette',
            15198 => 'Textbooks|Reference|Quotations',
            15199 => 'Textbooks|Reference|Study Aids',
            15200 => 'Textbooks|Reference|Words & Language',
            15201 => 'Textbooks|Reference|Writing',
            15202 => 'Textbooks|Religion & Spirituality',
            15203 => 'Textbooks|Religion & Spirituality|Bible Studies',
            15204 => 'Textbooks|Religion & Spirituality|Bibles',
            15205 => 'Textbooks|Religion & Spirituality|Buddhism',
            15206 => 'Textbooks|Religion & Spirituality|Christianity',
            15207 => 'Textbooks|Religion & Spirituality|Comparative Religion',
            15208 => 'Textbooks|Religion & Spirituality|Hinduism',
            15209 => 'Textbooks|Religion & Spirituality|Islam',
            15210 => 'Textbooks|Religion & Spirituality|Judaism',
            15211 => 'Textbooks|Religion & Spirituality|Spirituality',
            15212 => 'Textbooks|Romance',
            15213 => 'Textbooks|Romance|Contemporary',
            15214 => 'Textbooks|Romance|Erotic Romance',
            15215 => 'Textbooks|Romance|Paranormal',
            15216 => 'Textbooks|Romance|Historical',
            15217 => 'Textbooks|Romance|Short Stories',
            15218 => 'Textbooks|Romance|Suspense',
            15219 => 'Textbooks|Romance|Western',
            15220 => 'Textbooks|Sci-Fi & Fantasy',
            15221 => 'Textbooks|Sci-Fi & Fantasy|Fantasy',
            15222 => 'Textbooks|Sci-Fi & Fantasy|Fantasy|Contemporary',
            15223 => 'Textbooks|Sci-Fi & Fantasy|Fantasy|Epic',
            15224 => 'Textbooks|Sci-Fi & Fantasy|Fantasy|Historical',
            15225 => 'Textbooks|Sci-Fi & Fantasy|Fantasy|Paranormal',
            15226 => 'Textbooks|Sci-Fi & Fantasy|Fantasy|Short Stories',
            15227 => 'Textbooks|Sci-Fi & Fantasy|Science Fiction',
            15228 => 'Textbooks|Sci-Fi & Fantasy|Science Fiction & Literature',
            15229 => 'Textbooks|Sci-Fi & Fantasy|Science Fiction & Literature|Adventure',
            15230 => 'Textbooks|Sci-Fi & Fantasy|Science Fiction & Literature|High Tech',
            15231 => 'Textbooks|Sci-Fi & Fantasy|Science Fiction & Literature|Short Stories',
            15232 => 'Textbooks|Science & Nature',
            15233 => 'Textbooks|Science & Nature|Agriculture',
            15234 => 'Textbooks|Science & Nature|Astronomy',
            15235 => 'Textbooks|Science & Nature|Atmosphere',
            15236 => 'Textbooks|Science & Nature|Biology',
            15237 => 'Textbooks|Science & Nature|Chemistry',
            15238 => 'Textbooks|Science & Nature|Earth Sciences',
            15239 => 'Textbooks|Science & Nature|Ecology',
            15240 => 'Textbooks|Science & Nature|Environment',
            15241 => 'Textbooks|Science & Nature|Essays',
            15242 => 'Textbooks|Science & Nature|Geography',
            15243 => 'Textbooks|Science & Nature|Geology',
            15244 => 'Textbooks|Science & Nature|History',
            15245 => 'Textbooks|Science & Nature|Life Sciences',
            15246 => 'Textbooks|Science & Nature|Nature',
            15247 => 'Textbooks|Science & Nature|Physics',
            15248 => 'Textbooks|Science & Nature|Reference',
            15249 => 'Textbooks|Social Science',
            15250 => 'Textbooks|Social Science|Anthropology',
            15251 => 'Textbooks|Social Science|Archaeology',
            15252 => 'Textbooks|Social Science|Civics',
            15253 => 'Textbooks|Social Science|Government',
            15254 => 'Textbooks|Social Science|Social Studies',
            15255 => 'Textbooks|Social Science|Social Welfare',
            15256 => 'Textbooks|Social Science|Society',
            15257 => 'Textbooks|Social Science|Society|African Studies',
            15258 => 'Textbooks|Social Science|Society|American Studies',
            15259 => 'Textbooks|Social Science|Society|Asia Pacific Studies',
            15260 => 'Textbooks|Social Science|Society|Cross-Cultural Studies',
            15261 => 'Textbooks|Social Science|Society|European Studies',
            15262 => 'Textbooks|Social Science|Society|Immigration & Emigration',
            15263 => 'Textbooks|Social Science|Society|Indigenous Studies',
            15264 => 'Textbooks|Social Science|Society|Latin & Caribbean Studies',
            15265 => 'Textbooks|Social Science|Society|Middle Eastern Studies',
            15266 => 'Textbooks|Social Science|Society|Race & Ethnicity Studies',
            15267 => 'Textbooks|Social Science|Society|Sexuality Studies',
            15268 => "Textbooks|Social Science|Society|Women's Studies",
            15269 => 'Textbooks|Social Science|Sociology',
            15270 => 'Textbooks|Sports & Outdoors',
            15271 => 'Textbooks|Sports & Outdoors|Baseball',
            15272 => 'Textbooks|Sports & Outdoors|Basketball',
            15273 => 'Textbooks|Sports & Outdoors|Coaching',
            15274 => 'Textbooks|Sports & Outdoors|Equestrian',
            15275 => 'Textbooks|Sports & Outdoors|Extreme Sports',
            15276 => 'Textbooks|Sports & Outdoors|Football',
            15277 => 'Textbooks|Sports & Outdoors|Golf',
            15278 => 'Textbooks|Sports & Outdoors|Hockey',
            15279 => 'Textbooks|Sports & Outdoors|Motor Sports',
            15280 => 'Textbooks|Sports & Outdoors|Mountaineering',
            15281 => 'Textbooks|Sports & Outdoors|Outdoors',
            15282 => 'Textbooks|Sports & Outdoors|Racket Sports',
            15283 => 'Textbooks|Sports & Outdoors|Reference',
            15284 => 'Textbooks|Sports & Outdoors|Soccer',
            15285 => 'Textbooks|Sports & Outdoors|Training',
            15286 => 'Textbooks|Sports & Outdoors|Water Sports',
            15287 => 'Textbooks|Sports & Outdoors|Winter Sports',
            15288 => 'Textbooks|Teaching & Learning',
            15289 => 'Textbooks|Teaching & Learning|Adult Education',
            15290 => 'Textbooks|Teaching & Learning|Curriculum & Teaching',
            15291 => 'Textbooks|Teaching & Learning|Educational Leadership',
            15292 => 'Textbooks|Teaching & Learning|Educational Technology',
            15293 => 'Textbooks|Teaching & Learning|Family & Childcare',
            15294 => 'Textbooks|Teaching & Learning|Information & Library Science',
            15295 => 'Textbooks|Teaching & Learning|Learning Resources',
            15296 => 'Textbooks|Teaching & Learning|Psychology & Research',
            15297 => 'Textbooks|Teaching & Learning|Special Education',
            15298 => 'Textbooks|Travel & Adventure',
            15299 => 'Textbooks|Travel & Adventure|Africa',
            15300 => 'Textbooks|Travel & Adventure|Americas',
            15301 => 'Textbooks|Travel & Adventure|Americas|Canada',
            15302 => 'Textbooks|Travel & Adventure|Americas|Latin America',
            15303 => 'Textbooks|Travel & Adventure|Americas|United States',
            15304 => 'Textbooks|Travel & Adventure|Asia',
            15305 => 'Textbooks|Travel & Adventure|Caribbean',
            15306 => 'Textbooks|Travel & Adventure|Essays & Memoirs',
            15307 => 'Textbooks|Travel & Adventure|Europe',
            15308 => 'Textbooks|Travel & Adventure|Middle East',
            15309 => 'Textbooks|Travel & Adventure|Oceania',
            15310 => 'Textbooks|Travel & Adventure|Specialty Travel',
            15311 => 'Textbooks|Comics & Graphic Novels|Comics',
            15312 => 'Textbooks|Reference|Manuals',
            16001 => 'App Store|Stickers|Emoji & Expressions',
            16003 => 'App Store|Stickers|Animals & Nature',
            16005 => 'App Store|Stickers|Art',
            16006 => 'App Store|Stickers|Celebrations',
            16007 => 'App Store|Stickers|Celebrities',
            16008 => 'App Store|Stickers|Comics & Cartoons',
            16009 => 'App Store|Stickers|Eating & Drinking',
            16010 => 'App Store|Stickers|Gaming',
            16014 => 'App Store|Stickers|Movies & TV',
            16015 => 'App Store|Stickers|Music',
            16017 => 'App Store|Stickers|People',
            16019 => 'App Store|Stickers|Places & Objects',
            16021 => 'App Store|Stickers|Sports & Activities',
            16025 => 'App Store|Stickers|Kids & Family',
            16026 => 'App Store|Stickers|Fashion',
            100000 => 'Music|Christian & Gospel',
            100001 => 'Music|Classical|Art Song',
            100002 => 'Music|Classical|Brass & Woodwinds',
            100003 => 'Music|Classical|Solo Instrumental',
            100004 => 'Music|Classical|Contemporary Era',
            100005 => 'Music|Classical|Oratorio',
            100006 => 'Music|Classical|Cantata',
            100007 => 'Music|Classical|Electronic',
            100008 => 'Music|Classical|Sacred',
            100009 => 'Music|Classical|Guitar',
            100010 => 'Music|Classical|Piano',
            100011 => 'Music|Classical|Violin',
            100012 => 'Music|Classical|Cello',
            100013 => 'Music|Classical|Percussion',
            100014 => 'Music|Electronic|Dubstep',
            100015 => 'Music|Electronic|Bass',
            100016 => 'Music|Hip-Hop/Rap|UK Hip-Hop',
            100017 => 'Music|Reggae|Lovers Rock',
            100018 => 'Music|Alternative|EMO',
            100019 => 'Music|Alternative|Pop Punk',
            100020 => 'Music|Alternative|Indie Pop',
            100021 => 'Music|New Age|Yoga',
            100022 => 'Music|Pop|Tribute',
            100023 => 'Music|Pop|Shows',
            100024 => 'Music|Cuban',
            100025 => 'Music|Cuban|Mambo',
            100026 => 'Music|Cuban|Chachacha',
            100027 => 'Music|Cuban|Guajira',
            100028 => 'Music|Cuban|Son',
            100029 => 'Music|Cuban|Bolero',
            100030 => 'Music|Cuban|Guaracha',
            100031 => 'Music|Cuban|Timba',
            100032 => 'Music|Soundtrack|Video Game',
            100033 => 'Music|Indian|Regional Indian|Punjabi|Punjabi Pop',
            100034 => 'Music|Indian|Regional Indian|Bengali|Rabindra Sangeet',
            100035 => 'Music|Indian|Regional Indian|Malayalam',
            100036 => 'Music|Indian|Regional Indian|Kannada',
            100037 => 'Music|Indian|Regional Indian|Marathi',
            100038 => 'Music|Indian|Regional Indian|Gujarati',
            100039 => 'Music|Indian|Regional Indian|Assamese',
            100040 => 'Music|Indian|Regional Indian|Bhojpuri',
            100041 => 'Music|Indian|Regional Indian|Haryanvi',
            100042 => 'Music|Indian|Regional Indian|Odia',
            100043 => 'Music|Indian|Regional Indian|Rajasthani',
            100044 => 'Music|Indian|Regional Indian|Urdu',
            100045 => 'Music|Indian|Regional Indian|Punjabi',
            100046 => 'Music|Indian|Regional Indian|Bengali',
            100047 => 'Music|Indian|Indian Classical|Carnatic Classical',
            100048 => 'Music|Indian|Indian Classical|Hindustani Classical',
            100049 => 'Music|African|Afro House',
            100050 => 'Music|African|Afro Soul',
            100051 => 'Music|African|Afrobeats',
            100052 => 'Music|African|Benga',
            100053 => 'Music|African|Bongo-Flava',
            100054 => 'Music|African|Coupe-Decale',
            100055 => 'Music|African|Gqom',
            100056 => 'Music|African|Highlife',
            100057 => 'Music|African|Kuduro',
            100058 => 'Music|African|Kizomba',
            100059 => 'Music|African|Kwaito',
            100060 => 'Music|African|Mbalax',
            100061 => 'Music|African|Ndombolo',
            100062 => 'Music|African|Shangaan Electro',
            100063 => 'Music|African|Soukous',
            100064 => 'Music|African|Taarab',
            100065 => 'Music|African|Zouglou',
            100066 => 'Music|Turkish|Ozgun',
            100067 => 'Music|Turkish|Fantezi',
            100068 => 'Music|Turkish|Religious',
            100069 => 'Music|Pop|Turkish Pop',
            100070 => 'Music|Rock|Turkish Rock',
            100071 => 'Music|Alternative|Turkish Alternative',
            100072 => 'Music|Hip-Hop/Rap|Turkish Hip-Hop/Rap',
            100073 => 'Music|African|Maskandi',
            100074 => 'Music|Russian|Russian Romance',
            100075 => 'Music|Russian|Russian Bard',
            100076 => 'Music|Russian|Russian Pop',
            100077 => 'Music|Russian|Russian Rock',
            100078 => 'Music|Russian|Russian Hip-Hop',
            100079 => 'Music|Arabic|Levant',
            100080 => 'Music|Arabic|Levant|Dabke',
            100081 => 'Music|Arabic|Maghreb Rai',
            100082 => 'Music|Arabic|Khaleeji|Khaleeji Jalsat',
            100083 => 'Music|Arabic|Khaleeji|Khaleeji Shailat',
            100084 => 'Music|Tarab',
            100085 => 'Music|Tarab|Iraqi Tarab',
            100086 => 'Music|Tarab|Egyptian Tarab',
            100087 => 'Music|Tarab|Khaleeji Tarab',
            100088 => 'Music|Pop|Levant Pop',
            100089 => 'Music|Pop|Iraqi Pop',
            100090 => 'Music|Pop|Egyptian Pop',
            100091 => 'Music|Pop|Maghreb Pop',
            100092 => 'Music|Pop|Khaleeji Pop',
            100093 => 'Music|Hip-Hop/Rap|Levant Hip-Hop',
            100094 => 'Music|Hip-Hop/Rap|Egyptian Hip-Hop',
            100095 => 'Music|Hip-Hop/Rap|Maghreb Hip-Hop',
            100096 => 'Music|Hip-Hop/Rap|Khaleeji Hip-Hop',
            100097 => 'Music|Alternative|Indie Levant',
            100098 => 'Music|Alternative|Indie Egyptian',
            100099 => 'Music|Alternative|Indie Maghreb',
            100100 => 'Music|Electronic|Levant Electronic',
            100101 => "Music|Electronic|Electro-Cha'abi",
            100102 => 'Music|Electronic|Maghreb Electronic',
            100103 => 'Music|Folk|Iraqi Folk',
            100104 => 'Music|Folk|Khaleeji Folk',
            100105 => 'Music|Dance|Maghreb Dance',
            40000000 => 'iTunes U',
            40000001 => 'iTunes U|Business & Economics',
            40000002 => 'iTunes U|Business & Economics|Economics',
            40000003 => 'iTunes U|Business & Economics|Finance',
            40000004 => 'iTunes U|Business & Economics|Hospitality',
            40000005 => 'iTunes U|Business & Economics|Management',
            40000006 => 'iTunes U|Business & Economics|Marketing',
            40000007 => 'iTunes U|Business & Economics|Personal Finance',
            40000008 => 'iTunes U|Business & Economics|Real Estate',
            40000009 => 'iTunes U|Engineering',
            40000010 => 'iTunes U|Engineering|Chemical & Petroleum Engineering',
            40000011 => 'iTunes U|Engineering|Civil Engineering',
            40000012 => 'iTunes U|Engineering|Computer Science',
            40000013 => 'iTunes U|Engineering|Electrical Engineering',
            40000014 => 'iTunes U|Engineering|Environmental Engineering',
            40000015 => 'iTunes U|Engineering|Mechanical Engineering',
            40000016 => 'iTunes U|Music, Art, & Design',
            40000017 => 'iTunes U|Music, Art, & Design|Architecture',
            40000019 => 'iTunes U|Music, Art, & Design|Art History',
            40000020 => 'iTunes U|Music, Art, & Design|Dance',
            40000021 => 'iTunes U|Music, Art, & Design|Film',
            40000022 => 'iTunes U|Music, Art, & Design|Design',
            40000023 => 'iTunes U|Music, Art, & Design|Interior Design',
            40000024 => 'iTunes U|Music, Art, & Design|Music',
            40000025 => 'iTunes U|Music, Art, & Design|Theater',
            40000026 => 'iTunes U|Health & Medicine',
            40000027 => 'iTunes U|Health & Medicine|Anatomy & Physiology',
            40000028 => 'iTunes U|Health & Medicine|Behavioral Science',
            40000029 => 'iTunes U|Health & Medicine|Dentistry',
            40000030 => 'iTunes U|Health & Medicine|Diet & Nutrition',
            40000031 => 'iTunes U|Health & Medicine|Emergency Medicine',
            40000032 => 'iTunes U|Health & Medicine|Genetics',
            40000033 => 'iTunes U|Health & Medicine|Gerontology',
            40000034 => 'iTunes U|Health & Medicine|Health & Exercise Science',
            40000035 => 'iTunes U|Health & Medicine|Immunology',
            40000036 => 'iTunes U|Health & Medicine|Neuroscience',
            40000037 => 'iTunes U|Health & Medicine|Pharmacology & Toxicology',
            40000038 => 'iTunes U|Health & Medicine|Psychiatry',
            40000039 => 'iTunes U|Health & Medicine|Global Health',
            40000040 => 'iTunes U|Health & Medicine|Radiology',
            40000041 => 'iTunes U|History',
            40000042 => 'iTunes U|History|Ancient History',
            40000043 => 'iTunes U|History|Medieval History',
            40000044 => 'iTunes U|History|Military History',
            40000045 => 'iTunes U|History|Modern History',
            40000046 => 'iTunes U|History|African History',
            40000047 => 'iTunes U|History|Asia-Pacific History',
            40000048 => 'iTunes U|History|European History',
            40000049 => 'iTunes U|History|Middle Eastern History',
            40000050 => 'iTunes U|History|North American History',
            40000051 => 'iTunes U|History|South American History',
            40000053 => 'iTunes U|Communications & Journalism',
            40000054 => 'iTunes U|Philosophy',
            40000055 => 'iTunes U|Religion & Spirituality',
            40000056 => 'iTunes U|Languages',
            40000057 => 'iTunes U|Languages|African Languages',
            40000058 => 'iTunes U|Languages|Ancient Languages',
            40000061 => 'iTunes U|Languages|English',
            40000063 => 'iTunes U|Languages|French',
            40000064 => 'iTunes U|Languages|German',
            40000065 => 'iTunes U|Languages|Italian',
            40000066 => 'iTunes U|Languages|Linguistics',
            40000068 => 'iTunes U|Languages|Spanish',
            40000069 => 'iTunes U|Languages|Speech Pathology',
            40000070 => 'iTunes U|Writing & Literature',
            40000071 => 'iTunes U|Writing & Literature|Anthologies',
            40000072 => 'iTunes U|Writing & Literature|Biography',
            40000073 => 'iTunes U|Writing & Literature|Classics',
            40000074 => 'iTunes U|Writing & Literature|Literary Criticism',
            40000075 => 'iTunes U|Writing & Literature|Fiction',
            40000076 => 'iTunes U|Writing & Literature|Poetry',
            40000077 => 'iTunes U|Mathematics',
            40000078 => 'iTunes U|Mathematics|Advanced Mathematics',
            40000079 => 'iTunes U|Mathematics|Algebra',
            40000080 => 'iTunes U|Mathematics|Arithmetic',
            40000081 => 'iTunes U|Mathematics|Calculus',
            40000082 => 'iTunes U|Mathematics|Geometry',
            40000083 => 'iTunes U|Mathematics|Statistics',
            40000084 => 'iTunes U|Science',
            40000085 => 'iTunes U|Science|Agricultural',
            40000086 => 'iTunes U|Science|Astronomy',
            40000087 => 'iTunes U|Science|Atmosphere',
            40000088 => 'iTunes U|Science|Biology',
            40000089 => 'iTunes U|Science|Chemistry',
            40000090 => 'iTunes U|Science|Ecology',
            40000091 => 'iTunes U|Science|Geography',
            40000092 => 'iTunes U|Science|Geology',
            40000093 => 'iTunes U|Science|Physics',
            40000094 => 'iTunes U|Social Science',
            40000095 => 'iTunes U|Law & Politics|Law',
            40000096 => 'iTunes U|Law & Politics|Political Science',
            40000097 => 'iTunes U|Law & Politics|Public Administration',
            40000098 => 'iTunes U|Social Science|Psychology',
            40000099 => 'iTunes U|Social Science|Social Welfare',
            40000100 => 'iTunes U|Social Science|Sociology',
            40000101 => 'iTunes U|Society',
            40000103 => 'iTunes U|Society|Asia Pacific Studies',
            40000104 => 'iTunes U|Society|European Studies',
            40000105 => 'iTunes U|Society|Indigenous Studies',
            40000106 => 'iTunes U|Society|Latin & Caribbean Studies',
            40000107 => 'iTunes U|Society|Middle Eastern Studies',
            40000108 => "iTunes U|Society|Women's Studies",
            40000109 => 'iTunes U|Teaching & Learning',
            40000110 => 'iTunes U|Teaching & Learning|Curriculum & Teaching',
            40000111 => 'iTunes U|Teaching & Learning|Educational Leadership',
            40000112 => 'iTunes U|Teaching & Learning|Family & Childcare',
            40000113 => 'iTunes U|Teaching & Learning|Learning Resources',
            40000114 => 'iTunes U|Teaching & Learning|Psychology & Research',
            40000115 => 'iTunes U|Teaching & Learning|Special Education',
            40000116 => 'iTunes U|Music, Art, & Design|Culinary Arts',
            40000117 => 'iTunes U|Music, Art, & Design|Fashion',
            40000118 => 'iTunes U|Music, Art, & Design|Media Arts',
            40000119 => 'iTunes U|Music, Art, & Design|Photography',
            40000120 => 'iTunes U|Music, Art, & Design|Visual Art',
            40000121 => 'iTunes U|Business & Economics|Entrepreneurship',
            40000122 => 'iTunes U|Communications & Journalism|Broadcasting',
            40000123 => 'iTunes U|Communications & Journalism|Digital Media',
            40000124 => 'iTunes U|Communications & Journalism|Journalism',
            40000125 => 'iTunes U|Communications & Journalism|Photojournalism',
            40000126 => 'iTunes U|Communications & Journalism|Print',
            40000127 => 'iTunes U|Communications & Journalism|Speech',
            40000128 => 'iTunes U|Communications & Journalism|Writing',
            40000129 => 'iTunes U|Health & Medicine|Nursing',
            40000130 => 'iTunes U|Languages|Arabic',
            40000131 => 'iTunes U|Languages|Chinese',
            40000132 => 'iTunes U|Languages|Hebrew',
            40000133 => 'iTunes U|Languages|Hindi',
            40000134 => 'iTunes U|Languages|Indigenous Languages',
            40000135 => 'iTunes U|Languages|Japanese',
            40000136 => 'iTunes U|Languages|Korean',
            40000137 => 'iTunes U|Languages|Other Languages',
            40000138 => 'iTunes U|Languages|Portuguese',
            40000139 => 'iTunes U|Languages|Russian',
            40000140 => 'iTunes U|Law & Politics',
            40000141 => 'iTunes U|Law & Politics|Foreign Policy & International Relations',
            40000142 => 'iTunes U|Law & Politics|Local Governments',
            40000143 => 'iTunes U|Law & Politics|National Governments',
            40000144 => 'iTunes U|Law & Politics|World Affairs',
            40000145 => 'iTunes U|Writing & Literature|Comparative Literature',
            40000146 => 'iTunes U|Philosophy|Aesthetics',
            40000147 => 'iTunes U|Philosophy|Epistemology',
            40000148 => 'iTunes U|Philosophy|Ethics',
            40000149 => 'iTunes U|Philosophy|Metaphysics',
            40000150 => 'iTunes U|Philosophy|Political Philosophy',
            40000151 => 'iTunes U|Philosophy|Logic',
            40000152 => 'iTunes U|Philosophy|Philosophy of Language',
            40000153 => 'iTunes U|Philosophy|Philosophy of Religion',
            40000154 => 'iTunes U|Social Science|Archaeology',
            40000155 => 'iTunes U|Social Science|Anthropology',
            40000156 => 'iTunes U|Religion & Spirituality|Buddhism',
            40000157 => 'iTunes U|Religion & Spirituality|Christianity',
            40000158 => 'iTunes U|Religion & Spirituality|Comparative Religion',
            40000159 => 'iTunes U|Religion & Spirituality|Hinduism',
            40000160 => 'iTunes U|Religion & Spirituality|Islam',
            40000161 => 'iTunes U|Religion & Spirituality|Judaism',
            40000162 => 'iTunes U|Religion & Spirituality|Other Religions',
            40000163 => 'iTunes U|Religion & Spirituality|Spirituality',
            40000164 => 'iTunes U|Science|Environment',
            40000165 => 'iTunes U|Society|African Studies',
            40000166 => 'iTunes U|Society|American Studies',
            40000167 => 'iTunes U|Society|Cross-cultural Studies',
            40000168 => 'iTunes U|Society|Immigration & Emigration',
            40000169 => 'iTunes U|Society|Race & Ethnicity Studies',
            40000170 => 'iTunes U|Society|Sexuality Studies',
            40000171 => 'iTunes U|Teaching & Learning|Educational Technology',
            40000172 => 'iTunes U|Teaching & Learning|Information/Library Science',
            40000173 => 'iTunes U|Languages|Dutch',
            40000174 => 'iTunes U|Languages|Luxembourgish',
            40000175 => 'iTunes U|Languages|Swedish',
            40000176 => 'iTunes U|Languages|Norwegian',
            40000177 => 'iTunes U|Languages|Finnish',
            40000178 => 'iTunes U|Languages|Danish',
            40000179 => 'iTunes U|Languages|Polish',
            40000180 => 'iTunes U|Languages|Turkish',
            40000181 => 'iTunes U|Languages|Flemish',
            50000024 => 'Audiobooks',
            50000040 => 'Audiobooks|Fiction',
            50000041 => 'Audiobooks|Arts & Entertainment',
            50000042 => 'Audiobooks|Biographies & Memoirs',
            50000043 => 'Audiobooks|Business & Personal Finance',
            50000044 => 'Audiobooks|Kids & Young Adults',
            50000045 => 'Audiobooks|Classics',
            50000046 => 'Audiobooks|Comedy',
            50000047 => 'Audiobooks|Drama & Poetry',
            50000048 => 'Audiobooks|Speakers & Storytellers',
            50000049 => 'Audiobooks|History',
            50000050 => 'Audiobooks|Languages',
            50000051 => 'Audiobooks|Mysteries & Thrillers',
            50000052 => 'Audiobooks|Nonfiction',
            50000053 => 'Audiobooks|Religion & Spirituality',
            50000054 => 'Audiobooks|Science & Nature',
            50000055 => 'Audiobooks|Sci Fi & Fantasy',
            50000056 => 'Audiobooks|Self-Development',
            50000057 => 'Audiobooks|Sports & Outdoors',
            50000058 => 'Audiobooks|Technology',
            50000059 => 'Audiobooks|Travel & Adventure',
            50000061 => 'Music|Spoken Word',
            50000063 => 'Music|Disney',
            50000064 => 'Music|French Pop',
            50000066 => 'Music|German Pop',
            50000068 => 'Music|German Folk',
            50000069 => 'Audiobooks|Romance',
            50000070 => 'Audiobooks|Audiobooks Latino',
            50000071 => 'Books|Comics & Graphic Novels|Manga|Action',
            50000072 => 'Books|Comics & Graphic Novels|Manga|Comedy',
            50000073 => 'Books|Comics & Graphic Novels|Manga|Erotica',
            50000074 => 'Books|Comics & Graphic Novels|Manga|Fantasy',
            50000075 => 'Books|Comics & Graphic Novels|Manga|Four Cell Manga',
            50000076 => 'Books|Comics & Graphic Novels|Manga|Gay & Lesbian',
            50000077 => 'Books|Comics & Graphic Novels|Manga|Hard-Boiled',
            50000078 => 'Books|Comics & Graphic Novels|Manga|Heroes',
            50000079 => 'Books|Comics & Graphic Novels|Manga|Historical Fiction',
            50000080 => 'Books|Comics & Graphic Novels|Manga|Mecha',
            50000081 => 'Books|Comics & Graphic Novels|Manga|Mystery',
            50000082 => 'Books|Comics & Graphic Novels|Manga|Nonfiction',
            50000083 => 'Books|Comics & Graphic Novels|Manga|Religious',
            50000084 => 'Books|Comics & Graphic Novels|Manga|Romance',
            50000085 => 'Books|Comics & Graphic Novels|Manga|Romantic Comedy',
            50000086 => 'Books|Comics & Graphic Novels|Manga|Science Fiction',
            50000087 => 'Books|Comics & Graphic Novels|Manga|Sports',
            50000088 => 'Books|Fiction & Literature|Light Novels',
            50000089 => 'Books|Comics & Graphic Novels|Manga|Horror',
            50000090 => 'Books|Comics & Graphic Novels|Comics',
            50000091 => 'Books|Romance|Multicultural',
            50000092 => 'Audiobooks|Erotica',
            50000093 => 'Audiobooks|Light Novels',
        },
    },
    grup => { Name => 'Grouping', Avoid => 1 }, #10
    hdvd => { #10
        Name => 'HDVideo',
        Format => 'int8u', #24
        Writable => 'int8s', #27
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    keyw => 'Keyword', #7
    ldes => 'LongDescription', #10
    pcst => { #7
        Name => 'Podcast',
        Format => 'int8u', #23
        Writable => 'int8s', #27
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    perf => 'Performer',
    plID => {
        # (ref 10 called this PlayListID or TVSeason)
        Name => 'AlbumID', #28
        Format => 'int64u',
        Writable => 'int32s', #27
    },
    purd => 'PurchaseDate', #7
    purl => 'PodcastURL', #7
    rtng => { #10
        Name => 'Rating',
        Format => 'int8u', #23
        Writable => 'int8s', #27
        PrintConv => {
            0 => 'none',
            1 => 'Explicit',
            2 => 'Clean',
            4 => 'Explicit (old)',
        },
    },
    sfID => { #10
        Name => 'AppleStoreCountry',
        Format => 'int32u',
        Writable => 'int32s', #27
        SeparateTable => 1,
        PrintConv => { #21
            143441 => 'United States', # US
            143442 => 'France', # FR
            143443 => 'Germany', # DE
            143444 => 'United Kingdom', # GB
            143445 => 'Austria', # AT
            143446 => 'Belgium', # BE
            143447 => 'Finland', # FI
            143448 => 'Greece', # GR
            143449 => 'Ireland', # IE
            143450 => 'Italy', # IT
            143451 => 'Luxembourg', # LU
            143452 => 'Netherlands', # NL
            143453 => 'Portugal', # PT
            143454 => 'Spain', # ES
            143455 => 'Canada', # CA
            143456 => 'Sweden', # SE
            143457 => 'Norway', # NO
            143458 => 'Denmark', # DK
            143459 => 'Switzerland', # CH
            143460 => 'Australia', # AU
            143461 => 'New Zealand', # NZ
            143462 => 'Japan', # JP
            143463 => 'Hong Kong', # HK
            143464 => 'Singapore', # SG
            143465 => 'China', # CN
            143466 => 'Republic of Korea', # KR
            143467 => 'India', # IN
            143468 => 'Mexico', # MX
            143469 => 'Russia', # RU
            143470 => 'Taiwan', # TW
            143471 => 'Vietnam', # VN
            143472 => 'South Africa', # ZA
            143473 => 'Malaysia', # MY
            143474 => 'Philippines', # PH
            143475 => 'Thailand', # TH
            143476 => 'Indonesia', # ID
            143477 => 'Pakistan', # PK
            143478 => 'Poland', # PL
            143479 => 'Saudi Arabia', # SA
            143480 => 'Turkey', # TR
            143481 => 'United Arab Emirates', # AE
            143482 => 'Hungary', # HU
            143483 => 'Chile', # CL
            143484 => 'Nepal', # NP
            143485 => 'Panama', # PA
            143486 => 'Sri Lanka', # LK
            143487 => 'Romania', # RO
            143489 => 'Czech Republic', # CZ
            143491 => 'Israel', # IL
            143492 => 'Ukraine', # UA
            143493 => 'Kuwait', # KW
            143494 => 'Croatia', # HR
            143495 => 'Costa Rica', # CR
            143496 => 'Slovakia', # SK
            143497 => 'Lebanon', # LB
            143498 => 'Qatar', # QA
            143499 => 'Slovenia', # SI
            143501 => 'Colombia', # CO
            143502 => 'Venezuela', # VE
            143503 => 'Brazil', # BR
            143504 => 'Guatemala', # GT
            143505 => 'Argentina', # AR
            143506 => 'El Salvador', # SV
            143507 => 'Peru', # PE
            143508 => 'Dominican Republic', # DO
            143509 => 'Ecuador', # EC
            143510 => 'Honduras', # HN
            143511 => 'Jamaica', # JM
            143512 => 'Nicaragua', # NI
            143513 => 'Paraguay', # PY
            143514 => 'Uruguay', # UY
            143515 => 'Macau', # MO
            143516 => 'Egypt', # EG
            143517 => 'Kazakhstan', # KZ
            143518 => 'Estonia', # EE
            143519 => 'Latvia', # LV
            143520 => 'Lithuania', # LT
            143521 => 'Malta', # MT
            143523 => 'Moldova', # MD
            143524 => 'Armenia', # AM
            143525 => 'Botswana', # BW
            143526 => 'Bulgaria', # BG
            143528 => 'Jordan', # JO
            143529 => 'Kenya', # KE
            143530 => 'Macedonia', # MK
            143531 => 'Madagascar', # MG
            143532 => 'Mali', # ML
            143533 => 'Mauritius', # MU
            143534 => 'Niger', # NE
            143535 => 'Senegal', # SN
            143536 => 'Tunisia', # TN
            143537 => 'Uganda', # UG
            143538 => 'Anguilla', # AI
            143539 => 'Bahamas', # BS
            143540 => 'Antigua and Barbuda', # AG
            143541 => 'Barbados', # BB
            143542 => 'Bermuda', # BM
            143543 => 'British Virgin Islands', # VG
            143544 => 'Cayman Islands', # KY
            143545 => 'Dominica', # DM
            143546 => 'Grenada', # GD
            143547 => 'Montserrat', # MS
            143548 => 'St. Kitts and Nevis', # KN
            143549 => 'St. Lucia', # LC
            143550 => 'St. Vincent and The Grenadines', # VC
            143551 => 'Trinidad and Tobago', # TT
            143552 => 'Turks and Caicos', # TC
            143553 => 'Guyana', # GY
            143554 => 'Suriname', # SR
            143555 => 'Belize', # BZ
            143556 => 'Bolivia', # BO
            143557 => 'Cyprus', # CY
            143558 => 'Iceland', # IS
            143559 => 'Bahrain', # BH
            143560 => 'Brunei Darussalam', # BN
            143561 => 'Nigeria', # NG
            143562 => 'Oman', # OM
            143563 => 'Algeria', # DZ
            143564 => 'Angola', # AO
            143565 => 'Belarus', # BY
            143566 => 'Uzbekistan', # UZ
            143568 => 'Azerbaijan', # AZ
            143571 => 'Yemen', # YE
            143572 => 'Tanzania', # TZ
            143573 => 'Ghana', # GH
            143575 => 'Albania', # AL
            143576 => 'Benin', # BJ
            143577 => 'Bhutan', # BT
            143578 => 'Burkina Faso', # BF
            143579 => 'Cambodia', # KH
            143580 => 'Cape Verde', # CV
            143581 => 'Chad', # TD
            143582 => 'Republic of the Congo', # CG
            143583 => 'Fiji', # FJ
            143584 => 'Gambia', # GM
            143585 => 'Guinea-Bissau', # GW
            143586 => 'Kyrgyzstan', # KG
            143587 => "Lao People's Democratic Republic", # LA
            143588 => 'Liberia', # LR
            143589 => 'Malawi', # MW
            143590 => 'Mauritania', # MR
            143591 => 'Federated States of Micronesia', # FM
            143592 => 'Mongolia', # MN
            143593 => 'Mozambique', # MZ
            143594 => 'Namibia', # NA
            143595 => 'Palau', # PW
            143597 => 'Papua New Guinea', # PG
            143598 => 'Sao Tome and Principe', # ST (S&atilde;o Tom&eacute; and Pr&iacute;ncipe)
            143599 => 'Seychelles', # SC
            143600 => 'Sierra Leone', # SL
            143601 => 'Solomon Islands', # SB
            143602 => 'Swaziland', # SZ
            143603 => 'Tajikistan', # TJ
            143604 => 'Turkmenistan', # TM
            143605 => 'Zimbabwe', # ZW
        },
    },
    soaa => 'SortAlbumArtist', #10
    soal => 'SortAlbum', #10
    soar => 'SortArtist', #10
    soco => 'SortComposer', #10
    sonm => 'SortName', #10
    sosn => 'SortShow', #10
    stik => { #10
        Name => 'MediaType',
        Format => 'int8u', #23
        Writable => 'int8s', #27
        PrintConvColumns => 2,
        PrintConv => { #(http://weblog.xanga.com/gryphondwb/615474010/iphone-ringtones---what-did-itunes-741-really-do.html)
            0 => 'Movie (old)', #forum9059 (was Movie)
            1 => 'Normal (Music)',
            2 => 'Audiobook',
            5 => 'Whacked Bookmark',
            6 => 'Music Video',
            9 => 'Movie', #forum9059 (was Short Film)
            10 => 'TV Show',
            11 => 'Booklet',
            14 => 'Ringtone',
            21 => 'Podcast', #15
            23 => 'iTunes U', #forum9059
        },
    },
    rate => 'RatingPercent', #PH
    titl => { Name => 'Title', Avoid => 1 },
    tven => 'TVEpisodeID', #7
    tves => { #7/10
        Name => 'TVEpisode',
        Format => 'int32u',
        Writable => 'int32s', #27
    },
    tvnn => 'TVNetworkName', #7
    tvsh => 'TVShow', #10
    tvsn => { #7/10
        Name => 'TVSeason',
        Format => 'int32u',
    },
    yrrc => 'Year', #(ffmpeg source)
    itnu => { #PH (iTunes 10.5)
        Name => 'iTunesU',
        Format => 'int8u', #27
        Writable => 'int8s', #27
        Description => 'iTunes U',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    #https://github.com/communitymedia/mediautilities/blob/master/src/net/sourceforge/jaad/mp4/boxes/BoxTypes.java
    gshh => { Name => 'GoogleHostHeader',   Format => 'string' },
    gspm => { Name => 'GooglePingMessage',  Format => 'string' },
    gspu => { Name => 'GooglePingURL',      Format => 'string' },
    gssd => { Name => 'GoogleSourceData',   Format => 'string' },
    gsst => { Name => 'GoogleStartTime',    Format => 'string' },
    gstd => {
        Name => 'GoogleTrackDuration',
        Format => 'string',
        ValueConv => '$val / 1000',
        ValueConvInv => '$val * 1000',
        PrintConv => 'ConvertDuration($val)',
        PrintConvInv => q{
            my $sign = ($val =~ s/^-//) ? -1 : 1;
            my @a = $val =~ /(\d+(?:\.\d+)?)/g;
            unshift @a, 0 while @a < 4;
            return $sign * (((($a[0] * 24) + $a[1]) * 60 + $a[2]) * 60 + $a[3]);
        },
    },

    # atoms observed in AAX audiobooks (ref PH)
    "\xa9cpy" => { Name => 'Copyright', Avoid => 1, Groups => { 2 => 'Author' } },
    "\xa9pub" => 'Publisher',
    "\xa9nrt" => 'Narrator',
    '@pti' => 'ParentTitle', # (guess -- same as "\xa9nam")
    '@PST' => 'ParentShortTitle', # (guess -- same as "\xa9nam")
    '@ppi' => 'ParentProductID', # (guess -- same as 'prID')
    '@sti' => 'ShortTitle', # (guess -- same as "\xa9nam")
    prID => 'ProductID',
    rldt => { Name => 'ReleaseDate', Groups => { 2 => 'Time' }},
    CDEK => { Name => 'Unknown_CDEK', Unknown => 1 }, # eg: "B004ZMTFEG" - used in URL's ("asin=")
    CDET => { Name => 'Unknown_CDET', Unknown => 1 }, # eg: "ADBL"
    VERS => 'ProductVersion',
    GUID => 'GUID',
    AACR => { Name => 'Unknown_AACR', Unknown => 1 }, # eg: "CR!1T1H1QH6WX7T714G2BMFX3E9MC4S"
    # ausr - 30 bytes (User Alias?)
    "\xa9xyz" => { #PH (written by Google Photos)
        Name => 'GPSCoordinates',
        Groups => { 2 => 'Location' },
        ValueConv => \&ConvertISO6709,
        ValueConvInv => \&ConvInvISO6709,
        PrintConv => \&PrintGPSCoordinates,
        PrintConvInv => \&PrintInvGPSCoordinates,
    },
    # the following tags written by iTunes 12.5.1.21
    # (ref https://www.ventismedia.com/mantis/view.php?id=14963
    #  https://community.mp3tag.de/t/x-mp4-new-tag-problems/19488)
    "\xa9wrk" => 'Work', #PH
    "\xa9mvn" => 'MovementName', #PH
    "\xa9mvi" => { #PH
        Name => 'MovementNumber',
        Format => 'int16u', #27
        Writable => 'int16s', #27
    },
    "\xa9mvc" => { #PH
        Name => 'MovementCount',
        Format => 'int16u', #27
        Writable => 'int16s', #27
    },
    shwm => { #PH
        Name => 'ShowMovement',
        Format => 'int8u', #27
        Writable => 'int8s', #27
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    ownr => 'Owner', #PH (obscure) (ref ChrisAdan private communication)
    'xid ' => 'ISRC', #PH
    # found in DJI Osmo Action4 video
    tnal => { Name => 'ThumbnailImage',  Binary => 1, Groups => { 2 => 'Preview' } },
    snal => { Name => 'PreviewImage',    Binary => 1, Groups => { 2 => 'Preview' } },
);

# tag decoded from timed face records
%Image::ExifTool::QuickTime::FaceInfo = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    crec => {
        Name => 'FaceRec',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::FaceRec',
        },
    },
);

# tag decoded from timed face records
%Image::ExifTool::QuickTime::FaceRec = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    cits => {
        Name => 'FaceItem',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Keys',
            ProcessProc => \&Process_mebx,
        },
    },
);

# item list keys (ref PH)
%Image::ExifTool::QuickTime::Keys = (
    PROCESS_PROC => \&ProcessKeys,
    WRITE_PROC => \&WriteKeys,
    CHECK_PROC => \&CheckQTValue,
    VARS => { LONG_TAGS => 8 },
    WRITABLE => 1,
    # (not PREFERRED when writing)
    GROUPS => { 1 => 'Keys' },
    WRITE_GROUP => 'Keys',
    LANG_INFO => \&GetLangInfo,
    NOTES => q{
        This directory contains a list of key names which are used to decode tags
        written by the "mdta" handler.  Also in this table are a few tags found in
        timed metadata that are not yet writable by ExifTool.  The prefix of
        "com.apple.quicktime." has been removed from the TagID's below.  These tags
        support alternate languages in the same way as the
        L<ItemList|Image::ExifTool::TagNames/QuickTime ItemList Tags> tags.  Note
        that by default,
        L<ItemList|Image::ExifTool::TagNames/QuickTime ItemList Tags> and
        L<UserData|Image::ExifTool::TagNames/QuickTime UserData Tags> tags are
        preferred when writing, so to create a tag when a same-named tag exists in
        either of these tables, either the "Keys" location must be specified (eg.
        C<-Keys:Author=Phil> on the command line), or the PREFERRED level must be
        changed via L<the config file|../config.html#PREF>.
    },
    version     => 'Version',
    album       => 'Album',
    artist      => { },
    artwork     => { },
    author      => { Name => 'Author',      Groups => { 2 => 'Author' } },
    comment     => { },
    copyright   => { Name => 'Copyright',   Groups => { 2 => 'Author' } },
    creationdate=> {
        Name => 'CreationDate',
        Groups => { 2 => 'Time' },
        %iso8601Date,
    },
    description => { },
    director    => { },
    displayname => { Name => 'DisplayName' },
    title       => { }, #22
    genre       => { },
    information => { },
    keywords    => { },
    producer    => { }, #22
    make        => { Name => 'Make',        Groups => { 2 => 'Camera' } },
    model       => { Name => 'Model',       Groups => { 2 => 'Camera' } },
    publisher   => { },
    software    => { },
    year        => { Groups => { 2 => 'Time' } },
    'location.ISO6709' => {
        Name => 'GPSCoordinates',
        Groups => { 2 => 'Location' },
        Notes => q{
            Google Photos may ignore this if the coordinates have more than 5 digits
            after the decimal
        },
        ValueConv => \&ConvertISO6709,
        ValueConvInv => \&ConvInvISO6709,
        PrintConv => \&PrintGPSCoordinates,
        PrintConvInv => \&PrintInvGPSCoordinates,
    },
    'location.name' => { Name => 'LocationName', Groups => { 2 => 'Location' } },
    'location.body' => { Name => 'LocationBody', Groups => { 2 => 'Location' } },
    'location.note' => { Name => 'LocationNote', Groups => { 2 => 'Location' } },
    'location.role' => {
        Name => 'LocationRole',
        Groups => { 2 => 'Location' },
        PrintConv => {
            0 => 'Shooting Location',
            1 => 'Real Location',
            2 => 'Fictional Location',
        },
    },
    'location.date' => {
        Name => 'LocationDate',
        Groups => { 2 => 'Time' },
        %iso8601Date,
    },
    'location.accuracy.horizontal' => { Name => 'LocationAccuracyHorizontal' },
    'live-photo.auto'           => { Name => 'LivePhotoAuto', Writable => 'int8u' },
    'live-photo.vitality-score' => { Name => 'LivePhotoVitalityScore', Writable => 'float' },
    'live-photo.vitality-scoring-version' => { Name => 'LivePhotoVitalityScoringVersion', Writable => 'int64s' },
    'apple.photos.variation-identifier'   => { Name => 'ApplePhotosVariationIdentifier',  Writable => 'int64s' },
    'direction.facing' => { Name => 'CameraDirection', Groups => { 2 => 'Location' } },
    'direction.motion' => { Name => 'CameraMotion',    Groups => { 2 => 'Location' } },
    'location.body'    => { Name => 'LocationBody',    Groups => { 2 => 'Location' } },
    'player.version'                => 'PlayerVersion',
    'player.movie.visual.brightness'=> 'Brightness',
    'player.movie.visual.color'     => 'Color',
    'player.movie.visual.tint'      => 'Tint',
    'player.movie.visual.contrast'  => 'Contrast',
    'player.movie.audio.gain'       => 'AudioGain',
    'player.movie.audio.treble'     => 'Treble',
    'player.movie.audio.bass'       => 'Bass',
    'player.movie.audio.balance'    => 'Balance',
    'player.movie.audio.pitchshift' => 'PitchShift',
    'player.movie.audio.mute' => {
        Name => 'Mute',
        Format => 'int8u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    'rating.user'  => 'UserRating', # (Canon ELPH 510 HS)
    'collection.user' => 'UserCollection', #22
    'Encoded_With' => 'EncodedWith',
    'content.identifier' => 'ContentIdentifier', #forum14874
    'encoder' => { }, # forum15418 (written by ffmpeg)
#
# the following tags aren't in the com.apple.quicktime namespace:
#
    'com.android.version' => 'AndroidVersion',
    'com.android.capture.fps' => { Name  => 'AndroidCaptureFPS', Writable => 'float' },
    'com.android.manufacturer' => 'AndroidMake',
    'com.android.model' => 'AndroidModel',
    'com.xiaomi.preview_video_cover' => { Name => 'XiaomiPreviewVideoCover', Writable => 'int32s' },
    'xiaomi.exifInfo.videoinfo' => 'XiaomiExifInfo',
    'com.xiaomi.hdr10' => { Name => 'XiaomiHDR10', Writable => 'int32s' },
#
# also seen
#
    # com.divergentmedia.clipwrap.model            ('NEX-FS700EK')
    # com.divergentmedia.clipwrap.model1           ('49')
    # com.divergentmedia.clipwrap.model2           ('0')
    # com.divergentmedia.clipwrap.manufacturer     ('Sony')
    # com.divergentmedia.clipwrap.originalDateTime ('2013/2/6 10:30:40+0200')
#
# seen in timed metadata (mebx), and added dynamically to the table via SaveMetaKeys()
# NOTE: these tags are not writable! (timed metadata cannot yet be written)
#
    # (mdta)com.apple.quicktime.video-orientation (dtyp=66, int16s)
    'video-orientation' => {
        Name => 'VideoOrientation',
        Writable => 0,
        PrintConv => \%Image::ExifTool::Exif::orientation, #PH (NC)
    },
    # (mdta)com.apple.quicktime.live-photo-info (dtyp=com.apple.quicktime.com.apple.quicktime.live-photo-info)
    'live-photo-info' => {
        Name => 'LivePhotoInfo',
        Writable => 0,
        # not sure what these values mean, but unpack them anyway - PH
        # (ignore the fact that the "f" and "l" unpacks won't work on a big-endian machine)
        ValueConv => 'join " ",unpack "VfVVf6c4lCCcclf4Vvv", $val',
    },
    # (mdta)com.apple.quicktime.still-image-time (dtyp=65, int8s)
    'still-image-time' => { # (found in live photo)
        Name => 'StillImageTime',
        Writable => 0,
        Notes => q{
            this tag always has a value of -1; the time of the still image is obtained
            from the associated SampleTime
        },
    },
    # (mdta)com.apple.quicktime.detected-face (dtyp='com.apple.quicktime.detected-face')
    'detected-face' => {
        Name => 'FaceInfo',
        Writable => 0,
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::FaceInfo' },
    },
    # ---- detected-face fields ( ----
    # --> back here after a round trip through FaceInfo -> FaceRec -> FaceItem
    # (fiel)com.apple.quicktime.detected-face.bounds (dtyp=80, float[8])
    'detected-face.bounds' => {
        Name => 'DetectedFaceBounds',
        Writable => 0,
        # round to a reasonable number of decimal places
        PrintConv => 'my @a=split " ",$val;$_=int($_*1e6+.5)/1e6 foreach @a;join " ",@a',
        PrintConvInv => '$val',
    },
    # (fiel)com.apple.quicktime.detected-face.face-id (dtyp=77, int32u)
    'detected-face.face-id'    => { Name => 'DetectedFaceID',        Writable => 0 },
    # (fiel)com.apple.quicktime.detected-face.roll-angle (dtyp=23, float)
    'detected-face.roll-angle' => { Name => 'DetectedFaceRollAngle', Writable => 0 },
    # (fiel)com.apple.quicktime.detected-face.yaw-angle (dtyp=23, float)
    'detected-face.yaw-angle'  => { Name => 'DetectedFaceYawAngle',  Writable => 0 },
    # the following tags generated by ShutterEncoder when "preserve metadata" is selected (forum15610)
    major_brand       => { Name => 'MajorBrand',       Avoid => 1 },
    minor_version     => { Name => 'MinorVersion',     Avoid => 1 },
    compatible_brands => { Name => 'CompatibleBrands', Avoid => 1 },
    creation_time => {
        Name => 'CreationTime',
        Groups => { 2 => 'Time' },
        Avoid => 1,
        %iso8601Date,
    },
    # (mdta)com.apple.quicktime.scene-illuminance
    'scene-illuminance' => {
        Name => 'SceneIlluminance',
        Notes => 'milli-lux',
        ValueConv => 'unpack("N", $val)',
        Writable => 0, # (don't make this writable because it is found in timed metadata)
    },
    'full-frame-rate-playback-intent' => 'FullFrameRatePlaybackIntent', #forum16824
#
# seen in Apple ProRes RAW file
#
    # (mdta)com.apple.proapps.manufacturer (eg. "Sony")
    # (mdta)com.apple.proapps.exif.{Exif}.FNumber (float, eg. 1.0)
    # (mdta)org.smpte.rdd18.lens.irisfnumber (eg. "F1.0")
    # (mdta)com.apple.proapps.exif.{Exif}.ShutterSpeedValue (float, eg. 1.006)
    # (mdta)org.smpte.rdd18.camera.shutterspeed_angle (eg. "179.2deg")
    # (mdta)org.smpte.rdd18.camera.neutraldensityfilterwheelsetting (eg. "ND1")
    # (mdta)org.smpte.rdd18.camera.whitebalance (eg. "4300K")
    # (mdta)com.apple.proapps.exif.{Exif}.ExposureIndex (float, eg. 4000)
    # (mdta)org.smpte.rdd18.camera.isosensitivity (eg. "4000")
    # (mdta)com.apple.proapps.image.{TIFF}.Make (eg. "Atmos")
    # (mdta)com.apple.proapps.image.{TIFF}.Model (eg. "ShogunInferno")
    # (mdta)com.apple.proapps.image.{TIFF}.Software (eg. "9.0")
);

# Keys tags in the audio track (ref PH)
%Image::ExifTool::QuickTime::AudioKeys = (
    PROCESS_PROC => \&ProcessKeys,
    WRITE_PROC => \&WriteKeys,
    CHECK_PROC => \&CheckQTValue,
    WRITABLE => 1,
    GROUPS => { 1 => 'AudioKeys', 2 => 'Audio' },
    WRITE_GROUP => 'AudioKeys',
    LANG_INFO => \&GetLangInfo,
    NOTES => q{
        Keys tags written in the audio track by some Apple devices.  These tags
        belong to the ExifTool AudioKeys family 1 gorup.
    },
    'player.movie.audio.gain'       => 'AudioGain',
    'player.movie.audio.treble'     => 'Treble',
    'player.movie.audio.bass'       => 'Bass',
    'player.movie.audio.balance'    => 'Balance',
    'player.movie.audio.pitchshift' => 'PitchShift',
    'player.movie.audio.mute' => {
        Name => 'Mute',
        Format => 'int8u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
);

# Keys tags in the video track (ref PH)
%Image::ExifTool::QuickTime::VideoKeys = (
    PROCESS_PROC => \&ProcessKeys,
    WRITE_PROC => \&WriteKeys,
    CHECK_PROC => \&CheckQTValue,
    VARS => { LONG_TAGS => 2 },
    WRITABLE => 1,
    GROUPS => { 1 => 'VideoKeys', 2 => 'Camera' },
    WRITE_GROUP => 'VideoKeys',
    LANG_INFO => \&GetLangInfo,
    NOTES => q{
        Keys tags written in the video track.  These tags belong to the ExifTool
        VideoKeys family 1 gorup.
    },
    'camera.identifier' => 'CameraIdentifier',
    'camera.lens_model' => 'LensModel',
    'camera.focal_length.35mm_equivalent' => 'FocalLengthIn35mmFormat',
    'camera.framereadouttimeinmicroseconds' => {
        Name => 'FrameReadoutTime',
        ValueConv => '$val * 1e-6',
        ValueConvInv => 'int($val * 1e6 + 0.5)',
        PrintConv => '$val * 1e6 . " microseconds"',
        PrintConvInv => '$val =~ s/ .*//; $val * 1e-6',
    },
    'com.apple.photos.captureMode' => 'CaptureMode',
);

# iTunes info ('----') atoms
%Image::ExifTool::QuickTime::iTunesInfo = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 1 => 'iTunes', 2 => 'Audio' },
    VARS => { LONG_TAGS => 1 }, # (hack for discrepancy in the way long tags are counted in BuildTagLookup)
    NOTES => q{
        ExifTool will extract any iTunesInfo tags that exist, even if they are not
        defined in this table.  These tags belong to the family 1 "iTunes" group,
        and are not currently writable.
    },
    # 'mean'/'name'/'data' atoms form a triplet, but unfortunately
    # I haven't been able to find any documentation on this.
    # 'mean' is normally 'com.apple.iTunes'
    mean => {
        Name => 'Mean',
        # the 'Triplet' flag tells ProcessMOV() to generate
        # a single tag from the mean/name/data triplet
        Triplet => 1,
        Hidden => 1,
    },
    name => {
        Name => 'Name',
        Triplet => 1,
        Hidden => 1,
    },
    data => {
        Name => 'Data',
        Triplet => 1,
        Hidden => 1,
    },
    # the tag ID's below are composed from "mean/name",
    # but "mean/" is omitted if it is "com.apple.iTunes/":
    'iTunMOVI' => {
        Name => 'iTunMOVI',
        SubDirectory => { TagTable => 'Image::ExifTool::PLIST::Main' },
    },
    'tool' => {
        Name => 'iTunTool',
        Description => 'iTunTool',
        Format => 'int32u',
        PrintConv => 'sprintf("0x%.8x",$val)',
    },
    'iTunEXTC' => {
        Name => 'ContentRating',
        Notes => 'standard | rating | score | reasons',
        # eg. 'us-tv|TV-14|500|V', 'mpaa|PG-13|300|For violence and sexuality'
        # (see http://shadowofged.blogspot.ca/2008/06/itunes-content-ratings.html)
    },
    'iTunNORM' => {
        Name => 'VolumeNormalization',
        PrintConv => '$val=~s/ 0+(\w)/ $1/g; $val=~s/^\s+//; $val',
    },
    'iTunSMPB' => {
        Name => 'iTunSMPB',
        Description => 'iTunSMPB',
        # hex format, similar to iTunNORM, but 12 words instead of 10,
        # and 4th word is 16 hex digits (all others are 8)
        # (gives AAC encoder delay, ref http://code.google.com/p/l-smash/issues/detail?id=1)
        PrintConv => '$val=~s/ 0+(\w)/ $1/g; $val=~s/^\s+//; $val',
    },
    # (CDDB = Compact Disc DataBase)
    # iTunes_CDDB_1 = <CDDB1 disk ID>+<# tracks>+<logical block address for each track>...
    'iTunes_CDDB_1' => 'CDDB1Info',
    'iTunes_CDDB_TrackNumber' => 'CDDBTrackNumber',
    'Encoding Params' => {
        Name => 'EncodingParams',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::EncodingParams' },
    },
    # also heard about 'iTunPGAP', but I haven't seen a sample
    # all tags below were added based on samples I have seen - PH
    DISCNUMBER          => 'DiscNumber',
    TRACKNUMBER         => 'TrackNumber',
    ARTISTS             => 'Artists',
    CATALOGNUMBER       => 'CatalogNumber',
    RATING              => 'Rating',
    MEDIA               => 'Media',
    SCRIPT              => 'Script', # character set? (seen 'Latn')
    BARCODE             => 'Barcode',
    LABEL               => 'Label',
    MOOD                => 'Mood',
    DIRECTOR            => 'Director',
    DIRECTOR_OF_PHOTOGRAPHY => 'DirectorOfPhotography',
    PRODUCTION_DESIGNER => 'ProductionDesigner',
    COSTUME_DESIGNER    => 'CostumeDesigner',
    SCREENPLAY_BY       => 'ScreenplayBy',
    EDITED_BY           => 'EditedBy',
    PRODUCER            => 'Producer',
    IMDB_ID             => { },
    TMDB_ID             => { },
    Actors              => { },
    TIPL                => { },
    popularimeter       => 'Popularimeter',
    'Dynamic Range (DR)'=> 'DynamicRange',
    initialkey          => 'InitialKey',
    originalyear        => 'OriginalYear',
    originaldate        => 'OriginalDate',
    '~length'           => 'Length', # play length? (ie. duration?)
    replaygain_track_gain=>'ReplayTrackGain',
    replaygain_track_peak=>'ReplayTrackPeak',
   'Volume Level (ReplayGain)'=> 'ReplayVolumeLevel',
   'Dynamic Range (R128)'=> 'DynamicRangeR128',
   'Volume Level (R128)' => 'VolumeLevelR128',
   'Peak Level (Sample)' => 'PeakLevelSample',
   'Peak Level (R128)'   => 'PeakLevelR128',
    # also seen (many from forum12777):
    # 'MusicBrainz Album Release Country'
    # 'MusicBrainz Album Type'
    # 'MusicBrainz Album Status'
    # 'MusicBrainz Track Id'
    # 'MusicBrainz Release Track Id'
    # 'MusicBrainz Album Id'
    # 'MusicBrainz Album Artist Id'
    # 'MusicBrainz Artist Id'
    # 'Acoustid Id' (sic)
    # 'Tool Version'
    # 'Tool Name'
    # 'ISRC'
    # 'HDCD'
    # 'Waveform'
);

# iTunes audio encoding parameters
# ref https://developer.apple.com/library/mac/#documentation/MusicAudio/Reference/AudioCodecServicesRef/Reference/reference.html
%Image::ExifTool::QuickTime::EncodingParams = (
    PROCESS_PROC => \&ProcessEncodingParams,
    GROUPS => { 2 => 'Audio' },
    # (I have commented out the ones that don't have integer values because they
    #  probably don't appear, and definitely wouldn't work with current decoding - PH)

    # global codec properties
    #'lnam' => 'AudioCodecName',
    #'lmak' => 'AudioCodecManufacturer',
    #'lfor' => 'AudioCodecFormat',
    'vpk?' => 'AudioHasVariablePacketByteSizes',
    #'ifm#' => 'AudioSupportedInputFormats',
    #'ofm#' => 'AudioSupportedOutputFormats',
    #'aisr' => 'AudioAvailableInputSampleRates',
    #'aosr' => 'AudioAvailableOutputSampleRates',
    'abrt' => 'AudioAvailableBitRateRange',
    'mnip' => 'AudioMinimumNumberInputPackets',
    'mnop' => 'AudioMinimumNumberOutputPackets',
    'cmnc' => 'AudioAvailableNumberChannels',
    'lmrc' => 'AudioDoesSampleRateConversion',
    #'aicl' => 'AudioAvailableInputChannelLayoutTags',
    #'aocl' => 'AudioAvailableOutputChannelLayoutTags',
    #'if4o' => 'AudioInputFormatsForOutputFormat',
    #'of4i' => 'AudioOutputFormatsForInputFormat',
    #'acfi' => 'AudioFormatInfo',

    # instance codec properties
    'tbuf' => 'AudioInputBufferSize',
    'pakf' => 'AudioPacketFrameSize',
    'pakb' => 'AudioMaximumPacketByteSize',
    #'ifmt' => 'AudioCurrentInputFormat',
    #'ofmt' => 'AudioCurrentOutputFormat',
    #'kuki' => 'AudioMagicCookie',
    'ubuf' => 'AudioUsedInputBufferSize',
    'init' => 'AudioIsInitialized',
    'brat' => 'AudioCurrentTargetBitRate',
    #'cisr' => 'AudioCurrentInputSampleRate',
    #'cosr' => 'AudioCurrentOutputSampleRate',
    'srcq' => 'AudioQualitySetting',
    #'brta' => 'AudioApplicableBitRateRange',
    #'isra' => 'AudioApplicableInputSampleRates',
    #'osra' => 'AudioApplicableOutputSampleRates',
    'pad0' => 'AudioZeroFramesPadded',
    'prmm' => 'AudioCodecPrimeMethod',
    #'prim' => 'AudioCodecPrimeInfo',
    #'icl ' => 'AudioInputChannelLayout',
    #'ocl ' => 'AudioOutputChannelLayout',
    #'acs ' => 'AudioCodecSettings',
    #'acfl' => 'AudioCodecFormatList',
    'acbf' => 'AudioBitRateControlMode',
    'vbrq' => 'AudioVBRQuality',
    'mdel' => 'AudioMinimumDelayMode',

    # deprecated
    'pakd' => 'AudioRequiresPacketDescription',
    #'brt#' => 'AudioAvailableBitRates',
    'acef' => 'AudioExtendFrequencies',
    'ursr' => 'AudioUseRecommendedSampleRate',
    'oppr' => 'AudioOutputPrecedence',
    #'loud' => 'AudioCurrentLoudnessStatistics',

    # others
    'vers' => 'AudioEncodingParamsVersion', #PH
    'cdcv' => { #PH
        Name => 'AudioComponentVersion',
        ValueConv => 'join ".", unpack("ncc", pack("N",$val))',
    },
);

# print to video data block
%Image::ExifTool::QuickTime::Video = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    0 => {
        Name => 'DisplaySize',
        PrintConv => {
            0 => 'Normal',
            1 => 'Double Size',
            2 => 'Half Size',
            3 => 'Full Screen',
            4 => 'Current Size',
        },
    },
    6 => {
        Name => 'SlideShow',
        PrintConv => {
            0 => 'No',
            1 => 'Yes',
        },
    },
);

# 'hnti' atoms
%Image::ExifTool::QuickTime::HintInfo = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    'rtp ' => {
        Name => 'RealtimeStreamingProtocol',
        PrintConv => '$val=~s/^sdp /(SDP) /; $val',
    },
    'sdp ' => 'StreamingDataProtocol',
);

# 'hinf' atoms
%Image::ExifTool::QuickTime::HintTrackInfo = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    trpY => { Name => 'TotalBytes', Format => 'int64u' }, #(documented)
    trpy => { Name => 'TotalBytes', Format => 'int64u' }, #(observed)
    totl => { Name => 'TotalBytes', Format => 'int32u' },
    nump => { Name => 'NumPackets', Format => 'int64u' },
    npck => { Name => 'NumPackets', Format => 'int32u' },
    tpyl => { Name => 'TotalBytesNoRTPHeaders', Format => 'int64u' },
    tpaY => { Name => 'TotalBytesNoRTPHeaders', Format => 'int32u' }, #(documented)
    tpay => { Name => 'TotalBytesNoRTPHeaders', Format => 'int32u' }, #(observed)
    maxr => {
        Name => 'MaxDataRate',
        Format => 'int32u',
        Count => 2,
        PrintConv => 'my @a=split(" ",$val);sprintf("%d bytes in %.3f s",$a[1],$a[0]/1000)',
    },
    dmed => { Name => 'MediaTrackBytes',    Format => 'int64u' },
    dimm => { Name => 'ImmediateDataBytes', Format => 'int64u' },
    drep => { Name => 'RepeatedDataBytes',  Format => 'int64u' },
    tmin => {
        Name => 'MinTransmissionTime',
        Format => 'int32u',
        PrintConv => 'sprintf("%.3f s",$val/1000)',
    },
    tmax => {
        Name => 'MaxTransmissionTime',
        Format => 'int32u',
        PrintConv => 'sprintf("%.3f s",$val/1000)',
    },
    pmax => { Name => 'LargestPacketSize',  Format => 'int32u' },
    dmax => {
        Name => 'LargestPacketDuration',
        Format => 'int32u',
        PrintConv => 'sprintf("%.3f s",$val/1000)',
    },
    payt => {
        Name => 'PayloadType',
        Format => 'undef',  # (necessary to prevent decoding as string!)
        ValueConv => 'unpack("N",$val) . " " . substr($val, 5)',
        PrintConv => '$val=~s/ /, /;$val',
    },
);

# MP4 media box (ref 5)
%Image::ExifTool::QuickTime::Media = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 1 => 'Track#', 2 => 'Video' },
    NOTES => 'MP4 media box.',
    mdhd => {
        Name => 'MediaHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::MediaHeader' },
    },
    hdlr => {
        Name => 'Handler',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Handler' },
    },
    minf => {
        Name => 'MediaInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::MediaInfo' },
    },
);

# MP4 media header box (ref 5)
%Image::ExifTool::QuickTime::MediaHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    GROUPS => { 1 => 'Track#', 2 => 'Video' },
    FORMAT => 'int32u',
    DATAMEMBER => [ 0, 1, 2, 3, 4 ],
    0 => {
        Name => 'MediaHeaderVersion',
        RawConv => '$$self{MediaHeaderVersion} = $val',
    },
    1 => {
        Name => 'MediaCreateDate',
        Groups => { 2 => 'Time' },
        %timeInfo,
        # this is int64u if MediaHeaderVersion == 1 (ref 5/13)
        Hook => '$$self{MediaHeaderVersion} and $format = "int64u", $varSize += 4',
    },
    2 => {
        Name => 'MediaModifyDate',
        Groups => { 2 => 'Time' },
        %timeInfo,
        # this is int64u if MediaHeaderVersion == 1 (ref 5/13)
        Hook => '$$self{MediaHeaderVersion} and $format = "int64u", $varSize += 4',
    },
    3 => {
        Name => 'MediaTimeScale',
        RawConv => '$$self{MediaTS} = $val',
    },
    4 => {
        Name => 'MediaDuration',
        RawConv => '$$self{MediaTS} ? $val / $$self{MediaTS} : $val',
        PrintConv => '$$self{MediaTS} ? ConvertDuration($val) : $val',
        # this is int64u if MediaHeaderVersion == 1 (ref 5/13)
        Hook => '$$self{MediaHeaderVersion} and $format = "int64u", $varSize += 4',
    },
    5 => {
        Name => 'MediaLanguageCode',
        Format => 'int16u',
        RawConv => '$val ? $val : undef',
        # allow both Macintosh (for MOV files) and ISO (for MP4 files) language codes
        ValueConv => '($val < 0x400 or $val == 0x7fff) ? $val : pack "C*", map { (($val>>$_)&0x1f)+0x60 } 10, 5, 0',
        PrintConv => q{
            return $val unless $val =~ /^\d+$/;
            require Image::ExifTool::Font;
            return $Image::ExifTool::Font::ttLang{Macintosh}{$val} || "Unknown ($val)";
        },
    },
);

# MP4 media information box (ref 5)
%Image::ExifTool::QuickTime::MediaInfo = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 1 => 'Track#', 2 => 'Video' },
    NOTES => 'MP4 media info box.',
    vmhd => {
        Name => 'VideoHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::VideoHeader' },
    },
    smhd => {
        Name => 'AudioHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::AudioHeader' },
    },
    hmhd => {
        Name => 'HintHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::HintHeader' },
    },
    nmhd => {
        Name => 'NullMediaHeader',
        Flags => ['Binary','Unknown'],
    },
    dinf => {
        Name => 'DataInfo', # (don't change this name -- used to recognize directory when writing)
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::DataInfo' },
    },
    gmhd => {
        Name => 'GenMediaHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::GenMediaHeader' },
    },
    hdlr => { #PH
        Name => 'Handler',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Handler' },
    },
    stbl => {
        Name => 'SampleTable',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::SampleTable' },
    },
);

# MP4 video media header (ref 5)
%Image::ExifTool::QuickTime::VideoHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    NOTES => 'MP4 video media header.',
    FORMAT => 'int16u',
    2 => {
        Name => 'GraphicsMode',
        PrintHex => 1,
        SeparateTable => 'GraphicsMode',
        PrintConv => \%graphicsMode,
    },
    3 => { Name => 'OpColor', Format => 'int16u[3]' },
);

# MP4 audio media header (ref 5)
%Image::ExifTool::QuickTime::AudioHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Audio' },
    NOTES => 'MP4 audio media header.',
    FORMAT => 'int16u',
    2 => { Name => 'Balance', Format => 'fixed16s' },
);

# MP4 hint media header (ref 5)
%Image::ExifTool::QuickTime::HintHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => 'MP4 hint media header.',
    FORMAT => 'int16u',
    2 => 'MaxPDUSize',
    3 => 'AvgPDUSize',
    4 => { Name => 'MaxBitrate', Format => 'int32u', PrintConv => 'ConvertBitrate($val)' },
    6 => { Name => 'AvgBitrate', Format => 'int32u', PrintConv => 'ConvertBitrate($val)' },
);

# MP4 sample table box (ref 5)
%Image::ExifTool::QuickTime::SampleTable = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 2 => 'Video' },
    NOTES => 'MP4 sample table box.',
    stsd => [
        {
            Name => 'AudioSampleDesc',
            Condition => '$$self{HandlerType} and $$self{HandlerType} eq "soun"',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::AudioSampleDesc',
                ProcessProc => \&ProcessSampleDesc,
            },
        },{
            Name => 'VideoSampleDesc',
            Condition => '$$self{HandlerType} and $$self{HandlerType} eq "vide"',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::ImageDesc',
                ProcessProc => \&ProcessSampleDesc,
            },
        },{
            Name => 'HintSampleDesc',
            Condition => '$$self{HandlerType} and $$self{HandlerType} eq "hint"',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::HintSampleDesc',
                ProcessProc => \&ProcessSampleDesc,
            },
        },{
            Name => 'MetaSampleDesc',
            Condition => '$$self{HandlerType} and $$self{HandlerType} eq "meta"',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::MetaSampleDesc',
                ProcessProc => \&ProcessSampleDesc,
            },
        },{
            Name => 'OtherSampleDesc',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::OtherSampleDesc',
                ProcessProc => \&ProcessSampleDesc,
            },
        },
        # (Note: "alis" HandlerType handled by the parent audio or video handler)
    ],
    stts => [ # decoding time-to-sample table
        {
            Name => 'VideoFrameRate',
            Notes => 'average rate calculated from time-to-sample table for video media',
            Condition => '$$self{MediaType} eq "vide"',
            Format => 'undef',  # (necessary to prevent decoding as string!)
            # (must be RawConv so appropriate MediaTS is used in calculation)
            RawConv => 'Image::ExifTool::QuickTime::CalcSampleRate($self, \$val)',
            PrintConv => 'int($val * 1000 + 0.5) / 1000',
        },
        {
            Name => 'TimeToSampleTable',
            Flags => ['Binary','Unknown'],
        },
    ],
    ctts => {
        Name => 'CompositionTimeToSample',
        Flags => ['Binary','Unknown'],
    },
    stsc => {
        Name => 'SampleToChunk',
        Flags => ['Binary','Unknown'],
    },
    stsz => {
        Name => 'SampleSizes',
        Flags => ['Binary','Unknown'],
    },
    stz2 => {
        Name => 'CompactSampleSizes',
        Flags => ['Binary','Unknown'],
    },
    stco => {
        Name => 'ChunkOffset',
        Flags => ['Binary','Unknown'],
    },
    co64 => {
        Name => 'ChunkOffset64',
        Flags => ['Binary','Unknown'],
    },
    stss => {
        Name => 'SyncSampleTable',
        Flags => ['Binary','Unknown'],
    },
    stsh => {
        Name => 'ShadowSyncSampleTable',
        Flags => ['Binary','Unknown'],
    },
    padb => {
        Name => 'SamplePaddingBits',
        Flags => ['Binary','Unknown'],
    },
    stdp => {
        Name => 'SampleDegradationPriority',
        Flags => ['Binary','Unknown'],
    },
    sdtp => {
        Name => 'IdependentAndDisposableSamples',
        Flags => ['Binary','Unknown'],
    },
    sbgp => {
        Name => 'SampleToGroup',
        Flags => ['Binary','Unknown'],
    },
    sgpd => {
        Name => 'SampleGroupDescription',
        Flags => ['Binary','Unknown'],
        # bytes 4-7 give grouping type (ref ISO/IEC 14496-15:2014)
        #   tsas - temporal sublayer sample
        #   stsa - step-wise temporal layer access
        #   avss - AVC sample
        #   tscl - temporal layer scalability
        #   sync - sync sample
    },
    subs => {
        Name => 'Sub-sampleInformation',
        Flags => ['Binary','Unknown'],
    },
    cslg => {
        Name => 'CompositionToDecodeTimelineMapping',
        Flags => ['Binary','Unknown'],
    },
    stps => {
        Name => 'PartialSyncSamples',
        ValueConv => 'join " ",unpack("x8N*",$val)',
    },
    # mark - 8 bytes all zero (GoPro)
);

# MP4 audio sample description box (ref 5/AtomicParsley 0.9.4 parsley.cpp)
%Image::ExifTool::QuickTime::AudioSampleDesc = (
    PROCESS_PROC => \&ProcessHybrid,
    VARS => { ID_LABEL => 'ID/Index' },
    GROUPS => { 2 => 'Audio' },
    NOTES => q{
        MP4 audio sample description.  This hybrid atom contains both data and child
        atoms.
    },
    4  => {
        Name => 'AudioFormat',
        Format => 'undef[4]',
        RawConv => q{
            $$self{AudioFormat} = $val;
            return undef unless $val =~ /^[\w ]{4}$/i;
            # check for protected audio format
            $self->OverrideFileType('M4P') if $val eq 'drms' and $$self{FileType} eq 'M4A';
            return $val;
        },
        # see this link for print conversions (not complete):
        # https://github.com/yannickcr/brooser/blob/master/php/librairies/getid3/module.audio-video.quicktime.php
    },
    20 => { #PH
        Name => 'AudioVendorID',
        Condition => '$$self{AudioFormat} ne "mp4s"',
        Format => 'undef[4]',
        RawConv => '$val eq "\0\0\0\0" ? undef : $val',
        PrintConv => \%vendorID,
        SeparateTable => 'VendorID',
    },
    24 => { Name => 'AudioChannels',        Format => 'int16u' },
    26 => { Name => 'AudioBitsPerSample',   Format => 'int16u' },
    32 => { Name => 'AudioSampleRate',      Format => 'fixed32u' },
#
# Observed offsets for child atoms of various AudioFormat types:
#
#   AudioFormat  Offset  Child atoms
#   -----------  ------  ----------------
#   mp4a         52 *    wave, chan, esds, SA3D(Insta360 spherical video params?,also GoPro Max and Garmin VIRB 360)
#   in24         52      wave, chan
#   "ms\0\x11"   52      wave
#   sowt         52      chan
#   mp4a         36 *    esds, pinf
#   drms         36      esds, sinf
#   samr         36      damr
#   alac         36      alac
#   ac-3         36      dac3
#
# (* child atoms found at different offsets in mp4a)
#
    pinf => {
        Name => 'PurchaseInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::ProtectionInfo' },
    },
    sinf => { # "protection scheme information"
        Name => 'ProtectionInfo', #3
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::ProtectionInfo' },
    },
    # f - 16/36 bytes
    # esds - 31/40/42/43 bytes - ES descriptor (ref 3)
    damr => { #3
        Name => 'DecodeConfig',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::DecodeConfig' },
    },
    wave => {
        Name => 'Wave',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Wave' },
    },
    chan => {
        Name => 'AudioChannelLayout',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::ChannelLayout' },
    },
    SA3D => { # written by Garmin VIRB360
        Name => 'SpatialAudio',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::SpatialAudio' },
    },
    btrt => {
        Name => 'BitrateInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Bitrate' },
    },
    # alac - 28 bytes
    # adrm - AAX DRM atom? 148 bytes
    # aabd - AAX unknown 17kB (contains 'aavd' strings)
    # dapa - ? 203 bytes
);

# AMR decode config box (ref 3)
%Image::ExifTool::QuickTime::DecodeConfig = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Audio' },
    0 => {
        Name => 'EncoderVendor',
        Format => 'undef[4]',
    },
    4 => 'EncoderVersion',
    # 5 - int16u - packet modes
    # 7 - int8u - number of packet mode changes
    # 8 - int8u - bytes per packet
);

%Image::ExifTool::QuickTime::ProtectionInfo = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Audio' },
    NOTES => 'Child atoms found in "sinf" and/or "pinf" atoms.',
    frma => 'OriginalFormat',
    # imif - IPMP information
    schm => {
        Name => 'SchemeType',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::SchemeType' },
    },
    schi => {
        Name => 'SchemeInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::SchemeInfo' },
    },
    enda => {
        Name => 'Endianness',
        Format => 'int16u',
        PrintConv => {
            0 => 'Big-endian (Motorola, MM)',
            1 => 'Little-endian (Intel, II)',
        },
    },
    # skcr
);

%Image::ExifTool::QuickTime::Wave = (
    PROCESS_PROC => \&ProcessMOV,
    frma => 'PurchaseFileFormat',
    enda => {
        Name => 'Endianness',
        Format => 'int16u',
        PrintConv => {
            0 => 'Big-endian (Motorola, MM)',
            1 => 'Little-endian (Intel, II)',
        },
    },
    # "ms\0\x11" - 20 bytes
);

# audio channel layout (ref CoreAudioTypes.h)
%Image::ExifTool::QuickTime::ChannelLayout = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Audio' },
    DATAMEMBER => [ 0, 8 ],
    NOTES => 'Audio channel layout.',
    # 0 - version and flags
    4 => {
        Name => 'LayoutFlags',
        Format => 'int16u',
        RawConv => '$$self{LayoutFlags} = $val',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'UseDescriptions',
            1 => 'UseBitmap',
            100 => 'Mono',
            101 => 'Stereo',
            102 => 'StereoHeadphones',
            100 => 'Mono',
            101 => 'Stereo',
            102 => 'StereoHeadphones',
            103 => 'MatrixStereo',
            104 => 'MidSide',
            105 => 'XY',
            106 => 'Binaural',
            107 => 'Ambisonic_B_Format',
            108 => 'Quadraphonic',
            109 => 'Pentagonal',
            110 => 'Hexagonal',
            111 => 'Octagonal',
            112 => 'Cube',
            113 => 'MPEG_3_0_A',
            114 => 'MPEG_3_0_B',
            115 => 'MPEG_4_0_A',
            116 => 'MPEG_4_0_B',
            117 => 'MPEG_5_0_A',
            118 => 'MPEG_5_0_B',
            119 => 'MPEG_5_0_C',
            120 => 'MPEG_5_0_D',
            121 => 'MPEG_5_1_A',
            122 => 'MPEG_5_1_B',
            123 => 'MPEG_5_1_C',
            124 => 'MPEG_5_1_D',
            125 => 'MPEG_6_1_A',
            126 => 'MPEG_7_1_A',
            127 => 'MPEG_7_1_B',
            128 => 'MPEG_7_1_C',
            129 => 'Emagic_Default_7_1',
            130 => 'SMPTE_DTV',
            131 => 'ITU_2_1',
            132 => 'ITU_2_2',
            133 => 'DVD_4',
            134 => 'DVD_5',
            135 => 'DVD_6',
            136 => 'DVD_10',
            137 => 'DVD_11',
            138 => 'DVD_18',
            139 => 'AudioUnit_6_0',
            140 => 'AudioUnit_7_0',
            141 => 'AAC_6_0',
            142 => 'AAC_6_1',
            143 => 'AAC_7_0',
            144 => 'AAC_Octagonal',
            145 => 'TMH_10_2_std',
            146 => 'TMH_10_2_full',
            147 => 'DiscreteInOrder',
            148 => 'AudioUnit_7_0_Front',
            149 => 'AC3_1_0_1',
            150 => 'AC3_3_0',
            151 => 'AC3_3_1',
            152 => 'AC3_3_0_1',
            153 => 'AC3_2_1_1',
            154 => 'AC3_3_1_1',
            155 => 'EAC_6_0_A',
            156 => 'EAC_7_0_A',
            157 => 'EAC3_6_1_A',
            158 => 'EAC3_6_1_B',
            159 => 'EAC3_6_1_C',
            160 => 'EAC3_7_1_A',
            161 => 'EAC3_7_1_B',
            162 => 'EAC3_7_1_C',
            163 => 'EAC3_7_1_D',
            164 => 'EAC3_7_1_E',
            165 => 'EAC3_7_1_F',
            166 => 'EAC3_7_1_G',
            167 => 'EAC3_7_1_H',
            168 => 'DTS_3_1',
            169 => 'DTS_4_1',
            170 => 'DTS_6_0_A',
            171 => 'DTS_6_0_B',
            172 => 'DTS_6_0_C',
            173 => 'DTS_6_1_A',
            174 => 'DTS_6_1_B',
            175 => 'DTS_6_1_C',
            176 => 'DTS_7_0',
            177 => 'DTS_7_1',
            178 => 'DTS_8_0_A',
            179 => 'DTS_8_0_B',
            180 => 'DTS_8_1_A',
            181 => 'DTS_8_1_B',
            182 => 'DTS_6_1_D',
            183 => 'AAC_7_1_B',
            0xffff => 'Unknown',
        },
    },
    6  => {
        Name => 'AudioChannels',
        Condition => '$$self{LayoutFlags} != 0 and $$self{LayoutFlags} != 1',
        Format => 'int16u',
    },
    8 => {
        Name => 'AudioChannelTypes',
        Condition => '$$self{LayoutFlags} == 1',
        Format => 'int32u',
        PrintConv => { BITMASK => {
            0 => 'Left',
            1 => 'Right',
            2 => 'Center',
            3 => 'LFEScreen',
            4 => 'LeftSurround',
            5 => 'RightSurround',
            6 => 'LeftCenter',
            7 => 'RightCenter',
            8 => 'CenterSurround',
            9 => 'LeftSurroundDirect',
            10 => 'RightSurroundDirect',
            11 => 'TopCenterSurround',
            12 => 'VerticalHeightLeft',
            13 => 'VerticalHeightCenter',
            14 => 'VerticalHeightRight',
            15 => 'TopBackLeft',
            16 => 'TopBackCenter',
            17 => 'TopBackRight',
        }},
    },
    12  => {
        Name => 'NumChannelDescriptions',
        Condition => '$$self{LayoutFlags} == 1',
        Format => 'int32u',
        RawConv => '$$self{NumChannelDescriptions} = $val',
    },
    16 => {
        Name => 'Channel1Label',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 0',
        Format => 'int32u',
        SeparateTable => 'ChannelLabel',
        PrintConv => \%channelLabel,
    },
    20 => {
        Name => 'Channel1Flags',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 0',
        Format => 'int32u',
        PrintConv => { BITMASK => { 0 => 'Rectangular', 1 => 'Spherical', 2 => 'Meters' }},
    },
    24 => {
        Name => 'Channel1Coordinates',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 0',
        Notes => q{
            3 numbers:  for rectangular coordinates left/right, back/front, down/up; for
            spherical coordinates left/right degrees, down/up degrees, distance
        },
        Format => 'float[3]',
    },
    36 => {
        Name => 'Channel2Label',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 1',
        Format => 'int32u',
        SeparateTable => 'ChannelLabel',
        PrintConv => \%channelLabel,
    },
    40 => {
        Name => 'Channel2Flags',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 1',
        Format => 'int32u',
        PrintConv => { BITMASK => { 0 => 'Rectangular', 1 => 'Spherical', 2 => 'Meters' }},
    },
    44 => {
        Name => 'Channel2Coordinates',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 1',
        Format => 'float[3]',
    },
    56 => {
        Name => 'Channel3Label',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 2',
        Format => 'int32u',
        SeparateTable => 'ChannelLabel',
        PrintConv => \%channelLabel,
    },
    60 => {
        Name => 'Channel3Flags',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 2',
        Format => 'int32u',
        PrintConv => { BITMASK => { 0 => 'Rectangular', 1 => 'Spherical', 2 => 'Meters' }},
    },
    64 => {
        Name => 'Channel3Coordinates',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 2',
        Format => 'float[3]',
    },
    76 => {
        Name => 'Channel4Label',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 3',
        Format => 'int32u',
        SeparateTable => 'ChannelLabel',
        PrintConv => \%channelLabel,
    },
    80 => {
        Name => 'Channel4Flags',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 3',
        Format => 'int32u',
        PrintConv => { BITMASK => { 0 => 'Rectangular', 1 => 'Spherical', 2 => 'Meters' }},
    },
    84 => {
        Name => 'Channel4Coordinates',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 3',
        Format => 'float[3]',
    },
    96 => {
        Name => 'Channel5Label',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 4',
        Format => 'int32u',
        SeparateTable => 'ChannelLabel',
        PrintConv => \%channelLabel,
    },
    100 => {
        Name => 'Channel5Flags',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 4',
        Format => 'int32u',
        PrintConv => { BITMASK => { 0 => 'Rectangular', 1 => 'Spherical', 2 => 'Meters' }},
    },
    104 => {
        Name => 'Channel5Coordinates',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 4',
        Format => 'float[3]',
    },
    116 => {
        Name => 'Channel6Label',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 5',
        Format => 'int32u',
        SeparateTable => 'ChannelLabel',
        PrintConv => \%channelLabel,
    },
    120 => {
        Name => 'Channel6Flags',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 5',
        Format => 'int32u',
        PrintConv => { BITMASK => { 0 => 'Rectangular', 1 => 'Spherical', 2 => 'Meters' }},
    },
    124 => {
        Name => 'Channel6Coordinates',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 5',
        Format => 'float[3]',
    },
    136 => {
        Name => 'Channel7Label',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 6',
        Format => 'int32u',
        SeparateTable => 'ChannelLabel',
        PrintConv => \%channelLabel,
    },
    140 => {
        Name => 'Channel7Flags',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 6',
        Format => 'int32u',
        PrintConv => { BITMASK => { 0 => 'Rectangular', 1 => 'Spherical', 2 => 'Meters' }},
    },
    144 => {
        Name => 'Channel7Coordinates',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 6',
        Format => 'float[3]',
    },
    156 => {
        Name => 'Channel8Label',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 7',
        Format => 'int32u',
        SeparateTable => 'ChannelLabel',
        PrintConv => \%channelLabel,
    },
    160 => {
        Name => 'Channel8Flags',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 7',
        Format => 'int32u',
        PrintConv => { BITMASK => { 0 => 'Rectangular', 1 => 'Spherical', 2 => 'Meters' }},
    },
    164 => {
        Name => 'Channel8Coordinates',
        Condition => '$$self{LayoutFlags} == 1 and $$self{NumChannelDescriptions} > 7',
        Format => 'float[3]',
    },
    # (arbitrarily decode only first 8 channels)
);

# spatial audio (ref https://github.com/google/spatial-media/blob/master/docs/spatial-audio-rfc.md)
%Image::ExifTool::QuickTime::SpatialAudio = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Audio' },
    NOTES => 'Spatial Audio tags.',
    0 => 'SpatialAudioVersion',
    1 => { Name => 'AmbisonicType', PrintConv => { 0 => 'Periphonic' } },
    2 => { Name => 'AmbisonicOrder', Format => 'int32u' },
    6 => { Name => 'AmbisonicChannelOrdering', PrintConv => { 0 => 'ACN' } },
    7 => { Name => 'AmbisonicNormalization', PrintConv => { 0 => 'SN3D' } },
    8 => { Name => 'AmbisonicChannels', Format => 'int32u' },
    12 => { Name => 'AmbisonicChannelMap', Format => 'int32u[$val{8}]' },
);

# scheme type atom
# ref http://xhelmboyx.tripod.com/formats/mp4-layout.txt
%Image::ExifTool::QuickTime::SchemeType = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Audio' },
    # 0 - 4 bytes version
    4 => { Name => 'SchemeType',    Format => 'undef[4]' },
    8 => { Name => 'SchemeVersion', Format => 'int16u' },
    10 => { Name => 'SchemeURL',    Format => 'string[$size-10]' },
);

%Image::ExifTool::QuickTime::SchemeInfo = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Audio' },
    user => {
        Name => 'UserID',
        Groups => { 2 => 'Author' },
        ValueConv => '"0x" . unpack("H*",$val)',
    },
    cert => { # ref http://www.onvif.org/specs/stream/ONVIF-ExportFileFormat-Spec-v100.pdf
        Name => 'Certificate',
        ValueConv => '"0x" . unpack("H*",$val)',
    },
    'key ' => {
        Name => 'KeyID',
        ValueConv => '"0x" . unpack("H*",$val)',
    },
    iviv => {
        Name => 'InitializationVector',
        ValueConv => 'unpack("H*",$val)',
    },
    righ => {
        Name => 'Rights',
        Groups => { 2 => 'Author' },
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Rights' },
    },
    name => { Name => 'UserName', Groups => { 2 => 'Author' } },
    # chtb - seen 632 bytes of random data
    # priv - private data
    # sign
    # adkm - Adobe DRM key management system (ref http://download.macromedia.com/f4v/video_file_format_spec_v10_1.pdf)
    # iKMS
    # iSFM
    # iSLT
);

%Image::ExifTool::QuickTime::Rights = (
    PROCESS_PROC => \&ProcessRights,
    GROUPS => { 2 => 'Audio' },
    veID => 'ItemVendorID', #PH ("VendorID" ref 19)
    plat => 'Platform', #18?
    aver => 'VersionRestrictions', #19 ("appversion?" ref 18)
    tran => 'TransactionID', #18
    song => 'ItemID', #19 ("appid" ref 18)
    tool => {
        Name => 'ItemTool', #PH (guess) ("itunes build?" ref 18)
        Format => 'string',
    },
    medi => 'MediaFlags', #PH (?)
    mode => 'ModeFlags', #PH (?) 0x04 is HD flag (https://compilr.com/heksesang/requiem-mac/UnDrm.java)
    # sing - seen 4 zeros
    # hi32 - seen "00 00 00 04"
);

# MP4 hint sample description box (ref 5)
# (ref https://developer.apple.com/library/mac/documentation/QuickTime/QTFF/QTFFChap3/qtff3.html#//apple_ref/doc/uid/TP40000939-CH205-SW1)
%Image::ExifTool::QuickTime::HintSampleDesc = (
    PROCESS_PROC => \&ProcessHybrid,
    VARS => { ID_LABEL => 'ID/Index' },
    NOTES => 'MP4 hint sample description.',
    4  => { Name => 'HintFormat', Format => 'undef[4]' },
    # 14 - int16u DataReferenceIndex
    16 => { Name => 'HintTrackVersion', Format => 'int16u' },
    # 18 - int16u LastCompatibleHintTrackVersion
    20 => { Name => 'MaxPacketSize', Format => 'int32u' },
#
# Observed offsets for child atoms of various HintFormat types:
#
#   HintFormat   Offset  Child atoms
#   -----------  ------  ----------------
#   "rtp "       24      tims
#
    tims => { Name => 'RTPTimeScale',               Format => 'int32u' },
    tsro => { Name => 'TimestampRandomOffset',      Format => 'int32u' },
    snro => { Name => 'SequenceNumberRandomOffset', Format => 'int32u' },
);

# MP4 metadata sample description box
%Image::ExifTool::QuickTime::MetaSampleDesc = (
    PROCESS_PROC => \&ProcessHybrid,
    NOTES => 'MP4 metadata sample description.',
    4 => {
        Name => 'MetaFormat',
        Format => 'undef[4]',
        RawConv => '$$self{MetaFormat} = $val',
    },
    8 => { # starts at 8 for MetaFormat eq 'camm', and 17 for 'mett'
        Name => 'MetaType',
        Format => 'undef[$size-8]',
        # may start at various locations!
        RawConv => '$$self{MetaType} = ($val=~/(application[^\0]+)/ ? $1 : undef)',
    },
#
# Observed offsets for child atoms of various MetaFormat types:
#
#   MetaFormat   Offset  Child atoms
#   -----------  ------  ----------------
#   mebx         24      keys,btrt,lidp,lidl
#   fdsc         -       -
#   gpmd         -       -
#   rtmd         -       -
#   CTMD         -       -
#
   'keys' => { #PH (iPhone7+ hevc)
        Name => 'Keys',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Keys',
            ProcessProc => \&ProcessMetaKeys,
        },
    },
    btrt => {
        Name => 'BitrateInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Bitrate' },
    },
);

# MP4 generic sample description box
%Image::ExifTool::QuickTime::OtherSampleDesc = (
    PROCESS_PROC => \&ProcessHybrid,
    4 => {
        Name => 'OtherFormat',
        Format => 'undef[4]',
        RawConv => '$$self{MetaFormat} = $val', # (yes, use MetaFormat for this too)
    },
    24 => {
        Condition => '$$self{MetaFormat} eq "tmcd"',
        Name => 'PlaybackFrameRate', # (may differ from recorded FrameRate eg. ../pics/FujiFilmX-H1.mov)
        Format => 'rational64u',
    },
#
# Observed offsets for child atoms of various OtherFormat types:
#
#   OtherFormat  Offset  Child atoms
#   -----------  ------  ----------------
#   avc1         86      avcC
#   mp4a         36      esds
#   mp4s         16      esds
#   tmcd         34      name
#   data         -       -
#
    ftab => { Name => 'FontTable',  Format => 'undef', ValueConv => 'substr($val, 5)' },
    name => { Name => 'OtherName',  Format => 'undef', ValueConv => 'substr($val, 4)' },
    mrlh => { Name => 'MarlinHeader',    SubDirectory => { TagTable => 'Image::ExifTool::GM::mrlh' } },
    mrlv => { Name => 'MarlinValues',    SubDirectory => { TagTable => 'Image::ExifTool::GM::mrlv' } },
    mrld => { Name => 'MarlinDictionary',SubDirectory => { TagTable => 'Image::ExifTool::GM::mrld' } },
);

# MP4 data information box (ref 5)
%Image::ExifTool::QuickTime::DataInfo = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime, # (necessary to parse dref even though we don't change it)
    NOTES => 'MP4 data information box.',
    dref => {
        Name => 'DataRef',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::DataRef',
            Start => 8,
        },
    },
);

# Generic media header
%Image::ExifTool::QuickTime::GenMediaHeader = (
    PROCESS_PROC => \&ProcessMOV,
    gmin => {
        Name => 'GenMediaInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::GenMediaInfo' },
    },
    text => {
        Name => 'Text',
        Flags => ['Binary','Unknown'],
    },
    tmcd => {
        Name => 'TimeCode',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::TimeCode' },
    },
);

# TimeCode header
%Image::ExifTool::QuickTime::TimeCode = (
    PROCESS_PROC => \&ProcessMOV,
    tcmi => {
        Name => 'TCMediaInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::TCMediaInfo' },
    },
);

# TimeCode media info (ref 12)
%Image::ExifTool::QuickTime::TCMediaInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    4 => {
        Name => 'TextFont',
        Format => 'int16u',
        PrintConv => { 0 => 'System' },
    },
    6 => {
        Name => 'TextFace',
        Format => 'int16u',
        PrintConv => {
            0 => 'Plain',
            BITMASK => {
                0 => 'Bold',
                1 => 'Italic',
                2 => 'Underline',
                3 => 'Outline',
                4 => 'Shadow',
                5 => 'Condense',
                6 => 'Extend',
            },
        },
    },
    8 => {
        Name => 'TextSize',
        Format => 'int16u',
    },
    # 10 - reserved
    12 => {
        Name => 'TextColor',
        Format => 'int16u[3]',
    },
    18 => {
        Name => 'BackgroundColor',
        Format => 'int16u[3]',
    },
    24 => {
        Name => 'FontName',
        Format => 'pstring',
        ValueConv => '$self->Decode($val, $self->Options("CharsetQuickTime"))',
    },
);

# Generic media info (ref http://sourceforge.jp/cvs/view/ntvrec/ntvrec/libqtime/gmin.h?view=co)
%Image::ExifTool::QuickTime::GenMediaInfo = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    0  => 'GenMediaVersion',
    1  => { Name => 'GenFlags',   Format => 'int8u[3]' },
    4  => { Name => 'GenGraphicsMode',
        Format => 'int16u',
        PrintHex => 1,
        SeparateTable => 'GraphicsMode',
        PrintConv => \%graphicsMode,
    },
    6  => { Name => 'GenOpColor', Format => 'int16u[3]' },
    12 => { Name => 'GenBalance', Format => 'fixed16s' },
);

# MP4 data reference box (ref 5)
%Image::ExifTool::QuickTime::DataRef = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime, # (necessary to parse dref even though we don't change it)
    NOTES => 'MP4 data reference box.',
    'url ' => {
        Name => 'URL',
        Format => 'undef',  # (necessary to prevent decoding as string!)
        RawConv => q{
            # ignore if self-contained (flags bit 0 set)
            return undef if unpack("N",$val) & 0x01;
            $_ = substr($val,4); s/\0.*//s; $_;
        },
    },
    "url\0" => { # (written by GoPro)
        Name => 'URL',
        Format => 'undef',  # (necessary to prevent decoding as string!)
        RawConv => q{
            # ignore if self-contained (flags bit 0 set)
            return undef if unpack("N",$val) & 0x01;
            $_ = substr($val,4); s/\0.*//s; $_;
        },
    },
    'urn ' => {
        Name => 'URN',
        Format => 'undef',  # (necessary to prevent decoding as string!)
        RawConv => q{
            return undef if unpack("N",$val) & 0x01;
            $_ = substr($val,4); s/\0+/; /; s/\0.*//s; $_;
        },
    },
);

# MP4 handler box (ref 5)
%Image::ExifTool::QuickTime::Handler = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    4 => { #PH
        Name => 'HandlerClass',
        Format => 'undef[4]',
        RawConv => '$val eq "\0\0\0\0" ? undef : $val',
        PrintConv => {
            mhlr => 'Media Handler',
            dhlr => 'Data Handler',
        },
    },
    8 => {
        Name => 'HandlerType',
        Format => 'undef[4]',
        RawConv => q{
            $$self{HandlerType} = $val unless $val eq 'alis' or $val eq 'url ';
            $$self{MediaType} = $val if @{$$self{PATH}} > 1 and $$self{PATH}[-2] eq 'Media';
            $$self{HasHandler}{$val} = 1; # remember all our handlers
            return $val;
        },
        PrintConvColumns => 2,
        PrintConv => {
            alis => 'Alias Data', #PH
            crsm => 'Clock Reference', #3
            hint => 'Hint Track',
            ipsm => 'IPMP', #3
            m7sm => 'MPEG-7 Stream', #3
            meta => 'NRT Metadata', #PH
            mdir => 'Metadata', #3
            mdta => 'Metadata Tags', #PH
            mjsm => 'MPEG-J', #3
            ocsm => 'Object Content', #3
            odsm => 'Object Descriptor', #3
            priv => 'Private', #PH
            sdsm => 'Scene Description', #3
            soun => 'Audio Track',
            text => 'Text', #PH (but what type? subtitle?)
            tmcd => 'Time Code', #PH
           'url '=> 'URL', #3
            vide => 'Video Track',
            subp => 'Subpicture', #http://www.google.nl/patents/US7778526
            nrtm => 'Non-Real Time Metadata', #PH (Sony ILCE-7S) [how is this different from "meta"?]
            pict => 'Picture', # (HEIC images)
            camm => 'Camera Metadata', # (Insta360 MP4)
            psmd => 'Panasonic Static Metadata', #PH (Leica C-Lux CAM-DC25)
            data => 'Data', #PH (GPS and G-sensor data from DataKam)
            sbtl => 'Subtitle', #PH (TomTom Bandit Action Cam)
        },
    },
    12 => { #PH
        Name => 'HandlerVendorID',
        Format => 'undef[4]',
        RawConv => '$val eq "\0\0\0\0" ? undef : $val',
        PrintConv => \%vendorID,
        SeparateTable => 'VendorID',
    },
    24 => {
        Name => 'HandlerDescription',
        Format => 'string',
        # (sometimes this is a Pascal string, and sometimes it is a C string)
        RawConv => q{
            $val=substr($val,1,ord($1)) if $val=~/^([\0-\x1f])/ and ord($1)<length($val);
            length $val ? $val : undef;
        },
    },
);

# Flip uuid data (ref PH)
%Image::ExifTool::QuickTime::Flip = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    NOTES => 'Found in MP4 files from Flip Video cameras.',
    GROUPS => { 1 => 'MakerNotes', 2 => 'Image' },
    1 => 'PreviewImageWidth',
    2 => 'PreviewImageHeight',
    13 => 'PreviewImageLength',
    14 => { # (confirmed for FlipVideoMinoHD)
        Name => 'SerialNumber',
        Groups => { 2 => 'Camera' },
        Format => 'string[16]',
    },
    28 => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        Format => 'undef[$val{13}]',
        RawConv => '$self->ValidateImage(\$val, $tag)',
    },
);

# atoms in Pittasoft "free" atom
%Image::ExifTool::QuickTime::Pittasoft = (
    PROCESS_PROC => \&ProcessMOV,
    NOTES => 'Tags found in Pittasoft Blackvue dashcam "free" data.',
    cprt => 'Copyright',
    thum => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        Binary => 1,
        RawConv => q{
            return undef unless length $val > 4;
            my $len = unpack('N', $val);
            return undef unless length $val >= 4 + $len;
            return substr($val, 4, $len);
        },
    },
    ptnm => {
        Name => 'OriginalFileName',
        ValueConv => 'substr($val, 4, -1)',
    },
    ptrh => {
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Pittasoft' },
        # contains these atoms:
        # ptvi - 27 bytes: '..avc1...'
        # ptso - 16 bytes: '..mp4a...'
    },
    'gps ' => {
        Name => 'GPSLog',
        Binary => 1,    # (ASCII NMEA track log with leading timestamps)
        Notes => 'parsed to extract GPS separately when ExtractEmbedded is used',
        RawConv => q{
            $val =~ s/\0+$//;   # remove trailing nulls
            if (length $val and $$self{OPTIONS}{ExtractEmbedded}) {
                my $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
                Image::ExifTool::QuickTime::ProcessGPSLog($self, { DataPt => \$val }, $tagTbl);
            }
            return $val;
        },
    },
    '3gf ' => {
        Name => 'AccelData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Stream',
            ProcessProc => \&Process_3gf,
        },
    },
    sttm => {
        Name => 'StartTime',
        Format => 'int64u',
        Groups => { 2 => 'Time' },
        RawConv => '$$self{StartTime} = $val',
        # (ms since Jan 1, 1970, in local time zone - PH)
        ValueConv => q{
            my $secs = int($val / 1000);
            return ConvertUnixTime($secs) . sprintf(".%03d",$val - $secs * 1000);
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
);

# Nextbase tags (ref PH)
%Image::ExifTool::QuickTime::Nextbase = (
    GROUPS => { 1 => 'Nextbase', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessNextbase,
    WRITE_PROC => \&WriteNextbase,
    VARS => { LONG_TAGS => 3 },
    NOTES => q{
        Tags found in 'infi' atom from some Nextbase videos.  As well as these tags,
        other existing tags are also extracted.  These tags are not currently
        writable but they may all be removed by deleting the Nextbase group.
    },
   'Wi-Fi SSID' => { },
   'Wi-Fi Password' => { },
   'Wi-Fi MAC Address' => { },
   'Model' => { },
   'Firmware' => { },
   'Serial No' => { Name => 'SerialNumber' },
   'FCC-ID' => { },
   'Battery Status' => { },
   'SD Card Manf ID' => { },
   'SD Card OEM ID' => { },
   'SD Card Model No' => { },
   'SD Card Serial No' => { },
   'SD Card Manf Date' => { },
   'SD Card Type' => { },
   'SD Card Used Space' => { },
   'SD Card Class' => { },
   'SD Card Size' => { },
   'SD Card Format' => { },
   'Wi-Fi SSID' => { },
   'Wi-Fi Password' => { },
   'Wi-Fi MAC Address' => { },
   'Bluetooth Name' => { },
   'Bluetooth MAC Address' => { },
   'Resolution' => { },
   'Exposure' => { },
   'Video Length' => { },
   'Audio' => { },
   'Time Stamp' => { Name => 'VideoTimeStamp' },
   'Speed Stamp' => { },
   'GPS Stamp' => { },
   'Model Stamp' => { },
   'Dual Files' => { },
   'Time Lapse' => { },
   'Number / License Plate' => { },
   'G Sensor' => { },
   'Image Stabilisation' => { },
   'Extreme Weather Mode' => { },
   'Screen Saver' => { },
   'Alerts' => { },
   'Recording History' => { },
   'Parking Mode' => { },
   'Language' => { },
   'Country' => { },
   'Time Zone / DST' => { Groups => { 2 => 'Time' } },
   'Time & Date' => { Name => 'TimeAndDate', Groups => { 2 => 'Time' } },
   'Speed Units' => { },
   'Device Sounds' => { },
   'Screen Dimming' => { },
   'Auto Power Off' => { },
   'Keep User Settings' => { },
   'System Info' => { },
   'Format SD Card' => { },
   'Default Settings' => { },
   'Emergency SOS' => { },
   'Reversing Camera' => { },
   'what3words' => { Name => 'What3Words' },
   'MyNextbase - Pairing' => { },
   'MyNextbase - Paired Device Name' => { },
   'Alexa' => { },
   'Alexa - Pairing' => { },
   'Alexa - Paired Device Name' => { },
   'Alexa - Privacy Mode' => { },
   'Alexa - Wake Word Language' => { },
   'Firmware Version' => { },
   'RTOS' => { },
   'Linux' => { },
   'NBCD' => { },
   'Alexa' => { },
   '2nd Cam' => { Name => 'SecondCam' },
);

# QuickTime composite tags
%Image::ExifTool::QuickTime::Composite = (
    GROUPS => { 2 => 'Video' },
    Rotation => {
        Notes => q{
            degrees of clockwise camera rotation. Writing this tag updates QuickTime
            MatrixStructure for all tracks with a non-zero image size
        },
        Require => {
            0 => 'QuickTime:MatrixStructure',
            1 => 'QuickTime:HandlerType',
        },
        Writable => 1,
        Protected => 1,
        WriteAlso => {
            MatrixStructure => 'Image::ExifTool::QuickTime::GetRotationMatrix($val)',
        },
        ValueConv => 'Image::ExifTool::QuickTime::CalcRotation($self)',
        ValueConvInv => '$val',
    },
    AvgBitrate => {
        Priority => 0,  # let QuickTime::AvgBitrate take priority
        Require => {
            0 => 'QuickTime::MediaDataSize',
            1 => 'QuickTime::Duration',
        },
        RawConv => q{
            return undef unless $val[1];
            $val[1] /= $$self{TimeScale} if $$self{TimeScale};
            my $key = 'MediaDataSize';
            my $size = $val[0];
            for (;;) {
                $key = $self->NextTagKey($key) or last;
                $size += $self->GetValue($key, 'ValueConv');
            }
            return int($size * 8 / $val[1] + 0.5);
        },
        PrintConv => 'ConvertBitrate($val)',
    },
    GPSLatitude => {
        Require => 'QuickTime:GPSCoordinates',
        Groups => { 2 => 'Location' },
        ValueConv => 'my @c = split " ", $val; $c[0]',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    GPSLongitude => {
        Require => 'QuickTime:GPSCoordinates',
        Groups => { 2 => 'Location' },
        ValueConv => 'my @c = split " ", $val; $c[1]',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    # split altitude into GPSAltitude/GPSAltitudeRef like EXIF and XMP
    GPSAltitude => {
        Require => 'QuickTime:GPSCoordinates',
        Groups => { 2 => 'Location' },
        Priority => 0, # (because it may not exist)
        ValueConv => 'my @c = split " ", $val; defined $c[2] ? abs($c[2]) : undef',
        PrintConv => '"$val m"',
    },
    GPSAltitudeRef  => {
        Require => 'QuickTime:GPSCoordinates',
        Groups => { 2 => 'Location' },
        Priority => 0, # (because altitude information may not exist)
        ValueConv => 'my @c = split " ", $val; defined $c[2] ? ($c[2] < 0 ? 1 : 0) : undef',
        PrintConv => {
            0 => 'Above Sea Level',
            1 => 'Below Sea Level',
        },
    },
    GPSLatitude2 => {
        Name => 'GPSLatitude',
        Require => 'QuickTime:LocationInformation',
        Groups => { 2 => 'Location' },
        ValueConv => '$val =~ /Lat=([-+.\d]+)/; $1',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    GPSLongitude2 => {
        Name => 'GPSLongitude',
        Require => 'QuickTime:LocationInformation',
        Groups => { 2 => 'Location' },
        ValueConv => '$val =~ /Lon=([-+.\d]+)/; $1',
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    GPSAltitude2 => {
        Name => 'GPSAltitude',
        Require => 'QuickTime:LocationInformation',
        Groups => { 2 => 'Location' },
        ValueConv => '$val =~ /Alt=([-+.\d]+)/; abs($1)',
        PrintConv => '"$val m"',
    },
    GPSAltitudeRef2  => {
        Name => 'GPSAltitudeRef',
        Require => 'QuickTime:LocationInformation',
        Groups => { 2 => 'Location' },
        ValueConv => '$val =~ /Alt=([-+.\d]+)/; $1 < 0 ? 1 : 0',
        PrintConv => {
            0 => 'Above Sea Level',
            1 => 'Below Sea Level',
        },
    },
    CDDBDiscPlayTime => {
        Require => 'CDDB1Info',
        Groups => { 2 => 'Audio' },
        ValueConv => '$val =~ /^..([a-z0-9]{4})/i ? hex($1) : undef',
        PrintConv => 'ConvertDuration($val)',
    },
    CDDBDiscTracks => {
        Require => 'CDDB1Info',
        Groups => { 2 => 'Audio' },
        ValueConv => '$val =~ /^.{6}([a-z0-9]{2})/i ? hex($1) : undef',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::QuickTime');


#------------------------------------------------------------------------------
# AutoLoad our routines when necessary
#
sub AUTOLOAD
{
    # (Note: no need to autoload routines in QuickTimeStream that use Stream table)
    if ($AUTOLOAD eq 'Image::ExifTool::QuickTime::Process_mebx') {
        require 'Image/ExifTool/QuickTimeStream.pl';
        no strict 'refs';
        return &$AUTOLOAD(@_);
    } else {
        return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
    }
}

#------------------------------------------------------------------------------
# Get rotation matrix
# Inputs: 0) angle in degrees
# Returns: 9-element rotation matrix as a string (with 0 x/y offsets)
sub GetRotationMatrix($)
{
    my $ang = 3.14159265358979323846264 * shift() / 180;
    my $cos = cos $ang;
    my $sin = sin $ang;
    # round to zero
    $cos = 0 if abs($cos) < 1e-12;
    $sin = 0 if abs($sin) < 1e-12;
    my $msn = -$sin;
    return "$cos $sin 0 $msn $cos 0 0 0 1";
}

#------------------------------------------------------------------------------
# Get rotation angle from a matrix
# Inputs: 0) rotation matrix as a string
# Return: positive rotation angle in degrees rounded to 3 decimal points,
#         or undef on error
sub GetRotationAngle($)
{
    my $rotMatrix = shift;
    my @a = split ' ', $rotMatrix;
    return undef if $a[0]==0 and $a[1]==0;
    # calculate the rotation angle (assume uniform rotation)
    my $angle = atan2($a[1], $a[0]) * 180 / 3.14159;
    $angle += 360 if $angle < 0;
    return int($angle * 1000 + 0.5) / 1000;
}

#------------------------------------------------------------------------------
# Calculate rotation of video track
# Inputs: 0) ExifTool object ref
# Returns: rotation angle or undef
sub CalcRotation($)
{
    my $et = shift;
    my $value = $$et{VALUE};
    my ($i, $track);
    # get the video track family 1 group (eg. "Track1");
    for ($i=0; ; ++$i) {
        my $idx = $i ? " ($i)" : '';
        my $tag = "HandlerType$idx";
        last unless $$value{$tag};
        next unless $$value{$tag} eq 'vide';
        $track = $et->GetGroup($tag, 1);
        last;
    }
    return undef unless $track;
    # get the video track matrix
    for ($i=0; ; ++$i) {
        my $idx = $i ? " ($i)" : '';
        my $tag = "MatrixStructure$idx";
        last unless $$value{$tag};
        next unless $et->GetGroup($tag, 1) eq $track;
        return GetRotationAngle($$value{$tag});
    }
    return undef;
}

#------------------------------------------------------------------------------
# Get MatrixStructure for a given rotation angle
# Inputs: 0) rotation angle (deg), 1) ExifTool ref
# Returns: matrix structure as a string, or undef if it can't be rotated
# - requires ImageSizeLookahead to determine the video image size, and doesn't
#   rotate matrix unless image size is valid
sub GetMatrixStructure($$)
{
    my ($val, $et) = @_;
    my @a = split ' ', $val;
    # pass straight through if it already has an offset
    return $val unless $a[6] == 0 and $a[7] == 0;
    my @s = split ' ', $$et{ImageSizeLookahead};
    my ($w, $h) = @s[12,13];
    return undef unless $w and $h;  # don't rotate 0-sized track
    $_ = Image::ExifTool::QuickTime::FixWrongFormat($_) foreach $w,$h;
    # apply necessary offsets for the standard rotations
    my $angle = GetRotationAngle($val);
    return undef unless defined $angle;
    if ($angle == 90) {
        @a[6,7] = ($h, 0);
    } elsif ($angle == 180) {
        @a[6,7] = ($w, $h);
    } elsif ($angle == 270) {
        @a[6,7] = (0, $w);
    }
    return "@a";
}

#------------------------------------------------------------------------------
# Determine the average sample rate from a time-to-sample table
# Inputs: 0) ExifTool object ref, 1) time-to-sample table data ref
# Returns: average sample rate (in Hz)
sub CalcSampleRate($$)
{
    my ($et, $valPt) = @_;
    my @dat = unpack('N*', $$valPt);
    my ($num, $dur) = (0, 0);
    my $i;
    for ($i=2; $i<@dat-1; $i+=2) {
        $num += $dat[$i];               # total number of samples
        $dur += $dat[$i] * $dat[$i+1];  # total sample duration
    }
    return undef unless $num and $dur and $$et{MediaTS};
    return $num * $$et{MediaTS} / $dur;
}

#------------------------------------------------------------------------------
# Fix incorrect format for ImageWidth/Height as written by Pentax
sub FixWrongFormat($)
{
    my $val = shift;
    return undef unless $val;
    return $val & 0xfff00000 ? unpack('n',pack('N',$val)) : $val;
}

#------------------------------------------------------------------------------
# Convert ISO 6709 string to standard lag/lon format
# Inputs: 0) ISO 6709 string (lat, lon, and optional alt)
# Returns: position in decimal degrees with altitude if available
# Notes: Wikipedia indicates altitude may be in feet -- how is this specified?
sub ConvertISO6709($)
{
    my $val = shift;
    if ($val =~ /^([-+]\d{1,2}(?:\.\d*)?)([-+]\d{1,3}(?:\.\d*)?)([-+]\d+(?:\.\d*)?)?/) {
        # +DD.DDD+DDD.DDD+AA.AAA
        $val = ($1 + 0) . ' ' . ($2 + 0);
        $val .= ' ' . ($3 + 0) if $3;
    } elsif ($val =~ /^([-+])(\d{2})(\d{2}(?:\.\d*)?)([-+])(\d{3})(\d{2}(?:\.\d*)?)([-+]\d+(?:\.\d*)?)?/) {
        # +DDMM.MMM+DDDMM.MMM+AA.AAA
        my $lat = $2 + $3 / 60;
        $lat = -$lat if $1 eq '-';
        my $lon = $5 + $6 / 60;
        $lon = -$lon if $4 eq '-';
        $val = "$lat $lon";
        $val .= ' ' . ($7 + 0) if $7;
    } elsif ($val =~ /^([-+])(\d{2})(\d{2})(\d{2}(?:\.\d*)?)([-+])(\d{3})(\d{2})(\d{2}(?:\.\d*)?)([-+]\d+(?:\.\d*)?)?/) {
        # +DDMMSS.SSS+DDDMMSS.SSS+AA.AAA
        my $lat = $2 + $3 / 60 + $4 / 3600;
        $lat = -$lat if $1 eq '-';
        my $lon = $6 + $7 / 60 + $8 / 3600;
        $lon = -$lon if $5 eq '-';
        $val = "$lat $lon";
        $val .= ' ' . ($9 + 0) if $9;
    }
    return $val;
}

#------------------------------------------------------------------------------
# Convert Nero chapter list (ref ffmpeg libavformat/movenc.c)
# Inputs: 0) binary chpl data
# Returns: chapter list
sub ConvertChapterList($)
{
    my $val = shift;
    my $size = length $val;
    return '<invalid>' if $size < 9;
    my $num = Get8u(\$val, 8);
    my ($i, @chapters);
    my $pos = 9;
    for ($i=0; $i<$num; ++$i) {
        last if $pos + 9 > $size;
        my $dur = Get64u(\$val, $pos) / 10000000;
        my $len = Get8u(\$val, $pos + 8);
        last if $pos + 9 + $len > $size;
        my $title = substr($val, $pos + 9, $len);
        $pos += 9 + $len;
        push @chapters, "$dur $title";
    }
    return \@chapters;  # return as a list
}

#------------------------------------------------------------------------------
# Print conversion for a Nero chapter list item
# Inputs: 0) ValueConv chapter string
# Returns: formatted chapter string
sub PrintChapter($)
{
    my $val = shift;
    $val =~ /^(\S+) (.*)/ or return $val;
    my ($dur, $title) = ($1, $2);
    my $h = int($dur / 3600);
    $dur -= $h * 3600;
    my $m = int($dur / 60);
    my $s = $dur - $m * 60;
    my $ss = sprintf('%06.3f', $s);
    if ($ss >= 60) {
        $ss = '00.000';
        ++$m >= 60 and $m -= 60, ++$h;
    }
    return sprintf("[%d:%.2d:%s] %s",$h,$m,$ss,$title);
}

#------------------------------------------------------------------------------
# Format GPSCoordinates for printing
# Inputs: 0) string with numerical lat, lon and optional alt, separated by spaces
#         1) ExifTool object reference
# Returns: PrintConv value
sub PrintGPSCoordinates($)
{
    my ($val, $et) = @_;
    my @v = split ' ', $val;
    my $prt = Image::ExifTool::GPS::ToDMS($et, $v[0], 1, "N") . ', ' .
              Image::ExifTool::GPS::ToDMS($et, $v[1], 1, "E");
    if (defined $v[2]) {
        $prt .= ', ' . ($v[2] < 0 ? -$v[2] . ' m Below' : $v[2] . ' m Above') . ' Sea Level';
    }
    return $prt;
}

#------------------------------------------------------------------------------
# Unpack packed ISO 639/T language code
# Inputs: 0) packed language code (or undef/0), 1) true to not treat 'und' and 'eng' as default
# Returns: language code, or undef/0 for default language, or 'err' for format error
sub UnpackLang($;$)
{
    my ($lang, $noDef) = @_;
    if ($lang) {
        # language code is packed in 5-bit characters
        $lang = pack 'C*', map { (($lang>>$_)&0x1f)+0x60 } 10, 5, 0;
        # validate language code
        if ($lang =~ /^[a-z]+$/) {
            # treat 'eng' or 'und' as the default language
            undef $lang if ($lang eq 'und' or $lang eq 'eng') and not $noDef;
        } else {
            $lang = 'err';  # invalid language code
        }
    }
    return $lang;
}

#------------------------------------------------------------------------------
# Get language code string given QuickTime language and country codes
# Inputs: 0) numerical language code, 1) numerical country code, 2) no defaults
# Returns: language code string (ie. "fra-FR") or undef for default language
# ex) 0x15c7 0x0000 is 'eng' with no country (ie. returns 'und' unless $noDef)
#     0x15c7 0x5553 is 'eng-US'
#     0x1a41 0x4652 is 'fra-FR'
#     0x55c4 is 'und'
sub GetLangCode($;$$)
{
    my ($lang, $ctry, $noDef) = @_;
    # ignore country ('ctry') and language lists ('lang') for now
    undef $ctry if $ctry and $ctry <= 255;
    undef $lang if $lang and $lang <= 255;
    my $langCode = UnpackLang($lang, $noDef);
    # add country code if specified
    if ($ctry) {
        $ctry = unpack('a2',pack('n',$ctry)); # unpack as ISO 3166-1
        # treat 'ZZ' like a default country (see ref 12)
        undef $ctry if $ctry eq 'ZZ';
        if ($ctry and $ctry =~ /^[A-Z]{2}$/) {
            $langCode or $langCode = UnpackLang($lang,1) || 'und';
            $langCode .= "-$ctry";
        }
    }
    return $langCode;
}

#------------------------------------------------------------------------------
# Get langInfo hash and save details about alt-lang tags
# Inputs: 0) ExifTool ref, 1) tagInfo hash ref, 2) locale code
# Returns: new tagInfo hash ref, or undef if invalid
sub GetLangInfoQT($$$)
{
    my ($et, $tagInfo, $langCode) = @_;
    my $langInfo = Image::ExifTool::GetLangInfo($tagInfo, $langCode);
    if ($langInfo) {
        $$et{QTLang} or $$et{QTLang} = [ ];
        push @{$$et{QTLang}}, $$langInfo{Name};
    }
    return $langInfo;
}

#------------------------------------------------------------------------------
# Get variable-length integer from data (used by ParseItemLocation)
# Inputs: 0) data ref, 1) start position, 2) integer size in bytes (0, 4 or 8),
#         3) default value
# Returns: integer value, and updates current position
sub GetVarInt($$$;$)
{
    my ($dataPt, $pos, $n, $default) = @_;
    my $len = length $$dataPt;
    $_[1] = $pos + $n;  # update current position
    return undef if $pos + $n > $len;
    if ($n == 0) {
        return $default || 0;
    } elsif ($n == 4) {
        return Get32u($dataPt, $pos);
    } elsif ($n == 8) {
        return Get64u($dataPt, $pos);
    }
    return undef;
}

#------------------------------------------------------------------------------
# Get null-terminated string from binary data (used by ParseItemInfoEntry)
# Inputs: 0) data ref, 1) start position
# Returns: string, and updates current position
sub GetString($$)
{
    my ($dataPt, $pos) = @_;
    my $len = length $$dataPt;
    my $str = '';
    while ($pos < $len) {
        my $ch = substr($$dataPt, $pos, 1);
        ++$pos;
        last if ord($ch) == 0;
        $str .= $ch;
    }
    $_[1] = $pos;   # update current position
    return $str;
}

#------------------------------------------------------------------------------
# Get a printable version of the tag ID
# Inputs: 0) tag ID, 1) Flag: 0x01 - print as 4- or 8-digit hex value if necessary
#                             0x02 - put leading backslash before escaped character
# Returns: Printable tag ID
sub PrintableTagID($;$)
{
    my $tag = $_[0];
    my $n = ($tag =~ s/([\x00-\x1f\x7f-\xff])/'x'.unpack('H*',$1)/eg);
    if ($n and $_[1]) {
        if ($n > 2 and $_[1] & 0x01) {
            $tag = '0x' . unpack('H8', $_[0]);
            $tag =~ s/^0x0000/0x/;
        } elsif ($_[1] & 0x02) {
            ($tag = $_[0]) =~ s/([\x00-\x1f\x7f-\xff])/'\\x'.unpack('H*',$1)/eg;
        }
    }
    return $tag;
}

#==============================================================================
# The following ParseXxx routines parse various boxes to extract this
# information about embedded items in a $$et{ItemInfo} hash, keyed by item ID:
#
# iloc:
#  ConstructionMethod - offset type: 0=file, 1=idat, 2=item
#  DataReferenceIndex - 0 for "this file", otherwise index in dref box
#  BaseOffset         - base for file offsets
#  Extents            - list of details for data in file:
#                           0) index  (extent_index)
#                           1) offset (extent_offset)
#                           2) length (extent_length)
#                           3) nlen   (length_size)
#                           4) lenPt  (pointer to length word)
# infe:
#  ProtectionIndex    - index if item is protected (0 for unprotected)
#  Name               - item name
#  ContentType        - mime type of item
#  ContentEncoding    - item encoding
#  URI                - URI of a 'uri '-type item
#  infe               - raw data for 'infe' box (when writing only) [retracted]
# ipma:
#  Association        - list of associated properties in the ipco container
#  Essential          - list of "essential" flags for the associated properties
# cdsc:
#  RefersTo           - hash lookup of flags based on referred item ID
# other:
#  DocNum             - exiftool document number for this item
#
#------------------------------------------------------------------------------
# Parse item location (iloc) box (ref ISO 14496-12:2015 pg.79)
# Inputs: 0) iloc data, 1) ExifTool ref
# Returns: undef, and fills in ExifTool ItemInfo hash
# Notes: see also Handle_iloc() in WriteQuickTime.pl
sub ParseItemLocation($$)
{
    my ($val, $et) = @_;
    my ($i, $j, $num, $pos, $id);
    my ($extent_index, $extent_offset, $extent_length);

    my $verbose = $$et{IsWriting} ? 0 : $et->Options('Verbose');
    my $items = $$et{ItemInfo} || ($$et{ItemInfo} = { });
    my $len = length $val;
    return undef if $len < 8;
    my $ver = Get8u(\$val, 0);
    my $siz = Get16u(\$val, 4);
    my $noff = ($siz >> 12);
    my $nlen = ($siz >> 8) & 0x0f;
    my $nbas = ($siz >> 4) & 0x0f;
    my $nind = $siz & 0x0f;
    if ($ver < 2) {
        $num = Get16u(\$val, 6);
        $pos = 8;
    } else {
        return undef if $len < 10;
        $num = Get32u(\$val, 6);
        $pos = 10;
    }
    for ($i=0; $i<$num; ++$i) {
        if ($ver < 2) {
            return undef if $pos + 2 > $len;
            $id = Get16u(\$val, $pos);
            $pos += 2;
        } else {
            return undef if $pos + 4 > $len;
            $id = Get32u(\$val, $pos);
            $pos += 4;
        }
        if ($ver == 1 or $ver == 2) {
            return undef if $pos + 2 > $len;
            $$items{$id}{ConstructionMethod} = Get16u(\$val, $pos) & 0x0f;
            $pos += 2;
        }
        return undef if $pos + 2 > $len;
        $$items{$id}{DataReferenceIndex} = Get16u(\$val, $pos);
        $pos += 2;
        $$items{$id}{BaseOffset} = GetVarInt(\$val, $pos, $nbas);
        return undef if $pos + 2 > $len;
        my $ext_num = Get16u(\$val, $pos);
        $pos += 2;
        my @extents;
        for ($j=0; $j<$ext_num; ++$j) {
            if ($ver == 1 or $ver == 2) {
                $extent_index = GetVarInt(\$val, $pos, $nind, 1);
            }
            $extent_offset = GetVarInt(\$val, $pos, $noff);
            $extent_length = GetVarInt(\$val, $pos, $nlen);
            return undef unless defined $extent_length;
            $et->VPrint(1, "$$et{INDENT}  Item $id: const_meth=",
                defined $$items{$id}{ConstructionMethod} ? $$items{$id}{ConstructionMethod} : '',
                sprintf(" base=0x%x offset=0x%x len=0x%x\n", $$items{$id}{BaseOffset},
                    $extent_offset, $extent_length)) if $verbose;
            push @extents, [ $extent_index, $extent_offset, $extent_length, $nlen, $pos-$nlen ];
        }
        # save item location information keyed on 1-based item ID:
        $$items{$id}{Extents} = \@extents;
    }
    return undef;
}

#------------------------------------------------------------------------------
# Parse content describes entry (cdsc) box
# Inputs: 0) cdsc data, 1) ExifTool ref
# Returns: undef, and fills in ExifTool ItemInfo hash
sub ParseContentDescribes($$)
{
    my ($val, $et) = @_;
    my ($id, $count, @to);
    if ($$et{ItemRefVersion}) {
        return undef if length $val < 10;
        ($id, $count, @to) = unpack('NnN*', $val);
    } else {
        return undef if length $val < 6;
        ($id, $count, @to) = unpack('nnn*', $val);
    }
    if ($count > @to) {
        my $str = 'Missing values in ContentDescribes box';
        $$et{IsWriting} ? $et->Error($str) : $et->Warn($str);
    } elsif ($count < @to) {
        $et->Warn('Ignored extra values in ContentDescribes box', 1);
        @to = $count;
    }
    # add all referenced item ID's to a "RefersTo" lookup
    $$et{ItemInfo}{$id}{RefersTo}{$_} = 1 foreach @to;
    return undef;
}

#------------------------------------------------------------------------------
# Parse item information entry (infe) box (ref ISO 14496-12:2015 pg.82)
# Inputs: 0) infe data, 1) ExifTool ref
# Returns: undef, and fills in ExifTool ItemInfo hash
sub ParseItemInfoEntry($$)
{
    my ($val, $et) = @_;
    my $id;

    my $verbose = $$et{IsWriting} ? 0 : $et->Options('Verbose');
    my $items = $$et{ItemInfo} || ($$et{ItemInfo} = { });
    my $len = length $val;
    return undef if $len < 4;
    my $ver = Get8u(\$val, 0);
    my $pos = 4;
    return undef if $pos + 4 > $len;
    if ($ver == 0 or $ver == 1) {
        $id = Get16u(\$val, $pos);
        $$items{$id}{ProtectionIndex} = Get16u(\$val, $pos + 2);
        $pos += 4;
        $$items{$id}{Name} = GetString(\$val, $pos);
        $$items{$id}{ContentType} = GetString(\$val, $pos);
        $$items{$id}{ContentEncoding} = GetString(\$val, $pos);
    } else {
        if ($ver == 2) {
            $id = Get16u(\$val, $pos);
            $pos += 2;
        } elsif ($ver == 3) {
            $id = Get32u(\$val, $pos);
            $pos += 4;
        }
        return undef if $pos + 6 > $len;
        $$items{$id}{ProtectionIndex} = Get16u(\$val, $pos);
        my $type = substr($val, $pos + 2, 4);
        $$items{$id}{Type} = $type;
        $pos += 6;
        $$items{$id}{Name} = GetString(\$val, $pos);
        if ($type eq 'mime') {
            $$items{$id}{ContentType} = GetString(\$val, $pos);
            $$items{$id}{ContentEncoding} = GetString(\$val, $pos);
        } elsif ($type eq 'uri ') {
            $$items{$id}{URI} = GetString(\$val, $pos);
        }
    }
    #[retracted] # save raw infe box when writing in case we need to sort items later
    #[retracted] $$items{$id}{infe} = pack('N', length($val)+8) . 'infe' . $val if $$et{IsWriting};
    $et->VPrint(1, "$$et{INDENT}  Item $id: Type=", $$items{$id}{Type} || '',
                   ' Name=', $$items{$id}{Name} || '',
                   ' ContentType=', $$items{$id}{ContentType} || '',
                   ($$et{PrimaryItem} and $$et{PrimaryItem} == $id) ? ' (PrimaryItem)' : '',
                   "\n") if $verbose > 1;
    unless ($id > $$et{LastItemID}) {
        $et->Warn('Item info entries are out of order'); #[retracted] unless $$et{IsWriting};
        #[retracted] $$et{ItemsNotSorted} = 1;   # set flag indicating the items weren't sorted
    }
    $$et{LastItemID} = $id;
    return undef;
}

#------------------------------------------------------------------------------
# Parse item property association (ipma) box (ref https://github.com/gpac/gpac/blob/master/src/isomedia/iff.c)
# Inputs: 0) ipma data, 1) ExifTool ref
# Returns: undef, and fills in ExifTool ItemInfo hash
sub ParseItemPropAssoc($$)
{
    my ($val, $et) = @_;
    my ($i, $j, $id);

    my $verbose = $$et{IsWriting} ? 0 : $et->Options('Verbose');
    my $items = $$et{ItemInfo} || ($$et{ItemInfo} = { });
    my $len = length $val;
    return undef if $len < 8;
    my $ver = Get8u(\$val, 0);
    my $flg = Get32u(\$val, 0);
    my $num = Get32u(\$val, 4);
    my $pos = 8;
    my $lastID = -1;
    for ($i=0; $i<$num; ++$i) {
        if ($ver == 0) {
            return undef if $pos + 3 > $len;
            $id = Get16u(\$val, $pos);
            $pos += 2;
        } else {
            return undef if $pos + 5 > $len;
            $id = Get32u(\$val, $pos);
            $pos += 4;
        }
        my $n = Get8u(\$val, $pos++);
        my (@association, @essential);
        if ($flg & 0x01) {
            return undef if $pos + $n * 2 > $len;
            for ($j=0; $j<$n; ++$j) {
                my $tmp = Get16u(\$val, $pos + $j * 2);
                push @association, $tmp & 0x7fff;
                push @essential, ($tmp & 0x8000) ? 1 : 0;
            }
            $pos += $n * 2;
        } else {
            return undef if $pos + $n > $len;
            for ($j=0; $j<$n; ++$j) {
                my $tmp = Get8u(\$val, $pos + $j);
                push @association, $tmp & 0x7f;
                push @essential, ($tmp & 0x80) ? 1 : 0;
            }
            $pos += $n;
        }
        $$items{$id}{Association} = \@association;
        $$items{$id}{Essential} = \@essential;
        $et->VPrint(1, "$$et{INDENT}  Item $id properties: @association\n") if $verbose > 1;
        # (according to ISO/IEC 23008-12, these entries must be sorted by item ID)
        $et->Warn('Item property association entries are out of order') unless $id > $lastID;
        $lastID = $id;
    }
    return undef;
}

#------------------------------------------------------------------------------
# Process item information now
# Inputs: 0) ExifTool ref
sub HandleItemInfo($)
{
    my $et = shift;
    my $raf = $$et{RAF};
    my $items = $$et{ItemInfo};
    my $verbose = $et->Options('Verbose');
    my $buff;

    # extract information from EXIF/XMP metadata items
    if ($items and $raf) {
        push @{$$et{PATH}}, 'ItemInformation';
        my $curPos = $raf->Tell();
        my $primary = $$et{PrimaryItem};
        my $id;
        $et->VerboseDir('Processing items from ItemInformation', scalar(keys %$items));
        foreach $id (sort { $a <=> $b } keys %$items) {
            my $item = $$items{$id};
            my $type = $$item{ContentType} || $$item{Type} || next;
            if ($verbose) {
                # add up total length of this item for the verbose output
                my $len = 0;
                if ($$item{Extents} and @{$$item{Extents}}) {
                    $len += $$_[2] foreach @{$$item{Extents}};
                }
                my $enc = $$item{ContentEncoding} ? ", $$item{ContentEncoding} encoded" : '';
                $et->VPrint(0, "$$et{INDENT}Item $id) '${type}' ($len bytes$enc)\n");
            }
            # get ExifTool name for this item
            my $name = { Exif => 'EXIF', 'application/rdf+xml' => 'XMP', jpeg => 'PreviewImage' }->{$type} || '';
            my ($warn, $extent);
            if ($$item{ContentEncoding}) {
                if ($$item{ContentEncoding} ne 'deflate') {
                    # (other possible values are 'gzip' and 'compress', but I don't have samples of these)
                    $warn = "Can't currently decode $$item{ContentEncoding} encoded $type metadata";
                } elsif (not eval { require Compress::Zlib }) {
                    $warn = "Install Compress::Zlib to decode deflated $type metadata";
                }
            }
            $warn = "Can't currently decode protected $type metadata" if $$item{ProtectionIndex};
            # Note: In HEIC's, these seem to indicate data in 'idat' instead of 'mdat'
            my $constMeth = $$item{ConstructionMethod} || 0;
            $warn = "Can't currently extract $type with construction method $constMeth" if $constMeth > 1;
            $warn = "No 'idat' for $type object with construction method 1" if $constMeth == 1 and not $$et{MediaDataInfo};
            $et->Warn($warn) if $warn and $name;
            $warn = 'Not this file' if $$item{DataReferenceIndex}; # (can only extract from "this file")
            unless (($$item{Extents} and @{$$item{Extents}}) or $warn) {
                $warn = "No Extents for $type item";
                $et->Warn($warn) if $name;
            }
            if ($warn) {
                $et->VPrint(0, "$$et{INDENT}    [not extracted]  ($warn)\n") if $verbose > 2;
                next;
            }
            my $base = ($$item{BaseOffset} || 0) + ($constMeth ? $$et{MediaDataInfo}[0] : 0);
            if ($verbose > 2) {
                # do verbose hex dump
                my $len = 0;
                undef $buff;
                my $val = '';
                my $maxLen = $verbose > 3 ? 2048 : 96;
                foreach $extent (@{$$item{Extents}}) {
                    my $n = $$extent[2];
                    my $more = $maxLen - $len;
                    if ($more > 0 and $n) {
                        $more = $n if $more > $n;
                        $val .= $buff if defined $buff;
                        $raf->Seek($$extent[1] + $base, 0) or last;
                        $raf->Read($buff, $more) or last;
                    }
                    $len += $n;
                }
                if (defined $buff) {
                    $buff = $val . $buff if length $val;
                    $et->VerboseDump(\$buff, DataPos => $$item{Extents}[0][1] + $base);
                    my $snip = $len - length $buff;
                    $et->VPrint(0, "$$et{INDENT}    [snip $snip bytes]\n") if $snip;
                }
            }
            # do hash of AVIF "av01" and HEIC image data
            if ($isImageData{$type} and $$et{ImageDataHash}) {
                my $hash = $$et{ImageDataHash};
                my $tot = 0;
                foreach $extent (@{$$item{Extents}}) {
                    $raf->Seek($$extent[1] + $base, 0) or $et->Warn("Seek error in $type image data"), last;
                    $tot += $et->ImageDataHash($raf, $$extent[2], "$type image", 1);
                }
                $et->VPrint(0, "$$et{INDENT}(ImageDataHash: $tot bytes of $type data)\n") if $tot;
            }
            next unless $name;
            # assemble the data for this item
            undef $buff;
            my $val = '';
            foreach $extent (@{$$item{Extents}}) {
                $val .= $buff if defined $buff;
                $raf->Seek($$extent[1] + $base, 0) or last;
                $raf->Read($buff, $$extent[2]) or last;
            }
            next unless defined $buff;
            $buff = $val . $buff if length $val;
            next unless length $buff;   # ignore empty directories
            if ($$item{ContentEncoding}) {
                my ($v2, $stat);
                my $inflate = Compress::Zlib::inflateInit();
                $inflate and ($v2, $stat) = $inflate->inflate($buff);
                if ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                    $buff = $v2;
                    my $len = length $buff;
                    $et->VPrint(0, "$$et{INDENT}Inflated Item $id) '${type}' ($len bytes)\n");
                    $et->VerboseDump(\$buff);
                } else {
                    $warn = "Error inflating $name metadata";
                    $et->Warn($warn);
                    $et->VPrint(0, "$$et{INDENT}    [not extracted]  ($warn)\n") if $verbose > 2;
                    next;
                }
            }
            my ($start, $subTable, $proc);
            my $pos = $$item{Extents}[0][1] + $base;
            if ($name eq 'EXIF' and length $buff >= 4) {
                if ($buff =~ /^(MM\0\x2a|II\x2a\0)/) {
                    $et->Warn('Missing Exif header');
                    $start = 0;
                } elsif ($buff =~ /^Exif\0\0/) {
                    # (haven't seen this yet, but it is just a matter of time
                    #  until someone screws it up like this)
                    $et->Warn('Missing Exif header size');
                    $start = 6;
                } else {
                    my $n = unpack('N', $buff);
                    $start = 4 + $n; # skip "Exif\0\0" header if it exists
                    if ($start > length($buff)) {
                        $et->Warn('Invalid EXIF header');
                        next;
                    }
                    if ($$et{HTML_DUMP}) {
                        $et->HDump($pos, 4, 'Exif header length', "Value: $n");
                        $et->HDump($pos+4, $start-4, 'Exif header') if $n;
                    }
                }
                $subTable = GetTagTable('Image::ExifTool::Exif::Main');
                $proc = \&Image::ExifTool::ProcessTIFF;
            } elsif ($name eq 'PreviewImage') {
                # take a quick stab at determining the size of the image
                # (based on JPEG previews found in Fuji X-H2S HIF images)
                my $type = 'PreviewImage';
                if ($buff =~ /^.{556}\xff\xc0\0\x11.(.{4})/s) {
                    my ($h, $w) = unpack('n2', $1);
                    # (not sure if $h is ever the long dimension, but test it just in case)
                    if ($w == 160 or $h == 160) {
                        $type = 'ThumbnailImage';
                    } elsif ($w == 1920 or $h == 1920) {
                        $type = 'OtherImage'; # (large preview)
                    } # (PreviewImage is 640x480)
                }
                $et->FoundTag($type => $buff);
                next;
            } else {
                $start = 0;
                $subTable = GetTagTable('Image::ExifTool::XMP::Main');
            }
            my %dirInfo = (
                DataPt   => \$buff,
                DataLen  => length $buff,
                DirStart => $start,
                DirLen   => length($buff) - $start,
                DataPos  => $pos,
                Base     => $pos + $start, # (needed for HtmlDump and IsOffset tags in binary data)
            );
            # handle processing of metadata for sub-documents
            if (defined $primary and $$item{RefersTo} and not $$item{RefersTo}{$primary}) {
                # set document number if this doesn't refer to the primary document
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                # associate this document number with the lowest item index
                my ($lowest) = sort { $a <=> $b } keys %{$$item{RefersTo}};
                $$items{$lowest}{DocNum} = $$et{DOC_NUM};
            }
            $et->ProcessDirectory(\%dirInfo, $subTable, $proc);
            delete $$et{DOC_NUM};
        }
        $raf->Seek($curPos, 0) or $et->Warn('Seek error'), last;     # seek back to original position
        pop @{$$et{PATH}};
    }
    # process the item properties now that we should know their associations and document numbers
    if ($$et{ItemPropertyContainer}) {
        my ($dirInfo, $subTable, $proc) = @{$$et{ItemPropertyContainer}};
        $$et{IsItemProperty} = 1;   # set item property flag
        $et->ProcessDirectory($dirInfo, $subTable, $proc);
        delete $$et{ItemPropertyContainer};
        delete $$et{IsItemProperty};
        delete $$et{DOC_NUM};
    }
    delete $$et{ItemInfo};
    delete $$et{MediaDataInfo};
}

#------------------------------------------------------------------------------
# Warn if ExtractEmbedded option isn't used
# Inputs: 0) ExifTool ref
sub EEWarn($)
{
    my $et = shift;
    $et->Warn('The ExtractEmbedded option may find more tags in the media data',3);
}

#------------------------------------------------------------------------------
# Get quicktime format from flags word
# Inputs: 0) quicktime atom flags, 1) data length
# Returns: ExifTool format string
sub QuickTimeFormat($$)
{
    my ($flags, $len) = @_;
    my $format;
    if ($flags == 0x15 or $flags == 0x16) {
        $format = { 1=>'int8', 2=>'int16', 4=>'int32', 8=>'int64' }->{$len};
        $format .= $flags == 0x15 ? 's' : 'u' if $format;
    } elsif ($flags == 0x17) {
        $format = 'float';
    } elsif ($flags == 0x18) {
        $format = 'double';
    } elsif ($flags == 0x00) {
        $format = { 1=>'int8u', 2=>'int16u' }->{$len};
    }
    return $format;
}

#------------------------------------------------------------------------------
# Process MPEG-4 MTDT atom (ref 11)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessMetaData($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = length $$dataPt;
    my $verbose = $et->Options('Verbose');
    return 0 unless $dirLen >= 2;
    my $count = Get16u($dataPt, 0);
    $verbose and $et->VerboseDir('MetaData', $count);
    my $i;
    my $pos = 2;
    for ($i=0; $i<$count; ++$i) {
        last if $pos + 10 > $dirLen;
        my $size = Get16u($dataPt, $pos);
        last if $size < 10 or $size + $pos > $dirLen;
        my $tag  = Get32u($dataPt, $pos + 2);
        my $lang = Get16u($dataPt, $pos + 6);
        my $enc  = Get16u($dataPt, $pos + 8);
        my $val  = substr($$dataPt, $pos + 10, $size);
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if ($tagInfo) {
            # convert language code to ASCII (ignore read-only bit)
            $lang = UnpackLang($lang);
            # handle alternate languages
            if ($lang) {
                my $langInfo = GetLangInfoQT($et, $tagInfo, $lang);
                $tagInfo = $langInfo if $langInfo;
            }
            $verbose and $et->VerboseInfo($tag, $tagInfo,
                Value  => $val,
                DataPt => $dataPt,
                Start  => $pos + 10,
                Size   => $size - 10,
            );
            # convert from UTF-16 BE if necessary
            $val = $et->Decode($val, 'UCS2') if $enc == 1;
            if ($enc == 0 and $$tagInfo{Unknown}) {
                # binary data
                $et->FoundTag($tagInfo, \$val);
            } else {
                $et->FoundTag($tagInfo, $val);
            }
        }
        $pos += $size;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process sample description table
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# (ref https://developer.apple.com/library/content/documentation/QuickTime/QTFF/QTFFChap2/qtff2.html#//apple_ref/doc/uid/TP40000939-CH204-25691)
sub ProcessSampleDesc($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || (length($$dataPt) - $pos);
    return 0 if $pos + 8 > $dirLen;

    my $num = Get32u($dataPt, 4);   # get number of sample entries in table
    $pos += 8;
    my ($i, $err);
    for ($i=0; $i<$num; ++$i) {     # loop through sample entries
        $pos + 8 > $dirLen and $err = 1, last;
        my $size = Get32u($dataPt, $pos);
        $pos + $size > $dirLen and $err = 1, last;
        $$dirInfo{DirStart} = $pos;
        $$dirInfo{DirLen} = $size;
        ProcessHybrid($et, $dirInfo, $tagTablePtr);
        $pos += $size;
    }
    if ($err and $$et{HandlerType}) {
        my $grp = $$et{SET_GROUP1} || $$dirInfo{Parent} || 'unknown';
        $et->Warn("Truncated $$et{HandlerType} sample table for $grp");
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process hybrid binary data + QuickTime container (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessHybrid($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    # brute-force search for child atoms after first 8 bytes of binary data
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || length($$dataPt) - $dirStart;
    my $end = $dirStart + $dirLen;
    my $pos = $dirStart + 8;   # skip length/version
    my $try = $pos;
    my $childPos;

    while ($pos <= $end - 8) {
        my $tag = substr($$dataPt, $try+4, 4);
        # look only for well-behaved tag ID's
        $tag =~ /[^\w ]/ and $try = ++$pos, next;
        my $size = Get32u($dataPt, $try);
        if ($size + $try == $end) {
            # the atom ends exactly at the end of the parent -- this must be it
            $childPos = $pos;
            $$dirInfo{DirLen} = $pos;   # the binary data ends at the first child atom
            last;
        }
        if ($size < 8 or $size + $try > $end - 8) {
            $try = ++$pos;  # fail.  try next position
        } else {
            $try += $size;  # could be another atom following this
        }
    }
    # process binary data
    $$dirInfo{MixedTags} = 1; # ignore non-integer tag ID's
    $et->ProcessBinaryData($dirInfo, $tagTablePtr);
    # process child atoms if found
    if ($childPos) {
        $$dirInfo{DirStart} = $childPos;
        $$dirInfo{DirLen} = $end - $childPos;
        ProcessMOV($et, $dirInfo, $tagTablePtr);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process iTunes 'righ' atom (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessRights($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{Base};
    my $dirLen = length $$dataPt;
    my $unknown = $$et{OPTIONS}{Unknown} || $$et{OPTIONS}{Verbose};
    my $pos;
    $et->VerboseDir('righ', $dirLen / 8);
    for ($pos = 0; $pos + 8 <= $dirLen; $pos += 8) {
        my $tag = substr($$dataPt, $pos, 4);
        last if $tag eq "\0\0\0\0";
        my $val = substr($$dataPt, $pos + 4, 4);
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        unless ($tagInfo) {
            next unless $unknown;
            my $name = PrintableTagID($tag);
            $tagInfo = {
                Name => "Unknown_$name",
                Description => "Unknown $name",
                Unknown => 1,
            },
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        $val = '0x' . unpack('H*', $val) unless $$tagInfo{Format};
        $et->HandleTag($tagTablePtr, $tag, $val,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $pos + 4,
            Size    => 4,
        );
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process Nextbase 'infi' atom (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessNextbase($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    $et->VerboseDir('Nextbase', undef, length($$dataPt));
    while ($$dataPt =~ /(.*?): +(.*)\x0d/g) {
        my ($id, $val) = ($1, $2);
        $$tagTbl{$id} or AddTagToTable($tagTbl, $id, { Name => Image::ExifTool::MakeTagName($id) });
        $et->HandleTag($tagTbl, $id, $val, Size => length($val));
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process iTunes Encoding Params (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessEncodingParams($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = length $$dataPt;
    my $pos;
    $et->VerboseDir('Encoding Params', $dirLen / 8);
    for ($pos = 0; $pos + 8 <= $dirLen; $pos += 8) {
        my ($tag, $val) = unpack("x${pos}a4N", $$dataPt);
        $et->HandleTag($tagTablePtr, $tag, $val);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Read Meta Keys and add tags to ItemList table ('mdta' handler) (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessKeys($$$)
{
    local $_;
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = length $$dataPt;
    my $out;
    if ($et->Options('Verbose')) {
        $et->VerboseDir('Keys');
        $out = $et->Options('TextOut');
    }
    my $pos = 8;
    my $index = 1;
    ++$$et{KeysCount};  # increment key count for this directory
    my $itemList = GetTagTable('Image::ExifTool::QuickTime::ItemList');
    my $userData = GetTagTable('Image::ExifTool::QuickTime::UserData');
    while ($pos < $dirLen - 4) {
        my $len = unpack("x${pos}N", $$dataPt);
        last if $len < 8 or $pos + $len > $dirLen;
        delete $$tagTablePtr{$index};
        my $ns  = substr($$dataPt, $pos + 4, 4);
        my $tag = substr($$dataPt, $pos + 8, $len - 8);
        $tag =~ s/\0.*//s; # truncate at null
        my $full = $tag;
        $tag =~ s/^com\.(apple\.quicktime\.)?// if $ns eq 'mdta'; # remove apple quicktime domain
        $tag = "Tag_$ns" unless $tag;
        my $short = $tag;
        my $tagInfo;
        for (;;) {
            $tagInfo = $et->GetTagInfo($tagTablePtr, $tag) and last;
            # also try ItemList and UserData tables
            $tagInfo = $et->GetTagInfo($itemList, $tag) and last;
            $tagInfo = $et->GetTagInfo($userData, $tag) and last;
            # (I have some samples where the tag is a reversed ItemList or UserData tag ID)
            if ($tag =~ /^\w{3}\xa9$/) {
                $tag = pack('N', unpack('V', $tag));
                $tagInfo = $et->GetTagInfo($itemList, $tag) and last;
                $tagInfo = $et->GetTagInfo($userData, $tag);
                last;
            }
            if ($tag eq $full) {
                $tag = $short;
                last;
            }
            $tag = $full;
        }
        my ($newInfo, $msg);
        if ($tagInfo) {
            # copy tag information into new Keys tag
            $newInfo = {
                Name      => $$tagInfo{Name},
                Format    => $$tagInfo{Format},
                ValueConv => $$tagInfo{ValueConv},
                ValueConvInv => $$tagInfo{ValueConvInv},
                PrintConv => $$tagInfo{PrintConv},
                PrintConvInv => $$tagInfo{PrintConvInv},
                Writable  => defined $$tagInfo{Writable} ? $$tagInfo{Writable} : 1,
                SubDirectory => $$tagInfo{SubDirectory},
            };
            my $groups = $$tagInfo{Groups};
            $$newInfo{Groups} = $groups ? { %$groups } : { };
            $$newInfo{Groups}{$_} or $$newInfo{Groups}{$_} = $$tagTablePtr{GROUPS}{$_} foreach 0..2;
            # set Keys group.  This is necessary for logic when reading the associated ItemList entry,
            # but note that the group name will be overridden by TAG_EXTRA G1 for tags in a track
            $$newInfo{Groups}{1} = 'Keys';
        } elsif ($tag =~ /^[-\w. ]+$/ or $tag =~ /\w{4}/) {
            # create info for tags with reasonable id's
            my $name = ucfirst $tag;
            $name =~ tr/-0-9a-zA-Z_. //dc;
            $name =~ s/[. ]+(.?)/\U$1/g;
            $name =~ s/_([a-z])/_\U$1/g;
            $name =~ s/([a-z])_([A-Z])/$1$2/g;
            $name = "Tag_$name" if length $name < 2;
            $newInfo = { Name => $name, Groups => { 1 => 'Keys' } };
            $msg = ' (Unknown)';
        }
        # substitute this tag in the ItemList table with the given index
        my $id = $$et{KeysCount} . '.' . $index;
        if (ref $$itemList{$id} eq 'HASH') {
            # delete other languages too if they exist
            my $oldInfo = $$itemList{$id};
            if ($$oldInfo{OtherLang}) {
                delete $$itemList{$_} foreach @{$$oldInfo{OtherLang}};
            }
            delete $$itemList{$id};
        }
        if ($newInfo) {
            $$newInfo{KeysID} = $tag;  # save original ID for use in family 7 group name
            AddTagToTable($itemList, $id, $newInfo);
            $msg or $msg = '';
            $out and print $out "$$et{INDENT}Added ItemList Tag $id = ($ns) $full$msg\n";
        }
        $pos += $len;
        ++$index;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process keys in MetaSampleDesc directory
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessMetaKeys($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    # save this information to decode timed metadata samples when ExtractEmbedded is used
    SaveMetaKeys($et, $dirInfo, $tagTablePtr) if $$et{OPTIONS}{ExtractEmbedded};
    return 1;
}

#------------------------------------------------------------------------------
# Identify trailers at specified offset from end of file
# Inputs: 0) RAF reference, 1) Offset from end of file
# Returns: Array ref to first trailer in linked list: 0) name of trailer,
#          1) absolute offset to start of this trailer, 2) trailer length,
#          3) ref to next trailer. Or undef if no trailer found, or error string on error
# - file position is returned to its original location
sub IdentifyTrailers($)
{
    my $raf = shift;
    my ($trailer, $nextTrail, $buff, $type, $len);
    my $pos = $raf->Tell();
    my $offset = 0; # positive offset back from end of file
    while ($raf->Seek(-40-$offset, 2) and $raf->Read($buff, 40) == 40) {
        if (substr($buff, 8) eq '8db42d694ccc418790edff439fe026bf') {
            ($type, $len) = ('Insta360', unpack('V',$buff));
        } elsif ($buff =~ /\&\&\&\&(.{4})$/) {
            ($type, $len) = ('LigoGPS', Get32u(\$buff, 36));
        } elsif ($buff =~ /~\0\x04\0zmie~\0\0\x06.{4}([\x10\x18])(\x04)$/s or
                 $buff =~ /~\0\x04\0zmie~\0\0\x0a.{8}([\x10\x18])(\x08)$/s)
        {
            my $oldOrder = GetByteOrder();
            SetByteOrder($1 eq "\x10" ? 'MM' : 'II');
            $type = 'MIE';
            $len = ($2 eq "\x04") ? Get32u(\$buff, 34) : Get64u(\$buff, 30);
            SetByteOrder($oldOrder);
        } else {
            last;
        }
        $trailer = [ $type , $raf->Tell() - $len, $len, $nextTrail ];
        $nextTrail = $trailer;
        $offset += $len;
    }
    $raf->Seek($pos,0) or return 'Seek error';
    return $trailer;
}

#------------------------------------------------------------------------------
# Process a QuickTime atom
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) optional tag table ref
# Returns: 1 on success
sub ProcessMOV($$;$)
{
    local $_;
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $dataPt = $$dirInfo{DataPt};
    my $verbose = $et->Options('Verbose');
    my $validate = $$et{OPTIONS}{Validate};
    my $dirBase = $$dirInfo{Base} || 0;
    my $dataPos = $dirBase;
    my $dirID = $$dirInfo{DirID} || '';
    my $charsetQuickTime = $et->Options('CharsetQuickTime');
    my ($buff, $tag, $size, $track, $isUserData, %triplet, $doDefaultLang, $index);
    my ($dirEnd, $unkOpt, %saveOptions, $atomCount, $warnStr, $trailer);

    my $topLevel = not $$et{InQuickTime};
    $$et{InQuickTime} = 1;
    $$et{HandlerType} = $$et{MetaFormat} = $$et{MediaType} = '' if $topLevel;

    unless (defined $$et{KeysCount}) {
        $$et{KeysCount} = 0;    # initialize ItemList key directory count
        $doDefaultLang = 1;     # flag to generate default language tags
    }
    # more convenient to package data as a RandomAccess file
    unless ($raf) {
        $raf = File::RandomAccess->new($dataPt);
        $dirEnd = $dataPos + $$dirInfo{DirLen} + ($$dirInfo{DirStart} || 0) if $$dirInfo{DirLen};
    }
    # skip leading bytes if necessary
    if ($$dirInfo{DirStart}) {
        $raf->Seek($$dirInfo{DirStart}, 1) or return 0;
        $dataPos += $$dirInfo{DirStart};
    }
    # read size/tag name atom header
    $raf->Read($buff,8) == 8 or return 0;
    $dataPos += 8;
    if ($tagTablePtr) {
        $isUserData = ($tagTablePtr eq \%Image::ExifTool::QuickTime::UserData);
    } else {
        $tagTablePtr = GetTagTable('Image::ExifTool::QuickTime::Main');
    }
    ($size, $tag) = unpack('Na4', $buff);
    my $fast = $$et{OPTIONS}{FastScan} || 0;
    # check for Insta360, LIGOGPSINFO or MIE trailer
    if ($topLevel and not $fast) {
        $trailer = IdentifyTrailers($raf);
        $trailer and not ref $trailer and $et->Warn($trailer), return 0;
    }
    if ($dataPt) {
        $verbose and $et->VerboseDir($$dirInfo{DirName});
    } else {
        # check on file type if called with a RAF
        $$tagTablePtr{$tag} or return 0;
        my $fileType;
        if ($tag eq 'ftyp' and $size >= 12) {
            # read ftyp atom to see what type of file this is
            if ($raf->Read($buff, $size-8) == $size-8) {
                $raf->Seek(-($size-8), 1) or $et->Warn('Seek error'), return 0;
                my $type = substr($buff, 0, 4);
                $$et{save_ftyp} = $type;
                # see if we know the extension for this file type
                if ($ftypLookup{$type} and $ftypLookup{$type} =~ /\(\.(\w+)/) {
                    $fileType = $1;
                # check compatible brands
                } elsif ($buff =~ /^.{8}(.{4})+(mp41|mp42|avc1)/s) {
                    $fileType = 'MP4';
                } elsif ($buff =~ /^.{8}(.{4})+(f4v )/s) {
                    $fileType = 'F4V';
                } elsif ($buff =~ /^.{8}(.{4})+(qt  )/s) {
                    $fileType = 'MOV';
                }
            }
            $fileType or $fileType = 'MP4'; # default to MP4
            # set file type from extension if appropriate
            my $ext = $$et{FILE_EXT};
            $fileType = $ext if $ext and $useExt{$ext} and $fileType eq $useExt{$ext};
            $et->SetFileType($fileType, $mimeLookup{$fileType} || 'video/mp4');
            # temporarily set ExtractEmbedded option for CRX files
            $saveOptions{ExtractEmbedded} = $et->Options(ExtractEmbedded => 1) if $fileType eq 'CRX';
        } else {
            $et->SetFileType();     # MOV
        }
        SetByteOrder('MM');
        # have XMP take priority except for HEIC
        $$et{PRIORITY_DIR} = 'XMP' unless $fileType and $fileType eq 'HEIC';
    }
    $$raf{NoBuffer} = 1 if $fast;   # disable buffering in FastScan mode

    my $ee = $$et{OPTIONS}{ExtractEmbedded};
    my $hash = $$et{ImageDataHash};
    if ($ee or $hash) {
        $unkOpt = $$et{OPTIONS}{Unknown};
        require 'Image/ExifTool/QuickTimeStream.pl';
    }
    if ($$tagTablePtr{VARS}) {
        $index = $$tagTablePtr{VARS}{START_INDEX};
        $atomCount = $$tagTablePtr{VARS}{ATOM_COUNT};
    }
    my $lastTag = '';
    my $lastPos = 0;
    for (;;) {
        my ($eeTag, $ignore);
        last if defined $atomCount and --$atomCount < 0;
        if ($size < 8) {
            if ($size == 0) {
                if ($dataPt) {
                    # a zero size isn't legal for contained atoms, but Canon uses it to
                    # terminate the CNTH atom (eg. CanonEOS100D.mov), so tolerate it here
                    my $pos = $raf->Tell() - 4;
                    $raf->Seek(0,2) or $et->Warn('Seek error'), return 0;
                    my $str = $$dirInfo{DirName} . ' with ' . ($raf->Tell() - $pos) . ' bytes';
                    $et->VPrint(0,"$$et{INDENT}\[Terminator found in $str remaining]");
                } else {
                    my $t = PrintableTagID($tag,2);
                    $et->VPrint(0,"$$et{INDENT}Tag '${t}' extends to end of file");
                    if ($$tagTablePtr{"$tag-size"}) {
                        my $pos = $raf->Tell();
                        unless ($fast) {
                            $raf->Seek(0, 2) or $et->Warn('Seek error'), return 0;
                            $et->HandleTag($tagTablePtr, "$tag-size", $raf->Tell() - $pos);
                        }
                        $et->HandleTag($tagTablePtr, "$tag-offset", $pos) if $$tagTablePtr{"$tag-offset"};
                    }
                }
                last;
            }
            $size == 1 or $warnStr = 'Invalid atom size', last;
            # read extended atom size
            $raf->Read($buff, 8) == 8 or $warnStr = 'Truncated atom header', last;
            $dataPos += 8;
            my ($hi, $lo) = unpack('NN', $buff);
            if ($hi or $lo > 0x7fffffff) {
                if ($hi > 0x7fffffff) {
                    $warnStr = 'Invalid atom size';
                    last;
                } elsif (not $et->Options('LargeFileSupport')) {
                    $warnStr = 'End of processing at large atom (LargeFileSupport not enabled)';
                    last;
                } elsif ($et->Options('LargeFileSupport') eq '2') {
                    $et->Warn('Processing large atom (LargeFileSupport is 2)');
                }
            }
            $size = $hi * 4294967296 + $lo - 16;
            $size < 0 and $warnStr = 'Invalid extended size', last;
        } else {
            $size -= 8;
        }
        if ($validate) {
            $et->Warn("Invalid 'wide' atom size") if $tag eq 'wide' and $size;
            $$et{ValidatePath} or $$et{ValidatePath} = { };
            my $path = join('-', @{$$et{PATH}}, $tag);
            $path =~ s/-Track-/-$$et{SET_GROUP1}-/ if $$et{SET_GROUP1};
            if ($$et{ValidatePath}{$path} and not $dupTagOK{$tag} and not $dupDirOK{$dirID}) {
                my $i = Get32u(\$tag,0);
                my $str = $i < 255 ? "index $i" : "tag '" . PrintableTagID($tag,2) . "'";
                $et->Warn("Duplicate $str at " . join('-', @{$$et{PATH}}));
                $$et{ValidatePath} = { } if $path eq 'MOV-moov'; # avoid warnings for all contained dups
            }
            $$et{ValidatePath}{$path} = 1;
        }
        if ($isUserData and $$et{SET_GROUP1}) {
            my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
            unless ($$tagInfo{SubDirectory}) {
                # add track name to UserData tags inside tracks
                $tag = $$et{SET_GROUP1} . $tag;
                if (not $$tagTablePtr{$tag} and $tagInfo) {
                    my %newInfo = %$tagInfo;
                    foreach ('Name', 'Description') {
                        next unless $$tagInfo{$_};
                        $newInfo{$_} = $$et{SET_GROUP1} . $$tagInfo{$_};
                        $newInfo{$_} =~ s/^(Track\d+)Track/$1/; # remove duplicate "Track" in name
                    }
                    AddTagToTable($tagTablePtr, $tag, \%newInfo);
                }
            }
        }
        # set flag to store additional information for ExtractEmbedded option
        my $handlerType = $$et{HandlerType};
        if ($eeBox{$handlerType} and $eeBox{$handlerType}{$tag}) {
            if ($ee or $hash) {
                # (there is another 'gps ' box with a track log that doesn't contain offsets)
                if ($tag ne 'gps ' or $eeBox{$handlerType}{$tag} eq $dirID) {
                    $eeTag = 1;
                    $$et{OPTIONS}{Unknown} = 1; # temporarily enable "Unknown" option
                }
            } elsif ($handlerType ne 'vide' and not $$et{OPTIONS}{Validate}) {
                EEWarn($et);
            }
        } elsif ($ee and $ee > 1 and $eeBox2{$handlerType} and $eeBox2{$handlerType}{$tag}) {
            $eeTag = 1;
            $$et{OPTIONS}{Unknown} = 1;
        } elsif ($hash and $hashBox{$handlerType} and $hashBox{$handlerType}{$tag}) {
            $eeTag = 1;
            $$et{OPTIONS}{Unknown} = 1;
        }
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);

        $$et{OPTIONS}{Unknown} = $unkOpt if $eeTag;     # restore Unknown option

        # allow numerical tag ID's
        unless ($tagInfo) {
            my $id = $$et{KeysCount} . '.' . unpack('N', $tag);
            if ($$tagTablePtr{$id}) {
                $tagInfo = $et->GetTagInfo($tagTablePtr, $id);
                $tag = $id;
            }
        }
        # generate tagInfo if Unknown option set
        if (not defined $tagInfo and ($$et{OPTIONS}{Unknown} or
            $verbose or $tag =~ /^\xa9/))
        {
            my $name = PrintableTagID($tag,1);
            if ($name =~ /^xa9(.*)/) {
                $tagInfo = {
                    Name => "UserData_$1",
                    Description => "User Data $1",
                };
            } else {
                $tagInfo = {
                    Name => "Unknown_$name",
                    Description => "Unknown $name",
                    %unknownInfo,
                };
            }
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        # save required tag sizes
        if ($$tagTablePtr{"$tag-size"}) {
            $et->HandleTag($tagTablePtr, "$tag-size", $size);
            $et->HandleTag($tagTablePtr, "$tag-offset", $raf->Tell()+$dirBase) if $$tagTablePtr{"$tag-offset"};
        }
        # save position/size of 'idat'
        $$et{MediaDataInfo} = [ $raf->Tell() + $dirBase, $size ] if $tag eq 'idat';
        # stop processing at mdat/idat if -fast2 is used
        last if $fast > 1 and ($tag eq 'mdat' or ($tag eq 'idat' and $$et{FileType} ne 'HEIC'));
        # load values only if associated with a tag (or verbose) and not too big
        if ($size > 0x2000000) {    # start to get worried above 32 MiB
            # check for RIFF trailer (written by Auto-Vox dashcam)
            if ($buff =~ /^(gpsa|gps0|gsen|gsea)...\0/s) { # (yet seen only gpsa as first record)
                $et->VPrint(0, sprintf("Found RIFF trailer at offset 0x%x",$lastPos));
                if ($ee) {
                    $raf->Seek(-8, 1) or last;  # seek back to start of trailer
                    my $tbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
                    ProcessRIFFTrailer($et, { RAF => $raf }, $tbl);
                } else {
                    EEWarn($et);
                }
                last;
            } elsif ($buff eq 'CCCCCCCC') {
                $et->VPrint(0, sprintf("Found Kenwood trailer at offset 0x%x",$lastPos));
                my $tbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
                ProcessKenwoodTrailer($et, { RAF => $raf }, $tbl);
                last;
            }
            $ignore = 1;
            if ($tagInfo and not $$tagInfo{Unknown} and not $eeTag) {
                my $t = PrintableTagID($tag,2);
                if ($size > 0x8000000) {
                    $et->Warn("Skipping '${t}' atom > 128 MiB", 1);
                } else {
                    $et->Warn("Skipping '${t}' atom > 32 MiB", 2) or $ignore = 0;
                }
            }
        }
        if (defined $tagInfo and not $ignore) {
            # set document number for this item property if necessary
            if ($$et{IsItemProperty}) {
                my $items = $$et{ItemInfo};
                my ($id, $prop, $docNum, $lowest);
                my $primary = $$et{PrimaryItem} || 0;
ItemID:         foreach $id (reverse sort { $a <=> $b } keys %$items) {
                    next unless $$items{$id}{Association};
                    my $item = $$items{$id};
                    foreach $prop (@{$$item{Association}}) {
                        next unless $prop == $index;
                        if ($id == $primary or (not $dontInherit{$tag} and
                            (($$item{RefersTo} and $$item{RefersTo}{$primary}) or
                            # hack: assume Item 1 is from the main image (eg. hvc1 data)
                            # to hack the case where the primary item (ie. main image)
                            # doesn't directly reference this property
                            (not $$item{RefersTo} and $id == 1))))
                        {
                            # this is associated with the primary item or an item describing
                            # the primary item, so consider this part of the main document
                            undef $docNum;
                            undef $lowest;
                            last ItemID;
                        } elsif ($$item{DocNum}) {
                            # this property is already associated with an item that has
                            # an ExifTool document number, so use the lowest associated DocNum
                            $docNum = $$item{DocNum} if not defined $docNum or $docNum > $$item{DocNum};
                        } else {
                            # keep track of the lowest associated item ID
                            $lowest = $id;
                        }
                    }
                }
                if (not defined $docNum and defined $lowest) {
                    # this is the first time we've seen metadata from this item,
                    # so use a new document number
                    $docNum = ++$$et{DOC_COUNT};
                    $$items{$lowest}{DocNum} = $docNum;
                }
                $$et{DOC_NUM} = $docNum;
            }
            my $val;
            my $missing = $size - $raf->Read($val, $size);
            if ($missing) {
                my $t = PrintableTagID($tag,2);
                $warnStr = "Truncated '${t}' data (missing $missing bytes)";
                last;
            }
            # use value to get tag info if necessary
            $tagInfo or $tagInfo = $et->GetTagInfo($tagTablePtr, $tag, \$val);
            my $hasData = ($$dirInfo{HasData} and $val =~ /^....data\0/s);
            if ($verbose and not $hasData) {
                my $tval;
                if ($tagInfo and $$tagInfo{Format}) {
                    $tval = ReadValue(\$val, 0, $$tagInfo{Format}, $$tagInfo{Count}, length($val));
                }
                $et->VerboseInfo($tag, $tagInfo,
                    Value   => $tval,
                    DataPt  => \$val,
                    DataPos => $dataPos,
                    Size    => $size,
                    Format  => $tagInfo ? $$tagInfo{Format} : undef,
                    Index   => $index,
                );
                # print iref item ID numbers
                if ($dirID eq 'iref') {
                    my ($id, $count, @to, $i);
                    if ($$et{ItemRefVersion}) {
                        ($id, $count, @to) = unpack('NnN*', $val) if length $val >= 10;
                    } else {
                        ($id, $count, @to) = unpack('nnn*', $val) if length $val >= 6;
                    }
                    defined $id or $id = '<err>', $count = 0;
                    $id .= " (wrong count: $count)" if $count != @to;
                    # convert sequential numbers to a range
                    for ($i=1; $i<@to; ) {
                        $to[$i-1] =~ /(\d+)$/ and $to[$i] == $1 + 1 or ++$i, next;
                        $to[$i-1] =~ s/(-.*)?$/-$to[$i]/;
                        splice @to, $i, 1;
                    }
                    $et->VPrint(1, "$$et{INDENT}  Item $id refers to: ",join(',',@to),"\n");
                }
            }
            # extract metadata from stream if ExtractEmbedded option is enabled
            if ($eeTag) {
                ParseTag($et, $tag, \$val);
                # forget this tag if we generated it only for ExtractEmbedded
                undef $tagInfo if $tagInfo and $$tagInfo{Unknown} and not $unkOpt;
            }

            # handle iTunesInfo mean/name/data triplets
            if ($tagInfo and $$tagInfo{Triplet}) {
                if ($tag eq 'data' and $triplet{mean} and $triplet{name}) {
                    $tag = $triplet{name};
                    # add 'mean' to name unless it is 'com.apple.iTunes'
                    $tag = $triplet{mean} . '/' . $tag unless $triplet{mean} eq 'com.apple.iTunes';
                    $tagInfo = $et->GetTagInfo($tagTablePtr, $tag, \$val);
                    unless ($tagInfo) {
                        my $name = $triplet{name};
                        my $desc = $name;
                        $name =~ tr/-_a-zA-Z0-9//dc;
                        $desc =~ tr/_/ /;
                        $tagInfo = {
                            Name => $name,
                            Description => $desc,
                        };
                        $et->VPrint(0, $$et{INDENT}, "[adding QuickTime:$name]\n");
                        AddTagToTable($tagTablePtr, $tag, $tagInfo);
                    }
                    # ignore 8-byte header
                    $val = substr($val, 8) if length($val) >= 8;
                    unless ($$tagInfo{Format} or $$tagInfo{SubDirectory}) {
                        # extract as binary if it contains any non-ASCII or control characters
                        if ($val =~ /[^\x20-\x7e]/) {
                            my $buff = $val;
                            $val = \$buff;
                        }
                    }
                    $$tagInfo{List} = 1; # (allow any of these tags to have multiple data elements)
                    $et->VerboseInfo($tag, $tagInfo, Value => $val) if $verbose;
                } else {
                    $triplet{$tag} = substr($val,4) if length($val) > 4;
                    undef $tagInfo;  # don't store this tag
                }
            }
            if ($tagInfo) {
                my @found;
                my $subdir = $$tagInfo{SubDirectory};
                if ($subdir) {
                    my $start = $$subdir{Start} || 0;
                    my ($base, $dPos) = ($dataPos, 0);
                    if ($$subdir{Base}) {
                        $dPos -= eval $$subdir{Base};
                        $base -= $dPos;
                    }
                    my %dirInfo = (
                        DataPt     => \$val,
                        DataLen    => $size,
                        DirStart   => $start,
                        DirLen     => $size - $start,
                        DirName    => $$subdir{DirName} || $$tagInfo{Name},
                        DirID      => $tag,
                        HasData    => $$subdir{HasData},
                        Multi      => $$subdir{Multi},
                        IgnoreProp => $$subdir{IgnoreProp}, # (XML hack)
                        DataPos    => $dPos,
                        Base       => $base, # (needed for IsOffset tags in binary data)
                    );
                    $dirInfo{BlockInfo} = $tagInfo if $$tagInfo{BlockExtract};
                    if ($$subdir{ByteOrder} and $$subdir{ByteOrder} =~ /^Little/) {
                        SetByteOrder('II');
                    }
                    my $oldGroup1 = $$et{SET_GROUP1};
                    if ($$tagInfo{SubDirectory} and $$tagInfo{SubDirectory}{TagTable} and
                        $$tagInfo{SubDirectory}{TagTable} eq 'Image::ExifTool::QuickTime::Track')
                    {
                        $track or $track = 0;
                        $$et{SET_GROUP1} = 'Track' . (++$track);
                    }
                    my $subTable = GetTagTable($$subdir{TagTable});
                    my $proc = $$subdir{ProcessProc};
                    # make ProcessMOV() the default processing procedure for subdirectories
                    $proc = \&ProcessMOV unless $proc or $$subTable{PROCESS_PROC};
                    if ($size > $start) {
                        # delay processing of ipco box until after all other boxes
                        if ($tag eq 'ipco' and not $$et{IsItemProperty}) {
                            $$et{ItemPropertyContainer} = [ \%dirInfo, $subTable, $proc ];
                            $et->VPrint(0,"$$et{INDENT}\[Process ipco box later]");
                        } else {
                            $et->ProcessDirectory(\%dirInfo, $subTable, $proc);
                        }
                    }
                    if ($tag eq 'stbl') {
                        # process sample data when exiting SampleTable box if extracting embedded
                        ProcessSamples($et) if $ee or $hash;
                    } elsif ($tag eq 'minf') {
                        $$et{HandlerType} = ''; # reset handler type at end of media info box
                    }
                    $$et{SET_GROUP1} = $oldGroup1;
                    SetByteOrder('MM');
                } elsif ($hasData) {
                    # handle atoms containing 'data' tags
                    # (currently ignore contained atoms: 'itif', 'name', etc.)
                    my $pos = 0;
                    for (;;) {
                        last if $pos + 16 > $size;
                        my ($len, $type, $flags, $ctry, $lang) = unpack("x${pos}Na4Nnn", $val);
                        last if $pos + $len > $size or not $len;
                        my ($value, $langInfo, $oldDir);
                        my $format = $$tagInfo{Format};
                        if ($type eq 'data' and $len >= 16) {
                            $pos += 16;
                            $len -= 16;
                            $value = substr($val, $pos, $len);
                            # format flags (ref 12):
                            # 0x0=binary, 0x1=UTF-8, 0x2=UTF-16, 0x3=ShiftJIS,
                            # 0x4=UTF-8  0x5=UTF-16, 0xd=JPEG, 0xe=PNG,
                            # 0x15=signed int, 0x16=unsigned int, 0x17=float,
                            # 0x18=double, 0x1b=BMP, 0x1c='meta' atom
                            if ($stringEncoding{$flags}) {
                                # handle all string formats
                                $value = $et->Decode($value, $stringEncoding{$flags});
                                # (shouldn't be null terminated, but some software writes it anyway)
                                $value =~ s/\0$// unless $$tagInfo{Binary};
                            } else {
                                if (not $format) {
                                    $format = QuickTimeFormat($flags, $len);
                                } elsif ($format =~ /^int\d+([us])$/) {
                                    # adjust integer to available length (but not int64)
                                    my $fmt = { 1=>'int8', 2=>'int16', 4=>'int32' }->{$len};
                                    $format = $fmt . $1 if defined $fmt;
                                }
                                if ($format) {
                                    $value = ReadValue(\$value, 0, $format, $$tagInfo{Count}, $len);
                                } elsif (not $$tagInfo{ValueConv}) {
                                    # make binary data a scalar reference unless a ValueConv exists
                                    my $buf = $value;
                                    $value = \$buf;
                                }
                            }
                        }
                        if ($ctry or $lang) {
                            my $langCode = GetLangCode($lang, $ctry);
                            if ($langCode) {
                                # get tagInfo for other language
                                $langInfo = GetLangInfoQT($et, $tagInfo, $langCode);
                                # save other language tag ID's so we can delete later if necessary
                                if ($langInfo) {
                                    $$tagInfo{OtherLang} or $$tagInfo{OtherLang} = [ ];
                                    push @{$$tagInfo{OtherLang}}, $$langInfo{TagID};
                                }
                            }
                        }
                        $langInfo or $langInfo = $tagInfo;
                        my $str = $qtFlags{$flags} ? " ($qtFlags{$flags})" : '';
                        $et->VerboseInfo($tag, $langInfo,
                            Value   => ref $value ? $$value : $value,
                            DataPt  => \$val,
                            DataPos => $dataPos,
                            Start   => $pos,
                            Size    => $len,
                            Format  => $format,
                            Index   => $index,
                            Extra   => sprintf(", Type='${type}', Flags=0x%x%s, Lang=0x%.4x",$flags,$str,$lang),
                        ) if $verbose;
                        if (defined $value) {
                            # use "Keys" in path instead of ItemList if this was defined by a Keys tag
                            # (the only reason for this is to have "Keys" in the family 5 group name)
                            # Note that the Keys group is specifically set by the ProcessKeys routine,
                            # even though this tag would be in the ItemList table
                            my $isKeys = $$tagInfo{Groups} && $$tagInfo{Groups}{1} && $$tagInfo{Groups}{1} eq 'Keys';
                            $isKeys and $oldDir = $$et{PATH}[-1], $$et{PATH}[-1] = 'Keys';
                            push @found, $et->FoundTag($langInfo, $value);
                            $$et{PATH}[-1] = $oldDir if $isKeys;
                        }
                        $pos += $len;
                    }
                } elsif ($tag =~ /^\xa9/ or $$tagInfo{IText}) {
                    # parse international text to extract all languages
                    my $pos = 0;
                    if ($$tagInfo{Format}) {
                        push @found, $et->FoundTag($tagInfo, ReadValue(\$val, 0, $$tagInfo{Format}, undef, length($val)));
                        $pos = $size;
                    }
                    for (;;) {
                        my ($len, $lang);
                        if ($$tagInfo{IText} and $$tagInfo{IText} >= 6) {
                            last if $pos + $$tagInfo{IText} > $size;
                            $pos += $$tagInfo{IText} - 2;
                            $lang = unpack("x${pos}n", $val);
                            $pos += 2;
                            $len = $size - $pos;
                        } else {
                            last if $pos + 4 > $size;
                            ($len, $lang) = unpack("x${pos}nn", $val);
                            $pos += 4;
                            # according to the QuickTime spec (ref 12), $len should include
                            # 4 bytes for length and type words, but nobody (including
                            # Apple, Pentax and Kodak) seems to add these in, so try
                            # to allow for either
                            if ($pos + $len > $size) {
                                $len -= 4;
                                last if $pos + $len > $size or $len < 0;
                            }
                        }
                        # ignore any empty entries (or null padding) after the first
                        next if not $len and $pos;
                        my $str = substr($val, $pos, $len);
                        my ($langInfo, $enc);
                        if (($lang < 0x400 or $lang == 0x7fff) and $str !~ /^\xfe\xff/) {
                            # this is a Macintosh language code
                            # a language code of 0 is Macintosh english, so treat as default
                            if ($lang) {
                                if ($lang == 0x7fff) {
                                    # technically, ISO 639-2 doesn't have a 2-character
                                    # equivalent for 'und', but use 'un' anyway
                                    $lang = 'un';
                                } else {
                                    # use Font.pm to look up language string
                                    require Image::ExifTool::Font;
                                    $lang = $Image::ExifTool::Font::ttLang{Macintosh}{$lang};
                                }
                            } else {
                                # for the default language code of 0x0000, use UTF-8 instead
                                # of the CharsetQuickTime setting if obviously UTF8
                                $enc = 'UTF8' if Image::ExifTool::IsUTF8(\$str) > 0;
                            }
                            # the spec says only "Macintosh text encoding", but
                            # allow this to be configured by the user
                            $enc = $charsetQuickTime unless $enc;
                        } else {
                            # convert language code to ASCII (ignore read-only bit)
                            $lang = UnpackLang($lang);
                            # may be either UTF-8 or UTF-16BE
                            $enc = $str=~s/^\xfe\xff// ? 'UTF16' : 'UTF8';
                        }
                        unless ($$tagInfo{NoDecode}) {
                            $str = $et->Decode($str, $enc);
                            $str =~ s/\0+$//;   # remove any trailing nulls (eg. 3gp tags)
                        }
                        if ($$tagInfo{IText} and $$tagInfo{IText} > 6) {
                            my $n = $$tagInfo{IText} - 6;
                            # add back extra bytes (eg. 'rtng' box)
                            $str = substr($val, $pos-$n-2, $n) . $str;
                        }
                        $langInfo = GetLangInfoQT($et, $tagInfo, $lang) if $lang;
                        push @found, $et->FoundTag($langInfo || $tagInfo, $str);
                        $pos += $len;
                    }
                } else {
                    my $format = $$tagInfo{Format};
                    if ($format) {
                        $val = ReadValue(\$val, 0, $format, $$tagInfo{Count}, length($val));
                    }
                    my $oldBase;
                    if ($$tagInfo{SetBase}) {
                        $oldBase = $$et{BASE};
                        $$et{BASE} = $dataPos;
                    }
                    my $key = $et->FoundTag($tagInfo, $val);
                    push @found, $key;
                    $$et{BASE} = $oldBase if defined $oldBase;
                    # decode if necessary (NOTE: must be done after RawConv)
                    if (defined $key and (not $format or $format =~ /^string/) and
                        not $$tagInfo{Unknown} and not $$tagInfo{ValueConv} and
                        not $$tagInfo{Binary} and defined $$et{VALUE}{$key} and not ref $val)
                    {
                        my $vp = \$$et{VALUE}{$key};
                        if (not ref $$vp and length($$vp) <= 65536 and $$vp =~ /[\x80-\xff]/) {
                            # the encoding of this is not specified, so use CharsetQuickTime
                            # unless the string is valid UTF-8
                            my $enc = Image::ExifTool::IsUTF8($vp) > 0 ? 'UTF8' : $charsetQuickTime;
                            $$vp = $et->Decode($$vp, $enc);
                        }
                    }
                }
                # tweak family 1 group names for Keys/ItemList/UserData tags in a track
                if ($$et{SET_GROUP1} and ($dirID eq 'ilst' or $dirID eq 'udta') and @found) {
                    my $type = $trackPath{join '-', @{$$et{PATH}}};
                    if ($type) {
                        my $grp = ($avType{$$et{MediaType}} || $$et{SET_GROUP1}) . $type;
                        defined and $et->SetGroup($_, $grp) foreach @found;
                    }
                }
            }
        } else {
            $et->VerboseInfo($tag, $tagInfo,
                Size  => $size,
                Extra => sprintf(' at offset 0x%.4x', $raf->Tell()),
            ) if $verbose;
            if ($size and (not $raf->Seek($size-1, 1) or $raf->Read($buff, 1) != 1)) {
                my $t = PrintableTagID($tag,2);
                $warnStr = sprintf("Truncated '${t}' data at offset 0x%x", $lastPos);
                last;
            }
        }
        $$et{MediaType} = '' if $tag eq 'trak';  # reset track type at end of track
        $dataPos += $size + 8;  # point to start of next atom data
        last if $dirEnd and $dataPos >= $dirEnd; # (note: ignores last value if 0 bytes)
        $lastPos = $raf->Tell() + $dirBase;
        if ($trailer and $lastPos >= $$trailer[1]) {
            $et->Warn(sprintf('%s trailer at offset 0x%x (%d bytes)', @$trailer[0..2]), 1);
            last;
        }
        $raf->Read($buff, 8) == 8 or last;
        $lastTag = $tag if $$tagTablePtr{$tag} and $tag ne 'free'; # (Insta360 sometimes puts free block before trailer)
        ($size, $tag) = unpack('Na4', $buff);
        ++$index if defined $index;
    }
    if ($warnStr) {
        # assume this is an unknown trailer if it comes immediately after
        # mdat or moov and has a tag name we don't recognize
        if (($lastTag eq 'mdat' or $lastTag eq 'moov') and
            (not $$tagTablePtr{$tag} or ref $$tagTablePtr{$tag} eq 'HASH' and $$tagTablePtr{$tag}{Unknown}))
        {
            $et->Warn('Unknown trailer with '.lcfirst($warnStr));
        } else {
            $et->Warn($warnStr);
        }
    }
    # tweak file type based on track content ("iso*" and "dash" ftyp only)
    if ($topLevel and $$et{FileType} and $$et{FileType} eq 'MP4' and
        $$et{save_ftyp} and $$et{HasHandler} and $$et{save_ftyp} =~ /^(iso|dash)/ and
        $$et{HasHandler}{soun} and not $$et{HasHandler}{vide})
    {
        $et->OverrideFileType('M4A', 'audio/mp4');
    }
    # fill in missing defaults for alternate language tags
    # (the first language is taken as the default)
    if ($doDefaultLang and $$et{QTLang}) {
QTLang: foreach $tag (@{$$et{QTLang}}) {
            next unless defined $$et{VALUE}{$tag};
            my $langInfo = $$et{TAG_INFO}{$tag} or next;
            my $tagInfo = $$langInfo{SrcTagInfo} or next;
            my $infoHash = $$et{TAG_INFO};
            my $name = $$tagInfo{Name};
            # loop through all instances of this tag name and generate the default-language
            # version only if we don't already have a QuickTime tag with this name
            my ($i, $key);
            for ($i=0, $key=$name; $$infoHash{$key}; ++$i, $key="$name ($i)") {
                next QTLang if $et->GetGroup($key, 0) eq 'QuickTime';
            }
            $key = $et->FoundTag($tagInfo, $$et{VALUE}{$tag});
            # copy extra tag information (groups, etc) to the synthetic tag
            $$et{TAG_EXTRA}{$key} = $$et{TAG_EXTRA}{$tag};
            $et->VPrint(0, "(synthesized default-language tag for QuickTime:$$tagInfo{Name})");
        }
        delete $$et{QTLang};
    }
    # process item information now that we are done processing its 'meta' container
    HandleItemInfo($et) if $topLevel or $dirID eq 'meta';

    # process linked list of trailers
    for (; $trailer; $trailer=$$trailer[3]) {
        next if $lastPos > $$trailer[1];    # skip if we have already processed this as an atom
        last unless $raf->Seek($$trailer[1], 0);
        if ($$trailer[0] eq 'LigoGPS' and $raf->Read($buff, 8) == 8 and $buff =~ /skip$/) {
            $ee or $et->Warn('Use the ExtractEmbedded option to decode timed GPS',3), next;
            my $len = Get32u(\$buff, 0) - 16;
            if ($len > 0 and $raf->Read($buff, $len) == $len and $buff =~ /^LIGOGPSINFO\0/) {
                my $tbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
                my %dirInfo = ( DataPt => \$buff, DataPos => $$trailer[1] + 8, DirName => 'LigoGPSTrailer' );
                Image::ExifTool::LigoGPS::ProcessLigoGPS($et, \%dirInfo, $tbl);
            } else {
                $et->Warn('Unrecognized data in LigoGPS trailer');
            }
        } elsif ($$trailer[0] eq 'Insta360' and $ee) {
            # process Insta360 trailer if it exists
            $raf->Seek(0, 2) or $et->Warn('Seek error'), last;
            my $offset = $raf->Tell() - $$trailer[1] - $$trailer[2];
            ProcessInsta360($et, { RAF => $raf, DirName => $$trailer[0], Offset => $offset });
        } elsif ($$trailer[0] eq 'MIE') {
            require Image::ExifTool::MIE;
            Image::ExifTool::MIE::ProcessMIE($et, { RAF => $raf, DirName => 'MIE', Trailer => 1 });
        }
    }
    # brute force scan for metadata embedded in media data
    # (and process Insta360 trailer if it exists)
    ScanMediaData($et) if $ee and $topLevel;

    # restore any changed options
    $et->Options($_ => $saveOptions{$_}) foreach keys %saveOptions;
    return 1;
}

#------------------------------------------------------------------------------
# Process a QuickTime Image File
# Inputs: 0) ExifTool object reference, 1) directory information reference
# Returns: 1 on success
sub ProcessQTIF($$)
{
    my ($et, $dirInfo) = @_;
    my $table = GetTagTable('Image::ExifTool::QuickTime::ImageFile');
    return ProcessMOV($et, $dirInfo, $table);
}

#==============================================================================
# Autoload LigoGPS module if necessary
# NOTE: Switches to package LigoGPS!
#
package Image::ExifTool::LigoGPS;
use vars qw($AUTOLOAD);
sub AUTOLOAD {
    require Image::ExifTool::LigoGPS;
    unless (defined &$AUTOLOAD) {
        my @caller = caller(0);
        # reproduce Perl's standard 'undefined subroutine' message:
        die "Undefined subroutine $AUTOLOAD called at $caller[1] line $caller[2]\n";
    }
    no strict 'refs';
    return &$AUTOLOAD(@_);  # call the function
}
#==============================================================================

1;  # end

__END__

=head1 NAME

Image::ExifTool::QuickTime - Read QuickTime and MP4 meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
information from QuickTime and MP4 video, M4A audio, and HEIC image files.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://developer.apple.com/mac/library/documentation/QuickTime/QTFF/QTFFChap1/qtff1.html>

=item L<http://search.cpan.org/dist/MP4-Info-1.04/>

=item L<http://www.geocities.com/xhelmboyx/quicktime/formats/mp4-layout.txt>

=item L<http://wiki.multimedia.cx/index.php?title=Apple_QuickTime>

=item L<http://atomicparsley.sourceforge.net/mpeg-4files.html>

=item L<http://wiki.multimedia.cx/index.php?title=QuickTime_container>

=item L<http://code.google.com/p/mp4v2/wiki/iTunesMetadata>

=item L<http://www.canieti.com.mx/assets/files/1011/IEC_100_1384_DC.pdf>

=item L<http://www.adobe.com/devnet/flv/pdf/video_file_format_spec_v10.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/QuickTime Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

