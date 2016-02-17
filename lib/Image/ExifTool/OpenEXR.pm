#------------------------------------------------------------------------------
# File:         OpenEXR.pm
#
# Description:  Read OpenEXR meta information
#
# Revisions:    2011/12/10 - P. Harvey Created
#
# References:   1) http://www.openexr.com/
#------------------------------------------------------------------------------

package Image::ExifTool::OpenEXR;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::GPS;

$VERSION = '1.02';

# supported EXR value format types (other types are extracted as undef binary data)
my %formatType = (
    box2f          => 'float[4]',
    box2i          => 'int32s[4]',
    chlist         => 1,
    chromaticities => 'float[8]',
    compression    => 'int8u',
    double         => 'double',
    envmap         => 'int8u',
    float          => 'float',
   'int'           => 'int32s',
    keycode        => 'int32s[7]',
    lineOrder      => 'int8u',
    m33f           => 'float[9]',
    m44f           => 'float[16]',
    rational       => 'rational64s',
    string         => 'string', # incorrect in specification! (no leading int)
    stringvector   => 1,
    tiledesc       => 1,
    timecode       => 'int32u[2]',
    v2f            => 'float[2]',
    v2i            => 'int32s[2]',
    v3f            => 'float[3]',
    v3i            => 'int32s[3]',
);

