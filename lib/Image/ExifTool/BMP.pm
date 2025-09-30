#------------------------------------------------------------------------------
# File:         BMP.pm
#
# Description:  Read BMP meta information
#
# Revisions:    07/16/2005 - P. Harvey Created
#
# References:   1) http://www.fortunecity.com/skyscraper/windows/364/bmpffrmt.html
#               2) http://www.fourcc.org/rgb.php
#               3) https://msdn.microsoft.com/en-us/library/dd183381(v=vs.85).aspx
#------------------------------------------------------------------------------

package Image::ExifTool::BMP;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.09';

# conversions for fixed-point 2.30 format values
my %fixed2_30 = (
    ValueConv => q{
        my @a = split ' ', $val;
        $_ /= 0x40000000 foreach @a;
        "@a";
    },
    PrintConv => q{
        my @a = split ' ', $val;
        $_ = sprintf('%.6f', $_) foreach @a;
        "@a";
    },
);

# BMP chunks
%Image::ExifTool::BMP::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    NOTES => q{
        There really isn't much meta information in a BMP file as such, just a bit
        of image related information.
    },
    0 => {
        Name => 'BMPVersion',
        Format => 'int32u',
        Notes => q{
            this is actually the size of the BMP header, but used to determine the BMP
            version
        },
        RawConv => '$$self{BMPVersion} = $val',
        PrintConv => {
            40  => 'Windows V3',
            68  => 'AVI BMP structure?', #PH (seen in AVI movies from some Casio and Nikon cameras)
            108 => 'Windows V4',
            124 => 'Windows V5',
        },
    },
    4 => {
        Name => 'ImageWidth',
        Format => 'int32u',
    },
    8 => {
        Name => 'ImageHeight',
        Format => 'int32s', # (negative when stored in top-to-bottom order)
        ValueConv => 'abs($val)',
    },
    12 => {
        Name => 'Planes',
        Format => 'int16u',
        # values: 0,1,4,8,16,24,32
    },
    14 => {
        Name => 'BitDepth',
        Format => 'int16u',
    },
    16 => {
        Name => 'Compression',
        Format => 'int32u',
        RawConv => '$$self{BMPCompression} = $val',
        # (formatted as string[4] for some values in AVI images)
        ValueConv => '$val > 256 ? unpack("A4",pack("V",$val)) : $val',
        PrintConv => {
            0 => 'None',
            1 => '8-Bit RLE',
            2 => '4-Bit RLE',
            3 => 'Bitfields',
            4 => 'JPEG', #2
            5 => 'PNG', #2
            # pass through ASCII video compression codec ID's
            OTHER => sub {
                my $val = shift;
                # convert non-ascii characters
                $val =~ s/([\0-\x1f\x7f-\xff])/sprintf('\\x%.2x',ord $1)/eg;
                return $val;
            },
        },
    },
    20 => {
        Name => 'ImageLength',
        Format => 'int32u',
        RawConv => '$$self{BMPImageLength} = $val',
    },
    24 => {
        Name => 'PixelsPerMeterX',
        Format => 'int32u',
    },
    28 => {
        Name => 'PixelsPerMeterY',
        Format => 'int32u',
    },
    32 => {
        Name => 'NumColors',
        Format => 'int32u',
        PrintConv => '$val ? $val : "Use BitDepth"',
    },
    36 => {
        Name => 'NumImportantColors',
        Format => 'int32u',
        Hook => '$varSize += $size if $$self{BMPVersion} == 68', # (the rest is invalid for AVI BMP's)
        PrintConv => '$val ? $val : "All"',
    },
    40 => {
        Name => 'RedMask',
        Format => 'int32u',
        PrintConv => 'sprintf("0x%.8x",$val)',
    },
    44 => {
        Name => 'GreenMask',
        Format => 'int32u',
        PrintConv => 'sprintf("0x%.8x",$val)',
    },
    48 => {
        Name => 'BlueMask',
        Format => 'int32u',
        PrintConv => 'sprintf("0x%.8x",$val)',
    },
    52 => {
        Name => 'AlphaMask',
        Format => 'int32u',
        PrintConv => 'sprintf("0x%.8x",$val)',
    },
    56 => {
        Name => 'ColorSpace',
        Format => 'undef[4]',
        RawConv => '$$self{BMPColorSpace} = $val =~ /\0/ ? Get32u(\$val, 0) : pack("N",unpack("V",$val))',
        PrintConv => {
            0 => 'Calibrated RGB',
            1 => 'Device RGB',
            2 => 'Device CMYK',
            LINK => 'Linked Color Profile',
            MBED => 'Embedded Color Profile',
            sRGB => 'sRGB',
            'Win ' => 'Windows Color Space',
        },
    },
    60 => {
        Name => 'RedEndpoint',
        Condition => '$$self{BMPColorSpace} eq "0"',
        Format => 'int32u[3]',
        %fixed2_30,
    },
    72 => {
        Name => 'GreenEndpoint',
        Condition => '$$self{BMPColorSpace} eq "0"',
        Format => 'int32u[3]',
        %fixed2_30,
    },
    84 => {
        Name => 'BlueEndpoint',
        Condition => '$$self{BMPColorSpace} eq "0"',
        Format => 'int32u[3]',
        %fixed2_30,
    },
    96 => {
        Name => 'GammaRed',
        Condition => '$$self{BMPColorSpace} eq "0"',
        Format => 'fixed32u',
    },
    100 => {
        Name => 'GammaGreen',
        Condition => '$$self{BMPColorSpace} eq "0"',
        Format => 'fixed32u',
    },
    104 => {
        Name => 'GammaBlue',
        Condition => '$$self{BMPColorSpace} eq "0"',
        Format => 'fixed32u',
    },
    108 => {
        Name => 'RenderingIntent',
        Format => 'int32u',
        PrintConv => {
            1 => 'Graphic (LCS_GM_BUSINESS)',
            2 => 'Proof (LCS_GM_GRAPHICS)',
            4 => 'Picture (LCS_GM_IMAGES)',
            8 => 'Absolute Colorimetric (LCS_GM_ABS_COLORIMETRIC)',
        },
    },
    112 => {
        Name => 'ProfileDataOffset',
        Condition => '$$self{BMPColorSpace} eq "LINK" or $$self{BMPColorSpace} eq "MBED"',
        Format => 'int32u',
        RawConv => '$$self{BMPProfileOffset} = $val',
    },
    116 => {
        Name => 'ProfileSize',
        Condition => '$$self{BMPColorSpace} eq "LINK" or $$self{BMPColorSpace} eq "MBED"',
        Format => 'int32u',
        RawConv => '$$self{BMPProfileSize} = $val',
    },
    # 120 - reserved
);

