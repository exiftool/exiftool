#------------------------------------------------------------------------------
# File:         MNG.pm
#
# Description:  MNG and JNG meta information tags
#
# Revisions:    06/23/2005 - P. Harvey Created
#
# References:   1) http://www.libpng.org/pub/mng/
#------------------------------------------------------------------------------

package Image::ExifTool::MNG;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

# MNG chunks
%Image::ExifTool::MNG::Main = (
    GROUPS => { 2 => 'Image' },
    NOTES => q{
        This table contains definitions for tags found in MNG and JNG images.  MNG
        is a superset of PNG and JNG, so a MNG image may contain any of these tags
        as well as any PNG tags.  Conversely, only some of these tags are valid for
        JNG images.
    },
    BACK => {
        Name => 'Background',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::Background' },
    },
    BASI => {
        Name => 'BasisObject',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::BasisObject' },
    },
    CLIP => {
        Name => 'ClipObjects',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::ClipObjects' },
    },
    CLON => {
        Name => 'CloneObject',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::CloneObject' },
    },
    DBYK => {
        Name => 'DropByKeyword',
        Binary => 1,
    },
    DEFI => {
        Name => 'DefineObject',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::DefineObject' },
    },
    DHDR => {
        Name => 'DeltaPNGHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::DeltaPNGHeader' },
    },
    DISC => {
        Name => 'DiscardObjects',
        ValueConv => 'join(" ",unpack("n*",$val))',
    },
    DROP => {
        Name => 'DropChunks',
        ValueConv => 'join(" ",$val=~/..../g)',
    },
#   ENDL
    eXPi => {
        Name => 'ExportImage',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::ExportImage' },
    },
    fPRI => {
        Name => 'FramePriority',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::FramePriority' },
    },
    FRAM => {
        Name => 'Frame',
        Binary => 1,
    },
#   IJNG
#   IPNG
#   JDAA (JNG)
#   JDAT (JNG)
    JHDR => { # (JNG)
        Name => 'JNGHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::JNGHeader' },
    },
#   JSEP (JNG)
    LOOP => {
        Name => 'Loop',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::Loop' },
    },
    MAGN => {
        Name => 'MagnifyObject',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::MagnifyObject' },
    },
#   MEND
    MHDR => {
        Name => 'MNGHeader',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::MNGHeader' },
    },
    MOVE => {
        Name => 'MoveObjects',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::MoveObjects' },
    },
    nEED => {
        Name => 'ResourcesNeeded',
        Binary => 1,
    },
    ORDR => {
        Name => 'OrderingRestrictions',
        Binary => 1,
    },
    PAST => {
        Name => 'PasteImage',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::PasteImage' },
    },
    pHYg => {
        Name => 'GlobalPixelSize',
        SubDirectory => { TagTable => 'Image::ExifTool::PNG::PhysicalPixel' },
    },
    PPLT => {
        Name => 'PartialPalette',
        Binary => 1,
    },
    PROM => {
        Name => 'PromoteParent',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::PromoteParent' },
    },
    SAVE => {
        Name => 'SaveObjects',
        Binary => 1,
    },
    SEEK => {
        Name => 'SeekPoint',
        ValueConv => '$val=~s/\0.*//s; $val',
    },
    SHOW => {
        Name => 'ShowObjects',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::ShowObjects' },
    },
    TERM => {
        Name => 'TerminationAction',
        SubDirectory => { TagTable => 'Image::ExifTool::MNG::TerminationAction' },
    },
);

# MNG MHDR chunk
%Image::ExifTool::MNG::MNGHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int32u',
    0 => 'ImageWidth',
    1 => 'ImageHeight',
    2 => 'TicksPerSecond',
    3 => 'NominalLayerCount',
    4 => 'NominalFrameCount',
    5 => 'NominalPlayTime',
    6 => {
        Name => 'SimplicityProfile',
        PrintConv => 'sprintf("0x%.8x", $val)',
    },
);

# MNG BASI chunk
%Image::ExifTool::MNG::BasisObject = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'ImageWidth',
        Format => 'int32u',
    },
    4 => {
        Name => 'ImageHeight',
        Format => 'int32u',
    },
    8 => 'BitDepth',
    9 => {
        Name => 'ColorType',
        RawConv => '$Image::ExifTool::PNG::colorType = $val',
        PrintConv => {
            0 => 'Grayscale',
            2 => 'RGB',
            3 => 'Palette',
            4 => 'Grayscale with Alpha',
            6 => 'RGB with Alpha',
        },
    },
    10 => {
        Name => 'Compression',
        PrintConv => { 0 => 'Deflate/Inflate' },
    },
    11 => {
        Name => 'Filter',
        PrintConv => { 0 => 'Adaptive' },
    },
    12 => {
        Name => 'Interlace',
        PrintConv => { 0 => 'Noninterlaced', 1 => 'Adam7 Interlace' },
    },
    13 => {
        Name => 'RedSample',
        Format => 'int32u',
    },
    17 => {
        Name => 'GreenSample',
        Format => 'int32u',
    },
    21 => {
        Name => 'BlueSample',
        Format => 'int32u',
    },
    25 => {
        Name => 'AlphaSample',
        Format => 'int32u',
    },
    26 => 'Viewable',
);

