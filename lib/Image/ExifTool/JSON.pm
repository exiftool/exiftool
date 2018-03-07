#------------------------------------------------------------------------------
# File:         JSON.pm
#
# Description:  Read JSON files
#
# Notes:        Set ExifTool MissingTagValue to "null" to ignore JSON nulls
#
# Revisions:    2017/03/13 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::JSON;
use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Import;

$VERSION = '1.01';

sub ProcessTag($$$$%);

%Image::ExifTool::JSON::Main = (
    GROUPS => { 0 => 'JSON', 1 => 'JSON', 2 => 'Other' },
    NOTES => q{
        No JSON tags have been pre-defined, but ExifTool will read any existing
        tags from basic JSON-formatted files.
    },
);

#------------------------------------------------------------------------------
# Store a tag value
# Inputs: 0) ExifTool ref, 1) tag table, 2) tag ID, 3) value, 4) tagInfo flags
sub FoundTag($$$$%)
{
    my ($et, $tagTablePtr, $tag, $val, %flags) = @_;

    # avoid conflict with special table entries
    $tag .= '!' if $Image::ExifTool::specialTags{$tag};

    AddTagToTable($tagTablePtr, $tag, {
        Name => Image::ExifTool::MakeTagName($tag),
        %flags,
    }) unless $$tagTablePtr{$tag};

    $et->HandleTag($tagTablePtr, $tag, $val);
}

#------------------------------------------------------------------------------
# Process a JSON tag
# Inputs: 0) ExifTool ref, 1) tag table, 2) tag ID, 3) value, 4) tagInfo flags
# - expands structures into flattened tags as required
sub ProcessTag($$$$%)
{
    local $_;
    my ($et, $tagTablePtr, $tag, $val, %flags) = @_;

    if (ref $val eq 'HASH') {
        if ($et->Options('Struct')) {
            FoundTag($et, $tagTablePtr, $tag, $val, %flags, Struct => 1);
            return unless $et->Options('Struct') > 1;
        }
        foreach (sort keys %$val) {
            ProcessTag($et, $tagTablePtr, $tag . ucfirst, $$val{$_}, %flags, Flat => 1);
        }
    } elsif (ref $val eq 'ARRAY') {
        foreach (@$val) {
            ProcessTag($et, $tagTablePtr, $tag, $_, %flags, List => 1);
        }
    } elsif (defined $val) {
        FoundTag($et, $tagTablePtr, $tag, $val, %flags);
    }
}

#------------------------------------------------------------------------------
# Extract meta information from a JSON file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a recognized JSON file
sub ProcessJSON($$)
{
    local $_;
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $structOpt = $et->Options('Struct');
    my (%database, $key, $tag);

    # read information from JSON file into database structure
    my $err = Image::ExifTool::Import::ReadJSON($raf, \%database,
        $et->Options('MissingTagValue'), $et->Options('Charset'));

    return 0 if $err or not %database;

    $et->SetFileType();

    my $tagTablePtr = GetTagTable('Image::ExifTool::JSON::Main');

    # remove any old tag definitions in case they change flags
    foreach $key (TagTableKeys($tagTablePtr)) {
        delete $$tagTablePtr{$key};
    }

    # extract tags from JSON database
    foreach $key (sort keys %database) {
        foreach $tag (sort keys %{$database{$key}}) {
            my $val = $database{$key}{$tag};
            # (ignore SourceFile if generated automatically by ReadJSON)
            next if $tag eq 'SourceFile' and defined $val and $val eq '*';
            ProcessTag($et, $tagTablePtr, $tag, $val);
        }
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::JSON - Read JSON files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool read
information from JSON files.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/JSON Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

