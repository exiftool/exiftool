#------------------------------------------------------------------------------
# File:         SonyIDC.pm
#
# Description:  Read/write Sony IDC information
#
# Revisions:    2010/01/05 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::SonyIDC;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.08';

# Sony IDC tags (ref PH)
%Image::ExifTool::SonyIDC::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => 'Tags written by the Sony Image Data Converter utility in ARW images.',
    SET_GROUP1 => 1,
    0x201 => {
        Name => 'IDCPreviewStart',
        IsOffset => 1,
        OffsetPair => 0x202,
        DataTag => 'IDCPreview',
        Writable => 'int32u',
        Protected => 2,
    },
    0x202 => {
        Name => 'IDCPreviewLength',
        OffsetPair => 0x201,
        DataTag => 'IDCPreview',
        Writable => 'int32u',
        Protected => 2,
    },
    0x8000 => {
        Name => 'IDCCreativeStyle',
        Writable => 'int32u',
        PrintConvColumns => 2,
        PrintConv => {
            1 => 'Camera Setting',
            2 => 'Standard',
            3 => 'Real',
            4 => 'Vivid',
            5 => 'Adobe RGB',
            6 => 'A100 Standard', # shows up as '-' in IDC menu
            7 => 'Neutral',
            8 => 'Portrait',
            9 => 'Landscape',
            10 => 'Clear',
            11 => 'Deep',
            12 => 'Light',
            13 => 'Sunset',
            14 => 'Night View',
            15 => 'Autumn Leaves',
            16 => 'B&W',
            17 => 'Sepia',
        },
    },
    0x8001 => {
        Name => 'CreativeStyleWasChanged',
        Writable => 'int32u',
        Notes => 'set if the creative style was ever changed',
        #        (even if it was changed back again later)
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x8002 => {
        Name => 'PresetWhiteBalance',
        Writable => 'int32u',
        PrintConv => {
            1 => 'Camera Setting',
            2 => 'Color Temperature',
            3 => 'Specify Gray Point',
            4 => 'Daylight',
            5 => 'Cloudy',
            6 => 'Shade',
            7 => 'Cool White Fluorescent',
            8 => 'Day Light Fluorescent',
            9 => 'Day White Fluorescent',
            10 => 'Warm White Fluorescent',
            11 => 'Tungsten',
            12 => 'Flash',
            13 => 'Auto',
        },
    },
    0x8013 => { Name => 'ColorTemperatureAdj',  Writable => 'int16u' },
    0x8014 => { Name => 'PresetWhiteBalanceAdj',Writable => 'int32s' },
    0x8015 => { Name => 'ColorCorrection',      Writable => 'int32s' },
    0x8016 => { Name => 'SaturationAdj',        Writable => 'int32s' },
    0x8017 => { Name => 'ContrastAdj',          Writable => 'int32s' },
    0x8018 => {
        Name => 'BrightnessAdj',
        Writable => 'int32s',
        PrintConv => 'sprintf("%.2f", $val/300)', #JR
        PrintConvInv => '$val * 300',
    },
    0x8019 => { Name => 'HueAdj',               Writable => 'int32s' },
    0x801a => { Name => 'SharpnessAdj',         Writable => 'int32s' },
    0x801b => { Name => 'SharpnessOvershoot',   Writable => 'int32s' },
    0x801c => { Name => 'SharpnessUndershoot',  Writable => 'int32s' },
    0x801d => { Name => 'SharpnessThreshold',   Writable => 'int32s' },
    0x801e => {
        Name => 'NoiseReductionMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'On',
        },
    },
    0x8021 => {
        Name => 'GrayPoint',
        Writable => 'int16u',
        Count => 4,
    },
    0x8022 => {
        Name => 'D-RangeOptimizerMode',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Off',
            1 => 'Auto',
            2 => 'Manual',
        },
    },
    0x8023 => { Name => 'D-RangeOptimizerValue',    Writable => 'int32s' },
    0x8024 => { Name => 'D-RangeOptimizerHighlight',Writable => 'int32s' },
    0x8026 => {
        Name => 'HighlightColorDistortReduct',
        Writable => 'int16u',
        PrintConv => {
            0 => 'Standard',
            1 => 'Advanced',
        },
    },
    0x8027 => {
        Name => 'NoiseReductionValue',
        Writable => 'int32s',
        ValueConv => '($val + 100) / 2',
        ValueConvInv => '$val * 2 - 100',
    },
    0x8028 => {
        Name => 'EdgeNoiseReduction',
        Writable => 'int32s',
        ValueConv => '($val + 100) / 2',
        ValueConvInv => '$val * 2 - 100',
    },
    0x8029 => {
        Name => 'ColorNoiseReduction',
        Writable => 'int32s',
        ValueConv => '($val + 100) / 2',
        ValueConvInv => '$val * 2 - 100',
    },
    0x802d => { Name => 'D-RangeOptimizerShadow',       Writable => 'int32s' },
    0x8030 => { Name => 'PeripheralIllumCentralRadius', Writable => 'int32s' },
    0x8031 => { Name => 'PeripheralIllumCentralValue',  Writable => 'int32s' },
    0x8032 => { Name => 'PeripheralIllumPeriphValue',   Writable => 'int32s' },
    0x8040 => { #JR
        Name => 'DistortionCompensation',
        Writable => 'int32s',
        PrintConv => {
            -1 => 'n/a', # (fixed by lens)
            1 => 'On',
            2 => 'Off',
        },
    },
    0x9000 => {
        Name => 'ToneCurveBrightnessX',
        Writable => 'int16u',
        Count => -1,
    },
    0x9001 => {
        Name => 'ToneCurveRedX',
        Writable => 'int16u',
        Count => -1,
    },
    0x9002 => {
        Name => 'ToneCurveGreenX',
        Writable => 'int16u',
        Count => -1,
    },
    0x9003 => {
        Name => 'ToneCurveBlueX',
        Writable => 'int16u',
        Count => -1,
    },
    0x9004 => {
        Name => 'ToneCurveBrightnessY',
        Writable => 'int16u',
        Count => -1,
    },
    0x9005 => {
        Name => 'ToneCurveRedY',
        Writable => 'int16u',
        Count => -1,
    },
    0x9006 => {
        Name => 'ToneCurveGreenY',
        Writable => 'int16u',
        Count => -1,
    },
    0x9007 => {
        Name => 'ToneCurveBlueY',
        Writable => 'int16u',
        Count => -1,
    },
    0x900d => { #JR
        Name => 'ChromaticAberrationCorrection', # "Magnification Chromatic Aberration"
        Writable => 'int32s',
        PrintConv => { 1 => 'On', 2 => 'Off' },
    },
    0x900e => { #JR
        Name => 'InclinationCorrection',
        Writable => 'int32u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x900f => { #JR
        Name => 'InclinationAngle',
        Writable => 'int32s',
        PrintConv => 'sprintf("%.1f deg", $val/1000)',
        PrintConvInv => 'ToFloat($val) * 1000',
    },
    0x9010 => { #JR
        Name => 'Cropping',
        Writable => 'int32u',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x9011 => { #JR
        Name => 'CropArea',
        Writable => 'int32u',
        Count => 4,
    },
    0x9012 => { #JR
        Name => 'PreviewImageSize',
        Writable => 'int32u',
        Count => 2,
    },
    0x9013 => { #JR (ARQ images)
        Name => 'PxShiftPeriphEdgeNR',
        Writable => 'int32s',
        PrintConv => { 0 => 'Off', 1 => 'On' },
    },
    0x9014 => { #JR (ARQ images)
        Name => 'PxShiftPeriphEdgeNRValue',
        Writable => 'int32s',
        PrintConv => 'sprintf("%.1f", $val/10)',
        PrintConvInv => '$val * 10',
    },
    0x9017 => { Name => 'WhitesAdj',        Writable => 'int32s' }, #JR
    0x9018 => { Name => 'BlacksAdj',        Writable => 'int32s' }, #JR
    0x9019 => { Name => 'HighlightsAdj',    Writable => 'int32s' }, #JR
    0x901a => { Name => 'ShadowsAdj',       Writable => 'int32s' }, #JR
    0xd000 => { Name => 'CurrentVersion',   Writable => 'int32u' },
    0xd001 => {
        Name => 'VersionIFD',
        Groups => { 1 => 'Version0' },
        Flags => 'SubIFD',
        Notes => 'there is one VersionIFD for each entry in the "Version Stack"',
        SubDirectory => {
            DirName => 'Version0',
            TagTable => 'Image::ExifTool::SonyIDC::Main',
            Start => '$val',
            Base => '$start',
            MaxSubdirs => 20,   # (IDC v3.0 writes max. 10)
            RelativeBase => 1,  # needed to write SubIFD with relative offsets
        },
    },
    0xd100 => {
        Name => 'VersionCreateDate',
        Writable => 'string',
        Groups => { 2 => 'Time' },
        Notes => 'date/time when this entry was created in the "Version Stack"',
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,0)',
    },
    0xd101 => {
        Name => 'VersionModifyDate',
        Writable => 'string',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val,0)',
    },
);

