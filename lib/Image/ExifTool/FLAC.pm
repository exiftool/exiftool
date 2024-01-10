#------------------------------------------------------------------------------
# File:         FLAC.pm
#
# Description:  Read Free Lossless Audio Codec information
#
# Revisions:    11/13/2006 - P. Harvey Created
#
# References:   1) http://flac.sourceforge.net/
#------------------------------------------------------------------------------

package Image::ExifTool::FLAC;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.09';

sub ProcessBitStream($$$);

# FLAC metadata blocks
%Image::ExifTool::FLAC::Main = (
    NOTES => q{
        Free Lossless Audio Codec (FLAC) meta information.  ExifTool also extracts
        ID3 information from these files.
    },
    0 => {
        Name => 'StreamInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::FLAC::StreamInfo' },
    },
    1 => { Name => 'Padding',     Binary => 1, Unknown => 1 },
    2 => [{ # (see forum14064)
        Name => 'Application_riff',
        Condition => '$$valPt =~ /^riff(?!RIFF)/', # (all "riff" blocks but header)
        SubDirectory => {
            TagTable => 'Image::ExifTool::RIFF::Main',
            ByteOrder => 'LittleEndian',
            Start => 4,
        },
    },{
        Name => 'ApplicationUnknown',
        Binary => 1,
        Unknown => 1,
    }],
    3 => { Name => 'SeekTable',   Binary => 1, Unknown => 1 },
    4 => {
        Name => 'VorbisComment',
        SubDirectory => { TagTable => 'Image::ExifTool::Vorbis::Comments' },
    },
    5 => { Name => 'CueSheet',    Binary => 1, Unknown => 1 },
    6 => {
        Name => 'Picture',
        SubDirectory => { TagTable => 'Image::ExifTool::FLAC::Picture' },
    },
    # 7-126 - Reserved
    # 127 - Invalid
);

%Image::ExifTool::FLAC::StreamInfo = (
    PROCESS_PROC => \&ProcessBitStream,
    NOTES => 'FLAC is big-endian, so bit 0 is the high-order bit in this table.',
    GROUPS => { 2 => 'Audio' },
    'Bit000-015' => 'BlockSizeMin',
    'Bit016-031' => 'BlockSizeMax',
    'Bit032-055' => 'FrameSizeMin',
    'Bit056-079' => 'FrameSizeMax',
    'Bit080-099' => 'SampleRate',
    'Bit100-102' => {
        Name => 'Channels',
        ValueConv => '$val + 1',
    },
    'Bit103-107' => {
        Name => 'BitsPerSample',
        ValueConv => '$val + 1',
    },
    'Bit108-143' => 'TotalSamples',
    'Bit144-271' => { #Tim Eliseo
        Name => 'MD5Signature',
        Format => 'undef',
        ValueConv => 'unpack("H*",$val)',
    },
);

%Image::ExifTool::FLAC::Picture = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int32u',
    0 => {
        Name => 'PictureType',
        PrintConv => { # (Note: Duplicated in ID3, ASF and FLAC modules!)
            0 => 'Other',
            1 => '32x32 PNG Icon',
            2 => 'Other Icon',
            3 => 'Front Cover',
            4 => 'Back Cover',
            5 => 'Leaflet',
            6 => 'Media',
            7 => 'Lead Artist',
            8 => 'Artist',
            9 => 'Conductor',
            10 => 'Band',
            11 => 'Composer',
            12 => 'Lyricist',
            13 => 'Recording Studio or Location',
            14 => 'Recording Session',
            15 => 'Performance',
            16 => 'Capture from Movie or Video',
            17 => 'Bright(ly) Colored Fish',
            18 => 'Illustration',
            19 => 'Band Logo',
            20 => 'Publisher Logo',
        },
    },
    1 => {
        Name => 'PictureMIMEType',
        Format => 'var_pstr32',
    },
    2 => {
        Name => 'PictureDescription',
        Format => 'var_pstr32',
        ValueConv => '$self->Decode($val, "UTF8")',
    },
    3 => 'PictureWidth',
    4 => 'PictureHeight',
    5 => 'PictureBitsPerPixel',
    6 => 'PictureIndexedColors',
    7 => 'PictureLength',
    8 => {
        Name => 'Picture',
        Groups => { 2 => 'Preview' },
        Format => 'undef[$val{7}]',
        Binary => 1,
    },
);

