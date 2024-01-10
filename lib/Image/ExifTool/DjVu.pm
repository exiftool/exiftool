#------------------------------------------------------------------------------
# File:         DjVu.pm
#
# Description:  Read DjVu archive meta information
#
# Revisions:    09/25/2008 - P. Harvey Created
#
# References:   1) http://djvu.sourceforge.net/ (DjVu v3 specification, Nov 2005)
#               2) http://www.djvu.org/
#
# Notes:        DjVu files are recognized and the IFF structure is processed
#               by Image::ExifTool::AIFF
#------------------------------------------------------------------------------

package Image::ExifTool::DjVu;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.07';

sub ParseAnt($);
sub ProcessAnt($$$);
sub ProcessMeta($$$);
sub ProcessBZZ($$$);

# DjVu chunks that we parse (ref 4)
%Image::ExifTool::DjVu::Main = (
    GROUPS => { 2 => 'Image' },
    NOTES => q{
        Information is extracted from the following chunks in DjVu images. See
        L<http://www.djvu.org/> for the DjVu specification.
    },
    INFO => {
        SubDirectory => { TagTable => 'Image::ExifTool::DjVu::Info' },
    },
    FORM => {
        TypeOnly => 1,  # extract chunk type only, then descend into chunk
        SubDirectory => { TagTable => 'Image::ExifTool::DjVu::Form' },
    },
    ANTa => {
        SubDirectory => { TagTable => 'Image::ExifTool::DjVu::Ant' },
    },
    ANTz => {
        Name => 'CompressedAnnotation',
        SubDirectory => {
            TagTable => 'Image::ExifTool::DjVu::Ant',
            ProcessProc => \&ProcessBZZ,
        }
    },
    INCL => 'IncludedFileID',
);

# information in the DjVu INFO chunk
%Image::ExifTool::DjVu::Info = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int8u',
    PRIORITY => 0, # first INFO block takes priority
    0 => {
        Name => 'ImageWidth',
        Format => 'int16u',
    },
    2 => {
        Name => 'ImageHeight',
        Format => 'int16u',
    },
    4 => {
        Name => 'DjVuVersion',
        Description => 'DjVu Version',
        Format => 'int8u[2]',
        # (this may be just one byte as with version 0.16)
        ValueConv => '$val=~/(\d+) (\d+)/ ? "$2.$1" : "0.$val"',
    },
    6 => {
        Name => 'SpatialResolution',
        Format => 'int16u',
        ValueConv => '(($val & 0xff)<<8) + ($val>>8)', # (little-endian!)
    },
    8 => {
        Name => 'Gamma',
        ValueConv => '$val / 10',
    },
    9 => {
        Name => 'Orientation',
        Mask => 0x07, # (upper 5 bits reserved)
        PrintConv => {
            1 => 'Horizontal (normal)',
            2 => 'Rotate 180',
            5 => 'Rotate 90 CW',
            6 => 'Rotate 270 CW',
        },
    },
);

# information in the DjVu FORM chunk
%Image::ExifTool::DjVu::Form = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => {
        Name => 'SubfileType',
        Format => 'undef[4]',
        Priority => 0,
        PrintConv => {
            DJVU => 'Single-page image',
            DJVM => 'Multi-page document',
            PM44 => 'Color IW44',
            BM44 => 'Grayscale IW44',
            DJVI => 'Shared component',
            THUM => 'Thumbnail image',
        },
    },
);

# tags found in the DjVu annotation chunk (ANTz or ANTa)
%Image::ExifTool::DjVu::Ant = (
    PROCESS_PROC => \&Image::ExifTool::DjVu::ProcessAnt,
    GROUPS => { 2 => 'Image' },
    NOTES => 'Information extracted from annotation chunks.',
    # Note: For speed, ProcessAnt() pre-scans for known tag ID's, so if any
    # new tags are added here they must also be added to the pre-scan check
    metadata => {
        SubDirectory => { TagTable => 'Image::ExifTool::DjVu::Meta' }
    },
    xmp => {
        Name => 'XMP',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' }
    },
);

