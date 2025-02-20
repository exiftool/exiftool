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

$VERSION = '1.10';

sub ProcessJSON($$);
sub ProcessTag($$$$%);

%Image::ExifTool::JSON::Main = (
    GROUPS => { 0 => 'JSON', 1 => 'JSON', 2 => 'Other' },
    VARS => { NO_ID => 1 },
    PROCESS_PROC => \&ProcessJSON,
    NOTES => q{
        Other than a few tags in the table below, JSON tags have not been
        pre-defined.  However, ExifTool will read any existing tags from basic
        JSON-formatted files.
    },
    # ON1 settings tags
    ON1_SettingsData => {
        RawConv => q{
            require Image::ExifTool::XMP;
            $val = Image::ExifTool::XMP::DecodeBase64($val);
        },
        SubDirectory => { TagTable => 'Image::ExifTool::PLIST::Main' },
    },
    ON1_SettingsMetadataCreated     => { Groups => { 2 => 'Time' } },
    ON1_SettingsMetadataModified    => { Groups => { 2 => 'Time' } },
    ON1_SettingsMetadataName        => { },
    ON1_SettingsMetadataPluginID    => { },
    ON1_SettingsMetadataTimestamp   => { Groups => { 2 => 'Time' } },
    ON1_SettingsMetadataUsage       => { },
    ON1_SettingsMetadataVisibleToUser=>{ },
    adjustmentsSettingsStatisticsLightMap => { # (in JSON of AAE files)
        Name => 'AdjustmentsSettingsStatisticsLightMap',
        ValueConv => 'Image::ExifTool::XMP::DecodeBase64($val)',
    },
);

#------------------------------------------------------------------------------
# Store a tag value
# Inputs: 0) ExifTool ref, 1) tag table, 2) tag ID, 3) value, 4) tagInfo flags
sub FoundTag($$$$%)
{
    my ($et, $tagTablePtr, $tag, $val, %flags) = @_;

    # special case to reformat ON1 tag names
    if ($tag =~ s/^settings\w{8}-\w{4}-\w{4}-\w{4}-\w{12}(Data|Metadata.+)$/ON1_Settings$1/) {
        $et->OverrideFileType('ONP','application/on1') if $$et{FILE_TYPE} eq 'JSON';
    }

    # avoid conflict with special table entries
    $tag .= '!' if $Image::ExifTool::specialTags{$tag};

    unless ($$tagTablePtr{$tag}) {
        my $name = $tag;
        $name =~ tr/:/_/; # use underlines in place of colons in tag name
        $name =~ s/^c2pa/C2PA/i;   # hack to fix "C2PA" case
        $name = Image::ExifTool::MakeTagName($name);
        my $desc = Image::ExifTool::MakeDescription($name);
        $desc =~ s/^C2 PA/C2PA/;    # hack to get "C2PA" correct
        AddTagToTable($tagTablePtr, $tag, {
            Name => $name,
            Description => $desc,
            %flags,
            Temporary => 1,
        });
    }
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
        # support hashes with ordered keys
        foreach (Image::ExifTool::OrderedKeys($val)) {
            my $tg = $tag . ((/^\d/ and $tag =~ /\d$/) ? '_' : '') . ucfirst;
            $tg =~ s/([^a-zA-Z])([a-z])/$1\U$2/g;
            ProcessTag($et, $tagTablePtr, $tg, $$val{$_}, %flags, Flat => 1);
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
    my (%database, $key, $tag, $dataPt);

    unless ($raf) {
        $dataPt = $$dirInfo{DataPt};
        if ($$dirInfo{DirStart} or ($$dirInfo{DirLen} and $$dirInfo{DirLen} ne length($$dataPt))) {
            my $buff = substr(${$$dirInfo{DataPt}}, $$dirInfo{DirStart}, $$dirInfo{DirLen});
            $dataPt = \$buff;
        }
        $raf = File::RandomAccess->new($dataPt);
        # extract as a block if requested
        my $blockName = $$dirInfo{BlockInfo} ? $$dirInfo{BlockInfo}{Name} : '';
        my $blockExtract = $et->Options('BlockExtract');
        if ($blockName and ($blockExtract or $$et{REQ_TAG_LOOKUP}{lc $blockName} or
            ($$et{TAGS_FROM_FILE} and not $$et{EXCL_TAG_LOOKUP}{lc $blockName})))
        {
            $et->FoundTag($$dirInfo{BlockInfo}, $$dataPt);
            return 1 if $blockExtract and $blockExtract > 1;
        }
        $et->VerboseDir('JSON');
    }

    # read information from JSON file into database structure
    my $err = Image::ExifTool::Import::ReadJSON($raf, \%database,
        $et->Options('MissingTagValue'), $et->Options('Charset'));

    return 0 if $err or not %database;

    $et->SetFileType() unless $dataPt;

    my $tagTablePtr = GetTagTable('Image::ExifTool::JSON::Main');

    # remove any old tag definitions in case they change flags
    foreach $key (TagTableKeys($tagTablePtr)) {
        delete $$tagTablePtr{$key} if $$tagTablePtr{$key}{Temporary};
    }

    # extract tags from JSON database
    foreach $key (sort keys %database) {
        foreach $tag (Image::ExifTool::OrderedKeys($database{$key})) {
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

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/JSON Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

