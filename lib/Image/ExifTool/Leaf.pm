#------------------------------------------------------------------------------
# File:         Leaf.pm
#
# Description:  Read Creo Leaf EXIF meta information
#
# Revisions:    09/28/2005  - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Leaf;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Exif;

$VERSION = '1.07';

sub ProcessLeaf($$$);

%Image::ExifTool::Leaf::Main = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Camera' },
    NOTES => q{
        These tags are found in .MOS images from Leaf digital camera backs as
        written by Creo Leaf Capture.  They exist within the Leaf-specific directory
        structure of EXIF tag 0x8606.  The tables below list observed Leaf tags,
        however ExifTool will extract any tags found in the Leaf directories even if
        they don't appear in these tables.
    },
    icc_camera_profile => {
        Name => 'ICC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    icc_rgb_ws_profile => {
        Name => 'RGB_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    camera_profile => {
        Name => 'CameraProfile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::CameraProfile',
        },
    },
    JPEG_preview_data => {
        %Image::ExifTool::previewImageTagInfo,
        Groups => { 2 => 'Preview' },
    },
    JPEG_preview_info => 'PreviewInfo',
    icc_camera_to_tone_space_flow => {
        Name => 'ToneSpaceFlow',
        Description => 'ICC To Tone Space Flow',
        Format => 'int16u',
    },
    icc_camera_to_tone_matrix => {
        Name => 'ToneMatrix',
        Description => 'ICC To Tone Matrix',
        Format => 'int8u',
        Binary => 1,
    },
    PDA_histogram_data => {
        Name => 'PDAHistogram',
        Binary => 1,
    },
    pattern_ratation_angle => {
        Name => 'PatternAngle',
        Description => 'Pattern Rotation Angle',
        Format => 'int16u',
        Notes => '"ratation" is not a typo',
    },
    back_serial_number => {
        Name => 'BackSerial',
        Description => 'Back Serial Number',
        PrintConv => '$val =~ s/ .*//s; $val',
    },
    image_offset => { Format => 'int16u' },
);

%Image::ExifTool::Leaf::CameraProfile = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Camera' },
    CamProf_version => 'CameraProfileVersion',
    CamProf_name    => 'CameraName',
    CamProf_type    => 'CameraType',
    CamProf_back_type => 'CameraBackType',
    CamProf_back_type => {
        Name => 'CameraBackType',
    },
    CamProf_capture_profile => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::CaptureProfile',
        },
    },
    CamProf_image_profile => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::ImageProfile',
        },
    },
);

%Image::ExifTool::Leaf::CaptureProfile = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Image' },
    CaptProf_version        => {},
    CaptProf_name           => {},
    CaptProf_type           => {},
    CaptProf_back_type      => {},
    CaptProf_serial_number  => {
        Name => 'CaptureSerial',
        Description => 'Capture Serial Number',
        PrintConv => '$val =~ s/ .*//s; $val',
    },
    CaptProf_image_offset       => {},
    CaptProf_luminance_consts   => {},
    CaptProf_xy_offset_info     => 'XYOffsetInfo',
    CaptProf_color_matrix       => {},
    CaptProf_reconstruction_type=> {},
    CaptProf_image_fields       => {},
    CaptProf_image_bounds       => {},
    CaptProf_number_of_planes   => {},
    CaptProf_raw_data_rotation  => {},
    CaptProf_color_averages     => {},
    CaptProf_mosaic_pattern     => {},
    CaptProf_dark_correction_type=>{},
    CaptProf_right_dark_rect    => {},
    CaptProf_left_dark_rect     => {},
    CaptProf_center_dark_rect   => {},
    CaptProf_CCD_rect           => {},
    CaptProf_CCD_valid_rect     => {},
    CaptProf_CCD_video_rect     => {},
);

%Image::ExifTool::Leaf::ImageProfile = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Image' },
    ImgProf_version         => {},
    ImgProf_name            => {},
    ImgProf_type            => {},
    ImgProf_back_type       => {},
    ImgProf_shoot_setup => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::ShootSetup',
        },
    },
    ImgProf_image_status    => {},
    ImgProf_rotation_angle  => {},
);

%Image::ExifTool::Leaf::ShootSetup = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Image' },
    ShootObj_version        => {},
    ShootObj_name           => {},
    ShootObj_type           => {},
    ShootObj_back_type      => {},
    ShootObj_capture_setup => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::CaptureSetup',
        },
    },
    ShootObj_color_setup => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::ColorSetup',
        },
    },
    ShootObj_save_setup => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::SaveSetup',
        },
    },
    ShootObj_camera_setup => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::CameraSetup',
        },
    },
    ShootObj_look_header => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::LookHeader',
        },
    },
);

