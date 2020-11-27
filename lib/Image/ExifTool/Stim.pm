#------------------------------------------------------------------------------
# File:         Stim.pm
#
# Description:  Definitions for Stereo Still Image tags
#
# Revisions:    06/12/2009 - P. Harvey Created
#
# References:   1) http://www.cipa.jp/std/documents/e/DC-006_E.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::Stim;

use strict;
use vars qw($VERSION);

$VERSION = '1.01';

# Tags found in APP3 Stim segment in JPEG images
%Image::ExifTool::Stim::Main = (
    GROUPS => { 0 => 'Stim', 1 => 'Stim', 2 => 'Image'},
    NOTES => q{
        These tags are part of the CIPA Stereo Still Image specification, and are
        found in the APP3 "Stim" segment of JPEG images.  See
        L<https://web.archive.org/web/20190718152459/http://www.cipa.jp/std/documents/e/DC-006_E.pdf>
        for the official specification.
    },
    0 => 'StimVersion',
    1 => {
        Name => 'ApplicationData',
        Binary => 1,
    },
    2 => {
        Name => 'ImageArrangement',
        PrintConv => {
            0 => 'Parallel View Alignment',
            1 => 'Cross View Alignment',
        },
    },
    3 => {
        Name => 'ImageRotation',
        PrintConv => {
            1 => 'None',
        },
    },
    4 => 'ScalingFactor',
    5 => 'CropXSize',
    6 => 'CropYSize',
    7 => {
        Name => 'CropX',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Stim::CropX',
        },
    },
    8 => {
        Name => 'CropY',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Stim::CropY',
        },
    },
    9 => {
        Name => 'ViewType',
        PrintConv => {
            0 => 'No Pop-up Effect',
            1 => 'Pop-up Effect',
        },
    },
    10 => {
        Name => 'RepresentativeImage',
        PrintConv => {
            0 => 'Left Viewpoint',
            1 => 'Right Viewpoint',
        },
    },
    11 => {
        Name => 'ConvergenceBaseImage',
        PrintConv => {
            0 => 'Left Viewpoint',
            1 => 'Right Viewpoint',
            255 => 'Equivalent for Both Viewpoints',
        },
    },
    12 => {
        Name => 'AssumedDisplaySize',
        PrintConv => '"$val mm"',
    },
    13 => {
        Name => 'AssumedDistanceView',
        PrintConv => '"$val mm"',
    },
    14 => 'RepresentativeDisparityNear',
    15 => 'RepresentativeDisparityFar',
    16 => {
        Name => 'InitialDisplayEffect',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    17 => {
        Name => 'ConvergenceDistance',
        PrintConv => '$val ? "$val mm" : "inf"',
    },
    18 => {
        Name => 'CameraArrangementInterval',
        PrintConv => '"$val mm"',
    },
    19 => 'ShootingCount',
);

# crop offset X tags
%Image::ExifTool::Stim::CropX = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'Stim', 1 => 'Stim', 2 => 'Image'},
    0 => {
        Name => 'CropXCommonOffset',
        Format => 'int16u',
        PrintConv => {
            0 => 'Common Offset Setting',
            1 => 'Individual Offset Setting',
        },
    },
    2 => 'CropXViewpointNumber',
    3 => {
        Name => 'CropXOffset',
        Format => 'int32s',
    },
    7 => 'CropXViewpointNumber2',
    8 => {
        Name => 'CropXOffset2',
        Format => 'int32s',
    },
);

# crop offset Y tags
%Image::ExifTool::Stim::CropY = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'Stim', 1 => 'Stim', 2 => 'Image'},
    0 => {
        Name => 'CropYCommonOffset',
        Format => 'int16u',
        PrintConv => {
            0 => 'Common Offset Setting',
            1 => 'Individual Offset Setting',
        },
    },
    2 => 'CropYViewpointNumber',
    3 => {
        Name => 'CropYOffset',
        Format => 'int32s',
    },
    7 => 'CropYViewpointNumber2',
    8 => {
        Name => 'CropYOffset2',
        Format => 'int32s',
    },
);

1;  # end

__END__

=head1 NAME

Image::ExifTool::Stim - Definitions for Stereo Still Image tags

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains tag definitions for Stereo Still Image format (Stim)
information.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cipa.jp/std/documents/e/DC-006_E.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Stim Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

