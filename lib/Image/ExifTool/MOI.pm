#------------------------------------------------------------------------------
# File:         MOI.pm
#
# Description:  Read MOI meta information
#
# Revisions:    2014/12/15 - P. Harvey Created
#
# References:   1) https://en.wikipedia.org/wiki/MOI_(file_format)
#------------------------------------------------------------------------------

package Image::ExifTool::MOI;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.02';

# MOI tags (ref 1)
%Image::ExifTool::MOI::Main = (
    GROUPS => { 2 => 'Video' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    NOTES => q{
        MOI files store information about associated MOD or TOD files, and are
        written by some JVC, Canon and Panasonic camcorders.
    },
    0x00 => { Name => 'MOIVersion',  Format => 'string[2]' },
  # 0x02 => { Name => 'MOIFileSize', Format => 'int32u' },
    0x06 => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Format => 'undef[8]',
        Groups => { 2 => 'Time' },
        ValueConv => sub {
            my $val = shift;
            return undef unless length($val) >= 8;
            my @v = unpack('nCCCCn', $val);
            $v[5] /= 1000;
            return sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%06.3f', @v);
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x0e => {
        Name => 'Duration',
        Format => 'int32u',
        ValueConv => '$val / 1000',
        PrintConv => 'ConvertDuration($val)',
    },
    0x80 => {
        Name => 'AspectRatio',
        Format => 'int8u',
        PrintConv => q{
            my $lo = ($val & 0x0f);
            my $hi = ($val >> 4);
            my $aspect;
            if ($lo < 2) {
                $aspect = '4:3';
            } elsif ($lo == 4 or $lo == 5) {
                $aspect = '16:9';
            } else {
                $aspect = 'Unknown';
            }
            if ($hi == 4) {
                $aspect .= ' NTSC';
            } elsif ($hi == 5) {
                $aspect .= ' PAL';
            }
            return $aspect;
        },
    },
    0x84 => {
        Name => 'AudioCodec',
        Format => 'int16u',
        Groups => { 2 => 'Audio' },
        PrintHex => 1,
        PrintConv => {
            0x00c1 => 'AC3',
            0x4001 => 'MPEG',
        },
    },
    0x86 => {
        Name => 'AudioBitrate',
        Format => 'int8u',
        Groups => { 2 => 'Audio' },
        ValueConv => '$val * 16000 + 48000',
        PrintConv => 'ConvertBitrate($val)',
    },
    0xda => {
        Name => 'VideoBitrate',
        Format => 'int16u',
        PrintHex => 1,
        ValueConv => {
            0x5896 => '8500000',
            0x813d => '5500000',
        },
        PrintConv => 'ConvertBitrate($val)',
    },
);

#------------------------------------------------------------------------------
# Validate and extract metadata from MOI file
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid MOI file
sub ProcessMOI($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;
    # read enough to allow skipping over run-in if it exists
    $raf->Read($buff, 256) == 256 and $buff =~ /^V6/ or return 0;
    if (defined $$et{VALUE}{FileSize}) {
        my $size = unpack('x2N', $buff);
        $size == $$et{VALUE}{FileSize} or return 0;
    }
    $et->SetFileType();
    SetByteOrder('MM');
    my $tagTablePtr = GetTagTable('Image::ExifTool::MOI::Main');
    return $et->ProcessBinaryData({ DataPt => \$buff }, $tagTablePtr);
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MOI - Read MOI meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read meta
information from MOI files.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://en.wikipedia.org/wiki/MOI_(file_format)>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MOI Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

