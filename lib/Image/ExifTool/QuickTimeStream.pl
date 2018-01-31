#------------------------------------------------------------------------------
# File:         QuickTimeStream.pl
#
# Description:  Extract embedded information from QuickTime movie data
#
# Revisions:    2018-01-03 - P. Harvey Created
#
# References:   1) https://developer.apple.com/library/content/documentation/QuickTime/QTFF/QTFFChap3/qtff3.html#//apple_ref/doc/uid/TP40000939-CH205-SW130
#               2) http://sergei.nz/files/nvtk_mp42gpx.py
#------------------------------------------------------------------------------
package Image::ExifTool::QuickTime;

use strict;

# QuickTime data types that have ExifTool equivalents
# (ref https://developer.apple.com/library/content/documentation/QuickTime/QTFF/Metadata/Metadata.html#//apple_ref/doc/uid/TP40000939-CH1-SW35)
my %qtFmt = (
    0 => 'undef',
    1 => 'string', # (UTF-8)
    # 2 - UTF-16
    # 3 - shift-JIS
    # 4 - UTF-8 sort
    # 5 - UTF-16 sort
    # 13 - JPEG image
    # 14 - PNG image
    # 21 - signed integer (1,2,3 or 4 bytes)
    # 22 - unsigned integer (1,2,3 or 4 bytes)
    23 => 'float',
    24 => 'double',
    # 27 - BMP image
    # 28 - QuickTime atom
    65 => 'int8s',
    66 => 'int16s',
    67 => 'int32s',
    70 => 'float', # float[2] x,y
    71 => 'float', # float[2] width,height
    72 => 'float', # float[4] x,y,width,height
    74 => 'int64s',
    75 => 'int8u',
    76 => 'int16u',
    77 => 'int32u',
    78 => 'int64u',
    79 => 'float', # float[9] transform matrix
    80 => 'float', # float[8] face coordinates
);