# tags found in the DjVu annotation metadata
%Image::ExifTool::DjVu::Meta = (
    PROCESS_PROC => \&Image::ExifTool::DjVu::ProcessMeta,
    GROUPS => { 1 => 'DjVu-Meta', 2 => 'Image' },
    NOTES => q{
        This table lists the standard DjVu metadata tags, but ExifTool will extract
        any tags that exist even if they don't appear here.  The DjVu v3
        documentation endorses tags borrowed from two standards: 1) BibTeX
        bibliography system tags (all lowercase Tag ID's in the table below), and 2)
        PDF DocInfo tags (capitalized Tag ID's).
    },
    # BibTeX tags (ref http://en.wikipedia.org/wiki/BibTeX)
    address     => { Groups => { 2 => 'Location' } },
    annote      => { Name => 'Annotation' },
    author      => { Groups => { 2 => 'Author' } },
    booktitle   => { Name => 'BookTitle' },
    chapter     => { },
    crossref    => { Name => 'CrossRef' },
    edition     => { },
    eprint      => { Name => 'EPrint' },
    howpublished=> { Name => 'HowPublished' },
    institution => { },
    journal     => { },
    key         => { },
    month       => { Groups => { 2 => 'Time' } },
    note        => { },
    number      => { },
    organization=> { },
    pages       => { },
    publisher   => { },
    school      => { },
    series      => { },
    title       => { },
    type        => { },
    url         => { Name => 'URL' },
    volume      => { },
    year        => { Groups => { 2 => 'Time' } },
    # PDF tags (same as Image::ExifTool::PDF::Info)
    Title       => { },
    Author      => { Groups => { 2 => 'Author' } },
    Subject     => { },
    Keywords    => { },
    Creator     => { },
    Producer    => { },
    CreationDate => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        # RFC 3339 date/time format
        ValueConv => 'require Image::ExifTool::XMP; Image::ExifTool::XMP::ConvertXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    ModDate => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        ValueConv => 'require Image::ExifTool::XMP; Image::ExifTool::XMP::ConvertXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Trapped => {
        # remove leading '/' from '/True' or '/False'
        ValueConv => '$val=~s{^/}{}; $val',
    },
);

#------------------------------------------------------------------------------
# Parse DjVu annotation "s-expression" syntax (recursively)
# Inputs: 0) data ref (with pos($$dataPt) set to start of annotation)
# Returns: reference to list of tokens/references, or undef if no tokens,
#          and the position in $$dataPt is set to end of last token
# Notes: The DjVu annotation syntax is not well documented, so I make
#        a number of assumptions here!
sub ParseAnt($)
{
    my $dataPt = shift;
    my (@toks, $tok, $more);
    # (the DjVu annotation syntax really sucks, and requires that every
    # single token be parsed in order to properly scan through the items)
Tok: for (;;) {
        # find the next token
        last unless $$dataPt =~ /(\S)/sg;   # get next non-space character
        if ($1 eq '(') {       # start of list
            $tok = ParseAnt($dataPt);
        } elsif ($1 eq ')') {  # end of list
            $more = 1;
            last;
        } elsif ($1 eq '"') {  # quoted string
            $tok = '';
            for (;;) {
                # get string up to the next quotation mark
                # this doesn't work in perl 5.6.2! grrrr
                # last Tok unless $$dataPt =~ /(.*?)"/sg;
                # $tok .= $1;
                my $pos = pos($$dataPt);
                last Tok unless $$dataPt =~ /"/sg;
                $tok .= substr($$dataPt, $pos, pos($$dataPt)-1-$pos);
                # we're good unless quote was escaped by odd number of backslashes
                last unless $tok =~ /(\\+)$/ and length($1) & 0x01;
                $tok .= '"';    # quote is part of the string
            }
            # convert C escape sequences, allowed in quoted text
            # (note: this only converts a few of them!)
            my %esc = ( a => "\a", b => "\b", f => "\f", n => "\n",
                        r => "\r", t => "\t", '"' => '"', '\\' => '\\' );
            $tok =~ s/\\(.)/$esc{$1}||'\\'.$1/egs;
        } else {                # key name
            pos($$dataPt) = pos($$dataPt) - 1;
            # allow anything in key but whitespace, braces and double quotes
            # (this is one of those assumptions I mentioned)
            $tok = $$dataPt =~ /([^\s()"]+)/sg ? $1 : undef;
        }
        push @toks, $tok if defined $tok;
    }
    # prevent further parsing unless more after this
    pos($$dataPt) = length $$dataPt unless $more;
    return @toks ? \@toks : undef;
}

#------------------------------------------------------------------------------
# Process DjVu annotation chunk (ANTa or decoded ANTz)
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) tag table ref
# Returns: 1 on success
sub ProcessAnt($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};

    # quick pre-scan to check for metadata or XMP
    return 1 unless $$dataPt =~ /\(\s*(metadata|xmp)[\s("]/s;

    # parse annotations into a tree structure
    pos($$dataPt) = 0;
    my $toks = ParseAnt($dataPt) or return 0;

    # process annotations individually
    my $ant;
    foreach $ant (@$toks) {
        next unless ref $ant eq 'ARRAY' and @$ant >= 2;
        my $tag = shift @$ant;
        next if ref $tag or not defined $$tagTablePtr{$tag};
        if ($tag eq 'metadata') {
            # ProcessMeta() takes array reference
            $et->HandleTag($tagTablePtr, $tag, $ant);
        } else {
            next if ref $$ant[0];   # only process simple values
            $et->HandleTag($tagTablePtr, $tag, $$ant[0]);
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process DjVu metadata
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) tag table ref
# Returns: 1 on success
# Notes: input dirInfo DataPt is a reference to a list of pre-parsed metadata entries
sub ProcessMeta($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    return 0 unless ref $$dataPt eq 'ARRAY';
    $et->VerboseDir('Metadata', scalar @$$dataPt);
    my ($item, $err);
    foreach $item (@$$dataPt) {
        # make sure item is a simple tag/value pair
        $err=1, next unless ref $item eq 'ARRAY' and @$item >= 2 and
                            not ref $$item[0] and not ref $$item[1];
        # add any new tags to the table
        unless ($$tagTablePtr{$$item[0]}) {
            my $name = $$item[0];
            $name =~ tr/-_a-zA-Z0-9//dc; # remove illegal characters
            length $name or $err = 1, next;
            AddTagToTable($tagTablePtr, $$item[0], { Name => ucfirst($name) });
        }
        $et->HandleTag($tagTablePtr, $$item[0], $$item[1]);
    }
    $err and $et->Warn('Ignored invalid metadata entry(s)');
    return 1;
}

#------------------------------------------------------------------------------
# Process BZZ-compressed data (in DjVu images)
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) tag table ref
# Returns: 1 on success
sub ProcessBZZ($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    require Image::ExifTool::BZZ;
    my $buff = Image::ExifTool::BZZ::Decode($$dirInfo{DataPt});
    unless (defined $buff) {
        $et->Warn("Error decoding $$dirInfo{DirName}");
        return 0;
    }
    my $verbose = $et->Options('Verbose');
    if ($verbose >= 3) {
        # dump the decoded data in very verbose mode
        $et->VerboseDir("Decoded $$dirInfo{DirName}", 0, length $buff);
        $et->VerboseDump(\$buff);
    }
    $$dirInfo{DataPt} = \$buff;
    $$dirInfo{DataLen} = $$dirInfo{DirLen} = length $buff;
    # process the data using the default process proc for this table
    my $processProc = $$tagTablePtr{PROCESS_PROC} or return 0;
    return &$processProc($et, $dirInfo, $tagTablePtr);
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::DjVu - Read DjVu meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from DjVu images.  Parsing of the DjVu IFF structure is done by
Image::ExifTool::AIFF.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://djvu.sourceforge.net/>

=item L<http://www.djvu.org/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/DjVu Tags>,
L<Image::ExifTool::AIFF(3pm)|Image::ExifTool::AIFF>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

