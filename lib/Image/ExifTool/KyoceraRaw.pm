#------------------------------------------------------------------------------
# File:         KyoceraRaw.pm
#
# Description:  Read Kyocera RAW meta information
#
# Revisions:    02/17/2006 - P. Harvey Created
#
# References:   1) http://www.cybercom.net/~dcoffin/dcraw/
#------------------------------------------------------------------------------

package Image::ExifTool::KyoceraRaw;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.03';

sub ProcessRAW($$);

# utility to reverse order of characters in a string
sub ReverseString($) { pack('C*',reverse unpack('C*',shift)) }

# Contax N Digital tags (ref PH)
%Image::ExifTool::KyoceraRaw::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'Tags for Kyocera Contax N Digital RAW images.',
    0x01 => {
        Name => 'FirmwareVersion',
        Format => 'string[10]',
        ValueConv => \&ReverseString,
    },
    0x0c => {
        Name => 'Model',
        Format => 'string[12]',
        ValueConv => \&ReverseString,
    },
    0x19 => { #1
        Name => 'Make',
        Format => 'string[7]',
        ValueConv => \&ReverseString,
    },
    0x21 => { #1
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        Format => 'string[20]',
        ValueConv => \&ReverseString,
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x34 => {
        Name => 'ISO',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        PrintConv => {
            7 => 25,
            8 => 32,
            9 => 40,
            10 => 50,
            11 => 64,
            12 => 80,
            13 => 100,
            14 => 125,
            15 => 160,
            16 => 200,
            17 => 250,
            18 => 320,
            19 => 400,
        },
    },
    0x38 => {
        Name => 'ExposureTime',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '2**($val / 8) / 16000',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    0x3c => { #1
        Name => 'WB_RGGBLevels',
        Groups => { 2 => 'Image' },
        Format => 'int32u[4]',
    },
    0x58 => {
        Name => 'FNumber',
        Groups => { 2 => 'Image' },
        Format => 'int32u',
        ValueConv => '2**($val/16)',
        PrintConv => 'sprintf("%.2g",$val)',
    },
    0x68 => {
        Name => 'MaxAperture',
        Format => 'int32u',
        ValueConv => '2**($val/16)',
        PrintConv => 'sprintf("%.2g",$val)',
    },
    0x70 => {
        Name => 'FocalLength',
        Format => 'int32u',
        PrintConv => '"$val mm"',
    },
    0x7c => {
        Name => 'Lens',
        Format => 'string[32]',
    },
);

#------------------------------------------------------------------------------
# Extract information from Kyocera RAW image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 if this was a valid Kyocera RAW image
sub ProcessRAW($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $size = 156; # size of header
    my $buff;

    $raf->Read($buff, $size) == $size or return 0;
    # validate Make string ('KYOCERA' reversed)
    substr($buff, 0x19, 7) eq 'ARECOYK' or return 0;
    $et->SetFileType();
    SetByteOrder('MM');
    my %dirInfo = (
        DataPt => \$buff,
        DataPos => 0,
        DataLen => $size,
        DirStart => 0,
        DirLen => $size,
    );
    my $tagTablePtr = GetTagTable('Image::ExifTool::KyoceraRaw::Main');
    $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::KyoceraRaw - Read Kyocera RAW meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read
meta information from Kyocera Contax N Digital RAW images.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/KyoceraRaw Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