# MNG LOOP chunk
%Image::ExifTool::MNG::Loop = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => 'NestLevel',
    1 => {
        Name => 'IterationCount',
        Format => 'int32u',
    },
    5 => {
        Name => 'TerminationCondition',
        PrintConv => {
            0 => 'Deterministic, not cacheable',
            1 => 'Decoder discretion, not cacheable',
            2 => 'User discretion, not cacheable',
            3 => 'External signal, not cacheable',
            4 => 'Deterministic, cacheable',
            5 => 'Decoder discretion, cacheable',
            6 => 'User discretion, cacheable',
            7 => 'External signal, cacheable',
        },
    },
    6 => {
        Name => 'IterationMinMax',
        Format => 'int32u[2]',
    },
    14 => {
        Name => 'SignalNumber',
        Format => 'int32u',
    },
);

# MNG DEFI chunk
%Image::ExifTool::MNG::DefineObject = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'ObjectID',
        Format => 'int16u',
    },
    2 => 'DoNotShow',
    3 => 'ConcreteFlag',
    4 => {
        Name => 'XYLocation',
        Format => 'int32u[2]',
    },
    12 => {
        Name => 'ClippingBoundary',
        Format => 'int32u[4]',
    },
);

# MNG CLON chunk
%Image::ExifTool::MNG::CloneObject = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'SourceID',
        Format => 'int16u',
    },
    2 => {
        Name => 'CloneID',
        Format => 'int16u',
    },
    4 => {
        Name => 'CloneType',
        PrintConv => { 0 => 'Full', 1 => 'Parital', 2 => 'Renumber object' },
    },
    5 => 'DoNotShow',
    6 => 'ConcreteFlag',
    7 => {
        Name => 'LocalDeltaType',
        PrintConv => { 0 => 'Absolute', 1 => 'Relative' },
    },
    8 => {
        Name => 'DeltaXY',
        Format => 'int32u[2]',
    },
);

# MNG PAST chunk
%Image::ExifTool::MNG::PasteImage = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'DestinationID',
        Format => 'int16u',
    },
    2 => {
        Name => 'TargetDeltaType',
        PrintConv => { 0 => 'Absolute', 1 => 'Relative' },
    },
    3 => {
        Name => 'TargetXY',
        Format => 'int32u[2]',
    },
    11 => {
        Name => 'SourceID',
        Format => 'int16u',
    },
    13 => {
        Name => 'CompositionMode',
        PrintConv => { 0 => 'Over', 1 => 'Replace', 2 => 'Under' },
    },
    14 => {
        Name => 'Orientation',
        PrintConv => {
            0 => 'Same as source',
            2 => 'Flipped left-right, then up-down',
            4 => 'Flipped left-right',
            6 => 'Flipped up-down',
            8 => 'Tiled',
        },
    },
    15 => {
        Name => 'OffsetOrigin',
        PrintConv => { 0 => 'Desination Origin', 1 => 'Target Origin' },
    },
    16 => {
        Name => 'OffsetXY',
        Format => 'int32u[2]',
    },
    24 => {
        Name => 'BoundaryOrigin',
        PrintConv => { 0 => 'Desination Origin', 1 => 'Target Origin' },
    },
    25 => {
        Name => 'PastClippingBoundary',
        Format => 'int32u[4]',
    },
);

my %magMethod = (
    0 => 'No Magnification',
    1 => 'Pixel Replication',
    2 => 'Linear Interpolation',
    3 => 'Closest Pixel',
    4 => 'Color Linear Interpolation and Alpha Closest Pixel',
    5 => 'Color Closest Pixel and Alpha Linear Interpolation',
);

# MNG MAGN chunk
%Image::ExifTool::MNG::MagnifyObject = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'FirstObjectID',
        Format => 'int16u',
    },
    2 => {
        Name => 'LastObjectID',
        Format => 'int16u',
    },
    4 => {
        Name => 'XMethod',
        PrintConv => \%magMethod,
    },
    5 => {
        Name => 'XMag',
        Format => 'int16u',
    },
    7 => {
        Name => 'YMag',
        Format => 'int16u',
    },
    9 => {
        Name => 'LeftMag',
        Format => 'int16u',
    },
    11 => {
        Name => 'RightMag',
        Format => 'int16u',
    },
    13 => {
        Name => 'TopMag',
        Format => 'int16u',
    },
    15 => {
        Name => 'BottomMag',
        Format => 'int16u',
    },
    17 => {
        Name => 'YMethod',
        PrintConv => \%magMethod,
    },
);

# MNG TERM chunk
%Image::ExifTool::MNG::TerminationAction = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'TerminationAction',
        PrintConv => {
            0 => 'Show Last Frame',
            1 => 'Display Nothing',
            2 => 'Show First Frame',
            3 => 'Repeat Sequence',
        },
    },
    1 => {
        Name => 'IterationEndAction',
        PrintConv => {
            0 => 'Show Last Frame',
            1 => 'Display Nothing',
            2 => 'Show First Frame',
        },
    },
    2 => {
        Name => 'Delay',
        Format => 'int32u',
    },
    6 => {
        Name => 'IterationMax',
        Format => 'int32u',
    },
);

