#------------------------------------------------------------------------------
# File:         Torrent.pm
#
# Description:  Read information from BitTorrent file
#
# Revisions:    2013/08/27 - P. Harvey Created
#
# References:   1) https://wiki.theory.org/BitTorrentSpecification
#------------------------------------------------------------------------------

package Image::ExifTool::Torrent;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.03';

sub ReadBencode($$);
sub ExtractTags($$$;$$@);

# tags extracted from BitTorrent files
%Image::ExifTool::Torrent::Main = (
    GROUPS => { 2 => 'Document' },
    NOTES => q{
        Below are tags commonly found in BitTorrent files.  As well as these tags,
        any other existing tags will be extracted.  For convenience, list items are
        expanded into individual tags with an index in the tag name, but only the
        tags with index "1" are listed in the tables below.  See
        L<https://wiki.theory.org/BitTorrentSpecification> for the BitTorrent
        specification.
    },
    'announce'      => { },
    'announce-list' => { Name => 'AnnounceList1' },
    'comment'       => { },
    'created by'    => { Name => 'Creator' }, # software used to create the torrent
    'creation date' => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        ValueConv => 'ConvertUnixTime($val,1)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    'encoding'      => { },
    'info'          => { SubDirectory => { TagTable => 'Image::ExifTool::Torrent::Info' } },
    'url-list'      => { Name => 'URLList1' },
);

%Image::ExifTool::Torrent::Info = (
    GROUPS => { 2 => 'Document' },
    'file-duration' => { Name => 'File1Duration' },
    'file-media'    => { Name => 'File1Media' },
    'files'         => { SubDirectory => { TagTable => 'Image::ExifTool::Torrent::Files' } },
    'length'        => { },
    'md5sum'        => { Name => 'MD5Sum' },
    'name'          => { },
    'name.utf-8'    => { Name => 'NameUTF-8' },
    'piece length'  => { Name => 'PieceLength' },
    'pieces'        => {
        Name => 'Pieces',
        Notes => 'concatenation of 20-byte SHA-1 digests for each piece',
    },
    'private'       => { },
    'profiles'      => { SubDirectory => { TagTable => 'Image::ExifTool::Torrent::Profiles' } },
);

%Image::ExifTool::Torrent::Profiles = (
    GROUPS => { 2 => 'Document' },
    'width'         => { Name => 'Profile1Width' },
    'height'        => { Name => 'Profile1Height' },
    'acodec'        => { Name => 'Profile1AudioCodec' },
    'vcodec'        => { Name => 'Profile1VideoCodec' },
);

%Image::ExifTool::Torrent::Files = (
    GROUPS => { 2 => 'Document' },
    'length'        => { Name => 'File1Length', PrintConv => 'ConvertFileSize($val)' },
    'md5sum'        => { Name => 'File1MD5Sum'  },
    'path'          => { Name => 'File1Path', JoinPath => 1 },
    'path.utf-8'    => { Name => 'File1PathUTF-8', JoinPath => 1 },
);

#------------------------------------------------------------------------------
# Read 64kB more data into buffer
# Inputs: 0) RAF ref, 1) buffer ref
# Returns: number of bytes read
# Notes: Sets BencodeEOF element of RAF on end of file
sub ReadMore($$)
{
    my ($raf, $dataPt) = @_;
    my $buf2;
    my $n = $raf->Read($buf2, 65536);
    $$raf{BencodeEOF} = 1 if $n != 65536;
    $$dataPt = substr($$dataPt, pos($$dataPt)) . $buf2 if $n;
    return $n;
}

#------------------------------------------------------------------------------
# Read bencoded value
# Inputs: 0) input file, 1) buffer (pos must be set to current position)
# Returns: HASH ref, ARRAY ref, SCALAR ref, SCALAR, or undef on error or end of data
# Notes: Sets BencodeError element of RAF on any error
sub ReadBencode($$)
{
    my ($raf, $dataPt) = @_;

    # read more if necessary (keep a minimum of 64 bytes in the buffer)
    my $pos = pos($$dataPt);
    return undef unless defined $pos;
    my $remaining = length($$dataPt) - $pos;
    ReadMore($raf, $dataPt) if $remaining < 64 and not $$raf{BencodeEOF};

    # read next token
    $$dataPt =~ /(.)/sg or return undef;

    my $val;
    my $tok = $1;
    if ($tok eq 'i') {      # integer
        $$dataPt =~ /\G(-?\d+)e/g or return $val;
        $val = $1;
    } elsif ($tok eq 'd') { # dictionary
        $val = { };
        for (;;) {
            my $k = ReadBencode($raf, $dataPt);
            last unless defined $k;
            # the key must be a byte string
            if (ref $k) {
                ref $k ne 'SCALAR' and $$raf{BencodeError} = 'Bad dictionary key', last;
                $k = $$k;
            }
            my $v = ReadBencode($raf, $dataPt);
            last unless defined $v;
            $$val{$k} = $v;
        }
    } elsif ($tok eq 'l') { # list
        $val = [ ];
        for (;;) {
            my $v = ReadBencode($raf, $dataPt);
            last unless defined $v;
            push @$val, $v;
        }
    } elsif ($tok eq 'e') { # end of dictionary or list
        # return undef (no error)
    } elsif ($tok =~ /^\d$/ and $$dataPt =~ /\G(\d*):/g) { # byte string
        my $len = $tok . $1;
        my $more = $len - (length($$dataPt) - pos($$dataPt));
        my $value;
        if ($more <= 0) {
            $value = substr($$dataPt,pos($$dataPt),$len);
            pos($$dataPt) = pos($$dataPt) + $len;
        } elsif ($more > 10000000) {
            # just skip over really long values
            $val = \ "(Binary data $len bytes)" if $raf->Seek($more, 1);
        } else {
            # need to read more from file
            my $buff;
            my $n = $raf->Read($buff, $more);
            if ($n == $more) {
                $value = substr($$dataPt,pos($$dataPt)) . $buff;
                $$dataPt = '';
                pos($$dataPt) = 0;
            }
        }
        if (defined $value) {
            # return as binary data unless it is a reasonable-length ASCII string
            if (length($value) > 256 or $value =~ /[^\t\x20-\x7e]/) {
                $val = \$value;
            } else {
                $val = $value;
            }
        } elsif (not defined $val) {
            $$raf{BencodeError} = 'Truncated byte string';
        }
    } else {
        $$raf{BencodeError} = 'Bad format';
    }
    return $val;
}

