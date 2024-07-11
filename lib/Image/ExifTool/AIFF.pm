#------------------------------------------------------------------------------
# File:         AIFF.pm
#
# Description:  Read AIFF meta information
#
# Revisions:    01/06/2006 - P. Harvey Created
#               09/22/2008 - PH Added DjVu support
#
# References:   1) http://developer.apple.com/documentation/QuickTime/INMAC/SOUND/imsoundmgr.30.htm#pgfId=3190
#               2) http://astronomy.swin.edu.au/~pbourke/dataformats/aiff/
#               3) http://www.mactech.com/articles/mactech/Vol.06/06.01/SANENormalized/
#------------------------------------------------------------------------------

package Image::ExifTool::AIFF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::ID3;

$VERSION = '1.13';

# information for time/date-based tags (time zero is Jan 1, 1904)
my %timeInfo = (
    Groups => { 2 => 'Time' },
    ValueConv => 'ConvertUnixTime($val - ((66 * 365 + 17) * 24 * 3600))',
    PrintConv => '$self->ConvertDateTime($val)',
);

# AIFF info
%Image::ExifTool::AIFF::Main = (
    GROUPS => { 2 => 'Audio' },
    NOTES => q{
        Tags extracted from Audio Interchange File Format (AIFF) files.  See
        L<http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/AIFF/AIFF.html> for
        the AIFF specification.
    },
#    FORM => 'Format',
    FVER => {
        Name => 'FormatVersion',
        SubDirectory => { TagTable => 'Image::ExifTool::AIFF::FormatVers' },
    },
    COMM => {
        Name => 'Common',
        SubDirectory => { TagTable => 'Image::ExifTool::AIFF::Common' },
    },
    COMT => {
        Name => 'Comment',
        SubDirectory => { TagTable => 'Image::ExifTool::AIFF::Comment' },
    },
    NAME => {
        Name => 'Name',
        ValueConv => '$self->Decode($val, "MacRoman")',
    },
    AUTH => {
        Name => 'Author',
        Groups => { 2 => 'Author' },
        ValueConv => '$self->Decode($val, "MacRoman")',
    },
   '(c) ' => {
        Name => 'Copyright',
        Groups => { 2 => 'Author' },
        ValueConv => '$self->Decode($val, "MacRoman")',
    },
    ANNO => {
        Name => 'Annotation',
        ValueConv => '$self->Decode($val, "MacRoman")',
    },
   'ID3 ' => {
        Name => 'ID3',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ID3::Main',
            ProcessProc => \&Image::ExifTool::ID3::ProcessID3,
        },
    },
    APPL => 'ApplicationData', # (first 4 bytes are the application signature)
#    SSND => 'SoundData',
#    MARK => 'Marker',
#    INST => 'Instrument',
#    MIDI => 'MidiData',
#    AESD => 'AudioRecording',
);

%Image::ExifTool::AIFF::Common = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Audio' },
    FORMAT => 'int16u',
    0 => 'NumChannels',
    1 => { Name => 'NumSampleFrames', Format => 'int32u' },
    3 => 'SampleSize',
    4 => { Name => 'SampleRate', Format => 'extended' }, #3
    9 => {
        Name => 'CompressionType',
        Format => 'string[4]',
        PrintConv => {
            NONE => 'None',
            ACE2 => 'ACE 2-to-1',
            ACE8 => 'ACE 8-to-3',
            MAC3 => 'MAC 3-to-1',
            MAC6 => 'MAC 6-to-1',
            sowt => 'Little-endian, no compression',
            alaw => 'a-law',
            ALAW => 'A-law',
            ulaw => 'mu-law',
            ULAW => 'Mu-law',
           'GSM '=> 'GSM',
            G722 => 'G722',
            G726 => 'G726',
            G728 => 'G728',
        },
    },
    11 => { #PH
        Name => 'CompressorName',
        Format => 'pstring',
        ValueConv => '$self->Decode($val, "MacRoman")',
    },
);

%Image::ExifTool::AIFF::FormatVers = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    FORMAT => 'int32u',
    0 => { Name => 'FormatVersionTime', %timeInfo },
);

%Image::ExifTool::AIFF::Comment = (
    PROCESS_PROC => \&Image::ExifTool::AIFF::ProcessComment,
    GROUPS => { 2 => 'Audio' },
    0 => { Name => 'CommentTime', %timeInfo },
    1 => 'MarkerID',
    2 => {
        Name => 'Comment',
        ValueConv => '$self->Decode($val, "MacRoman")',
    },
);