# OS/2 12-byte bitmap header (ref http://www.fileformat.info/format/bmp/egff.htm)
%Image::ExifTool::BMP::OS2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    NOTES => 'Information extracted from OS/2-format BMP images.',
    0 => {
        Name => 'BMPVersion',
        Format => 'int32u',
        Notes => 'again, the header size is used to determine the BMP version',
        PrintConv => {
            12  => 'OS/2 V1',
            64  => 'OS/2 V2',
        },
    },
    4  => { Name => 'ImageWidth',  Format => 'int16u' },
    6  => { Name => 'ImageHeight', Format => 'int16u' },
    8  => { Name => 'Planes',      Format => 'int16u' },
    10 => { Name => 'BitDepth',    Format => 'int16u' },
);

%Image::ExifTool::BMP::Extra = (
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    NOTES => 'Extra information extracted from some BMP images.',
    VARS => { ID_FMT => 'none' },
    LinkedProfileName => { },
    ICC_Profile => { SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::Main' } },
    EmbeddedJPG => {
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
    EmbeddedPNG => {
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
);

#------------------------------------------------------------------------------
# Extract metadata from a BMP image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid BMP file
sub ProcessBMP($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $tagTablePtr);

    # verify this is a valid BMP file
    return 0 unless $raf->Read($buff, 18) == 18;
    return 0 unless $buff =~ /^BM/;
    SetByteOrder('II');
    my $len = Get32u(\$buff, 14);
    # len = v1:12, v4:108, v5:124
    return 0 unless $len == 12 or $len == 16 or ($len >= 40 and $len < 1000000);
    return 0 unless $raf->Seek(-4, 1) and $raf->Read($buff, $len) == $len;
    $et->SetFileType();   # set the FileType tag
#
# process the BMP header
#
    my %dirInfo = (
        DataPt => \$buff,
        DirStart => 0,
        DirLen => length($buff),
    );
    if ($len == 12 or $len == 16 or $len == 64) {   # old OS/2 format BMP
        $tagTablePtr = GetTagTable('Image::ExifTool::BMP::OS2');
    } else {
        $tagTablePtr = GetTagTable('Image::ExifTool::BMP::Main');
    }
    $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
#
# extract any embedded images
#
    my $extraTable = GetTagTable('Image::ExifTool::BMP::Extra');
    if ($$et{BMPCompression} and $$et{BMPImageLength} and
        ($$et{BMPCompression} == 4 or $$et{BMPCompression} == 5))
    {
        my $tag = $$et{BMPCompression} == 4 ? 'EmbeddedJPG' : 'EmbeddedPNG';
        my $val = $et->ExtractBinary($raf->Tell(), $$et{BMPImageLength}, $tag);
        if ($val) {
            $et->HandleTag($extraTable, $tag, $val);
        }
    }
#
# process profile data if it exists (v5 header only)
#
    if ($len == 124 and $$et{BMPProfileOffset}) {
        my $pos = $$et{BMPProfileOffset} + 14;  # (note the 14-byte shift!)
        my $size = $$et{BMPProfileSize};
        if ($raf->Seek($pos, 0) and $raf->Read($buff, $size) == $size) {
            my $tag;
            if ($$et{BMPColorSpace} eq 'LINK') {
                $buff =~ s/\0+$//;  # remove null terminator(s)
                $buff = $et->Decode($buff, 'Latin'); # convert from Latin
                $tag = 'LinkedProfileName';
            } else {
                $tag = 'ICC_Profile';
            }
            $et->HandleTag($extraTable, $tag => $buff, Size => $size, DataPos => $pos);
        } else {
            $et->Warn('Error loading profile data', 1);
        }
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::BMP - Read BMP meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read BMP
(Windows Bitmap) images.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.fortunecity.com/skyscraper/windows/364/bmpffrmt.html>

=item L<http://www.fourcc.org/rgb.php>

=item L<https://msdn.microsoft.com/en-us/library/dd183381(v=vs.85).aspx>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/BMP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
