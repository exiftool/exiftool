#------------------------------------------------------------------------------
# File:         OpenEXR.pm
#
# Description:  Read OpenEXR meta information
#
# Revisions:    2011/12/10 - P. Harvey Created
#               2023/01/31 - PH Added support for multipart images
#
# References:   1) http://www.openexr.com/
#------------------------------------------------------------------------------

package Image::ExifTool::OpenEXR;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::GPS;

$VERSION = '1.07';

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

# chomaticities names correspondances
my %chromaticityToColorspace = (
    '0.712999999523163 0.293000012636185 0.165000006556511 0.829999983310699 0.128000006079674 0.0439999997615814 0.321680009365082 0.337669998407364' => 'ACEScg',
    '0.7124263048172 0.293813675642014 0.180122509598732 0.807839155197144 0.125906214118004 0.0442668609321117 0.345702916383743 0.358537524938583' => 'ACEScg AMPAS S-2014-004',
    '0.733956277370453 0.268055468797684 0.0164710879325867 0.972419202327728 -0.0559232085943222 -0.121274426579475 0.345702916383743 0.358537524938583' => 'ACES SMPTE ST 2065-1',
    '0.639999985694885 0.330000013113022 0.300000011920929 0.600000023841858 0.150000005960464 0.0599999986588955 0.312700003385544 0.328999996185303' => 'sRGB',
    '0.648453652858734 0.330852478742599 0.321197688579559 0.597844362258911 0.155884742736816 0.0660382062196732 0.345702916383743 0.358538597822189' => 'sRGB IEC61966-2.1',
    '0.648438155651093 0.330855995416641 0.230178281664848 0.701570689678192 0.155893236398697 0.0660597011446953 0.345702916383743 0.358538597822189' => 'Adobe RGB (1998)',
    '0.734698474407196 0.265301525592804 0.159599378705025 0.840400636196136 0.0365994907915592 0.000106911851617042 0.345702916383743 0.358538597822189' => 'ProPhoto RGB',
    '0.708493113517761 0.293545454740524 0.190204367041588 0.775371015071869 0.129246488213539 0.0471405945718288 0.345702916383743 0.358537524938583' => 'Rec.2020 Gamma 2.4',
    '0.734700918197632 0.265299111604691 0.115173131227493 0.826431155204773 0.156608253717422 0.017684992402792 0.345702916383743 0.358538597822189' => 'Wide Gamut RGB',
    # Add more entries as needed
);

