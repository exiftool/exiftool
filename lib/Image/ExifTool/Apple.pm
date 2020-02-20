#------------------------------------------------------------------------------
# File:         Apple.pm
#
# Description:  Apple EXIF maker notes tags
#
# Revisions:    2013-09-13 - P. Harvey Created
#
# References:   1) http://www.photoinvestigator.co/blog/the-mystery-of-maker-apple-metadata/
#------------------------------------------------------------------------------

package Image::ExifTool::Apple;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;
use Image::ExifTool::PLIST;

$VERSION = '1.04';

# Apple iPhone metadata (ref PH)
%Image::ExifTool::Apple::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => 'Tags extracted from the maker notes of iPhone images.',
    # 0x0001 - int32s: seen 0,1,2,3,4,9
    # 0x0002 - binary plist with a single data object of size 512 bytes (iPhone5s)
    0x0003 => {
        Name => 'RunTime', # (includes time plugged in, but not when suspended, ref 1)
        SubDirectory => { TagTable => 'Image::ExifTool::Apple::RunTime' },
    },
    # 0x0004 - int32s: normally 1, but 0 for low-light images
    # 0x0005 - int32s: seen values 113-247, and 100 for blank images
    # 0x0006 - int32s: seen values 27-258, and 20 for blank images
    # 0x0007 - int32s: seen 1
    0x0008 => { #1
        Name => 'AccelerationVector',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64s',
        Count => 3,
        # Note: the directions are contrary to the Apple documentation (which have the
        # signs of all axes reversed -- apparently the Apple geeks aren't very good
        # with basic physics, and don't understand the concept of acceleration.  See
        # http://nscookbook.com/2013/03/ios-programming-recipe-19-using-core-motion-to-access-gyro-and-accelerometer/
        # for one of the few correct descriptions of this).  Note that this leads to
        # a left-handed coordinate system for acceleration.
        Notes => q{
            XYZ coordinates of the acceleration vector in units of g.  As viewed from
            the front of the phone, positive X is toward the left side, positive Y is
            toward the bottom, and positive Z points into the face of the phone
        },
    },
    # 0x0009 - int32s: seen 19,275,531,4371
    0x000a => {
        Name => 'HDRImageType',
        Writable => 'int32s',
        PrintConv => {
            # 2 => ? (iPad mini 2)
            3 => 'HDR Image',
            4 => 'Original Image',
        },
    },
    0x000b => {
        Name => 'BurstUUID',
        Writable => 'string',
        Notes => 'unique ID for all images in a burst',
    },
    # 0x000c - rational64s[2]: eg) "0.1640625 0.19921875"
    # 0x000d - int32s: 0,1,6,20,24,32,40
    # 0x000e - int32s: 0,1,4,12 (Orientation? 0=landscape? 4=portrait? ref 1)
    # 0x000f - int32s: 2,3
    # 0x0010 - int32s: 1
    0x0011 => {
        Name => 'ContentIdentifier', #forum8750
        Writable => 'string',
    },
    # 0x0014 - int32s: 1,2,3,4,5 (iPhone 6s, iOS 6.1)
    0x0015 => {
        Name => 'ImageUniqueID',
        Writable => 'string',
    },
    # 0x0016 - string[29]: "AXZ6pMTOh2L+acSh4Kg630XCScoO\0"
    # 0x0017 - int32s: 0,8192
    # 0x0019 - int32s: 0,2,128
    # 0x001a - string[6]: "q825s\0"
    # 0x001f - int32s: 0
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

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Apple Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
