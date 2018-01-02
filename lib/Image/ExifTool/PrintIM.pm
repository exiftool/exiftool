#------------------------------------------------------------------------------
# File:         PrintIM.pm
#
# Description:  Read PrintIM meta information
#
# Revisions:    04/07/2004  - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::PrintIM;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess);

$VERSION = '1.07';

sub ProcessPrintIM($$$);

# PrintIM table (proprietary specification by Epson)
%Image::ExifTool::PrintIM::Main = (
    PROCESS_PROC => \&ProcessPrintIM,
    GROUPS => { 0 => 'PrintIM', 1 => 'PrintIM', 2 => 'Printing' },
    PRINT_CONV => 'sprintf("0x%.8x", $val)',
    TAG_PREFIX => 'PrintIM',
    PrintIMVersion => { # values: 0100, 0250, 0260, 0300
        Description => 'PrintIM Version',
        PrintConv => undef,
    },
    # the following names are from http://www.kanzaki.com/ns/exif
    # but the decoding is unknown:
    # 9  => { Name => 'PIMContrast',     Unknown => 1 }, #1
    # 10 => { Name => 'PIMBrightness',   Unknown => 1 }, #1
    # 11 => { Name => 'PIMColorbalance', Unknown => 1 }, #1
    # 12 => { Name => 'PIMSaturation',   Unknown => 1 }, #1
    # 13 => { Name => 'PIMSharpness',    Unknown => 1 }, #1
);


#------------------------------------------------------------------------------
# Process PrintIM IFD
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessPrintIM($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $offset = $$dirInfo{DirStart};
    my $size = $$dirInfo{DirLen};
    my $verbose = $et->Options('Verbose');

    unless ($size) {
        $et->Warn('Empty PrintIM data', 1);
        return 0;
    }
    unless ($size > 15) {
        $et->Warn('Bad PrintIM data');
        return 0;
    }
    unless (substr($$dataPt, $offset, 7) eq 'PrintIM') {
        $et->Warn('Invalid PrintIM header');
        return 0;
    }
    # check size of PrintIM block
    my $num = Get16u($dataPt, $offset + 14);
    if ($size < 16 + $num * 6) {
        # size is too big, maybe byte ordering is wrong
        ToggleByteOrder();
        $num = Get16u($dataPt, $offset + 14);
        if ($size < 16 + $num * 6) {
            $et->Warn('Bad PrintIM size');
            return 0;
        }
    }
    $verbose and $et->VerboseDir('PrintIM', $num);
    $et->HandleTag($tagTablePtr, 'PrintIMVersion', substr($$dataPt, $offset + 8, 4),
        DataPt => $dataPt,
        Start  => $offset + 8,
        Size   => 4,
    );
    my $n;
    for ($n=0; $n<$num; ++$n) {
        my $pos = $offset + 16 + $n * 6;
        my $tag = Get16u($dataPt, $pos);
        my $val = Get32u($dataPt, $pos + 2);
        $et->HandleTag($tagTablePtr, $tag, $val,
            Index  => $n,
            DataPt => $dataPt,
            Start  => $pos + 2,
            Size   => 4,
        );
    }
    return 1;
}


1;  # end

__END__

=head1 NAME

Image::ExifTool::PrintIM - Read PrintIM meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Print Image Matching meta information.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PrintIM Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
