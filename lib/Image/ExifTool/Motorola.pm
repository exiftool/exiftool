#------------------------------------------------------------------------------
# File:         Motorola.pm
#
# Description:  Read Motorola meta information
#
# Revisions:    2015/10/29 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Motorola;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.00';

# Motorola makernotes tags (ref PH)
%Image::ExifTool::Motorola::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITABLE => 1,
    # 0x5570 - some sort of picture mode (auto,hdr)
    # 0x6400 - HDR? (OFF,ON)
    # 0x6410 - HDR? (NO,YES)
    # 0x6420 - only exists in HDR images
    0x665e => { Name => 'Sensor',           Writable => 'string' }, # (eg. "BACK,IMX230")
    # 0x6700 - serial number?
    0x6705 => { Name => 'ManufactureDate',  Writable => 'string' }, # (NC, eg. "03Jun2015")
    # 0x6706 - serial number?
);

1; # end

__END__

=head1 NAME

Image::ExifTool::Motorola - Read Motorola meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains the definitions to read meta information from Motorola
cell phone images.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Motorola Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