# tags extracted from various QuickTime data streams
%Image::ExifTool::QuickTime::Stream = (
    GROUPS => { 2 => 'Location' },
    NOTES => q{
        Tags extracted from QuickTime movie data when the ExtractEmbedded option is
        used.
    },
    GPSLatitude  => { PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")' },
    GPSLongitude => { PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")' },
    GPSAltitude  => { PrintConv => '(sprintf("%.4f", $val) + 0) . " m"' }, # round to 4 decimals
    GPSAltitudeRef=>{ PrintConv => { 0 => 'Above Sea Level', 1 => 'Below Sea Level' } },
    GPSSpeed     => { PrintConv => 'sprintf("%.4f", $val) + 0' },   # round to 4 decimals
    GPSSpeedRef  => { PrintConv => { K => 'km/h', M => 'mph', N => 'knots' } },
    GPSTrack     => { PrintConv => 'sprintf("%.4f", $val) + 0' },    # round to 4 decimals
    GPSTrackRef  => { PrintConv => { M => 'Magnetic North', T => 'True North' } },
    GPSDateTime  => { PrintConv => '$self->ConvertDateTime($val)', Groups => { 2 => 'Time' } },
    Accelerometer=> { Notes => 'right/up/backward acceleration in units of g' },
    Text         => { Groups => { 2 => 'Other' } },
    TimeCode     => { Groups => { 2 => 'Other' } },
    SampleTime   => { Groups => { 2 => 'Other' }, PrintConv => 'ConvertDuration($val)', Notes => 'sample decoding time' },
    SampleDuration=>{ Groups => { 2 => 'Other' }, PrintConv => 'ConvertDuration($val)' },
#
# timed metadata decoded based on MetaFormat (format of 'meta' sample description)
#
    mebx => {
        Name => 'QuickTime_mebx',
        SubDirectory => {
            TagTable => 'Image::ExifTool::QuickTime::Keys',
            ProcessProc => \&ProcessMebx,
        },
    },
    gpmd => {
        Name => 'GoPro_gpmd',
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::GPMF' },
    },
    fdsc => {
        Name => 'GoPro_fdsc',
        Condition => '$$valPt =~ /^GPRO/',
        # (other types of "fdsc" samples aren't yet parsed: /^GP\x00/ and /^GP\x04/)
        SubDirectory => { TagTable => 'Image::ExifTool::GoPro::fdsc' },
    },
    rtmd => {
        Name => 'Sony_rtmd',
        SubDirectory => { TagTable => 'Image::ExifTool::Sony::rtmd' },
    },
);

#------------------------------------------------------------------------------
# Save information from keys in OtherSampleDesc directory for processing timed metadata
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# (ref "Timed Metadata Media" here:
#  https://developer.apple.com/library/content/documentation/QuickTime/QTFF/QTFFChap3/qtff3.html)
sub SaveMetaKeys($$$)
{
    local $_;
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = length $$dataPt;
    return 0 unless $dirLen > 8;
    my $pos = 0;
    my $verbose = $$et{OPTIONS}{Verbose};
    my $oldIndent = $$et{INDENT};
    my $ee = $$et{ee};
    $ee or $ee = $$et{ee} = { };

    $verbose and $et->VerboseDir($$dirInfo{DirName}, undef, $dirLen);

    # loop through metadata key table
    while ($pos + 8 < $dirLen) {
        my $size = Get32u($dataPt, $pos);
        my $id = substr($$dataPt, $pos+4, 4);
        my $end = $pos + $size;
        $end = $dirLen if $end > $dirLen;
        $pos += 8;
        my ($tagID, $format, $pid);
        if ($verbose) {
            $pid = PrintableTagID($id,1);
            $et->VPrint(0,"$oldIndent+ [Metdata Key entry, Local ID=$pid, $size bytes]\n");
            $$et{INDENT} .= '| ';
        }

        while ($pos + 4 < $end) {
            my $len = unpack("x${pos}N", $$dataPt);
            last if $len < 8 or $pos + $len > $end;
            my $tag = substr($$dataPt, $pos + 4, 4);
            $pos += 8;  $len -= 8;
            my $val = substr($$dataPt, $pos, $len);
            $pos += $len;
            my $str;
            if ($tag eq 'keyd') {
                ($tagID = $val) =~ s/^(mdta|fiel)com\.apple\.quicktime\.//;
                $tagID = "Tag_$val" unless $tagID;
                ($str = $val) =~ s/(.{4})/$1 / if $verbose;
            } elsif ($tag eq 'dtyp') {
                next if length $val < 4;
                if (length $val >= 4) {
                    my $ns = unpack('N', $val);
                    if ($ns == 0) {
                        length $val >= 8 or $et->Warn('Short dtyp data'), next;
                        $str = unpack('x4N',$val);
                        $format = $qtFmt{$str} || 'undef';
                    } elsif ($ns == 1) {
                        $str = substr($val, 4);
                        $format = 'undef';
                    } else {
                        $format = 'undef';
                    }
                    $str .= " ($format)" if $verbose and defined $str;
                }
            }
            if ($verbose > 1) {
                if (defined $str) {
                    $str =~ tr/\x00-\x1f\x7f-\xff/./;
                    $str = " = $str";
                } else {
                    $str = '';
                }
                $et->VPrint(1, $$et{INDENT}."- Tag '".PrintableTagID($tag)."' ($len bytes)$str\n");
                HexDump(\$val, undef, Prefix => $$et{INDENT}) if $verbose > 2;
            }
        }
        if (defined $tagID and defined $format) {
            if ($verbose) {
                my $t2 = PrintableTagID($tagID);
                $et->VPrint(0,"$$et{INDENT}Added Local ID $pid = $t2 ($format)\n");
            }
            $$ee{'keys'}{$id} = { TagID => $tagID, Format => $format };
        }
        $$et{INDENT} = $oldIndent;
    }
    return 1;
}

#------------------------------------------------------------------------------
# We found some tags for this sample, so set document number and save timing information
# Inputs: 0) ExifTool ref, 1) tag table ref, 2) sample time, 3) sample duration
sub FoundSomething($$$$)
{
    my ($et, $tagTablePtr, $time, $dur) = @_;
    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
    $et->HandleTag($tagTablePtr, SampleTime => $time) if defined $time;
    $et->HandleTag($tagTablePtr, SampleDuration => $dur) if defined $dur;
}

#------------------------------------------------------------------------------
# Exract embedded metadata from media samples
# Inputs: 0) ExifTool ref
# Notes: Also accesses ExifTool RAF*, SET_GROUP1, HandlerType, MetaFormat,
#        ee*, and avcC elements (* = must exist)
sub ProcessSamples($)
{
    my $et = shift;
    my ($raf, $ee) = @$et{qw(RAF ee)};
    my ($i, $buff, $pos, %parms, $hdrLen, $hdrFmt, @time, @dur, $oldIndent);

    return unless $ee;
    delete $$et{ee};    # use only once
    my ($start, $size) = @$ee{qw(start size)};
#
# determine sample start offsets from chunk offsets (stco) and sample-to-chunk table (stsc),
# and sample time/duration from time-to-sample (stts)
#
    unless ($start and $size) {
        return unless $size;
        my ($stco, $stsc, $stts) = @$ee{qw(stco stsc stts)};
        return unless $stco and $stsc and @$stsc;
        $start = [ ];
        my ($nextChunk, $iChunk) = (0, 1);
        my ($chunkStart, $startChunk, $samplesPerChunk, $descIdx, $timeCount, $timeDelta, $time);
        if ($stts and @$stts > 1) {
            $time = 0;
            $timeCount = shift @$stts;
            $timeDelta = shift @$stts;
        }
        my $ts = $$et{MediaTS} || 1;
        foreach $chunkStart (@$stco) {
            if ($iChunk >= $nextChunk and @$stsc) {
                ($startChunk, $samplesPerChunk, $descIdx) = @{shift @$stsc};
                $nextChunk = $$stsc[0][0] if @$stsc;
            }
            @$size < @$start + $samplesPerChunk and $et->WarnOnce('Sample size error'), return;
            my $sampleStart = $chunkStart;
            for ($i=0; ; ) {
                push @$start, $sampleStart;
                if (defined $time) {
                    until ($timeCount) {
                        if (@$stts < 2) {
                            undef $time;
                            last;
                        }
                        $timeCount = shift @$stts;
                        $timeDelta = shift @$stts;
                    }
                    push @time, $time / $ts;
                    push @dur, $timeDelta / $ts;
                    $time += $timeDelta;
                    --$timeCount;
                }
                # (eventually should use the description indices: $descIdx)
                last if ++$i >= $samplesPerChunk;
                $sampleStart += $$size[$#$start];
            }
            ++$iChunk;
        }
        @$start == @$size or $et->WarnOnce('Incorrect sample start/size count'), return;
    }
#
# extract and parse the sample data
#
    my $tagTablePtr = GetTagTable('Image::ExifTool::QuickTime::Stream');
    my $verbose = $et->Options('Verbose');
    my $type = $$et{HandlerType} || '';
    my $metaFormat = $$et{MetaFormat} || '';
    my $tell = $raf->Tell();

    if ($verbose) {
        $et->VPrint(0,"---- Extract Embedded ----\n");
        $oldIndent = $$et{INDENT};
        $$et{INDENT} = '';
        $parms{MaxLen} = $verbose == 3 ? 96 : 2048 if $verbose < 5;
    }
    # get required information from avcC box if parsing video data
    if ($type eq 'vide' and $$ee{avcC}) {
        $hdrLen = (Get8u(\$$ee{avcC}, 4) & 0x03) + 1;
        $hdrFmt = ($hdrLen == 4 ? 'N' : $hdrLen == 2 ? 'n' : 'C');
        require Image::ExifTool::H264;
    }
    # loop through all samples
    for ($i=0; $i<@$start and $i<@$size; ++$i) {

        # read the sample data
        my $size = $$size[$i];
        next unless $raf->Seek($$start[$i], 0) and $raf->Read($buff, $size) == $size;

        if ($type eq 'vide' and defined $hdrLen) {
            next if length($buff) <= $hdrLen;
            # scan through all NAL units and send them to ParseH264Video()
            for ($pos=0; ; ) {
                my $len = unpack("x$pos$hdrFmt", $buff);
                last if $pos + $hdrLen + $len > length($buff);
                my $tmp = "\0\0\0\x01" . substr($buff, $pos+$hdrLen, $len);
                Image::ExifTool::H264::ParseH264Video($et, \$tmp);
                $pos += $hdrLen + $len;
                last if $pos + $hdrLen >= length($buff);
            }
            next;
        }
        if ($verbose > 1) {
            my $hdr = $$et{SET_GROUP1} ? "$$et{SET_GROUP1} Type='${type}' Format='${metaFormat}'" : "Type='${type}'";
            $et->VPrint(1, "${hdr}, Sample ".($i+1).' of '.scalar(@$start)." ($size bytes)\n");
            $parms{Addr} = $$start[$i];
            HexDump(\$buff, undef, %parms) if $verbose > 2;
        }
        if ($type eq 'text') {

            FoundSomething($et, $tagTablePtr, $time[$i], $dur[$i]);
            unless ($buff =~ /^\$BEGIN/) {
                # remove ending "encd" box if it exists
                $buff =~ s/\0\0\0\x0cencd\0\0\x01\0$// and $size -= 12;
                # cameras such as the CanonPowerShotN100 store ASCII time codes with a
                # leading 2-byte integer giving the length of the string
                # (and chapter names start with a 2-byte integer too)
                if ($size >= 2 and unpack('n',$buff) == $size - 2) {
                    next if $size == 2;
                    $buff = substr($buff,2);
                }
                $et->HandleTag($tagTablePtr, Text => $buff);
                next;
            }
            while ($buff =~ /\$(\w+)([^\$]*)/g) {
                my ($tag, $dat) = ($1, $2);
                if ($tag eq 'GPRMC' and $dat =~ /^,(\d{2})(\d{2})(\d+(\.\d*)?),A?,(\d*?)(\d{1,2}\.\d+),([NS]),(\d*?)(\d{1,2}\.\d+),([EW]),(\d*\.?\d*),(\d*\.?\d*),(\d{2})(\d{2})(\d+)/) {
                    $et->HandleTag($tagTablePtr, GPSLatitude  => (($5 || 0) + $6/60) * ($7 eq 'N' ? 1 : -1));
                    $et->HandleTag($tagTablePtr, GPSLongitude => (($8 || 0) + $9/60) * ($10 eq 'E' ? 1 : -1));
                    if (length $11) {
                        $et->HandleTag($tagTablePtr, GPSSpeed => $11);
                        $et->HandleTag($tagTablePtr, GPSSpeedRef => 'N');
                    }
                    if (length $12) {
                        $et->HandleTag($tagTablePtr, GPSTrack => $11);
                        $et->HandleTag($tagTablePtr, GPSTrackRef => 'T');
                    }
                    my $year = $15 + ($15 >= 70 ? 1900 : 2000);
                    my $str = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d', $year, $14, $13, $1, $2, $3);
                    $et->HandleTag($tagTablePtr, GPSDateTime => $str);
                } elsif ($tag eq 'BEGINGSENSOR' and $dat =~ /^:([-+]\d+\.\d+):([-+]\d+\.\d+):([-+]\d+\.\d+)/) {
                    $et->HandleTag($tagTablePtr, Accelerometer => "$1 $2 $3");
                } elsif ($tag eq 'TIME' and $dat =~ /^:(\d+)/) {
                    $et->HandleTag($tagTablePtr, TimeCode => $1 / ($$et{MediaTS} || 1));
                } elsif ($tag eq 'BEGIN') {
                    $et->HandleTag($tagTablePtr, Text => $dat) if length $dat;
                } elsif ($tag ne 'END') {
                    $et->HandleTag($tagTablePtr, Text => "\$$tag$dat");
                }
            }

        } elsif ($type eq 'meta') {

            if ($$tagTablePtr{$metaFormat}) {
                my $tagInfo = $et->GetTagInfo($tagTablePtr, $metaFormat, \$buff);
                if ($tagInfo) {
                    FoundSomething($et, $tagTablePtr, $time[$i], $dur[$i]);
                    $$et{ee} = $ee; # need ee information for 'keys'
                    $et->HandleTag($tagTablePtr, $metaFormat, undef,
                        DataPt  => \$buff,
                        Base    => $$start[$i],
                        TagInfo => $tagInfo,
                    );
                    delete $$et{ee};
                }
            } elsif ($verbose) {
                $et->VPrint(0, "Unknown meta format ($metaFormat)");
            }

        } elsif ($type eq 'gps ') {

            # decode Novatek GPS data (ref 2)
            next unless $buff =~ /^....freeGPS /s and length $buff >= 92;
            my ($hr,$min,$sec,$yr,$mon,$day,$active,$latRef,$lonRef) = unpack('x48V6a1a1a1', $buff);
            next unless $active eq 'A'; # ignore bad GPS fixes
            my ($lat,$lon,$spd,$trk) = unpack('f*', pack('L*', unpack('x76V4', $buff)));
            FoundSomething($et, $tagTablePtr, $time[$i], $dur[$i]);
            # lat/long are in DDDmm.mmmm format
            my $deg = int($lat / 100);
            $lat = $deg + (($lat - $deg * 100) / 60) * ($latRef eq 'S' ? -1 : 1);
            $deg = int($lon / 100);
            $lon = $deg + (($lon - $deg * 100) / 60) * ($lonRef eq 'W' ? -1 : 1);
            $et->HandleTag($tagTablePtr, GPSLatitude => $lat);
            $et->HandleTag($tagTablePtr, GPSLongitude => $lon);
            $et->HandleTag($tagTablePtr, GPSSpeed => $spd);
            $et->HandleTag($tagTablePtr, GPSSpeedRef => 'N');
            $et->HandleTag($tagTablePtr, GPSTrack => $trk); #PH (NC, could be GPSImageDirection)
            $et->HandleTag($tagTablePtr, GPSTrackRef => 'T');
            $yr += $yr >= 70 ? 1900 : 2000;
            $et->HandleTag($tagTablePtr, GPSDateTime =>
                sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d',$yr,$mon,$day,$hr,$min,$sec));
        }
    }
    if ($verbose) {
        $$et{INDENT} = $oldIndent;
        $et->VPrint(0,"--------------------------\n");
    }
    # clean up
    $raf->Seek($tell, 0); # restore original file position
    $$et{DOC_NUM} = 0;
    $$et{HandlerType} = $$et{HanderDesc} = '';
}

#------------------------------------------------------------------------------
# Extract embedded information referenced from a track
# Inputs: 0) ExifTool ref, 1) tag name, 2) data ref
sub ParseTag($$$)
{
    local $_;
    my ($et, $tag, $dataPt) = @_;
    my $dataLen = length $$dataPt;

    if ($tag eq 'stsz' or $tag eq 'stz2' and $dataLen > 12) {
        # read the sample sizes
        my ($sz, $num) = unpack('x4N2', $$dataPt);
        my $size = $$et{ee}{size} = [ ];
        if ($tag eq 'stsz') {
            if ($sz == 0) {
                @$size = ReadValue($dataPt, 12, 'int32u', $num, $dataLen-12);
            } else {
                @$size = ($sz) x $num;
            }
        } else {
            $sz &= 0xff;
            if ($sz == 4) {
                my @tmp = ReadValue($dataPt, 12, 'int8u', int(($num+1)/2), $dataLen-12);
                foreach (@tmp) {
                    push @$size, $_ >> 4;
                    push @$size, $_ & 0xff;
                }
            } elsif ($sz == 8 || $sz == 16) {
                @$size = ReadValue($dataPt, 12, "int${sz}u", $num, $dataLen-12);
            }
        }
    } elsif ($tag eq 'stco' or $tag eq 'co64' and $dataLen > 8) {
        # read the chunk offsets
        my $num = unpack('x4N', $$dataPt);
        my $stco = $$et{ee}{stco} = [ ];
        @$stco = ReadValue($dataPt, 8, $tag eq 'stco' ? 'int32u' : 'int64u', $num, $dataLen-8);
    } elsif ($tag eq 'stsc' and $dataLen > 8) {
        # read the sample-to-chunk box
        my $num = unpack('x4N', $$dataPt);
        if ($dataLen >= 8 + $num * 12) {
            my ($i, @stsc);
            for ($i=0; $i<$num; ++$i) {
                # list of (first-chunk, samples-per-chunk, sample-description-index)
                push @stsc, [ unpack('x'.(8+$i*12).'N3', $$dataPt) ];
            }
            $$et{ee}{stsc} = \@stsc;
        }
    } elsif ($tag eq 'stts' and $dataLen > 8) {
        # read the time-to-sample box
        my $num = unpack('x4N', $$dataPt);
        if ($dataLen >= 8 + $num * 8) {
            $$et{ee}{stts} = [ unpack('x8N'.($num*2), $$dataPt) ];
        }
    } elsif ($tag eq 'avcC') {
        # read the AVC compressor configuration
        $$et{ee}{avcC} = $$dataPt if $dataLen >= 7;  # (minimum length is 7)
    } elsif ($tag eq 'gps ' and $dataLen > 8) {
        # decode Novatek 'gps ' box (ref 2)
        my $num = Get32u($dataPt, 4);
        $num = int(($dataLen - 8) / 8) if $num * 8 + 8 > $dataLen;
        my $start = $$et{ee}{start} = [ ];
        my $size = $$et{ee}{size} = [ ];
        my $i;
        for ($i=0; $i<$num; $i+=2) {
            push @$start, Get32u($dataPt, 8 + $i * 8);
            push @$size, Get32u($dataPt, 12 + $i * 8);
        }
        $$et{HandlerType} = $tag;   # fake handler type
        ProcessSamples($et);        # we have all we need to process sample data now
    }
}

#------------------------------------------------------------------------------
# Process QuickTime 'mebx' timed metadata
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# - uses tag ID keys stored in the ExifTool ee data member by a previous call to SaveMetaKeys
sub ProcessMebx($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $ee = $$et{ee} or return 0;
    return 0 unless $$ee{'keys'};
    my $dataPt = $$dirInfo{DataPt};

    # parse using information from 'keys' table (eg. Apple iPhone7+ hevc 'Core Media Data Handler')
    $et->VerboseDir('mebx', undef, length $$dataPt);
    my $pos = 0;
    while ($pos + 8 < length $$dataPt) {
        my $len = Get32u($dataPt, $pos);
        last if $len < 8 or $pos + $len > length $$dataPt;
        my $id = substr($$dataPt, $pos+4, 4);
        my $info = $$ee{'keys'}{$id};
        if ($info) {
            my $tag = $$info{TagID};
            unless ($$tagTablePtr{$tag}) {
                next unless $tag =~ /^[-\w.]+$/;
                # create info for tags with reasonable id's
                my $name = $tag;
                $name =~ s/[-.](.)/\U$1/g;
                AddTagToTable($tagTablePtr, $tag, { Name => ucfirst($name) });
            }
            my $val = ReadValue($dataPt, $pos+8, $$info{Format}, undef, $len-8);
            $et->HandleTag($tagTablePtr, $tag, $val,
                DataPt => $dataPt,
                Base   => $$dirInfo{Base},
                Start  => $pos + 8,
                Size   => $len - 8,
            );
        } else {
            $et->WarnOnce('No key information for mebx ID ' . PrintableTagID($id,1));
        }
        $pos += $len;
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::QuickTime - Extract embedded information from movie data

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool::QuickTime.

=head1 DESCRIPTION

This file contains routines used by Image::ExifTool to extract embedded
information like GPS tracks from MOV and MP4 movie data.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item Lhttps://developer.apple.com/library/content/documentation/QuickTime/QTFF/QTFFChap3/qtff3.html#//apple_ref/doc/uid/TP40000939-CH205-SW130>

=item L<http://sergei.nz/files/nvtk_mp42gpx.py>

=back

=head1 SEE ALSO

L<Image::ExifTool::QuickTime(3pm)|Image::ExifTool::QuickTime>,
L<Image::ExifTool::TagNames/QuickTime Stream Tags>,
L<Image::ExifTool::TagNames/GoPro GPMF Tags>,
L<Image::ExifTool::TagNames/Sony rtmd Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

