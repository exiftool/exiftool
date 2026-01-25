#------------------------------------------------------------------------------
# File:         MPEG.pm
#
# Description:  Read MPEG-1 and MPEG-2 meta information
#
# Revisions:    05/11/2006 - P. Harvey Created
#
# References:   1) http://www.mp3-tech.org/
#               2) http://www.getid3.org/
#               3) http://dvd.sourceforge.net/dvdinfo/dvdmpeg.html
#               4) http://ffmpeg.org/
#               5) http://sourceforge.net/projects/mediainfo/
#------------------------------------------------------------------------------

package Image::ExifTool::MPEG;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.17';

%Image::ExifTool::MPEG::Audio = (
    GROUPS => { 2 => 'Audio' },
    'Bit11-12' => {
        Name => 'MPEGAudioVersion',
        RawConv => '$self->{MPEG_Vers} = $val',
        PrintConv => {
            0 => 2.5,
            2 => 2,
            3 => 1,
        },
    },
    'Bit13-14' => {
        Name => 'AudioLayer',
        RawConv => '$self->{MPEG_Layer} = $val',
        PrintConv => {
            1 => 3,
            2 => 2,
            3 => 1,
        },
    },
    # Bit 15 indicates CRC protection
    'Bit16-19' => [
        {
            Name => 'AudioBitrate',
            Condition => '$self->{MPEG_Vers} == 3 and $self->{MPEG_Layer} == 3',
            Notes => 'version 1, layer 1',
            PrintConvColumns => 3,
            ValueConv => {
                0 => 'free',
                1 => 32000,
                2 => 64000,
                3 => 96000,
                4 => 128000,
                5 => 160000,
                6 => 192000,
                7 => 224000,
                8 => 256000,
                9 => 288000,
                10 => 320000,
                11 => 352000,
                12 => 384000,
                13 => 416000,
                14 => 448000,
            },
            PrintConv => 'ConvertBitrate($val)',
        },
        {
            Name => 'AudioBitrate',
            Condition => '$self->{MPEG_Vers} == 3 and $self->{MPEG_Layer} == 2',
            Notes => 'version 1, layer 2',
            PrintConvColumns => 3,
            ValueConv => {
                0 => 'free',
                1 => 32000,
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
            },
            PrintConv => 'ConvertBitrate($val)',
        },
        {
            Name => 'AudioBitrate',
            Condition => '$self->{MPEG_Vers} == 3 and $self->{MPEG_Layer} == 1',
            Notes => 'version 1, layer 3',
            PrintConvColumns => 3,
            ValueConv => {
                0 => 'free',
                1 => 32000,
                2 => 40000,
                3 => 48000,
                4 => 56000,
                5 => 64000,
                6 => 80000,
                7 => 96000,
                8 => 112000,
                9 => 128000,
                10 => 160000,
                11 => 192000,
                12 => 224000,
                13 => 256000,
                14 => 320000,
            },
            PrintConv => 'ConvertBitrate($val)',
        },
        {
            Name => 'AudioBitrate',
            Condition => '$self->{MPEG_Vers} != 3 and $self->{MPEG_Layer} == 3',
            Notes => 'version 2 or 2.5, layer 1',
            PrintConvColumns => 3,
            ValueConv => {
                0 => 'free',
                1 => 32000,
                2 => 48000,
                3 => 56000,
                4 => 64000,
                5 => 80000,
                6 => 96000,
                7 => 112000,
                8 => 128000,
                9 => 144000,
                10 => 160000,
                11 => 176000,
                12 => 192000,
                13 => 224000,
                14 => 256000,
            },
            PrintConv => 'ConvertBitrate($val)',
        },
        {
            Name => 'AudioBitrate',
            Condition => '$self->{MPEG_Vers} != 3 and $self->{MPEG_Layer}',
            Notes => 'version 2 or 2.5, layer 2 or 3',
            PrintConvColumns => 3,
            ValueConv => {
                0 => 'free',
                1 => 8000,
                2 => 16000,
                3 => 24000,
                4 => 32000,
                5 => 40000,
                6 => 48000,
                7 => 56000,
                8 => 64000,
                9 => 80000,
                10 => 96000,
                11 => 112000,
                12 => 128000,
                13 => 144000,
                14 => 160000,
            },
            PrintConv => 'ConvertBitrate($val)',
        },
    ],
    'Bit20-21' => [
        {
            Name => 'SampleRate',
            Condition => '$self->{MPEG_Vers} == 3',
            Notes => 'version 1',
            PrintConv => {
                0 => 44100,
                1 => 48000,
                2 => 32000,
            },
        },
        {
            Name => 'SampleRate',
            Condition => '$self->{MPEG_Vers} == 2',
            Notes => 'version 2',
            PrintConv => {
                0 => 22050,
                1 => 24000,
                2 => 16000,
            },
        },
        {
            Name => 'SampleRate',
            Condition => '$self->{MPEG_Vers} == 0',
            Notes => 'version 2.5',
            PrintConv => {
                0 => 11025,
                1 => 12000,
                2 => 8000,
            },
        },
    ],
    # Bit 22 - padding flag
    # Bit 23 - private bit
    'Bit24-25' => {
        Name => 'ChannelMode',
        RawConv => '$self->{MPEG_Mode} = $val',
        PrintConv => {
            0 => 'Stereo',
            1 => 'Joint Stereo',
            2 => 'Dual Channel',
            3 => 'Single Channel',
        },
    },
    'Bit26' => {
        Name => 'MSStereo',
        Condition => '$self->{MPEG_Layer} == 1',
        Notes => 'layer 3',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    'Bit27' => {
        Name => 'IntensityStereo',
        Condition => '$self->{MPEG_Layer} == 1',
        Notes => 'layer 3',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    'Bit26-27' => {
        Name => 'ModeExtension',
        Condition => '$self->{MPEG_Layer} > 1',
        Notes => 'layer 1 or 2',
        PrintConv => {
            0 => 'Bands 4-31',
            1 => 'Bands 8-31',
            2 => 'Bands 12-31',
            3 => 'Bands 16-31',
        },
    },
    'Bit28'    => {
        Name => 'CopyrightFlag',
        PrintConv => {
            0 => 'False',
            1 => 'True',
        },
    },
    'Bit29'    => {
        Name => 'OriginalMedia',
        PrintConv => {
            0 => 'False',
            1 => 'True',
        },
    },
    'Bit30-31' => {
        Name => 'Emphasis',
        PrintConv => {
            0 => 'None',
            1 => '50/15 ms',
            2 => 'reserved',
            3 => 'CCIT J.17',
        },
    },
);

%Image::ExifTool::MPEG::Video = (
    GROUPS => { 2 => 'Video' },
    'Bit00-11' => 'ImageWidth',
    'Bit12-23' => 'ImageHeight',
    'Bit24-27' => {
        Name => 'AspectRatio',
        ValueConv => {
            1 => 1,
            2 => 0.6735,
            3 => 0.7031,
            4 => 0.7615,
            5 => 0.8055,
            6 => 0.8437,
            7 => 0.8935,
            8 => 0.9157,
            9 => 0.9815,
            10 => 1.0255,
            11 => 1.0695,
            12 => 1.0950,
            13 => 1.1575,
            14 => 1.2015,
        },
        PrintConv => {
            1      => '1:1',
            0.6735 => '0.6735',
            0.7031 => '16:9, 625 line, PAL',
            0.7615 => '0.7615',
            0.8055 => '0.8055',
            0.8437 => '16:9, 525 line, NTSC',
            0.8935 => '0.8935',
            0.9157 => '4:3, 625 line, PAL, CCIR601',
            0.9815 => '0.9815',
            1.0255 => '1.0255',
            1.0695 => '1.0695',
            1.0950 => '4:3, 525 line, NTSC, CCIR601',
            1.1575 => '1.1575',
            1.2015 => '1.2015',
        },
    },
    'Bit28-31' => {
        Name => 'FrameRate',
        ValueConv => {
            1 => 23.976,
            2 => 24,
            3 => 25,
            4 => 29.97,
            5 => 30,
            6 => 50,
            7 => 59.94,
            8 => 60,
        },
        PrintConv => '"$val fps"',
    },
    'Bit32-49' => {
        Name => 'VideoBitrate',
        ValueConv => '$val eq 0x3ffff ? "Variable" : $val * 400',
        PrintConv => 'ConvertBitrate($val)',
    },
    # these tags not very interesting
    #'Bit50'    => 'MarkerBit',
    #'Bit51-60' => 'VBVBufferSize',
    #'Bit61'    => 'ConstrainedParamFlag',
    #'Bit62'    => 'IntraQuantMatrixFlag',
);

%Image::ExifTool::MPEG::Xing = (
    GROUPS => { 2 => 'Audio' },
    VARS => { ID_FMT => 'none' },
    NOTES => 'These tags are extracted from the Xing/Info frame.',
    1 => { Name => 'VBRFrames' },
    2 => { Name => 'VBRBytes' },
    3 => { Name => 'VBRScale' },
    4 => { Name => 'Encoder' },
    5 => { Name => 'LameVBRQuality' },
    6 => { Name => 'LameQuality' },
    7 => { # (for documentation only)
        Name => 'LameHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::MPEG::Lame' },
    },
);

# Lame header tags (ref 5)
%Image::ExifTool::MPEG::Lame = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Audio' },
    NOTES => 'Tags extracted from Lame 3.90 or later header.',
    9 => {
        Name => 'LameMethod',
        Mask => 0x0f,
        PrintConv => {
            1 => 'CBR',
            2 => 'ABR',
            3 => 'VBR (old/rh)',
            4 => 'VBR (new/mtrh)',
            5 => 'VBR (old/rh)',
            6 => 'VBR',
            8 => 'CBR (2-pass)',
            9 => 'ABR (2-pass)',
        },
    },
    10 => {
        Name => 'LameLowPassFilter',
        ValueConv => '$val * 100',
        PrintConv => '($val / 1000) . " kHz"',
    },
    # 19 - EncodingFlags
    20 => {
        Name => 'LameBitrate',
        ValueConv => '$val * 1000',
        PrintConv => 'ConvertBitrate($val)',
    },
    24 => {
        Name => 'LameStereoMode',
        Mask => 0x1c,
        PrintConv => {
            0 => 'Mono',
            1 => 'Stereo',
            2 => 'Dual Channels',
            3 => 'Joint Stereo',
            4 => 'Forced Joint Stereo',
            6 => 'Auto',
            7 => 'Intensity Stereo',
        },
    },
);

