#------------------------------------------------------------------------------
# File:         Audible.pm
#
# Description:  Read metadata from Audible audio books
#
# Revisions:    2015/04/05 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Audible;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

sub ProcessAudible_meta($$$);
sub ProcessAudible_cvrx($$$);

# 'tags' atoms observed in Audible .m4b audio books (ref PH)
%Image::ExifTool::Audible::tags = (
    GROUPS => { 0 => 'QuickTime', 2 => 'Audio' },
    NOTES => 'Information found in "tags" atom of Audible M4B audio books.',
    meta => {
        Name => 'Audible_meta',
        SubDirectory => { TagTable => 'Image::ExifTool::Audible::meta' },
    },
    cvrx => {
        Name => 'Audible_cvrx',
        SubDirectory => { TagTable => 'Image::ExifTool::Audible::cvrx' },
    },
    tseg => {
        Name => 'Audible_tseg',
        SubDirectory => { TagTable => 'Image::ExifTool::Audible::tseg' },
    },
);

# 'meta' information observed in Audible .m4b audio books (ref PH)
%Image::ExifTool::Audible::meta = (
    PROCESS_PROC => \&ProcessAudible_meta,
    GROUPS => { 0 => 'QuickTime', 2 => 'Audio' },
    NOTES => 'Information found in Audible M4B "meta" atom.',
    Album       => 'Album',
    ALBUMARTIST => { Name => 'AlbumArtist', Groups => { 2 => 'Author' } },
    Artist      => { Name => 'Artist',      Groups => { 2 => 'Author' } },
    Comment     => 'Comment',
    Genre       => 'Genre',
    itunesmediatype => { Name => 'iTunesMediaType', Description => 'iTunes Media Type' },
    SUBTITLE    => 'Subtitle',
    Title       => 'Title',
    TOOL        => 'CreatorTool',
    Year        => { Name => 'Year', Groups => { 2 => 'Time' } },
    track       => 'ChapterName', # (found in 'meta' of 'tseg' atom)
);

# 'cvrx' information observed in Audible .m4b audio books (ref PH)
%Image::ExifTool::Audible::cvrx = (
    PROCESS_PROC => \&ProcessAudible_cvrx,
    GROUPS => { 0 => 'QuickTime', 2 => 'Audio' },
    NOTES => 'Audible cover art information in M4B audio books.',
    VARS => { NO_ID => 1 },
    CoverArtType => 'CoverArtType',
    CoverArt     => { Name => 'CoverArt', Binary => 1 },
);

# 'tseg' information observed in Audible .m4b audio books (ref PH)
%Image::ExifTool::Audible::tseg = (
    GROUPS => { 0 => 'QuickTime', 2 => 'Audio' },
    tshd => {
        Name => 'ChapterNumber',
        Format => 'int32u',
        ValueConv => '$val + 1',    # start counting from 1
    },
    meta => {
        Name => 'Audible_meta2',
        SubDirectory => { TagTable => 'Image::ExifTool::Audible::meta' },
    },
);

#------------------------------------------------------------------------------
# Process Audible 'meta' tags (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessAudible_meta($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $dirLen = length $$dataPt;
    return 0 if $dirLen < 4;
    my $num = Get32u($dataPt, 0);
    $et->VerboseDir('Audible_meta', $num);
    my $pos = 4;
    my $index;
    for ($index=0; $index<$num; ++$index) {
        last if $pos + 3 > $dirLen;
        my $unk = Get8u($dataPt, $pos);             # ? (0x80 or 0x00)
        last unless $unk eq 0x80 or $unk eq 0x00;
        my $len = Get16u($dataPt, $pos + 1);        # tag length
        $pos += 3;
        last if $pos + $len + 6 > $dirLen or not $len;
        my $tag = substr($$dataPt, $pos, $len);     # tag ID
        my $ver = Get16u($dataPt, $pos + $len);     # version?
        last unless $ver eq 0x0001;
        my $size = Get32u($dataPt, $pos + $len + 2);# data size
        $pos += $len + 6;
        last if $pos + $size > $dirLen;
        my $val = $et->Decode(substr($$dataPt, $pos, $size), 'UTF8');
        unless ($$tagTablePtr{$tag}) {
            next unless $len > 1;
            my $name = ucfirst(($tag =~ /[a-z]/) ? $tag : lc($tag));
            $name =~ tr/-_A-Za-z0-9//dc;
            next if length($name) < 2;
            AddTagToTable($tagTablePtr, $tag, { Name => $name });
        }
        $et->HandleTag($tagTablePtr, $tag, $val,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $pos,
            Size    => $size,
            Index   => $index,
        );
        $pos += $size;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process Audible 'cvrx' cover art atom (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessAudible_cvrx($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $dirLen = length $$dataPt;
    return 0 if 0x0a > $dirLen;
    my $len = Get16u($dataPt, 0x08);
    return 0 if 0x0a + $len + 6 > $dirLen;
    my $size = Get32u($dataPt, 0x0a + $len + 2);
    return 0 if 0x0a + $len + 6 + $size > $dirLen;
    $et->VerboseDir('Audible_cvrx', undef, $dirLen);
    $et->HandleTag($tagTablePtr, 'CoverArtType', undef,
        DataPt  => $dataPt,
        DataPos => $dataPos,
        Start   => 0x0a,
        Size    => $len,
    );
    $et->HandleTag($tagTablePtr, 'CoverArt', undef,
        DataPt  => $dataPt,
        DataPos => $dataPos,
        Start   => 0x0a + $len + 6,
        Size    => $size,
    );
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Audible - Read meta information from Audible audio books

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read meta
information from Audible audio books.

=head1 AUTHOR

Copyright 2003-2015, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Audible Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

