#------------------------------------------------------------------------------
# File:         Unknown.pm
#
# Description:  Unknown EXIF maker notes tags
#
# Revisions:    04/07/2004  - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Unknown;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.13';

# Unknown maker notes
%Image::ExifTool::Unknown::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 1 => 'MakerUnknown', 2 => 'Camera' },

    # this seems to be a common fixture, so look for it in unknown maker notes
    0x0e00 => {
        Name => 'PrintIM',
        Description => 'Print Image Matching',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PrintIM::Main',
        },
    },
);


1;  # end

__END__

=head1 NAME

Image::ExifTool::Unknown - Unknown EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

Image::ExifTool has definitions for the maker notes from many manufacturers,
however information can sometimes be extracted from unknown manufacturers if
the maker notes are in standard IFD format.  This module contains the
definitions necessary for Image::ExifTool to read the maker notes from
unknown manufacturers.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Unknown Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
