#------------------------------------------------------------------------------
# File:         QuickTime.pm
#
# Description:  Read QuickTime, MP4 and M4A meta information
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
#------------------------------------------------------------------------------

package Image::ExifTool::QuickTime;

use strict;
use vars qw($VERSION $AUTOLOAD);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::GPS;

$VERSION = '1.96';

sub FixWrongFormat($);
sub ProcessMOV($$;$);
sub ProcessKeys($$$);
sub ProcessMetaData($$$);
sub ProcessEncodingParams($$$);
sub ProcessHybrid($$$);
sub ProcessRights($$$);
sub ConvertISO6709($);
sub ConvertChapterList($);
sub PrintChapter($);
sub PrintGPSCoordinates($);
sub UnpackLang($);
sub WriteQuickTime($$$);
sub WriteMOV($$);

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
    'iso2' => 'MP4 Base Media v2 [ISO 14496-12:2005]', # video/mp4
    'isom' => 'MP4  Base Media v1 [IS0 14496-12:2003]', # video/mp4
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
);

# information for time/date-based tags (time zero is Jan 1, 1904)
my %timeInfo = (
    Notes => 'converted from UTC to local time if the QuickTimeUTC option is set',
    # It is not uncommon for brain-dead software to use the wrong time zero,
    # so assume a time zero of Jan 1, 1970 if the date is before this
    RawConv => q{
        my $offset = (66 * 365 + 17) * 24 * 3600;
        return $val - $offset if $val >= $offset or $$self{OPTIONS}{QuickTimeUTC};
        $self->WarnOnce('Patched incorrect time zero for QuickTime date/time tag',1) if $val;
        return $val;
    },
    Shift => 'Time',
    Writable => 1,
    Permanent => 1,
    DelValue => 0,
    # Note: This value will be in UTC if generated by a system that is aware of the time zone
    ValueConv => 'ConvertUnixTime($val, $self->Options("QuickTimeUTC"))',
    ValueConvInv => 'GetUnixTime($val, $self->Options("QuickTimeUTC")) + (66 * 365 + 17) * 24 * 3600',
    PrintConv => '$self->ConvertDateTime($val)',
    PrintConvInv => '$self->InverseDateTime($val)',
    # (can't put Groups here because they aren't constant!)
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
# parsing for most of the 3gp udta language text boxes
my %langText = (
    RawConv => sub {
        my ($val, $self) = @_;
        return '<err>' unless length $val >= 6;
        my $lang = UnpackLang(Get16u(\$val, 4));
        $lang = $lang ? "($lang) " : '';
        $val = substr($val, 6); # isolate string
        $val = $self->Decode($val, 'UCS2') if $val =~ /^\xfe\xff/;
        return $lang . $val;
    },
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
my %stringEncoding = (
    1 => 'UTF8',
    2 => 'UTF16',
    3 => 'ShiftJIS',
    4 => 'UTF8',
    5 => 'UTF16',
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

# QuickTime atoms
%Image::ExifTool::QuickTime::Main = (
    PROCESS_PROC => \&ProcessMOV,
    WRITE_PROC => \&WriteQuickTime,
    GROUPS => { 2 => 'Video' },
    NOTES => q{
        The QuickTime format is used for many different types of audio, video and
        image files (most commonly, MOV and MP4 videos).  Exiftool extracts standard
        meta information a variety of audio, video and image parameters, as well as
        proprietary information written by many camera models.  Tags with a question
        mark after their name are not extracted unless the Unknown option is set.

        ExifTool has the ability to write/create XMP, and edit some date/time tags
        in QuickTime-format files.

        According to the specification, many QuickTime date/time tags should be
        stored as UTC.  Unfortunately, digital cameras often store local time values
        instead (presumably because they don't know the time zone).  For this
        reason, by default ExifTool does not assume a time zone for these values.
        However, if the QuickTimeUTC API option is set, then ExifTool will assume
        these values are properly stored as UTC, and will convert them to local time
        when extracting.

        See
        L<http://developer.apple.com/mac/library/documentation/QuickTime/QTFF/QTFFChap1/qtff1.html>
        for the official specification.
    },
    meta => { # 'meta' is found here in my Sony ILCE-7S MP4 sample - PH
        Name => 'Meta',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Meta',
            Start => 4, # skip 4-byte version number header
        },
    },
    free => [
        {
            Name => 'KodakFree',
            # (found in Kodak M5370 MP4 videos)
            Condition => '$$valPt =~ /^\0\0\0.Seri/s',
            SubDirectory => { TagTable => 'Image::ExifTool::Kodak::Free' },
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
        { Name => 'Skip', Unknown => 1, Binary => 1 },
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
    moov => {
        Name => 'Movie',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Movie' },
    },
    mdat => { Name => 'MovieData', Unknown => 1, Binary => 1 },
    'mdat-size' => {
        Name => 'MovieDataSize',
        Notes => q{
            not a real tag ID, this tag represents the size of the 'mdat' data in bytes
            and is used in the AvgBitrate calculation
        },
    },
    'mdat-offset' => 'MovieDataOffset',
    junk => { Unknown => 1, Binary => 1 }, #8
    uuid => [
        { #9 (MP4 files)
            Name => 'XMP',
            # *** this is where ExifTool writes XMP in MP4 videos (as per XMP spec) ***
            Condition => '$$valPt=~/^\xbe\x7a\xcf\xcb\x97\xa9\x42\xe8\x9c\x71\x99\x94\x91\xe3\xaf\xac/',
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
        { #8
            Name => 'UUID-Unknown',
            %unknownInfo,
        },
    ],
    _htc => {
        Name => 'HTCInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::HTCInfo' },
    },
    udta => {
        Name => 'UserData',
        SubDirectory => { TagTable => 'Image::ExifTool::FLIR::UserData' },
    },
    thum => { #PH
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
    # meta - proprietary XML information written by some Flip cameras - PH
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
        ValueConv => 'join(" ", substr($val,0,4), unpack("x4n*",$val))',
    },
    pasp => {
        Name => 'PixelAspectRatio',
        ValueConv => 'join(":", unpack("N*",$val))',
    },
    clap => {
        Name => 'CleanAperture',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::CleanAperture' },
    },
    # avcC - AVC configuration (ref http://thompsonng.blogspot.ca/2010/11/mp4-file-format-part-2.html)
    # hvcC - HEVC configuration
    # svcC - 7 bytes: 00 00 00 00 ff e0 00
    # esds - elementary stream descriptor
    # d263
    gama => { Name => 'Gamma', Format => 'fixed32u' },
    # mjqt - default quantization table for MJPEG
    # mjht - default Huffman table for MJPEG
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
    FORMAT => 'rational64u',
    0 => 'CleanApertureWidth',
    1 => 'CleanApertureHeight',
    2 => 'CleanApertureOffsetX',
    3 => 'CleanApertureOffsetY',
);

# preview data block
%Image::ExifTool::QuickTime::Preview = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
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
    # prfl - Profile (ref 12)
    # clip - clipping --> contains crgn (clip region) (ref 12)
    # mvex - movie extends --> contains mehd (movie extends header), trex (track extends) (ref 14)
    # ICAT - 4 bytes: "6350" (Nikon CoolPix S6900)
);

# movie header data block
%Image::ExifTool::QuickTime::MovieHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
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
        {
            Name => 'UUID-Unknown',
            %unknownInfo,
        },
    ],
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
    GROUPS => { 1 => 'Track#', 2 => 'Video' },
    FORMAT => 'int32u',
    DATAMEMBER => [ 0, 1, 2, 5 ],
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
        # (the right column is fixed 2.30 instead of 16.16)
        ValueConv => q{
            my @a = split ' ',$val;
            $_ /= 0x4000 foreach @a[2,5,8];
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
    GROUPS => { 2 => 'Video' },
    NOTES => q{
        Tag ID's beginning with the copyright symbol (hex 0xa9) are multi-language
        text.  Alternate language tags are accessed by adding a dash followed by the
        language/country code to the tag name.  ExifTool will extract any
        multi-language user data tags found, even if they don't exist in this table.
    },
    "\xa9cpy" => { Name => 'Copyright',  Groups => { 2 => 'Author' } },
    "\xa9day" => {
        Name => 'ContentCreateDate',
        Groups => { 2 => 'Time' },
        # handle values in the form "2010-02-12T13:27:14-0800" (written by Apple iPhone)
        ValueConv => q{
            require Image::ExifTool::XMP;
            $val =  Image::ExifTool::XMP::ConvertXMPDate($val);
            $val =~ s/([-+]\d{2})(\d{2})$/$1:$2/; # add colon to timezone if necessary
            return $val;
        },
        PrintConv => '$self->ConvertDateTime($val)',
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
    "\xa9dir" => 'Director', #12
    "\xa9req" => 'Requirements',
    "\xa9snk" => 'SubtitleKeywords', #12
    "\xa9snm" => 'Subtitle', #12
    "\xa9src" => 'SourceCredits', #12
    "\xa9swf" => 'SongWriter', #12
    "\xa9swk" => 'SongWriterKeywords', #12
    "\xa9swr" => 'SoftwareVersion', #12
    "\xa9too" => 'Encoder', #PH (NC)
    "\xa9trk" => 'Track', #PH (NC)
    "\xa9wrt" => 'Composer',
    "\xa9xyz" => { #PH (iPhone 3GS)
        Name => 'GPSCoordinates',
        Groups => { 2 => 'Location' },
        ValueConv => \&ConvertISO6709,
        PrintConv => \&PrintGPSCoordinates,
    },
    # \xa9 tags written by DJI Phantom 3: (ref PH)
    # \xa9xsp - +0.00
    # \xa9ysp - +0.00
    # \xa9zsp - +0.00,+0.40
    # \xa9fpt - -2.80,-0.80,-0.20,+0.20,+0.70,+6.50
    # \xa9fyw - -160.70,-83.60,-4.30,+87.20,+125.90,+158.80,
    # \xa9frl - +1.60,-0.30,+0.40,+0.60,+2.50,+7.20
    # \xa9gpt - -49.90,-17.50,+0.00
    # \xa9gyw - -160.60,-83.40,-3.80,+87.60,+126.20,+158.00 (similar values to fyw)
    # \xa9grl - +0.00
    # and the following entries don't have the proper 4-byte header for \xa9 tags:
    "\xa9dji" => { Name => 'UserData_dji', Format => 'undef', Binary => 1, Unknown => 1, Hidden => 1 },
    "\xa9res" => { Name => 'UserData_res', Format => 'undef', Binary => 1, Unknown => 1, Hidden => 1 },
    "\xa9uid" => { Name => 'UserData_uid', Format => 'undef', Binary => 1, Unknown => 1, Hidden => 1 },
    "\xa9mdl" => { Name => 'Model',        Format => 'string', Notes => 'non-standard-format DJI tag' },
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
        # *** this is where ExifTool writes XMP in MOV videos (as per XMP spec) ***
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
    # the following are 3gp tags, references:
    # http://atomicparsley.sourceforge.net
    # http://www.3gpp.org/ftp/tsg_sa/WG4_CODEC/TSGS4_25/Docs/
    cprt => { Name => 'Copyright',  %langText, Groups => { 2 => 'Author' } },
    auth => { Name => 'Author',     %langText, Groups => { 2 => 'Author' } },
    titl => { Name => 'Title',      %langText },
    dscp => { Name => 'Description',%langText },
    perf => { Name => 'Performer',  %langText },
    gnre => { Name => 'Genre',      %langText },
    albm => { Name => 'Album',      %langText },
    coll => { Name => 'CollectionName', %langText }, #17
    rtng => {
        Name => 'Rating',
        # (4-byte flags, 4-char entity, 4-char criteria, 2-byte lang, string)
        RawConv => q{
            return '<err>' unless length $val >= 14;
            my $str = 'Entity=' . substr($val,4,4) . ' Criteria=' . substr($val,8,4);
            $str =~ tr/\0-\x1f\x7f-\xff//d; # remove unprintable characters
            my $lang = Image::ExifTool::QuickTime::UnpackLang(Get16u(\$val, 12));
            $lang = $lang ? "($lang) " : '';
            $val = substr($val, 14);
            $val = $self->Decode($val, 'UCS2') if $val =~ /^\xfe\xff/;
            return $lang . $str . ' ' . $val;
        },
    },
    clsf => {
        Name => 'Classification',
        # (4-byte flags, 4-char entity, 2-byte index, 2-byte lang, string)
        RawConv => q{
            return '<err>' unless length $val >= 12;
            my $str = 'Entity=' . substr($val,4,4) . ' Index=' . Get16u(\$val,8);
            $str =~ tr/\0-\x1f\x7f-\xff//d; # remove unprintable characters
            my $lang = Image::ExifTool::QuickTime::UnpackLang(Get16u(\$val, 10));
            $lang = $lang ? "($lang) " : '';
            $val = substr($val, 12);
            $val = $self->Decode($val, 'UCS2') if $val =~ /^\xfe\xff/;
            return $lang . $str . ' ' . $val;
        },
    },
    kywd => {
        Name => 'Keywords',
        # (4 byte flags, 2-byte lang, 1-byte count, count x pascal strings)
        RawConv => q{
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
            my $sep = $self->Options('ListSep');
            return $lang . join($sep, @vals);
        },
    },
    loci => {
        Name => 'LocationInformation',
        Groups => { 2 => 'Location' },
        # (4-byte flags, 2-byte lang, location string, 1-byte role, 4-byte fixed longitude,
        #  4-byte fixed latitude, 4-byte fixed altitude, body string, notes string)
        RawConv => q{
            return '<err>' unless length $val >= 6;
            my $lang = Image::ExifTool::QuickTime::UnpackLang(Get16u(\$val, 4));
            $lang = $lang ? "($lang) " : '';
            $val = substr($val, 6);
            my $str;
            if ($val =~ /^\xfe\xff/) {
                $val =~ s/^(\xfe\xff(.{2})*?)\0\0//s or return '<err>';
                $str = $self->Decode($1, 'UCS2');
            } else {
                $val =~ s/^(.*?)\0//s or return '<err>';
                $str = $1;
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
                $str .= " Body=$1";
            }
            if ($val =~ s/^(\xfe\xff(.{2})*?)\0\0//s) {
                $str .= ' Notes=' . $self->Decode($1, 'UCS2');
            } elsif ($val =~ s/^(.*?)\0//s) {
                $str .= " Notes=$1";
            }
            return $lang . $str;
        },
    },
    yrrc => {
        Name => 'Year',
        Groups => { 2 => 'Time' },
        RawConv => 'length($val) >= 6 ? Get16u(\$val,4) : "<err>"',
    },
    urat => { #17
        Name => 'UserRating',
        RawConv => q{
            return '<err>' unless length $val >= 8;
            return Get8u(\$val, 7);
        },
    },
    # tsel - TrackSelection (ref 17)
    # Apple tags (ref 16)
    angl => { Name => 'CameraAngle',  Format => 'string' }, # (NC)
    clfn => { Name => 'ClipFileName', Format => 'string' }, # (NC)
    clid => { Name => 'ClipID',       Format => 'string' }, # (NC)
    cmid => { Name => 'CameraID',     Format => 'string' }, # (NC)
    cmnm => { # (NC)
        Name => 'Model',
        Description => 'Camera Model Name',
        Format => 'string', # (necessary to remove the trailing NULL)
    },
    date => { # (NC)
        Name => 'DateTimeOriginal',
        Groups => { 2 => 'Time' },
        ValueConv => q{
            require Image::ExifTool::XMP;
            $val =  Image::ExifTool::XMP::ConvertXMPDate($val);
            $val =~ s/([-+]\d{2})(\d{2})$/$1:$2/; # add colon to timezone if necessary
            return $val;
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    manu => { # (SX280)
        Name => 'Make',
        # (with Canon there are 6 unknown bytes before the model: "\0\0\0\0\x15\xc7")
        RawConv => '$val=~s/^\0{4}..//s; $val=~s/\0.*//; $val',
    },
    modl => { # (Samsung GT-S8530, Canon SX280)
        Name => 'Model',
        Description => 'Camera Model Name',
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
        IText => 1,
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
                $self->{VALUE}->{FileType} eq "MOV"
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
                $self->{VALUE}->{FileType} eq "MP4"
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
    # ---- GoPro ---- (ref PH)
    GoPr => 'GoProType', # (Hero3+)
    FIRM => 'FirmwareVersion', # (Hero4)
    LENS => 'LensSerialNumber', # (Hero4)
    CAME => { # (Hero4)
        Name => 'SerialNumberHash',
        Description => 'Camera Serial Number Hash',
        ValueConv => 'unpack("H*",$val)',
    },
    # SETT? 12 bytes (Hero4)
    # MUID? 32 bytes (Hero4, starts with serial number hash)
    # HMMT? 404 bytes (Hero4, all zero)
    # free (all zero)
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
    # AMBA => Ambarella AVC atom (unknown data written by Kodak Playsport video cam)
    # tmlp - 1 byte: 0 (PixPro SP360)
    # pivi - 72 bytes (PixPro SP360)
    # pive - 12 bytes (PixPro SP360)
    # m ev - 2 bytes: 0 0 (PixPro SP360)
    # m wb - 4 bytes: 0 0 0 0 (PixPro SP360)
    # mclr - 4 bytes: 0 0 0 0 (PixPro SP360)
    # mmtr - 4 bytes: 6 0 0 0 (PixPro SP360)
    # mflr - 4 bytes: 0 0 0 0 (PixPro SP360)
    # lvlm - 24 bytes (PixPro SP360)
    # ufdm - 4 bytes: 0 0 0 1 (PixPro SP360)
    # mtdt - 1 byte: 0 (PixPro SP360)
    # gdta - 75240 bytes (PixPro SP360)
    # ---- LG ----
    adzc => { Name => 'Unknown_adzc', Unknown => 1, Hidden => 1, %langText }, # "false\0/","true\0/"
    adze => { Name => 'Unknown_adze', Unknown => 1, Hidden => 1, %langText }, # "false\0/"
    adzm => { Name => 'Unknown_adzm', Unknown => 1, Hidden => 1, %langText }, # "\x0e\x04/","\x10\x06"
    # ---- Microsoft ----
    Xtra => { #PH (microsoft)
        Name => 'MicrosoftXtra',
        SubDirectory => { TagTable => 'Image::ExifTool::Microsoft::Xtra' },
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
            Condition => '$$valPt =~ /^.{8}\xff\xd8\xff\xdb/s',
            Groups => { 2 => 'Preview' },
            ValueConv => 'substr($val, 8)',
        },{ #17 (format is in bytes 3-7)
            Name => 'ThumbnailPNG',
            Condition => '$$valPt =~ /^.{8}\x89PNG\r\n\x1a\n/s',
            Groups => { 2 => 'Preview' },
            ValueConv => 'substr($val, 8)',
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
    # smrd - string "TRUEBLUE" (Samsung SM-C101)
    # ---- Unknown ----
    # CDET - 128 bytes (unknown origin)
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
    PROCESS_PROC => \&Image::ExifTool::QuickTime::ProcessMetaData,
    GROUPS => { 2 => 'Video' },
    TAG_PREFIX => 'MetaData',
    0x01 => 'Title',
    0x03 => {
        Name => 'ProductionDate',
        Groups => { 2 => 'Time' },
        # translate from format "YYYY/mm/dd HH:MM:SS"
        ValueConv => '$val=~tr{/}{:}; $val',
        PrintConv => '$self->ConvertDateTime($val)',
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
        RawConv => 'Get16s(\$val,0)',
        PrintConv => 'TimeZoneString($val)',
    },
    0x0c => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        # translate from format "YYYY/mm/dd HH:MM:SS"
        ValueConv => '$val=~tr{/}{:}; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
);

# compressed movie atoms (ref http://wiki.multimedia.cx/index.php?title=QuickTime_container#cmov)
%Image::ExifTool::QuickTime::CMovie = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Video' },
    dcom => 'Compression',
    # cmvd - compressed movie data
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
    GROUPS => { 2 => 'Video' },
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
        Name => 'DataInformation',
        Flags => ['Binary','Unknown'],
    },
    ipmc => {
        Name => 'IPMPControl',
        Flags => ['Binary','Unknown'],
    },
    iloc => {
        Name => 'ItemLocation',
        Flags => ['Binary','Unknown'],
    },
    ipro => {
        Name => 'ItemProtection',
        Flags => ['Binary','Unknown'],
    },
    iinf => {
        Name => 'ItemInformation',
        Flags => ['Binary','Unknown'],
    },
   'xml ' => {
        Name => 'XML',
        Flags => [ 'Binary', 'Protected', 'BlockExtract' ],
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::XML',
            IgnoreProp => { NonRealTimeMeta => 1 }, # ignore container for Sony 'nrtm'
        },
    },
   'keys' => {
        Name => 'Keys',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Keys' },
    },
    bxml => {
        Name => 'BinaryXML',
        Flags => ['Binary','Unknown'],
    },
    pitm => {
        Name => 'PrimaryItemReference',
        Flags => ['Binary','Unknown'],
    },
    free => { #PH
        Name => 'Free',
        Flags => ['Binary','Unknown'],
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
    GROUPS => { 2 => 'Audio' },
    NOTES => q{
        As well as these tags, the 'mdta' handler uses numerical tag ID's which are
        added dynamically to this table after processing the Meta Keys information.
    },
    # in this table, binary 1 and 2-byte "data"-type tags are interpreted as
    # int8u and int16u.  Multi-byte binary "data" tags are extracted as binary data
    "\xa9ART" => 'Artist',
    "\xa9alb" => 'Album',
    "\xa9cmt" => 'Comment',
    "\xa9com" => 'Composer',
    "\xa9day" => {
        Name => 'ContentCreateDate',
        Groups => { 2 => 'Time' },
        # handle values in the form "2010-02-12T13:27:14-0800"
        ValueConv => q{
            require Image::ExifTool::XMP;
            $val =  Image::ExifTool::XMP::ConvertXMPDate($val);
            $val =~ s/([-+]\d{2})(\d{2})$/$1:$2/; # add colon to timezone if necessary
            return $val;
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    "\xa9des" => 'Description', #4
    "\xa9enc" => 'EncodedBy', #10
    "\xa9gen" => 'Genre',
    "\xa9grp" => 'Grouping',
    "\xa9lyr" => 'Lyrics',
    "\xa9nam" => 'Title',
    # "\xa9st3" ? #10
    "\xa9too" => 'Encoder',
    "\xa9trk" => 'Track',
    "\xa9wrt" => 'Composer',
    '----' => {
        Name => 'iTunesInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::iTunesInfo' },
    },
    aART => { Name => 'AlbumArtist', Groups => { 2 => 'Author' } },
    covr => { Name => 'CoverArt',    Groups => { 2 => 'Preview' } },
    cpil => { #10
        Name => 'Compilation',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    disk => {
        Name => 'DiskNumber',
        Format => 'undef',  # (necessary to prevent decoding as string!)
        ValueConv => 'length($val) >= 6 ? join(" of ",unpack("x2nn",$val)) : \$val',
    },
    pgap => { #10
        Name => 'PlayGap',
        PrintConv => {
            0 => 'Insert Gap',
            1 => 'No Gap',
        },
    },
    tmpo => {
        Name => 'BeatsPerMinute',
        Format => 'int16u', # marked as boolean but really int16u in my sample
    },
    trkn => {
        Name => 'TrackNumber',
        Format => 'undef',  # (necessary to prevent decoding as string!)
        ValueConv => 'length($val) >= 6 ? join(" of ",unpack("x2nn",$val)) : \$val',
    },
#
# Note: it is possible that the tags below are not being decoded properly
# because I don't have samples to verify many of these - PH
#
    akID => { #10
        Name => 'AppleStoreAccountType',
        PrintConv => {
            0 => 'iTunes',
            1 => 'AOL',
        },
    },
    albm => 'Album', #(ffmpeg source)
    apID => 'AppleStoreAccount',
    atID => { #10 (or TV series)
        Name => 'AlbumTitleID',
        Format => 'int32u',
    },
    auth => { Name => 'Author', Groups => { 2 => 'Author' } },
    catg => 'Category', #7
    cnID => { #10
        Name => 'AppleStoreCatalogID',
        Format => 'int32u',
    },
    cprt => { Name => 'Copyright', Groups => { 2 => 'Author' } },
    dscp => 'Description',
    desc => 'Description', #7
    gnre => { #10
        Name => 'Genre',
        PrintConv => q{
            return $val unless $val =~ /^\d+$/;
            require Image::ExifTool::ID3;
            Image::ExifTool::ID3::PrintGenre($val - 1); # note the "- 1"
        },
    },
    egid => 'EpisodeGlobalUniqueID', #7
    geID => { #10
        Name => 'GenreID',
        Format => 'int32u',
        SeparateTable => 1,
        PrintConv => { #21 (based on http://www.apple.com/itunes/affiliates/resources/documentation/genre-mapping.html)
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
            1117 => 'Music|Latino|Latin Pop',
            1118 => 'Music|Latino|Raices', # (Ra&iacute;ces)
            1119 => 'Music|Latino|Latin Urban',
            1120 => 'Music|Latino|Baladas y Boleros',
            1121 => 'Music|Latino|Latin Alternative & Rock',
            1122 => 'Music|Brazilian',
            1123 => 'Music|Latino|Regional Mexicano',
            1124 => 'Music|Latino|Salsa y Tropical',
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
            1177 => 'Music|World|Afro-Beat',
            1178 => 'Music|World|Afro-Pop',
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
            1203 => 'Music|World|Africa',
            1204 => 'Music|World|Asia',
            1205 => 'Music|World|Europe',
            1206 => 'Music|World|South Africa',
            1207 => 'Music|Jazz|Hard Bop',
            1208 => 'Music|Jazz|Trad Jazz',
            1209 => 'Music|Jazz|Cool',
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
            1264 => 'Music|Indian|Tamil',
            1265 => 'Music|Indian|Telugu',
            1266 => 'Music|Indian|Regional Indian',
            1267 => 'Music|Indian|Devotional & Spiritual',
            1268 => 'Music|Indian|Sufi',
            1269 => 'Music|Indian|Indian Classical',
            1270 => 'Music|World|Russian Chanson',
            1271 => 'Music|World|Dini',
            1272 => 'Music|World|Halk',
            1273 => 'Music|World|Sanat',
            1274 => 'Music|World|Dangdut',
            1275 => 'Music|World|Indonesian Religious',
            1276 => 'Music|World|Calypso',
            1277 => 'Music|World|Soca',
            1278 => 'Music|Indian|Ghazals',
            1279 => 'Music|Indian|Indian Folk',
            1280 => 'Music|World|Arabesque',
            1281 => 'Music|World|Afrikaans',
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
            1299 => 'Music|World|Russian',
            1300 => 'Music|World|Turkish',
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
            1692 => 'Music Videos|Indian|Tamil',
            1693 => 'Music Videos|Indian|Telugu',
            1694 => 'Music Videos|Indian|Regional Indian',
            1695 => 'Music Videos|Indian|Devotional & Spiritual',
            1696 => 'Music Videos|Indian|Sufi',
            1697 => 'Music Videos|Indian|Indian Classical',
            1698 => 'Music Videos|World|Russian Chanson',
            1699 => 'Music Videos|World|Dini',
            1700 => 'Music Videos|World|Halk',
            1701 => 'Music Videos|World|Sanat',
            1702 => 'Music Videos|World|Dangdut',
            1703 => 'Music Videos|World|Indonesian Religious',
            1704 => 'Music Videos|Indian|Indian Pop',
            1705 => 'Music Videos|World|Calypso',
            1706 => 'Music Videos|World|Soca',
            1707 => 'Music Videos|Indian|Ghazals',
            1708 => 'Music Videos|Indian|Indian Folk',
            1709 => 'Music Videos|World|Arabesque',
            1710 => 'Music Videos|World|Afrikaans',
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
            1729 => 'Music Videos|World|Russian',
            1730 => 'Music Videos|World|Turkish',
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
            1830 => 'Music Videos|Jazz|Cool',
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
            1847 => 'Music Videos|Latin|Regional Mexicano',
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
            1904 => 'Music Videos|World|Africa',
            1905 => 'Music Videos|World|Afro-Beat',
            1906 => 'Music Videos|World|Afro-Pop',
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
            4000 => 'TV Shows|Comedy',
            4001 => 'TV Shows|Drama',
            4002 => 'TV Shows|Animation',
            4003 => 'TV Shows|Action & Adventure',
            4004 => 'TV Shows|Classic',
            4005 => 'TV Shows|Kids',
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
            6021 => 'App Store|Newsstand',
            6022 => 'App Store|Catalogs',
            6023 => 'App Store|Food & Drink',
            7001 => 'App Store|Games|Action',
            7002 => 'App Store|Games|Adventure',
            7003 => 'App Store|Games|Arcade',
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
            8196 => 'Tones|Ringtones|Indian|Tamil',
            8197 => 'Tones|Ringtones|Indian|Telugu',
            8198 => 'Tones|Ringtones|Instrumental',
            8199 => 'Tones|Ringtones|Jazz|Avant-Garde Jazz',
            8201 => 'Tones|Ringtones|Jazz|Big Band',
            8202 => 'Tones|Ringtones|Jazz|Bop',
            8203 => 'Tones|Ringtones|Jazz|Contemporary Jazz',
            8204 => 'Tones|Ringtones|Jazz|Cool',
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
            8228 => 'Tones|Ringtones|Latin|Regional Mexicano',
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
            8304 => 'Tones|Ringtones|World|Africa',
            8305 => 'Tones|Ringtones|World|Afrikaans',
            8306 => 'Tones|Ringtones|World|Afro-Beat',
            8307 => 'Tones|Ringtones|World|Afro-Pop',
            8308 => 'Tones|Ringtones|World|Arabesque',
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
            8324 => 'Tones|Ringtones|World|Halk',
            8325 => 'Tones|Ringtones|World|Hawaii',
            8326 => 'Tones|Ringtones|World|Iberia',
            8327 => 'Tones|Ringtones|World|Indonesian Religious',
            8328 => 'Tones|Ringtones|World|Israeli',
            8329 => 'Tones|Ringtones|World|Japan',
            8330 => 'Tones|Ringtones|World|Klezmer',
            8331 => 'Tones|Ringtones|World|North America',
            8332 => 'Tones|Ringtones|World|Polka',
            8333 => 'Tones|Ringtones|World|Russian',
            8334 => 'Tones|Ringtones|World|Russian Chanson',
            8335 => 'Tones|Ringtones|World|Sanat',
            8336 => 'Tones|Ringtones|World|Soca',
            8337 => 'Tones|Ringtones|World|South Africa',
            8338 => 'Tones|Ringtones|World|South America',
            8339 => 'Tones|Ringtones|World|Tango',
            8340 => 'Tones|Ringtones|World|Traditional Celtic',
            8341 => 'Tones|Ringtones|World|Turkish',
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
            9025 => 'Books|Health, Mind & Body',
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
            10004 => 'Books|Health, Mind & Body|Spirituality',
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
            10069 => 'Books|Health, Mind & Body|Health & Fitness',
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
            10094 => 'Books|Health, Mind & Body|Psychology',
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
            10119 => 'Books|Health, Mind & Body|Self-Improvement',
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
            11062 => 'Books|Health, Mind & Body|Diet & Nutrition',
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
            12203 => 'Mac App Store|Games|Arcade',
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
            13001 => 'App Store|Newsstand|News & Politics',
            13002 => 'App Store|Newsstand|Fashion & Style',
            13003 => 'App Store|Newsstand|Home & Garden',
            13004 => 'App Store|Newsstand|Outdoors & Nature',
            13005 => 'App Store|Newsstand|Sports & Leisure',
            13006 => 'App Store|Newsstand|Automotive',
            13007 => 'App Store|Newsstand|Arts & Photography',
            13008 => 'App Store|Newsstand|Brides & Weddings',
            13009 => 'App Store|Newsstand|Business & Investing',
            13010 => "App Store|Newsstand|Children's Magazines",
            13011 => 'App Store|Newsstand|Computers & Internet',
            13012 => 'App Store|Newsstand|Cooking, Food & Drink',
            13013 => 'App Store|Newsstand|Crafts & Hobbies',
            13014 => 'App Store|Newsstand|Electronics & Audio',
            13015 => 'App Store|Newsstand|Entertainment',
            13017 => 'App Store|Newsstand|Health, Mind & Body',
            13018 => 'App Store|Newsstand|History',
            13019 => 'App Store|Newsstand|Literary Magazines & Journals',
            13020 => "App Store|Newsstand|Men's Interest",
            13021 => 'App Store|Newsstand|Movies & Music',
            13023 => 'App Store|Newsstand|Parenting & Family',
            13024 => 'App Store|Newsstand|Pets',
            13025 => 'App Store|Newsstand|Professional & Trade',
            13026 => 'App Store|Newsstand|Regional News',
            13027 => 'App Store|Newsstand|Science',
            13028 => 'App Store|Newsstand|Teens',
            13029 => 'App Store|Newsstand|Travel & Regional',
            13030 => "App Store|Newsstand|Women's Interest",
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
            40000000 => 'iTunes U',
            40000001 => 'iTunes U|Business',
            40000002 => 'iTunes U|Business|Economics',
            40000003 => 'iTunes U|Business|Finance',
            40000004 => 'iTunes U|Business|Hospitality',
            40000005 => 'iTunes U|Business|Management',
            40000006 => 'iTunes U|Business|Marketing',
            40000007 => 'iTunes U|Business|Personal Finance',
            40000008 => 'iTunes U|Business|Real Estate',
            40000009 => 'iTunes U|Engineering',
            40000010 => 'iTunes U|Engineering|Chemical & Petroleum Engineering',
            40000011 => 'iTunes U|Engineering|Civil Engineering',
            40000012 => 'iTunes U|Engineering|Computer Science',
            40000013 => 'iTunes U|Engineering|Electrical Engineering',
            40000014 => 'iTunes U|Engineering|Environmental Engineering',
            40000015 => 'iTunes U|Engineering|Mechanical Engineering',
            40000016 => 'iTunes U|Art & Architecture',
            40000017 => 'iTunes U|Art & Architecture|Architecture',
            40000019 => 'iTunes U|Art & Architecture|Art History',
            40000020 => 'iTunes U|Art & Architecture|Dance',
            40000021 => 'iTunes U|Art & Architecture|Film',
            40000022 => 'iTunes U|Art & Architecture|Design',
            40000023 => 'iTunes U|Art & Architecture|Interior Design',
            40000024 => 'iTunes U|Art & Architecture|Music',
            40000025 => 'iTunes U|Art & Architecture|Theater',
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
            40000053 => 'iTunes U|Communications & Media',
            40000054 => 'iTunes U|Philosophy',
            40000055 => 'iTunes U|Religion & Spirituality',
            40000056 => 'iTunes U|Language',
            40000057 => 'iTunes U|Language|African Languages',
            40000058 => 'iTunes U|Language|Ancient Languages',
            40000061 => 'iTunes U|Language|English',
            40000063 => 'iTunes U|Language|French',
            40000064 => 'iTunes U|Language|German',
            40000065 => 'iTunes U|Language|Italian',
            40000066 => 'iTunes U|Language|Linguistics',
            40000068 => 'iTunes U|Language|Spanish',
            40000069 => 'iTunes U|Language|Speech Pathology',
            40000070 => 'iTunes U|Literature',
            40000071 => 'iTunes U|Literature|Anthologies',
            40000072 => 'iTunes U|Literature|Biography',
            40000073 => 'iTunes U|Literature|Classics',
            40000074 => 'iTunes U|Literature|Literary Criticism',
            40000075 => 'iTunes U|Literature|Fiction',
            40000076 => 'iTunes U|Literature|Poetry',
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
            40000094 => 'iTunes U|Psychology & Social Science',
            40000095 => 'iTunes U|Law & Politics|Law',
            40000096 => 'iTunes U|Law & Politics|Political Science',
            40000097 => 'iTunes U|Law & Politics|Public Administration',
            40000098 => 'iTunes U|Psychology & Social Science|Psychology',
            40000099 => 'iTunes U|Psychology & Social Science|Social Welfare',
            40000100 => 'iTunes U|Psychology & Social Science|Sociology',
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
            40000116 => 'iTunes U|Art & Architecture|Culinary Arts',
            40000117 => 'iTunes U|Art & Architecture|Fashion',
            40000118 => 'iTunes U|Art & Architecture|Media Arts',
            40000119 => 'iTunes U|Art & Architecture|Photography',
            40000120 => 'iTunes U|Art & Architecture|Visual Art',
            40000121 => 'iTunes U|Business|Entrepreneurship',
            40000122 => 'iTunes U|Communications & Media|Broadcasting',
            40000123 => 'iTunes U|Communications & Media|Digital Media',
            40000124 => 'iTunes U|Communications & Media|Journalism',
            40000125 => 'iTunes U|Communications & Media|Photojournalism',
            40000126 => 'iTunes U|Communications & Media|Print',
            40000127 => 'iTunes U|Communications & Media|Speech',
            40000128 => 'iTunes U|Communications & Media|Writing',
            40000129 => 'iTunes U|Health & Medicine|Nursing',
            40000130 => 'iTunes U|Language|Arabic',
            40000131 => 'iTunes U|Language|Chinese',
            40000132 => 'iTunes U|Language|Hebrew',
            40000133 => 'iTunes U|Language|Hindi',
            40000134 => 'iTunes U|Language|Indigenous Languages',
            40000135 => 'iTunes U|Language|Japanese',
            40000136 => 'iTunes U|Language|Korean',
            40000137 => 'iTunes U|Language|Other Languages',
            40000138 => 'iTunes U|Language|Portuguese',
            40000139 => 'iTunes U|Language|Russian',
            40000140 => 'iTunes U|Law & Politics',
            40000141 => 'iTunes U|Law & Politics|Foreign Policy & International Relations',
            40000142 => 'iTunes U|Law & Politics|Local Governments',
            40000143 => 'iTunes U|Law & Politics|National Governments',
            40000144 => 'iTunes U|Law & Politics|World Affairs',
            40000145 => 'iTunes U|Literature|Comparative Literature',
            40000146 => 'iTunes U|Philosophy|Aesthetics',
            40000147 => 'iTunes U|Philosophy|Epistemology',
            40000148 => 'iTunes U|Philosophy|Ethics',
            40000149 => 'iTunes U|Philosophy|Metaphysics',
            40000150 => 'iTunes U|Philosophy|Political Philosophy',
            40000151 => 'iTunes U|Philosophy|Logic',
            40000152 => 'iTunes U|Philosophy|Philosophy of Language',
            40000153 => 'iTunes U|Philosophy|Philosophy of Religion',
            40000154 => 'iTunes U|Psychology & Social Science|Archaeology',
            40000155 => 'iTunes U|Psychology & Social Science|Anthropology',
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
            40000173 => 'iTunes U|Language|Dutch',
            40000174 => 'iTunes U|Language|Luxembourgish',
            40000175 => 'iTunes U|Language|Swedish',
            40000176 => 'iTunes U|Language|Norwegian',
            40000177 => 'iTunes U|Language|Finnish',
            40000178 => 'iTunes U|Language|Danish',
            40000179 => 'iTunes U|Language|Polish',
            40000180 => 'iTunes U|Language|Turkish',
            40000181 => 'iTunes U|Language|Flemish',
            50000024 => 'Audiobooks',
            50000040 => 'Audiobooks|Fiction',
            50000041 => 'Audiobooks|Arts & Entertainment',
            50000042 => 'Audiobooks|Biography & Memoir',
            50000043 => 'Audiobooks|Business',
            50000044 => 'Audiobooks|Kids & Young Adults',
            50000045 => 'Audiobooks|Classics',
            50000046 => 'Audiobooks|Comedy',
            50000047 => 'Audiobooks|Drama & Poetry',
            50000048 => 'Audiobooks|Speakers & Storytellers',
            50000049 => 'Audiobooks|History',
            50000050 => 'Audiobooks|Languages',
            50000051 => 'Audiobooks|Mystery',
            50000052 => 'Audiobooks|Nonfiction',
            50000053 => 'Audiobooks|Religion & Spirituality',
            50000054 => 'Audiobooks|Science',
            50000055 => 'Audiobooks|Sci Fi & Fantasy',
            50000056 => 'Audiobooks|Self Development',
            50000057 => 'Audiobooks|Sports',
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
        },
    },
    grup => 'Grouping', #10
    hdvd => { #10
        Name => 'HDVideo',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    keyw => 'Keyword', #7
    ldes => 'LongDescription', #10
    pcst => { #7
        Name => 'Podcast',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    perf => 'Performer',
    plID => { #10 (or TV season)
        Name => 'PlayListID',
        Format => 'int8u',  # actually int64u, but split it up
    },
    purd => 'PurchaseDate', #7
    purl => 'PodcastURL', #7
    rtng => { #10
        Name => 'Rating',
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
        SeparateTable => 1,
        PrintConv => { #21
            143441 => 'United States', # USA
            143442 => 'France', # FRA
            143443 => 'Germany', # DEU
            143444 => 'United Kingdom', # GBR
            143445 => 'Austria', # AUT
            143446 => 'Belgium', # BEL
            143447 => 'Finland', # FIN
            143448 => 'Greece', # GRC
            143449 => 'Ireland', # IRL
            143450 => 'Italy', # ITA
            143451 => 'Luxembourg', # LUX
            143452 => 'Netherlands', # NLD
            143453 => 'Portugal', # PRT
            143454 => 'Spain', # ESP
            143455 => 'Canada', # CAN
            143456 => 'Sweden', # SWE
            143457 => 'Norway', # NOR
            143458 => 'Denmark', # DNK
            143459 => 'Switzerland', # CHE
            143460 => 'Australia', # AUS
            143461 => 'New Zealand', # NZL
            143462 => 'Japan', # JPN
            143463 => 'Hong Kong', # HKG
            143464 => 'Singapore', # SGP
            143465 => 'China', # CHN
            143466 => 'Republic of Korea', # KOR
            143467 => 'India', # IND
            143468 => 'Mexico', # MEX
            143469 => 'Russia', # RUS
            143470 => 'Taiwan', # TWN
            143471 => 'Vietnam', # VNM
            143472 => 'South Africa', # ZAF
            143473 => 'Malaysia', # MYS
            143474 => 'Philippines', # PHL
            143475 => 'Thailand', # THA
            143476 => 'Indonesia', # IDN
            143477 => 'Pakistan', # PAK
            143478 => 'Poland', # POL
            143479 => 'Saudi Arabia', # SAU
            143480 => 'Turkey', # TUR
            143481 => 'United Arab Emirates', # ARE
            143482 => 'Hungary', # HUN
            143483 => 'Chile', # CHL
            143484 => 'Nepal', # NPL
            143485 => 'Panama', # PAN
            143486 => 'Sri Lanka', # LKA
            143487 => 'Romania', # ROU
            143489 => 'Czech Republic', # CZE
            143491 => 'Israel', # ISR
            143492 => 'Ukraine', # UKR
            143493 => 'Kuwait', # KWT
            143494 => 'Croatia', # HRV
            143495 => 'Costa Rica', # CRI
            143496 => 'Slovakia', # SVK
            143497 => 'Lebanon', # LBN
            143498 => 'Qatar', # QAT
            143499 => 'Slovenia', # SVN
            143501 => 'Colombia', # COL
            143502 => 'Venezuela', # VEN
            143503 => 'Brazil', # BRA
            143504 => 'Guatemala', # GTM
            143505 => 'Argentina', # ARG
            143506 => 'El Salvador', # SLV
            143507 => 'Peru', # PER
            143508 => 'Dominican Republic', # DOM
            143509 => 'Ecuador', # ECU
            143510 => 'Honduras', # HND
            143511 => 'Jamaica', # JAM
            143512 => 'Nicaragua', # NIC
            143513 => 'Paraguay', # PRY
            143514 => 'Uruguay', # URY
            143515 => 'Macau', # MAC
            143516 => 'Egypt', # EGY
            143517 => 'Kazakhstan', # KAZ
            143518 => 'Estonia', # EST
            143519 => 'Latvia', # LVA
            143520 => 'Lithuania', # LTU
            143521 => 'Malta', # MLT
            143523 => 'Moldova', # MDA
            143524 => 'Armenia', # ARM
            143525 => 'Botswana', # BWA
            143526 => 'Bulgaria', # BGR
            143528 => 'Jordan', # JOR
            143529 => 'Kenya', # KEN
            143530 => 'Macedonia', # MKD
            143531 => 'Madagascar', # MDG
            143532 => 'Mali', # MLI
            143533 => 'Mauritius', # MUS
            143534 => 'Niger', # NER
            143535 => 'Senegal', # SEN
            143536 => 'Tunisia', # TUN
            143537 => 'Uganda', # UGA
            143538 => 'Anguilla', # AIA
            143539 => 'Bahamas', # BHS
            143540 => 'Antigua and Barbuda', # ATG
            143541 => 'Barbados', # BRB
            143542 => 'Bermuda', # BMU
            143543 => 'British Virgin Islands', # VGB
            143544 => 'Cayman Islands', # CYM
            143545 => 'Dominica', # DMA
            143546 => 'Grenada', # GRD
            143547 => 'Montserrat', # MSR
            143548 => 'St. Kitts and Nevis', # KNA
            143549 => 'St. Lucia', # LCA
            143550 => 'St. Vincent and The Grenadines', # VCT
            143551 => 'Trinidad and Tobago', # TTO
            143552 => 'Turks and Caicos', # TCA
            143553 => 'Guyana', # GUY
            143554 => 'Suriname', # SUR
            143555 => 'Belize', # BLZ
            143556 => 'Bolivia', # BOL
            143557 => 'Cyprus', # CYP
            143558 => 'Iceland', # ISL
            143559 => 'Bahrain', # BHR
            143560 => 'Brunei Darussalam', # BRN
            143561 => 'Nigeria', # NGA
            143562 => 'Oman', # OMN
            143563 => 'Algeria', # DZA
            143564 => 'Angola', # AGO
            143565 => 'Belarus', # BLR
            143566 => 'Uzbekistan', # UZB
            143568 => 'Azerbaijan', # AZE
            143571 => 'Yemen', # YEM
            143572 => 'Tanzania', # TZA
            143573 => 'Ghana', # GHA
            143575 => 'Albania', # ALB
            143576 => 'Benin', # BEN
            143577 => 'Bhutan', # BTN
            143578 => 'Burkina Faso', # BFA
            143579 => 'Cambodia', # KHM
            143580 => 'Cape Verde', # CPV
            143581 => 'Chad', # TCD
            143582 => 'Republic of the Congo', # COG
            143583 => 'Fiji', # FJI
            143584 => 'Gambia', # GMB
            143585 => 'Guinea-Bissau', # GNB
            143586 => 'Kyrgyzstan', # KGZ
            143587 => "Lao People's Democratic Republic", # LAO
            143588 => 'Liberia', # LBR
            143589 => 'Malawi', # MWI
            143590 => 'Mauritania', # MRT
            143591 => 'Federated States of Micronesia', # FSM
            143592 => 'Mongolia', # MNG
            143593 => 'Mozambique', # MOZ
            143594 => 'Namibia', # NAM
            143595 => 'Palau', # PLW
            143597 => 'Papua New Guinea', # PNG
            143598 => 'Sao Tome and Principe', # STP (S&atilde;o Tom&eacute; and Pr&iacute;ncipe)
            143599 => 'Seychelles', # SYC
            143600 => 'Sierra Leone', # SLE
            143601 => 'Solomon Islands', # SLB
            143602 => 'Swaziland', # SWZ
            143603 => 'Tajikistan', # TJK
            143604 => 'Turkmenistan', # TKM
            143605 => 'Zimbabwe', # ZWE
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
        PrintConvColumns => 2,
        PrintConv => { #(http://weblog.xanga.com/gryphondwb/615474010/iphone-ringtones---what-did-itunes-741-really-do.html)
            0 => 'Movie',
            1 => 'Normal (Music)',
            2 => 'Audiobook',
            5 => 'Whacked Bookmark',
            6 => 'Music Video',
            9 => 'Short Film',
            10 => 'TV Show',
            11 => 'Booklet',
            14 => 'Ringtone',
            21 => 'Podcast', #15
        },
    },
    rate => 'RatingPercent', #PH
    titl => 'Title',
    tven => 'TVEpisodeID', #7
    tves => { #7/10
        Name => 'TVEpisode',
        Format => 'int32u',
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
        Description => 'iTunes U',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    #https://github.com/communitymedia/mediautilities/blob/master/src/net/sourceforge/jaad/mp4/boxes/BoxTypes.java
    gshh => { Name => 'GoogleHostHeader',   Format => 'string' },
    gspm => { Name => 'GooglePingMessage',  Format => 'string' },
    gspu => { Name => 'GooglePingURL',      Format => 'string' },
    gssd => { Name => 'GoogleSourceData',   Format => 'string' },
    gsst => { Name => 'GoogleStartTime',    Format => 'string' },
    gstd => { Name => 'GoogleTrackDuration',Format => 'string', ValueConv => '$val / 1000',  PrintConv => 'ConvertDuration($val)' },

    # atoms observed in AAX audiobooks (ref PH)
    "\xa9cpy" => { Name => 'Copyright',  Groups => { 2 => 'Author' } },
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
);

# item list keys (ref PH)
%Image::ExifTool::QuickTime::Keys = (
    PROCESS_PROC => \&Image::ExifTool::QuickTime::ProcessKeys,
    VARS => { LONG_TAGS => 1 },
    NOTES => q{
        This directory contains a list of key names which are used to decode
        ItemList tags written by the "mdta" handler.  The prefix of
        "com.apple.quicktime." has been removed from all TagID's below.
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
        ValueConv => q{
            require Image::ExifTool::XMP;
            $val =  Image::ExifTool::XMP::ConvertXMPDate($val,1);
            $val =~ s/([-+]\d{2})(\d{2})$/$1:$2/; # add colon to timezone if necessary
            return $val;
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    description => { },
    director    => { },
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
    'camera.identifier' => 'CameraIdentifier', # (iPhone 4)
    'camera.framereadouttimeinmicroseconds' => { # (iPhone 4)
        Name => 'FrameReadoutTime',
        ValueConv => '$val * 1e-6',
        PrintConv => '$val * 1e6 . " microseconds"',
    },
    'location.ISO6709' => {
        Name => 'GPSCoordinates',
        Groups => { 2 => 'Location' },
        ValueConv => \&ConvertISO6709,
        PrintConv => \&PrintGPSCoordinates,
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
        ValueConv => q{
            require Image::ExifTool::XMP;
            $val =  Image::ExifTool::XMP::ConvertXMPDate($val);
            $val =~ s/([-+]\d{2})(\d{2})$/$1:$2/; # add colon to timezone if necessary
            return $val;
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    'direction.facing' => { Name => 'CameraDirection', Groups => { 2 => 'Location' } },
    'direction.motion' => { Name => 'CameraMotion', Groups => { 2 => 'Location' } },
    'location.body' => { Name => 'LocationBody', Groups => { 2 => 'Location' } },
    'player.version'                => 'PlayerVersion',
    'player.movie.visual.brightness'=> 'Brightness',
    'player.movie.visual.color'     => 'Color',
    'player.movie.visual.tint'      => 'Tint',
    'player.movie.visual.contrast'  => 'Contrast',
    'player.movie.audio.gain'       => 'AudioGain',
    'player.movie.audio.treble'     => 'Trebel',
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
);

# iTunes info ('----') atoms
%Image::ExifTool::QuickTime::iTunesInfo = (
    PROCESS_PROC => \&ProcessMOV,
    GROUPS => { 2 => 'Audio' },
    NOTES => q{
        ExifTool will extract any iTunesInfo tags that exist, even if they are not
        defined in this table.
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
    DISCNUMBER => 'DiscNumber', #PH
    TRACKNUMBER => 'TrackNumber', #PH
    popularimeter => 'Popularimeter', #PH
);

# iTunes audio encoding parameters
# ref https://developer.apple.com/library/mac/#documentation/MusicAudio/Reference/AudioCodecServicesRef/Reference/reference.html
%Image::ExifTool::QuickTime::EncodingParams = (
    PROCESS_PROC => \&ProcessEncodingParams,
    GROUPS => { 2 => 'Audio' },
    # (I have commented out the ones that don't have integer values because they
    #  probably don't appear, and definitly wouldn't work with current decoding - PH)

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
        ValueConv => '$val < 0x400 ? $val : pack "C*", map { (($val>>$_)&0x1f)+0x60 } 10, 5, 0',
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
        Name => 'DataInfo',
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
    GROUPS => { 2 => 'Video' },
    NOTES => 'MP4 sample table box.',
    stsd => [
        {
            Name => 'AudioSampleDesc',
            Condition => '$$self{HandlerType} and $$self{HandlerType} eq "soun"',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::AudioSampleDesc',
                Start => 8, # skip version number and count
            },
        },{
            Name => 'VideoSampleDesc',
            Condition => '$$self{HandlerType} and $$self{HandlerType} eq "vide"',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::ImageDesc',
                Start => 8, # skip version number and count
            },
        },{
            Name => 'HintSampleDesc',
            Condition => '$$self{HandlerType} and $$self{HandlerType} eq "hint"',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::HintSampleDesc',
                Start => 8, # skip version number and count
            },
        },{
            Name => 'OtherSampleDesc',
            SubDirectory => {
                TagTable => 'Image::ExifTool::QuickTime::OtherSampleDesc',
                Start => 8, # skip version number and count
            },
        },
        # (Note: "alis" HandlerType handled by the parent audio or video handler)
    ],
    stts => [ # decoding time-to-sample table
        {
            Name => 'VideoFrameRate',
            Notes => 'average rate calculated from time-to-sample table for video media',
            Condition => '$$self{HandlerType} and $$self{HandlerType} eq "vide"',
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
            $self->OverrideFileType('M4P') if $val eq 'drms' and $$self{VALUE}{FileType} eq 'M4A';
            return $val;
        },
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
#   mp4a         52 *    wave, chan, esds
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
    # chan - 16/36 bytes
    # esds - 31/40/42/43 bytes - ES descriptor (ref 3)
    damr => { #3
        Name => 'DecodeConfig',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::DecodeConfig' },
    },
    wave => {
        Name => 'Wave',
        SubDirectory => { TagTable => 'Image::ExifTool::QuickTime::Wave' },
    },
    # alac - 28 bytes
    # adrm - AAX DRM atom? 148 bytes
    # aabd - AAX unknown 17kB (contains 'aavd' strings)
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
    # skcr
    # enda
);

%Image::ExifTool::QuickTime::Wave = (
    PROCESS_PROC => \&ProcessMOV,
    frma => 'PurchaseFileFormat',
    # "ms\0\x11" - 20 bytes
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
    # chtb
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

# MP4 generic sample description box
%Image::ExifTool::QuickTime::OtherSampleDesc = (
    PROCESS_PROC => \&ProcessHybrid,
    4 => { Name => 'OtherFormat', Format => 'undef[4]' },
#
# Observed offsets for child atoms of various OtherFormat types:
#
#   OtherFormat  Offset  Child atoms
#   -----------  ------  ----------------
#   avc1         86      avcC
#   mp4a         36      esds
#   mp4s         16      esds
#   tmcd         34      name
#
    ftab => { Name => 'FontTable',  Format => 'undef', ValueConv => 'substr($val, 5)' },
);

# MP4 data information box (ref 5)
%Image::ExifTool::QuickTime::DataInfo = (
    PROCESS_PROC => \&ProcessMOV,
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
    'urn ' => {
        Name => 'URN',
        Format => 'undef',  # (necessary to prevent decoding as string!)
        RawConv => q{
            return undef if unpack("N",$val) & 0x01;
            $_ = substr($val,4); s/\0.*//s; $_;
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
        RawConv => '$$self{HandlerType} = $val unless $val eq "alis" or $val eq "url "; $val',
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

# QuickTime composite tags
%Image::ExifTool::QuickTime::Composite = (
    GROUPS => { 2 => 'Video' },
    Rotation => {
        Require => {
            0 => 'QuickTime:MatrixStructure',
            1 => 'QuickTime:HandlerType',
        },
        ValueConv => 'Image::ExifTool::QuickTime::CalcRotation($self)',
    },
    AvgBitrate => {
        Priority => 0,  # let QuickTime::AvgBitrate take priority
        Require => {
            0 => 'QuickTime::MovieDataSize',
            1 => 'QuickTime::Duration',
        },
        RawConv => q{
            return undef unless $val[1];
            $val[1] /= $$self{TimeScale} if $$self{TimeScale};
            my $key = 'MovieDataSize';
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
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
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
        my @a = split ' ', $$value{$tag};
        return undef unless $a[0] or $a[1];
        # calculate the rotation angle (assume uniform rotation)
        my $angle = atan2($a[1], $a[0]) * 180 / 3.14159;
        $angle += 360 if $angle < 0;
        return int($angle * 1000 + 0.5) / 1000;
    }
    return undef;
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
    if ($val & 0xffff0000) {
        $val = unpack('n',pack('N',$val));
    }
    return $val;
}

#------------------------------------------------------------------------------
# Convert ISO 6709 string to standard lag/lon format
# Inputs: 0) ISO 6709 string (lat, lon, and optional alt)
# Returns: position in decimal degress with altitude if available
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
    return sprintf("[%d:%.2d:%06.3f] %s",$h,$m,$s,$title);
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
# Inputs: 0) packed language code (or undef)
# Returns: language code, or undef for default language, or 'err' for format error
sub UnpackLang($)
{
    my $lang = shift;
    if ($lang) {
        # language code is packed in 5-bit characters
        $lang = pack "C*", map { (($lang>>$_)&0x1f)+0x60 } 10, 5, 0;
        # validate language code
        if ($lang =~ /^[a-z]+$/) {
            # treat 'eng' or 'und' as the default language
            undef $lang if $lang eq 'und' or $lang eq 'eng';
        } else {
            $lang = 'err';  # invalid language code
        }
    }
    return $lang;
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
# Process hybrid binary data + QuickTime container (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessHybrid($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    # brute-force search for child atoms after first 8 bytes of binary data
    my $dataPt = $$dirInfo{DataPt};
    my $pos = ($$dirInfo{DirStart} || 0) + 8;
    my $len = length($$dataPt);
    my $try = $pos;
    my $childPos;

    while ($pos <= $len - 8) {
        my $tag = substr($$dataPt, $try+4, 4);
        # look only for well-behaved tag ID's
        $tag =~ /[^\w ]/ and $try = ++$pos, next;
        my $size = Get32u($dataPt, $try);
        if ($size + $try == $len) {
            # the atom ends exactly at the end of the parent -- this must be it
            $childPos = $pos;
            $$dirInfo{DirLen} = $pos;   # the binary data ends at the first child atom
            last;
        }
        if ($size < 8 or $size + $try > $len - 8) {
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
        $$dirInfo{DirLen} = $len - $childPos;
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
    my $unknown = $$et{OPTIONS}{Unkown} || $$et{OPTIONS}{Verbose};
    my $pos;
    $et->VerboseDir('righ', $dirLen / 8);
    for ($pos = 0; $pos + 8 <= $dirLen; $pos += 8) {
        my $tag = substr($$dataPt, $pos, 4);
        last if $tag eq "\0\0\0\0";
        my $val = substr($$dataPt, $pos + 4, 4);
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        unless ($tagInfo) {
            next unless $unknown;
            my $name = $tag;
            $name =~ s/([\x00-\x1f\x7f-\xff])/'x'.unpack('H*',$1)/eg;
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
# Process Meta keys and add tags to the ItemList table ('mdta' handler) (ref PH)
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
    ++$$et{KeyCount};   # increment key count for this directory
    my $infoTable = GetTagTable('Image::ExifTool::QuickTime::ItemList');
    my $userTable = GetTagTable('Image::ExifTool::QuickTime::UserData');
    while ($pos < $dirLen - 4) {
        my $len = unpack("x${pos}N", $$dataPt);
        last if $len < 8 or $pos + $len > $dirLen;
        delete $$tagTablePtr{$index};
        my $ns  = substr($$dataPt, $pos + 4, 4);
        my $tag = substr($$dataPt, $pos + 8, $len - 8);
        $tag =~ s/\0.*//s; # truncate at null
        if ($ns eq 'mdta') {
            $tag =~ s/^com\.apple\.quicktime\.//;   # remove common apple quicktime domain
        }
        next unless $tag;
        # (I have some samples where the tag is a reversed ItemList or UserData tag ID)
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        unless ($tagInfo) {
            $tagInfo = $et->GetTagInfo($infoTable, $tag);
            unless ($tagInfo) {
                $tagInfo = $et->GetTagInfo($userTable, $tag);
                if (not $tagInfo and $tag =~ /^\w{3}\xa9$/) {
                    $tag = pack('N', unpack('V', $tag));
                    $tagInfo = $et->GetTagInfo($infoTable, $tag);
                    $tagInfo or $tagInfo = $et->GetTagInfo($userTable, $tag);
                }
            }
        }
        my ($newInfo, $msg);
        if ($tagInfo) {
            $newInfo = {
                Name      => $$tagInfo{Name},
                Format    => $$tagInfo{Format},
                ValueConv => $$tagInfo{ValueConv},
                PrintConv => $$tagInfo{PrintConv},
            };
            my $groups = $$tagInfo{Groups};
            $$newInfo{Groups} = { %$groups } if $groups;
        } elsif ($tag =~ /^[-\w.]+$/) {
            # create info for tags with reasonable id's
            my $name = $tag;
            $name =~ s/\.(.)/\U$1/g;
            $newInfo = { Name => ucfirst($name) };
            $msg = ' (Unknown)';
        }
        # substitute this tag in the ItemList table with the given index
        my $id = $$et{KeyCount} . '.' . $index;
        if (ref $$infoTable{$id} eq 'HASH') {
            # delete other languages too if they exist
            my $oldInfo = $$infoTable{$id};
            if ($$oldInfo{OtherLang}) {
                delete $$infoTable{$_} foreach @{$$oldInfo{OtherLang}};
            }
            delete $$infoTable{$id};
        }
        if ($newInfo) {
            $msg or $msg = '';
            AddTagToTable($infoTable, $id, $newInfo);
            $out and print $out "$$et{INDENT}Added ItemList Tag $id = $tag$msg\n";
        }
        $pos += $len;
        ++$index;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process a QuickTime atom
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) optional tag table ref
# Returns: 1 on success
sub ProcessMOV($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $dataPt = $$dirInfo{DataPt};
    my $verbose = $et->Options('Verbose');
    my $dataPos = $$dirInfo{Base} || 0;
    my $charsetQuickTime = $et->Options('CharsetQuickTime');
    my ($buff, $tag, $size, $track, $isUserData, %triplet, $doDefaultLang);

    unless (defined $$et{KeyCount}) {
        $$et{KeyCount} = 0;     # initialize ItemList key directory count
        $doDefaultLang = 1;     # flag to generate default language tags
    }
    # more convenient to package data as a RandomAccess file
    $raf or $raf = new File::RandomAccess($dataPt);
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
    if ($dataPt) {
        $verbose and $et->VerboseDir($$dirInfo{DirName});
    } else {
        # check on file type if called with a RAF
        $$tagTablePtr{$tag} or return 0;
        if ($tag eq 'ftyp' and $size >= 12) {
            # read ftyp atom to see what type of file this is
            my $fileType;
            if ($raf->Read($buff, $size-8) == $size-8) {
                $raf->Seek(-($size-8), 1);
                my $type = substr($buff, 0, 4);
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
            $et->SetFileType($fileType, $mimeLookup{$fileType} || 'video/mp4');
        } else {
            $et->SetFileType();       # MOV
        }
        SetByteOrder('MM');
        $$et{PRIORITY_DIR} = 'XMP';   # have XMP take priority
    }
    for (;;) {
        if ($size < 8) {
            if ($size == 0) {
                if ($dataPt) {
                    # a zero size isn't legal for contained atoms, but Canon uses it to
                    # terminate the CNTH atom (eg. CanonEOS100D.mov), so tolerate it here
                    my $pos = $raf->Tell() - 4;
                    $raf->Seek(0,2);
                    my $str = $$dirInfo{DirName} . ' with ' . ($raf->Tell() - $pos) . ' bytes';
                    $et->VPrint(0,"$$et{INDENT}\[Terminator found in $str remaining]");
                } else {
                    $tag = sprintf("0x%.8x",Get32u(\$tag,0)) if $tag =~ /[\x00-\x1f\x7f-\xff]/;
                    $et->VPrint(0,"$$et{INDENT}Tag '$tag' extends to end of file");
                }
                last;
            }
            $size == 1 or $et->Warn('Invalid atom size'), last;
            # read extended atom size
            $raf->Read($buff, 8) == 8 or last;
            $dataPos += 8;
            my ($hi, $lo) = unpack('NN', $buff);
            if ($hi or $lo > 0x7fffffff) {
                if ($hi > 0x7fffffff) {
                    $et->Warn('Invalid atom size');
                    last;
                } elsif (not $et->Options('LargeFileSupport')) {
                    $et->Warn('End of processing at large atom (LargeFileSupport not enabled)');
                    last;
                }
            }
            $size = $hi * 4294967296 + $lo - 16;
            $size < 0 and $et->Warn('Invalid extended size'), last;
        } else {
            $size -= 8;
        }
        if ($isUserData and $$et{SET_GROUP1}) {
            my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
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
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        # allow numerical tag ID's
        unless ($tagInfo) {
            my $id = $$et{KeyCount} . '.' . unpack('N', $tag);
            if ($$tagTablePtr{$id}) {
                $tagInfo = $et->GetTagInfo($tagTablePtr, $id);
                $tag = $id;
            }
        }
        # generate tagInfo if Unknown option set
        if (not defined $tagInfo and ($$et{OPTIONS}{Unknown} or
            $verbose or $tag =~ /^\xa9/))
        {
            my $name = $tag;
            my $n = ($name =~ s/([\x00-\x1f\x7f-\xff])/'x'.unpack('H*',$1)/eg);
            # print in hex if tag is numerical
            $name = sprintf('0x%.4x',unpack('N',$tag)) if $n > 2;
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
            $et->HandleTag($tagTablePtr, "$tag-offset", $raf->Tell()) if $$tagTablePtr{"$tag-offset"};
        }
        # load values only if associated with a tag (or verbose) and not too big
        my $ignore;
        if ($size > 0x2000000) {    # start to get worried above 32 MB
            $ignore = 1;
            if ($tagInfo and not $$tagInfo{Unknown}) {
                my $t = $tag;
                $t =~ s/([\x00-\x1f\x7f-\xff])/'x'.unpack('H*',$1)/eg;
                if ($size > 0x8000000) {
                    $et->Warn("Skipping '$t' atom > 128 MB", 1);
                } else {
                    $et->Warn("Skipping '$t' atom > 32 MB", 2) or $ignore = 0;
                }
            }
        }
        if (defined $tagInfo and not $ignore) {
            my $val;
            my $missing = $size - $raf->Read($val, $size);
            if ($missing) {
                $et->Warn("Truncated '$tag' data (missing $missing bytes)");
                last;
            }
            # use value to get tag info if necessary
            $tagInfo or $tagInfo = $et->GetTagInfo($tagTablePtr, $tag, \$val);
            my $hasData = ($$dirInfo{HasData} and $val =~ /\0...data\0/s);
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
                );
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
                    undef %triplet;
                } else {
                    undef %triplet if $tag eq 'mean';
                    $triplet{$tag} = substr($val,4) if length($val) > 4;
                    undef $tagInfo;  # don't store this tag
                }
            }
            if ($tagInfo) {
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
                    if ($$tagInfo{Name} eq 'Track') {
                        $track or $track = 0;
                        $$et{SET_GROUP1} = 'Track' . (++$track);
                    }
                    my $subTable = GetTagTable($$subdir{TagTable});
                    my $proc = $$subdir{ProcessProc};
                    # make ProcessMOV() the default processing procedure for subdirectories
                    $proc = \&ProcessMOV unless $proc or $$subTable{PROCESS_PROC};
                    $et->ProcessDirectory(\%dirInfo, $subTable, $proc) if $size > $start;
                    $$et{SET_GROUP1} = $oldGroup1;
                    SetByteOrder('MM');
                } elsif ($hasData) {
                    # handle atoms containing 'data' tags
                    # (currently ignore contained atoms: 'itif', 'name', etc.)
                    my $pos = 0;
                    for (;;) {
                        last if $pos + 16 > $size;
                        my ($len, $type, $flags, $ctry, $lang) = unpack("x${pos}Na4Nnn", $val);
                        last if $pos + $len > $size;
                        my $value;
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
                                    if ($flags == 0x15 or $flags == 0x16) {
                                        $format = { 1=>'int8', 2=>'int16', 4=>'int32' }->{$len};
                                        $format .= $flags == 0x15 ? 's' : 'u' if $format;
                                    } elsif ($flags == 0x17) {
                                        $format = 'float';
                                    } elsif ($flags == 0x18) {
                                        $format = 'double';
                                    } elsif ($flags == 0x00) {
                                        # read 1 and 2-byte binary as integers
                                        if ($len == 1) {
                                            $format = 'int8u',
                                        } elsif ($len == 2) {
                                            $format = 'int16u',
                                        }
                                    }
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
                        my $langInfo;
                        if ($ctry or $lang) {
                            # ignore country ('ctry') and language lists ('lang') for now
                            undef $ctry if $ctry and $ctry <= 255;
                            undef $lang if $lang and $lang <= 255;
                            $lang = UnpackLang($lang);
                            # add country code if specified
                            if ($ctry) {
                                $ctry = unpack('a2',pack('n',$ctry)); # unpack as ISO 3166-1
                                # treat 'ZZ' like a default country (see ref 12)
                                undef $ctry if $ctry eq 'ZZ';
                                if ($ctry and $ctry =~ /^[A-Z]{2}$/) {
                                    $lang or $lang = 'und';
                                    $lang .= "-$ctry";
                                }
                            }
                            if ($lang) {
                                # get tagInfo for other language
                                $langInfo = GetLangInfoQT($et, $tagInfo, $lang);
                                # save other language tag ID's so we can delete later if necessary
                                if ($langInfo) {
                                    $$tagInfo{OtherLang} or $$tagInfo{OtherLang} = [ ];
                                    push @{$$tagInfo{OtherLang}}, $$langInfo{TagID};
                                }
                            }
                        }
                        $langInfo or $langInfo = $tagInfo;
                        $et->VerboseInfo($tag, $langInfo,
                            Value   => ref $value ? $$value : $value,
                            DataPt  => \$val,
                            DataPos => $dataPos,
                            Start   => $pos,
                            Size    => $len,
                            Format  => $format,
                            Extra   => sprintf(", Type='$type', Flags=0x%x",$flags)
                        ) if $verbose;
                        $et->FoundTag($langInfo, $value) if defined $value;
                        $pos += $len;
                    }
                } elsif ($tag =~ /^\xa9/ or $$tagInfo{IText}) {
                    # parse international text to extract all languages
                    my $pos = 0;
                    if ($$tagInfo{Format}) {
                        $et->FoundTag($tagInfo, ReadValue(\$val, 0, $$tagInfo{Format}, undef, length($val)));
                        $pos = $size;
                    }
                    for (;;) {
                        last if $pos + 4 > $size;
                        my ($len, $lang) = unpack("x${pos}nn", $val);
                        $pos += 4;
                        # according to the QuickTime spec (ref 12), $len should include
                        # 4 bytes for length and type words, but nobody (including
                        # Apple, Pentax and Kodak) seems to add these in, so try
                        # to allow for either
                        if ($pos + $len > $size) {
                            $len -= 4;
                            last if $pos + $len > $size or $len < 0;
                        }
                        # ignore any empty entries (or null padding) after the first
                        next if not $len and $pos;
                        my $str = substr($val, $pos, $len);
                        my $langInfo;
                        if ($lang < 0x400) {
                            # this is a Macintosh language code
                            # a language code of 0 is Macintosh english, so treat as default
                            if ($lang) {
                                # use Font.pm to look up language string
                                require Image::ExifTool::Font;
                                $lang = $Image::ExifTool::Font::ttLang{Macintosh}{$lang};
                            }
                            # the spec says only "Macintosh text encoding", but
                            # allow this to be configured by the user
                            $str = $et->Decode($str, $charsetQuickTime);
                        } else {
                            # convert language code to ASCII (ignore read-only bit)
                            $lang = UnpackLang($lang);
                            # may be either UTF-8 or UTF-16BE
                            my $enc = $str=~s/^\xfe\xff// ? 'UTF16' : 'UTF8';
                            $str = $et->Decode($str, $enc);
                        }
                        $langInfo = GetLangInfoQT($et, $tagInfo, $lang) if $lang;
                        $et->FoundTag($langInfo || $tagInfo, $str);
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
                            require Image::ExifTool::XMP;
                            my $enc = Image::ExifTool::XMP::IsUTF8($vp) > 0 ? 'UTF8' : $charsetQuickTime;
                            $$vp = $et->Decode($$vp, $enc);
                        }
                    }
                }
            }
        } else {
            $et->VerboseInfo($tag, $tagInfo,
                Size  => $size,
                Extra => sprintf(' at offset 0x%.4x', $raf->Tell()),
            ) if $verbose;
            $raf->Seek($size, 1) or $et->Warn("Truncated '$tag' data"), last;
        }
        $raf->Read($buff, 8) == 8 or last;
        $dataPos += $size + 8;
        ($size, $tag) = unpack('Na4', $buff);
    }
    # fill in missing defaults for alternate language tags
    # (the first language is taken as the default)
    if ($doDefaultLang and $$et{QTLang}) {
        foreach $tag (@{$$et{QTLang}}) {
            next unless defined $$et{VALUE}{$tag};
            my $langInfo = $$et{TAG_INFO}{$tag} or next;
            my $tagInfo = $$langInfo{SrcTagInfo} or next;
            next if defined $$et{VALUE}{$$tagInfo{Name}};
            $et->FoundTag($tagInfo, $$et{VALUE}{$tag});
        }
        delete $$et{QTLang};
    }
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

1;  # end

__END__

=head1 NAME

Image::ExifTool::QuickTime - Read QuickTime and MP4 meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
information from QuickTime and MP4 video, and M4A audio files.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

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