%Image::ExifTool::Leaf::CaptureSetup = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Image' },
    CaptureObj_version      => {},
    CaptureObj_name         => {},
    CaptureObj_type         => {},
    CaptureObj_back_type    => {},
    CaptureObj_neutals => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::Neutrals',
        },
    },
    CaptureObj_selection => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::Selection',
        },
    },
    CaptureObj_tone_curve => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::ToneCurve',
        },
    },
    CaptureObj_sharpness => {
        SubDirectory => {
            TagTable => 'Image::ExifTool::Leaf::Sharpness',
        },
    },
    CaptureObj_single_quality => {},
    CaptureObj_Multi_quality  => {},
);

%Image::ExifTool::Leaf::Neutrals = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Image' },
    NeutObj_version         => {},
    NeutObj_name            => {},
    NeutObj_type            => {},
    NeutObj_back_type       => {},
    NeutObj_neutrals        => {},
    NeutObj_color_casts     => {},
    NeutObj_shadow_end_points    => {},
    NeutObj_highlight_end_points => {},
);

%Image::ExifTool::Leaf::Selection = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Image' },
    SelObj_version          => {},
    SelObj_name             => {},
    SelObj_type             => {},
    SelObj_back_type        => {},
    SelObj_rect             => {},
    SelObj_resolution       => {},
    SelObj_scale            => {},
    SelObj_locks            => {},
    SelObj_orientation      => {},
);

%Image::ExifTool::Leaf::ToneCurve = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Image' },
    ToneObj_version         => {},
    ToneObj_name            => {},
    ToneObj_type            => {},
    ToneObj_back_type       => {},
    ToneObj_npts            => {},
    ToneObj_tones           => {},
    ToneObj_gamma           => {},
);

%Image::ExifTool::Leaf::Sharpness = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Image' },
    SharpObj_version        => {},
    SharpObj_name           => {},
    SharpObj_type           => {},
    SharpObj_back_type      => {},
    SharpObj_sharp_method   => {},
    SharpObj_data_len       => {},
    SharpObj_sharp_info     => {},
);

%Image::ExifTool::Leaf::ColorSetup = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Image' },
    ColorObj_version        => {},
    ColorObj_name           => {},
    ColorObj_type           => {},
    ColorObj_back_type      => {},
    ColorObj_has_ICC        => {},
    ColorObj_input_profile  => {},
    ColorObj_output_profile => {},
    ColorObj_color_mode     => {},
    ColorObj_color_type     => {},
);

%Image::ExifTool::Leaf::SaveSetup = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Other' },
    SaveObj_version         => {},
    SaveObj_name            => {},
    SaveObj_type            => {},
    SaveObj_back_type       => {},
    SaveObj_leaf_auto_active=> {},
    SaveObj_leaf_hot_folder => {},
    SaveObj_leaf_output_file_type => {},
    SaveObj_leaf_auto_base_name   => {},
    SaveObj_leaf_save_selection   => {},
    SaveObj_leaf_open_proc_HDR    => {},
    SaveObj_std_auto_active       => {},
    SaveObj_std_hot_folder        => {},
    SaveObj_std_output_file_type  => {},
    SaveObj_std_output_color_mode => {},
    SaveObj_std_output_bit_depth  => {},
    SaveObj_std_base_name         => {},
    SaveObj_std_save_selection    => {},
    SaveObj_std_oxygen            => {},
    SaveObj_std_open_in_photoshop => {},
    SaveObj_std_scaled_output     => {},
    SaveObj_std_sharpen_output    => {},
);

%Image::ExifTool::Leaf::CameraSetup = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Camera' },
    CameraObj_version       => {},
    CameraObj_name          => {},
    CameraObj_type          => {},
    CameraObj_back_type     => {},
    CameraObj_ISO_speed     => {},
    CameraObj_strobe        => {},
    CameraObj_camera_type   => {},
    CameraObj_lens_type     => {},
    CameraObj_lens_ID       => {},
);

%Image::ExifTool::Leaf::LookHeader = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Other' },
    LookHead_version        => {},
    LookHead_name           => {},
    LookHead_type           => {},
    LookHead_back_type      => {},
);

# tag table for any unknown Leaf directories
%Image::ExifTool::Leaf::Unknown = (
    PROCESS_PROC => \&ProcessLeaf,
    GROUPS => { 0 => 'Leaf', 2 => 'Unknown' },
);

# table for Leaf SubIFD entries
%Image::ExifTool::Leaf::SubIFD = (
    GROUPS => { 0 => 'MakerNotes', 1 => 'LeafSubIFD', 2 => 'Image'},
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    NOTES => q{
        Leaf writes a TIFF-format sub-IFD inside IFD0 of a MOS image.  No tags in
        this sub-IFD are currently known, except for tags 0x8602 and 0x8606 which
        really shouldn't be here anyway (so they don't appear in the table below)
        because they duplicate references to the same data from tags with the same
        ID in IFD0.
    },
);

