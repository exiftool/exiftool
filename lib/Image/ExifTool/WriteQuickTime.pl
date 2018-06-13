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
    HEIC => { },    # can't currently write XMP to HEIC files
);

#------------------------------------------------------------------------------
# Check to see if path is current
# Inputs: 0) ExifTool object ref, 1) directory name
# Returns: true if current path is the root of the specified directory
sub IsCurPath($$)
{
    local $_;
    my ($et, $dir) = @_;
    $dir = $$et{DirMap}{$dir} and $dir eq $_ or last foreach reverse @{$$et{PATH}};
    return($dir and $dir eq 'MOV');
}

#------------------------------------------------------------------------------
# Write a series of QuickTime atoms from file or in memory
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: A) if dirInfo contains DataPt: new directory data
#          B) otherwise: true on success, 0 if a write error occurred
#             (true but sets an Error on a file format error)
sub WriteQuickTime($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my ($foundMDAT, $lengthChanged, @hold, $track);
    my $outfile = $$dirInfo{OutFile} or return 0;
    my $raf = $$dirInfo{RAF};
    my $dataPt = $$dirInfo{DataPt};
    my $dirName = $$dirInfo{DirName};
    my $parent = $$dirInfo{Parent};
    my $addDirs = $$et{ADD_DIRS};
    my $rtnVal = 1;

    if ($dataPt) {
        $raf = new File::RandomAccess($dataPt);
        my $outBuff = '';
        $outfile = \$outBuff;
    } else {
        return 0 unless $raf;
    }
    for (;;) {
        my ($hdr, $buff);
        my $n = $raf->Read($hdr, 8);
        unless ($n == 8) {
            if ($n == 4 and $hdr eq "\0\0\0\0") {
                # "for historical reasons" the udta is optionally terminated by 4 zeros (ref 1)
                # --> hold this terminator to the end
                push @hold, $hdr;
            } elsif ($n != 0) {
                $et->Error('File format error');
            }
            last;
        }
        my ($size, $tag) = unpack('Na4', $hdr);
        if ($size >= 8) {
            $size -= 8;
        } elsif ($size == 1) {
            # read the extended size
            $raf->Read($buff, 8) == 8 or $et->Error('Truncated extended atom'), last;
            $hdr .= $buff;
            my ($hi, $lo) = unpack('NN', $buff);
            $size = $hi * 4294967296 + $lo - 16;
            $size < 0 and $et->Error('Invalid extended atom size'), last;
        } elsif (not $size and not $dataPt) {
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
            } elsif (@hold) {
                $et->Error("Sorry, can't yet add tags to this type of QuickTime file");
                return $rtnVal;
            } else {
                # blindly copy the rest of the file
                Write($outfile, $hdr) or $rtnVal = 0;
                while ($raf->Read($buff, 65536)) {
                    Write($outfile, $buff) or $rtnVal = 0, last;
                }
                return $rtnVal;
            }
        } else {
            $et->Error('Invalid atom size');
            last;
        }

        # set flag if we have passed the 'mdat' atom
        if ($tag eq 'mdat') {
            if ($dataPt) {
                $et->Error("'mdat' not at top level");
            } elsif ($foundMDAT and $foundMDAT == 1 and $lengthChanged and
                not $et->Options('FixCorruptedMOV'))
            {
                $et->Error("Multiple 'mdat' blocks!  Can only edit existing tags");
                $foundMDAT = 2;
            } else {
                $foundMDAT = 1;
            }
        }

        # rewrite this atom
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if (defined $tagInfo and not $tagInfo) {
            my $n = $size < 256 ? $size : 256;
            unless ($raf->Read($buff, $n) == $n and $raf->Seek(-$n, 1)) {
                $et->Error("Read/seek error in $tag atom");
                last;
            }
            $tagInfo = $et->GetTagInfo($tagTablePtr, $tag, \$buff);
        }
        if ($tagInfo) {
            if ($$tagInfo{Unknown}) {
                undef $tagInfo;
            } elsif ($size > 100000000) {
                # limit maximum size of atom that we load into memory
                my $mb = $size / 0x100000;
                $et->Warn("Not editing metadata in $tag atom. $mb MB is too big");
                undef $tagInfo;
            }
        }
        if ($tagInfo and (not defined $$tagInfo{Writable} or $$tagInfo{Writable})) {
            # read the atom data
            $raf->Read($buff, $size) == $size or $et->Error("Error reading $tag data"), last;
            my $subdir = $$tagInfo{SubDirectory};
            my $newData;
            if ($subdir) {
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
                    HasData  => $$subdir{HasData},  # necessary?
                    Multi    => $$subdir{Multi},    # necessary?
                    OutFile  => $outfile,
                    InPlace  => 2, # (to write fixed-length XMP if possible)
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
                undef $newData if $$et{CHANGED} == $oldChanged; # don't change unless necessary
                $$et{CUR_WRITE_GROUP} = $oldWriteGroup;
                SetByteOrder('MM');
                # add back header if necessary
                if ($start and defined $newData and length $newData) {
                    $newData = substr($buff,0,$start) . $newData;
                }
                # the directory exists, so we don't need to add it
                delete $$addDirs{$subName} if IsCurPath($et, $subName);
            } else {
                # --> this is where individual QuickTime tags would be edited,
                # (this is such a can of worms, so don't implement this for now)
            }
            if (defined $newData) {
                my $len = length $newData;
                $len > 0x7ffffff7 and $et->Error("$tag to large to write"), last;
                if ($len == $size or $dataPt or $foundMDAT) {
                    # write the updated directory now (unless length is zero, or it is needed as padding)
                    if ($len or (not $dataPt and not $foundMDAT) or 
                        ($et->Options('FixCorruptedMOV') and $tag eq 'udta'))
                    {
                        Write($outfile, Set32u($len+8), $tag, $newData) or $rtnVal = 0, last;
                        $lengthChanged = 1 if $len != $size;
                    } else {
                        $lengthChanged = 1; # (we deleted this atom)
                    }
                    next;
                } else {
                    # bad things happen if 'mdat' atom is moved (eg. Adobe Bridge crashes --
                    # there are absolute offsets that point into mdat), so hold this atom
                    # and write it out later
                    if ($len) {
                        push @hold, Set32u($len+8), $tag, $newData;
                        $et->VPrint(0,"  Moving '${tag}' atom to after 'mdat'");
                    } else {
                        $et->VPrint(0,"  Freeing '${tag}' atom (and zeroing data)");
                    }
                    # write a 'free' atom here to keep 'mdat' at the same offset
                    substr($hdr, 4, 4) = 'free';
                    $buff = "\0" x length($buff);   # zero out old data
                }
            }
            # write out the existing atom (or 'free' padding)
            Write($outfile, $hdr, $buff) or $rtnVal = 0, last;
        } else {
            # write the unknown/large atom header
            Write($outfile, $hdr) or $rtnVal = 0, last;
            next unless $size;
            # copy the atom data
            my $result = Image::ExifTool::CopyBlock($raf, $outfile, $size);
            defined $result or $rtnVal = 0, last;
            $result or $et->Error("Truncated $tag atom"), last;
        }
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
                Write($outfile, $newHdr, $newData) or $rtnVal = 0;
                $lengthChanged = 1;
            }
            delete $$addDirs{$subName}; # add only once (must delete _after_ call to WriteDirectory())
        }
    }
    # write out any atoms that we are holding until the end
    Write($outfile, @hold) or $rtnVal = 0 if @hold;

    # issue minor error if we didn't find an 'mdat' atom
    # (we could duplicate atoms indefinitely through repeated editing if we
    #  held back some atoms here, so in this case it isn't a minor error)
    $dataPt or $foundMDAT or $et->Error('No mdat atom found', @hold ? 0 : 1);

    return $dataPt ? ($rtnVal ? $$outfile : undef) : $rtnVal;
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
            $et->Error("Can't currently write HEIC/HEIF files");
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

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::QuickTime(3pm)|Image::ExifTool::QuickTime>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
