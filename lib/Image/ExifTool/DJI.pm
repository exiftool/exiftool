#------------------------------------------------------------------------------
# File:         DJI.pm
#
# Description:  DJI Phantom maker notes tags
#
# Revisions:    2016-07-25 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::DJI;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.00';

my %convFloat2 = (
    PrintConv => 'sprintf("%+.2f", $val)',
    PrintConvInv => '$val',
);

# DJI maker notes (ref PH, mostly educated guesses based on DJI QuickTime::UserData tags)
%Image::ExifTool::DJI::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => q{
        This table lists tags found in the maker notes of images from some DJI
        Phantom drones.
    },
    0x01 => { Name => 'Make',       Writable => 'string' },
  # 0x02 - int8u[4]: "1 0 0 0", "1 1 0 0"
    0x03 => { Name => 'SpeedX',     Writable => 'float', %convFloat2 }, # (guess)
    0x04 => { Name => 'SpeedY',     Writable => 'float', %convFloat2 }, # (guess)
    0x05 => { Name => 'SpeedZ',     Writable => 'float', %convFloat2 }, # (guess)
    0x06 => { Name => 'Pitch',      Writable => 'float', %convFloat2 },
    0x07 => { Name => 'Yaw',        Writable => 'float', %convFloat2 },
    0x08 => { Name => 'Roll',       Writable => 'float', %convFloat2 },
    0x09 => { Name => 'CameraPitch',Writable => 'float', %convFloat2 },
    0x0a => { Name => 'CameraYaw',  Writable => 'float', %convFloat2 },
    0x0b => { Name => 'CameraRoll', Writable => 'float', %convFloat2 },
);

__END__

=head1 NAME

Image::ExifTool::DJI - DJI Phantom maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
the maker notes in images from some DJI Phantom drones.

=head1 AUTHOR

Copyright 2003-2017, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/DJI Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
