#------------------------------------------------------------------------------
# File:         BPG.pm
#
# Description:  Read BPG meta information
#
# Revisions:    2016-07-05 - P. Harvey Created
#
# References:   1) http://bellard.org/bpg/
#------------------------------------------------------------------------------

package Image::ExifTool::BPG;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

# BPG information
%Image::ExifTool::BPG::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    NOTES => q{
        The information listed below is extracted from BPG (Better Portable
        Graphics) images.  See L<http://bellard.org/bpg/> for the specification.
    },
    4 => {
        Name => 'PixelFormat',
        Format => 'int16u',
        Mask => 0xe000,
        PrintConv => {
            0x0000 => 'Grayscale',
            0x2000 => '4:2:0 (chroma at 0.5, 0.5)',
            0x4000 => '4:2:2 (chroma at 0.5, 0)',
            0x6000 => '4:4:4',
            0x8000 => '4:2:0 (chroma at 0, 0.5)',
            0xa000 => '4:2:2 (chroma at 0, 0)',
        },
    },
    4.1 => {
        Name => 'Alpha',
        Format => 'int16u',
        Mask => 0x1004,
        PrintConv => {
            0x0000 => 'No Alpha Plane',
            0x1000 => 'Alpha Exists (color not premultiplied)',
            0x1004 => 'Alpha Exists (color premultiplied)',
            0x0004 => 'Alpha Exists (W color component)',
        },
    },
    4.2 => {
        Name => 'BitDepth',
        Format => 'int16u',
        Mask => 0x0f00,
        ValueConv => '($val >> 8) + 8',
    },
    4.3 => {
        Name => 'ColorSpace',
        Format => 'int16u',
        Mask => 0x00f0,
        PrintConv => {
            0x0000 => 'YCbCr (BT 601)',
            0x0010 => 'RGB',
            0x0020 => 'YCgCo',
            0x0030 => 'YCbCr (BT 709)',
            0x0040 => 'YCbCr (BT 2020)',
            0x0050 => 'BT 2020 Constant Luminance',
        },
    },
    4.4 => {
        Name => 'Flags',
        Format => 'int16u',
        Mask => 0x000b,
        PrintConv => { BITMASK => {
            0 => 'Animation',
            1 => 'Limited Range',
            3 => 'Extension Present',
        }},
    },
    6 => { Name => 'ImageWidth',    Format => 'var_ue7' },
    7 => { Name => 'ImageHeight',   Format => 'var_ue7' },
    # length of image data or 0 to EOF
    # (must be decoded so we know where the extension data starts)
    8 => { Name => 'ImageLength',   Format => 'var_ue7' },
);

%Image::ExifTool::BPG::Extensions = (
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    VARS => { ALPHA_FIRST => 1 },
    1 => {
        Name => 'EXIF',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
        },
    },
    2 => {
        Name => 'ICC_Profile',
        SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::Main' },
    },
    3 => {
        Name => 'XMP',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
    4 => {
        Name => 'ThumbnailBPG',
        Binary => 1,
    },
    5 => {
        Name => 'AnimationControl',
        Binary => 1,
        Unknown => 1,
    },
);

#------------------------------------------------------------------------------
# Get ue7 integer from binary data (max 32 bits)
# Inputs: 0) data ref, 1) location in data (undef for 0)
# Returns: 0) ue7 as integer or undef on error, 1) length of ue7 in bytes
sub Get_ue7($;$)
{
    my $dataPt = shift;
    my $pos = shift || 0;
    my $size = length $$dataPt;
    my $val = 0;
    my $i;
    for ($i=0; ; ) {
        return() if $pos+$i >= $size or $i >= 5;
        my $byte = Get8u($dataPt, $pos + $i);
        $val = ($val << 7) | ($byte & 0x7f);
        unless ($byte & 0x80) {
            return() if $i == 4 and $byte & 0x70;   # error if bits 32-34 are set
            last;   # this was the last byte
        }
        return() if $i == 0 and $byte == 0x80;      # error if first byte is 0x80
        ++$i;       # step to the next byte
    }
    return($val, $i+1);
}

#------------------------------------------------------------------------------
# Extract EXIF information from a BPG image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid BPG file
sub ProcessBPG($$)
{
    local $_;
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $size, $n, $len, $pos);

    # verify this is a valid BPG file
    return 0 unless $raf->Read($buff, 21) == 21; # (21 bytes is maximum header length)
    return 0 unless $buff =~ /^BPG\xfb/;
    $et->SetFileType();   # set the FileType tag

    SetByteOrder('MM');
    my %dirInfo = (
        DataPt   => \$buff,
        DirStart => 0,
        DirLen   => length($buff),
        VarFormatData => [ ],
    );
    $et->ProcessDirectory(\%dirInfo, GetTagTable('Image::ExifTool::BPG::Main'));

    return 1 unless $$et{VALUE}{Flags} & 0x0008;  # all done unless extension flag is set

    # add varSize from last entry in VarFormatData to determine
    # the current read position in the file
    my $dataPos = 9 + $dirInfo{VarFormatData}[-1][1];
    # read extension length
    unless ($raf->Seek($dataPos, 0) and $raf->Read($buff, 5) == 5) {
        $et->Warn('Missing BPG extension data');
        return 1;
    }
    ($size, $n) = Get_ue7(\$buff);
    defined $size or $et->Warn('Corrupted BPG extension length'), return 1;
    $dataPos += $n;
    $size > 10000000 and $et->Warn('BPG extension is too large'), return 1;
    unless ($raf->Seek($dataPos, 0) and $raf->Read($buff, $size) == $size) {
        $et->Warn('Truncated BPG extension');
        return 1;
    }
    my $tagTablePtr = GetTagTable('Image::ExifTool::BPG::Extensions');
    # loop through the individual extensions
    for ($pos=0; $pos<$size; $pos+=$len) {
        my $type = Get8u(\$buff, $pos);
        # get length of this extension
        ($len, $n) = Get_ue7(\$buff, ++$pos);
        defined $len or $et->Warn('Corrupted BPG extension'), last;
        $pos += $n; # point to start of data for this extension
        $pos + $len > $size and $et->Warn('Invalid BPG extension size'), last;
        $$tagTablePtr{$type} or $et->Warn("Unrecognized BPG extension $type ($len bytes)", 1), next;
        # libbpg (in my opinion) incorrectly copies the padding byte after the
        # "EXIF\0" APP1 header to the start of the BPG EXIF extension, so issue a
        # minor warning and ignore the padding if we find it before the TIFF header
        if ($type == 1 and $len > 3 and substr($buff,$pos,3)=~/^.(II|MM)/s) {
            $et->Warn("Ignored extra byte at start of EXIF extension", 1);
            ++$pos;
            --$len;
        }
        $et->HandleTag($tagTablePtr, $type, undef,
            DataPt  => \$buff,
            DataPos => $dataPos,
            Start   => $pos,
            Size    => $len,
            Parent  => 'BPG',
        );
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::BPG - Read BPG meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read BPG
(Better Portable Graphics) images.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://bellard.org/bpg/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/BPG Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

