#------------------------------------------------------------------------------
# File:         Opus.pm
#
# Description:  Read Ogg Opus audio meta information
#
# Revisions:    2016/07/14 - P. Harvey Created
#
# References:   1) https://www.opus-codec.org/docs/
#               2) https://wiki.xiph.org/OggOpus
#               3) https://tools.ietf.org/pdf/rfc7845.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::Opus;

use strict;
use vars qw($VERSION);

$VERSION = '1.00';

# Opus metadata types
%Image::ExifTool::Opus::Main = (
    NOTES => q{
        Information extracted from Ogg Opus files.  See
        L<https://www.opus-codec.org/docs/> for the specification.
    },
    'OpusHead' => {
        Name => 'Header',
        SubDirectory => { TagTable => 'Image::ExifTool::Opus::Header' },
    },
    'OpusTags' => {
        Name => 'Comments',
        SubDirectory => { TagTable => 'Image::ExifTool::Vorbis::Comments' },
    },
);

%Image::ExifTool::Opus::Header = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Audio' },
    0 => 'OpusVersion',
    1 => 'AudioChannels',
  # 2 => 'PreSkip' (int16u)
    4 => {
        Name => 'SampleRate',
        Format => 'int32u',
    },
    8 => {
        Name => 'OutputGain',
        Format => 'int16u',
        ValueConv => '10 ** ($val/5120)',
    },
);

1;  # end

__END__

=head1 NAME

Image::ExifTool::Opus - Read Ogg Opus audio meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Ogg Opus audio files.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://www.opus-codec.org/docs/>

=item L<https://wiki.xiph.org/OggOpus>

=item L<https://tools.ietf.org/pdf/rfc7845.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Opus Tags>,
L<Image::ExifTool::TagNames/Ogg Tags>,
L<Image::ExifTool::TagNames/Vorbis Tags>,
L<Image::ExifTool::TagNames/FLAC Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

