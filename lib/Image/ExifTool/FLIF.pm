#------------------------------------------------------------------------------
# File:         FLIF.pm
#
# Description:  Read FLIF meta information
#
# Revisions:    2016/10/11 - P. Harvey Created
#
# References:   1) http://flif.info/
#------------------------------------------------------------------------------

package Image::ExifTool::FLIF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

# FLIF tags
%Image::ExifTool::FLIF::Main = (
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    VARS => { HEX_ID => 0 },
    NOTES => q{
        Tags read from Free Lossless Image Format files.  See L<http://flif.info/>
        for more information.
    },
#
# header information
#
    0 => {
        Name => 'ImageType',
        PrintConv => {
            '1' => 'Grayscale, non-interlaced',
            '3' => 'RGB, non-interlaced',
            '4' => 'RGBA, non-interlaced',
            'A' => 'Grayscale',
            'C' => 'RGB, interlaced',
            'D' => 'RGBA, interlaced',
            'Q' => 'Grayscale, non-interlaced',
            'S' => 'RGB, non-interlaced',
            'T' => 'RGBA, non-interlaced',
            'a' => 'Grayscale',
            'c' => 'RGB, interlaced',
            'd' => 'RGBA, interlaced',
        },
    },
    1 => {
        Name => 'BitDepth',
        PrintConv => {
            '0' => 'Custom',
            '1' => 8,
            '2' => 16,
        },
    },
    2 => 'ImageWidth',
    3 => 'ImageHeight',
    4 => 'Frames',
#
# metadata chunks
#
    iCCP => {
        Name => 'ICC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    eXif => {
        Name => 'EXIF',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            Start => 6, # (skip "Exif\0\0" header)
        },
    },
    eXmp => {
        Name => 'XMP',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
    # tRko - list of truncation offsets
    # \0 - FLIF16-format image data
);

#------------------------------------------------------------------------------
# Read variable-length FLIF integer
# Inputs: 0) raf reference
# Returns: integer, or undef on EOF
sub GetVarInt($)
{
    my $raf = shift;
    my ($val, $buff);
    for ($val=0; ; $val<<=7) {
        $raf->Read($buff, 1) or return undef;
        my $byte = ord($buff);
        $val |= ($byte & 0x7f);
        last unless $byte & 0x80;
    }
    return $val;
}

#------------------------------------------------------------------------------
# Extract information from an FLIF file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid FLIF file
sub ProcessFLIF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my $binary = $et->Options('Binary') || $verbose;
    my ($buff, $frames, $tag, $stat, $inflated);

    # verify this is a valid FLIF file
    return 0 unless $raf->Read($buff, 6) == 6;
    return 0 unless $buff =~ /^FLIF[0-\x6f][0-2]/;

    # decode header information ("FLIF" box)
    my $type = substr($buff, 4, 1);
    my $depth = substr($buff, 5, 1);
    my $width = GetVarInt($raf);
    my $height = GetVarInt($raf);
    return 0 unless defined $width and defined $height;
    if ($type gt 'H') {
        $frames = GetVarInt($raf);
        return 0 unless defined $frames;
    }

    $et->SetFileType();
    my $tagTablePtr = GetTagTable('Image::ExifTool::FLIF::Main');

    $et->HandleTag($tagTablePtr, 0, $type);
    $et->HandleTag($tagTablePtr, 1, $depth);
    $et->HandleTag($tagTablePtr, 2, $width + 1);
    $et->HandleTag($tagTablePtr, 3, $height + 1);
    $et->HandleTag($tagTablePtr, 4, $frames + 2) if defined $frames;

    # read through the other FLIF boxes
    for (;;) {
        $raf->Read($tag, 4) == 4 or $et->Warn('Unexpected EOF'), last;
        last if substr($tag, 0, 1) lt 'A';
        my $size = GetVarInt($raf);
        $et->VPrint(0, "FLIF $tag ($size bytes):\n") if $verbose;
        if ($$tagTablePtr{$tag} and $size < 10000000) {
            $raf->Read($buff, $size) == $size or $et->Warn("Truncated FLIF $tag box"), last;
            $et->VerboseDump(\$buff, Addr => $raf->Tell() - $size) if $verbose > 2;
            # inflate the compressed data
            if (eval { require IO::Uncompress::RawInflate }) {
                if (IO::Uncompress::RawInflate::rawinflate(\$buff => \$inflated)) {
                    $et->HandleTag($tagTablePtr, $tag, $inflated,
                        DataPt => \$inflated,
                        Size => length $inflated,
                        Extra => ' inflated',
                    );
                } else {
                    $et->Warn("Error inflating FLIF $tag box");
                }
            } else {
                $et->WarnOnce('Install IO::Uncompress::RawInflate to decode FLIF metadata');
            }
        } else {
            $raf->Seek($size, 1) or $et->Warn('Seek error'), last;
        }
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::FLIF - Read FLIF meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from FLIF (Free Lossless Image Format) images.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://flif.info/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/FLIF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

