#------------------------------------------------------------------------------
# File:         DV.pm
#
# Description:  Read DV meta information
#
# Revisions:    2010/12/24 - P. Harvey Created
#
# References:   1) http://www.ffmpeg.org/
#               2) http://dvswitch.alioth.debian.org/wiki/DV_format/
#------------------------------------------------------------------------------

package Image::ExifTool::DV;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.02';

# DV profiles (ref 1)
my @dvProfiles = (
    {
        DSF => 0,
        VideoSType => 0x0,
        FrameSize => 120000,
        VideoFormat => 'IEC 61834, SMPTE-314M - 525/60 (NTSC)',
        Colorimetry => '4:1:1',
        FrameRate => 30000/1001,
        ImageHeight => 480,
        ImageWidth => 720,
    },{
        DSF => 1,
        VideoSType => 0x0,
        FrameSize => 144000,
        VideoFormat => 'IEC 61834 - 625/50 (PAL)',
        Colorimetry => '4:2:0',
        FrameRate => 25/1,
        ImageHeight => 576,
        ImageWidth => 720,
    },{
        DSF => 1,
        VideoSType => 0x0,
        FrameSize => 144000,
        VideoFormat => 'SMPTE-314M - 625/50 (PAL)',
        Colorimetry => '4:1:1',
        FrameRate => 25/1,
        ImageHeight => 576,
        ImageWidth => 720,
    },{
        DSF => 0,
        VideoSType => 0x4,
        FrameSize => 240000,
        VideoFormat => 'DVCPRO50: SMPTE-314M - 525/60 (NTSC) 50 Mbps',
        Colorimetry => '4:2:2',
        FrameRate => 30000/1001,
        ImageHeight => 480,
        ImageWidth => 720,
    },{
        DSF => 1,
        VideoSType => 0x4,
        FrameSize => 288000,
        VideoFormat => 'DVCPRO50: SMPTE-314M - 625/50 (PAL) 50 Mbps',
        Colorimetry => '4:2:2',
        FrameRate => 25/1,
        ImageHeight => 576,
        ImageWidth => 720,
    },{
        DSF => 0,
        VideoSType => 0x14,
        FrameSize => 480000,
        VideoFormat => 'DVCPRO HD: SMPTE-370M - 1080i60 100 Mbps',
        Colorimetry => '4:2:2',
        FrameRate => 30000/1001,
        ImageHeight => 1080,
        ImageWidth => 1280,
    },{
        DSF => 1,
        VideoSType => 0x14,
        FrameSize => 576000,
        VideoFormat => 'DVCPRO HD: SMPTE-370M - 1080i50 100 Mbps',
        Colorimetry => '4:2:2',
        FrameRate => 25/1,
        ImageHeight => 1080,
        ImageWidth => 1440,
    },{
        DSF => 0,
        VideoSType => 0x18,
        FrameSize => 240000,
        VideoFormat => 'DVCPRO HD: SMPTE-370M - 720p60 100 Mbps',
        Colorimetry => '4:2:2',
        FrameRate => 60000/1001,
        ImageHeight => 720,
        ImageWidth => 960,
    },{
        DSF => 1,
        VideoSType => 0x18,
        FrameSize => 288000,
        VideoFormat => 'DVCPRO HD: SMPTE-370M - 720p50 100 Mbps',
        Colorimetry => '4:2:2',
        FrameRate => 50/1,
        ImageHeight => 720,
        ImageWidth => 960,
    },{
        DSF => 1,
        VideoSType => 0x1,
        FrameSize => 144000,
        VideoFormat => 'IEC 61883-5 - 625/50 (PAL)',
        Colorimetry => '4:2:0',
        FrameRate => 25/1,
        ImageHeight => 576,
        ImageWidth => 720,
    },
);

# tags to extract, in the order we want to extract them
my @dvTags = (
    'DateTimeOriginal', 'ImageWidth',  'ImageHeight',   'Duration',
    'TotalBitrate',     'VideoFormat', 'VideoScanType', 'FrameRate',
    'AspectRatio',      'Colorimetry', 'AudioChannels', 'AudioSampleRate',
    'AudioBitsPerSample',
);

