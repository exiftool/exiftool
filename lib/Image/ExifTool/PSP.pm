#------------------------------------------------------------------------------
# File:         PSP.pm
#
# Description:  Read Paint Shop Pro meta information
#
# Revisions:    2010/01/23 - P. Harvey Created
#
# References:   1) http://www.jasc.com/support/kb/articles/pspspec.asp
#------------------------------------------------------------------------------

package Image::ExifTool::PSP;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.05';

sub ProcessExtData($$$);

# PSP info
%Image::ExifTool::PSP::Main = (
    GROUPS => { 2 => 'Image' },
    VARS => { ALPHA_FIRST => 1 },
    NOTES => q{
        Tags extracted from Paint Shop Pro images (PSP, PSPIMAGE, PSPFRAME,
        PSPSHAPE, PSPTUBE and TUB extensions).
    },
    # FileVersions:
    #  3.0 => PSP 5
    #  4.0 => PSP 6
    #  5.0 => PSP 7
    #  6.0 => PSP 8
    #  7.0 => PSP 9
    #   ?  => PSP X
    #   ?  => PSP X1 (is this the same as X?)
    #   ?  => PSP X2
    # 10.0 => PSP X3 (= PSP 13)
    FileVersion => { PrintConv => '$val=~tr/ /./; $val' },
    0  => [
        {
            Condition => '$$self{PSPFileVersion} > 3',
            Name => 'ImageInfo',
            SubDirectory => {
                TagTable => 'Image::ExifTool::PSP::Image',
                Start => 4,
            },
        },
        {
            Name => 'ImageInfo',
            SubDirectory => {
                TagTable => 'Image::ExifTool::PSP::Image',
            },
        },
    ],
    1  => {
        Name => 'CreatorInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::PSP::Creator' },
    },
    10 => {
        Name => 'ExtendedInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::PSP::Ext' },
    },
    # this is inside the composite image bank block (16), which I don't want to parse...
    #18 => {
    #    Name => 'PreviewImage',
    #    Groups => { 2 => 'Preview' },
    #    RawConv => '$self->ValidateImage(\$val,$tag)',
    #},
);

# the PSP image block
%Image::ExifTool::PSP::Image = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Image' },
    0 => { Name => 'ImageWidth',  Format => 'int32u' },
    4 => { Name => 'ImageHeight', Format => 'int32u' },
    8 => { Name => 'ImageResolution', Format => 'double' },
    16 => {
        Name => 'ResolutionUnit',
        Format => 'int8u',
        PrintConv => {
            0 => 'None',
            1 => 'inches',
            2 => 'cm',
        },
    },
    17 => {
        Name => 'Compression',
        Format => 'int16u',
        PrintConv => {
            0 => 'None',
            1 => 'RLE',
            2 => 'LZ77',
            3 => 'JPEG',
        },
    },
    19 => { Name => 'BitsPerSample',Format => 'int16u' },
    21 => { Name => 'Planes',       Format => 'int16u' },
    23 => { Name => 'NumColors',    Format => 'int32u' },
);

