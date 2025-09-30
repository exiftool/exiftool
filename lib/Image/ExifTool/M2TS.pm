#------------------------------------------------------------------------------
# File:         M2TS.pm
#
# Description:  Read M2TS (AVCHD) meta information
#
# Revisions:    2009/07/03 - P. Harvey Created
#
# References:   1) http://neuron2.net/library/mpeg2/iso13818-1.pdf
#               2) http://www.blu-raydisc.com/Assets/Downloadablefile/BD-RE_Part3_V2.1_WhitePaper_080406-15271.pdf
#               3) http://www.videohelp.com/forum/archive/reading-avchd-playlist-files-bdmv-playlist-mpl-t358888.html
#               4) http://en.wikipedia.org/wiki/MPEG_transport_stream
#               5) http://www.dunod.com/documents/9782100493463/49346_DVB.pdf
#               6) http://trac.handbrake.fr/browser/trunk/libhb/stream.c
#               7) http://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=04560141
#               8) http://www.w6rz.net/xport.zip
#               9) https://en.wikipedia.org/wiki/Program-specific_information
#
# Notes:        Variable names containing underlines are the same as in ref 1.
#
# Glossary:     PES = Packetized Elementary Stream
#               PAT = Program Association Table
#               PMT = Program Map Table
#               PCR = Program Clock Reference
#               PID = Packet Identifier
#
# To Do:        - parse PCR to obtain average bitrates?
#------------------------------------------------------------------------------

package Image::ExifTool::M2TS;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.31';

# program map table "stream_type" lookup (ref 6/1/9)
my %streamType = (
    0x00 => 'Reserved',
    0x01 => 'MPEG-1 Video',
    0x02 => 'MPEG-2 Video',
    0x03 => 'MPEG-1 Audio',
    0x04 => 'MPEG-2 Audio',
    0x05 => 'ISO 13818-1 private sections',
    0x06 => 'ISO 13818-1 PES private data',
    0x07 => 'ISO 13522 MHEG',
    0x08 => 'ISO 13818-1 DSM-CC',
    0x09 => 'ISO 13818-1 auxiliary',
    0x0A => 'ISO 13818-6 multi-protocol encap',
    0x0B => 'ISO 13818-6 DSM-CC U-N msgs',
    0x0C => 'ISO 13818-6 stream descriptors',
    0x0D => 'ISO 13818-6 sections',
    0x0E => 'ISO 13818-1 auxiliary',
    0x0F => 'MPEG-2 AAC Audio',
    0x10 => 'MPEG-4 Video',
    0x11 => 'MPEG-4 LATM AAC Audio',
    0x12 => 'MPEG-4 generic',
    0x13 => 'ISO 14496-1 SL-packetized',
    0x14 => 'ISO 13818-6 Synchronized Download Protocol',
    0x15 => 'Packetized metadata',
    0x16 => 'Sectioned metadata',
    0x17 => 'ISO/IEC 13818-6 DSM CC Data Carousel metadata',
    0x18 => 'ISO/IEC 13818-6 DSM CC Object Carousel metadata',
    0x19 => 'ISO/IEC 13818-6 Synchronized Download Protocol metadata',
    0x1a => 'ISO/IEC 13818-11 IPMP',
    0x1b => 'H.264 (AVC) Video',
    0x1c => 'ISO/IEC 14496-3 (MPEG-4 raw audio)',
    0x1d => 'ISO/IEC 14496-17 (MPEG-4 text)',
    0x1e => 'ISO/IEC 23002-3 (MPEG-4 auxiliary video)',
    0x1f => 'ISO/IEC 14496-10 SVC (MPEG-4 AVC sub-bitstream)',
    0x20 => 'ISO/IEC 14496-10 MVC (MPEG-4 AVC sub-bitstream)',
    0x21 => 'ITU-T Rec. T.800 and ISO/IEC 15444 (JPEG 2000 video)',
    0x24 => 'H.265 (HEVC) Video', #PH
    0x42 => 'Chinese Video Standard',
    0x7f => 'ISO/IEC 13818-11 IPMP (DRM)',
    0x80 => 'DigiCipher II Video',
    0x81 => 'A52/AC-3 Audio',
    0x82 => 'HDMV DTS Audio',
    0x83 => 'LPCM Audio',
    0x84 => 'SDDS Audio',
    0x85 => 'ATSC Program ID',
    0x86 => 'DTS-HD Audio',
    0x87 => 'E-AC-3 Audio',
    0x8a => 'DTS Audio',
    0x90 => 'Presentation Graphic Stream (subtitle)', #https://en.wikipedia.org/wiki/Program-specific_information
    0x91 => 'A52b/AC-3 Audio',
    0x92 => 'DVD_SPU vls Subtitle',
    0x94 => 'SDDS Audio',
    0xa0 => 'MSCODEC Video',
    0xea => 'Private ES (VC-1)',
  # 0x80-0xFF => 'User Private',
);

# "table_id" values (ref 5)
my %tableID = (
    0x00 => 'Program Association',
    0x01 => 'Conditional Access',
    0x02 => 'Program Map',
    0x03 => 'Transport Stream Description',
    0x40 => 'Actual Network Information',
    0x41 => 'Other Network Information',
    0x42 => 'Actual Service Description',
    0x46 => 'Other Service Description',
    0x4a => 'Bouquet Association',
    0x4e => 'Actual Event Information - Present/Following',
    0x4f => 'Other Event Information - Present/Following',
    0x50 => 'Actual Event Information - Schedule', #(also 0x51-0x5f)
    0x60 => 'Other Event Information - Schedule', # (also 0x61-0x6f)
    0x70 => 'Time/Date',
    0x71 => 'Running Status',
    0x72 => 'Stuffing',
    0x73 => 'Time Offset',
    0x7e => 'Discontinuity Information',
    0x7f => 'Selection Information',
  # 0x80-0xfe => 'User Defined',
);

# PES stream ID's for which a syntax field does not exist
my %noSyntax = (
    0xbc => 1, # program_stream_map
    0xbe => 1, # padding_stream
    0xbf => 1, # private_stream_2
    0xf0 => 1, # ECM_stream
    0xf1 => 1, # EMM_stream
    0xf2 => 1, # DSMCC_stream
    0xf8 => 1, # ITU-T Rec. H.222.1 type E stream
    0xff => 1, # program_stream_directory
);

my $knotsToKph = 1.852;     # knots --> km/h

