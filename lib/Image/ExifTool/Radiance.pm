#------------------------------------------------------------------------------
# File:         Radiance.pm
#
# Description:  Read Radiance RGBE HDR meta information
#
# Revisions:    2011/12/10 - P. Harvey Created
#
# References:   1) http://www.graphics.cornell.edu/online/formats/rgbe/
#               2) http://radsite.lbl.gov/radiance/refer/filefmts.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::Radiance;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.02';

# Radiance tags
%Image::ExifTool::Radiance::Main = (
    GROUPS => { 2 => 'Image' },
    NOTES => q{
        Information extracted from Radiance RGBE HDR images.  Tag ID's are all
        uppercase as stored in the file, but converted to lowercase by when
        extracting to avoid conflicts with internal ExifTool variables.  See
        L<http://radsite.lbl.gov/radiance/refer/filefmts.pdf> and
        L<http://www.graphics.cornell.edu/online/formats/rgbe/> for the
        specification.
    },
    _orient   => {
        Name => 'Orientation',
        PrintConv => {
            '-Y +X' => 'Horizontal (normal)',
            '-Y -X' => 'Mirror horizontal',
            '+Y -X' => 'Rotate 180',
            '+Y +X' => 'Mirror vertical',
            '+X -Y' => 'Mirror horizontal and rotate 270 CW',
            '+X +Y' => 'Rotate 90 CW',
            '-X +Y' => 'Mirror horizontal and rotate 90 CW',
            '-X -Y' => 'Rotate 270 CW',
        },
    },
    _command  => 'Command',
    _comment  => 'Comment',
    software  => 'Software',
    view      => 'View',
   'format'   => 'Format', # <-- this is the one that caused the conflict when uppercase
    exposure  => {
        Name => 'Exposure',
        Notes => 'divide pixel values by this to get watts/steradian/meter^2',
    },
    gamma     => 'Gamma',
    colorcorr => 'ColorCorrection',
    pixaspect => 'PixelAspectRatio',
    primaries => 'ColorPrimaries',
);

#------------------------------------------------------------------------------
# Extract information from a Radiance HDR file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid RGBE image
sub ProcessHDR($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;
    local $/ = "\x0a";  # set newline character for reading

    # verify this is a valid RIFF file
    return 0 unless $raf->ReadLine($buff) and $buff =~ /^#\?(RADIANCE|RGBE)\x0a/s;
    $et->SetFileType();
    my $tagTablePtr = GetTagTable('Image::ExifTool::Radiance::Main');

    while ($raf->ReadLine($buff)) {
        chomp $buff;
        last unless length($buff) > 0 and length($buff) < 4096;
        if ($buff =~ s/^#\s*//) {
            $et->HandleTag($tagTablePtr, '_comment', $buff) if length $buff;
            next;
        }
        unless ($buff =~ /^(.*)?\s*=\s*(.*)/) {
            $et->HandleTag($tagTablePtr, '_command', $buff) if length $buff;
            next;
        }
        # use lower-case tag names to avoid conflicts with reserved tag table entries
        my ($tag, $val) = (lc $1, $2);
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        unless ($tagInfo) {
            my $name = $tag;
            $name =~ tr/-_a-zA-Z0-9//dc;
            next unless length($name) > 1;
            $name = ucfirst $name;
            $tagInfo = { Name => $name };
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        $et->FoundTag($tagInfo, $val);
    }
    # get image dimensions
    if ($raf->ReadLine($buff) and $buff =~ /([-+][XY])\s*(\d+)\s*([-+][XY])\s*(\d+)/) {
        $et->HandleTag($tagTablePtr, '_orient', "$1 $3");
        $et->FoundTag('ImageHeight', $2);
        $et->FoundTag('ImageWidth', $4);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Radiance - Read Radiance RGBE HDR meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Radiance RGBE images.  RGBE (Red Green Blue Exponent)
images are a type of high dynamic-range image.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://radsite.lbl.gov/radiance/refer/filefmts.pdf>

=item L<http://www.graphics.cornell.edu/online/formats/rgbe/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Radiance Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

