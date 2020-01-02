#------------------------------------------------------------------------------
# File:         BigTIFF.pm
#
# Description:  Read Big TIFF meta information
#
# Revisions:    07/03/2007 - P. Harvey Created
#
# References:   1) http://www.awaresystems.be/imaging/tiff/bigtiff.html
#------------------------------------------------------------------------------

package Image::ExifTool::BigTIFF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.07';

my $maxOffset = 0x7fffffff; # currently supported maximum data offset/size

#------------------------------------------------------------------------------
# Process Big IFD directory
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessBigIFD($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $$et{OPTIONS}{Verbose};
    my $htmlDump = $$et{HTML_DUMP};
    my $dirName = $$dirInfo{DirName};
    my $dirStart = $$dirInfo{DirStart};
    my ($offName, $nextOffName);

    if ($htmlDump) {
        $verbose = -1;  # mix htmlDump into verbose so we can test for both at once
        $offName = $$dirInfo{OffsetName};
    }

    # loop through IFD chain
    for (;;) {
        if ($dirStart > $maxOffset and not $et->Options('LargeFileSupport')) {
            $et->Warn('Huge offsets not supported (LargeFileSupport not set)');
            last;
        }
        unless ($raf->Seek($dirStart, 0)) {
            $et->Warn("Bad $dirName offset");
            return 0;
        }
        my ($dirBuff, $index);
        unless ($raf->Read($dirBuff, 8) == 8) {
            $et->Warn("Truncated $dirName count");
            return 0;
        }
        my $numEntries = Image::ExifTool::Get64u(\$dirBuff, 0);
        $verbose > 0 and $et->VerboseDir($dirName, $numEntries);
        my $bsize = $numEntries * 20;
        if ($bsize > $maxOffset) {
            $et->Warn('Huge directory counts not yet supported');
            last;
        }
        my $bufPos = $raf->Tell();
        unless ($raf->Read($dirBuff, $bsize) == $bsize) {
            $et->Warn("Truncated $dirName directory");
            return 0;
        }
        my $nextIFD;
        $raf->Read($nextIFD, 8) == 8 or undef $nextIFD; # try to read next IFD pointer
        if ($htmlDump) {
            $et->HDump($bufPos-8, 8, "$dirName entries", "Entry count: $numEntries", undef, $offName);
            if (defined $nextIFD) {
                my $off = Image::ExifTool::Get64u(\$nextIFD, 0);
                my $tip = sprintf("Offset: 0x%.8x", $off);
                my $id = $offName;
                ($nextOffName, $id) = Image::ExifTool::Exif::NextOffsetName($et, $id) if $off;
                $et->HDump($bufPos + 20 * $numEntries, 8, "Next IFD", $tip, 0, $id);
            }
        }
        # loop through all entries in this BigTIFF IFD
        for ($index=0; $index<$numEntries; ++$index) {
            my $entry = 20 * $index;
            my $tagID = Get16u(\$dirBuff, $entry);
            my $format = Get16u(\$dirBuff, $entry+2);
            my $count = Image::ExifTool::Get64u(\$dirBuff, $entry+4);
            my $formatSize = $Image::ExifTool::Exif::formatSize[$format];
            unless (defined $formatSize) {
                $et->HDump($bufPos+$entry,20,"[invalid IFD entry]",
                           "Bad format value: $format", 1, $offName);
                # warn unless the IFD was just padded with zeros
                $et->Warn(sprintf("Unknown format ($format) for $dirName tag 0x%x",$tagID));
                return 0; # assume corrupted IFD
            }
            my $formatStr = $Image::ExifTool::Exif::formatName[$format];
            my $size = $count * $formatSize;
            my $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID);
            next unless defined $tagInfo or $verbose;
            my $valuePtr = $entry + 12;
            my ($valBuff, $valBase, $rational, $subOffName);
            if ($size > 8) {
                if ($size > $maxOffset) {
                    $et->Warn("Can't handle $dirName entry $index (huge size)");
                    next;
                }
                $valuePtr = Image::ExifTool::Get64u(\$dirBuff, $valuePtr);
                if ($valuePtr > $maxOffset and not $et->Options('LargeFileSupport')) {
                    $et->Warn("Can't handle $dirName entry $index (LargeFileSupport not set)");
                    next;
                }
                unless ($raf->Seek($valuePtr, 0) and $raf->Read($valBuff, $size) == $size) {
                    $et->Warn("Error reading $dirName entry $index");
                    next;
                }
                $valBase = 0;
            } else {
                $valBuff = substr($dirBuff, $valuePtr, $size);
                $valBase = $bufPos;
            }
            if (defined $tagInfo and not $tagInfo) {
                # GetTagInfo() required the value for a Condition
                $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID, \$valBuff);
            }
            my $val = ReadValue(\$valBuff, 0, $formatStr, $count, $size, \$rational);
            if ($htmlDump) {
                my $tval = $val;
                # show numerator/denominator separately for rational numbers
                $tval .= " ($rational)" if defined $rational;
                my ($tagName, $colName);
                if ($tagID == 0x927c and $dirName eq 'ExifIFD') {
                    $tagName = 'MakerNotes';
                } elsif ($tagInfo) {
                    $tagName = $$tagInfo{Name};
                } else {
                    $tagName = sprintf("Tag 0x%.4x",$tagID);
                }
                my $dname = sprintf("$dirName-%.2d", $index);
                # build our tool tip
                my $tip = sprintf("Tag ID: 0x%.4x\n", $tagID) .
                          "Format: $formatStr\[$count]\nSize: $size bytes\n";
                if ($size > 8) {
                    $tip .= sprintf("Value offset: 0x%.8x\n", $valuePtr);
                    $colName = "<span class=H>$tagName</span>";
                } else {
                    $colName = $tagName;
                }
                $tval = substr($tval,0,28) . '[...]' if length($tval) > 32;
                if ($formatStr =~ /^(string|undef|binary)/) {
                    # translate non-printable characters
                    $tval =~ tr/\x00-\x1f\x7f-\xff/./;
                } elsif ($tagInfo and Image::ExifTool::IsInt($tval)) {
                    if ($$tagInfo{IsOffset}) {
                        $tval = sprintf('0x%.4x', $tval);
                    } elsif ($$tagInfo{PrintHex}) {
                        $tval = sprintf('0x%x', $tval);
                    }
                }
                $tip .= "Value: $tval";
                my ($id, $sid);
                if ($tagInfo and $$tagInfo{SubIFD}) {
                    ($subOffName, $id, $sid) = Image::ExifTool::Exif::NextOffsetName($et, $offName);
                } else {
                    $id = $offName;
                }
                $et->HDump($entry+$bufPos, 20, "$dname $colName", $tip, 1, $id);
                if ($size > 8) {
                    # add value data block
                    my $flg = ($tagInfo and $$tagInfo{SubDirectory} and $$tagInfo{MakerNotes}) ? 4 : 0;
                    $et->HDump($valuePtr,$size,"$tagName value",'SAME', $flg, $sid);
                }
            }
            if ($tagInfo and $$tagInfo{SubIFD}) {
                # process all SubIFD's as BigTIFF
                $verbose > 0 and $et->VerboseInfo($tagID, $tagInfo,
                    Table   => $tagTablePtr,
                    Index   => $index,
                    Value   => $val,
                    DataPt  => \$valBuff,
                    DataPos => $valBase + $valuePtr,
                    Start   => 0,
                    Size    => $size,
                    Format  => $formatStr,
                    Count   => $count,
                );
                my @offsets = split ' ', $val;
                my $i;
                for ($i=0; $i<scalar(@offsets); ++$i) {
                    my $subdirName = $$tagInfo{Name};
                    $subdirName .= $i if $i;
                    my %subdirInfo = (
                        RAF        => $raf,
                        DataPos    => 0,
                        DirStart   => $offsets[$i],
                        DirName    => $subdirName,
                        Parent     => $dirName,
                        OffsetName => $subOffName,
                    );
                    $et->ProcessDirectory(\%subdirInfo, $tagTablePtr, \&ProcessBigIFD);
                }
            } else {
                my $tagKey = $et->HandleTag($tagTablePtr, $tagID, $val,
                    Index   => $index,
                    DataPt  => \$valBuff,
                    DataPos => $valBase + $valuePtr,
                    Start   => 0,
                    Size    => $size,
                    Format  => $formatStr,
                    TagInfo => $tagInfo,
                    RAF     => $raf,
                );
                $tagKey and $et->SetGroup($tagKey, $dirName);
            }
        }
        last unless $dirName =~ /^(IFD|SubIFD)(\d*)$/;
        $dirName = $1 . (($2 || 0) + 1);
        defined $nextIFD or $et->Warn("Bad $dirName pointer"), return 0;
        $dirStart = Image::ExifTool::Get64u(\$nextIFD, 0);
        $dirStart or last;
        $offName = $nextOffName;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract meta information from a BigTIFF image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid BigTIFF image
