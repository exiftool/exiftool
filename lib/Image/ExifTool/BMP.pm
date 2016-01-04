#------------------------------------------------------------------------------
# File:         BMP.pm
#
# Description:  Read BMP meta information
#
# Revisions:    07/16/2005 - P. Harvey Created
#
# References:   1) http://www.fortunecity.com/skyscraper/windows/364/bmpffrmt.html
#               2) http://www.fourcc.org/rgb.php
#------------------------------------------------------------------------------

package Image::ExifTool::BMP;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.08';

# BMP chunks
%Image::ExifTool::BMP::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    NOTES => q{
        There really isn't much meta information in a BMP file as such, just a bit
        of image related information.
    },
    # 0 => size of bitmap structure:
    #        12  bytes => 'OS/2 V1',
    #        40  bytes => 'Windows V3',
    #        64  bytes => 'OS/2 V2',
    #        68  bytes => some bitmap structure in AVI videos
    #        108 bytes => 'Windows V4',
    #        124 bytes => 'Windows V5',
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
    },
    14 => {
        Name => 'BitDepth',
        Format => 'int16u',
    },
    16 => {
        Name => 'Compression',
        Format => 'int32u',
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
        PrintConv => '$val ? $val : "All"',
    },
);

# OS/2 12-byte bitmap header (ref http://www.fileformat.info/format/bmp/egff.htm)
%Image::ExifTool::BMP::OS2 = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    NOTES => 'Information extracted from OS/2-format BMP images.',
    # 0 => size of bitmap structure (12)
    4  => { Name => 'ImageWidth',  Format => 'int16u' },
    6  => { Name => 'ImageHeight', Format => 'int16u' },
    8  => { Name => 'Planes',      Format => 'int16u' },
    10 => { Name => 'BitDepth',    Format => 'int16u' },
);

#------------------------------------------------------------------------------
# Extract EXIF information from a BMP image
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
    return 0 unless $len == 12 or $len >= 40;
    return 0 unless $raf->Seek(-4, 1) and $raf->Read($buff, $len) == $len;
    $et->SetFileType();   # set the FileType tag
    my %dirInfo = (
        DataPt => \$buff,
        DirStart => 0,
        DirLen => length($buff),
    );
    if ($len == 12) {   # old OS/2 format BMP
        $tagTablePtr = GetTagTable('Image::ExifTool::BMP::OS2');
    } else {
        $tagTablePtr = GetTagTable('Image::ExifTool::BMP::Main');
    }
    $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
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

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.fortunecity.com/skyscraper/windows/364/bmpffrmt.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/BMP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

