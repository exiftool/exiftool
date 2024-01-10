#------------------------------------------------------------------------------
# File:         Real.pm
#
# Description:  Read Real audio/video meta information
#
# Revisions:    05/16/2006 - P. Harvey Created
#
# References:   1) http://www.getid3.org/
#               2) https://common.helixcommunity.org/nonav/2003/HCS_SDK_r5/htmfiles/rmff.htm
#------------------------------------------------------------------------------

package Image::ExifTool::Real;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Canon;

$VERSION = '1.07';

sub ProcessRealMeta($$$);
sub ProcessRealProperties($$$);

# Real property types (ref PH)
my %propertyType = (
    0 => 'int32u',
    2 => 'string',
);

# Real Metadata property types
my %metadataFormat = (
    1 => 'string',  # text
    2 => 'string',  # text list
    3 => 'flag',    # 1 or 4 byte integer
    4 => 'int32u',  # 4-byte integer
    5 => 'undef',   # binary data
    6 => 'string',  # URL
    7 => 'string',  # date
    8 => 'string',  # file name
    9 =>  undef,    # grouping
    10 => undef,    # reference
);

# Real Metadata property flag bit descriptions
my %metadataFlag = (
    0 => 'Read Only',
    1 => 'Private',
    2 => 'Type Descriptor',
);


# tags used in RealMedia (RM, RV and RMVB) files
%Image::ExifTool::Real::Media = (
    GROUPS => { 2 => 'Video' },
    NOTES => q{
        These B<Tag ID>'s are Chunk ID's used in RealMedia and RealVideo (RM, RV and
        RMVB) files.
    },
    CONT => { SubDirectory => { TagTable => 'Image::ExifTool::Real::ContentDescr' } },
    MDPR => { SubDirectory => { TagTable => 'Image::ExifTool::Real::MediaProps' } },
    PROP => { SubDirectory => { TagTable => 'Image::ExifTool::Real::Properties' } },
    RJMD => { SubDirectory => { TagTable => 'Image::ExifTool::Real::Metadata' } },
);

# pseudo-tags used in RealAudio (RA) files
%Image::ExifTool::Real::Audio = (
    GROUPS => { 2 => 'Audio' },
    NOTES => q{
        Tags in the following table reference information extracted from various
        versions of RealAudio (RA) files.
    },
    '.ra3' => { Name => 'RA3', SubDirectory => { TagTable => 'Image::ExifTool::Real::AudioV3' } },
    '.ra4' => { Name => 'RA4', SubDirectory => { TagTable => 'Image::ExifTool::Real::AudioV4' } },
    '.ra5' => { Name => 'RA5', SubDirectory => { TagTable => 'Image::ExifTool::Real::AudioV5' } },
);

# pseudo-tags used in RealMedia Metafiles and RealMedia Plug-in Metafiles (RAM and RPM)
%Image::ExifTool::Real::Metafile = (
    GROUPS => { 2 => 'Video' },
    NOTES => q{
        Tags representing information extracted from Real Audio Metafile and
        RealMedia Plug-in Metafile (RAM and RPM) files.
    },
    txt => 'Text',
    url => 'URL',
);

%Image::ExifTool::Real::Properties = (
    GROUPS => { 1 => 'Real-PROP', 2 => 'Video' },
    PROCESS_PROC => \&Image::ExifTool::Canon::ProcessSerialData,
    VARS => { ID_LABEL => 'Sequence' },
    FORMAT => 'int32u',
    0  => { Name => 'MaxBitrate', PrintConv => 'ConvertBitrate($val)' },
    1  => { Name => 'AvgBitrate', PrintConv => 'ConvertBitrate($val)' },
    2  => 'MaxPacketSize',
    3  => 'AvgPacketSize',
    4  => 'NumPackets',
    5 => { Name => 'Duration',      ValueConv => '$val / 1000',  PrintConv => 'ConvertDuration($val)' },
    6 => { Name => 'Preroll',       ValueConv => '$val / 1000',  PrintConv => 'ConvertDuration($val)' },
    7 => { Name => 'IndexOffset',   Unknown => 1 },
    8 => { Name => 'DataOffset',    Unknown => 1 },
    9 => { Name => 'NumStreams',    Format => 'int16u' },
    10 => {
        Name => 'Flags',
        Format => 'int16u',
        PrintConv => { BITMASK => {
            0 => 'Allow Recording',
            1 => 'Perfect Play',
            2 => 'Live',
            3 => 'Allow Download', #PH (from rmeditor dump)
        } },
    },
);

