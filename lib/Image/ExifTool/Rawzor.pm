#------------------------------------------------------------------------------
# File:         Rawzor.pm
#
# Description:  Read meta information from Rawzor compressed images
#
# Revisions:    09/09/2008 - P. Harvey Created
#
# References:   1) http://www.rawzor.com/
#------------------------------------------------------------------------------

package Image::ExifTool::Rawzor;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.04';

# currently support this version Rawzor images
my $implementedRawzorVersion = 199; # (up to version 1.99)

# Rawzor-specific tags
%Image::ExifTool::Rawzor::Main = (
    GROUPS => { 2 => 'Other' },
    VARS => { NO_ID => 1 },
    NOTES => q{
        Rawzor files store compressed images of other formats. As well as the
        information listed below, exiftool uncompresses and extracts the meta
        information from the original image.
    },
    OriginalFileType => { },
    OriginalFileSize => {
        PrintConv => $Image::ExifTool::Extra{FileSize}->{PrintConv},
    },
    RawzorRequiredVersion => {
        ValueConv => '$val / 100',
        PrintConv => 'sprintf("%.2f", $val)',
    },
    RawzorCreatorVersion => {
        ValueConv => '$val / 100',
        PrintConv => 'sprintf("%.2f", $val)',
    },
    # compression factor is originalSize/compressedSize (and compression
    # ratio is the inverse - ref "Data Compression" by David Salomon)
    CompressionFactor => { PrintConv => 'sprintf("%.2f", $val)' },
);

#------------------------------------------------------------------------------
# Extract information from a Rawzor file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid Rawzor file
sub ProcessRWZ($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $buf2);

    # read the Rawzor file header:
    #  0 string - "rawzor" signature
    #  6 int16u - Required SDK version
    #  8 int16u - Creator SDK version
    # 10 int64u - RWZ file size
    # 18 int64u - original raw file size
    # 26 undef[12] - reserved
    # 38 int64u - metadata offset
    $raf->Read($buff, 46) == 46 and $buff =~ /^rawzor/ or return 0;

    SetByteOrder('II');
    my $reqVers = Get16u(\$buff, 6);
    my $creatorVers = Get16u(\$buff, 8);
    my $rwzSize = Get64u(\$buff, 10);
    my $origSize = Get64u(\$buff, 18);
    my $tagTablePtr = GetTagTable('Image::ExifTool::Rawzor::Main');
    $et->HandleTag($tagTablePtr, RawzorRequiredVersion => $reqVers);
    $et->HandleTag($tagTablePtr, RawzorCreatorVersion => $creatorVers);
    $et->HandleTag($tagTablePtr, OriginalFileSize => $origSize);
    $et->HandleTag($tagTablePtr, CompressionFactor => $origSize/$rwzSize) if $rwzSize;
    # check version numbers
    if ($reqVers > $implementedRawzorVersion) {
        $et->Warn("Version $reqVers Rawzor images not yet supported");
        return 1;
    }
    my $metaOffset = Get64u(\$buff, 38);
    if ($metaOffset > 0x7fffffff) {
        $et->Warn('Bad metadata offset');
        return 1;
    }
    # check for the ability to uncompress the information
    unless (eval { require IO::Uncompress::Bunzip2 }) {
        $et->Warn('Install IO::Compress::Bzip2 to decode Rawzor bzip2 compression');
        return 1;
    }
    # read the metadata header:
    #  0 int64u - metadata section 0 end (offset in original file)
    #  8 int64u - metadata section 1 start
    # 16 int64u - metadata section 1 end
    # 24 int64u - metadata section 2 start
    # 32 undef[4] - reserved
    # 36 int32u - original metadata size
    # 40 int32u - compressed metadata size
    unless ($raf->Seek($metaOffset, 0) and $raf->Read($buff, 44) == 44) {
        $et->Warn('Error reading metadata header');
        return 1;
    }
    my $metaSize = Get32u(\$buff, 36);
    if ($metaSize) {
        # validate the metadata header and read the compressed metadata
        my $end0 = Get64u(\$buff, 0);
        my $pos1 = Get64u(\$buff, 8);
        my $end1 = Get64u(\$buff, 16);
        my $pos2 = Get64u(\$buff, 24);
        my $len = Get32u(\$buff, 40);
        unless ($raf->Read($buff, $len) == $len and
            $end0 + ($end1 - $pos1) + ($origSize - $pos2) == $metaSize and
            $end0 <= $pos1 and $pos1 <= $end1 and $end1 <= $pos2)
        {
            $et->Warn('Error reading image metadata');
            return 1;
        }
        # uncompress the metadata
        unless (IO::Uncompress::Bunzip2::bunzip2(\$buff, \$buf2) and
            length($buf2) eq $metaSize)
        {
            $et->Warn('Error uncompressing image metadata');
            return 1;
        }
        # re-assemble the original file (sans image data)
        undef $buff; # (can't hurt to free memory as soon as possible)
        $buff = substr($buf2, 0, $end0) . ("\0" x ($pos1 - $end0)) .
                substr($buf2, $end0, $end1 - $pos1) . ("\0" x ($pos2 - $end1)) .
                substr($buf2, $end0 + $end1 - $pos1, $origSize - $pos2);
        undef $buf2;

        # extract original information by calling ExtractInfo recursively
        $et->ExtractInfo(\$buff, { ReEntry => 1 });
        undef $buff;
    }
    # set OriginalFileType from FileType of original file
    # then change FileType and MIMEType to indicate a Rawzor image
    my $origFileType = $$et{VALUE}{FileType};
    if ($origFileType) {
        $et->HandleTag($tagTablePtr, OriginalFileType => $origFileType);
        $et->OverrideFileType('RWZ');
    } else {
        $et->HandleTag($tagTablePtr, OriginalFileType => 'Unknown');
        $et->SetFileType();
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Rawzor - Read meta information from Rawzor compressed images

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Rawzor compressed images.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.rawzor.com/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Rawzor Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

