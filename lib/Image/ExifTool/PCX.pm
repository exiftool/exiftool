#------------------------------------------------------------------------------
# File:         PCX.pm
#
# Description:  Read metadata from PC Paintbrush files
#
# Revisions:    2018/12/12 - P. Harvey Created
#
# References:   1) http://qzx.com/pc-gpe/pcx.txt
#               2) https://www.fileformat.info/format/pcx/corion.htm
#------------------------------------------------------------------------------

package Image::ExifTool::PCX;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

# PCX info
%Image::ExifTool::PCX::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    NOTES => 'Tags extracted from PC Paintbrush images.',
    DATAMEMBER => [ 0x04, 0x05 ],
    0x00 => {
        Name => 'Manufacturer',
        PrintConv => { 10 => 'ZSoft' },
    },
    0x01 => {
        Name => 'Software',
        PrintConv => {
            0 => 'PC Paintbrush 2.5',
            2 => 'PC Paintbrush 2.8 (with palette)',
            3 => 'PC Paintbrush 2.8 (without palette)',
            4 => 'PC Paintbrush for Windows',
            5 => 'PC Paintbrush 3.0+',
        },
    },
    0x02 => { Name => 'Encoding', PrintConv => { 1 => 'RLE' } },
    0x03 => 'BitsPerPixel',
    0x04 => {
        Name => 'LeftMargin',
        Format => 'int16u',
        RawConv => '$$self{LeftMargin} = $val',
    },
    0x06 => {
        Name => 'TopMargin',
        Format => 'int16u',
        RawConv => '$$self{TopMargin} = $val',
    },
    0x08 => {
        Name => 'ImageWidth',
        Format => 'int16u',
        Notes => 'adjusted for LeftMargin',
        ValueConv => '$val - $$self{LeftMargin} + 1',
    },
    0x0a => {
        Name => 'ImageHeight',
        Format => 'int16u',
        Notes => 'adjusted for TopMargin',
        ValueConv => '$val - $$self{TopMargin} + 1',
    },
    0x0c => 'XResolution',
    0x0e => 'YResolution',
    0x41 => 'ColorPlanes',
    0x42 => { Name => 'BytesPerLine', Format => 'int16u' },
    0x44 => {
        Name => 'ColorMode',
        PrintConv => {
            0 => 'n/a',
            1 => 'Color Palette',
            2 => 'Grayscale',
        },
    },
    0x46 => { Name => 'ScreenWidth',  Format => 'int16u', RawConv => '$val or undef' },
    0x48 => { Name => 'ScreenHeight', Format => 'int16u', RawConv => '$val or undef' },
);

#------------------------------------------------------------------------------
# Extract information from a PCX image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid PCX file
sub ProcessPCX($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;
    return 0 unless $raf->Read($buff, 0x50) == 0x50 and
                    $buff =~ /^\x0a[\0-\x05]\x01[\x01\x02\x04\x08].{64}[\0-\x02]/s;
    SetByteOrder('II');
    $et->SetFileType();
    my %dirInfo = ( DirName => 'PCX', DataPt => \$buff );
    my $tagTablePtr = GetTagTable('Image::ExifTool::PCX::Main');
    return $et->ProcessBinaryData(\%dirInfo, $tagTablePtr);
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::PCX - Read metadata from PC Paintbrush files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
information from PC Paintbrush (PCX) files.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://qzx.com/pc-gpe/pcx.txt>

=item L<https://www.fileformat.info/format/pcx/corion.htm>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PCX Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

