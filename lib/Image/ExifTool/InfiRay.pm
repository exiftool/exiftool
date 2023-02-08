#------------------------------------------------------------------------------
# File:         InfiRay.pm
#
# Description:  InfiRay IJPEG thermal image metadata
#
# Revisions:    2023-02-08 - M. Del Sol Created
#
# Notes:        Information in this document has been mostly gathered by
#				disassembling the P2 Pro Android app, version 1.0.8.230111.
#------------------------------------------------------------------------------

package Image::ExifTool::InfiRay;

use strict;
use vars qw($VERSION);

$VERSION = '1.00';

# InfiRay IJPEG version header, found in JPEGs APP2
%Image::ExifTool::InfiRay::Version = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q{
        This table lists tags found in the InfiRay IJPEG version header, found
		in JPEGs taken with the P2 Pro camera app.
    },
    0x00 => { Name => 'Version',              Format => 'int8u[4]' },
    0x04 => { Name => 'Signature',            Format => 'string' },
    0x0c => { Name => 'ImageOrgType',         Format => 'int8u' },
    0x0d => { Name => 'ImageDispType',        Format => 'int8u' },
    0x0e => { Name => 'ImageRotate',          Format => 'int8u' },
    0x0f => { Name => 'ImageMirrorFlip',      Format => 'int8u' },
    0x10 => { Name => 'ImageColorSwitchable', Format => 'int8u' },
    0x11 => { Name => 'ImageColorPalette',    Format => 'int16u' },
    0x20 => { Name => 'IRDataSize',           Format => 'int64u' },
    0x28 => { Name => 'IRDataFormat',         Format => 'int16u' },
    0x2a => { Name => 'IRImageWidth',         Format => 'int16u' },
    0x2c => { Name => 'IRImageHeight',        Format => 'int16u' },
    0x2e => { Name => 'IRImageBpp',           Format => 'int8u' },
    0x30 => { Name => 'TempDataSize',         Format => 'int64u' },
    0x38 => { Name => 'TempDataFormat',       Format => 'int16u' },
    0x3a => { Name => 'TempImageWidth',       Format => 'int16u' },
    0x3c => { Name => 'TempImageHeight',      Format => 'int16u' },
    0x3e => { Name => 'TempImageBpp',         Format => 'int8u' },
    0x40 => { Name => 'VisibleDataSize',      Format => 'int64u' },
    0x48 => { Name => 'VisibleDataFormat',    Format => 'int16u' },
    0x4a => { Name => 'VisibleImageWidth',    Format => 'int16u' },
    0x4c => { Name => 'VisibleImageHeight',   Format => 'int16u' },
    0x4e => { Name => 'VisibleImageBpp',      Format => 'int8u' },
);

__END__

=head1 NAME

Image::ExifTool::InfiRay - InfiRay IJPEG thermal image metadata

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
metadata and thermal-related information of pictures saved by the InfiRay
IJPEG SDK, used in cameras such as the P2 Pro.

=head1 AUTHOR

Copyright 2003-2023, Marcos Del Sol Vives (marcos at orca.pet)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/InfiRay Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
