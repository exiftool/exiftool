#------------------------------------------------------------------------------
# File:         Lytro.pm
#
# Description:  Read Lytro LFP files
#
# Revisions:    2014-07-17 - P. Harvey Created
#
# References:   1) http://optics.miloush.net/lytro/TheFileFormat.aspx
#------------------------------------------------------------------------------

package Image::ExifTool::Lytro;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Import;

$VERSION = '1.03';

sub ExtractTags($$$);

# Lytro LFP tags (ref PH)
%Image::ExifTool::Lytro::Main = (
    GROUPS => { 2 => 'Camera' },
    VARS => { NO_ID => 1 },
    NOTES => q{
        Tag definitions for Lytro Light Field Picture (LFP) files.  ExifTool
        extracts the full JSON metadata blocks, as well as breaking them down into
        individual tags.  All available tags are extracted from the JSON metadata,
        even if they don't appear in the table below.
    },
    JSONMetadata => {
        Notes => 'the full JSON-format metadata blocks',
        Binary => 1,
        List => 1,
    },
    EmbeddedImage => {
        Notes => 'JPEG image embedded in LFP files written by Lytro Desktop',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
    Type                => { Name => 'CameraType' },
    CameraMake          => { Name => 'Make' },
    CameraModel         => { Name => 'Model', Description => 'Camera Model Name' },
    CameraSerialNumber  => { Name => 'SerialNumber'},
    CameraFirmware      => { Name => 'FirmwareVersion'},
    DevicesAccelerometerSampleArrayTime => { Name => 'AccelerometerTime'},
    DevicesAccelerometerSampleArrayX    => { Name => 'AccelerometerX'},
    DevicesAccelerometerSampleArrayY    => { Name => 'AccelerometerY'},
    DevicesAccelerometerSampleArrayZ    => { Name => 'AccelerometerZ'},
    DevicesClockZuluTime => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        ValueConv => 'require Image::ExifTool::XMP; Image::ExifTool::XMP::ConvertXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    DevicesLensFNumber => {
        Name => 'FNumber',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
    },
    DevicesLensFocalLength => {
        Name => 'FocalLength',
        ValueConv => '$val * 1000', # convert from metres to mm
        PrintConv => 'sprintf("%.1f mm",$val)',
    },
    DevicesLensTemperature => {
        Name => 'LensTemperature',
        PrintConv => 'sprintf("%.1f C",$val)',
    },
    DevicesSocTemperature => {
        Name => 'SocTemperature',
        PrintConv => 'sprintf("%.1f C",$val)',
    },
    DevicesShutterFrameExposureDuration => {
        Name => 'FrameExposureTime',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    DevicesShutterPixelExposureDuration => {
        Name => 'ExposureTime',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    DevicesSensorPixelPitch => {
        Name => 'FocalPlaneXResolution',
        Notes => 'Y resolution is the same as X resolution',
        ValueConv => '25.4 / $val / 1000',  # convert from metres to pixels/inch
    },
    DevicesSensorSensorSerial   => { Name => 'SensorSerialNumber'},
    DevicesSensorIso            => { Name => 'ISO' },
    ImageLimitExposureBias      => { Groups => { 2 => 'Image' }, PrintConv => 'sprintf("%+.1f", $val)' },
    ImageModulationExposureBias => { Groups => { 2 => 'Image' }, PrintConv => 'sprintf("%+.1f", $val)' },
    ImageOrientation => {
        Name => 'Orientation',
        Groups => { 2 => 'Image' },
        PrintConv => {
            1 => 'Horizontal (normal)',
        },
    },
);

#------------------------------------------------------------------------------
# Extract tags from a parsed JSON hash
# Inputs: 0) ExifTool ref, 1) tag hash ref, 2) base tag name
sub ExtractTags($$$)
{
    my ($et, $meta, $parent) = @_;
    ref $meta eq 'HASH' or $et->Warn('Invalid LFP metadata'), return;
    my ($key, $val, $name, $tagTablePtr);
    foreach $key (sort keys %$meta) {
        my $tag = $parent . ucfirst($key);
        foreach $val (ref $$meta{$key} eq 'ARRAY' ? @{$$meta{$key}} : $$meta{$key}) {
            ref $val eq 'HASH' and ExtractTags($et, $val, $tag), next;
            $tagTablePtr or $tagTablePtr = GetTagTable('Image::ExifTool::Lytro::Main');
            unless ($$tagTablePtr{$tag}) {
                ($name = $tag) =~ s/[^-_a-zA-Z0-9](.?)/\U$1/g;
                $name =~ s/ParametersVendorContentComLytroTags//;
                my %tagInfo;
                $tagInfo{Groups} = { 2 => 'Image' } unless $name =~ s/^Devices//;
                $tagInfo{List} = 1 if ref $$meta{$key} eq 'ARRAY';
                $tagInfo{Name} = $name;
                my $str = $tag eq $name ? '' : " as $name";
                $et->VPrint(0, "  [adding $tag$str]\n");
                AddTagToTable($tagTablePtr, $tag, \%tagInfo);
            }
            $et->HandleTag($tagTablePtr, $tag, $val);
        }
    }
}

#------------------------------------------------------------------------------
# Process segments from a Lytro LFP image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid Lytro image
sub ProcessLFP($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my ($buff, $id);

    # validate the Lytro file header
    return 0 unless $raf->Read($buff, 16) == 16 and $buff =~ /^\x89LFP\x0d\x0a\x1a\x0a/;
    $et->SetFileType();   # set the FileType tag
    SetByteOrder('MM');
    my $tagTablePtr = GetTagTable('Image::ExifTool::Lytro::Main');
    while ($raf->Read($buff, 16) == 16) {
        $buff =~ /^\x89LF/ or $et->Warn('LFP format error'), last;
        my $size = Get32u(\$buff, 12);
        $size & 0x80000000 and $et->Warn('Invalid LFP segment size'), last;
        $raf->Read($id, 80) == 80 or $et->Warn('Truncated LFP segment'), last;  # ignore the sha1
        if ($verbose) {
            $id =~ s/\0.*//s;
            $et->VPrint(0, substr($buff,1,3), " segment ($size bytes, $id)\n");
        }
        if ($size > 20000000) {
            $raf->Seek($size, 1) or $et->Warn('Seek error in LFP file'), last;
        } else {
            $raf->Read($buff,$size) == $size or $et->Warn('Truncated LFP data'), last;
            $et->VerboseDump(\$buff, Addr=>$raf->Tell()-$size);
            if ($buff =~ /^\{\s+"/) { # JSON metadata?
                pos($buff) = 0;
                $et->HandleTag($tagTablePtr, 'JSONMetadata', $buff);
                my $meta = Image::ExifTool::Import::ReadJSONObject(undef, \$buff);
                ExtractTags($et, $meta, '');
            } elsif ($buff =~ /^\xff\xd8\xff/) { # embedded JPEG image?
                $et->HandleTag($tagTablePtr, 'EmbeddedImage', $buff);
            }
        }
        # skip padding if necessary
        my $pad = 16 - ($size % 16);
        $raf->Seek($pad, 1) if $pad != 16;
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Lytro - Read Lytro LFP files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read metadata
from Lytro Light Field Picture (LFP) files.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://optics.miloush.net/lytro/TheFileFormat.aspx>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Lytro Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