# DV tags
%Image::ExifTool::DV::Main = (
    GROUPS => { 2 => 'Video' },
    VARS => { NO_ID => 1 },
    NOTES => 'The following tags are extracted from DV videos.',
    DateTimeOriginal => {
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ImageWidth         => { },
    ImageHeight        => { },
    Duration           => { PrintConv => 'ConvertDuration($val)' },
    TotalBitrate       => { PrintConv => 'ConvertBitrate($val)' },
    VideoFormat        => { },
    VideoScanType      => { },
    FrameRate          => { PrintConv => 'int($val * 1000 + 0.5) / 1000' },
    AspectRatio        => { },
    Colorimetry        => { },
    AudioChannels      => { Groups => { 2 => 'Audio' } },
    AudioSampleRate    => { Groups => { 2 => 'Audio' } },
    AudioBitsPerSample => { Groups => { 2 => 'Audio' } },
);

#------------------------------------------------------------------------------
# Read information in a DV file (ref 1)
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid DV file
sub ProcessDV($$)
{
    my ($et, $dirInfo) = @_;
    local $_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $start, $profile, $tag, $i, $j);

    $raf->Read($buff, 12000) or return 0;
    if ($buff =~ /\x1f\x07\0[\x3f\xbf]/sg) {
        $start = pos($buff) - 4;
    } else {
        while ($buff =~ /[\0\xff]\x3f\x07\0.{76}\xff\x3f\x07\x01/sg) {
            next if pos($buff) - 163 < 0;
            $start = pos($buff) - 163;
            last;
        }
        return 0 unless defined $start;
    }
    my $len = length $buff;
    # must at least have a full DIF header
    return 0 if $start + 80 * 6 > $len;

    $et->SetFileType();

    my $pos = $start;
    my $dsf = (Get8u(\$buff, $pos + 3) & 0x80) >> 7;
    my $stype = Get8u(\$buff, $pos + 80*5 + 48 + 3) & 0x1f;

    # 576i50 25Mbps 4:1:1 is a special case
    if ($dsf == 1 && $stype == 0 && Get8u(\$buff, 4) & 0x07) {
        $profile = $dvProfiles[2];
    } else {
        foreach (@dvProfiles) {
            next unless $dsf == $$_{DSF} and $stype == $$_{VideoSType};
            $profile = $_;
            last;
        }
        $profile or $et->Warn("Unrecognized DV profile"), return 1;
    }
    my $tagTablePtr = GetTagTable('Image::ExifTool::DV::Main');

    # calculate total bit rate and duration
    my $byteRate = $$profile{FrameSize} * $$profile{FrameRate};
    my $fileSize = $$et{VALUE}{FileSize};
    $$profile{TotalBitrate} = 8 * $byteRate;
    $$profile{Duration} = $fileSize / $byteRate if defined $fileSize;

    # read DVPack metadata from the VAUX DIF's to extract video tags
    delete $$profile{DateTimeOriginal};
    delete $$profile{AspectRatio};
    delete $$profile{VideoScanType};
    my ($date, $time, $is16_9, $interlace);
    for ($i=1; $i<6; ++$i) {
        $pos += 80;
        my $type = Get8u(\$buff, $pos);
        next unless ($type & 0xf0) == 0x50;   # look for VAUX types
        for ($j=0; $j<15; ++$j) {
            my $p = $pos + $j * 5 + 3;
            $type = Get8u(\$buff, $p);
            if ($type == 0x61) { # video control
                my $apt = Get8u(\$buff, $start + 4) & 0x07;
                my $t = Get8u(\$buff, $p + 2);
                $is16_9 = (($t & 0x07) == 0x02 or (not $apt and ($t & 0x07) == 0x07));
                $interlace = Get8u(\$buff, $p + 3) & 0x10; # (ref 2)
            } elsif ($type == 0x62) { # date
                # mask off unused bits
                my @d = unpack('C*', substr($buff, $p + 1, 4));
                # (ignore timezone in byte 0 until we can test this properly - see ref 2)
                $date = sprintf('%.2x:%.2x:%.2x', $d[3], $d[2] & 0x1f, $d[1] & 0x3f);
                if ($date =~ /[a-f]/) {
                    undef $date;    # invalid date
                } else {
                    # add century (this will work until 2089)
                    $date = ($date lt '9' ? '20' : '19') . $date;
                }
                undef $time;
            } elsif ($type == 0x63 and $date) { # time
                # (ignore frames past second in byte 0 for now - see ref 2)
                my $val = Get32u(\$buff, $p + 1) & 0x007f7f3f;
                my @t = unpack('C*', substr($buff, $p + 1, 4));
                $time = sprintf('%.2x:%.2x:%.2x', $t[3] & 0x3f, $t[2] & 0x7f, $t[1] & 0x7f);
                last;
            } else {
                undef $time;    # must be consecutive
            }
        }
    }
    if ($date and $time) {
        $$profile{DateTimeOriginal} = "$date $time";
        if (defined $is16_9) {
            $$profile{AspectRatio} = $is16_9 ? '16:9' : '4:3';
            $$profile{VideoScanType} = $interlace ? 'Interlaced' : 'Progressive';
        }
    }

    # read audio tags if available
    delete $$profile{AudioSampleRate};
    delete $$profile{AudioBitsPerSample};
    delete $$profile{AudioChannels};
    $pos = $start + 80*6 + 80*16*3 + 3;
    if ($pos + 4 < $len and Get8u(\$buff, $pos) == 0x50) {
        my $smpls = Get8u(\$buff, $pos + 1);
        my $freq = (Get8u(\$buff, $pos + 4) >> 3) & 0x07;
        my $stype = Get8u(\$buff, $pos + 3) & 0x1f;
        my $quant = Get8u(\$buff, $pos + 4) & 0x07;
        if ($freq < 3) {
            $$profile{AudioSampleRate} = {0=>48000, 1=>44100, 2=>32000}->{$freq};
        }
        if ($stype < 3) {
            $stype = 2 if $stype == 0 and $quant and $freq == 2;
            $$profile{AudioChannels} = {0=>2, 1=>0, 2=>4, 3=>8}->{$stype};
        }
        $$profile{AudioBitsPerSample} = $quant ? 12 : 16;
    }

    # save our metadata
    foreach $tag (@dvTags) {
        next unless defined $$profile{$tag};
        $et->HandleTag($tagTablePtr, $tag, $$profile{$tag});
    }

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::DV - Read DV meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read meta
information from DV (raw Digital Video) files.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://ffmpeg.org/>

=item L<http://dvswitch.alioth.debian.org/wiki/DV_format/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/DV Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

