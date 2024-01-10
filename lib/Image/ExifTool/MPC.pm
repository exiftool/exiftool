#------------------------------------------------------------------------------
# File:         MPC.pm
#
# Description:  Read Musepack audio meta information
#
# Revisions:    11/14/2006 - P. Harvey Created
#
# References:   1) http://www.musepack.net/
#------------------------------------------------------------------------------

package Image::ExifTool::MPC;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::FLAC;

$VERSION = '1.01';

# MPC metadata blocks
%Image::ExifTool::MPC::Main = (
    PROCESS_PROC => \&Image::ExifTool::FLAC::ProcessBitStream,
    GROUPS => { 2 => 'Audio' },
    NOTES => q{
        Tags used in Musepack (MPC) audio files.  ExifTool also extracts ID3 and APE
        information from these files.
    },
    'Bit032-063' => 'TotalFrames',
    'Bit080-081' => {
        Name => 'SampleRate',
        PrintConv => {
            0 => 44100,
            1 => 48000,
            2 => 37800,
            3 => 32000,
        },
    },
    'Bit084-087' => {
        Name => 'Quality',
        PrintConv => {
             1 => 'Unstable/Experimental',
             5 => '0',
             6 => '1',
             7 => '2 (Telephone)',
             8 => '3 (Thumb)',
             9 => '4 (Radio)',
            10 => '5 (Standard)',
            11 => '6 (Xtreme)',
            12 => '7 (Insane)',
            13 => '8 (BrainDead)',
            14 => '9',
            15 => '10',
       },
    },
    'Bit088-093' => 'MaxBand',
    'Bit096-111' => 'ReplayGainTrackPeak',
    'Bit112-127' => 'ReplayGainTrackGain',
    'Bit128-143' => 'ReplayGainAlbumPeak',
    'Bit144-159' => 'ReplayGainAlbumGain',
    'Bit179' => {
        Name => 'FastSeek',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    'Bit191' => {
        Name => 'Gapless',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    'Bit216-223' => {
        Name => 'EncoderVersion',
        PrintConv => '$val =~ s/(\d)(\d)(\d)$/$1.$2.$3/; $val',
    },
);

#------------------------------------------------------------------------------
# Extract information from an MPC file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# - Just looks for MPC trailer if FileType is already set
# Returns: 1 on success, 0 if this wasn't a valid MPC file
sub ProcessMPC($$)
{
    my ($et, $dirInfo) = @_;

    # must first check for leading ID3 information
    unless ($$et{DoneID3}) {
        require Image::ExifTool::ID3;
        Image::ExifTool::ID3::ProcessID3($et, $dirInfo) and return 1;
    }
    my $raf = $$dirInfo{RAF};
    my $buff;

    # check MPC signature
    $raf->Read($buff, 32) == 32 and $buff =~ /^MP\+(.)/s or return 0;
    my $vers = ord($1) & 0x0f;
    $et->SetFileType();

    # extract audio information (currently only from version 7 MPC files)
    if ($vers == 0x07) {
        SetByteOrder('II');
        my $pos = $raf->Tell() - 32;
        if ($et->Options('Verbose')) {
            $et->VPrint(0, "MPC Header (32 bytes):\n");
            $et->VerboseDump(\$buff, DataPos => $pos);
        }
        my $tagTablePtr = GetTagTable('Image::ExifTool::MPC::Main');
        my %dirInfo = ( DataPt => \$buff, DataPos => $pos );
        $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
    } else {
        $et->Warn('Audio info currently not extracted from this version MPC file');
    }

    # process APE trailer if it exists
    require Image::ExifTool::APE;
    Image::ExifTool::APE::ProcessAPE($et, $dirInfo);

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MPC - Read Musepack audio meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from Musepack (MPC) audio files.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.musepack.net/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MPC Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