# information extracted from the MPEG-2 transport stream
%Image::ExifTool::M2TS::Main = (
    GROUPS => { 2 => 'Video' },
    VARS => { ID_FMT => 'none' },
    NOTES => q{
        The MPEG-2 transport stream is used as a container for many different
        audio/video formats (including AVCHD).  This table lists information
        extracted from M2TS files.
    },
    VideoStreamType => {
        PrintHex => 1,
        PrintConv => \%streamType,
        SeparateTable => 'StreamType',
    },
    AudioStreamType => {
        PrintHex => 1,
        PrintConv => \%streamType,
        SeparateTable => 'StreamType',
    },
    Duration => {
        Notes => q{
            the -fast option may be used to avoid scanning to the end of file to
            calculate the Duration
        },
        ValueConv => '$val / 27000000', # (clock is 27MHz)
        PrintConv => 'ConvertDuration($val)',
    },
    # the following tags are for documentation purposes only
    _AC3  => { SubDirectory => { TagTable => 'Image::ExifTool::M2TS::AC3' } },
    _H264 => { SubDirectory => { TagTable => 'Image::ExifTool::H264::Main' } },
    _MISB => { SubDirectory => { TagTable => 'Image::ExifTool::MISB::Main' } },
);

# information extracted from AC-3 audio streams
%Image::ExifTool::M2TS::AC3 = (
    GROUPS => { 1 => 'AC3', 2 => 'Audio' },
    VARS => { ID_FMT => 'none' },
    NOTES => 'Tags extracted from AC-3 audio streams.',
    AudioSampleRate => {
        PrintConv => {
            0 => '48000',
            1 => '44100',
            2 => '32000',
        },
    },
    AudioBitrate => {
        PrintConvColumns => 2,
        ValueConv => {
            0 => 32000,
            1 => 40000,
            2 => 48000,
            3 => 56000,
            4 => 64000,
            5 => 80000,
            6 => 96000,
            7 => 112000,
            8 => 128000,
            9 => 160000,
            10 => 192000,
            11 => 224000,
            12 => 256000,
            13 => 320000,
            14 => 384000,
            15 => 448000,
            16 => 512000,
            17 => 576000,
            18 => 640000,
            32 => '32000 max',
            33 => '40000 max',
            34 => '48000 max',
            35 => '56000 max',
            36 => '64000 max',
            37 => '80000 max',
            38 => '96000 max',
            39 => '112000 max',
            40 => '128000 max',
            41 => '160000 max',
            42 => '192000 max',
            43 => '224000 max',
            44 => '256000 max',
            45 => '320000 max',
            46 => '384000 max',
            47 => '448000 max',
            48 => '512000 max',
            49 => '576000 max',
            50 => '640000 max',
        },
        PrintConv => 'ConvertBitrate($val)',
    },
    SurroundMode => {
        PrintConv => {
            0 => 'Not indicated',
            1 => 'Not Dolby surround',
            2 => 'Dolby surround',
        },
    },
    AudioChannels => {
        PrintConvColumns => 2,
        PrintConv => {
            0 => '1 + 1',
            1 => 1,
            2 => 2,
            3 => 3,
            4 => '2/1',
            5 => '3/1',
            6 => '2/2',
            7 => '3/2',
            8 => 1,
            9 => '2 max',
            10 => '3 max',
            11 => '4 max',
            12 => '5 max',
            13 => '6 max',
        },
    },
);

#------------------------------------------------------------------------------
# Extract information from AC-3 audio stream
# Inputs: 0) ExifTool ref, 1) data ref
# Reference: http://www.atsc.org/standards/a_52b.pdf
sub ParseAC3Audio($$)
{
    my ($et, $dataPt) = @_;
    if ($$dataPt =~ /\x0b\x77..(.)/sg) {
        my $sampleRate = ord($1) >> 6;
        my $tagTablePtr = GetTagTable('Image::ExifTool::M2TS::AC3');
        $et->HandleTag($tagTablePtr, AudioSampleRate => $sampleRate);
    }
}

#------------------------------------------------------------------------------
# Extract information from AC-3 stream descriptor
# Inputs: 0) ExifTool ref, 1) data ref
# Reference: http://www.atsc.org/standards/a_52b.pdf
# Note: This information is duplicated in the Audio stream, but it
#       is somewhat easier to extract it from the descriptor instead
sub ParseAC3Descriptor($$)
{
    my ($et, $dataPt) = @_;
    return if length $$dataPt < 3;
    my @v = unpack('C3', $$dataPt);
    my $tagTablePtr = GetTagTable('Image::ExifTool::M2TS::AC3');
    # $et->HandleTag($tagTablePtr, 'AudioSampleRate', $v[0] >> 5);
    $et->HandleTag($tagTablePtr, 'AudioBitrate', $v[1] >> 2);
    $et->HandleTag($tagTablePtr, 'SurroundMode', $v[1] & 0x03);
    $et->HandleTag($tagTablePtr, 'AudioChannels', ($v[2] >> 1) & 0x0f);
    # don't (yet) decode any more (language codes, etc)
}

