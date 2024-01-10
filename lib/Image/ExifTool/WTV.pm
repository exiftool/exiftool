#------------------------------------------------------------------------------
# File:         WTV.pm
#
# Description:  Read WTV meta information
#
# Revisions:    2018-05-30 - P. Harvey Created
#
# References:   1) https://wiki.multimedia.cx/index.php?title=WTV
#------------------------------------------------------------------------------

package Image::ExifTool::WTV;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

sub ProcessMetadata($$$);

my %timeInfo = (
    # time looks like 100 ns intervals since 0:00 UTC Jan 1, 0001 (ref PH)
    ValueConv => q{ # (719162 days from 0001:01:01 to 1970:01:01)
        my $t = $val / 1e7 - 719162*24*3600;
        return Image::ExifTool::ConvertUnixTime($t) . 'Z';
    },
    PrintConv => '$self->ConvertDateTime($val)',
);

my %bool = ( PrintConv => { 0 => 'No', 1 => 'Yes' }, PrintConvColumns => 2 );

# WTV chunks
%Image::ExifTool::WTV::Main = (
    GROUPS => { 0 => 'WTV', 1 => 'WTV', 2 => 'Video' },
    NOTES => 'Tags found in Windows recorded TV (WTV) videos.',
  # 'timeline.table.0.header.Events' (not decoded)
  # 'timeline.table.0.entries.Events' (not decoded)
  # 'timeline' (not decoded)
  # 'table.0.header.legacy_attrib' (not decoded)
    'table.0.entries.legacy_attrib' => {
        Name => 'Metdata',
        SubDirectory => { TagTable => 'Image::ExifTool::WTV::Metadata' },
    },
  # 'table.0.redirector.legacy_attrib' (not decoded)
  # 'table.0.header.time' (not decoded)
  # 'table.0.entries.time' (not decoded)
);