%Image::ExifTool::Real::MediaProps = (
    GROUPS => { 1 => 'Real-MDPR', 2 => 'Video' },
    PROCESS_PROC => \&Image::ExifTool::Canon::ProcessSerialData,
    VARS => { ID_LABEL => 'Sequence' },
    FORMAT => 'int32u',
    PRIORITY => 0,  # first stream takes priority
    0  => { Name => 'StreamNumber',  Format => 'int16u' },
    1  => { Name => 'StreamMaxBitrate', PrintConv => 'ConvertBitrate($val)' },
    2  => { Name => 'StreamAvgBitrate', PrintConv => 'ConvertBitrate($val)' },
    3  => { Name => 'StreamMaxPacketSize' },
    4  => { Name => 'StreamAvgPacketSize' },
    5  => { Name => 'StreamStartTime' },
    6  => { Name => 'StreamPreroll', ValueConv => '$val / 1000',  PrintConv => 'ConvertDuration($val)' },
    7  => { Name => 'StreamDuration',ValueConv => '$val / 1000',  PrintConv => 'ConvertDuration($val)' },
    8  => { Name => 'StreamNameLen', Format => 'int8u', Unknown => 1 },
    9  => { Name => 'StreamName',    Format => 'string[$val{8}]' },
    10 => { Name => 'StreamMimeLen', Format => 'int8u', Unknown => 1 },
    11 => {
        Name => 'StreamMimeType',
        Format => 'string[$val{10}]',
        RawConv => '$self->{RealStreamMime} = $val',
    },
    12 => { Name => 'FileInfoLen', Unknown => 1 },
    13 => {
        Name => 'FileInfoLen2',
        # if this condition fails, subsequent tags will not be processed
        Condition => '$self->{RealStreamMime} eq "logical-fileinfo"',
        Unknown => 1,
    },
    14 => {
        Name => 'FileInfoVersion',
        Format => 'int16u',
    },
    15 => {
        Name => 'PhysicalStreams',
        Format => 'int16u',
        Unknown => 1,
    },
    16 => {
        Name => 'PhysicalStreamNumbers',
        Format => 'int16u[$val{15}]',
        Unknown => 1,
    },
    17 => {
        Name => 'DataOffsets',
        Format => 'int32u[$val{15}]',
        Unknown => 1,
    },
    18 => {
        Name => 'NumRules',
        Format => 'int16u',
        Unknown => 1,
    },
    19 => {
        Name => 'PhysicalStreamNumberMap',
        Format => 'int16u[$val{18}]',
        Unknown => 1,
    },
    20 => {
        Name => 'NumProperties',
        Format => 'int16u',
        Unknown => 1,
    },
    21 => {
        Name => 'FileInfoProperties',
        Format => 'undef[$val{13}-$val{15}*6-$val{18}*2-12]',
        SubDirectory => { TagTable => 'Image::ExifTool::Real::FileInfo' },
    },
);

