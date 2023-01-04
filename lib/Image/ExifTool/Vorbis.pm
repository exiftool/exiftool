#------------------------------------------------------------------------------
# File:         Vorbis.pm
#
# Description:  Read Ogg Vorbis audio meta information
#
# Revisions:    2006/11/10 - P. Harvey Created
#               2011/07/12 - PH Moved Ogg to a separate module and added Theora
#
# References:   1) http://www.xiph.org/vorbis/doc/
#               2) http://flac.sourceforge.net/ogg_mapping.html
#               3) http://www.theora.org/doc/Theora.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::Vorbis;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.08';

sub ProcessComments($$$);

# Vorbis header types
%Image::ExifTool::Vorbis::Main = (
    NOTES => q{
        Information extracted from Ogg Vorbis files.  See
        L<http://www.xiph.org/vorbis/doc/> for the Vorbis specification.
    },
    1 => {
        Name => 'Identification',
        SubDirectory => { TagTable => 'Image::ExifTool::Vorbis::Identification' },
    },
    3 => {
        Name => 'Comments',
        SubDirectory => { TagTable => 'Image::ExifTool::Vorbis::Comments' },
    },
);

%Image::ExifTool::Vorbis::Identification = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Audio' },
    0 => {
        Name => 'VorbisVersion',
        Format => 'int32u',
    },
    4 => 'AudioChannels',
    5 => {
        Name => 'SampleRate',
        Format => 'int32u',
    },
    9 => {
        Name => 'MaximumBitrate',
        Format => 'int32u',
        RawConv => '$val || undef',
        PrintConv => 'ConvertBitrate($val)',
    },
    13 => {
        Name => 'NominalBitrate',
        Format => 'int32u',
        RawConv => '$val || undef',
        PrintConv => 'ConvertBitrate($val)',
    },
    17 => {
        Name => 'MinimumBitrate',
        Format => 'int32u',
        RawConv => '$val || undef',
        PrintConv => 'ConvertBitrate($val)',
    },
);

%Image::ExifTool::Vorbis::Comments = (
    PROCESS_PROC => \&ProcessComments,
    GROUPS => { 2 => 'Audio' },
    NOTES => q{
        The tags below are only some common tags found in the Vorbis comments of Ogg
        Vorbis and Ogg FLAC audio files, however ExifTool will extract values from
        any tag found, even if not listed here.
    },
    vendor    => { Notes => 'from comment header' },
    TITLE     => { Name => 'Title' },
    VERSION   => { Name => 'Version' },
    ALBUM     => { Name => 'Album' },
    TRACKNUMBER=>{ Name => 'TrackNumber' },
    ARTIST    => { Name => 'Artist',       Groups => { 2 => 'Author' }, List => 1 },
    PERFORMER => { Name => 'Performer',    Groups => { 2 => 'Author' }, List => 1 },
    COPYRIGHT => { Name => 'Copyright',    Groups => { 2 => 'Author' } },
    LICENSE   => { Name => 'License',      Groups => { 2 => 'Author' } },
    ORGANIZATION=>{Name => 'Organization', Groups => { 2 => 'Author' } },
    DESCRIPTION=>{ Name => 'Description' },
    GENRE     => { Name => 'Genre' },
    DATE      => { Name => 'Date',         Groups => { 2 => 'Time' } },
    LOCATION  => { Name => 'Location',     Groups => { 2 => 'Location' } },
    CONTACT   => { Name => 'Contact',      Groups => { 2 => 'Author' }, List => 1 },
    ISRC      => { Name => 'ISRCNumber' },
    COVERARTMIME => { Name => 'CoverArtMIMEType' },
    COVERART  => {
        Name => 'CoverArt',
        Groups => { 2 => 'Preview' },
        Notes => 'base64-encoded image',
        ValueConv => q{
            require Image::ExifTool::XMP;
            Image::ExifTool::XMP::DecodeBase64($val);
        },
    },
    REPLAYGAIN_TRACK_PEAK => { Name => 'ReplayGainTrackPeak' },
    REPLAYGAIN_TRACK_GAIN => { Name => 'ReplayGainTrackGain' },
    REPLAYGAIN_ALBUM_PEAK => { Name => 'ReplayGainAlbumPeak' },
    REPLAYGAIN_ALBUM_GAIN => { Name => 'ReplayGainAlbumGain' },
    # observed in "Xiph.Org libVorbis I 20020717" ogg:
    ENCODED_USING => { Name => 'EncodedUsing' },
    ENCODED_BY  => { Name => 'EncodedBy' },
    COMMENT     => { Name => 'Comment' },
    # in Theora documentation (ref 3)
    DIRECTOR    => { Name => 'Director' },
    PRODUCER    => { Name => 'Producer' },
    COMPOSER    => { Name => 'Composer' },
    ACTOR       => { Name => 'Actor' },
    # Opus tags
    ENCODER     => { Name => 'Encoder' },
    ENCODER_OPTIONS => { Name => 'EncoderOptions' },
    METADATA_BLOCK_PICTURE => {
        Name => 'Picture',
        Binary => 1,
        # ref https://wiki.xiph.org/VorbisComment#METADATA_BLOCK_PICTURE
        RawConv => q{
            require Image::ExifTool::XMP;
            Image::ExifTool::XMP::DecodeBase64($val);
        },
        SubDirectory => {
            TagTable => 'Image::ExifTool::FLAC::Picture',
            ByteOrder => 'BigEndian',
        },
    },
);