# composite tags
%Image::ExifTool::MPEG::Composite = (
    Duration => {
        Groups => { 2 => 'Video' },
        Require => {
            0 => 'FileSize',
        },
        Desire => {
            1 => 'ID3Size',
            2 => 'MPEG:AudioBitrate',
            3 => 'MPEG:VideoBitrate',
            4 => 'MPEG:VBRFrames',
            5 => 'MPEG:SampleRate',
            6 => 'MPEG:MPEGAudioVersion',
        },
        Priority => -1, # (don't want to replace any other Duration tag)
        ValueConv => q{
            if ($val[4] and defined $val[5] and defined $val[6]) {
                # calculate from number of VBR audio frames
                my $mfs = $prt[5] / ($val[6] == 3 ? 144 : 72);
                # calculate using VBR length
                return 8 * $val[4] / $mfs;
            }
            # calculate duration as file size divided by total bitrate
            # (note: this is only approximate!)
            return undef unless $val[2] or $val[3];
            return undef if $val[2] and not $val[2] =~ /^\d+$/;
            return undef if $val[3] and not $val[3] =~ /^\d+$/;
            return (8 * ($val[0] - ($val[1]||0))) / (($val[2]||0) + ($val[3]||0));
        },
        PrintConv => 'ConvertDuration($val) . " (approx)"',
    },
    AudioBitrate => {
        Groups => { 2 => 'Audio' },
        Notes => 'calculated for variable-bitrate MPEG audio',
        Require => {
            0 => 'MPEG:MPEGAudioVersion',
            1 => 'MPEG:SampleRate',
            2 => 'MPEG:VBRBytes',
            3 => 'MPEG:VBRFrames',
        },
        ValueConv => q{
            return undef unless $val[3];
            my $mfs = $prt[1] / ($val[0] == 3 ? 144 : 72);
            return $mfs * $val[2] / $val[3];
        },
        PrintConv => 'ConvertBitrate($val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::MPEG');


#------------------------------------------------------------------------------
# Process information in an MPEG audio or video frame header
# Inputs: 0) ExifTool object ref, 1) tag table ref, 2-N) list of 32-bit data words
sub ProcessFrameHeader($$@)
{
    my ($et, $tagTablePtr, @data) = @_;
    my $tag;
    foreach $tag (sort keys %$tagTablePtr) {
        next unless $tag =~ /^Bit(\d{2})-?(\d{2})?/;
        my ($b1, $b2) = ($1, $2 || $1);
        my $index = int($b1 / 32);
        my $word = $data[$index];
        my $mask = 0;
        foreach (0 .. ($b2 - $b1)) {
            $mask += (1 << $_);
        }
        my $val = ($word >> (31 + 32*$index - $b2)) & $mask;
        $et->HandleTag($tagTablePtr, $tag, $val);
    }
}

#------------------------------------------------------------------------------
# Read MPEG audio frame header
# Inputs: 0) ExifTool object reference, 1) Reference to audio data
#         2) flag set if we are trying to recognized MP3 file only
# Returns: 1 on success, 0 if no audio header was found
sub ParseMPEGAudio($$;$)
{
    my ($et, $buffPt, $mp3) = @_;
    my ($word, $pos);
    my $ext = $$et{FILE_EXT} || '';

    for (;;) {
        # find frame sync
        return 0 unless $$buffPt =~ m{(\xff.{3})}sg;
        $word = unpack('N', $1);    # get audio frame header word
        unless (($word & 0xffe00000) == 0xffe00000) {
            pos($$buffPt) = pos($$buffPt) - 2;  # next possible location for frame sync
            next;
        }
        # validate header as much as possible
        if (($word & 0x180000) == 0x080000 or   # 01 is a reserved version ID
            ($word & 0x060000) == 0x000000 or   # 00 is a reserved layer description
            ($word & 0x00f000) == 0x000000 or   # 0000 is the "free" bitrate index
            ($word & 0x00f000) == 0x00f000 or   # 1111 is a bad bitrate index
            ($word & 0x000c00) == 0x000c00 or   # 11 is a reserved sampling frequency
            ($word & 0x000003) == 0x000002 or   # 10 is a reserved emphasis
            (($mp3 and ($word & 0x060000) != 0x020000))) # must be layer 3 for MP3
        {
            # give up easily unless this really should be an MP3 file
            return 0 unless $ext eq 'MP3';
            pos($$buffPt) = pos($$buffPt) - 1;
            next;
        }
        $pos = pos($$buffPt);
        last;
    }
    # set file type if not done already
    $et->SetFileType();

    my $tagTablePtr = GetTagTable('Image::ExifTool::MPEG::Audio');
    ProcessFrameHeader($et, $tagTablePtr, $word);

    # extract the VBR information (ref MP3::Info)
    my ($v, $m) = ($$et{MPEG_Vers}, $$et{MPEG_Mode});
    while (defined $v and defined $m) {
        my $len = length $$buffPt;
        $pos += $v == 3 ? ($m == 3 ? 17 : 32) : ($m == 3 ?  9 : 17);
        last if $pos + 8 > $len;
        my $buff = substr($$buffPt, $pos, 8);
        last unless $buff =~ /^(Xing|Info)/;
        my $xingTable = GetTagTable('Image::ExifTool::MPEG::Xing');
        my $vbrScale;
        my $flags = unpack('x4N', $buff);
        my $isVBR = ($buff !~ /^Info/);     # Info frame is not VBR (ref 5)
        $pos += 8;
        if ($flags & 0x01) {    # VBRFrames
            last if $pos + 4 > $len;
            $et->HandleTag($xingTable, 1, unpack("x${pos}N", $$buffPt)) if $isVBR;
            $pos += 4;
        }
        if ($flags & 0x02) {    # VBRBytes
            last if $pos + 4 > $len;
            $et->HandleTag($xingTable, 2, unpack("x${pos}N", $$buffPt)) if $isVBR;
            $pos += 4;
        }
        if ($flags & 0x04) {    # VBR_TOC
            last if $pos + 100 > $len;
            # (ignore toc for now)
            $pos += 100;
        }
        if ($flags & 0x08) {    # VBRScale
            last if $pos + 4 > $len;
            $vbrScale = unpack("x${pos}N", $$buffPt);
            $et->HandleTag($xingTable, 3, $vbrScale) if $isVBR;
            $pos += 4;
        }
        # process Lame header (ref 5)
        if ($flags & 0x10) {    # Lame
            last if $pos + 348 > $len;
        } elsif ($pos + 4 <= $len) {
            my $lib = substr($$buffPt, $pos, 4);
            unless ($lib eq 'LAME' or $lib eq 'GOGO') {
                # attempt to identify other encoders
                my $n;
                if (index($$buffPt, 'RCA mp3PRO Encoder') >= 0) {
                    $lib = 'RCA mp3PRO';
                } elsif (($n = index($$buffPt, 'THOMSON mp3PRO Encoder')) >= 0) {
                    $lib = 'Thomson mp3PRO';
                    $n += 22;
                    $lib .= ' ' . substr($$buffPt, $n, 6) if length($$buffPt) - $n >= 6;
                } elsif (index($$buffPt, 'MPGE') >= 0) {
                    $lib = 'Gogo (<3.0)';
                } else {
                    last;
                }
                $et->HandleTag($xingTable, 4, $lib);
                last;
            }
        }
        my $lameLen = $len - $pos;
        last if $lameLen < 9;
        my $enc = substr($$buffPt, $pos, 9);
        if ($enc ge 'LAME3.90') {
            $et->HandleTag($xingTable, 4, $enc);
            if ($vbrScale <= 100) {
                $et->HandleTag($xingTable, 5, int((100 - $vbrScale) / 10));
                $et->HandleTag($xingTable, 6, (100 - $vbrScale) % 10);
            }
            my %dirInfo = (
                DataPt   => $buffPt,
                DirStart => $pos,
                DirLen   => length($$buffPt) - $pos,
            );
            my $subTablePtr = GetTagTable('Image::ExifTool::MPEG::Lame');
            $et->ProcessDirectory(\%dirInfo, $subTablePtr);
        } else {
            $et->HandleTag($xingTable, 4, substr($$buffPt, $pos, 20));
        }
        last;   # (didn't want to loop anyway)
    }

    return 1;
}

#------------------------------------------------------------------------------
# Read MPEG video frame header
# Inputs: 0) ExifTool object reference, 1) Reference to video data
# Returns: 1 on success, 0 if no video header was found
sub ProcessMPEGVideo($$)
{
    my ($et, $buffPt) = @_;

    return 0 unless length $$buffPt >= 4;
    my ($w1, $w2) = unpack('N2', $$buffPt);
    # validate as much as possible
    if (($w1 & 0x000000f0) == 0x00000000 or     # 0000 is a forbidden aspect ratio
        ($w1 & 0x000000f0) == 0x000000f0 or     # 1111 is a reserved aspect ratio
        ($w1 & 0x0000000f) == 0 or              # frame rate must be 1-8
        ($w1 & 0x0000000f) > 8)
    {
        return 0;
    }
    # set file type if not done already
    $et->SetFileType('MPEG') unless $$et{FileType};

    my $tagTablePtr = GetTagTable('Image::ExifTool::MPEG::Video');
    ProcessFrameHeader($et, $tagTablePtr, $w1, $w2);
    return 1;
}

#------------------------------------------------------------------------------
# Read MPEG audio and video frame headers
# Inputs: 0) ExifTool object reference, 1) Reference to audio/video data
# Returns: 1 on success, 0 if no video header was found
# To Do: Properly parse MPEG streams:
#   0xb7 - sequence end
#   0xb9 - end code
#   0xba - pack start code
#   0xbb - system header
#   0xbc - program map <-- should parse this
#   0xbd - private stream 1 --> for VOB, this contains sub-streams:
#           0x20-0x3f - pictures
#           0x80-0x87 - audio (AC3,DTS,SDDS)
#           0xa0-0xa7 - audio (LPCM)
#   0xbe - padding
#   0xbf - private stream 2
#   0xc0-0xdf - audio stream
#   0xe0-0xef - video stream
sub ParseMPEGAudioVideo($$)
{
    my ($et, $buffPt) = @_;
    my (%found, $didHdr);
    my $rtnVal = 0;
    my %proc = ( audio => \&ParseMPEGAudio, video => \&ProcessMPEGVideo );

    delete $$et{AudioBitrate};
    delete $$et{VideoBitrate};

    while ($$buffPt =~ /\0\0\x01(\xb3|\xc0)/g) {
        my $type = $1 eq "\xb3" ? 'video' : 'audio';
        unless ($didHdr) {
            # make sure we didn't miss an audio frame sync before this (eg. MP3 file)
            # (the last byte of the 4-byte MP3 audio frame header word may be zero,
            # but the 2nd last must be non-zero, so we need only check to pos-3)
            my $buff = substr($$buffPt, 0, pos($$buffPt) - 3);
            $found{audio} = 1 if ParseMPEGAudio($et, \$buff);
            $didHdr = 1;
        }
        next if $found{$type};
        my $len = length($$buffPt) - pos($$buffPt);
        last if $len < 4;
        $len > 256 and $len = 256;
        my $dat = substr($$buffPt, pos($$buffPt), $len);
        # process MPEG audio or video
        if (&{$proc{$type}}($et, \$dat)) {
            $rtnVal = 1;
            $found{$type} = 1;
            # done if we found audio and video
            last if scalar(keys %found) == 2;
        }
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Read information from an MPEG file
# Inputs: 0) ExifTool object reference, 1) Directory information reference
# Returns: 1 on success, 0 if this wasn't a valid MPEG file
sub ProcessMPEG($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;

    $raf->Read($buff, 4) == 4 or return 0;
    return 0 unless $buff =~ /^\0\0\x01[\xb0-\xbf]/;
    $et->SetFileType();

    $raf->Seek(0,0);
    $raf->Read($buff, 65536*4) or return 0;

    return ParseMPEGAudioVideo($et, \$buff);
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MPEG - Read MPEG-1 and MPEG-2 meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read MPEG-1
and MPEG-2 audio/video files.

=head1 NOTES

Since ISO charges money for the official MPEG specification, this module is
based on unofficial sources which may be incomplete, inaccurate or outdated.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.mp3-tech.org/>

=item L<http://www.getid3.org/>

=item L<http://dvd.sourceforge.net/dvdinfo/dvdmpeg.html>

=item L<http://ffmpeg.org/>

=item L<http://sourceforge.net/projects/mediainfo/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MPEG Tags>,
L<MP3::Info(3pm)|MP3::Info>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

