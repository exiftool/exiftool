#------------------------------------------------------------------------------
# File:         MIFF.pm
#
# Description:  Read Magick Image File Format meta information
#
# Revisions:    06/10/2005 - P. Harvey Created
#
# References:   1) http://www.imagemagick.org/script/miff.php
#               2) http://www.cs.uni.edu/Help/ImageMagick/www/miff.html
#------------------------------------------------------------------------------

package Image::ExifTool::MIFF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.07';

# MIFF chunks
%Image::ExifTool::MIFF::Main = (
    GROUPS => { 2 => 'Image' },
    NOTES => q{
        The MIFF (Magick Image File Format) format allows aribrary tag names to be
        used.  Only the standard tag names are listed below, however ExifTool will
        decode any tags found in the image.
    },
   'background-color' => 'BackgroundColor',
   'blue-primary' => 'BluePrimary',
   'border-color' => 'BorderColor',
   'matt-color' => 'MattColor',
    class => 'Class',
    colors => 'Colors',
    colorspace => 'ColorSpace',
    columns => 'ImageWidth',
    compression => 'Compression',
    delay => 'Delay',
    depth => 'Depth',
    dispose => 'Dispose',
    gamma => 'Gamma',
   'green-primary' => 'GreenPrimary',
    id => 'ID',
    iterations => 'Iterations',
    label => 'Label',
    matte => 'Matte',
    montage => 'Montage',
    packets => 'Packets',
    page => 'Page',
    # profile tags.  Note the SubDirectory is not used by ProcessMIFF(),
    # but is inserted for documentation purposes only
   'profile-APP1' => [
        # [this list is just for the sake of the documentation]
        {
            Name => 'APP1_Profile',
            SubDirectory => {
                TagTable => 'Image::ExifTool::Exif::Main',
            },
        },
        {
            Name => 'APP1_Profile',
            SubDirectory => {
                TagTable => 'Image::ExifTool::XMP::Main',
            },
        },
    ],
   'profile-exif' => { # haven't seen this, but it would make sense - PH
        Name => 'EXIF_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
        },
    },
   'profile-icc' => {
        Name => 'ICC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
   'profile-iptc' => {
        Name => 'IPTC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Photoshop::Main',
        },
    },
   'profile-xmp' => { # haven't seen this, but it would make sense - PH
        Name => 'XMP_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
   'red-primary' => 'RedPrimary',
   'rendering-intent' => 'RenderingIntent',
    resolution => 'Resolution',
    rows => 'ImageHeight',
    scene => 'Scene',
    signature => 'Signature',
    units => 'Units',
   'white-point' => 'WhitePoint',
);

