#------------------------------------------------------------------------------
# File:         DSF.pm
#
# Description:  Read DSF meta information
#
# Revisions:    2025-09-24 - P. Harvey Created
#
# References:   1) https://dsd-guide.com/sites/default/files/white-papers/DSFFileFormatSpec_E.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::DSF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

# DSF header format
%Image::ExifTool::DSF::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Audio' },
    FORMAT => 'int32u',
    NOTES => q{
        Tags read from the 'fmt ' header of a DSF (DSD Stream File) audio files. As
        well, ID3 metadata may also exist in these files. See
        L<https://dsd-guide.com/sites/default/files/white-papers/DSFFileFormatSpec_E.pdf>
        for the specification.
    },
    3 => 'FormatVersion',
    4 => { Name => 'FormatID', PrintConv => { 0 => 'DSD Raw' }},
    5 => {
        Name => 'ChannelType',
        PrintConv => {
            1 => 'Mono',
            2 => 'Stereo (Left, Right)',
            3 => '3 Channels (Left, Right, Center)',
            4 => 'Quad (Left, Right, Back L, Back R)',
            5 => '4 Channels (Left, Right, Center, Bass)',
            6 => '5 Channels (Left, Right, Center, Back L, Back R)',
            7 => '5.1 Channels (Left, Right, Center, Bass, Back L, Back R)',
        },
    },
    6 => 'ChannelCount',
    7 => 'SampleRate',
    8 => 'BitsPerSample',
    9 => { Name => 'SampleCount', Format => 'int64u' },
    11 => 'BlockSize',
);

#------------------------------------------------------------------------------
# Extract metadata from a DSF file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid DSF file
sub ProcessDSF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $buf2, $tagTablePtr);

    # verify this is a valid DSF file
    return 0 unless $raf->Read($buff, 40) == 40;
    return 0 unless $buff =~ /^DSD \x1c\0{7}.{16}fmt /s;
    $et->SetFileType();   # set the FileType tag
    my $tagTbl = GetTagTable('Image::ExifTool::DSF::Main');
    SetByteOrder('II');
    my $fmtLen = Get64u(\$buff,32);
    unless ($fmtLen > 12 and $fmtLen < 1000 and
        $raf->Read($buf2, $fmtLen - 12) == $fmtLen - 12)
    {
        $et->Warn('Error reading DSF fmt chunk');
        return 1;
    }
    my $fileSize = Get64u(\$buff, 12);
    my $metaPos = Get64u(\$buff, 20);
    $buff = substr($buff, 28) . $buf2;
#
# process the DSF 'fmt ' chunk
#
    my %dirInfo = (
        DataPt => \$buff,
        DirStart => 0,
        DirLen => length($buff),
    );
    $et->ProcessBinaryData(\%dirInfo, $tagTbl);
#
# process ID3v2 if it exists
#
    my $metaLen = $fileSize - $metaPos;
    if ($metaPos and $metaLen > 0 and $metaLen < 20000000 and
        $raf->Seek($metaPos, 0) and $raf->Read($buff, $metaLen) == $metaLen)
    {
        $dirInfo{DataPos} = $metaPos;
        $dirInfo{DirLen}  = $metaLen;
        my $id3Tbl = GetTagTable('Image::ExifTool::ID3::Main');
        $et->ProcessDirectory(\%dirInfo, $id3Tbl);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::DSF - Read DSF meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read DSF
(DSD Stream File) audio files.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://dsd-guide.com/sites/default/files/white-papers/DSFFileFormatSpec_E.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/DSF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
