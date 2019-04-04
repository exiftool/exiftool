#------------------------------------------------------------------------------
# File:         WriteQuickTime.pl
#
# Description:  Write XMP to QuickTime (MOV and MP4) files
#
# Revisions:    2013-10-29 - P. Harvey Created
#------------------------------------------------------------------------------
package Image::ExifTool::QuickTime;

use strict;

# map for adding directories to QuickTime-format files
my %movMap = (
    # MOV (no 'ftyp', or 'ftyp'='qt  ') -> 'moov'-'udta'-'XMP_'
    XMP      => 'UserData',
    UserData => 'Movie',
    Movie    => 'MOV',
);
my %mp4Map = (
    # MP4 ('ftyp' compatible brand 'mp41', 'mp42' or 'f4v ') -> top level 'uuid'
    XMP => 'MOV',
);
my %dirMap = (
    MOV => \%movMap,
    MP4 => \%mp4Map,
    HEIC => \%mp4Map,
);

#------------------------------------------------------------------------------
# Format GPSCoordinates for writing
# Inputs: 0) PrintConv value
# Returns: ValueConv value
sub PrintInvGPSCoordinates($)
{
    my ($val, $et) = @_;
    my @v = split /, */, $val;
    if (@v == 2 or @v == 3) {
        my $below = ($v[2] and $v[2] =~ /below/i);
        $v[0] = Image::ExifTool::GPS::ToDegrees($v[0], 1);
        $v[1] = Image::ExifTool::GPS::ToDegrees($v[1], 1);
        $v[2] = Image::ExifTool::ToFloat($v[2]) * ($below ? -1 : 1) if @v == 3;
        return "@v";
    }
    return $val if $val =~ /^([-+]\d+(\.\d*)?){2,3}(CRS.*)?$/; # already in ISO6709 format?
    return undef;
}

#------------------------------------------------------------------------------
# Convert GPS coordinates back to ISO6709 format
# Inputs: 0) ValueConv value
# Returns: ISO6709 coordinates
sub ConvInvISO6709($)
{
    local $_;
    my $val = shift;
    my @a = split ' ', $val;
    if (@a == 2 or @a == 3) {
        foreach (@a) {
            Image::ExifTool::IsFloat($_) or return undef;
            $_ = '+' . $_ if $_ >= 0;
        }
        return join '', @a;
    }
    return $val if $val =~ /^([-+]\d+(\.\d*)?){2,3}(CRS.*)?$/; # already in ISO6709 format?
    return undef;
}

#------------------------------------------------------------------------------
# Check to see if path is current
# Inputs: 0) ExifTool ref, 1) directory name
# Returns: true if current path is the root of the specified directory
sub IsCurPath($$)
{
    local $_;
    my ($et, $dir) = @_;
    $dir = $$et{DirMap}{$dir} and $dir eq $_ or last foreach reverse @{$$et{PATH}};
    return($dir and $dir eq 'MOV');
}

