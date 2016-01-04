#------------------------------------------------------------------------------
# File:         ITC.pm
#
# Description:  Read iTunes Cover Flow meta information
#
# Revisions:    01/12/2008 - P. Harvey Created
#
# References:   1) http://www.waldoland.com/dev/Articles/ITCFileFormat.aspx
#               2) http://www.falsecognate.org/2007/01/deciphering_the_itunes_itc_fil/
#------------------------------------------------------------------------------

package Image::ExifTool::ITC;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.02';

sub ProcessITC($$);

# tags used in ITC files
%Image::ExifTool::ITC::Main = (
    NOTES => 'This information is found in iTunes Cover Flow data files.',
    itch => { SubDirectory => { TagTable => 'Image::ExifTool::ITC::Header' } },
    item => { SubDirectory => { TagTable => 'Image::ExifTool::ITC::Item' } },
    data => {
        Name => 'ImageData',
        Notes => 'embedded JPEG or PNG image, depending on ImageType',
    },
);

# ITC header information
%Image::ExifTool::ITC::Header = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0x10 => {
        Name => 'DataType',
        Format => 'undef[4]',
        PrintConv => { artw => 'Artwork' },
    },
);

# ITC item information
%Image::ExifTool::ITC::Item = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    FORMAT => 'int32u',
    FIRST_ENTRY => 0,
    0 => {
        Name => 'LibraryID',
        Format => 'undef[8]',
        ValueConv => 'uc unpack "H*", $val',
    },
    2 => {
        Name => 'TrackID',
        Format => 'undef[8]',
        ValueConv => 'uc unpack "H*", $val',
    },
    4 => {
        Name => 'DataLocation',
        Format => 'undef[4]',
        PrintConv => {
            down => 'Downloaded Separately',
            locl => 'Local Music File',
        },
    },
    5 => {
        Name => 'ImageType',
        Format => 'undef[4]',
        ValueConv => { # (not PrintConv because the unconverted JPEG value is nasty)
            'PNGf' => 'PNG',
            "\0\0\0\x0d" => 'JPEG',
        },
    },
    7 => 'ImageWidth',
    8 => 'ImageHeight',
);

#------------------------------------------------------------------------------
# Process an iTunes Cover Flow (ITC) file
# Inputs: 0) ExifTool object reference, 1) Directory information reference
# Returns: 1 on success, 0 if this wasn't a valid ITC file
sub ProcessITC($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $rtnVal = 0;
    my ($buff, $err, $pos, $tagTablePtr, %dirInfo);

    # loop through all blocks in this image
    for (;;) {
        # read the block header
        my $n = $raf->Read($buff, 8);
        unless ($n == 8) {
            # no error if we reached the EOF normally
            undef $err unless $n;
            last;
        }
        my ($size, $tag) = unpack('Na4', $buff);
        if ($rtnVal) {
            last unless $size >= 8 and $size < 0x80000000;
        } else {
            # check to be sure this is a valid ITC image
            # (first block must be 'itch')
            last unless $tag eq 'itch';
            last unless $size >= 0x1c and $size < 0x10000;
            $et->SetFileType();
            SetByteOrder('MM');
            $rtnVal = 1;    # this is an ITC file
            $err = 1;       # format error unless we read to EOF
        }
        if ($tag eq 'itch') {
            $pos = $raf->Tell();
            $size -= 8; # size of remaining data in block
            $raf->Read($buff,$size) == $size or last;
            # extract header information
            %dirInfo = (
                DirName => 'ITC Header',
                DataPt  => \$buff,
                DataPos => $pos,
            );
            my $tagTablePtr = GetTagTable('Image::ExifTool::ITC::Header');
            $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        } elsif ($tag eq 'item') {
            # don't want to read the entire item data (includes image)
            $size > 12 or last;
            $raf->Read($buff, 4) == 4 or last;
            my $len = unpack('N', $buff);
            $len >= 0xd0 and $len <= $size or last;
            $size -= $len;  # size of data after item header
            $len -= 12;     # length of remaining item header
            # read in 4-byte blocks until we find the null terminator
            # (this is just a guess about how to parse this variable-length part)
            while ($len >= 4) {
                $raf->Read($buff, 4) == 4 or last;
                $len -= 4;
                last if $buff eq "\0\0\0\0";
            }
            last if $len < 4;
            $pos = $raf->Tell();
            $raf->Read($buff, $len) == $len or last;
            unless ($len >= 0xb4 and substr($buff, 0xb0, 4) eq 'data') {
                $et->Warn('Parsing error. Please submit this ITC file for testing');
                last;
            }
            %dirInfo = (
                DirName => 'ITC Item',
                DataPt  => \$buff,
                DataPos => $pos,
            );
            $tagTablePtr = GetTagTable('Image::ExifTool::ITC::Item');
            $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
            # extract embedded image
            $pos += $len;
            if ($size > 0) {
                $tagTablePtr = GetTagTable('Image::ExifTool::ITC::Main');
                my $tagInfo = $et->GetTagInfo($tagTablePtr, 'data');
                my $image = $et->ExtractBinary($pos, $size, $$tagInfo{Name});
                $et->FoundTag($tagInfo, \$image);
                # skip the rest of the block if necessary
                $raf->Seek($pos+$size, 0) or last
            } elsif ($size < 0) {
                last;
            }
        } else {
            $et->VPrint(0, "Unknown $tag block ($size bytes)\n");
            $raf->Seek($size-8, 1) or last;
        }
    }
    $err and $et->Warn('ITC file format error');
    return $rtnVal;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::ITC - Read iTunes Cover Flow meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains the routines required by Image::ExifTool to read meta
information (including artwork images) from iTunes Cover Flow files.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.waldoland.com/dev/Articles/ITCFileFormat.aspx>

=item L<http://www.falsecognate.org/2007/01/deciphering_the_itunes_itc_fil/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/ITC Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

