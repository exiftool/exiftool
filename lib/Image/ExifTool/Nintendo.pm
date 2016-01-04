#------------------------------------------------------------------------------
# File:         Nintendo.pm
#
# Description:  Nintendo EXIF maker notes tags
#
# Revisions:    2014/03/25 - P. Harvey Created
#
# References:   1) http://3dbrew.org/wiki/MPO
#------------------------------------------------------------------------------

package Image::ExifTool::Nintendo;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.00';

%Image::ExifTool::Nintendo::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    # 0x1000 - undef[28]
    # 0x1001 - undef[8]
    # 0x1100 - undef[80] (found in MPO files)
    0x1101 => {
        Name => 'CameraInfo',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Nintendo::CameraInfo',
            ByteOrder => 'Little-endian',
        },
    },
);

# Nintendo MPO info (ref 1)
%Image::ExifTool::Nintendo::CameraInfo = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    PRIORITY => 0,
    FORMAT => 'int8u',
    FIRST_ENTRY => 0,
    0x00 => { # "3DS1"
        Name => 'ModelID',
        Format => 'undef[4]',
    },
    # 0x04 - int32u: 1,2,4,5
    0x08 => {
        Name => 'TimeStamp',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        # zero time is 2000/01/01 (10957 days after Unix time zero)
        ValueConv => 'ConvertUnixTime($val + 10957 * 24 * 3600)',
        ValueConvInv => 'GetUnixTime($val) - 10957 * 24 * 3600',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    # 0x10 - int32u: title ID low
    # 0x14 - int32u: flags
    0x18 => {
        Name => 'InternalSerialNumber',
        Groups => { 2 => 'Camera' },
        Format => 'undef[4]',
        ValueConv => '"0x" . unpack("H*",$val)',
        ValueConvInv => '$val=~s/^0x//; pack("H*",$val)',
    },
    0x28 => {
        Name => 'Parallax',
        Format => 'float',
        PrintConv => 'sprintf("%.2f", $val)',
        PrintConvInv => '$val',
    },
    0x30 => {
        Name => 'Category',
        Format => 'int16u',
        PrintHex => 1,
        PrintConv => {
            0x0000 => '(none)',
            0x1000 => 'Mii',
            0x2000 => 'Man',
            0x4000 => 'Woman',
        },
    },
    # 0x32 - int16u: filter
);

1;  # end

__END__

=head1 NAME

Image::ExifTool::Nintendo - Nintendo EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to
interpret Nintendo maker notes EXIF meta information.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://3dbrew.org/wiki/MPO>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Nintendo Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