#------------------------------------------------------------------------------
# Parse PID stream data
# Inputs: 0) ExifTool ref, 1) PID number, 2) PID type, 3) PID name, 4) data ref
# Returns: 0=stream parsed OK,
#          1=stream parsed but we want to parse more of these,
#          -1=can't parse yet because we don't know the type
sub ParsePID($$$$$)
{
    my ($et, $pid, $type, $pidName, $dataPt) = @_;
    # can't parse until we know the type (Program Map Table may be later in the stream)
    return -1 unless defined $type;
    my $verbose = $et->Options('Verbose');
    if ($verbose > 1) {
        my $out = $et->Options('TextOut');
        printf $out "Parsing stream 0x%.4x (%s) %d bytes\n", $pid, $pidName, length($$dataPt);
        $et->VerboseDump($dataPt);
    }
    my $more = 0;
    if ($type == 0x01 or $type == 0x02) {
        # MPEG-1/MPEG-2 Video
        require Image::ExifTool::MPEG;
        Image::ExifTool::MPEG::ParseMPEGAudioVideo($et, $dataPt);
    } elsif ($type == 0x03 or $type == 0x04) {
        # MPEG-1/MPEG-2 Audio
        require Image::ExifTool::MPEG;
        Image::ExifTool::MPEG::ParseMPEGAudio($et, $dataPt);
    } elsif ($type == 6 and $pid == 0x0300) {
        # LIGOGPSINFO from unknown dashcam (../testpics/gps_video/Wrong Way pass.ts)
        if ($$dataPt =~ /^LIGOGPSINFO/s) {
            my $tbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
            my %dirInfo = ( DataPt => $dataPt, DirName => 'Ligo0x0300' );
            Image::ExifTool::LigoGPS::ProcessLigoGPS($et, \%dirInfo, $tbl, 1);
            $$et{FoundGoodGPS} = 1;
            $more = 1;
        }
    } elsif ($type == 0x1b) {
        # H.264 Video
        require Image::ExifTool::H264;
        $more = Image::ExifTool::H264::ParseH264Video($et, $dataPt);
        # force parsing additional H264 frames with ExtractEmbedded option
        if ($$et{OPTIONS}{ExtractEmbedded}) {
            $more = 1;
        } elsif (not $$et{OPTIONS}{Validate}) {
            $et->Warn('The ExtractEmbedded option may find more tags in the video data',7);
        }
    } elsif ($type == 0x81 or $type == 0x87 or $type == 0x91) {
        # AC-3 audio
        ParseAC3Audio($et, $dataPt);
    } elsif ($type == 0x15) {
        # packetized metadata (look for MISB code starting after 5-byte header)
        if ($$dataPt =~ /^.{5}\x06\x0e\x2b\x34/s) {
            $more = Image::ExifTool::MISB::ParseMISB($et, $dataPt, GetTagTable('Image::ExifTool::MISB::Main'));
            if (not $$et{OPTIONS}{ExtractEmbedded}) {
                $more = 0;  # extract from only the first packet unless ExtractEmbedded is used
            } elsif ($$et{OPTIONS}{ExtractEmbedded} > 2) {
                $more = 1;  # read past unknown 0x15 packets if ExtractEmbedded > 2
            }
        }
# still have a lot of questions about how to decode this...
# (see https://exiftool.org/forum/index.php?topic=16486 and ../testpics/gps_video/forum16486.ts)
#    } elsif ($type == 6) {
#        my @a = unpack('x17x2NNx2nx2nx2nx2Cx2a4x2a5x2Nx2Nx2nx2Nx2Nx2Nx2nx2nx2Nx2nx2n', $$dataPt . "        ");
#        my $hi = shift @a;
#        $a[0] = Image::ExifTool::ConvertUnixTime(($a[0] + $hi * 4294967296) * 1e-6, undef, 6);
#        print "@a\n";
#        $more = 1;
    } elsif ($type < 0) {
        if ($$dataPt =~ /^(.{164})?(.{24})A[NS][EW]/s) {
            # (Blueskysea B4K, Novatek NT96670)
            # 0000: 01 00 ff 00 30 31 32 33 34 35 37 38 61 62 63 64 [....01234578abcd]
            # 0010: 65 66 67 0a 00 00 00 00 00 00 00 00 00 00 00 00 [efg.............]
            # 0020: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
            # 0030: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
            # 0040: 00 00 00 00 30 31 32 33 34 35 37 38 71 77 65 72 [....01234578qwer]
            # 0050: 74 79 75 69 6f 70 0a 00 00 00 00 00 00 00 00 00 [tyuiop..........]
            # 0060: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
            # 0070: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 [................]
            # 0080: 00 00 00 00 63 38 61 61 32 35 63 66 34 35 65 65 [....c8aa25cf45ee]
            # 0090: 61 39 65 32 34 34 32 66 61 65 62 35 65 30 39 39 [a9e2442faeb5e099]
            # 00a0: 30 37 64 34 15 00 00 00 10 00 00 00 1b 00 00 00 [07d4............]
            # 00b0: 15 00 00 00 01 00 00 00 09 00 00 00 41 4e 57 00 [............ANW.]
            # 00c0: 82 9a 57 45 98 b2 00 46 66 66 e4 41 d7 e3 14 43 [..WE...Fff.A...C]
            # 00d0: 01 00 02 00 03 00 04 00 05 00 06 00             [............]
            # (Viofo A119V3)
            # 0000: 08 00 00 00 07 00 00 00 18 00 00 00 15 00 00 00 [................]
            # 0010: 03 00 00 00 0b 00 00 00 41 4e 45 00 01 f2 ac 45 [........ANE....E]
            # 0020: 2d 7f 6e 45 b8 1e 97 41 d7 23 46 43 00 00 00 00 [-.nE...A.#FC....]
            # pad with dummy header and parse with existing FreeGPS code (minimum 92 bytes)
            my $dat = ("\0" x 16) . substr($$dataPt, length($1 || '')) . ("\0" x 20);
            my $tbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
            Image::ExifTool::QuickTime::ProcessFreeGPS($et, { DataPt => \$dat }, $tbl);
            $more = 1;
        } elsif ($$dataPt =~ /^(V00|A([NS])([EW]))\0/s) {
            # INNOVV TS video (same format as INNOVV MP4)
            SetByteOrder('II');
            my $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
            while ($$dataPt =~ /((V00|A[NS][EW])\0.{28})/g) {
                my $dat = $1;
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                if ($2 ne 'V00') {
                    my $lat = abs(GetFloat(\$dat, 4)); # (abs just to be safe)
                    my $lon = abs(GetFloat(\$dat, 8)); # (abs just to be safe)
                    my $spd = GetFloat(\$dat, 12) * $knotsToKph;
                    my $trk = GetFloat(\$dat, 16);
                    Image::ExifTool::QuickTime::ConvertLatLon($lat, $lon);
                    $et->HandleTag($tagTbl, GPSLatitude  => abs($lat) * (substr($dat,1,1) eq 'S' ? -1 : 1));
                    $et->HandleTag($tagTbl, GPSLongitude => abs($lon) * (substr($dat,2,1) eq 'W' ? -1 : 1));
                    $et->HandleTag($tagTbl, GPSSpeed     => $spd);
                    $et->HandleTag($tagTbl, GPSSpeedRef  => 'K');
                    $et->HandleTag($tagTbl, GPSTrack     => $trk);
                    $et->HandleTag($tagTbl, GPSTrackRef  => 'T');
                }
                my @acc = unpack('x20V3', $dat);
                map { $_ = $_ - 4294967296 if $_ >= 0x80000000 } @acc;
                $et->HandleTag($tagTbl, Accelerometer => "@acc");
            }
            SetByteOrder('MM');
            $$et{FoundGoodGPS} = 1; # (necessary to skip over empty/unknown INNOV records)
            $more = 1;
        } elsif ($$dataPt =~ /^\$(GPSINFO|GSNRINFO),/) {
            # $GPSINFO,0x0004,2021.08.09 13:27:36,2341.54561,12031.70135,8.0,51,153,0,0,\x0d
            # $GSNRINFO,0.01,0.04,0.25\0
            $$dataPt =~ tr/\x0d/\x0a/;
            $$dataPt =~ tr/\0//d;
            my $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
            my @lines = split /\x0a/, $$dataPt;
            my ($line, $lastTime);
            foreach $line (@lines) {
                if ($line =~ /^\$GPSINFO/) {
                    my @a = split /,/, $lines[0];
                    next unless @a > 7;
                    # ignore duplicate fixes
                    next if $lastTime and $a[2] eq $lastTime;
                    $lastTime = $a[2];
                    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                    $a[2] =~ tr/./:/;
                    # (untested, and probably doesn't work for S/W hemispheres)
                    my ($lat, $lon) = @a[3,4];
                    Image::ExifTool::QuickTime::ConvertLatLon($lat, $lon);
                    # $a[0] - flags? values: '0x0001','0x0004','0x0008','0x0010'
                    $et->HandleTag($tagTbl, GPSDateTime  => $a[2]);
                    $et->HandleTag($tagTbl, GPSLatitude  => $lat);
                    $et->HandleTag($tagTbl, GPSLongitude => $lon);
                    $et->HandleTag($tagTbl, GPSSpeed     => $a[5]);
                    $et->HandleTag($tagTbl, GPSSpeedRef  => 'K');
                    # $a[6] - values: 48-60
                    $et->HandleTag($tagTbl, GPSTrack     => $a[7]);
                    $et->HandleTag($tagTbl, GPSTrackRef  => 'T');
                    # #a[8,9] - always 0
                } elsif ($line =~ /^\$GSNRINFO/) {
                    my @a = split /,/, $line;
                    shift @a;
                    $et->HandleTag($tagTbl, Accelerometer => "@a");
                }
            }
            $more = 1;
        } elsif ($$dataPt =~ /\$GPRMC,/) {
            # Jomise T860S-GM dashcam
            # $GPRMC,hhmmss.ss,A,ddmm.mmmmm,N,dddmm.mmmmm,W,spd-kts,dir-dg,DDMMYY,,M*cs - lat,lon,spd from video
            # $GPRMC,172255.00,A,:985.95194,N,17170.14674,W,029.678,170.68,240822,,,D*7B - N47.70428,W122.15338,35mph
            # $GPRMC,192643.00,A,:987.94979,N,17171.07268,W,010.059,079.61,111122,,,A*73 - N47.71862,W122.16437,12mph
            # $GPRMC,192743.00,A,:988.72110,N,17171.04873,W,017.477,001.03,111122,,,A*78 - N47.72421,W122.16408,20mph
            # $GPRMC,192844.00,A,:989.43771,N,17171.03538,W,016.889,001.20,111122,,,A*7B - N47.72932,W122.16393,19mph
            # $GPRMC,005241.00,A,:987.70873,N,17171.81293,W,000.284,354.78,141122,,,A*7F - N47.71687,W122.17318,0mph
            # $GPRMC,005341.00,A,:987.90851,N,17171.85380,W,000.080,349.36,141122,,,A*7C - N47.71832,W122.17367,0mph
            # $GPRMC,005441.00,A,:987.94538,N,17171.21783,W,029.686,091.09,141122,,,A*7A - N47.71859,W122.16630,35mph
            # $GPRMC,002816.00,A,6820.67273,N,13424.26599,W,000.045,000.00,261122,,,A*79 - N29.52096,W95.55953,0mph (seattle)
            # $GPRMC,035136.00,A,:981.47322,N,17170.14105,W,024.594,180.50,291122,,,D*79 - N47.67180,W122.15328,28mph
            my $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
            while ($$dataPt =~ /\$[A-Z]{2}RMC,(\d{2})(\d{2})(\d+(\.\d*)?),A?,(.{2})(\d{2}\.\d+),([NS]),(.{3})(\d{2}\.\d+),([EW]),(\d*\.?\d*),(\d*\.?\d*),(\d{2})(\d{2})(\d+)/g and
                # do some basic sanity checks on the date
                $13 <= 31 and $14 <= 12 and $15 <= 99)
            {
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                my $year = $15 + ($15 >= 70 ? 1900 : 2000);
                $et->HandleTag($tagTbl, GPSDateTime => sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2dZ', $year, $14, $13, $1, $2, $3));
                #(not this simple)
                #$et->HandleTag($tagTbl, GPSLatitude => (($5 || 0) + $6/60) * ($7 eq 'N' ? 1 : -1));
                #$et->HandleTag($tagTbl, GPSLongitude => (($8 || 0) + $9/60) * ($10 eq 'E' ? 1 : -1));
                $et->HandleTag($tagTbl, GPSSpeed => $11 * $knotsToKph) if length $11;
                $et->HandleTag($tagTbl, GPSTrack => $12) if length $12;
                # it looks like maybe the degrees are xor-ed with something,
                # and the minutes have some scaling factor and offset?
                # (the code below is approximately correct for my only sample)
                my @chars = unpack('C*', $5 . $8);
                my @xor = (0x0e,0x0e,0x00,0x05,0x03); # (empirical based on 1 sample; may be completely off base)
                my $bad;
                foreach (@chars) {
                    $_ ^= shift(@xor);
                    $bad = 1 if $_ < 0x30 or $_ > 0x39;
                }
                if ($bad) {
                    $et->Warn('Error decrypting GPS degrees');
                } else {
                    my $la = pack('C*', @chars[0,1]);
                    my $lo = pack('C*', @chars[2,3,4]);
                    $et->Warn('Decryption of this GPS is highly experimental. More testing samples are required');
                    $et->HandleTag($tagTbl, GPSLatitude  => (($la || 0) + (($6-85.95194)/2.43051724137931+42.2568)/60) * ($7 eq 'N' ? 1 : -1));
                    $et->HandleTag($tagTbl, GPSLongitude => (($lo || 0) + (($9-70.14674)/1.460987654320988+9.2028)/60) * ($10 eq 'E' ? 1 : -1));
                }
            }
        } elsif ($$dataPt =~ /\$GSENSORD,\s*(\d+),\s*(\d+),\s*(\d+),/) {
            # Jomise T860S-GM dashcam
            my $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
            $$et{DOC_NUM} = $$et{DOC_COUNT};
            $et->HandleTag($tagTbl, Accelerometer => "$1 $2 $3"); # (NC - values range from 0 to 6)
        } elsif ($$dataPt =~ /^.{44}A\0{3}.{4}([NS])\0{3}.{4}([EW])\0{3}/s and length($$dataPt) >= 84) {
            #forum11320
            SetByteOrder('II');
            my $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
            my $lat = abs(GetFloat($dataPt, 48)); # (abs just to be safe)
            my $lon = abs(GetFloat($dataPt, 56)); # (abs just to be safe)
            my $spd = GetFloat($dataPt, 64);
            my $trk = GetFloat($dataPt, 68);
            $et->Warn('GPSLatitude/Longitude encryption is not yet known, so these will be wrong');
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};
            my @date = unpack('x32V3x28V3', $$dataPt);
            $date[3] += 2000;
            $et->HandleTag($tagTbl, GPSDateTime  => sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d', @date[3..5,0..2]));
            $et->HandleTag($tagTbl, GPSLatitude  => abs($lat) * ($1 eq 'S' ? -1 : 1));
            $et->HandleTag($tagTbl, GPSLongitude => abs($lon) * ($2 eq 'W' ? -1 : 1));
            $et->HandleTag($tagTbl, GPSSpeed     => $spd);
            $et->HandleTag($tagTbl, GPSSpeedRef  => 'K');
            $et->HandleTag($tagTbl, GPSTrack     => $trk);
            $et->HandleTag($tagTbl, GPSTrackRef  => 'T');
            SetByteOrder('MM');
            $more = 1;
        } elsif (length($$dataPt) >= 64 and substr($$dataPt, 32, 2) eq '$S') {
            # DOD_LS600W.TS
            my $tagTbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
            # find the earliest sample time in the cyclical list
            my ($n, $last) = (32, "\0");
            for (my $i=32; $i<length($$dataPt)-32; $i+=32) {
                last unless substr($$dataPt, $n, 2) eq '$S';
                my $dateTime = substr($$dataPt, $i+6, 8);
                $last gt $dateTime and $n = $i, last;  # earliest sample if time goes backwards
                $last = $dateTime;
            }
            for (my $i=32; $i<length($$dataPt)-32; $i+=32, $n+=32) {
                $n = 32 if $n > length($$dataPt)-32;
                last unless substr($$dataPt, $n, 2) eq '$S';
                my @a = unpack("x${n}nnnnCCCCnCNNC", $$dataPt);
                $a[8] /= 10;    # 1/10 sec
                $a[2] += (36000 - 65536) if $a[2] & 0x8000; # convert signed integer into range 0-36000
                $$et{DOC_NUM} = ++$$et{DOC_COUNT};
                $et->HandleTag($tagTbl, GPSDateTime  => sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%04.1fZ', @a[3..8]));
                $et->HandleTag($tagTbl, GPSLatitude  => $a[10] * 1e-7);
                $et->HandleTag($tagTbl, GPSLongitude => $a[11] * 1e-7);
                $et->HandleTag($tagTbl, GPSSpeed     => $a[1] * 0.036); # convert from metres per 100 s
                $et->HandleTag($tagTbl, GPSTrack     => $a[2] / 100);
            }
            # Note: 10 bytes after last GPS record look like a single 3-axis accelerometer reading:
            # eg. fd ff 00 00 ff ff 00 00 01 00
            $$et{FoundGoodGPS} = 1; # so we skip over unrecognized packets
            $more = 1;
        } elsif ($$dataPt =~ /^skip.{4}LIGOGPSINFO\0/s) {
            # (this record contains 2 copies of the same 'skip' atom in my sample --
            #  only extract data from the first one)
            my $tbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
            my %dirInfo = ( DataPt => $dataPt, DirStart => 8, DirName => sprintf('Ligo0x%.4x',$pid));
            Image::ExifTool::LigoGPS::ProcessLigoGPS($et, \%dirInfo, $tbl, 1);
            $$et{FoundGoodGPS} = 1;
        } elsif ($$et{FoundGoodGPS}) {
            $more = 1;
        }
        delete $$et{DOC_NUM};
    }
    return $more;
}

#------------------------------------------------------------------------------
# Extract information from a M2TS file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid M2TS file
sub ProcessM2TS($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $j, $eof, $pLen, $readSize);
    my (%pmt, %pidType, %data, %sectLen, %packLen, %fromStart);
    my ($startTime, $endTime, $fwdTime, $backScan, $maxBack);
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');

    # read enough to guarantee 2 sync bytes
    return 0 unless $raf->Read($buff, 383) == 383;
    # test for magic number (sync byte is the only thing we can safely check)
    return 0 unless $buff =~ /^(.{0,190}?)\x47(.{187}|.{191})\x47/s;
    my $tcLen = length($2) - 187; # (length of timecode = 0 or 4 bytes)
    my $start = length($1) - $tcLen;
    # we may need to try the validation twice to handle the edge case
    # where the first byte of a timecode is 0x47 and we were fooled
    # into thinking there was no timecode
Try: for (;;) {
        $start += 192 if $start < 0; # (if all or part of first timecode was missing)
        $pLen = 188 + $tcLen;
        $readSize = 64 * $pLen;      # size of our read buffer
        $raf->Seek($start, 0);       # rewind to start
        $raf->Read($buff, $readSize) >= $pLen * 4 or return 0;  # require at least 4 packets
        # validate the sync byte in the next 3 packets
        for ($j=1; $j<4; ++$j) {
            next if substr($buff, $tcLen + $pLen * $j, 1) eq 'G'; # (0x47)
            return 0 if $tcLen;
            $tcLen = 4;
            $start -= 4;
            next Try;
        }
        last;   # success!
    }
    # (use M2T instead of M2TS just as an indicator that there is no timecode)
    $et->SetFileType($tcLen ? 'M2TS' : 'M2T');
    $et->Warn("File doesn't begin with the start of a packet") if $start;
    SetByteOrder('MM');
    my $tagTablePtr = GetTagTable('Image::ExifTool::M2TS::Main');

    # PID lookup strings (will add to this with entries from program map table)
    my %pidName = (
        0 => 'Program Association Table',
        1 => 'Conditional Access Table',
        2 => 'Transport Stream Description Table',
        0x1fff => 'Null Packet',
    );
    my %didPID = ( 1 => 0, 2 => 0, 0x1fff => 0 );
    my %needPID = ( 0 => 1 );       # lookup for stream PID's that we still need to parse
    # PID's that may contain GPS info
    my %gpsPID = (
        0x0300 => 1,    # Novatek INNOVV, DOD_LS600W
        0x01e4 => 1,    # vsys a6l dashcam
        0x0e1b => 1,    # Jomise T860S-GM dashcam GPS
        0x0e1a => 1,    # Jomise T860S-GM dashcam accelerometer
    );
    my $pEnd = 0;

    # scan entire file for GPS programs if ExtractEmbedded option is 3 or higher
    # (some dashcams write these programs but don't include it in the PMT)
    if (($et->Options('ExtractEmbedded') || 0) > 2) {
        foreach (keys %gpsPID) {
            $needPID{$_} = 1;
            $pidType{$_} = -1;
            $pidName{$_} ='unregistered dashcam GPS';
        }
    }

    # parse packets from MPEG-2 Transport Stream
    for (;;) {

        unless (%needPID) {
            last unless defined $startTime;
            # reconfigure to seek backwards for last PCR
            unless (defined $backScan) {
                my $saveTime = $endTime;
                undef $endTime;
                last if $et->Options('FastScan');
                $verbose and print $out "[Starting backscan for last PCR]\n";
                # remember how far we got when reading forward through the file
                my $fwdPos = $raf->Tell() - length($buff) + $pEnd;
                # determine the position of the last packet relative to the EOF
                $raf->Seek(0, 2) or last;
                my $fsize = $raf->Tell();
                $backScan = int($fsize / $pLen) * $pLen - $fsize;
                # set limit on how far back we will go
                $maxBack = $fwdPos - $fsize;
                # scan back a maximum of 512k (have seen last PCR at -276k)
                my $nMax = int(512000 / $pLen);     # max packets to backscan
                if ($nMax < int(-$maxBack / $pLen)) {
                    $maxBack = $backScan - $nMax * $pLen;
                } else {
                    # use this time if none found in all remaining packets
                    $fwdTime = $saveTime;
                }
                $pEnd = 0;
            }
        }
        my $pos;
        # read more if necessary
        if (defined $backScan) {
            last if defined $endTime;
            $pos = $pEnd = $pEnd - 2 * $pLen;   # step back to previous packet
            if ($pos < 0) {
                # read another buffer from end of file
                last if $backScan <= $maxBack;
                my $buffLen = $backScan - $maxBack;
                $buffLen = $readSize if $buffLen > $readSize;
                $backScan -= $buffLen;
                $raf->Seek($backScan, 2) or last;
                $raf->Read($buff, $buffLen) == $buffLen or last;
                $pos = $pEnd = $buffLen - $pLen;
            }
        } else {
            $pos = $pEnd;
            if ($pos + $pLen > length $buff) {
                $raf->Read($buff, $readSize) >= $pLen or $eof = 1, last;
                $pos = $pEnd = 0;
            }
        }
        $pEnd += $pLen;
        # decode the packet prefix
        $pos += $tcLen;
        my $prefix = unpack("x${pos}N", $buff); # (use unpack instead of Get32u for speed)
        # validate sync byte
        unless (($prefix & 0xff000000) == 0x47000000) {
            $et->Warn('M2TS synchronization error') unless defined $backScan;
            last;
        }
      # my $transport_error_indicator    = $prefix & 0x00800000;
        my $payload_unit_start_indicator = $prefix & 0x00400000;
      # my $transport_priority           = $prefix & 0x00200000;
        my $pid                          =($prefix & 0x001fff00) >> 8; # packet ID
      # my $transport_scrambling_control = $prefix & 0x000000c0;
        my $adaptation_field_exists      = $prefix & 0x00000020;
        my $payload_data_exists          = $prefix & 0x00000010;
      # my $continuity_counter           = $prefix & 0x0000000f;
        if ($verbose > 1) {
            my $i = ($raf->Tell() - length($buff) + $pEnd) / $pLen - 1;
            print  $out "Transport packet $i:\n";
            $et->VerboseDump(\$buff, Len => $pLen, Addr => $i * $pLen, Start => $pos - $tcLen);
            my $str = $pidName{$pid} ? " ($pidName{$pid})" : ' <not in Program Map Table!>';
            printf $out "  Timecode:   0x%.4x\n", Get32u(\$buff, $pos - $tcLen) if $pLen == 192;
            printf $out "  Packet ID:  0x%.4x$str\n", $pid;
            printf $out "  Start Flag: %s\n", $payload_unit_start_indicator ? 'Yes' : 'No';
        }

        $pos += 4;
        # handle adaptation field
        if ($adaptation_field_exists) {
            my $len = Get8u(\$buff, $pos++);
            $pos + $len > $pEnd and $et->Warn('Invalid adaptation field length'), last;
            # read PCR value for calculation of Duration
            if ($len > 6) {
                my $flags = Get8u(\$buff, $pos);
                if ($flags & 0x10) { # PCR_flag
                    # combine 33-bit program_clock_reference_base and 9-bit extension
                    my $pcrBase = Get32u(\$buff, $pos + 1);
                    my $pcrExt  = Get16u(\$buff, $pos + 5);
                    # ignore separate programs (PID's) and store just the
                    # first and last timestamps found in the file (is this OK?)
                    $endTime = 300 * (2 * $pcrBase + ($pcrExt >> 15)) + ($pcrExt & 0x01ff);
                    $startTime = $endTime unless defined $startTime;
                }
            }
            $pos += $len;
        }

        # all done with this packet unless it carries a payload
        # or if we are just looking for the last timestamp
        next unless $payload_data_exists and not defined $backScan;

       # decode payload data
        if ($pid == 0 or            # program association table
            defined $pmt{$pid})     # program map table(s)
        {
            # must interpret pointer field if payload_unit_start_indicator is set
            my $buf2;
            if ($payload_unit_start_indicator) {
                # skip to start of section
                my $pointer_field = Get8u(\$buff, $pos);
                $pos += 1 + $pointer_field;
                $pos >= $pEnd and $et->Warn('Bad pointer field'), last;
                $buf2 = substr($buff, $pEnd-$pLen, $pLen);
                $pos -= $pEnd - $pLen;
            } else {
                # not the start of a section
                next unless $sectLen{$pid};
                my $more = $sectLen{$pid} - length($data{$pid});
                my $size = $pLen - $pos;
                $size = $more if $size > $more;
                $data{$pid} .= substr($buff, $pos, $size);
                next unless $size == $more;
                # we have the complete section now, so put into $buf2 for parsing
                $buf2 = $data{$pid};
                $pos = 0;
                delete $data{$pid};
                delete $fromStart{$pid};
                delete $sectLen{$pid};
            }
            my $slen = length($buf2);   # section length
            $pos + 8 > $slen and $et->Warn('Truncated payload'), last;
            # validate table ID
            my $table_id = Get8u(\$buf2, $pos);
            my $name = ($tableID{$table_id} || sprintf('Unknown (0x%x)',$table_id)) . ' Table';
            my $expectedID = $pid ? 0x02 : 0x00;
            unless ($table_id == $expectedID) {
                $verbose > 1 and print $out "  (skipping $name)\n";
                delete $needPID{$pid};
                $didPID{$pid} = 1;
                next;
            }
            # validate section syntax indicator for parsed tables (PAT, PMT)
            my $section_syntax_indicator = Get8u(\$buf2, $pos + 1) & 0xc0;
            $section_syntax_indicator == 0x80 or $et->Warn("Bad $name"), last;
            my $section_length = Get16u(\$buf2, $pos + 1) & 0x0fff;
            $section_length > 1021 and $et->Warn("Invalid $name length"), last;
            if ($slen < $section_length + 3) { # (3 bytes for table_id + section_length)
                # must wait until we have the full section
                $data{$pid} = substr($buf2, $pos);
                $sectLen{$pid} = $section_length + 3;
                next;
            }
            my $program_number = Get16u(\$buf2, $pos + 3);
            my $section_number = Get8u(\$buf2, $pos + 6);
            my $last_section_number = Get8u(\$buf2, $pos + 7);
            if ($verbose > 1) {
                print  $out "  $name length: $section_length\n";
                print  $out "  Program No: $program_number\n" if $pid;
                printf $out "  Stream ID:  0x%x\n", $program_number if not $pid;
                print  $out "  Section No: $section_number\n";
                print  $out "  Last Sect.: $last_section_number\n";
            }
            my $end = $pos + $section_length + 3 - 4; # (don't read 4-byte CRC)
            $pos += 8;
            if ($pid == 0) {
                # decode PAT (Program Association Table)
                while ($pos <= $end - 4) {
                    my $program_number = Get16u(\$buf2, $pos);
                    my $program_map_PID = Get16u(\$buf2, $pos + 2) & 0x1fff;
                    $pmt{$program_map_PID} = $program_number; # save our PMT PID's
                    my $str = "Program $program_number Map";
                    $pidName{$program_map_PID} = $str;
                    $needPID{$program_map_PID} = 1 unless $didPID{$program_map_PID};
                    $verbose and printf $out "  PID(0x%.4x) --> $str\n", $program_map_PID;
                    $pos += 4;
                }
            } else {
                # decode PMT (Program Map Table)
                $pos + 4 > $slen and $et->Warn('Truncated PMT'), last;
                my $pcr_pid = Get16u(\$buf2, $pos) & 0x1fff;
                my $program_info_length = Get16u(\$buf2, $pos + 2) & 0x0fff;
                my $str = "Program $program_number Clock Reference";
                $pidName{$pcr_pid} = $str;
                $verbose and printf $out "  PID(0x%.4x) --> $str\n", $pcr_pid;
                $pos += 4;
                $pos + $program_info_length > $slen and $et->Warn('Truncated program info'), last;
                # dump program information descriptors if verbose
                if ($verbose > 1) { for ($j=0; $j<$program_info_length-2; ) {
                    my $descriptor_tag = Get8u(\$buf2, $pos + $j);
                    my $descriptor_length = Get8u(\$buf2, $pos + $j + 1);
                    $j += 2;
                    last if $j + $descriptor_length > $program_info_length;
                    my $desc = substr($buf2, $pos+$j, $descriptor_length);
                    $j += $descriptor_length;
                    $desc =~ s/([\x00-\x1f\x7f-\xff])/sprintf("\\x%.2x",ord $1)/eg;
                    printf $out "    Program Descriptor: Type=0x%.2x \"$desc\"\n", $descriptor_tag;
                }}
                $pos += $program_info_length; # skip descriptors (for now)
                while ($pos <= $end - 5) {
                    my $stream_type = Get8u(\$buf2, $pos);
                    my $elementary_pid = Get16u(\$buf2, $pos + 1) & 0x1fff;
                    my $es_info_length = Get16u(\$buf2, $pos + 3) & 0x0fff;
                    my $str = $streamType{$stream_type};
                    $str or $str = ($stream_type < 0x7f ? 'Reserved' : 'Private');
                    $str = sprintf('%s (0x%.2x)', $str, $stream_type);
                    $str = "Program $program_number $str";
                    $verbose and printf $out "  PID(0x%.4x) --> $str\n", $elementary_pid;
                    if ($str =~ /(Audio|Video)/) {
                        unless ($pidName{$elementary_pid}) {
                            $et->HandleTag($tagTablePtr, $1 . 'StreamType', $stream_type)
                        }
                        # we want to parse all Audio and Video streams
                        $needPID{$elementary_pid} = 1 unless $didPID{$elementary_pid};
                    }
                    # save PID type and name string
                    $pidName{$elementary_pid} = $str;
                    $pidType{$elementary_pid} = $stream_type;
                    $pos += 5;
                    $pos + $es_info_length > $slen and $et->Warn('Truncated ES info'), $pos = $end, last;
                    # parse elementary stream descriptors
                    for ($j=0; $j<$es_info_length-2; ) {
                        my $descriptor_tag = Get8u(\$buf2, $pos + $j);
                        my $descriptor_length = Get8u(\$buf2, $pos + $j + 1);
                        $j += 2;
                        last if $j + $descriptor_length > $es_info_length;
                        my $desc = substr($buf2, $pos+$j, $descriptor_length);
                        $j += $descriptor_length;
                        if ($verbose > 1) {
                            my $dstr = $desc;
                            $dstr =~ s/([\x00-\x1f\x7f-\xff])/sprintf("\\x%.2x",ord $1)/eg;
                            printf $out "    ES Descriptor: Type=0x%.2x \"$dstr\"\n", $descriptor_tag;
                        }
                        # parse type-specific descriptor information (once)
                        unless ($didPID{$pid}) {
                            if ($descriptor_tag == 0x81) {  # AC-3
                                ParseAC3Descriptor($et, \$desc);
                            }
                        }
                    }
                    $pos += $es_info_length;
                }
            }
            # $pos = $end + 4; # skip CRC

        } elsif (not defined $didPID{$pid}) {

            # save data from the start of each elementary stream
            if ($payload_unit_start_indicator) {
                if (defined $data{$pid}) {
                    # we must have a whole section, so parse now
                    my $more = ParsePID($et, $pid, $pidType{$pid}, $pidName{$pid}, \$data{$pid});
                    # start fresh even if we couldn't process this PID yet
                    delete $data{$pid};
                    delete $fromStart{$pid};
                    unless ($more) {
                        delete $needPID{$pid};
                        $didPID{$pid} = 1;
                        next;
                    }
                    # set flag indicating we found this PID but we still want more
                    $needPID{$pid} = -1;
                }
                # check for a PES header
                next if $pos + 6 > $pEnd;
                my $start_code = Get32u(\$buff, $pos);
                next unless ($start_code & 0xffffff00) == 0x00000100;
                my $stream_id = $start_code & 0xff;
                my $pes_packet_length = Get16u(\$buff, $pos + 4);
                if ($verbose > 1) {
                    printf $out "  Stream ID:  0x%.2x\n", $stream_id;
                    print  $out "  Packet Len: $pes_packet_length\n";
                }
                $pos += 6;
                unless ($noSyntax{$stream_id}) {
                    next if $pos + 3 > $pEnd;
                    # validate PES syntax
                    my $syntax = Get8u(\$buff, $pos) & 0xc0;
                    $syntax == 0x80 or $et->Warn('Bad PES syntax'), next;
                    # skip PES header
                    my $pes_header_data_length = Get8u(\$buff, $pos + 2);
                    $pos += 3 + $pes_header_data_length;
                    next if $pos >= $pEnd;
                }
                $data{$pid} = substr($buff, $pos, $pEnd-$pos);
                # set flag that we read this payload from the start
                $fromStart{$pid} = 1;
                # save the packet length
                if ($pes_packet_length > 8) {
                    $packLen{$pid} = $pes_packet_length - 8; # (where are the 8 extra bytes? - PH)
                } else {
                    delete $packLen{$pid};
                }
            } else {
                unless (defined $data{$pid}) {
                    # (vsys a6l dashcam GPS record doesn't have a start indicator)
                    next unless $gpsPID{$pid};
                    $data{$pid} = '';
                }
                # accumulate data for each elementary stream
                $data{$pid} .= substr($buff, $pos, $pEnd-$pos);
            }
            # save only the first 256 bytes of most streams, except for
            # unknown, H.264 or metadata streams where we save up to 1 kB
            my $saveLen;
            if (not $pidType{$pid} or $pidType{$pid} == 0x1b) {
                $saveLen = 1024;
            } elsif ($pidType{$pid} == 0x15) {
                # use 1024 or actual size of metadata packet if smaller
                $saveLen = 1024;
                $saveLen = $packLen{$pid} if defined $packLen{$pid} and $saveLen > $packLen{$pid};
            } else {
                $saveLen = 256;
            }
            if (length($data{$pid}) >= $saveLen) {
                my $more = ParsePID($et, $pid, $pidType{$pid}, $pidName{$pid}, \$data{$pid});
                next if $more < 0;  # wait for program map table (hopefully not too long)
                # don't stop parsing if we weren't successful and may have missed the start
                $more = 1 if not $more and not $fromStart{$pid};
                delete $data{$pid};
                delete $fromStart{$pid};
                $more and $needPID{$pid} = -1, next; # parse more of these
                delete $needPID{$pid};
                $didPID{$pid} = 1;
            }
            next;
        }
        if ($needPID{$pid}) {
            # we found and parsed a section with this PID, so
            # delete from the lookup of PID's we still need to parse
            delete $needPID{$pid};
            $didPID{$pid} = 1;
        }
    }

    # calculate Duration if available
    $endTime = $fwdTime unless defined $endTime;
    if (defined $startTime and defined $endTime) {
        $endTime += 0x80000000 * 1200 if $startTime > $endTime; # handle 33-bit wrap
        $et->HandleTag($tagTablePtr, 'Duration', $endTime - $startTime);
    }

    if ($verbose) {
        my @need;
        foreach (keys %needPID) {
            push @need, sprintf('0x%.2x',$_) if $needPID{$_} > 0;
        }
        if (@need) {
            @need = sort @need;
            print $out "End of file.  Missing PID(s): @need\n";
        } else {
            my $what = $eof ? 'of file' : 'scan';
            print $out "End $what.  All PID's parsed.\n";
        }
    }

    # parse any remaining partial PID streams
    my $pid;
    foreach $pid (sort keys %data) {
        ParsePID($et, $pid, $pidType{$pid}, $pidName{$pid}, \$data{$pid});
        delete $data{$pid};
    }

    # look for LIGOGPSINFO trailer
    if ($et->Options('ExtractEmbedded') and
        $raf->Seek(-8, 2) and $raf->Read($buff, 8) == 8 and
        $buff =~ /^&&&&/)
    {
        my $len = unpack('x4N', $buff);
        if ($len < $raf->Tell() and $raf->Seek(-$len, 2) and $raf->Read($buff,$len) == $len) {
            my $tbl = GetTagTable('Image::ExifTool::QuickTime::Stream');
            my %dirInfo = ( DataPt => \$buff, DirStart => 8, DirName => 'LigoTrailer' );
            Image::ExifTool::LigoGPS::ProcessLigoGPS($et, \%dirInfo, $tbl);
        }
    }

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::M2TS - Read M2TS (AVCHD) meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
information from MPEG-2 transport streams, such as those used by AVCHD
video.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://neuron2.net/library/mpeg2/iso13818-1.pdf>

=item L<http://www.blu-raydisc.com/Assets/Downloadablefile/BD-RE_Part3_V2.1_WhitePaper_080406-15271.pdf>

=item L<http://www.videohelp.com/forum/archive/reading-avchd-playlist-files-bdmv-playlist-mpl-t358888.html>

=item L<http://en.wikipedia.org/wiki/MPEG_transport_stream>

=item L<http://www.dunod.com/documents/9782100493463/49346_DVB.pdf>

=item L<http://trac.handbrake.fr/browser/trunk/libhb/stream.c>

=item L<http://ieeexplore.ieee.org/stamp/stamp.jsp?arnumber=04560141>

=item L<http://www.w6rz.net/xport.zip>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/M2TS Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