# Vorbis composite tags
%Image::ExifTool::Vorbis::Composite = (
    Duration => {
        Require => {
            0 => 'Vorbis:NominalBitrate',
            1 => 'FileSize',
        },
        RawConv => '$val[0] ? $val[1] * 8 / $val[0] : undef',
        PrintConv => 'ConvertDuration($val) . " (approx)"', # (only approximate)
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Vorbis');


#------------------------------------------------------------------------------
# Process Vorbis Comments
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessComments($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $pos = $$dirInfo{DirStart} || 0;
    my $end = $$dirInfo{DirLen} ? $pos + $$dirInfo{DirLen} : length $$dataPt;
    my ($num, $index);

    SetByteOrder('II');
    for (;;) {
        last if $pos + 4 > $end;
        my $len = Get32u($dataPt, $pos);
        last if $pos + 4 + $len > $end;
        my $start = $pos + 4;
        my $buff = substr($$dataPt, $start, $len);
        $pos = $start + $len;
        my ($tag, $val);
        if (defined $num) {
            $buff =~ /(.*?)=(.*)/s or last;
            ($tag, $val) = (uc $1, $2);
            # Vorbis tag ID's are all capitals, so they may conflict with our internal tags
            # --> protect against this by adding a trailing underline if necessary
            $tag .= '_' if $Image::ExifTool::specialTags{$tag};
        } else {
            $tag = 'vendor';
            $val = $buff;
            $num = ($pos + 4 < $end) ? Get32u($dataPt, $pos) : 0;
            $et->VPrint(0, "  + [Vorbis comments with $num entries]\n");
            $pos += 4;
        }
        # add tag to table unless it exists already
        unless ($$tagTablePtr{$tag}) {
            my $name = ucfirst(lc($tag));
            # remove invalid characters in tag name and capitalize following letters
            $name =~ s/[^\w-]+(.?)/\U$1/sg;
            $name =~ s/([a-z0-9])_([a-z])/$1\U$2/g;
            $et->VPrint(0, "  | [adding $tag]\n");
            AddTagToTable($tagTablePtr, $tag, { Name => $name });
        }
        $et->HandleTag($tagTablePtr, $tag, $et->Decode($val, 'UTF8'),
            Index   => $index,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $start,
            Size    => $len,
        );
        # all done if this was our last tag
        $num-- or return 1;
        $index = (defined $index) ? $index + 1 : 0;
    }
    $et->Warn('Format error in Vorbis comments');
    return 0;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Vorbis - Read Ogg Vorbis audio meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Ogg Vorbis audio headers.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.xiph.org/vorbis/doc/>

=item L<http://flac.sourceforge.net/ogg_mapping.html>

=item L<http://www.theora.org/doc/Theora.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Vorbis Tags>,
L<Image::ExifTool::TagNames/Ogg Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