# MNG BACK chunk
%Image::ExifTool::MNG::Background = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'BackgroundColor',
        Format => 'int16u[3]',
    },
    6 => {
        Name => 'MandatoryBackground',
        PrintConv => {
            0 => 'Color and Image Advisory',
            1 => 'Color Mandatory, Image Advisory',
            2 => 'Color Advisory, Image Mandatory',
            3 => 'Color and Image Mandatory',
        },
    },
    7 => {
        Name => 'BackgroundImageID',
        Format => 'int16u',
    },
    9 => {
        Name => 'BackgroundTiling',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
);

# MNG MOVE chunk
%Image::ExifTool::MNG::MoveObjects = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'FirstObject',
        Format => 'int16u',
    },
    2 => {
        Name => 'LastObject',
        Format => 'int16u',
    },
    4 => {
        Name => 'DeltaType',
        PrintConv => { 0 => 'Absolute', 1 => 'Relative' },
    },
    5 => {
        Name => 'DeltaXY',
        Format => 'int32u[2]',
    },
);

# MNG CLIP chunk
%Image::ExifTool::MNG::ClipObjects = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'FirstObject',
        Format => 'int16u',
    },
    2 => {
        Name => 'LastObject',
        Format => 'int16u',
    },
    4 => {
        Name => 'DeltaType',
        PrintConv => { 0 => 'Absolute', 1 => 'Relative' },
    },
    5 => {
        Name => 'ClipBoundary',
        Format => 'int32u[4]',
    },
);

# MNG SHOW chunk
%Image::ExifTool::MNG::ShowObjects = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'FirstObject',
        Format => 'int16u',
    },
    2 => {
        Name => 'LastObject',
        Format => 'int16u',
    },
    4 => 'ShowMode',
);

# MNG eXPI chunk
%Image::ExifTool::MNG::ExportImage = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'SnapshotID',
        Format => 'int16u',
    },
    2 => {
        Name => 'SnapshotName',
        Format => 'string',
    },
);

# MNG fPRI chunk
%Image::ExifTool::MNG::FramePriority = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'DeltaType',
        PrintConv => { 0 => 'Absolute', 1 => 'Relative' },
    },
    2 => 'Priority',
);

# MNG DHDR chunk
%Image::ExifTool::MNG::DeltaPNGHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'ObjectID',
        Format => 'int16u',
    },
    2 => {
        Name => 'ImageType',
        PrintConv => {
            0 => 'Unspecified',
            1 => 'PNG',
            2 => 'JNG',
        },
    },
    3 => {
        Name => 'DeltaType',
        PrintConv => {
            0 => 'Full Replacement',
            1 => 'Pixel Addition',
            2 => 'Alpha Addition',
            3 => 'Color Addition',
            4 => 'Pixel Replacement',
            5 => 'Alpha Replacement',
            6 => 'Color Replacement',
            7 => 'No Change',
        },
    },
    4 => {
        Name => 'BlockSize',
        Format => 'int32u[2]',
    },
    12 => {
        Name => 'BlockLocation',
        Format => 'int32u[2]',
    },
);

# MNG PROM chunk
%Image::ExifTool::MNG::PromoteParent = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => 'NewColorType',
    1 => 'NewBitDepth',
    2 => {
        Name => 'FillMethod',
        PrintConv => { 0 => 'Bit Replication', 1 => 'Zero Fill' },
    },
);

# JNG JHDR chunk
%Image::ExifTool::MNG::JNGHeader = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'ImageWidth',
        Format => 'int32u',
    },
    4 => {
        Name => 'ImageHeight',
        Format => 'int32u',
    },
    8 => {
        Name => 'ColorType',
        PrintConv => {
            8 => 'Gray',
            10 => 'Color',
            12 => 'Gray Alpha',
            14 => 'Color Alpha',
        },
    },
    9 => 'BitDepth',
    10 => {
        Name => 'Compression',
        PrintConv => { 8 => 'Huffman-coded baseline JPEG' },
    },
    11 => {
        Name => 'Interlace',
        PrintConv => { 0 => 'Sequential', 8 => 'Progressive' },
    },
    12 => 'AlphaBitDepth',
    13 => {
        Name => 'AlphaCompression',
        PrintConv => {
            0 => 'MNG Grayscale IDAT',
            8 => 'JNG 8-bit Grayscale JDAA',
        },
    },
    14 => {
        Name => 'AlphaFilter',
        PrintConv => { 0 => 'Adaptive MNG (N/A for JPEG)' },
    },
    15 => {
        Name => 'AlphaInterlace',
        PrintConv => { 0 => 'Noninterlaced' },
    },
);

1;  # end

__END__

=head1 NAME

Image::ExifTool::MNG - MNG and JNG meta information tags

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read MNG
(Multi-image Network Graphics) and JNG (JPEG Network Graphics) images.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.libpng.org/pub/mng/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MNG Tags>,
L<Image::ExifTool::TagNames/PNG Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

