#------------------------------------------------------------------------------
# File:         Theora.pm
#
# Description:  Read Theora video meta information
#
# Revisions:    2011/07/13 - P. Harvey Created
#
# References:   1) http://www.theora.org/doc/Theora.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::Theora;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

# Theora header types
%Image::ExifTool::Theora::Main = (
    NOTES => q{
        Information extracted from Ogg Theora video files.  See
        L<http://www.theora.org/doc/Theora.pdf> for the Theora specification.
    },
    0x80 => {
        Name => 'Identification',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Theora::Identification',
            ByteOrder => 'BigEndian',
        },
    },
    0x81 => {
        Name => 'Comments',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Vorbis::Comments',
        },
    },
    # 0x82 - Setup
);

# tags extracted from Theora Idenfication header
%Image::ExifTool::Theora::Identification = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Video' },
    NOTES => 'Tags extracted from the Theora identification header.',
    0 => {
        Name => 'TheoraVersion',
        Format => 'int8u[3]',
        PrintConv => '$val =~ tr/ /./; $val',
    },
    7 => {
        Name => 'ImageWidth',
        Format => 'int32u',
        ValueConv => '$val >> 8',
    },
    10 => {
        Name => 'ImageHeight',
        Format => 'int32u',
        ValueConv => '$val >> 8',
    },
    13 => 'XOffset',
    14 => 'YOffset',
    15 => {
        Name => 'FrameRate',
        Format => 'rational64u',
        PrintConv => 'int($val * 1000 + 0.5) / 1000',
    },
    23 => {
        Name => 'PixelAspectRatio',
        Format => 'int16u[3]',
        ValueConv => 'my @a=split(" ",$val); (($a[0]<<8)+($a[1]>>8)) / ((($a[1]&0xff)<<8)+$a[2])',
        PrintConv => 'int($val * 1000 + 0.5) / 1000',
    },
    29 => {
        Name => 'ColorSpace',
        PrintConv => {
            0 => 'Undefined',
            1 => 'Rec. 470M',
            2 => 'Rec. 470BG',
        },
    },
    30 => {
        Name => 'NominalVideoBitrate',
        Format => 'int32u',
        ValueConv => '$val >> 8',
        PrintConv => {
            0 => 'Unspecified',
            OTHER => \&Image::ExifTool::ConvertBitrate,
        },
    },
    33 => {
        Name => 'Quality',
        ValueConv => '$val >> 2',
    },
    34 => {
        Name => 'PixelFormat',
        ValueConv => '($val >> 3) & 0x3',
        PrintConv => {
            0 => '4:2:0',
            2 => '4:2:2',
            3 => '4:4:4',
        },
    },
);

1;  # end

__END__

=head1 NAME

Image::ExifTool::Theora - Read Theora video meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Theora video streams.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.theora.org/doc/Theora.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Theora Tags>,
L<Image::ExifTool::TagNames/Ogg Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