# FLAC composite tags
%Image::ExifTool::FLAC::Composite = (
    Duration => {
        Require => {
            0 => 'FLAC:SampleRate',
            1 => 'FLAC:TotalSamples',
        },
        ValueConv => '($val[0] and $val[1]) ? $val[1] / $val[0] : undef',
        PrintConv => 'ConvertDuration($val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::FLAC');


#------------------------------------------------------------------------------
# Process information in a bit stream
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Notes: Byte order is used to determine the ordering of bits in the stream:
# 'MM' = bit 0 is most significant, 'II' = bit 0 is least significant
# - can handle arbitrarily wide values (eg. 8-byte or larger integers)
sub ProcessBitStream($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt   = $$dirInfo{DataPt};
    my $dataPos  = $$dirInfo{DataPos};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen   = $$dirInfo{DirLen} || (length($$dataPt) - $dirStart);
    my $verbose  = $et->Options('Verbose');
    my $byteOrder = GetByteOrder();
    my $tag;

    if ($verbose) {
        $et->VPrint(0, "  + [BitStream directory, $dirLen bytes, '${byteOrder}' order]\n");
    }
    foreach $tag (sort keys %$tagTablePtr) {
        next unless $tag =~ /^Bit(\d+)-?(\d+)?/;
        my ($b1, $b2) = ($1, $2 || $1);     # start/end bit numbers in stream
        my ($i1, $i2) = (int($b1 / 8), int($b2 / 8)); # start/end byte numbers
        my ($f1, $f2) = ($b1 % 8, $b2 % 8); # start/end bit numbers within each byte
        last if $i2 >= $dirLen;
        my ($val, $extra);
        # if Format is unspecified, convert the specified number of bits to an unsigned integer,
        # otherwise allow HandleTag to convert whole bytes the normal way (via undefined $val)
        if (ref $$tagTablePtr{$tag} ne 'HASH' or not $$tagTablePtr{$tag}{Format}) {
            my ($i, $mask);
            $val = 0;
            $extra = ', Mask=0x' if $verbose and ($f1 != 0 or $f2 != 7);
            if ($byteOrder eq 'MM') {
                # loop from high byte to low byte
                for ($i=$i1; $i<=$i2; ++$i) {
                    $mask = 0xff;
                    if ($i == $i1 and $f1) {
                        # mask off high bits in first word (0 is high bit)
                        foreach ((8-$f1) .. 7) { $mask ^= (1 << $_) }
                    }
                    if ($i == $i2 and $f2 < 7) {
                        # mask off low bits in last word (7 is low bit)
                        foreach (0 .. (6-$f2)) { $mask ^= (1 << $_) }
                    }
                    $val = $val * 256 + ($mask & Get8u($dataPt, $i + $dirStart));
                    $extra .= sprintf('%.2x', $mask) if $extra;
                }
            } else {
                # (FLAC is big-endian, but support little-endian bit streams
                #  so this routine can be used by other modules)
                # loop from high byte to low byte
                for ($i=$i2; $i>=$i1; --$i) {
                    $mask = 0xff;
                    if ($i == $i1 and $f1) {
                        # mask off low bits in first word (0 is low bit)
                        foreach (0 .. ($f1-1)) { $mask ^= (1 << $_) }
                    }
                    if ($i == $i2 and $f2 < 7) {
                        # mask off high bits in last word (7 is high bit)
                        foreach (($f2+1) .. 7) { $mask ^= (1 << $_) }
                    }
                    $val = $val * 256 + ($mask & Get8u($dataPt, $i + $dirStart));
                    $extra .= sprintf('%.2x', $mask) if $extra;
                }
            }
            # shift word down until low bit is in position 0
            until ($mask & 0x01) {
                $val /= 2;
                $mask >>= 1;
            }
        }
        $et->HandleTag($tagTablePtr, $tag, $val,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $dirStart + $i1,
            Size    => $i2 - $i1 + 1,
            Extra   => $extra,
        );
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from an Ogg FLAC file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid Ogg FLAC file
sub ProcessFLAC($$)
{
    my ($et, $dirInfo) = @_;

    # must first check for leading/trailing ID3 information
    unless ($$et{DoneID3}) {
        require Image::ExifTool::ID3;
        Image::ExifTool::ID3::ProcessID3($et, $dirInfo) and return 1;
    }
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');
    my ($buff, $err);

    # check FLAC signature
    $raf->Read($buff, 4) == 4 and $buff eq 'fLaC' or return 0;
    $et->SetFileType();
    SetByteOrder('MM');
    my $tagTablePtr = GetTagTable('Image::ExifTool::FLAC::Main');
    for (;;) {
        # read next metadata block header
        $raf->Read($buff, 4) == 4 or last;
        my $flag = unpack('C', $buff);
        my $size = unpack('N', $buff) & 0x00ffffff;
        $raf->Read($buff, $size) == $size or $err = 1, last;
        my $last = $flag & 0x80;    # last-metadata-block flag
        my $tag  = $flag & 0x7f;    # tag bits
        if ($verbose) {
            print $out "FLAC metadata block, type $tag:\n";
            $et->VerboseDump(\$buff, DataPos => $raf->Tell() - $size);
        }
        $et->HandleTag($tagTablePtr, $tag, $buff,
            DataPt  => \$buff,
            DataPos => $raf->Tell() - $size,
            Start   => 0,
            Size    => $size,
        );
        last if $last;   # all done if  is set
    }
    $err and $et->Warn('Format error in FLAC file');
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::FLAC - Read Free Lossless Audio Codec information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Free Lossless Audio Codec (FLAC) audio files.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://flac.sourceforge.net/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/FLAC Tags>,
L<Image::ExifTool::TagNames/Ogg Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