# Observed FileInfo properties (ref PH)
%Image::ExifTool::Real::FileInfo = (
    GROUPS => { 1 => 'Real-MDPR', 2 => 'Video' },
    PROCESS_PROC => \&ProcessRealProperties,
    NOTES => q{
        The following tags have been observed in the FileInfo properties, but any
        other existing information will also be extracted.
    },
    Indexable       => { PrintConv => { 0 => 'False', 1 => 'True' } },
    Keywords        => { },
    Description     => { },
   'File ID'        => { Name => 'FileID' },
   'Content Rating' => {
        Name => 'ContentRating',
        PrintConv => {
            0 => 'No Rating',
            1 => 'All Ages',
            2 => 'Older Children',
            3 => 'Younger Teens',
            4 => 'Older Teens',
            5 => 'Adult Supervision Recommended',
            6 => 'Adults Only',
        },
    },
    Audiences       => { },
    audioMode       => { Name => 'AudioMode' },
   'Creation Date'  => {
        Name => 'CreateDate',
        Groups => { 2 => 'Time' },
        ValueConv => q{
            $val =~ m{(\d+)/(\d+)/(\d+)\s+(\d+):(\d+):(\d+)} ?
            sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2d",$3,$2,$1,$4,$5,$6) : $val
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
   'Generated By'   => { Name => 'Software' },
   'Modification Date' => {
        Name => 'ModifyDate',
        Groups => { 2 => 'Time' },
        ValueConv => q{
            $val =~ m{(\d+)/(\d+)/(\d+)\s+(\d+):(\d+):(\d+)} ?
            sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2d",$3,$2,$1,$4,$5,$6) : $val
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
   'Target Audiences' => { Name => 'TargetAudiences' },
   'Audio Format'   => { Name => 'AudioFormat' },
   'Video Quality'  => { Name => 'VideoQuality' },
    videoMode       => { Name => 'VideoMode' },
);

%Image::ExifTool::Real::ContentDescr = (
    GROUPS => { 1 => 'Real-CONT', 2 => 'Video' },
    PROCESS_PROC => \&Image::ExifTool::Canon::ProcessSerialData,
    VARS => { ID_LABEL => 'Sequence' },
    FORMAT => 'int16u',
    0 => { Name => 'TitleLen',      Unknown => 1 },
    1 => { Name => 'Title',         Format => 'string[$val{0}]' },
    2 => { Name => 'AuthorLen',     Unknown => 1 },
    3 => { Name => 'Author',        Format => 'string[$val{2}]', Groups => { 2 => 'Author' } },
    4 => { Name => 'CopyrightLen',  Unknown => 1 },
    5 => { Name => 'Copyright',     Format => 'string[$val{4}]', Groups => { 2 => 'Author' } },
    6 => { Name => 'CommentLen',    Unknown => 1 },
    7 => { Name => 'Comment',       Format => 'string[$val{6}]' },
);

# Real RJMD meta information (ref PH)
%Image::ExifTool::Real::Metadata = (
    GROUPS => { 1 => 'Real-RJMD', 2 => 'Video' },
    PROCESS_PROC => \&ProcessRealMeta,
    NOTES => q{
        The tags below represent information which has been observed in the Real
        Metadata format, but ExifTool will extract any information it finds in this
        format.  (As far as I can tell from the referenced documentation, string
        values should be plain text, but this is not the case for the only sample
        file I have been able to obtain containing this information.  These tags
        could also be split into separate sub-directories, but this will wait until
        I have better documentation or a more complete set of samples.)
    },
   'Album/Name'     => 'AlbumName',
   'Track/Category' => 'TrackCategory',
   'Track/Comments' => 'TrackComments',
   'Track/Lyrics'   => 'TrackLyrics',
);

%Image::ExifTool::Real::AudioV3 = (
    GROUPS => { 1 => 'Real-RA3', 2 => 'Audio' },
    PROCESS_PROC => \&Image::ExifTool::Canon::ProcessSerialData,
    VARS => { ID_LABEL => 'Sequence' },
    FORMAT => 'int8u',
    0  => { Name => 'Channels',       Format => 'int16u' },
    1  => { Name => 'Unknown',        Format => 'int16u[3]', Unknown => 1 },
    2  => { Name => 'BytesPerMinute', Format => 'int16u' },
    3  => { Name => 'AudioBytes',     Format => 'int32u' },
    4  => { Name => 'TitleLen',       Unknown => 1 },
    5  => { Name => 'Title',          Format => 'string[$val{4}]' },
    6  => { Name => 'ArtistLen',      Unknown => 1 },
    7  => { Name => 'Artist',         Format => 'string[$val{6}]', Groups => { 2 => 'Author' } },
    8  => { Name => 'CopyrightLen',   Unknown => 1 },
    9  => { Name => 'Copyright',      Format => 'string[$val{8}]', Groups => { 2 => 'Author' } },
    10 => { Name => 'CommentLen',     Unknown => 1 },
    11 => { Name => 'Comment',        Format => 'string[$val{10}]' },
);

%Image::ExifTool::Real::AudioV4 = (
    GROUPS => { 1 => 'Real-RA4', 2 => 'Audio' },
    PROCESS_PROC => \&Image::ExifTool::Canon::ProcessSerialData,
    VARS => { ID_LABEL => 'Sequence' },
    FORMAT => 'int16u',
    0  => { Name => 'FourCC1',        Format => 'undef[4]', Unknown => 1 },
    1  => { Name => 'AudioFileSize',  Format => 'int32u',   Unknown => 1 },
    2  => { Name => 'Version2',       Unknown => 1 },
    3  => { Name => 'HeaderSize',     Format => 'int32u',   Unknown => 1 },
    4  => { Name => 'CodecFlavorID',  Unknown => 1 },
    5  => { Name => 'CodedFrameSize', Format => 'int32u',   Unknown => 1 },
    6  => { Name => 'AudioBytes',     Format => 'int32u' },
    7  => { Name => 'BytesPerMinute', Format => 'int32u' },
    8  => { Name => 'Unknown',        Format => 'int32u',   Unknown => 1 },
    9  => { Name => 'SubPacketH',     Unknown => 1 },
    10 => 'AudioFrameSize',
    11 => { Name => 'SubPacketSize',  Unknown => 1 },
    12 => { Name => 'Unknown',        Unknown => 1 },
    13 => 'SampleRate',
    14 => { Name => 'Unknown',        Unknown => 1 },
    15 => 'BitsPerSample',
    16 => 'Channels',
    17 => { Name => 'FourCC2Len',     Format => 'int8u',    Unknown => 1 },
    18 => { Name => 'FourCC2',        Format => 'undef[4]', Unknown => 1 },
    19 => { Name => 'FourCC3Len',     Format => 'int8u',    Unknown => 1 },
    20 => { Name => 'FourCC3',        Format => 'undef[4]', Unknown => 1 },
    21 => { Name => 'Unknown',        Format => 'int8u',    Unknown => 1 },
    22 => { Name => 'Unknown',        Unknown => 1 },
    23 => { Name => 'TitleLen',       Format => 'int8u',    Unknown => 1 },
    24 => { Name => 'Title',          Format => 'string[$val{23}]' },
    25 => { Name => 'ArtistLen',      Format => 'int8u',    Unknown => 1 },
    26 => { Name => 'Artist',         Format => 'string[$val{25}]', Groups => { 2 => 'Author' } },
    27 => { Name => 'CopyrightLen',   Format => 'int8u',    Unknown => 1 },
    28 => { Name => 'Copyright',      Format => 'string[$val{27}]', Groups => { 2 => 'Author' } },
    29 => { Name => 'CommentLen',     Format => 'int8u',    Unknown => 1 },
    30 => { Name => 'Comment',        Format => 'string[$val{29}]' },
);

%Image::ExifTool::Real::AudioV5 = (
    GROUPS => { 1 => 'Real-RA5', 2 => 'Audio' },
    PROCESS_PROC => \&Image::ExifTool::Canon::ProcessSerialData,
    VARS => { ID_LABEL => 'Sequence' },
    FORMAT => 'int16u',
    0  => { Name => 'FourCC1',        Format => 'undef[4]', Unknown => 1 },
    1  => { Name => 'AudioFileSize',  Format => 'int32u',   Unknown => 1 },
    2  => { Name => 'Version2',       Unknown => 1 },
    3  => { Name => 'HeaderSize',     Format => 'int32u',   Unknown => 1 },
    4  => { Name => 'CodecFlavorID',  Unknown => 1 },
    5  => { Name => 'CodedFrameSize', Format => 'int32u',   Unknown => 1 },
    6  => { Name => 'AudioBytes',     Format => 'int32u' },
    7  => { Name => 'BytesPerMinute', Format => 'int32u' },
    8  => { Name => 'Unknown',        Format => 'int32u',   Unknown => 1 },
    9  => { Name => 'SubPacketH',     Unknown => 1 },
    10 => { Name => 'FrameSize',      Unknown => 1 },
    11 => { Name => 'SubPacketSize',  Unknown => 1 },
    12 => 'SampleRate',
    13 => { Name => 'SampleRate2',    Unknown => 1 },
    14 => { Name => 'BitsPerSample',  Format => 'int32u' },
    15 => 'Channels',
    16 => { Name => 'Genr',           Format => 'int32u',   Unknown => 1 },
    17 => { Name => 'FourCC3',        Format => 'undef[4]', Unknown => 1 },
);

#------------------------------------------------------------------------------
# Process Real NameValueProperties
# Inputs: 0) ExifTool object reference, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessRealProperties($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = $$dirInfo{DirLen};
    my $pos = $$dirInfo{DirStart};
    my $verbose = $et->Options('Verbose');

    $verbose and $et->VerboseDir('RealProperties', undef, $dirLen);

    while ($pos + 6 <= $dirLen) {

        # get property size and version
        my ($size, $vers) = unpack("x${pos}Nn", $$dataPt);
        last if $size < 6;
        unless ($vers == 0) {
            $pos += $size;
            next;
        }
        $pos += 6;

        my $tagLen = unpack("x${pos}C", $$dataPt);
        ++$pos;

        last if $pos + $tagLen > $dirLen;
        my $tag = substr($$dataPt, $pos, $tagLen);
        $pos += $tagLen;

        last if $pos + 6 > $dirLen;
        my ($type, $valLen) = unpack("x${pos}Nn", $$dataPt);
        $pos += 6;

        last if $pos + $valLen > $dirLen;
        my $format = $propertyType{$type} || 'undef';
        my $count = int($valLen / Image::ExifTool::FormatSize($format));
        my $val = ReadValue($dataPt, $pos, $format, $count, $dirLen-$pos);

        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        unless ($tagInfo) {
            my $tagName;
            ($tagName = $tag) =~ s/\s+//g;
            next unless $tagName =~ /^\w+$/;    # ignore crazy names
            $tagInfo = { Name => ucfirst($tagName) };
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        if ($verbose) {
            $et->VerboseInfo($tag, $tagInfo,
                Table  => $tagTablePtr,
                Value  => $val,
                DataPt => $dataPt,
                Size   => $valLen,
                Start  => $pos,
                Addr   => $pos + $$dirInfo{DataPos},
                Format => $format,
                Count  => $count,
            );
        }
        $et->FoundTag($tagInfo, $val);
        $pos += $valLen;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process Real metadata properties
# Inputs: 0) ExifTool object reference, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessRealMeta($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $pos = $$dirInfo{DirStart};
    my $dirEnd = $pos + $$dirInfo{DirLen};
    my $verbose = $et->Options('Verbose');
    my $prefix = $$dirInfo{Prefix} || '';
    $prefix and $prefix .= '/';

    $verbose and $et->VerboseDir('RealMetadata', undef, $$dirInfo{DirLen});

    for (;;) {
        last if $pos + 28 > $dirEnd;
        # extract fixed-position metadata structure members
        my ($size, $type, $flags, $valuePos, $subPropPos, $numSubProps, $nameLen)
            = unpack("x${pos}N7", $$dataPt);
        # make pointers relative to data start
        $valuePos += $pos;
        $subPropPos += $pos;
        # validate what we have read so far
        last if $pos + $size > $dirEnd;
        last if $pos + 28 + $nameLen > $dirEnd;
        last if $valuePos <  $pos + 28 + $nameLen;
        last if $valuePos + 4 > $dirEnd;
        my $tag = substr($$dataPt, $pos + 28, $nameLen);
        $tag =~ s/\0.*//s;  # truncate at null
        $tag = $prefix . $tag;
        my $valueLen = unpack("x${valuePos}N", $$dataPt);
        $valuePos += 4; # point at value itself
        last if $valuePos + $valueLen > $dirEnd;

        my $format = $metadataFormat{$type};
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        unless ($tagInfo) {
            my $tagName = $tag;
            $tagName =~ tr/A-Za-z0-9//dc;
            $tagInfo = { Name => ucfirst($tagName) };
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        if ($verbose) {
            $format = 'undef' unless defined $format;
            $flags = Image::ExifTool::DecodeBits($flags, \%metadataFlag);
        }
        if ($valueLen and $format) {
            # (a flag can be 1 or 4 bytes)
            if ($format eq 'flag') {
                $format = ($valueLen == 4) ? 'int32u' : 'int8u';
            } elsif ($type == 7 and $tagInfo) {
                # add PrintConv and ValueConv for "date" type
                $$tagInfo{ValueConv} or $$tagInfo{ValueConv} = q{
                    $val =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})/ ?
                    sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2d",$1,$2,$3,$4,$5,$6) :
                    $val;
                };
                $$tagInfo{PrintConv} or $$tagInfo{PrintConv} = '$self->ConvertDateTime($val)';
            }
            my $count = int($valueLen / Image::ExifTool::FormatSize($format));
            my $val = ReadValue($dataPt, $valuePos, $format, $count, $dirEnd-$valuePos);
            $et->HandleTag($tagTablePtr, $tag, $val,
                DataPt => $dataPt,
                DataPos => $dataPos,
                Start => $valuePos,
                Size => $valueLen,
                Format => "type=$type, flags=$flags",
            );
        }
        # extract sub-properties
        if ($numSubProps) {
            my $dirStart = $valuePos + $valueLen + $numSubProps * 8;
            my %dirInfo = (
                DataPt => $dataPt,
                DataPos => $dataPos,
                DirStart => $dirStart,
                DirLen => $pos + $size - $dirStart,
                Prefix => $tag,
            );
            $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        }
        $pos += $size;  # step to next Metadata structure
    }
    unless ($pos == $dirEnd) {
        $et->Warn('Format error in Real Metadata');
        return 0;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Read information frame a Real file
# Inputs: 0) ExifTool object reference, 1) Directory information reference
# Returns: 1 on success, 0 if this wasn't a valid Real file
sub ProcessReal($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $tag, $vers, $extra, @mimeTypes, %dirCount);

    $raf->Read($buff, 8) == 8 or return 0;
    $buff =~ m{^(\.RMF|\.ra\xfd|pnm://|rtsp://|http://)} or return 0;

    my $fast3 = $$et{OPTIONS}{FastScan} && $$et{OPTIONS}{FastScan} == 3;
    my ($type, $tagTablePtr);
    if ($1 eq '.RMF') {
        $tagTablePtr = GetTagTable('Image::ExifTool::Real::Media');
        $type = 'RM';
    } elsif ($1 eq ".ra\xfd") {
        $tagTablePtr = GetTagTable('Image::ExifTool::Real::Audio');
        $type = 'RA';
    } else {
        $tagTablePtr = GetTagTable('Image::ExifTool::Real::Metafile');
        my $ext = $$et{FILE_EXT};
        $type = ($ext and $ext eq 'RPM') ? 'RPM' : 'RAM';
        require Image::ExifTool::PostScript;
        local $/ = Image::ExifTool::PostScript::GetInputRecordSeparator($raf) || "\n";
        $raf->Seek(0,0);
        while ($raf->ReadLine($buff)) {
            last if length $buff > 256;
            next unless $buff ;
            chomp $buff;
            if ($type) {
                # must be a Real file type if protocol is http
                return 0 if $buff =~ /^http/ and $buff !~ /\.(ra|rm|rv|rmvb|smil)$/i;
                $et->SetFileType($type);
                return 1 if $fast3;
                undef $type;
            }
            # save URL or Text from RAM file
            my $tag = $buff =~ m{^[a-z]{3,4}://} ? 'url' : 'txt';
            $et->HandleTag($tagTablePtr, $tag, $buff);
        }
        return 1;
    }

    $et->SetFileType($type);
    return 1 if $fast3;
    SetByteOrder('MM');
    my $verbose = $et->Options('Verbose');
#
# Process RealAudio file
#
    if ($type eq 'RA') {
        ($vers, $extra) = unpack('x4nn', $buff);
        $tag = ".ra$vers";
        my $fpos = $raf->Tell();
        unless ($raf->Read($buff, 512)) {
            $et->Warn('Error reading audio header');
            return 1;
        }
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if ($verbose > 2) {
            $et->VerboseInfo($tag, $tagInfo, DataPt => \$buff, DataPos => $fpos);
        }
        if ($tagInfo) {
            my $subTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
            my %dirInfo = (
                DataPt   => \$buff,
                DataPos  => $fpos,
                DirLen   => length $buff,
                DirStart => 0,
            );
            $et->ProcessDirectory(\%dirInfo, $subTablePtr);
        } else {
            $et->Warn('Unsupported RealAudio version');
        }
        return 1;
    }
#
# Process RealMedia file
#
    # skip the rest of the RM header
    my $size = unpack('x4N', $buff);
    unless ($raf->Seek($size - 8, 1)) {
        $et->Warn('Error seeking in file');
        return 0;
    }

    # Process RealMedia chunks
    for (;;) {
        $raf->Read($buff, 10) == 10 or last;
        ($tag, $size, $vers) = unpack('a4Nn', $buff);
        last if $tag eq "\0\0\0\0";
        if ($verbose) {
            $et->VPrint(0, "$tag chunk ($size bytes):\n");
        } else {
            last if $tag eq 'DATA'; # stop normal parsing at DATA tag
        }
        if ($size & 0x80000000 or $size < 10) {
            $et->Warn('Bad chunk header');
            last;
        }
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if ($tagInfo and $$tagInfo{SubDirectory}) {
            my $fpos = $raf->Tell();
            unless ($raf->Read($buff, $size-10) == $size-10) {
                $et->Warn("Error reading $tag chunk");
                last;
            }
            if ($verbose > 2) {
                $et->VerboseInfo($tag, $tagInfo, DataPt => \$buff, DataPos => $fpos);
            }
            my $subTablePtr = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
            my %dirInfo = (
                DataPt   => \$buff,
                DataPos  => $fpos,
                DirLen   => length $buff,
                DirStart => 0,
            );
            if ($dirCount{$tag}) {
                $$et{SET_GROUP1} = '+' . ++$dirCount{$tag};
            } else {
                $dirCount{$tag} = 1;
            }
            $et->ProcessDirectory(\%dirInfo, $subTablePtr);
            delete $$et{SET_GROUP1};
            # keep track of stream MIME types
            my $mime = $$et{RealStreamMime};
            if ($mime) {
                delete $$et{RealStreamMime};
                $mime =~ s/\0.*//s;
                push @mimeTypes, $mime unless $mime =~ /^logical-/;
            }
        } else {
            unless ($raf->Seek($size-10, 1)) {
                $et->Warn('Error seeking in file');
                last;
            }
        }
    }
    # override MIMEType with stream MIME type if we only have one stream
    if (@mimeTypes == 1 and length $mimeTypes[0]) {
        $$et{VALUE}{MIMEType} = $mimeTypes[0];
        $et->VPrint(0, "  MIMEType = $mimeTypes[0]\n");
    }
#
# Process footer containing Real metadata and ID3 information
#
    if ($raf->Seek(-140, 2) and $raf->Read($buff, 12) == 12 and $buff =~ /^RMJE/) {
        my $metaSize = unpack('x8N', $buff);
        if ($raf->Seek(-$metaSize-12, 1) and
            $raf->Read($buff, $metaSize) == $metaSize and
            $buff =~ /^RJMD/)
        {
            my %dirInfo = (
                DataPt => \$buff,
                DataPos => $raf->Tell() - $metaSize,
                DirStart => 8,
                DirLen => length($buff) - 8,
            );
            my $tagTablePtr = GetTagTable('Image::ExifTool::Real::Metadata');
            $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        } else {
            $et->Warn('Bad metadata footer');
        }
        if ($raf->Seek(-128, 2) and $raf->Read($buff, 128) == 128 and $buff =~ /^TAG/) {
            $et->VPrint(0, "ID3v1:\n");
            my %dirInfo = (
                DataPt => \$buff,
                DirStart => 0,
                DirLen => length($buff),
            );
            my $tagTablePtr = GetTagTable('Image::ExifTool::ID3::v1');
            $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        }
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Real - Read Real audio/video meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains the routines required by Image::ExifTool to read meta
information in RealAudio (RA), RealMedia (RM, RV and RMVB) and RealMedia
Metafile (RAM and RPM) files.

=head1 NOTES

There must be a bug in the software that wrote the Metadata used in the test
file t/images/Real.rm because the TrackLyricsDataSize word is written
little-endian, but the Real format is big-endian.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.getid3.org/>

=item L<https://common.helixcommunity.org/nonav/2003/HCS_SDK_r5/htmfiles/rmff.htm>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Real Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