# extract IDC preview images as composite tags
%Image::ExifTool::SonyIDC::Composite = (
    GROUPS => { 2 => 'Image' },
    IDCPreviewImage => {
        Groups => { 2 => 'Preview' },
        Require => {
            0 => 'IDCPreviewStart',
            1 => 'IDCPreviewLength',
        },
        # extract all preview images (not just one)
        RawConv => q{
            @grps = $self->GetGroup($$val{0});
            require Image::ExifTool::SonyIDC;
            Image::ExifTool::SonyIDC::ExtractPreviews($self);
        },
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::SonyIDC');

# set "Permanent" flag for all tags
{
    my $key;
    foreach $key (TagTableKeys(\%Image::ExifTool::SonyIDC::Main)) {
        $Image::ExifTool::SonyIDC::Main{$key}{Permanent} = 1;
    }
}

#------------------------------------------------------------------------------
# Extract all IDC preview images
# Inputs: 0) ExifTool object ref
# Returns: data for "IDCPreviewImage" tag (which I have never seen),
#          or undef if there was no preview in the SonyIDC IFD
sub ExtractPreviews($)
{
    my $et = shift;
    my $i = 1;
    my $xtra = ' (1)';
    my $preview;
    # loop through all available IDC preview images in the order they were found
    for (;;) {
        my $key = "IDCPreviewStart$xtra";
        unless (defined $$et{VALUE}{$key}) {
            last unless $xtra;
            $xtra = ''; # do the last tag extracted last
            next;
        }
        # run through IDC preview images in the same order they were extracted
        my $off = $et->GetValue($key, 'ValueConv') or last;
        my $len = $et->GetValue("IDCPreviewLength$xtra", 'ValueConv') or last;
        # get stack version from number in group 1 name
        my $grp1 = $et->GetGroup($key, 1);
        if ($grp1 =~ /(\d+)$/) {
            my $tag = "IDCPreviewImage$1";
            unless ($Image::ExifTool::Extra{$tag}) {
                AddTagToTable(\%Image::ExifTool::Extra, $tag, {
                    Name => $tag,
                    Groups => { 0 => 'Composite', 1 => 'Composite', 2 => 'Preview'},
                });
            }
            my $val = Image::ExifTool::Exif::ExtractImage($et, $off, $len, $tag);
            $et->FoundTag($tag, $val, $et->GetGroup($key));
        } else {
            $preview = Image::ExifTool::Exif::ExtractImage($et, $off, $len, 'IDCPreviewImage');
        }
        # step to next set of tags unless we are done
        last unless $xtra;
        ++$i;
        $xtra = " ($i)";
    }
    return $preview;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::SonyIDC - Read/write Sony IDC information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read and
write Sony Image Data Converter version 3.0 metadata in ARW images.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/SonyIDC Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

