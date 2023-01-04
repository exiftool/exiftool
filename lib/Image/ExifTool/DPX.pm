#------------------------------------------------------------------------------
# File:         DPX.pm
#
# Description:  Read DPX meta information
#
# Revisions:    2013-09-19 - P. Harvey created
#
# References:   1) http://www.cineon.com/ff_draft.php
#               2) Harry Mallon private communication
#------------------------------------------------------------------------------

package Image::ExifTool::DPX;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.06';

# DPX tags
%Image::ExifTool::DPX::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    NOTES => 'Tags extracted from DPX (Digital Picture Exchange) images.',
    0   => { Name => 'ByteOrder',     Format => 'undef[4]', PrintConv => { SDPX => 'Big-endian', XPDS => 'Little-endian' } },
    8   => { Name => 'HeaderVersion', Format => 'string[8]' },
    # 24 => { Name => 'GenericHeaderSize', Format => 'int32u' }, # = 1664
    # 28 => { Name => 'IndustryStandardHeaderSize', Format => 'int32u' }, # = 384
    16  => { Name => 'DPXFileSize',   Format => 'int32u' },
    20  => { Name => 'DittoKey',      Format => 'int32u', PrintConv => { 0 => 'Same', 1 => 'New' } },
    36  => { Name => 'ImageFileName', Format => 'string[100]' },
    136 => {
        Name => 'CreateDate',
        Format => 'string[24]',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/(\d{4}:\d{2}:\d{2}):/$1 /; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    160 => { Name => 'Creator',       Format => 'string[100]', Groups => { 2 => 'Author' } },
    260 => { Name => 'Project',       Format => 'string[200]' },
    460 => { Name => 'Copyright',     Format => 'string[200]', Groups => { 2 => 'Author' } },
    660 => { Name => 'EncryptionKey', Format => 'int32u', PrintConv => 'sprintf("%.8x",$val)' },
    768 => {
        Name => 'Orientation',
        Format => 'int16u',
        PrintConv => {
            0 => 'Horizontal (normal)',
            1 => 'Mirror vertical',
            2 => 'Mirror horizontal',
            3 => 'Rotate 180',
            4 => 'Mirror horizontal and rotate 270 CW',
            5 => 'Rotate 90 CW',
            6 => 'Rotate 270 CW',
            7 => 'Mirror horizontal and rotate 90 CW',
        },
    },
    770 => { Name => 'ImageElements', Format => 'int16u' },
    772 => { Name => 'ImageWidth',    Format => 'int32u' },
    776 => { Name => 'ImageHeight',   Format => 'int32u' },
    780 => { Name => 'DataSign',      Format => 'int32u', PrintConv => { 0 => 'Unsigned', 1 => 'Signed' } },
    800 => {
        Name => 'ComponentsConfiguration',
        Format => 'int8u',
        PrintConv => {
            0 => 'User-defined single component',
            1 => 'Red (R)',
            2 => 'Green (G)',
            3 => 'Blue (B)',
            4 => 'Alpha (matte)',
            6 => 'Luminance (Y)',
            7 => 'Chrominance (Cb, Cr, subsampled by two)',
            8 => 'Depth (Z)',
            9 => 'Composite video',
            50 => 'R, G, B',
            51 => 'R, G, B, Alpha',
            52 => 'Alpha, B, G, R',
            100 => 'Cb, Y, Cr, Y (4:2:2)',
            101 => 'Cb, Y, A, Cr, Y, A (4:2:2:4)',
            102 => 'Cb, Y, Cr (4:4:4)',
            103 => 'Cb, Y, Cr, A (4:4:4:4)',
            150 => 'User-defined 2 component element',
            151 => 'User-defined 3 component element',
            152 => 'User-defined 4 component element',
            153 => 'User-defined 5 component element',
            154 => 'User-defined 6 component element',
            155 => 'User-defined 7 component element',
            156 => 'User-defined 8 component element',
        },
    },
    801 => { #2
        Name => 'TransferCharacteristic',
        Format => 'int8u',
        PrintConv => {
            0 => 'User-defined',
            1 => 'Printing density',
            2 => 'Linear',
            3 => 'Logarithmic',
            4 => 'Unspecified video',
            5 => 'SMPTE 274M',
            6 => 'ITU-R 704-4',
            7 => 'ITU-R 601-5 system B or G (625)',
            8 => 'ITU-R 601-5 system M (525)',
            9 => 'Composite video (NTSC)',
            10 => 'Composite video (PAL)',
            11 => 'Z (depth) - linear',
            12 => 'Z (depth) - homogeneous',
            13 => 'SMPTE ADX',
            14 => 'ITU-R 2020 NCL',
            15 => 'ITU-R 2020 CL',
            16 => 'IEC 61966-2-4 xvYCC',
            17 => 'ITU-R 2100 NCL/PQ',
            18 => 'ITU-R 2100 ICtCp/PQ',
            19 => 'ITU-R 2100 NCL/HLG',
            20 => 'ITU-R 2100 ICtCp/HLG',
            21 => 'RP 431-2:2011 Gama 2.6',
            22 => 'IEC 61966-2-1 sRGB',
        },
    },
    802 => { #2
        Name => 'ColorimetricSpecification',
        Format => 'int8u',
        PrintConv => {
            0 => 'User-defined',
            1 => 'Printing density',
            4 => 'Unspecified video',
            5 => 'SMPTE 274M',
            6 => 'ITU-R 704-4',
            7 => 'ITU-R 601-5 system B or G (625)',
            8 => 'ITU-R 601-5 system M (525)',
            9 => 'Composite video (NTSC)',
            10 => 'Composite video (PAL)',
            13 => 'SMPTE ADX',
            14 => 'ITU-R 2020',
            15 => 'P3D65',
            16 => 'P3DCI',
            17 => 'P3D60',
            18 => 'ACES',
        },
    },
    803 => { Name => 'BitDepth',      Format => 'int8u' },
    820 => { Name => 'ImageDescription',  Format => 'string[32]' },
    892 => { Name => 'Image2Description', Format => 'string[32]', RawConv => '$val=~/[^\xff]/ ? $val : undef' },
    964 => { Name => 'Image3Description', Format => 'string[32]', RawConv => '$val=~/[^\xff]/ ? $val : undef' },
    1036=> { Name => 'Image4Description', Format => 'string[32]', RawConv => '$val=~/[^\xff]/ ? $val : undef' },
    1108=> { Name => 'Image5Description', Format => 'string[32]', RawConv => '$val=~/[^\xff]/ ? $val : undef' },
    1180=> { Name => 'Image6Description', Format => 'string[32]', RawConv => '$val=~/[^\xff]/ ? $val : undef' },
    1252=> { Name => 'Image7Description', Format => 'string[32]', RawConv => '$val=~/[^\xff]/ ? $val : undef' },
    1324=> { Name => 'Image8Description', Format => 'string[32]', RawConv => '$val=~/[^\xff]/ ? $val : undef' },
    # 1408=> { Name => 'XOffset',           Format => 'int32u' },
    # 1412=> { Name => 'YOffset',           Format => 'int32u' },
    # 1416=> { Name => 'XCenter',           Format => 'float' },
    # 1420=> { Name => 'YCenter',           Format => 'float' },
    # 1424=> { Name => 'XOriginalSize',     Format => 'int32u' },
    # 1428=> { Name => 'YOriginalSize',     Format => 'int32u' },
    1432=> { Name => 'SourceFileName',    Format => 'string[100]' },
    1532=> { Name => 'SourceCreateDate',  Format => 'string[24]' },
    1556=> { Name => 'InputDeviceName',   Format => 'string[32]' },
    1588=> { Name => 'InputDeviceSerialNumber', Format => 'string[32]' },
    # 1620 => { Name => 'Border',           Format => 'int16u[4]' },
    1628 => {
        Name => 'AspectRatio',
        Format => 'int32u[2]',
        RawConv => '$val =~ /4294967295/ ? undef : $val', # ignore undefined values
        PrintConv => q{
            return 'undef' if $val eq '0 0';
            return 'inf' if $val=~/ 0$/;
            my @a=split(' ',$val);
            return join(':', Rationalize($a[0]/$a[1]));
        },
    },
    1724 => { Name => 'OriginalFrameRate',Format => 'float' },
    1728 => { Name => 'ShutterAngle',     Format => 'float', RawConv => '($val =~ /\d/ and $val !~ /nan/i) ? $val : undef' }, #2
    1732 => { Name => 'FrameID',          Format => 'string[32]' },
    1764 => { Name => 'SlateInformation', Format => 'string[100]' },
    1920 => { Name => 'TimeCode',         Format => 'int32u' }, #2
    1940 => { Name => 'FrameRate',        Format => 'float', RawConv => '($val =~ /\d/ and $val !~ /nan/i) ? $val : undef' }, #2
    1972 => { Name => 'Reserved5',        Format => 'string[76]', Unknown => 1 },
    2048 => { Name => 'UserID',           Format => 'string[32]' },
);

#------------------------------------------------------------------------------
# Extract EXIF information from a DPX image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid DPX file
sub ProcessDPX($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;

    # verify this is a valid DPX file
    return 0 unless $raf->Read($buff, 2080) == 2080;
    return 0 unless $buff =~ /^(SDPX|XPDS)/;
    SetByteOrder($1 eq 'SDPX' ? 'MM' : 'II');
    $et->SetFileType();   # set the FileType tag
    my $hdrLen = Get32u(\$buff,24) + Get32u(\$buff,28);
    $hdrLen == 2048 or $et->Warn("Unexpected DPX header length ($hdrLen)");
    my %dirInfo = (
        DataPt => \$buff,
        DirStart => 0,
        DirLen => length($buff),
    );
    my $tagTablePtr = GetTagTable('Image::ExifTool::DPX::Main');
    $et->ProcessDirectory(\%dirInfo, $tagTablePtr);

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::DPX - Read DPX meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read
metadata from DPX (Digital Picture Exchange) images.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cineon.com/ff_draft.php>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/DPX Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