# prepare Leaf tables by generating tag 'Name' and table 'NOTES'
{
    my @tableList = ( 'Image::ExifTool::Leaf::Main' );
    my ($tag, %doneTable);
    # keep prefix in tag name of common tags
    my %keepPrefix = ( Version=>1, Name=>1, Type=>1, BackType=>1 );
    while (@tableList) {
        my $table = shift @tableList;
        next if $doneTable{$table};
        my $prefix = ($table =~ /::Main$/) ? undef : '';
        $doneTable{$table} = 1;
        no strict 'refs';
        $table = \%$table;
        use strict 'refs';
        foreach $tag (keys %$table) {
            my $tagInfo = $$table{$tag};
            next unless ref $tagInfo eq 'HASH';
            next if $tag eq 'GROUPS';
            if (defined $prefix and not $prefix) {
                ($prefix = $tag) =~ s/_.*//;
            }
            unless ($$tagInfo{Name}) {
                my $name;
                ($name = $tag) =~ s/_(.)/\U$1/g;
                if ($prefix) {
                    $name =~ s/^$prefix//;
                    $name = $prefix . $name if $keepPrefix{$name};
                }
                $$tagInfo{Name} = ucfirst($name);
            }
            next unless $$tagInfo{SubDirectory};
            my $subTable = $tagInfo->{SubDirectory}->{TagTable};
            next unless $subTable =~ /::Leaf::/;
            push @tableList, $subTable;
        }
        next unless $prefix;
        $$table{NOTES} = "All B<Tag ID>'s in the following table have a " .
                         "leading '${prefix}_' which\nhas been removed.\n";
    }
}

#------------------------------------------------------------------------------
# Process Leaf information
# Inputs: 0) ExifTool object reference
#         1) Reference to directory information hash
#         2) Pointer to tag table for this directory
# Returns: 1 on success, otherwise returns 0 and sets a Warning
sub ProcessLeaf($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || $$dirInfo{DataLen} - $dirStart;
    my $dirEnd = $dirStart + $dirLen;
    my $verbose = $et->Options('Verbose');
    my $pos = $dirStart;
    my $hdrLen = 52;    # header length for PKTS information
    my $success;

    $verbose and $et->VerboseDir('Leaf');
    for (;;) {
        last if $pos + $hdrLen > $dirEnd;
        my $header = substr($$dataPt, $pos, $hdrLen);
        last unless substr($header, 0, 4) eq 'PKTS';
        $success = 1;
        my $size = Get32u(\$header, 48);
        $pos += $hdrLen;
        if ($pos + $size > $dirEnd) {
            $et->Warn('Truncated Leaf data');
            last;
        }
        my $tag = substr($header, 8, 40);
        $tag =~ s/\0.*//s;
        next unless $tag;
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        # generate tag info for unknown tags
        my $val;
        if ($tagInfo and $$tagInfo{Format}) {
            $val = ReadValue($dataPt, $pos, $$tagInfo{Format}, undef, $size);
        } else {
            $val = substr($$dataPt, $pos, $size);
        }
        unless ($tagInfo) {
            my $name = ucfirst($tag);
            $name =~ s/_(.)/\U$1/g;
            if ($val =~ /^PKTS\0\0\0\x01/) {
                # also unpack unknown directories
                $tagInfo = {
                    Name => $name,
                    SubDirectory => { TagTable => 'Image::ExifTool::Leaf::Unknown' },
                };
            } elsif ($tagTablePtr ne \%Image::ExifTool::Leaf::Main or
                     $et->Options('Unknown'))
            {
                $tagInfo = {
                    Name => $name,
                    Writable => 0,
                    PrintConv => 'length($val) > 60 ? substr($val,0,55) . "[...]" : $val',
                };
                # make tags in main table unknown because they tend to be binary
                $$tagInfo{Unknown} = 1 if $tagTablePtr eq \%Image::ExifTool::Leaf::Main;
            }
            $tagInfo and AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        if ($verbose) {
            $et->VerboseInfo($tag, $tagInfo,
                Table   => $tagTablePtr,
                Value   => $val,
                DataPt  => $dataPt,
                DataPos => $$dirInfo{DataPos},
                Size    => $size,
                Start   => $pos,
            );
        }
        if ($tagInfo) {
            if ($$tagInfo{SubDirectory}) {
                my %subdirInfo = (
                    DataPt => $dataPt,
                    DirLen => $size,
                    DirStart => $pos,
                    DataPos => $$dirInfo{DataPos},
                    DirName => 'Leaf PKTS',
                );
                my $subTable = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                $et->ProcessDirectory(\%subdirInfo, $subTable);
            } else {
                $val =~ tr/\n/ /;   # translate newlines to spaces
                $val =~ s/\0+$//;   # remove null terminators
                $et->FoundTag($tagInfo, $val);
            }
        }
        $pos += $size;
    }
    $success or $et->Warn('Bad format Leaf data');
    return $success;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Leaf - Read Creo Leaf EXIF meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
meta information from Leaf digital camera backs written by Creo Leaf
Capture.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Leaf Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