# Note: Many of these tags are similar to those found in Image::ExifTool::Microsoft::Xtra
#       and Image::ExifTool::ASF::ExtendedDescr
%Image::ExifTool::WTV::Metadata = (
    GROUPS => { 0 => 'WTV', 1 => 'WTV', 2 => 'Video' },
    PROCESS_PROC => \&ProcessMetadata,
    NOTES => 'ExifTool will extract any tag found, even if not in this table.',
    VARS => { NO_ID => 1 },
    'Duration'  => {
        Name => 'Duration',
        ValueConv => '$val/1e7',
        PrintConv => 'ConvertDuration($val)',
    },
    'Title'     => { },
    'WM/Genre'  => 'Genre',
    'WM/Language'               => 'Language',
    'WM/MediaClassPrimaryID'    => 'MediaClassPrimaryID',
    'WM/MediaClassSecondaryID'  => 'MediaClassSecondaryID',
    'WM/MediaCredits'           => 'MediaCredits',
    'WM/MediaIsDelay'           => { Name => 'MediaIsDelay',    %bool },
    'WM/MediaIsFinale'          => { Name => 'MediaIsFinale',   %bool },
    'WM/MediaIsLive'            => { Name => 'MediaIsLive',     %bool },
    'WM/MediaIsMovie'           => { Name => 'MediaIsMovie',    %bool },
    'WM/MediaIsPremiere'        => { Name => 'MediaIsPremiere', %bool },
    'WM/MediaIsRepeat'          => { Name => 'MediaIsRepeat',   %bool },
    'WM/MediaIsSAP'             => { Name => 'MediaIsSAP',      %bool },
    'WM/MediaIsSport'           => { Name => 'MediaIsSport',    %bool },
    'WM/MediaIsStereo'          => { Name => 'MediaIsStereo',   %bool, Groups => { 2 => 'Audio' } },
    'WM/MediaIsSubtitled'       => { Name => 'MediaIsSubtitled',%bool },
    'WM/MediaIsTape'            => { Name => 'MediaIsTape',     %bool },
    'WM/MediaNetworkAffiliation'=> 'MediaNetworkAffiliation',
    'WM/MediaOriginalBroadcastDateTime' => {
        Name => 'MediaOriginalBroadcastDateTime',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ tr/-T/: /; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    'WM/MediaOriginalChannel'   => { Name => 'MediaOriginalChannel' },
    'WM/MediaOriginalChannelSubNumber'  => { Name => 'MediaOriginalChannelSubNumber' },
    'WM/MediaOriginalRunTime'   => {
        Name => 'MediaOriginalRunTime',
        ValueConv => '$val / 1e7',
        PrintConv => 'ConvertDuration($val)',
    },
    'WM/MediaStationCallSign'   => 'MediaStationCallSign',
    'WM/MediaStationName'       => 'MediaStationName',
    'WM/MediaThumbAspectRatioX' => 'MediaThumbAspectRatioX',
    'WM/MediaThumbAspectRatioY' => 'MediaThumbAspectRatioY',
    'WM/MediaThumbHeight'       => 'MediaThumbHeight',
    'WM/MediaThumbRatingAttributes'     => { Name => 'MediaThumbRatingAttributes' },
    'WM/MediaThumbRatingLevel'  => 'MediaThumbRatingLevel',
    'WM/MediaThumbRatingSystem' => 'MediaThumbRatingSystem',
    'WM/MediaThumbRet'          => 'MediaThumbRet',
    'WM/MediaThumbStride'       => 'MediaThumbStride',
    'WM/MediaThumbTimeStamp'    => { Name => 'MediaThumbTimeStamp', Notes => 'unknown units', Unknown => 1 },
    'WM/MediaThumbWidth'        => 'MediaThumbWidth',
    'WM/OriginalReleaseTime'    => {
        Name => 'OriginalReleaseTime',
        Groups => { 2 => 'Time' },
        ValueConv => '$val=~tr/-T/: /; $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    'WM/ParentalRating'         => 'ParentalRating',
    'WM/ParentalRatingReason'   => 'ParentalRatingReason',
    'WM/Provider'               => 'Provider',
    'WM/ProviderCopyright'      => 'ProviderCopyright',
    'WM/ProviderRating'         => 'ProviderRating',
    'WM/SubTitle'               => 'Subtitle',
    'WM/SubTitleDescription'    => 'SubtitleDescription',
    'WM/VideoClosedCaptioning'  => { Name => 'VideoClosedCaptioning', %bool },
    'WM/WMRVATSCContent'        => { Name => 'ATSCContent', %bool },
    'WM/WMRVActualSoftPostPadding'  => 'ActualSoftPostPadding',
    'WM/WMRVActualSoftPrePadding'   => 'ActualSoftPrePadding',
    'WM/WMRVBitrate'            => { Name => 'Bitrate', Notes => 'unknown units', Unknown => 1 },
    'WM/WMRVBrandingImageID'    => 'BrandingImageID',
    'WM/WMRVBrandingName'       => 'BrandingName',
    'WM/WMRVContentProtected'   => { Name => 'ContentProtected', %bool },
    'WM/WMRVContentProtectedPercent' => 'ContentProtectedPercent',
    'WM/WMRVDTVContent'         => { Name => 'DTVContent', %bool },
    'WM/WMRVEncodeTime'         => { Name => 'EncodeTime',     Groups => { 2 => 'Time' }, %timeInfo },
    'WM/WMRVEndTime'            => { Name => 'EndTime',        Groups => { 2 => 'Time' }, %timeInfo },
    'WM/WMRVExpirationDate'     => { Name => 'ExpirationDate', Groups => { 2 => 'Time' }, %timeInfo, Unknown => 1 },
    'WM/WMRVExpirationSpan'     => { Name => 'ExpirationSpan', Notes => 'unknown units', Unknown => 1 },
    'WM/WMRVHDContent'          => { Name => 'HDContent', %bool },
    'WM/WMRVHardPostPadding'    => 'HardPostPadding',
    'WM/WMRVHardPrePadding'     => 'HardPrePadding',
    'WM/WMRVInBandRatingAttributes' => 'InBandRatingAttributes',
    'WM/WMRVInBandRatingLevel'  => 'InBandRatingLevel',
    'WM/WMRVInBandRatingSystem' => 'InBandRatingSystem',
    'WM/WMRVKeepUntil'          => 'KeepUntil',
    'WM/WMRVOriginalSoftPostPadding'=> 'OriginalSoftPostPadding',
    'WM/WMRVOriginalSoftPrePadding' => 'OriginalSoftPrePadding',
    'WM/WMRVProgramID'          => 'ProgramID',
    'WM/WMRVQuality'            => 'Quality',
    'WM/WMRVRequestID'          => 'RequestID',
    'WM/WMRVScheduleItemID'     => 'ScheduleItemID',
    'WM/WMRVSeriesUID'          => 'SeriesUID',
    'WM/WMRVServiceID'          => 'ServiceID',
    'WM/WMRVWatched'            => { Name => 'Watched', %bool },
);

#------------------------------------------------------------------------------
# Read specified sectors from the file
# Inputs: 0) raf ref, 1) sector table ref, 2) offset in sector table, 3) sector size
# Returns: Data or undef on error
sub ReadSectors($$$$)
{
    my ($raf, $secPt, $pos, $secSize) = @_;
    my ($data, $buff);
    while ($pos <= length($$secPt) - 4) {
        my $sec = Get32u($secPt, $pos);
        return undef if $sec == 0xffff; # (just in case)
        last unless $sec;   # a null marks the end of the sector table
        defined($data) ? ($data .= $buff) : ($data = $buff);
        return undef unless $raf->Seek($sec*$secSize,0) and $raf->Read($buff,$secSize) == $secSize;
        $pos += 4;
    }
    return defined($data) ? $data . $buff : $buff;
}

#------------------------------------------------------------------------------
# Process WTV metadata
# Inputs: 0) ExifTool object reference, 1) dirInfo reference, 2) tag table ref
# Returns: 1 on success
sub ProcessMetadata($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = 0;
    my $end = length $$dataPt;
    $et->VerboseDir('WTV Metadata', undef, $end);
    while ($pos + 0x18 < $end) {
        last unless substr($$dataPt,$pos,16) eq "\x5a\xfe\xd7\x6d\xc8\x1d\x8f\x4a\x99\x22\xfa\xb1\x1c\x38\x14\x53";
        my $fmt = Get32u($dataPt, $pos + 0x10);
        my $len = Get32u($dataPt, $pos + 0x14);
        my $str = '';
        $pos += 0x18;
        for (;;) {
            $pos + 2 > $end and $et->Warn('Corrupt metadata directory'), last;
            my $ch = substr($$dataPt, $pos, 2);
            $pos += 2;
            last if $ch eq "\0\0";
            $str .= $ch;
        }
        last if $pos + $len > $end;
        my $tag = $et->Decode($str, 'UCS2', undef, 'UTF8');
        my $dat = substr($$dataPt, $pos, $len);
        # add tag if not already there
        unless ($$tagTablePtr{$tag}) {
            my $name = $tag;
            $name =~ s{^(WTV_Metadata_)?WM/(WMRV)?}{};
            AddTagToTable($tagTablePtr, $tag, $name);
            $et->VPrint(0, $$et{INDENT}, "[adding WTV:$name]\n");
        }
        my $val;
        if ($fmt==0 or $fmt==3) {   # int32u or boolean32
            $val = Get32s(\$dat, 0);
        } elsif ($fmt == 1) {       # string
            $val = $et->Decode($dat, 'UCS2');
        } elsif ($fmt == 6) {       # GUID
            $val = unpack('H*', $dat);
        } elsif ($fmt == 4) {       # int64u (date/time values use this)
            $val = Get64u(\$dat, 0);
        } else {
            $val = $dat;
            $fmt = "Unknown($fmt)";
        }
        $et->HandleTag($tagTablePtr, $tag, $val,
            Format => "format $fmt",
            Size => length $dat,
        );
        $et->VerboseDump(\$dat);
        $pos += $len;
    }
}

#------------------------------------------------------------------------------
# Extract information from a WTV video
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid WTV file
sub ProcessWTV($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my ($buff, $tagTablePtr, $pos, $len);

    # verify this is a valid WTV file
    return 0 unless $raf->Read($buff, 0x60) == 0x60;
    return 0 unless $buff =~ /^\xb7\xd8\x00\x20\x37\x49\xda\x11\xa6\x4e\x00\x07\xe9\x5e\xad\x8d/;
    $et->SetFileType();
    SetByteOrder('II');
    # 0x28 - int32u: sector size? (=0x1000) (PH NC)
    # 0x38 - int32u: sector number for main WTV directory (PH assume this is a sector table, NC)
    # 0x58 - int32u: total number of sectors in file
    my $secSize = Get32u(\$buff, 0x28);
    # in case I'm wrong about this, constrain sector size to
    # either 0x1000 (standard) or 0x100 (ExifTool test file) - PH
    $secSize = 0x1000 unless $secSize == 0x1000 or $secSize == 0x100;
    $buff = ReadSectors($raf, \$buff, 0x38, $secSize);  # read the WTV directory
    return 0 unless defined $buff;
    $tagTablePtr = GetTagTable('Image::ExifTool::WTV::Main');
    # parse the WTV directory
    $et->VerboseDir('WTV');
    for ($pos=0; $pos<length($buff)-0x28; $pos+=$len) {
        unless (substr($buff,$pos,0x10) eq "\x92\xb7\x74\x91\x59\x70\x70\x44\x88\xdf\x06\x3b\x82\xcc\x21\x3d") {
            $et->Warn("WTV directory wasn't at expected location") unless $pos;
            last;
        }
        $len = Get32u(\$buff, $pos+0x10);
        last if $pos + $len > length($buff);
        my $n = Get32u(\$buff, $pos + 0x20);
        0x28 + $n*2 + 8 > $len and $et->Warn('WTV directory error'), last;
        my $tag = $et->Decode(substr($buff,$pos+0x28,$n*2), 'UCS2', undef, 'UTF8');
        my $ptr = $pos + 0x28 + $n * 2;
        my $flg = Get32u(\$buff, $ptr + 4);
        if ($verbose) {
            my $s = Get32s(\$buff, $ptr);
            $s = sprintf('0x%x', $s) unless $s < 0;
            $et->VPrint(1,"- Tag '${tag}' (sector=$s, flag=$flg)");
        }
        next unless $$tagTablePtr{$tag} and ($flg == 0 or $flg == 1);
        my $sec = substr($buff, $ptr, 4);
        my $data = ReadSectors($raf, \$sec, 0, $secSize);
        last unless defined $data;
        # read sectors from table if necessary (flag=1 indicates a sector table)
        $data = ReadSectors($raf, \$data, 0, $secSize) if $flg == 1;
        defined $data or $et->Warn("Error fetching data for $tag"), next;
        $et->HandleTag($tagTablePtr, $tag, $data);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::WTV - Read WTV meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read WTV
(Windows recorded TV show) videos.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://wiki.multimedia.cx/index.php?title=WTV>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/WTV Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

