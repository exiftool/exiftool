#------------------------------------------------------------------------------
# File:         PGF.pm
#
# Description:  Read Progressive Graphics File meta information
#
# Revisions:    2011/01/25 - P. Harvey Created
#
# References:   1) http://www.libpgf.org/
#               2) http://www.exiv2.org/
#------------------------------------------------------------------------------

package Image::ExifTool::PGF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.02';

# PGF header information
%Image::ExifTool::PGF::Main = (
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    PRIORITY => 2,  # (to take precedence over PNG tags from embedded image)
    NOTES => q{
        The following table lists information extracted from the header of
        Progressive Graphics File (PGF) images.  As well, information is extracted
        from the embedded PNG metadata image if it exists.  See
        L<http://www.libpgf.org/> for the PGF specification.
    },
    3  => {
        Name => 'PGFVersion',
        PrintConv => 'sprintf("0x%.2x", $val)',
        # this is actually a bitmask (ref digikam PGFtypes.h):
        # 0x02 - data structure PGFHeader of major version 2
        # 0x04 - 32-bit values
        # 0x08 - supports regions of interest
        # 0x10 - new coding scheme since major version 5
        # 0x20 - new HeaderSize: 32 bits instead of 16 bits
    },
    8  => { Name => 'ImageWidth',  Format => 'int32u' },
    12 => { Name => 'ImageHeight', Format => 'int32u' },
    16 => 'PyramidLevels',
    17 => 'Quality',
    18 => 'BitsPerPixel',
    19 => 'ColorComponents',
    20 => {
        Name => 'ColorMode',
        RawConv => '$$self{PGFColorMode} = $val',
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Bitmap',
            1 => 'Grayscale',
            2 => 'Indexed',
            3 => 'RGB',
            4 => 'CMYK',
            7 => 'Multichannel',
            8 => 'Duotone',
            9 => 'Lab',
        },
    },
    21 => { Name => 'BackgroundColor', Format => 'int8u[3]' },
);

#------------------------------------------------------------------------------
# Extract information from a PGF image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid PGF file
sub ProcessPGF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;

    # read header and check magic number
    return 0 unless $raf->Read($buff, 24) == 24 and $buff =~ /^PGF(.)/s;
    my $ver = ord $1;
    $et->SetFileType();
    SetByteOrder('II');

    # currently support only version 0x36
    unless ($ver == 0x36) {
        $et->Error(sprintf('Unsupported PGF version 0x%.2x', $ver));
        return 1;
    }
    # extract information from the PGF header
    my $tagTablePtr = GetTagTable('Image::ExifTool::PGF::Main');
    $et->ProcessDirectory({ DataPt => \$buff, DataPos => 0 }, $tagTablePtr);

    my $len = Get32u(\$buff, 4) - 16; # length of post-header data

    # skip colour table if necessary
    $len -= $raf->Seek(1024, 1) ? 1024 : $len if $$et{PGFColorMode} == 2;

    # extract information from the embedded metadata image (PNG format)
    if ($len > 0 and $len < 0x1000000 and $raf->Read($buff, $len) == $len) {
        $et->ExtractInfo(\$buff, { ReEntry => 1 });
    }
    return 1;
}


1;  # end

__END__

=head1 NAME

Image::ExifTool::PGF - Read Progressive Graphics File meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Progressive Graphics File (PGF) images.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.libpgf.org/>

=item L<http://www.exiv2.org/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PGF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

