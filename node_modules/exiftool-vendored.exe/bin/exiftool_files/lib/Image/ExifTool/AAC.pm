#------------------------------------------------------------------------------
# File:         AAC.pm
#
# Description:  Read AAC audio files
#
# Revisions:    2023-12-29 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::AAC;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::FLAC;

$VERSION = '1.00';

my %convSampleRate = (
    0 => 96000,  7 => 22050,
    1 => 88200,  8 => 16000,
    2 => 64000,  9 => 12000,
    3 => 48000,  10 => 11025,
    4 => 44100,  11 => 8000,
    5 => 32000,  12 => 7350,
    6 => 24000,
);

%Image::ExifTool::AAC::Main = (
    PROCESS_PROC => \&Image::ExifTool::FLAC::ProcessBitStream,
    GROUPS => { 2 => 'Audio' },
    NOTES => 'Tags extracted from Advanced Audio Coding (AAC) files.',
   # Bit000-011 - sync word (all 1's)
   # Bit012     - ID (seems to be always 0)
   # Bit013-014 - layer (00)
   # Bit015     - CRC absent (0=crc exists, 1=no crc)
    'Bit016-017' => {
        Name => 'ProfileType',
        PrintConv => {
            0 => 'Main',
            1 => 'Low Complexity',
            2 => 'Scalable Sampling Rate',
        },
    },
    'Bit018-021' => {
        Name => 'SampleRate',
        ValueConv => \%convSampleRate,
    },
   # Bit022 - private
    'Bit023-025' => {
        Name => 'Channels',
        PrintConv => {
            0 => '?',
            1 => 1,
            2 => 2,
            3 => 3,
            4 => 4,
            5 => 5,
            6 => '5+1',
            7 => '7+1',
        },
    },
   # Bit026 - original/copy
   # Bit027 - home
   # Bit028 - copyright ID
   # Bit029 - copyright start
   # Bit030-042 - FrameLength
   # Bit043-053 - buffer fullness
   # Bit054-055 - BlocksInFrame (minus 1)
   # Note: Bitrate for frame = FrameLength * 8 * SampleRate / ((BlocksInFrame+1) * 1024)
   # - but all frames must be scanned to calculate average bitrate
    Encoder => {
        Name => 'Encoder',
        Notes => 'taken from filler payload of first frame',
    },
);

#------------------------------------------------------------------------------
# Read information from an AAC file
# Inputs: 0) ExifTool object reference, 1) Directory information reference
# Returns: 1 on success, 0 if this wasn't a valid AAC file
sub ProcessAAC($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $buf2);

# format of frame header (7 bytes):
# SSSS SSSS SSSS ILLC PPRR RRpC CCoh csff ffff ffff fffb bbbb bbbb bbNN
# 1111 1111 1111 0001 0110 0000 0100 0000 0000 0101 0101 1111 1111 1100 (eg.)
#  S = sync word                o = original/copy
#  I = ID                       h = home
#  L = layer (00)               c = copyright ID
#  C = CRC absent               s = copyright start
#  P = profile object type      f = frame length
#  R = sampling rate index      b = buffer fullness
#  p = private                  N = number of raw data blocks in frame
#  C = channel configuration

    $raf->Read($buff, 7) == 7 or return 0;
    return 0 unless $buff =~ /^\xff[\xf0\xf1]/;
    my @t = unpack('NnC', $buff);
    return 0 if (($t[0] >> 16) & 0x03) == 3; # (reserved profile type)
    return 0 if (($t[0] >> 12) & 0x0f) > 12; # validate sampling frequency index
    my $len = (($t[0] << 11) & 0x1800) | (($t[1] >> 5) & 0x07ff);
    return 0 if $len < 7;

    $et->SetFileType();

    my $tagTablePtr = GetTagTable('Image::ExifTool::AAC::Main');
    $et->ProcessDirectory({ DataPt => \$buff }, $tagTablePtr);

    # read the first frame data to check for a filler with the encoder name
    while ($len > 8 and $raf->Read($buff, $len-7) == $len-7) {
        my $noCRC = ($t[0] & 0x00010000);
        my $blocks = ($t[2] & 0x03);
        my $pos = 0;
        $pos += 2 + 2 * $blocks unless $noCRC;
        last if $pos + 2 > length($buff);
        my $tmp = unpack("x${pos}n", $buff);
        my $id = $tmp >> 13;
        # read filler payload
        if ($id == 6) {
            my $cnt = ($tmp >> 9) & 0x0f;
            ++$pos;
            if ($cnt == 15) {
                $cnt += (($tmp >> 1) & 0xff) - 1;
                ++$pos;
            }
            if ($pos + $cnt <= length($buff)) {
                my $dat = substr($buff, $pos, $cnt);
                $dat =~ s/^\0+//;
                $dat =~ s/\0+$//;
                $et->HandleTag($tagTablePtr, Encoder => $dat) if $dat =~ /^[\x20-\x7e]+$/;
            }
        }
        last;
    }

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::AAC - Read AAC audio files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read
Advanced Audio Coding (AAC) files.

=head1 NOTES

Since ISO charges money for the official AAC specification, this module is
based on unofficial sources which may be incomplete, inaccurate or outdated.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/AAC Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