# the PSP creator data block
%Image::ExifTool::PSP::Creator = (
    PROCESS_PROC => \&ProcessExtData,
    GROUPS => { 2 => 'Image' },
    PRIORITY => 0,  # prefer EXIF if it exists
    0 => 'Title',
    1 => {
        Name => 'CreateDate',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::ConvertUnixTime($val,1)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    2 => {
        Name => 'ModifyDate',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::ConvertUnixTime($val,1)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    3 => {
        Name => 'Artist',
        Groups => { 2 => 'Author' },
    },
    4 => {
        Name => 'Copyright',
        Groups => { 2 => 'Author' },
    },
    5 => 'Description',
    6 => {
        Name => 'CreatorAppID',
        Format => 'int32u',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Paint Shop Pro',
        },
    },
    7 => {
        Name => 'CreatorAppVersion',
        Format => 'int8u',
        Count => 4,
        ValueConv => 'join(" ",reverse split " ", $val)', # low byte first
        PrintConv => '$val=~tr/ /./; $val',
    },
);

# the PSP extended data block
%Image::ExifTool::PSP::Ext = (
    PROCESS_PROC => \&ProcessExtData,
    GROUPS => { 2 => 'Image' },
    3 => {
        Name => 'EXIFInfo', #(don't change this name, it is used in the code)
        SubDirectory => { TagTable => 'Image::ExifTool::Exif::Main' },
    },
);

#------------------------------------------------------------------------------
# Extract information from the extended data block
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessExtData($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my $pos = 0;
    # loop through sub-blocks
    while ($pos + 10 < $dirLen) {
        unless (substr($$dataPt, $pos, 4) eq "~FL\0") {
            $et->Warn('Lost synchronization while reading sub blocks');
            last;
        }
        my $tag = Get16u($dataPt, $pos + 4);
        my $len = Get32u($dataPt, $pos + 6);
        $pos += 10 + $len;
        if ($pos > $dirLen) {
            $et->Warn("Truncated sub block ID=$tag len=$len");
            last;
        }
        next unless $$tagTablePtr{$tag};
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag) or next;
        my $start = $pos - $len;
        unless ($$tagInfo{Name} eq 'EXIFInfo') {
            $et->HandleTag($tagTablePtr, $tag, undef,
                TagInfo => $tagInfo,
                DataPt  => $dataPt,
                DataPos => $$dirInfo{DataPos},
                DataLen => length $$dataPt,
                Start   => $start,
                Size    => $len,
            );
            next;
        }
        # validate EXIF block header and set byte order
        next unless $len > 14 and substr($$dataPt, $pos - $len, 6) eq "Exif\0\0";
        next unless SetByteOrder(substr($$dataPt, $start + 6, 2));
        # This is REALLY annoying...  They use a standard TIFF offset to point to
        # the first IFD, but after that the offsets are relative to the start of
        # the IFD instead of the TIFF base, which means that I must handle it as a
        # special case.  Dumb, dumb...
        $start += 14;
        my %dirInfo = (
            DirName  => 'EXIF',
            Parent   => 'PSP',
            DataPt   => $dataPt,
            DataPos  => -$start,        # data position relative to Base
            DataLen  => length $$dataPt,
            DirStart => $start,
            Base     => $start + $$dirInfo{DataPos}, # absolute base offset
            Multi    => 0,
        );
        my $exifTable = GetTagTable($$tagInfo{SubDirectory}{TagTable});
        Image::ExifTool::Exif::ProcessExif($et, \%dirInfo, $exifTable);
        SetByteOrder('II');
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from a PSP file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid PSP file
sub ProcessPSP($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $tag, $len, $err);
    return 0 unless $raf->Read($buff, 32) == 32 and
                    $buff eq "Paint Shop Pro Image File\x0a\x1a\0\0\0\0\0" and
                    $raf->Read($buff, 4) == 4;
    $et->SetFileType();
    SetByteOrder('II');
    my $tagTablePtr = GetTagTable('Image::ExifTool::PSP::Main');
    my @a = unpack('v*', $buff);
    # figure out block header length for this format PSP file
    my $hlen = $a[0] > 3 ? 10 : 14;
    $$et{PSPFileVersion} = $a[0]; # save for use in Condition
    $et->HandleTag($tagTablePtr, FileVersion => "@a");
    # loop through blocks in file
    my $pos = 36;
    for (;;) {
        last unless $raf->Read($buff, $hlen) == $hlen;
        unless ($buff =~ /^~BK\0/) {
            $et->Warn('Lost synchronization while reading main PSP blocks');
            last;
        }
        $tag = Get16u(\$buff, 4);
        $len = Get32u(\$buff, $hlen - 4);
        $pos += $hlen + $len;
        unless ($$tagTablePtr{$tag}) {
            $raf->Seek($len, 1) or $err=1, last;
            next;
        }
        $raf->Read($buff, $len) == $len or $err=1, last;
        $et->HandleTag($tagTablePtr, $tag, $buff,
            DataPt  => \$buff,
            DataPos => $pos - $len,
            Size    => $len,
        );
    }
    $err and $et->Warn("Truncated main block ID=$tag len=$len");
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::PSP - Read Paint Shop Pro meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
information from Paint Shop Pro images.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.jasc.com/support/kb/articles/pspspec.asp>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PSP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

