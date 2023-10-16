#------------------------------------------------------------------------------
# File:         XISF.pm
#
# Description:  Read Extensible Image Serialization Format metadata
#
# Revisions:    2023-10-10 - P. Harvey Created
#
# References:   1) https://pixinsight.com/doc/docs/XISF-1.0-spec/XISF-1.0-spec.html
#------------------------------------------------------------------------------

package Image::ExifTool::XISF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::XMP;

$VERSION = '1.00';

# XISF tags (ref 1)
%Image::ExifTool::XISF::Main = (
    GROUPS => { 0 => 'XML', 1 => 'XML', 2 => 'Image' },
    VARS => { LONG_TAGS => 1 },
    NOTES => q{
        This table lists some standard Extensible Image Serialization Format (XISF)
        tags, but ExifTool will extract any other tags found.  See
        L<https://pixinsight.com/xisf/> for the specification.
    },
    ImageGeometry   => { },
    ImageSampleFormat => { },
    ImageBounds     => { },
    ImageImageType  => { Name => 'ImageType' },
    ImageColorSpace => { Name => 'ColorSpace' },
    ImageLocation   => { },
    ImageResolutionHorizontal => 'XResolution',
    ImageResolutionVertical => 'YResolution',
    ImageResolutionUnit => 'ResolutionUnit',
    ImageICCProfile => {
        Name => 'ICC_Profile',
        ValueConv => 'Image::ExifTool::XMP::DecodeBase64($val)',
        Binary => 1,
    },
    ImageICCProfileLocation => { Name => 'ICCProfileLocation' },
    ImagePixelStorage => { },
    ImageOffset      => { Name => 'ImagePixelOffset' },
    ImageOrientation => { Name => 'Orientation' },
    ImageId          => { Name => 'ImageID' },
    ImageUuid        => { Name => 'UUID' },
    ImageData        => { Binary => 1 },
    'CreationTime' => {
        Name => 'CreateDate',
        Shift => 'Time',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::XMP::ConvertXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    CreatorApplication => { },
    Abstract        => { },
    AccessRights    => { },
    Authors         => { Groups => { 2 => 'Author' } },
    BibliographicReferences => { },
    BriefDescription => { },
    CompressionLevel => { },
    CompressionCodecs => { },
    Contributors    => { Groups => { 2 => 'Author' } },
    Copyright       => { Groups => { 2 => 'Author' } },
    CreatorModule   => { },
    CreatorOS       => { },
    Description     => { },
    Keywords        => { },
    Languages       => { },
    License         => { },
    OriginalCreationTime => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Shift => 'Time',
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::XMP::ConvertXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    RelatedResources => { },
    Title            => { },
);

#------------------------------------------------------------------------------
# Handle properties in XISF metadata structures
# Inputs: 0) attribute list ref, 1) attr hash ref,
#         2) property name ref, 3) property value ref
# Returns: true if value was changed
sub HandleXISFAttrs($$$$)
{
    my ($attrList, $attrs, $prop, $valPt) = @_;
    return 0 unless defined $$attrs{id};
    my ($changed, $a);
    # use "id" as the tag name, "value" as the value, and ignore "type"
    $$prop = $$attrs{id};
    $$prop =~ s/^XISF://;   # remove XISF namespace
    if (defined $$attrs{value}) {
        $$valPt = $$attrs{value};
        $changed = 1;
    }
    my @attrs = @$attrList;
    @$attrList = ( );
    foreach $a (@attrs) {
        if ($a eq 'id' or $a eq 'value' or $a eq 'type') {
            delete $$attrs{$a};
        } else {
            push @$attrList, $a;
        }
    }
    return $changed;
}

#------------------------------------------------------------------------------
# Read information in a XISF document
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid XISF file
sub ProcessXISF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;

    return 0 unless $raf->Read($buff, 16) == 16 and $buff =~ /^XISF0100/;
    $et->SetFileType();
    SetByteOrder('II');
    my $tagTablePtr = GetTagTable('Image::ExifTool::XISF::Main');
    my $hdrLen = Get32u(\$buff, 8);
    $raf->Read($buff, $hdrLen) == $hdrLen or $et->Warn('Error reading XISF header'), return 1;
    $et->FoundTag(XML => $buff);
    my %dirInfo = (
        DataPt => \$buff,
        IgnoreProp => { xisf => 1, Metadata => 1, Property => 1 },
        XMPParseOpts => { AttrProc => \&HandleXISFAttrs },
    );
    Image::ExifTool::XMP::ProcessXMP($et, \%dirInfo, $tagTablePtr);
    my $geo = $$et{VALUE}{ImageGeometry};
    if ($geo) {
        my ($w, $h, $n) = split /:/, $geo;
        $et->FoundTag(ImageWidth => $w);
        $et->FoundTag(ImageHeight => $h);
        $et->FoundTag(NumPlanes => $n);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::XISF - Read Extensible Image Serialization Format metadata

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read meta
information from XISF (Extensible Image Serialization Format) images.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://pixinsight.com/doc/docs/XISF-1.0-spec/XISF-1.0-spec.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/XISF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