%Image::ExifTool::AIFF::Composite = (
    Duration => {
        Require => {
            0 => 'AIFF:SampleRate',
            1 => 'AIFF:NumSampleFrames',
        },
        RawConv => '($val[0] and $val[1]) ? $val[1] / $val[0] : undef',
        PrintConv => 'ConvertDuration($val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::AIFF');


#------------------------------------------------------------------------------
# Process AIFF Comment chunk
# Inputs: 0) ExifTool object reference, 1) DirInfo reference, 2) tag table ref
# Returns: 1 on success
sub ProcessComment($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my $verbose = $et->Options('Verbose');
    return 0 unless $dirLen > 2;
    my $numComments = unpack('n',$$dataPt);
    my $pos = 2;
    my $i;
    $verbose and $et->VerboseDir('Comment', $numComments);
    for ($i=0; $i<$numComments; ++$i) {
        last if $pos + 8 > $dirLen;
        my ($time, $markerID, $size) = unpack("x${pos}Nnn", $$dataPt);
        $et->HandleTag($tagTablePtr, 0, $time);
        $et->HandleTag($tagTablePtr, 1, $markerID) if $markerID;
        $pos += 8;
        last if $pos + $size > $dirLen;
        my $val = substr($$dataPt, $pos, $size);
        $et->HandleTag($tagTablePtr, 2, $val);
        ++$size if $size & 0x01;    # account for padding byte if necessary
        $pos += $size;
    }
}

#------------------------------------------------------------------------------
# Extract information from a AIFF file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid AIFF file
sub ProcessAIFF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $err, $tagTablePtr, $page, $type, $n);

    # verify this is a valid AIFF file
    return 0 unless $raf->Read($buff, 12) == 12;
    my $fast3 = $$et{OPTIONS}{FastScan} && $$et{OPTIONS}{FastScan} == 3;
    my $pos = 12;
    # check for DjVu image
    if ($buff =~ /^AT&TFORM/) {
        # http://www.djvu.org/
        # http://djvu.sourceforge.net/specs/djvu3changes.txt
        my $buf2;
        return 0 unless $raf->Read($buf2, 4) == 4 and $buf2 =~ /^(DJVU|DJVM)/;
        $pos += 4;
        $buff = substr($buff, 4) . $buf2;
        $et->SetFileType('DJVU');
        return 1 if $fast3;
        $tagTablePtr = GetTagTable('Image::ExifTool::DjVu::Main');
        # modify FileType to indicate a multi-page document
        $$et{VALUE}{FileType} .= " (multi-page)" if $buf2 eq 'DJVM' and $$et{VALUE}{FileType};
        $type = 'DjVu';
    } else {
        return 0 unless $buff =~ /^FORM....(AIF(F|C))/s;
        $et->SetFileType($1);
        return 1 if $fast3;
        $tagTablePtr = GetTagTable('Image::ExifTool::AIFF::Main');
        $type = 'AIFF';
    }
    SetByteOrder('MM');
    my $verbose = $et->Options('Verbose');
#
# Read through the IFF chunks
#
    for ($n=0;;++$n) {
        $raf->Read($buff, 8) == 8 or last;
        $pos += 8;
        my ($tag, $len) = unpack('a4N', $buff);
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        $et->VPrint(0, "AIFF '${tag}' chunk ($len bytes of data): ", $raf->Tell(),"\n");
        # AIFF chunks are padded to an even number of bytes
        my $len2 = $len + ($len & 0x01);
        if ($len2 > 100000000) {
            if ($len2 >= 0x80000000) {
                if (not $et->Options('LargeFileSupport')) {
                    $et->Warn('End of processing at large chunk (LargeFileSupport not enabled)');
                    last;
                } elsif ($et->Options('LargeFileSupport') eq '2') {
                    $et->WarnOnce('Skipping large chunk (LargeFileSupport is 2)');
                }
            }
            if ($tagInfo) {
                $et->Warn("Skipping large $$tagInfo{Name} chunk (> 100 MB)");
                undef $tagInfo;
            }
        }
        if ($tagInfo) {
            if ($$tagInfo{TypeOnly}) {
                $len = $len2 = 4;
                $page = ($page || 0) + 1;
                $et->VPrint(0, $$et{INDENT} . "Page $page:\n");
            }
            $raf->Read($buff, $len2) >= $len or $err=1, last;
            unless ($$tagInfo{SubDirectory} or $$tagInfo{Binary}) {
                $buff =~ s/\0+$//;  # remove trailing nulls
            }
            $et->HandleTag($tagTablePtr, $tag, $buff,
                DataPt => \$buff,
                DataPos => $pos,
                Start => 0,
                Size => $len,
            );
        } elsif (not $len) {
            next if ++$n < 100;
            $et->Warn('Aborting scan.  Too many empty chunks');
            last;
        } elsif ($verbose > 2 and $len2 < 1024000) {
            $raf->Read($buff, $len2) == $len2 or $err = 1, last;
            $et->VerboseDump(\$buff);
        } else {
            $raf->Seek($len2, 1) or $err=1, last;
        }
        $pos += $len2;
        $n = 0;
    }
    $err and $et->Warn("Error reading $type file (corrupted?)");
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::AIFF - Read AIFF meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to extract
information from AIFF (Audio Interchange File Format) audio files.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://developer.apple.com/documentation/QuickTime/INMAC/SOUND/imsoundmgr.30.htm#pgfId=3190>

=item L<http://astronomy.swin.edu.au/~pbourke/dataformats/aiff/>

=item L<http://www.mactech.com/articles/mactech/Vol.06/06.01/SANENormalized/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/AIFF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
