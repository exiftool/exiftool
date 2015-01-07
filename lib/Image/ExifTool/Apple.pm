#------------------------------------------------------------------------------
# File:         Apple.pm
#
# Description:  Apple EXIF maker notes tags
#
# Revisions:    2013-09-13 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Apple;

use strict;
use vars qw($VERSION);
use Image::ExifTool::PLIST;

$VERSION = '1.01';

%Image::ExifTool::Apple::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => 'Tags extracted from maker notes of images from the iPhone 5 with iOS 7.',
    # 0x0001 - int32s: seen 0, 1
    # 0x0002 - binary plist with a single data object of size 512 bytes (iPhone5s)
    0x0003 => {
        Name => 'RunTime',
        SubDirectory => { TagTable => 'Image::ExifTool::Apple::RunTime' },
    },
    # 0x0004 - int32s: normally 1, but 0 for low-light images
    # 0x0005 - int32s: seen values 147-247, and 100 for blank images
    # 0x0006 - int32s: seen values 129-241, and 20 for blank images
    # 0x0007 - int32s: seen 1
    # 0x0009 - int32s: seen 19
    0x000a => {
        Name => 'HDRImageType',
        Writable => 'int32s',
        PrintConv => {
            3 => 'HDR Image',
            4 => 'Original Image',
        },
    },
);

# PLIST-format CMTime structure (ref PH)
# (CMTime ref https://developer.apple.com/library/ios/documentation/CoreMedia/Reference/CMTime/Reference/reference.html)
%Image::ExifTool::Apple::RunTime = (
    PROCESS_PROC => \&Image::ExifTool::PLIST::ProcessBinaryPLIST,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => q{
        This PLIST-format information contains the elements of a CMTime structure
        representing the amount of time the phone has been running since the last
        boot, not including standby time.
    },
    timescale => { Name => 'RunTimeScale' }, # (seen 1000000000 --> ns)
    epoch     => { Name => 'RunTimeEpoch' }, # (seen 0)
    value     => { Name => 'RunTimeValue' }, # (should divide by RunTimeScale to get seconds)
    flags => {
        Name => 'RunTimeFlags',
        PrintConv => { BITMASK => {
            0 => 'Valid',
            1 => 'Has been rounded',
            2 => 'Positive infinity',
            3 => 'Negative infinity',
            4 => 'Indefinite',
        }},
    },
);

# Apple composite tags
%Image::ExifTool::Apple::Composite = (
    GROUPS => { 2 => 'Camera' },
    RunTimeSincePowerUp => {
        Require => {
            0 => 'Apple:RunTimeValue',
            1 => 'Apple:RunTimeScale',
        },
        ValueConv => '$val[1] ? $val[0] / $val[1] : undef',
        PrintConv => 'ConvertDuration($val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Apple');


1;  # end

__END__

=head1 NAME

Image::ExifTool::Apple - Apple EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Apple maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2015, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Apple Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