# OpenEXR tags
%Image::ExifTool::OpenEXR::Main = (
    GROUPS => { 2 => 'Image' },
    NOTES => q{
        Information extracted from EXR images.  Use the ExtractEmbedded option to
        extract information from all frames of a multipart image.  See
        L<http://www.openexr.com/> for the official specification.
    },
    _ver => { Name => 'EXRVersion', Notes => 'low byte of Flags word' },
    _flags => { Name => 'Flags', 
        PrintConv => { BITMASK => {
            9 => 'Tiled',
            10 => 'Long names',
            11 => 'Deep data',
            12 => 'Multipart',
        }},
    },
    adoptedNeutral      => { },
    altitude => {
        Name => 'GPSAltitude',
        Groups => { 2 => 'Location' },
        PrintConv => q{
            $val = int($val * 10) / 10;
            return(($val =~ s/^-// ? "$val m Below" : "$val m Above") . " Sea Level");
        },
    },
    aperture            => { PrintConv => 'sprintf("%.1f",$val)' },
    channels            => { },
    chromaticities      => { },
    capDate => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
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
            8 => 'DWAA',
            9 => 'DWAB',
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
    preview             => { Groups => { 2 => 'Preview' } },
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
    name                => { },
    type                => { },
    version             => { },
    chunkCount          => { },
    # exif and xmp written by PanoramaStudio4.0.2Pro
    exif => {
        Name => 'EXIF',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            Start => 4, # (skip leading 4 bytes with data length)
        },
    },
    xmp  => {
        Name => 'XMP',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
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
    my ($buff, $dim);

    # verify this is a valid RIFF file
    return 0 unless $raf->Read($buff, 8) == 8;
    return 0 unless $buff =~ /^\x76\x2f\x31\x01/s;
    $et->SetFileType();
    SetByteOrder('II');
    my $tagTablePtr = GetTagTable('Image::ExifTool::OpenEXR::Main');

    # extract information from header
    my $flags = unpack('x4V', $buff);
    $et->HandleTag($tagTablePtr, '_ver', $flags & 0xff);
    $et->HandleTag($tagTablePtr, '_flags', $flags & 0xffffff00);
    my $maxLen = ($flags & 0x400) ? 255 : 31;
    my $multi = $flags & 0x1000;

    # extract attributes
    for (;;) {
        $raf->Read($buff, ($maxLen + 1) * 2 + 5) or last;
        if ($buff =~ /^\0/) {
            last unless $multi and $et->Options('ExtractEmbedded');
            # remove null and process the next frame header as a sub-document
            # (second null is end of all headers)
            last if $buff =~ s/^(\0+)// and length($1) > 1;
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};
        }
        unless ($buff =~ /^([^\0]{1,$maxLen})\0([^\0]{1,$maxLen})\0(.{4})/sg) {
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
            $name =~ s/([^a-zA-Z])([a-z])/$1\U$2/g; # capitalize first letter of each word
            $name =~ tr/-_a-zA-Z0-9//dc;
            if (length $name <= 1) {
                if (length $name) {
                    $name = "Tag$name";
                } else {
                    $name = 'Invalid';
                }
            }
            $tagInfo = { Name => $name };
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
            $et->VPrint(0, $$et{INDENT}, "[adding $tag]\n");
        }
        my ($val, $success, $buf2);
        my $format = $formatType{$type};
        my $subdir = $$tagInfo{SubDirectory};
        if ($format or $binary or $subdir) {
            $raf->Read($buf2, $size) == $size and $success = 1;
            if ($subdir) {
                $et->HandleTag($tagTablePtr, $tag, undef,
                    DataPt => \$buf2, DataPos => $raf->Tell() - length($buf2));
                next if $success;
            } elsif (not $format) {
                $val = \$buf2;  # treat as undef binary data
            } elsif ($format ne '1') {
                # handle formats which map nicely into ExifTool format codes
                if ($format =~ /^(\w+)\[?(\d*)/) {
                    my ($fmt, $cnt) = ($1, $2);
                    $cnt = $fmt eq 'string' ? $size : 1 unless $cnt;
                    $val = ReadValue(\$buf2, 0, $fmt, $cnt, $size);
                }
            # handle other format types
            } elsif ($type eq 'tiledesc') {
                if ($size >= 9) {
                    my $x = Get32u(\$buf2, 0);
                    my $y = Get32u(\$buf2, 4);
                    my $mode = Get8u(\$buf2, 8);
                    my $lvl = { 0 => 'One Level', 1 => 'MIMAP Levels', 2 => 'RIPMAP Levels' }->{$mode & 0x0f};
                    $lvl or $lvl = 'Unknown Levels (' . ($mode & 0xf) . ')';
                    my $rnd = { 0 => 'Round Down', 1 => 'Round Up' }->{$mode >> 4};
                    $rnd or $rnd = 'Unknown Rounding (' . ($mode >> 4) . ')';
                    $val = "${x}x$y; $lvl; $rnd";
                }
            } elsif ($type eq 'chlist') {
                $val = [ ];
                while ($buf2 =~ /\G([^\0]{1,31})\0(.{16})/sg) {
                    my ($str, $dat) = ($1, $2);
                    my ($pix,$lin,$x,$y) = unpack('VCx3VV', $dat);
                    $pix = { 0 => 'int8u', 1 => 'half', 2 => 'float' }->{$pix} || "unknown($pix)";
                    push @$val, "$str $pix" . ($lin ? ' linear' : '') . " $x $y";
                }
            } elsif ($type eq 'stringvector') {
                $val = [ ];
                my $pos = 0;
                while ($pos + 4 <= length($buf2)) {
                    my $len = Get32u(\$buf2, $pos);
                    last if $pos + 4 + $len > length($buf2);
                    push @$val, substr($buf2, $pos + 4, $len);
                    $pos += 4 + $len;
                }
            } else {
                $val = \$buf2;  # (shouldn't happen)
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

        # translates chromaticities 
        if ($tag eq 'chromaticities') {
            my $colorspace;
            if (exists $chromaticityToColorspace{$val}) { # in the %chromaticityToColorspace hash, search for the key named as the value stored in chromaticites's $val
                $colorspace = $chromaticityToColorspace{$val}; # if above condition true, assign the value of the found key to the "colorspace" variable
            }else{
                $colorspace = "no match found";
            }
            $et->FoundTag('Colorspace', $colorspace); # add the colorspace attribute to the list of attributes to be displayerd in the $et hash under the 'Colorspace' label
        }

        # take image dimensions from dataWindow (with displayWindow as backup)
        if (($tag eq 'dataWindow' or (not $dim and $tag eq 'displayWindow')) and
            $val =~ /^(-?\d+) (-?\d+) (-?\d+) (-?\d+)$/ and not $$et{DOC_NUM})
        {
            $dim = [$3 - $1 + 1, $4 - $2 + 1];
        }
        if ($verbose) {
            my $dataPt = ref $val eq 'SCALAR' ? $val : \$buf2;
            $et->VerboseInfo($tag, $tagInfo,
                Table   => $tagTablePtr,
                Value   => $val,
                Size    => $size,
                Format  => $type,
                DataPt  => $dataPt,
                Addr    => $raf->Tell() - $size,
            );
        }
        $et->FoundTag($tagInfo, $val);
    }
    delete $$et{DOC_NUM};
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

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

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