sub ProcessBTF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;

    return 0 unless $raf->Read($buff, 16) == 16;
    return 0 unless $buff =~ /^(MM\0\x2b\0\x08\0\0|II\x2b\0\x08\0\0\0)/;
    if ($$dirInfo{OutFile}) {
        $et->Error('ExifTool does not support writing of BigTIFF images');
        return 1;
    }
    $et->SetFileType('BTF'); # set the FileType tag
    SetByteOrder(substr($buff, 0, 2));
    my $offset = Image::ExifTool::Get64u(\$buff, 8);
    if ($$et{HTML_DUMP}) {
        my $o = (GetByteOrder() eq 'II') ? 'Little' : 'Big';
        $et->HDump(0, 8, "BigTIFF header", "Byte order: $o endian", 0);
        $et->HDump(8, 8, "IFD0 pointer", sprintf("Offset: 0x%.8x",$offset), 0);
    }
    my %dirInfo = (
        RAF      => $raf,
        DataPos  => 0,
        DirStart => $offset,
        DirName  => 'IFD0',
        Parent   => 'BigTIFF',
    );
    my $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');
    $et->ProcessDirectory(\%dirInfo, $tagTablePtr, \&ProcessBigIFD);
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::BigTIFF - Read Big TIFF meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read meta
information in BigTIFF images.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.awaresystems.be/imaging/tiff/bigtiff.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/EXIF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

