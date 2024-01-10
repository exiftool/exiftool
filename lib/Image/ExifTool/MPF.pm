#------------------------------------------------------------------------------
# File:         MPF.pm
#
# Description:  Read Multi-Picture Format information
#
# Revisions:    06/12/2009 - P. Harvey Created
#
# References:   1) http://www.cipa.jp/std/documents/e/DC-007_E.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::MPF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.15';

sub ProcessMPImageList($$$);

# Tags found in APP2 MPF segment in JPEG images
%Image::ExifTool::MPF::Main = (
    GROUPS => { 0 => 'MPF', 1 => 'MPF0', 2 => 'Image'},
    NOTES => q{
        These tags are part of the CIPA Multi-Picture Format specification, and are
        found in the APP2 "MPF" segment of JPEG images.  MPImage data referenced
        from this segment is stored as a JPEG trailer.  The MPF tags are not
        writable, however the MPF segment may be deleted as a group (with "MPF:All")
        but then the JPEG trailer should also be deleted (with "Trailer:All").  See
        L<https://web.archive.org/web/20190713230858/http://www.cipa.jp/std/documents/e/DC-007_E.pdf>
        for the official specification.
    },
    0xb000 => 'MPFVersion',
    0xb001 => 'NumberOfImages',
    0xb002 => {
        Name => 'MPImageList',
        SubDirectory => {
            TagTable => 'Image::ExifTool::MPF::MPImage',
            ProcessProc => \&ProcessMPImageList,
        },
    },
    0xb003 => {
        Name => 'ImageUIDList',
        Binary => 1,
    },
    0xb004 => 'TotalFrames',
    0xb101 => 'MPIndividualNum',
    0xb201 => {
        Name => 'PanOrientation',
        PrintHex => 1,
        Notes => 'long integer is split into 4 bytes',
        ValueConv => 'join(" ",unpack("C*",pack("N",$val)))',
        PrintConv => [
            '"$val rows"',
            '"$val columns"',
            {
                0 => '[unused]',
                1 => 'Start at top right',
                2 => 'Start at top left',
                3 => 'Start at bottom left',
                4 => 'Start at bottom right',
            },
            {
                0x01 => 'Left to right',
                0x02 => 'Right to left',
                0x03 => 'Top to bottom',
                0x04 => 'Bottom to top',
                0x10 => 'Clockwise',
                0x20 => 'Counter clockwise',
                0x30 => 'Zigzag (row start)',
                0x40 => 'Zigzag (column start)',
            },
        ],
    },
    0xb202 => 'PanOverlapH',
    0xb203 => 'PanOverlapV',
    0xb204 => 'BaseViewpointNum',
    0xb205 => 'ConvergenceAngle',
    0xb206 => 'BaselineLength',
    0xb207 => 'VerticalDivergence',
    0xb208 => 'AxisDistanceX',
    0xb209 => 'AxisDistanceY',
    0xb20a => 'AxisDistanceZ',
    0xb20b => 'YawAngle',
    0xb20c => 'PitchAngle',
    0xb20d => 'RollAngle',
);

# Tags found in MPImage structure
%Image::ExifTool::MPF::MPImage = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    #WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    #CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    #WRITABLE => 1,
    GROUPS => { 0 => 'MPF', 1 => 'MPImage', 2 => 'Image'},
    NOTES => q{
        The first MPF "Large Thumbnail" image is extracted as PreviewImage, and the
        rest of the embedded MPF images are extracted as MPImage#.  The
        L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded> (-ee) option may be used to extract information from these
        embedded images.
    },
    0.1 => {
        Name => 'MPImageFlags',
        Format => 'int32u',
        Mask => 0xf8000000,
        PrintConv => { BITMASK => {
            2 => 'Representative image',
            3 => 'Dependent child image',
            4 => 'Dependent parent image',
        }},
    },
    0.2 => {
        Name => 'MPImageFormat',
        Format => 'int32u',
        Mask => 0x07000000,
        PrintConv => {
            0 => 'JPEG',
        },
    },
    0.3 => {
        Name => 'MPImageType',
        Format => 'int32u',
        Mask => 0x00ffffff,
        PrintHex => 1,
        PrintConv => {
            0x000000 => 'Undefined',
            0x010001 => 'Large Thumbnail (VGA equivalent)',
            0x010002 => 'Large Thumbnail (full HD equivalent)',
            0x020001 => 'Multi-frame Panorama',
            0x020002 => 'Multi-frame Disparity',
            0x020003 => 'Multi-angle',
            0x030000 => 'Baseline MP Primary Image',
            0x040000 => 'Original Preservation Image', # (Exif 3.0)
        },
    },
    4 => {
        Name => 'MPImageLength',
        Format => 'int32u',
    },
    8 => {
        Name => 'MPImageStart',
        Format => 'int32u',
        IsOffset => '$val',
    },
    12 => {
        Name => 'DependentImage1EntryNumber',
        Format => 'int16u',
    },
    14 => {
        Name => 'DependentImage2EntryNumber',
        Format => 'int16u',
    },
);