#------------------------------------------------------------------------------
# Handle offsets in iloc (ItemLocation) atom when writing
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) data ref, 3) output buffer ref
# Returns: true on success
# Notes: see also ParseItemLocation() in QuickTime.pm
# (variable names with underlines correspond to names in ISO14496-12)
sub Handle_iloc($$$$)
{
    my ($et, $dirInfo, $dataPt, $outfile) = @_;
    my ($i, $j, $num, $pos);

    my $off = $$dirInfo{ChunkOffset};
    my $len = length $$dataPt;
    return 0 if $len < 8;
    my $ver = Get8u($dataPt, 0);
    my $siz = Get16u($dataPt, 4);
    my $noff = ($siz >> 12);
    my $nlen = ($siz >> 8) & 0x0f;
    my $nbas = ($siz >> 4) & 0x0f;
    my $nind = $siz & 0x0f;
    my %ok = ( 0 => 1, 4 => 1, 8 => 8 );
    return 0 unless $ok{$noff} and $ok{$nlen} and $ok{$nbas} and $ok{$nind};
    # piggy-back on existing code to fix up stco/co64 4/8-byte offsets
    my $tag = $noff == 4 ? 'stcoiloc' : 'co64iloc';
    if ($ver < 2) {
        $num = Get16u($dataPt, 6);
        $pos = 8;
    } else {
        return 0 if $len < 10;
        $num = Get32u($dataPt, 6);
        $pos = 10;
    }
    for ($i=0; $i<$num; ++$i) {
        if ($ver < 2) {
            return 0 if $pos + 2 > $len;
            # $id = Get16u($dataPt, $pos);
            $pos += 2;
        } else {
            return 0 if $pos + 4 > $len;
            # $id = Get32u($dataPt, $pos);
            $pos += 4;
        }
        my $constructionMethod; # (absolute offset only if this is 0)
        if ($ver == 1 or $ver == 2) {
            return 0 if $pos + 2 > $len;
            $constructionMethod = Get16u($dataPt, $pos) & 0x0f;
            $pos += 2;
        }
        return 0 if $pos + 2 > $len;
        my $drefIdx = Get16u($dataPt, $pos);
        my ($constOff, @offBase, @offItem, $minOffset);
        if ($drefIdx) {
            if ($$et{QtDataRef} and $$et{QtDataRef}[$drefIdx - 1]) {
                my $dref = $$et{QtDataRef}[$drefIdx - 1];
                # these offsets are constant unless the data is in this file
                $constOff = 1 unless $$dref[1] == 1 and $$dref[0] ne 'rsrc';
            } else {
                $et->Error("No data reference for iloc entry $i");
                return 0;
            }
        }
        $pos += 2;
        # get base offset and save its location if in this file
        my $base_offset = GetVarInt($dataPt, $pos, $nbas);
        if ($base_offset and not $constOff) {
            my $tg = ($nbas == 4 ? 'stco' : 'co64') . 'iloc';
            push @offBase, [ $tg, length($$outfile) + 8 + $pos - $nbas, $nbas ];
        }
        return 0 if $pos + 2 > $len;
        my $ext_num = Get16u($dataPt, $pos);
        $pos += 2;
        my $listStartPos = $pos;
        # run through the item list to get offset locations and the minimum offset in this file
        for ($j=0; $j<$ext_num; ++$j) {
            $pos += $nind if $ver == 1 or $ver == 2;
            my $extent_offset = GetVarInt($dataPt, $pos, $noff);
            return 0 unless defined $extent_offset;
            unless ($constOff) {
                push @offItem, [ $tag, length($$outfile) + 8 + $pos - $noff, $noff ] if $noff;
                $minOffset = $extent_offset if not defined $minOffset or $minOffset > $extent_offset;
            }
            return 0 if $pos + $nlen > length $$dataPt;
            $pos += $nlen;
        }
        # decide whether to fix up the base offset or individual item offsets
        # (adjust the one that is larger)
        if (defined $minOffset and $minOffset > $base_offset) {
            $off or $off = $$dirInfo{ChunkOffset} = [ ];
            push @$off, @offItem;
        } else {
            push @$off, @offBase;
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Write a series of QuickTime atoms from file or in memory
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: A) if dirInfo contains DataPt: new directory data
#          B) otherwise: true on success, 0 if a write error occurred
#             (true but sets an Error on a file format error)
sub WriteQuickTime($$$)
{
    local $_;
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;
    my ($mdat, @mdat, $track, $outBuff, $co, $term, $err);
    my $outfile = $$dirInfo{OutFile} || return 0;
    my $raf = $$dirInfo{RAF};       # (will be null for lower-level atoms)
    my $dataPt = $$dirInfo{DataPt}; # (will be null for top-level atoms)
    my $dirName = $$dirInfo{DirName};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $parent = $$dirInfo{Parent};
    my $addDirs = $$et{ADD_DIRS};
    my ($rtnVal, $rtnErr) = $dataPt ? (undef, undef) : (1, 0);

    if ($dataPt) {
        $raf = new File::RandomAccess($dataPt);
    } else {
        return 0 unless $raf;
    }
    # initialize ItemList key directory count
    $$et{KeyCount} = 0 unless defined $$et{KeyCount};

    # use buffered output for everything but 'mdat' atoms
    $outBuff = '';
    $outfile = \$outBuff;

    $raf->Seek($dirStart, 1) if $dirStart;  # skip header if it exists

    for (;;) {      # loop through all atoms at this level
        my ($hdr, $buff);
        my $n = $raf->Read($hdr, 8);
        unless ($n == 8) {
            if ($n == 4 and $hdr eq "\0\0\0\0") {
                # "for historical reasons" the udta is optionally terminated by 4 zeros (ref 1)
                # --> hold this terminator to the end
                $term = $hdr;
            } elsif ($n != 0) {
                $et->Error('File format error');
            }
            last;
        }
        my $size = Get32u(\$hdr, 0) - 8;    # (size includes 8-byte header)
        my $tag = substr($hdr, 4, 4);
        if ($size == -7) {
            # read the extended size
            $raf->Read($buff, 8) == 8 or $et->Error('Truncated extended atom'), last;
            $hdr .= $buff;
            my ($hi, $lo) = unpack('NN', $buff);
            if ($hi or $lo > 0x7fffffff) {
                if ($hi > 0x7fffffff) {
                    $et->Error('Invalid atom size');
                    last;
                } elsif (not $et->Options('LargeFileSupport')) {
                    $et->Error('End of processing at large atom (LargeFileSupport not enabled)');
                    last;
                }
            }
            $size = $hi * 4294967296 + $lo - 16;
            $size < 0 and $et->Error('Invalid extended atom size'), last;
        } elsif ($size == -8 and not $dataPt) {
            # size of zero is only valid for top-level atom, and
            # indicates the atom extends to the end of file
            if (not $raf->{FILE_PT}) {
                # get file size from image in memory
                $size = length ${$$raf{BUFF_PT}};
            } else {
                $size = -s $$raf{FILE_PT};
            }
            if ($size and ($size -= $raf->Tell()) >= 0 and $size <= 0x7fffffff) {
                Set32u($size + 8, \$hdr, 0);
            } else {
                # (save as an mdat to write later; with zero end position to copy rest of file)
                push @mdat, [ $raf->Tell(), 0, $hdr ];
                last;
            }
        } elsif ($size < 0) {
            $et->Error('Invalid atom size');
            last;
        }

        # keep track of 'mdat' atom locations for writing later
        if ($tag eq 'mdat') {
            if ($dataPt) {
                $et->Error("'mdat' not at top level");
                last;
            }
            push @mdat, [ $raf->Tell(), $raf->Tell() + $size, $hdr ];
            $raf->Seek($size, 1) or $et->Error("Seek error in mdat atom"), return $rtnVal;
            next;
        } elsif ($tag eq 'cmov') {
            $et->Error("Can't yet write compressed movie metadata");
            return $rtnVal;
        } elsif ($tag eq 'wide') {
            next;   # drop 'wide' tag
        }

        # read the atom data
        if (not $size) {
            $buff = '';
        } elsif ($size > 100000000) {
            my $mb = int($size / 0x100000 + 0.5);
            $tag = PrintableTagID($tag,3);
            $et->Error("'${tag}' atom is too large for rewriting ($mb MB)");
            return $rtnVal;
        } elsif ($raf->Read($buff, $size) != $size) {
            $tag = PrintableTagID($tag,3);
            $et->Error("Truncated $tag atom");
            return $rtnVal;
        }

        # if this atom stores offsets, save its location so we can fix up offsets later
        # (are there any other atoms that may store absolute file offsets?)
        if ($tag =~ /^(stco|co64|iloc|mfra)$/) {
            # (note that we only need to do this if the movie data is stored in this file)
            my $flg = $$et{QtDataFlg};
            if ($tag eq 'mfra') {
                $et->Error("Can't yet handle movie fragments when writing");
                return $rtnVal;
            } elsif ($tag eq 'iloc') {
                Handle_iloc($et, $dirInfo, \$buff, $outfile) or $et->Error('Error parsing iloc atom');
            } elsif (not $flg) {
                my $grp = $$et{CUR_WRITE_GROUP} || $parent;
                $et->Error("Can't locate data reference to update offsets for $grp");
                return $rtnVal;
            } elsif ($flg == 3) {
                $et->Error("Can't write files with mixed internal/external movie data");
                return $rtnVal;
            } elsif ($flg == 1) {
                # must update offsets since the data is in this file
                my $off = $$dirInfo{ChunkOffset};
                $off or $off = $$dirInfo{ChunkOffset} = [ ];
                push @$off, [ $tag, length($$outfile) + length($hdr), $size ];
            }
        }

        # rewrite this atom
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag, \$buff);

        # call write hook if it exists
        &{$$tagInfo{WriteHook}}($buff,$et) if $tagInfo and $$tagInfo{WriteHook};

        # allow numerical tag ID's
        unless ($tagInfo) {
            my $id = $$et{KeyCount} . '.' . unpack('N', $tag);
            $tagInfo = $et->GetTagInfo($tagTablePtr, $id);
        }

        undef $tagInfo if $tagInfo and $$tagInfo{Unknown};

        if ($tagInfo and (not defined $$tagInfo{Writable} or $$tagInfo{Writable})) {
            my $subdir = $$tagInfo{SubDirectory};
            my ($newData, @chunkOffset);

            if ($subdir) {  # process atoms in this container from a buffer in memory

                my $subName = $$subdir{DirName} || $$tagInfo{Name};
                my $start = $$subdir{Start} || 0;
                my $base = ($$dirInfo{Base} || 0) + $raf->Tell() - $size;
                my $dPos = 0;
                my $hdrLen = $start;
                if ($$subdir{Base}) {
                    my $localBase = eval $$subdir{Base};
                    $dPos -= $localBase;
                    $base -= $dPos;
                    # get length of header before base offset
                    $hdrLen -= $localBase if $localBase <= $hdrLen;
                }
                my %subdirInfo = (
                    Parent   => $dirName,
                    DirName  => $subName,
                    DataPt   => \$buff,
                    DataLen  => $size,
                    DataPos  => $dPos,
                    DirStart => $start,
                    DirLen   => $size - $start,
                    Base     => $base,
                    HasData  => $$subdir{HasData},
                    Multi    => $$subdir{Multi},    # necessary?
                    OutFile  => $outfile,
                    # initialize array to hold details about chunk offset table
                    # (each entry has 3 items: 0=atom type, 1=table offset, 2=table size)
                    ChunkOffset => \@chunkOffset,
                );
                # pass the header pointer if necessary (for EXIF IFD's
                # where the Base offset is at the end of the header)
                if ($hdrLen and $hdrLen < $size) {
                    my $header = substr($buff,0,$hdrLen);
                    $subdirInfo{HeaderPtr} = \$header;
                }
                SetByteOrder('II') if $$subdir{ByteOrder} and $$subdir{ByteOrder} =~ /^Little/;
                my $oldWriteGroup = $$et{CUR_WRITE_GROUP};
                if ($subName eq 'Track') {
                    $track or $track = 0;
                    $$et{CUR_WRITE_GROUP} = 'Track' . (++$track);
                }
                my $subTable = GetTagTable($$subdir{TagTable});
                # demote non-QuickTime errors to warnings
                $$et{DemoteErrors} = 1 unless $$subTable{GROUPS}{0} eq 'QuickTime';
                my $oldChanged = $$et{CHANGED};
                $newData = $et->WriteDirectory(\%subdirInfo, $subTable);
                if ($$et{DemoteErrors}) {
                    # just copy existing subdirectory a non-quicktime error occurred
                    $$et{CHANGED} = $oldChanged if $$et{DemoteErrors} > 1;
                    delete $$et{DemoteErrors};
                }
                $$et{CUR_WRITE_GROUP} = $oldWriteGroup;
                SetByteOrder('MM');
                # add back header if necessary
                if ($start and defined $newData and length $newData) {
                    $newData = substr($buff,0,$start) . $newData;
                    $$_[1] += $start foreach @chunkOffset;
                }
                # the directory exists, so we don't need to add it
                delete $$addDirs{$subName} if IsCurPath($et, $subName);

            } else {    # modify existing QuickTime tags in various formats

                my $nvHash = $et->GetNewValueHash($tagInfo);
                if ($nvHash) {
                    my ($val, $len, $lang, $type, $flags, $ctry, $charsetQuickTime);
                    my $format = $$tagInfo{Format};
                    my $hasData = ($$dirInfo{HasData} and $buff =~ /\0...data\0/s);
                    if ($hasData) {
                        my $pos = 0;
                        for (;;) {
                            last if $pos + 16 > $size;
                            ($len, $type, $flags, $ctry, $lang) = unpack("x${pos}Na4Nnn", $buff);
                            last if $pos + $len > $size;
                            if ($type eq 'data' and $len >= 16) {
                                $pos += 16;
                                $len -= 16;
                                $val = substr($buff, $pos, $len);
                                # decode value (see QuickTime.pm for an explanation)
                                if ($stringEncoding{$flags}) {
                                    $val = $et->Decode($val, $stringEncoding{$flags});
                                    $val =~ s/\0$// unless $$tagInfo{Binary};
                                } else {
                                    $format = $$tagInfo{Format} || QuickTimeFormat($flags, $len);
                                    $val = ReadValue(\$val, 0, $format, $$tagInfo{Count}, $len) if $format;
                                }
                                if ($et->IsOverwriting($nvHash, $val)) {
                                    my $newVal = $et->GetNewValue($nvHash);
                                    $newVal = '' unless defined $newVal;    # (can't yet delete tags)
                                    my $prVal = $newVal;
                                    if ($stringEncoding{$flags}) {
                                        # handle all string formats
                                        $newVal = $et->Encode($newVal, $stringEncoding{$flags});
                                    } elsif ($format) {
                                        $newVal = WriteValue($newVal, $format);
                                    }
                                    if (defined $newVal) {
                                        ++$$et{CHANGED};
                                        $et->VerboseValue("- QuickTime:$$tagInfo{Name}", $val);
                                        $et->VerboseValue("+ QuickTime:$$tagInfo{Name}", $prVal);
                                        $newData = substr($buff, 0, $pos-16) unless defined $newData;
                                        $newData .= pack('Na4Nnn', length($newVal)+16, $type, $flags, $ctry, $lang);
                                        $newData .= $newVal;
                                    } elsif (defined $newData) {
                                        $newData .= substr($buff, $pos-16, $len+16);
                                    }
                                }
                            } elsif (defined $newData) {
                                $newData .= substr($buff, $pos, $len);
                            }
                            $pos += $len;
                        }
                        $newData .= substr($buff, $pos) if defined $newData and $pos < $size;
                        undef $val; # (already constructed $newData)
                    } elsif ($format) {
                        $val = ReadValue(\$buff, 0, $format, undef, $size);
                    } elsif (($tag =~ /^\xa9/ or $$tagInfo{IText}) and $size >= 4) {
                        ($len, $lang) = unpack('nn', $buff);
                        $len -= 4 if 4 + $len > $size; # (see QuickTime.pm for explanation)
                        $len = $size - 4 if $len > $size - 4 or $len < 0;
                        $val = substr($buff, 4, $len);
                        if ($lang < 0x400) {
                            $charsetQuickTime = $et->Options('CharsetQuickTime');
                            $val = $et->Decode($val, $charsetQuickTime);
                        } else {
                            my $enc = $val=~s/^\xfe\xff// ? 'UTF16' : 'UTF8';
                            $val = $et->Decode($val, $enc);
                        }
                    }
                    if (defined $val and $et->IsOverwriting($nvHash, $val)) {
                        $newData = $et->GetNewValue($nvHash);
                        $newData = '' unless defined $newData;  # (can't yet delete tags)
                        ++$$et{CHANGED};
                        $et->VerboseValue("- QuickTime:$$tagInfo{Name}", $val);
                        $et->VerboseValue("+ QuickTime:$$tagInfo{Name}", $newData);
                        # add back necessary header and encode as necessary
                        if (defined $lang) {
                            $newData = $et->Encode($newData, $lang < 0x400 ? $charsetQuickTime : 'UTF8');
                            $newData = pack('nn', length($newData), $lang) . $newData;
                        }
                    }
                }
            }
            # write the new atom if it was modified
            if (defined $newData) {
                my $len = length $newData;
                $len > 0x7ffffff7 and $et->Error("$$tagInfo{Name} to large to write"), last;
                next unless $len;
                # maintain pointer to chunk offsets if necessary
                if (@chunkOffset) {
                    $$dirInfo{ChunkOffset} or $$dirInfo{ChunkOffset} = [ ];
                    $$_[1] += 8 + length $$outfile foreach @chunkOffset;
                    push @{$$dirInfo{ChunkOffset}}, @chunkOffset;
                }
                # write the updated directory now (unless length is zero, or it is needed as padding)
                Write($outfile, Set32u($len+8), $tag, $newData) or $rtnVal=$rtnErr, $err=1, last;
                next;
            }
        }
        # keep track of data references in this track
        if ($tag eq 'dinf') {
            $$et{QtDataRef} = [ ];  # initialize list of data references
        } elsif ($parent eq 'DataInfo' and length($buff) >= 4) {
            # save data reference type and version/flags
            push @{$$et{QtDataRef}}, [ $tag, Get32u(\$buff,0) ];
        } elsif ($tag eq 'stsd' and length($buff) >= 8) {
            my $n = Get32u(\$buff, 4);      # get number of sample descriptions in table
            my ($pos, $flg) = (8, 0);
            my $i;
            for ($i=0; $i<$n; ++$i) {       # loop through sample descriptions
                last if $pos + 16 > length($buff);
                my $siz = Get32u(\$buff, $pos);
                last if $pos + $siz > length($buff);
                my $drefIdx = Get16u(\$buff, $pos + 14);
                my $drefTbl = $$et{QtDataRef};
                if (not $drefIdx) {
                    $flg |= 0x01;   # in this file if data reference index is 0 (if like iloc)
                } elsif ($drefTbl and $$drefTbl[$drefIdx-1]) {
                    my $dref = $$drefTbl[$drefIdx-1];
                    # $flg = 0x01-in this file, 0x02-in some other file
                    $flg |= ($$dref[1] == 1 and $$dref[0] ne 'rsrc') ? 0x01 : 0x02;
                } else {
                    my $grp = $$et{CUR_WRITE_GROUP} || $parent;
                    $et->Error("No data reference for $grp sample description $i");
                    return $rtnVal;
                }
                $pos += $siz;
            }
            $$et{QtDataFlg} = $flg;
        }
        # copy the existing atom
        Write($outfile, $hdr, $buff) or $rtnVal=$rtnErr, $err=1, last;
    }
    # add new directories at this level if necessary
    if (exists $$et{EDIT_DIRS}{$dirName}) {
        # get a hash of tagInfo references to add to this directory
        my $dirs = $et->GetAddDirHash($tagTablePtr, $dirName);
        # make sorted list of new tags to be added
        my @addTags = sort keys(%$dirs);
        my $tag;
        foreach $tag (@addTags) {
            my $tagInfo = $$dirs{$tag};
            my $subdir = $$tagInfo{SubDirectory} or next;
            my $subName = $$subdir{DirName} || $$tagInfo{Name};
            # QuickTime hierarchy is complex, so check full directory path before adding
            next unless IsCurPath($et, $subName);
            my $buff = '';  # write from scratch
            my %subdirInfo = (
                Parent   => $dirName,
                DirName  => $subName,
                DataPt   => \$buff,
                DirStart => 0,
                OutFile  => $outfile,
            );
            my $subTable = GetTagTable($$subdir{TagTable});
            my $newData = $et->WriteDirectory(\%subdirInfo, $subTable);
            if ($newData and length($newData) <= 0x7ffffff7) {
                my $uuid = '';
                # add atom ID if necessary (obtain from Condition expression)
                if ($$subdir{Start}) {
                    my $cond = $$tagInfo{Condition};
                    $uuid = eval qq("$1") if $cond and $cond =~ m{=~\s*\/\^(.*)/};
                    length($uuid) == $$subdir{Start} or $et->Error('Internal UUID error');
                }
                my $newHdr = Set32u(8+length($newData)+length($uuid)) . $tag . $uuid;
                Write($outfile, $newHdr, $newData) or $rtnVal=$rtnErr, $err=1;
            }
            delete $$addDirs{$subName}; # add only once (must delete _after_ call to WriteDirectory())
        }
    }
    # write out any necessary terminator
    Write($outfile, $term) or $rtnVal=$rtnErr, $err=1 if $term;

    # return now if writing subdirectory
    return $err ? undef : $$outfile if $dataPt;

    # issue minor error if we didn't find an 'mdat' atom
    my $off = $$dirInfo{ChunkOffset} || [ ];
    if (not @mdat) {
        if (@$off) {
            $et->Error('Movie data referenced but not found');
            return $rtnVal;
        }
        $et->Warn('No movie data', 1);
    }

    # determine our new mdat positions
    # (0=old pos, 1=old end, 2=mdat header, 3=new pos)
    my $pos = length $$outfile;
    foreach $mdat (@mdat) {
        $pos += length $$mdat[2];
        $$mdat[3] = $pos;
        $pos += $$mdat[1] - $$mdat[0];
    }

    # fix up offsets for new mdat position(s)
    foreach $co (@$off) {
        my ($type, $ptr, $len) = @$co;
        $type =~ /^(stco|co64)(.*)$/ or $et->Error('Internal error fixing offsets'), last;
        my $siz = $1 eq 'co64' ? 8 : 4;
        my ($n, $tag);
        if ($2) {   # is this an offset in an iloc atom?
            $n = 1;
            $type = $1;
            $tag = $2;
        } else {    # this is an stco or co84 atom
            next if $len < 8;
            $n = Get32u($outfile, $ptr + 4);    # get number of entries in table
            $ptr += 8;
            $len -= 8;
            $tag = $1;
        }
        my $end = $ptr + $n * $siz;
        $end > $ptr + $len and $et->Error("Invalid $tag table"), return $rtnVal;
        for (; $ptr<$end; $ptr+=$siz) {
            my $ok;
            my $val = $type eq 'co64' ? Get64u($outfile, $ptr) : Get32u($outfile, $ptr);
            foreach $mdat (@mdat) {
                next unless $val >= $$mdat[0] and $val <= $$mdat[1]; # (have seen == $$mdat[1])
                $val += $$mdat[3] - $$mdat[0];
                if ($val < 0) {
                    $et->Error("Error fixing up $tag offset");
                    return $rtnVal;
                }
                if ($type eq 'co64') {
                    Set64u($val, $outfile, $ptr);
                } elsif ($val <= 0xffffffff) {
                    Set32u($val, $outfile, $ptr);
                } else {
                    $et->Error("Can't yet promote $tag offset to 64 bits");
                    return $rtnVal;
                }
                $ok = 1;
                last;
            }
            unless ($ok) {
                $et->Error("Chunk offset in $tag atom is outside movie data");
                return $rtnVal;
            }
        }
    }

    # switch back to actual output file
    $outfile = $$dirInfo{OutFile};  

    # write the metadata
    Write($outfile, $outBuff) or $rtnVal = 0;

    # write the movie data
    foreach $mdat (@mdat) {
        $raf->Seek($$mdat[0], 0) or $et->Error('Seek error'), last;
        Write($outfile, $$mdat[2]) or $rtnVal = 0;  # write mdat header
        if ($$mdat[1]) {
            my $result = Image::ExifTool::CopyBlock($raf, $outfile, $$mdat[1] - $$mdat[0]);
            defined $result or $rtnVal = 0, last;
            $result or $et->Error("Truncated mdat atom"), last;
        } else {
            # mdat continues to end of file
            my $buff;
            while ($raf->Read($buff, 65536)) {
                Write($outfile, $buff) or $rtnVal = 0, last;
            }
        }
    }

    return $rtnVal;
}

#------------------------------------------------------------------------------
# Write QuickTime-format MOV/MP4 file
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid QuickTime file,
#          or -1 if a write error occurred
sub WriteMOV($$)
{
    my ($et, $dirInfo) = @_;
    $et or return 1;
    my $raf = $$dirInfo{RAF} or return 0;
    my ($buff, $ftype);

    # read the first atom header
    return 0 unless $raf->Read($buff, 8) == 8;
    my ($size, $tag) = unpack('Na4', $buff);
    return 0 if $size < 8 and $size != 1;

    # validate the file format
    my $tagTablePtr = GetTagTable('Image::ExifTool::QuickTime::Main');
    return 0 unless $$tagTablePtr{$tag};

    # determine the file type
    if ($tag eq 'ftyp' and $size >= 12 and $size < 100000 and
        $raf->Read($buff, $size-8) == $size-8 and
        $buff !~ /^(....)+(qt  )/s)
    {
        # file is MP4 format if 'ftyp' exists without 'qt  ' as a compatible brand
        if ($buff =~ /^(heic|mif1|msf1|heix|hevc|hevx)/) {
            $ftype = 'HEIC';
        } else {
            $ftype = 'MP4';
        }
    } else {
        $ftype = 'MOV';
    }
    $et->SetFileType($ftype); # need to set "FileType" tag for a Condition
    $et->InitWriteDirs($dirMap{$ftype}, 'XMP');
    $$et{DirMap} = $dirMap{$ftype};     # need access to directory map when writing
    SetByteOrder('MM');
    $raf->Seek(0,0);

    # write the file
    $$dirInfo{Parent} = '';
    $$dirInfo{DirName} = 'MOV';
    return WriteQuickTime($et, $dirInfo, $tagTablePtr) ? 1 : -1;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::WriteQuickTime.pl - Write XMP to QuickTime (MOV and MP4) files

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool::QuickTime.

=head1 DESCRIPTION

This file contains routines used by ExifTool to write XMP metadata to
QuickTime-based file formats like MOV and MP4.

=head1 AUTHOR

Copyright 2003-2019, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::QuickTime(3pm)|Image::ExifTool::QuickTime>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
