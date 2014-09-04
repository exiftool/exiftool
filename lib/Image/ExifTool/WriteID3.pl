#------------------------------------------------------------------------------
# File:         WriteID3.pl
#
# Description:  Write ID3 meta information
#
# Revisions:    07/10/2006 - P. Harvey Created
#------------------------------------------------------------------------------
package Image::ExifTool::ID3;

use strict;
use Image::ExifTool qw(:DataAccess :Utils);

#------------------------------------------------------------------------------
# Write information to MP3 file
# Inputs: 0) ExifTool object reference, 1) source dirInfo reference
# Returns: 1 on success, 0 if not valid MP3 file, -1 on write error
sub WriteMP3($$)
{
    my ($et, $dirInfo) = @_;
}


1; # end

__END__

=head1 NAME

Image::ExifTool::WriteID3.pl - Write ID3 meta information

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool::ID3.

=head1 DESCRIPTION

This file contains routines to write ID3 metadata.

=head1 AUTHOR

Copyright 2003-2014, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::ID3(3pm)|Image::ExifTool::ID3>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
