#------------------------------------------------------------------------------
# File:         Audible.pm
#
# Description:  Read metadata from Audible audio books
#
# Revisions:    2015/04/05 - P. Harvey Created
#
# References:   1) https://github.com/jteeuwen/audible
#               2) https://code.google.com/p/pyaudibletags/
#               3) http://wiki.multimedia.cx/index.php?title=Audible_Audio
#------------------------------------------------------------------------------

package Image::ExifTool::Audible;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.02';

sub ProcessAudible_meta($$$);
sub ProcessAudible_cvrx($$$);

%Image::ExifTool::Audible::Main = (
    GROUPS => { 2 => 'Audio' },
    NOTES => q{
        ExifTool will extract any information found in the metadata dictionary of
        Audible .AA files, even if not listed in the table below.
    },
    # tags found in the metadata dictionary (chunk 2)
    pubdate    => { Name => 'PublishDate', Groups => { 2 => 'Time' } },
    pub_date_start => { Name => 'PublishDateStart', Groups => { 2 => 'Time' } },
    author     => { Name => 'Author',      Groups => { 2 => 'Author' } },
    copyright  => { Name => 'Copyright',   Groups => { 2 => 'Author' } },
    # also seen (ref PH):
    # product_id, parent_id, title, provider, narrator, price, description,
    # long_description, short_title, is_aggregation, title_id, codec, HeaderSeed,
    # EncryptedBlocks, HeaderKey, license_list, CPUType, license_count, <12 hex digits>,
    # parent_short_title, parent_title, aggregation_id, short_description, user_alias

    # information extracted from other chunks
    _chapter_count => { Name => 'ChapterCount' },       # from chunk 6
    _cover_art => { # from chunk 11
        Name => 'CoverArt',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
);

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
    CoverArt     => {
        Name => 'CoverArt',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
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
# Process Audible 'meta' tags from M4B files (ref PH)
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
            my $name = Image::ExifTool::MakeTagName(($tag =~ /[a-z]/) ? $tag : lc($tag));
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
# Process Audible 'cvrx' cover art atom from M4B files (ref PH)
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

#------------------------------------------------------------------------------
# Read information from an Audible .AA file
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid AA file
sub ProcessAA($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $toc, $entry, $i);

    # check magic number
    return 0 unless $raf->Read($buff, 16) == 16 and $buff=~/^.{4}\x57\x90\x75\x36/s;
    # check file size
    if (defined $$et{VALUE}{FileSize}) {
        # first 4 bytes of the file should be the filesize
        unpack('N', $buff) == $$et{VALUE}{FileSize} or return 0;
    }
    $et->SetFileType();
    SetByteOrder('MM');
    my $bytes = 12 * Get32u(\$buff, 8); # table of contents size in bytes
    $bytes > 0xc00 and $et->Warn('Invalid TOC'), return 1;
    # read the table of contents
    $raf->Read($toc, $bytes) == $bytes or $et->Warn('Truncated TOC'), return 1;
    my $tagTablePtr = GetTagTable('Image::ExifTool::Audible::Main');
    # parse table of contents (in $toc)
    for ($entry=0; $entry<$bytes; $entry+=12) {
        my $type = Get32u(\$toc, $entry);
        next unless $type == 2 or $type == 6 or $type == 11;
        my $offset = Get32u(\$toc, $entry + 4);
        my $length = Get32u(\$toc, $entry + 8) or next;
        $raf->Seek($offset, 0) or $et->Warn("Chunk $type seek error"), last;
        if ($type == 6) {   # offset table
            next if $length < 4 or $raf->Read($buff, 4) != 4; # only read the chapter count
            $et->HandleTag($tagTablePtr, '_chapter_count', Get32u(\$buff, 0));
            next;
        }
        # read the chunk
        $length > 100000000 and $et->Warn("Chunk $type too big"), next;
        $raf->Read($buff, $length) == $length or $et->Warn("Chunk $type read error"), last;
        if ($type == 11) {  # cover art
            next if $length < 8;
            my $len = Get32u(\$buff, 0);
            my $off = Get32u(\$buff, 4);
            next if $off < $offset + 8 or $off - $offset + $len > $length;
            $et->HandleTag($tagTablePtr, '_cover_art', substr($buff, $off-$offset, $len));
            next;
        }
        # parse metadata dictionary (in $buff)
        $length < 4 and $et->Warn('Bad dictionary'), next;
        my $num = Get32u(\$buff, 0);
        $num > 0x200 and $et->Warn('Bad dictionary count'), next;
        my $pos = 4;    # dictionary starts immediately after count
        require Image::ExifTool::HTML;  # (for UnescapeHTML)
        $et->VerboseDir('Audible Metadata', $num);
        for ($i=0; $i<$num; ++$i) {
            my $tagPos = $pos + 9;                  # position of tag string
            $tagPos > $length and $et->Warn('Truncated dictionary'), last;
            # (1 unknown byte ignored at start of each dictionary entry)
            my $tagLen = Get32u(\$buff, $pos + 1);  # tag string length
            my $valLen = Get32u(\$buff, $pos + 5);  # value string length
            my $valPos = $tagPos + $tagLen;         # position of value string
            my $nxtPos = $valPos + $valLen;         # position of next entry
            $nxtPos > $length and $et->Warn('Bad dictionary entry'), last;
            my $tag = substr($buff, $tagPos, $tagLen);
            my $val = substr($buff, $valPos, $valLen);
            unless ($$tagTablePtr{$tag}) {
                my $name = Image::ExifTool::MakeTagName($tag);
                $name =~ s/_(.)/\U$1/g; # change from underscore-separated to mixed case
                AddTagToTable($tagTablePtr, $tag, { Name => $name });
            }
            # unescape HTML character references and convert from UTF-8
            $val = $et->Decode(Image::ExifTool::HTML::UnescapeHTML($val), 'UTF8');
            $et->HandleTag($tagTablePtr, $tag, $val,
                DataPos => $offset,
                DataPt  => \$buff,
                Start   => $valPos,
                Size    => $valLen,
                Index   => $i,
            );
            $pos = $nxtPos; # step to next dictionary entry
        }
    }
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

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://github.com/jteeuwen/audible>

=item L<https://code.google.com/p/pyaudibletags/>

=item L<http://wiki.multimedia.cx/index.php?title=Audible_Audio>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Audible Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