#------------------------------------------------------------------------------
# Extract tags from dictionary hash
# Inputs: 0) ExifTool ref, 1) dictionary hash reference, 2) tag table ref,
#         3) parent hash ID, 4) parent hash name, 5-N) list indices
# Returns: number of tags extracted
sub ExtractTags($$$;$$@)
{
    my ($et, $hashPtr, $tagTablePtr, $baseID, $baseName, @index) = @_;
    my $count = 0;
    my $tag;
    foreach $tag (sort keys %$hashPtr) {
        my $val = $$hashPtr{$tag};
        my ($i, $j, @more);
        for (; defined $val; $val = shift @more) {
            my $id = defined $baseID ? "$baseID/$tag" : $tag;
            unless ($$tagTablePtr{$id}) {
                my $name = ucfirst $tag;
                # capitalize all words in tag name and remove illegal characters
                $name =~ s/[^-_a-zA-Z0-9]+(.?)/\U$1/g;
                $name = "Tag$name" if length($name) < 2 or $name !~ /^[A-Z]/;
                $name = $baseName . $name if defined $baseName; # add base name if necessary
                AddTagToTable($tagTablePtr, $id, { Name => $name });
                $et->VPrint(0, "  [adding $id '$name']\n");
            }
            my $tagInfo = $et->GetTagInfo($tagTablePtr, $id) or next;
            if (ref $val eq 'ARRAY') {
                if ($$tagInfo{JoinPath}) {
                    $val = join '/', @$val;
                } else {
                    push @more, @$val;
                    next if ref $more[0] eq 'ARRAY'; # continue expanding nested lists
                    $val = shift @more;
                    $i or $i = 0, push(@index, $i);
                }
            }
            $index[-1] = ++$i if defined $i;
            if (@index) {
                $id .= join '_', @index;  # add instance number(s) to tag ID
                unless ($$tagTablePtr{$id}) {
                    my $name = $$tagInfo{Name};
                    # embed indices at position of '1' in tag name
                    my $n = ($name =~ tr/1/#/);
                    for ($j=0; $j<$n; ++$j) {
                        my $idx = $index[$j] || '';
                        $name =~ s/#/$idx/;
                    }
                    # put remaining indices at end of tag name
                    for (; $j<@index; ++$j) {
                        $name .= '_' if $name =~ /\d$/;
                        $name .= $index[$j];
                    }
                    AddTagToTable($tagTablePtr, $id, { %$tagInfo, Name => $name });
                }
                $tagInfo = $et->GetTagInfo($tagTablePtr, $id) or next;
            }
            if (ref $val eq 'HASH') {
                # extract tags from this dictionary
                my ($table, $rootID, $rootName);
                if ($$tagInfo{SubDirectory}) {
                    $table = GetTagTable($$tagInfo{SubDirectory}{TagTable});
                } else {
                    $table = $tagTablePtr;
                    # use hash ID and Name as base for contained tags to avoid conflicts
                    $rootID = $id;
                    $rootName = $$tagInfo{Name};
                }
                $count += ExtractTags($et, $val, $table, $rootID, $rootName, @index);
            } else {
                # handle this simple tag value
                $et->HandleTag($tagTablePtr, $id, $val);
                ++$count;
            }
        }
        pop @index if defined $i;
    }
    return $count;
}

#------------------------------------------------------------------------------
# Process BitTorrent file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference (with RAF set)
# Returns: 1 on success, 0 if this wasn't a valid BitTorrent file
sub ProcessTorrent($$)
{
    my ($et, $dirInfo) = @_;
    my $success = 0;
    my $raf = $$dirInfo{RAF};
    my $buff = '';
    pos($buff) = 0;
    my $dict = ReadBencode($raf, \$buff);
    my $err = $$raf{BencodeError};
    $et->Warn("Bencode error: $err") if $err;
    if (ref $dict eq 'HASH' and $$dict{announce}) {
        $et->SetFileType();
        my $tagTablePtr = GetTagTable('Image::ExifTool::Torrent::Main');
        ExtractTags($et, $dict, $tagTablePtr) and $success = 1;
    }
    return $success;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Torrent - Read information from BitTorrent file

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read
bencoded information from BitTorrent files.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://wiki.theory.org/BitTorrentSpecification>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Torrent Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