# OpenEXR tags
%Image::ExifTool::OpenEXR::Main = (
    GROUPS => { 2 => 'Image' },
    NOTES => q{
        Information extracted from EXR images.  See L<http://www.openexr.com/> for
        the official specification.
    },
    _ver => { Name => 'EXRVersion' },
    _lay => {
        Name => 'Layout',
        PrintHex => 1,
        PrintConv => { 0 => 'Scan Lines', 0x200 => 'Tiles' },
    },
    adoptedNeutral      => { },
    altitude => {
        Name => 'GPSAltitude',
        Groups => { 2 => 'Location' },
        PrintConv => q{
            $val = int($val * 10) / 10;
            return ($val =~ s/^-// ? "$val m Below" : "$val m Above") . " Sea Level";
        },
    },
    aperture            => { PrintConv => 'sprintf("%.1f",$val)' },
    channels            => { },
    chromaticities      => { },
    capDate => {
        Name => 'DateTimeOriginal',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    comments            => { },
    compression => {
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'None',
            1 => 'RLE',
            2 => 'ZIPS',
            3 => 'ZIP',
            4 => 'PIZ',
            5 => 'PXR24',
            6 => 'B44',
            7 => 'B44A',
        },
    },
    dataWindow          => { },
    displayWindow       => { },
    envmap => {
        Name => 'EnvironmentMap',
        PrintConv => {
            0 => 'Latitude/Longitude',
            1 => 'Cube',
        },
    },
    expTime => {
        Name => 'ExposureTime',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    focus => {
        Name => 'FocusDistance',
        PrintConv => '"$val m"',
    },
    framesPerSecond     => { },
    keyCode             => { },
    isoSpeed            => { Name => 'ISO' },
    latitude => {
        Name => 'GPSLatitude',
        Groups => { 2 => 'Location' },
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    lineOrder => {
        PrintConv => {
            0 => 'Increasing Y',
            1 => 'Decreasing Y',
            2 => 'Random Y',
        },
    },
    longitude => {
        Name => 'GPSLongitude',
        Groups => { 2 => 'Location' },
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    lookModTransform    => { },
    multiView           => { },
    owner               => { Groups => { 2 => 'Author' } },
    pixelAspectRatio    => { },
    preview             => { },
    renderingTransform  => { },
    screenWindowCenter  => { },
    screenWindowWidth   => { },
    tiles               => { },
    timeCode            => { },
    utcOffset => {
        Name => 'TimeZone',
        Groups => { 2 => 'Time' },
        PrintConv => 'TimeZoneString($val / 60)',
    },
    whiteLuminance      => { },
    worldToCamera       => { },
    worldToNDC          => { },
    wrapmodes           => { Name => 'WrapModes' },
    xDensity            => { Name => 'XResolution' },
    # also observed:
    # ilut
);

#------------------------------------------------------------------------------
# Extract information from an OpenEXR file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid OpenEXR file
sub ProcessEXR($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my $binary = $et->Options('Binary') || $verbose;
    my ($buff, $buf2, $dim);

    # verify this is a valid RIFF file
    return 0 unless $raf->Read($buff, 8) == 8;
    return 0 unless $buff =~ /^\x76\x2f\x31\x01/s;
    $et->SetFileType();
    SetByteOrder('II');
    my $tagTablePtr = GetTagTable('Image::ExifTool::OpenEXR::Main');

    # extract information from header
    my $ver = unpack('x4V', $buff);
    $et->HandleTag($tagTablePtr, '_ver', $ver & 0xff);
    $et->HandleTag($tagTablePtr, '_lay', $ver & 0x200);

    # extract attributes
    for (;;) {
        $raf->Read($buff, 68) or last;
        last if $buff =~ /^\0/;
        unless ($buff =~ /^([^\0]{1,31})\0([^\0]{1,31})\0(.{4})/sg) {
            $et->Warn('EXR format error');
            last;
        }
        my ($tag, $type, $size) = ($1, $2, unpack('V', $3));
        unless ($raf->Seek(pos($buff) - length($buff), 1)) {
            $et->Warn('Seek error');
            last;
        }
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        unless ($tagInfo) {
            my $name = ucfirst $tag;
            $name =~ tr/-_a-zA-Z0-9//dc;
            if (length $name <= 1) {
                if (length $name) {
                    $name = "Tag$name";
                } else {
                    $name = 'Invalid';
                }
            }
            $tagInfo = { Name => $name, WasAdded => 1 };
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
            $et->VPrint(0, $$et{INDENT}, "[adding $tag]\n");
        }
        my ($val, $success);
        my $format = $formatType{$type};
        if ($format or $binary) {
            $raf->Read($buff, $size) == $size and $success = 1;
            if (not $format) {
                $val = \$buff;  # treat as undef binary data
            } elsif ($format ne '1') {
                # handle formats which map nicely into ExifTool format codes
                if ($format =~ /^(\w+)\[?(\d*)/) {
                    my ($fmt, $cnt) = ($1, $2);
                    $cnt = $fmt eq 'string' ? $size : 1 unless $cnt;
                    $val = ReadValue(\$buff, 0, $fmt, $cnt, $size);
                }
            # handle other format types
            } elsif ($type eq 'tiledesc') {
                if ($size >= 9) {
                    my $x = Get32u(\$buff, 0);
                    my $y = Get32u(\$buff, 4);
                    my $mode = Get8u(\$buff, 8);
                    my $lvl = { 0 => 'One Level', 1 => 'MIMAP Levels', 2 => 'RIPMAP Levels' }->{$mode & 0x0f};
                    $lvl or $lvl = 'Unknown Levels (' . ($mode & 0xf) . ')';
                    my $rnd = { 0 => 'Round Down', 1 => 'Round Up' }->{$mode >> 4};
                    $rnd or $rnd = 'Unknown Rounding (' . ($mode >> 4) . ')';
                    $val = "${x}x$y; $lvl; $rnd";
                }
            } elsif ($type eq 'chlist') {
                $val = [ ];
                while ($buff =~ /\G([^\0]{1,31})\0(.{16})/sg) {
                    my ($str, $dat) = ($1, $2);
                    my ($pix,$lin,$x,$y) = unpack('VCx3VV', $dat);
                    $pix = { 0 => 'int8u', 1 => 'half', 2 => 'float' }->{$pix} || "unknown($pix)";
                    push @$val, "$str $pix" . ($lin ? ' linear' : '') . " $x $y";
                }
            } elsif ($type eq 'stringvector') {
                $val = [ ];
                my $pos = 0;
                while ($pos + 4 <= length($buff)) {
                    my $len = Get32u(\$buff, $pos);
                    last if $pos + 4 + $len > length($buff);
                    push @$val, substr($buff, $pos + 4, $len);
                    $pos += 4 + $len;
                }
            } else {
                $val = \$buff;  # (shouldn't happen)
            }
        } else {
            # avoid loading binary data
            $val = \ "Binary data $size bytes";
            $success = $raf->Seek($size, 1);
        }
        unless ($success) {
            $et->Warn('Truncated or corrupted EXR file');
            last;
        }
        $val = '<bad>' unless defined $val;

        # take image dimensions from dataWindow (with displayWindow as backup)
        if (($tag eq 'dataWindow' or (not $dim and $tag eq 'displayWindow')) and
            $val =~ /^(-?\d+) (-?\d+) (-?\d+) (-?\d+)$/)
        {
            $dim = [$3 - $1 + 1, $4 - $2 + 1];
        }
        if ($verbose) {
            my $dataPt = ref $val ? $val : \$val,
            $et->VerboseInfo($tag, $tagInfo,
                Table   => $tagTablePtr,
                Value   => $val,
                Size    => $size,
                Format  => $type,
                DataPt  => \$buff,
                Addr    => $raf->Tell() - $size,
            );
        }
        $et->FoundTag($tagInfo, $val);
    }
    if ($dim) {
        $et->FoundTag('ImageWidth', $$dim[0]);
        $et->FoundTag('ImageHeight', $$dim[1]);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::OpenEXR - Read OpenEXR meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from OpenEXR images.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.openexr.com/documentation.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/OpenEXR Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