# extract MP Images as composite tags
%Image::ExifTool::MPF::Composite = (
    GROUPS => { 2 => 'Preview' },
    MPImage => {
        Require => {
            0 => 'MPImageStart',
            1 => 'MPImageLength',
            2 => 'MPImageType',
        },
        Notes => q{
            the first MPF "Large Thumbnail" is extracted as PreviewImage, and the rest
            of the embedded MPF images are extracted as MPImage#.  The L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded>
            option may be used to extract information from these embedded images.
        },
        # extract all MPF images (not just one)
        RawConv => q{
            require Image::ExifTool::MPF;
            @grps = $self->GetGroup($$val{0});  # set groups from input tag
            Image::ExifTool::MPF::ExtractMPImages($self);
        },
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::MPF');

#------------------------------------------------------------------------------
# Extract all MP images
# Inputs: 0) ExifTool object ref
# Returns: undef
sub ExtractMPImages($)
{
    my $et = shift;
    my $ee = $et->Options('ExtractEmbedded');
    my $saveBinary = $et->Options('Binary');
    my ($i, $didPreview, $xtra);

    for ($i=1; $xtra or not defined $xtra; ++$i) {
        # run through MP images in the same order they were extracted
        $xtra = defined $$et{VALUE}{"MPImageStart ($i)"} ? " ($i)" : '';
        my $off = $et->GetValue("MPImageStart$xtra", 'ValueConv');
        my $len = $et->GetValue("MPImageLength$xtra", 'ValueConv');
        if ($off and $len) {
            my $type = $et->GetValue("MPImageType$xtra", 'ValueConv');
            my $tag = "MPImage$i";
            # store first "Large Thumbnail" as a PreviewImage
            if (not $didPreview and $type and ($type & 0x0f0000) == 0x010000) {
                $tag = 'PreviewImage';
                $didPreview = 1;
            }
            $et->Options('Binary', 1) if $ee;
            my $val = Image::ExifTool::Exif::ExtractImage($et, $off, $len, $tag);
            $et->Options('Binary', $saveBinary) if $ee;
            next unless defined $val;
            unless ($Image::ExifTool::Extra{$tag}) {
                AddTagToTable(\%Image::ExifTool::Extra, $tag, {
                    Name => $tag,
                    Groups => { 0 => 'Composite', 1 => 'Composite', 2 => 'Preview'},
                });
            }
            my $key = $et->FoundTag($tag, $val, $et->GetGroup("MPImageStart$xtra"));
            # extract information from MP images if ExtractEmbedded option used
            if ($ee) {
                my $oldBase = $$et{BASE};
                $$et{BASE} = $off;
                $$et{DOC_NUM} = $i;
                $et->ExtractInfo($val, { ReEntry => 1 });
                delete $$et{DOC_NUM};
                $$et{BASE} = $oldBase;
            }
        }
    }
    return undef;
}

#------------------------------------------------------------------------------
# Process MP Entry list
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessMPImageList($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $num = int($$dirInfo{DirLen} / 16); # (16 bytes per MP Entry)
    $$dirInfo{DirLen} = 16;
    my ($i, $success);
    my $oldG1 = $$et{SET_GROUP1};
    for ($i=0; $i<$num; ++$i) {
        $$et{SET_GROUP1} = '+' . ($i + 1);
        $success = $et->ProcessBinaryData($dirInfo, $tagTablePtr);
        $$dirInfo{DirStart} += 16;
    }
    $$et{SET_GROUP1} = $oldG1;
    return $success;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MPF - Read Multi-Picture Format information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains tag definitions and routines to read Multi-Picture
Format (MPF) information from JPEG images.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cipa.jp/std/documents/e/DC-007_E.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MPF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

