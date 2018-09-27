#------------------------------------------------------------------------------
# File:         GIMP.pm
#
# Description:  Read meta information from GIMP XCF images
#
# Revisions:    2010/10/05 - P. Harvey Created
#               2018/08/21 - PH Updated to current XCF specification (v013)
#
# References:   1) GIMP source code
#               2) https://gitlab.gnome.org/GNOME/gimp/blob/master/devel-docs/xcf.txt
#------------------------------------------------------------------------------

package Image::ExifTool::GIMP;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.03';

sub ProcessParasites($$$);

# GIMP XCF properties (ref 2)
%Image::ExifTool::GIMP::Main = (
    GROUPS => { 2 => 'Image' },
    VARS => { ALPHA_FIRST => 1 },
    NOTES => q{
        The GNU Image Manipulation Program (GIMP) writes these tags in its native
        XCF (eXperimental Computing Facilty) images.
    },
    header => { SubDirectory => { TagTable => 'Image::ExifTool::GIMP::Header' } },
    # recognized properties
    # 1 - ColorMap
    # 17 - SamplePoints? (doc says 17 is also "PROP_SAMPLE_POINTS"??)
    17 => {
        Name => 'Compression',
        Format => 'int8u',
        PrintConv => {
            0 => 'None',
            1 => 'RLE Encoding',
            2 => 'Zlib',
            3 => 'Fractal',
        },
    },
    # 18 - Guides
    19 => {
        Name => 'Resolution',
        SubDirectory => { TagTable => 'Image::ExifTool::GIMP::Resolution' },
    },
    20 => {
        Name => 'Tattoo',
        Format => 'int32u',
    },
    21 => {
        Name => 'Parasites',
        SubDirectory => { TagTable => 'Image::ExifTool::GIMP::Parasite' },
    },
    22 => {
        Name => 'Units',
        Format => 'int32u',
        PrintConv => {
            1 => 'Inches',
            2 => 'mm',
            3 => 'Points',
            4 => 'Picas',
        },
    },
    # 23 Paths
    # 24 UserUnit
    # 25 Vectors
);

# information extracted from the XCF file header (ref 2)
%Image::ExifTool::GIMP::Header = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    9 => {
        Name => 'XCFVersion',
        Format => 'string[5]',
        DataMember => 'XCFVersion',
        RawConv => '$$self{XCFVersion} = $val',
        PrintConv => {
            'file' => '0',
            'v001' => '1',
            'v002' => '2',
            OTHER => sub { my $val = shift; $val =~ s/^v0*//; return $val },
        },
    },
    14 => { Name => 'ImageWidth',  Format => 'int32u' },
    18 => { Name => 'ImageHeight', Format => 'int32u' },
    22 => {
        Name => 'ColorMode',
        Format => 'int32u',
        PrintConv => {
            0 => 'RGB Color',
            1 => 'Grayscale',
            2 => 'Indexed Color',
        },
    },
    # 26 - [XCF 4 or later] Precision
);

# XCF resolution data (property type 19) (ref 2)
%Image::ExifTool::GIMP::Resolution = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'float',
    0 => 'XResolution',
    1 => 'YResolution',
);

# XCF "Parasite" data (property type 21) (ref 1/PH)
%Image::ExifTool::GIMP::Parasite = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&ProcessParasites,
    'gimp-comment' => {
        Name => 'Comment',
        Format => 'string',
    },
    'exif-data' => {
        Name => 'ExifData',
        SubDirectory => {
            TagTable    => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            Start       => 6, # starts after "Exif\0\0" header
        },
    },
    'jpeg-exif-data' => { # (deprecated, untested)
        Name => 'JPEGExifData',
        SubDirectory => {
            TagTable    => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            Start       => 6,
        },
    },
    'iptc-data' => { # (untested)
        Name => 'IPTCData',
        SubDirectory => { TagTable => 'Image::ExifTool::IPTC::Main' },
    },
    'icc-profile' => {
        Name => 'ICC_Profile',
        SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::Main' },
    },
    'icc-profile-name' => {
        Name => 'ICCProfileName',
        Format => 'string',
    },
    'gimp-metadata' => {
        Name => 'XMP',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
            Start => 10, # starts after "GIMP_XMP_1" header
        },
    },
    'gimp-image-metadata' => {
        Name => 'XML',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::XML' },
    },
    # Seen, but not yet decoded:
    #  gimp-image-grid
    #  jpeg-settings
);

#------------------------------------------------------------------------------
# Read information in a GIMP XCF parasite data (ref PH)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessParasites($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $unknown = $et->Options('Unknown') || $et->Options('Verbose');
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart} || 0;
    my $end = length $$dataPt;
    $et->VerboseDir('Parasites', undef, $end);
    for (;;) {
        last if $pos + 4 > $end;
        my $size = Get32u($dataPt, $pos);   # length of tag string
        $pos += 4;
        last if $pos + $size + 8 > $end;
        my $tag = substr($$dataPt, $pos, $size);
        $pos += $size;
        $tag =~ s/\0.*//s;                  # trim at null terminator
        # my $flags = Get32u($dataPt, $pos);  (ignore flags)
        $size = Get32u($dataPt, $pos + 4);  # length of data
        $pos += 8;
        last if $pos + $size > $end;
        if (not $$tagTablePtr{$tag} and $unknown) {
            my $name = $tag;
            $name =~ tr/-_A-Za-z0-9//dc;
            $name =~ s/^gimp-//;
            next unless length $name;
            $name = ucfirst $name;
            $name =~ s/([a-z])-([a-z])/$1\u$2/g;
            $name = "GIMP-$name" unless length($name) > 1;
            AddTagToTable($tagTablePtr, $tag, { Name => $name, Unknown => 1 });
        }
        $et->HandleTag($tagTablePtr, $tag, undef,
            DataPt => $dataPt,
            Start  => $pos,
            Size   => $size,
        );
        $pos += $size;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Read information in a GIMP XCF document
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid XCF file
sub ProcessXCF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;

    return 0 unless $raf->Read($buff, 26) == 26;
    return 0 unless $buff =~ /^gimp xcf /;

    my $tagTablePtr = GetTagTable('Image::ExifTool::GIMP::Main');
    my $verbose = $et->Options('Verbose');
    $et->SetFileType();
    SetByteOrder('MM');

    # process the XCF header
    $et->HandleTag($tagTablePtr, 'header', $buff);

    # skip over precision for XCV version 4 or later
    $raf->Seek(4, 1) if $$et{XCFVersion} =~ /^v0*(\d+)/ and $1 >= 4;
     
    # loop through image properties
    for (;;) {
        $raf->Read($buff, 8) == 8 or last;
        my $tag  = Get32u(\$buff, 0) or last;
        my $size = Get32u(\$buff, 4);
        $verbose and $et->VPrint(0, "XCF property $tag ($size bytes):\n");
        unless ($$tagTablePtr{$tag}) {
            $raf->Seek($size, 1);
            next;
        }
        $raf->Read($buff, $size) == $size or last;
        $et->HandleTag($tagTablePtr, $tag, undef,
            DataPt  => \$buff,
            DataPos => $raf->Tell() - $size,
            Size    => $size,
        );
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::GIMP - Read meta information from GIMP XCF images

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read meta
information from GIMP (GNU Image Manipulation Program) XCF (eXperimental
Computing Facility) images.  This is the native image format used by the
GIMP software.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<GIMP source code>

=item L<http://svn.gnome.org/viewvc/gimp/trunk/devel-docs/xcf.txt?view=markup>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/GIMP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

