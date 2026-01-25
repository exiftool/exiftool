#------------------------------------------------------------------------------
# File:         WavPack.pm
#
# Description:  Read metadata from WavPack audio files
#
# Revisions:    2025-09-24 - P. Harvey Created
#
# References:   1) https://www.wavpack.com/WavPack5FileFormat.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::WavPack;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::RIFF;
use Image::ExifTool::APE;

$VERSION = '1.00';

%Image::ExifTool::WavPack::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Audio' },
    FORMAT => 'int32u',
    NOTES => q{
        Tags extracted from the header of WavPack (WV and WVP) audio files.  These
        files may also contain RIFF, ID3 and/or APE metadata which is also extracted
        by ExifTool.  See L<https://www.wavpack.com/WavPack5FileFormat.pdf> for the
        WavPack specification.
    },
    6.1 => {
        Name => 'BytesPerSample',
        Mask => 0x03,
        ValueConv => '$val + 1',
    },
    6.2 => {
        Name => 'AudioType',
        Mask => 0x04,
        PrintConv => { 0 => 'Stereo', 1 => 'Mono' },
    },
    6.3 => {
        Name => 'Compression',
        Mask => 0x08,
        PrintConv => { 0 => 'Lossless', 1 => 'Hybrid' },
    },
    6.4 => {
        Name => 'DataFormat',
        Mask => 0x80,
        PrintConv => { 0 => 'Integer', 1 => 'Floating Point' },
    },
    6.5 => {
        Name => 'SampleRate',
        Mask => 0x07800000,
        Priority => 0, # ("Custom" is not very useful)
        PrintConv => { # (NC)
            0 => 6000,
            1 => 8000,
            2 => 9600,
            3 => 11025,
            4 => 12000,
            5 => 16000,
            6 => 22050,
            7 => 24000,
            8 => 32000,
            9 => 44100,
            10 => 48000,
            11 => 64000,
            12 => 88200,
            13 => 96000,
            14 => 192000,
            15 => 'Custom',
        },
    },
);

#------------------------------------------------------------------------------
# Extract metadata from a WavPack file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid WavPack file
sub ProcessWV($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;

    # verify this is a valid WavPack file
    return 0 unless $raf->Read($buff, 32) == 32;
    return 0 unless $buff =~ /^wvpk.{4}[\x02\x10]\x04/s;
    $et->SetFileType();
    my %dirInfo = (
        DataPt => \$buff,
        DirStart => 0,
        DirLen => length($buff),
    );
    $et->ProcessBinaryData(\%dirInfo, GetTagTable('Image::ExifTool::WavPack::Main'));
    # historically, the RIFF module has handled RIFF-type WavPack files
    $raf->Seek(0,0);
    push @{$$et{PATH}}, 'RIFF'; # update metadata path
    Image::ExifTool::RIFF::ProcessRIFF($et, $dirInfo);
    # also look for ID3 and APE trailers (ProcessAPE also checks for ID3)
    $$et{PATH}[-1] = 'APE';
    Image::ExifTool::APE::ProcessAPE($et, $dirInfo);
    pop @{$$et{PATH}};
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::WavPack - Read metadata from WavPack audio files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read metadata
from WavPack audio files.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://www.wavpack.com/WavPack5FileFormat.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/WavPack Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