#------------------------------------------------------------------------------
# Extract meta information from a MIFF image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid MIFF image
sub ProcessMIFF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $$et{OPTIONS}{Verbose};
    my ($hdr, $buff);

    # validate the MIFF file (note: MIFF files _may_ begin with other
    # characters, but this starting sequence is strongly suggested.)
    return 0 unless $raf->Read($hdr, 14) == 14;
    return 0 unless $hdr eq 'id=ImageMagick';
    $et->SetFileType();   # set the FileType tag

    # set end-of-line character sequence to read to end of the TEXT
    # section for new-type MIFF files (text ends with Colon+Ctrl-Z)
    # Old MIFF files end with Colon+Linefeed, so this will likely
    # slurp those entire files, which will be slower, but will work
    # OK except that the profile information won't be decoded
    local $/ = ":\x1a";

    my $mode = '';
    my @profiles;
    if ($raf->ReadLine($buff)) {
        chomp $buff;    # remove end-of-line chars
        my $tagTablePtr = GetTagTable('Image::ExifTool::MIFF::Main');
        my @entries = split ' ', $buff;
        unshift @entries, $hdr; # put the ID back in
        my ($tag, $val);
        foreach (@entries) {
            if ($mode eq 'com') {
                $mode = '' if /\}$/;
                next;
            } elsif (/^\{/) {
                $mode = 'com';  # read to the end of the comment
                next;
            }
            if ($mode eq 'val') {
                $val .= " $_";  # join back together with a space
                next unless /\}$/;
                $mode = '';
                $val =~ s/(^\{|\}$)//g; # remove braces
            } elsif (/(.+)=(.+)/) {
                ($tag, $val) = ($1, $2);
                if ($val =~ /^\{/) {
                    $mode = 'val';      # read to the end of the value data
                    next;
                }
            } elsif (/^:/) {
                # this could be the end of an old-style MIFF file
                last;
            } else {
                # something we don't recognize -- stop parsing here
                $et->Warn('Unrecognized MIFF data');
                last;
            }
            my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
            unless ($tagInfo) {
                $tagInfo = { Name => $tag };
                AddTagToTable($tagTablePtr, $tag, $tagInfo);
            }
            $verbose and $et->VerboseInfo($tag, $tagInfo,
                Table  => $tagTablePtr,
                DataPt => \$val,
            );
            # handle profile tags specially
            if ($tag =~ /^profile-(.*)/) {
                push @profiles, [$1, $val];
            } else {
                $et->FoundTag($tagInfo, $val);
            }
        }
    }

    # process profile information
    foreach (@profiles) {
        my ($type, $len) = @{$_};
        unless ($len =~ /^\d+$/) {
            $et->Warn("Invalid length for $type profile");
            last;   # don't try to read the rest
        }
        unless ($raf->Read($buff, $len) == $len) {
            $et->Warn("Error reading $type profile ($len bytes)");
            next;
        }
        my $processed = 0;
        my %dirInfo = (
            Parent   => 'PNG',
            DataPt   => \$buff,
            DataPos  => $raf->Tell() - $len,
            DataLen  => $len,
            DirStart => 0,
            DirLen   => $len,
        );
        if ($type eq 'icc') {
            # ICC Profile information
            my $tagTablePtr = GetTagTable('Image::ExifTool::ICC_Profile::Main');
            $processed = $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        } elsif ($type eq 'iptc') {
            if ($buff =~ /^8BIM/) {
                # Photoshop information
                my $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Main');
                $processed = $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
            }
        # I haven't seen 'exif' or 'xmp' profile types yet, but I have seen them
        # in newer PNG files so presumably they are possible here as well - PH
        } elsif ($type eq 'APP1' or $type eq 'exif' or $type eq 'xmp') {
            if ($buff =~ /^$Image::ExifTool::exifAPP1hdr/) {
                # APP1 EXIF
                my $hdrLen = length($Image::ExifTool::exifAPP1hdr);
                $dirInfo{DirStart} += $hdrLen;
                $dirInfo{DirLen} -= $hdrLen;
                # use the usual position for EXIF data: 12 bytes from start of file
                # (this may be wrong, but I can't see where the PNG stores this information)
                $dirInfo{Base} = 12; # this is the usual value
                $processed = $et->ProcessTIFF(\%dirInfo);
            } elsif ($buff =~ /^$Image::ExifTool::xmpAPP1hdr/) {
                # APP1 XMP
                my $hdrLen = length($Image::ExifTool::xmpAPP1hdr);
                my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
                $dirInfo{DirStart} += $hdrLen;
                $dirInfo{DirLen} -= $hdrLen;
                $processed = $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
            }
        }
        unless ($processed) {
            $et->Warn("Unknown MIFF $type profile data");
            if ($verbose) {
                $et->VerboseDir($type, 0, $len);
                $et->VerboseDump(\$buff);
            }
         }
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MIFF - Read Magick Image File Format meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read MIFF
(Magick Image File Format) images.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.imagemagick.org/script/miff.php>

=item L<http://www.cs.uni.edu/Help/ImageMagick/www/miff.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MIFF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

