#------------------------------------------------------------------------------
# File:         JVC.pm
#
# Description:  JVC EXIF maker notes tags
#
# Revisions:    12/21/2005  - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::JVC;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.04';

sub ProcessJVCText($$$);

# JVC EXIF-based maker notes
%Image::ExifTool::JVC::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    NOTES => 'JVC EXIF maker note tags.',
    #0x0001 - almost always '2', but '3' for GR-DV700 samples
    0x0002 => { #PH
        Name => 'CPUVersions',
        # remove trailing nulls/spaces and split at remaining nulls/spaces
        ValueConv => '$_=$val; s/(\s*\0)+$//; s/(\s*\0)+/, /g; $_',
    },
    0x0003 => { #PH
        Name => 'Quality',
        PrintConv => {
            0 => 'Low',
            1 => 'Normal',
            2 => 'Fine',
        },
    },
);

# JVC text-based maker notes
%Image::ExifTool::JVC::Text = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&ProcessJVCText,
    NOTES => 'JVC/Victor text-based maker note tags.',
    VER => 'MakerNoteVersion', #PH
    QTY => { #PH
        Name => 'Quality',
        PrintConv => {
            STND => 'Normal',
            STD  => 'Normal',
            FINE => 'Fine',
        },
    },
);

#------------------------------------------------------------------------------
# Process JVC text-based maker notes
# Inputs: 0) ExifTool object reference
#         1) Reference to directory information hash
#         2) Pointer to tag table for this directory
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessJVCText($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dataLen = $$dirInfo{DataLen};
    my $dirLen = $$dirInfo{DirLen} || $dataLen - $dirStart;
    my $verbose = $et->Options('Verbose');

    my $data = substr($$dataPt, $dirStart, $dirLen);
    # validate text maker notes
    unless ($data =~ /^VER:/) {
        $et->Warn('Bad JVC text maker notes');
        return 0;
    }
    while ($data =~ m/([A-Z]+):(.{3,4})/sg) {
        my ($tag, $val) = ($1, $2);
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        $et->VerboseInfo($tag, $tagInfo,
            Table  => $tagTablePtr,
            Value  => $val,
        ) if $verbose;
        unless ($tagInfo) {
            next unless $$et{OPTIONS}{Unknown};
            $tagInfo = {
                Name => "JVC_Text_$tag",
                Unknown => 1,
                PrintConv => \&Image::ExifTool::LimitLongValues,
            };
            # add tag information to table
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        $et->FoundTag($tagInfo, $val);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::JVC - JVC EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains routines used by Image::ExifTool to interpret JVC maker
notes.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/JVC Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
