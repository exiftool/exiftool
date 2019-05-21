#------------------------------------------------------------------------------
# File:         WriteQuickTime.pl
#
# Description:  Write XMP to QuickTime (MOV and MP4) files
#
# Revisions:    2013-10-29 - P. Harvey Created
#------------------------------------------------------------------------------
package Image::ExifTool::QuickTime;

use strict;

# maps for adding metadata to various QuickTime-based file types
my %movMap = (
    # MOV (no 'ftyp', or 'ftyp'='qt  ') -> XMP in 'moov'-'udta'-'XMP_'
    QuickTime => 'ItemList',
    ItemList  => 'Meta',
    Meta      => 'UserData',
    XMP       => 'UserData',
    UserData  => 'Movie',
    Movie     => 'MOV',
);
my %mp4Map = (
    # MP4 ('ftyp' compatible brand 'mp41', 'mp42' or 'f4v ') -> XMP at top level
    QuickTime => 'ItemList',
    ItemList  => 'Meta',
    Meta      => 'UserData',
    UserData  => 'Movie',
    Movie     => 'MOV',
    XMP       => 'MOV',
);
my %heicMap = (
    # HEIC ('ftyp' compatible brand 'heic' or 'mif1') -> XMP/EXIF in top level 'meta'
    Meta         => 'MOV',
    ItemInformation => 'Meta',
    ItemPropertyContainer => 'Meta',
    XMP          => 'ItemInformation',
    EXIF         => 'ItemInformation',
    ICC_Profile  => 'ItemPropertyContainer',
    IFD0         => 'EXIF',
    IFD1         => 'IFD0',
    ExifIFD      => 'IFD0',
    GPS          => 'IFD0',
    SubIFD       => 'IFD0',
    GlobParamIFD => 'IFD0',
    PrintIM      => 'IFD0',
    InteropIFD   => 'ExifIFD',
    MakerNotes   => 'ExifIFD',
);
my %cr3Map = (
    # CR3 ('ftyp' compatible brand 'crx ') -> XMP at top level
    Movie     => 'MOV',
    XMP       => 'MOV',
   'UUID-Canon'=>'Movie',
    ExifIFD   => 'UUID-Canon',
    IFD0      => 'UUID-Canon',
    GPS       => 'UUID-Canon',
    #MakerNoteCanon => 'UUID-Canon', # (doesn't yet work -- goes into ExifIFD instead)
);
my %dirMap = (
    MOV  => \%movMap,
    MP4  => \%mp4Map,
    CR3  => \%cr3Map,
    HEIC => \%heicMap,
);

# convert ExifTool Format to QuickTime type
my %qtFormat = (
   'undef' => 0x00,  string => 0x01,
    int8s  => 0x15,  int16s => 0x15,  int32s => 0x15,
    int8u  => 0x16,  int16u => 0x16,  int32u => 0x16,
    float  => 0x17,  double => 0x18,
);
my $undLang = 0x55c4;   # numeric code for default ('und') language

# mark UserData tags that don't have ItemList counterparts as Preferred
# (and for now, set Writable to 0 for any tag with a RawConv)
{
    my $itemList = \%Image::ExifTool::QuickTime::ItemList;
    my $userData = \%Image::ExifTool::QuickTime::UserData;
    my (%pref, $tag);
    foreach $tag (TagTableKeys($itemList)) {
        my $tagInfo = $$itemList{$tag};
        if (ref $tagInfo ne 'HASH') {
            next if ref $tagInfo;
            $tagInfo = $$userData{$tag} = { Name => $tagInfo };
        }
        $$tagInfo{Writable} = 0 if $$tagInfo{RawConv};
        next if $$tagInfo{Avoid} or defined $$tagInfo{Preferred} and not $$tagInfo{Preferred};
        $pref{$$tagInfo{Name}} = 1;
    }
    foreach $tag (TagTableKeys($userData)) {
        my $tagInfo = $$userData{$tag};
        if (ref $tagInfo ne 'HASH') {
            next if ref $tagInfo;
            $tagInfo = $$userData{$tag} = { Name => $tagInfo };
        }
        $$tagInfo{Writable} = 0 if $$tagInfo{RawConv};
        next if $$tagInfo{Avoid} or defined $$tagInfo{Preferred} or $pref{$$tagInfo{Name}};
        $$tagInfo{Preferred} = 1;
    }
}

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
# Handle offsets in iloc (ItemLocation) atom when writing (ref ISO 14496-12:2015 pg.79)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) data ref, 3) output buffer ref
# Returns: true on success
# Notes: see also ParseItemLocation() in QuickTime.pm
# (variable names with underlines correspond to names in ISO 14496-12)
sub Handle_iloc($$$$)
{
    my ($et, $dirInfo, $dataPt, $outfile) = @_;
    my ($i, $j, $num, $pos, $id);

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
    my $tag = $noff == 4 ? 'stco_iloc' : 'co64_iloc';
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
            $id = Get16u($dataPt, $pos);
            $pos += 2;
        } else {
            return 0 if $pos + 4 > $len;
            $id = Get32u($dataPt, $pos);
            $pos += 4;
        }
        my ($constOff, @offBase, @offItem, $minOffset);
        if ($ver == 1 or $ver == 2) {
            return 0 if $pos + 2 > $len;
            # offsets are absolute only if ConstructionMethod is 0, otherwise
            # the relative offsets are constant as far as we are concerned
            $constOff = Get16u($dataPt, $pos) & 0x0f;
            $pos += 2;
        }
        return 0 if $pos + 2 > $len;
        my $drefIdx = Get16u($dataPt, $pos);
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
            my $tg = ($nbas == 4 ? 'stco' : 'co64') . '_iloc';
            push @offBase, [ $tg, length($$outfile) + 8 + $pos - $nbas, $nbas, 0, $id ];
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
                push @offItem, [ $tag, length($$outfile) + 8 + $pos - $noff, $noff, 0, $id ] if $noff;
                $minOffset = $extent_offset if not defined $minOffset or $minOffset > $extent_offset;
            }
            return 0 if $pos + $nlen > length $$dataPt;
            $pos += $nlen;
        }
        # decide whether to fix up the base offset or individual item offsets
        # (adjust the one that is larger)
        if (defined $minOffset and $minOffset > $base_offset) {
            $off or $off = $$dirInfo{ChunkOffset} = [ ];
            $$_[3] = $base_offset foreach @offItem;
            push @$off, @offItem;
        } else {
            $$_[3] = $minOffset foreach @offBase;
            push @$off, @offBase;
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Get localized version of tagInfo hash
# Inputs: 0) tagInfo hash ref, 1) language code (eg. "fra-FR")
# Returns: new tagInfo hash ref, or undef if invalid or no language code
sub GetLangInfo($$)
{
    my ($tagInfo, $langCode) = @_;
    return undef unless $langCode;
    # only allow alternate language tags in lang-alt lists
    my $writable = $$tagInfo{Writable};
    $writable = $$tagInfo{Table}{WRITABLE} unless defined $writable;
    return undef unless $writable;
    $langCode =~ tr/_/-/;   # RFC 3066 specifies '-' as a separator
    my $langInfo = Image::ExifTool::GetLangInfo($tagInfo, $langCode);
    return $langInfo;
}

#------------------------------------------------------------------------------
# validate raw values for writing
# Inputs: 0) ExifTool ref, 1) tagInfo hash ref, 2) raw value ref
# Returns: error string or undef (and possibly changes value) on success
sub CheckQTValue($$$)
{
    my ($et, $tagInfo, $valPtr) = @_;
    my $format = $$tagInfo{Format} || $$tagInfo{Table}{FORMAT};
    return undef unless $format;
    return Image::ExifTool::CheckValue($valPtr, $format, $$tagInfo{Count});
}

#------------------------------------------------------------------------------
# Format QuickTime value for writing
# Inputs: 0) ExifTool ref, 1) value ref, 2) Format (or undef)
# Returns: Flags for QT data type, and reformats value as required
sub FormatQTValue($$;$)
{
    my ($et, $valPt, $format) = @_;
    my $flags;
    if ($format and $format ne 'string') {
        $$valPt = WriteValue($$valPt, $format);
        $flags = $qtFormat{$format} || 0;
    } elsif ($$valPt =~ /^\xff\xd8\xff/) {
        $flags = 0x0d;  # JPG
    } elsif ($$valPt =~ /^(\x89P|\x8aM|\x8bJ)NG\r\n\x1a\n/) {
        $flags = 0x0e;  # PNG
    } elsif ($$valPt =~ /^BM.{15}\0/s) {
        $flags = 0x1b;  # BMP
    } else {
        $flags = 0x01;  # UTF8
        $$valPt = $et->Encode($$valPt, 'UTF8');
    }
    return $flags;
}

#------------------------------------------------------------------------------
# Set variable-length integer (used by WriteItemInfo)
# Inputs: 0) value, 1) integer size in bytes (0, 4 or 8),
# Returns: packed integer
sub SetVarInt($$)
{
    my ($val, $n) = @_;
    if ($n == 4) {
        return Set32u($val);
    } elsif ($n == 8) {
        return Set64u($val);
    }
    return '';
}

#------------------------------------------------------------------------------
# Write ItemInformation in HEIC files
# Inputs: 0) ExifTool ref, 1) dirInfo ref (with BoxPos entry), 2) output buffer ref
# Returns: mdat edit list ref (empty if nothing changed)
sub WriteItemInfo($$$)
{
    my ($et, $dirInfo, $outfile) = @_;
    my $boxPos = $$dirInfo{BoxPos};
    my $raf = $$et{RAF};
    my $items = $$et{ItemInfo};
    my (%did, @mdatEdit, $name);

    return () unless $items and $raf;

    # extract information from EXIF/XMP metadata items
    if ($items and $raf) {
        my $curPos = $raf->Tell();
        my $primary = $$et{PrimaryItem} || 0;
        my $id;
        foreach $id (sort { $a <=> $b } keys %$items) {
            my $item = $$items{$id};
            # only edit primary EXIF/XMP metadata
            next unless $$item{RefersTo} and $$item{RefersTo}{$primary};
            my $type = $$item{ContentType} || $$item{Type} || next;
            # get ExifTool name for this item
            $name = { Exif => 'EXIF', 'application/rdf+xml' => 'XMP' }->{$type};
            next unless $name;  # only care about EXIF and XMP
            next unless $$et{EDIT_DIRS}{$name};
            $did{$name} = 1;    # set flag to prevent creating this metadata
            my ($warn, $extent, $buff, @edit);
            $warn = 'Missing iloc box' unless $$boxPos{iloc};
            $warn = "No Extents for $type item" unless $$item{Extents} and @{$$item{Extents}};
            $warn = "Can't currently decode encoded $type metadata" if $$item{ContentEncoding};
            $warn = "Can't currently decode protected $type metadata" if $$item{ProtectionIndex};
            $warn = "Can't currently extract $type with construction method $$item{ConstructionMethod}" if $$item{ConstructionMethod};
            $warn = "$type metadata is not this file" if $$item{DataReferenceIndex};
            $warn and $et->Warn($warn), next;
            my $base = $$item{BaseOffset} || 0;
            my $val = '';
            foreach $extent (@{$$item{Extents}}) {
                $val .= $buff if defined $buff;
                my $pos = $$extent[1] + $base;
                if ($$extent[2]) {
                    $raf->Seek($pos, 0) or last;
                    $raf->Read($buff, $$extent[2]) or last;
                } else {
                    $buff = '';
                }
                push @edit, [ $pos, $pos + $$extent[2] ];   # replace or delete this if changed
            }
            next unless defined $buff;
            $buff = $val . $buff if length $val;
            my ($hdr, $subTable, $proc);
            if ($name eq 'EXIF') {
                $hdr = "\0\0\0\x06Exif\0\0";
                $subTable = GetTagTable('Image::ExifTool::Exif::Main');
                $proc = \&Image::ExifTool::WriteTIFF;
            } else {
                $hdr = '';
                $subTable = GetTagTable('Image::ExifTool::XMP::Main');
            }
            my %dirInfo = (
                DataPt   => \$buff,
                DataLen  => length $buff,
                DirStart => length $hdr,
                DirLen   => length($buff) - length $hdr,
            );
            my $changed = $$et{CHANGED};
            my $newVal = $et->WriteDirectory(\%dirInfo, $subTable, $proc);
            if (defined $newVal and $changed ne $$et{CHANGED} and
                # nothing changed if deleting an empty directory
                ($dirInfo{DirLen} or length $newVal))
            {
                $newVal = $hdr . $newVal if length $hdr and length $newVal;
                $edit[0][2] = \$newVal;     # replace the old chunk with the new data
                $edit[0][3] = $id;          # mark this chunk with the item ID
                push @mdatEdit, @edit;
                # update item extent_length
                my $n = length $newVal;
                foreach $extent (@{$$item{Extents}}) {
                    my ($nlen, $lenPt) = @$extent[3,4];
                    if ($nlen == 8) {
                        Set64u($n, $outfile, $$boxPos{iloc}[0] + 8 + $lenPt);
                    } elsif ($n <= 0xffffffff) {
                        Set32u($n, $outfile, $$boxPos{iloc}[0] + 8 + $lenPt);
                    } else {
                        $et->Error("Can't yet promote iloc offset to 64 bits");
                        return ();
                    }
                    $n = 0;
                }
                if (@{$$item{Extents}} != 1) {
                    $et->Error("Can't yet handle $name in multiple parts. Please submit sample for testing");
                }
            }
            $$et{CHANGED} = $changed;   # (will set this later if successful in editing mdat)
        }
        $raf->Seek($curPos, 0);     # seek back to original position
    }
    # add necessary metadata types if they didn't already exist
    my ($countNew, %add, %usedID);
    foreach $name ('EXIF','XMP') {
        next if $did{$name} or not $$et{ADD_DIRS}{$name};
        unless ($$boxPos{iinf} and $$boxPos{iref} and $$boxPos{iloc}) {
            $et->Warn("Can't create $name. Missing expected box");
            last;
        }
        my $primary = $$et{PrimaryItem};
        unless (defined $primary) {
            $et->Warn("Can't create $name. No primary item reference");
            last;
        }
        my $buff = '';
        my ($hdr, $subTable, $proc);
        if ($name eq 'EXIF') {
            $hdr = "\0\0\0\x06Exif\0\0";
            $subTable = GetTagTable('Image::ExifTool::Exif::Main');
            $proc = \&Image::ExifTool::WriteTIFF;
        } else {
            $hdr = '';
            $subTable = GetTagTable('Image::ExifTool::XMP::Main');
        }
        my %dirInfo = (
            DataPt   => \$buff,
            DataLen  => 0,
            DirStart => 0,
            DirLen   => 0,
        );
        my $changed = $$et{CHANGED};
        my $newVal = $et->WriteDirectory(\%dirInfo, $subTable, $proc);
        if (defined $newVal and $changed ne $$et{CHANGED}) {
            $newVal = $hdr . $newVal if length $hdr;
            # add new infe to iinf
            $add{iinf} = $add{iref} = $add{iloc} = '' unless defined $add{iinf};
            my ($type, $mime);
            if ($name eq 'XMP') {
                $type = "mime\0";
                $mime = "application/rdf+xml\0";
            } else {
                $type = "Exif\0";
                $mime = '';
            }
            my $id = 1;
            ++$id while $$items{$id} or $usedID{$id};   # find next unused item ID
            my $n = length($type) + length($mime) + 16;
            if ($id < 0x10000) {
                $add{iinf} .= pack('Na4CCCCnn', $n, 'infe', 2, 0, 0, 1, $id, 0) . $type . $mime;
            } else {
                $n += 2;
                $add{iinf} .= pack('Na4CCCCNn', $n, 'infe', 3, 0, 0, 1, $id, 0) . $type . $mime;
            }
            # add new cdsc to iref
            my $irefVer = Get8u($outfile, $$boxPos{iref}[0] + 8);
            if ($irefVer) {
                $add{iref} .= pack('Na4NnN', 18, 'cdsc', $id, 1, $primary);
            } else {
                $add{iref} .= pack('Na4nnn', 14, 'cdsc', $id, 1, $primary);
            }
            # add new entry to iloc table (see ISO14496-12:2015 pg.79)
            my $ilocVer = Get8u($outfile, $$boxPos{iloc}[0] + 8);
            my $siz = Get16u($outfile, $$boxPos{iloc}[0] + 12);  # get size information
            my $noff = ($siz >> 12);
            my $nlen = ($siz >> 8) & 0x0f;
            my $nbas = ($siz >> 4) & 0x0f;
            my $nind = $siz & 0x0f;
            my $p;
            if ($ilocVer == 0) {
                # set offset to 0 as flag that this is a new idat chunk being added
                $p = length($add{iloc}) + 4 + $nbas + 2;
                $add{iloc} .= pack('nn',$id,0) . SetVarInt(0,$nbas) . Set16u(1) .
                            SetVarInt(0,$noff) . SetVarInt(length($newVal),$nlen);
            } elsif ($ilocVer == 1) {
                $p = length($add{iloc}) + 6 + $nbas + 2 + $nind;
                $add{iloc} .= pack('nnn',$id,0,0) . SetVarInt(0,$nbas) . Set16u(1) . SetVarInt(0,$nind) .
                            SetVarInt(0,$noff) . SetVarInt(length($newVal),$nlen);
            } elsif ($ilocVer == 2) {
                $p = length($add{iloc}) + 8 + $nbas + 2 + $nind;
                $add{iloc} .= pack('Nnn',$id,0,0) . SetVarInt(0,$nbas) . Set16u(1) . SetVarInt(0,$nind) .
                            SetVarInt(0,$noff) . SetVarInt(length($newVal),$nlen);
            } else {
                $et->Warn("Can't create $name. Unsupported iloc version $ilocVer");
                last;
            }
            # add new ChunkOffset entry to update this new offset
            my $off = $$dirInfo{ChunkOffset} or $et->Warn('Internal error. Missing ChunkOffset'), last;
            my $newOff;
            if ($noff == 4) {
                $newOff = [ 'stco_iloc', $$boxPos{iloc}[0] + $$boxPos{iloc}[1] + $p, $noff, 0, $id ];
            } elsif ($noff == 8) {
                $newOff = [ 'co64_iloc', $$boxPos{iloc}[0] + $$boxPos{iloc}[1] + $p, $noff, 0, $id ];
            } else {
                $et->Warn("Can't create $name. Invalid iloc offset size");
                last;
            }
            # add directory as a new mdat chunk
            push @$off, $newOff;
            push @mdatEdit, [ 0, 0, \$newVal, $id ];
            $usedID{$id} = 1;
            $countNew = ($countNew || 0) + 1;
            $$et{CHANGED} = $changed; # set this later if successful in editing mdat
        }
    }
    if ($countNew) {
        # insert new entries into iinf, iref and iloc boxes
        my $added = 0;
        my $tag;
        foreach $tag (sort { $$boxPos{$a}[0] <=> $$boxPos{$b}[0] } keys %$boxPos) {
            next unless $add{$tag};
            my $pos = $$boxPos{$tag}[0] + $added;
            my $n = Get32u($outfile, $pos);
            Set32u($n + length($add{$tag}), $outfile, $pos);        # increase box size
            if ($tag eq 'iinf') {
                my $iinfVer = Get8u($outfile, $pos + 8);
                if ($iinfVer == 0) {
                    $n = Get16u($outfile, $pos + 12);
                    Set16u($n + $countNew, $outfile, $pos + 12);    # incr count
                } else {
                    $n = Get32u($outfile, $pos + 12);
                    Set32u($n + $countNew, $outfile, $pos + 12);    # incr count
                }
            } elsif ($tag eq 'iref') {
                # nothing more to do
            } elsif ($tag eq 'iloc') {
                my $ilocVer = Get8u($outfile, $pos + 8);
                if ($ilocVer < 2) {
                    $n = Get16u($outfile, $pos + 14);
                    Set16u($n + $countNew, $outfile, $pos + 14);    # incr count
                } else {
                    $n = Get32u($outfile, $pos + 14);
                    Set32u($n + $countNew, $outfile, $pos + 14);    # incr count
                }
                # must also update pointer locations in this box
                if ($added) {
                    $$_[1] += $added foreach @{$$dirInfo{ChunkOffset}};
                }
            } else {
                next;
            }
            # add new entries to this box
            substr($$outfile, $pos + $$boxPos{$tag}[1], 0) = $add{$tag};
            $added += length $add{$tag};    # positions are shifted by length of new entries
        }
    }
    delete $$et{ItemInfo};
    return @mdatEdit ? \@mdatEdit : undef;
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
    $et or return 1;    # allow dummy access to autoload this package
    my ($mdat, @mdat, @mdatEdit, $edit, $track, $outBuff, $co, $term, $err);
    my (%langTags, $keysTags, $canCreate, %didTag, $delGrp, %boxPos);
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

    # get hash of new tags to add to this directory if this is the proper place for them
    my $curPath = join '-', @{$$et{PATH}};
    my ($dir, $writePath) = ($dirName, $dirName);
    $writePath = "$dir-$writePath" while defined($dir = $$et{DirMap}{$dir});
    my $delQt = $$et{DEL_GROUP}{QuickTime};
    if ($curPath eq $writePath) {
        $canCreate = 1;
        $delGrp = $delQt || $$et{DEL_GROUP}{$dirName};
        $et->VPrint(0, "  Deleting $dirName tags\n") if $delGrp;
    }
    my $newTags = $et->GetNewTagInfoHash($tagTablePtr);
    # make lookup of language tags for this ID
    foreach (keys %$newTags) {
        next unless $$newTags{$_}{LangCode} and $$newTags{$_}{SrcTagInfo};
        my $id = $$newTags{$_}{SrcTagInfo}{TagID};
        $langTags{$id} = { } unless $langTags{$id};
        $langTags{$id}{$_} = $$newTags{$_};
    }

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
        my $size = Get32u(\$hdr, 0) - 8;    # (atom size without 8-byte header)
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
            # (save in mdat list to write later; with zero end position to copy rest of file)
            push @mdat, [ $raf->Tell(), 0, $hdr ];
            last;
        } elsif ($size < 0) {
            if ($$tagTablePtr{VARS}{IGNORE_BAD_ATOMS} and $dataPt) {
                # ignore bad atom and just copy the rest of this directory
                $buff = substr($$dataPt, $raf->Tell());
                Write($outfile, $hdr, $buff) or $rtnVal=$rtnErr, $err=1;
                last;
            } else {
                $et->Error('Invalid atom size');
                last;
            }
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
        if ($tag =~ /^(stco|co64|iloc|mfra|gps )$/) {
            # (note that we only need to do this if the movie data is stored in this file)
            my $flg = $$et{QtDataFlg};
            if ($tag eq 'mfra') {
                $et->Error("Can't yet handle movie fragments when writing");
                return $rtnVal;
            } elsif ($tag eq 'iloc') {
                Handle_iloc($et, $dirInfo, \$buff, $outfile) or $et->Error('Error parsing iloc atom');
            } elsif ($tag eq 'gps ') {
                # (only care about the 'gps ' box in 'moov')
                if ($$dirInfo{DirID} and $$dirInfo{DirID} eq 'moov' and length $buff > 8) {
                    my $off = $$dirInfo{ChunkOffset};
                    $off or $off = $$dirInfo{ChunkOffset} = [ ];
                    my $num = Get32u(\$buff, 4);
                    $num = int((length($buff) - 8) / 8) if $num * 8 + 8 > length($buff);
                    my $i;
                    for ($i=0; $i<$num; ++$i) {
                        push @$off, [ 'stco_gps ', length($$outfile) + length($hdr) + 8 + $i * 8, 4 ];
                    }
                }
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

        # allow numerical tag ID's (ItemList entries defined by Keys)
        unless ($tagInfo) {
            my $id = $$et{KeyCount} . '.' . unpack('N', $tag);
            $tagInfo = $et->GetTagInfo($tagTablePtr, $id);
        }
        # delete all ItemList/UserData tags if deleting group
        if ($delGrp and $dirName =~ /^(ItemList|UserData)$/) {
            ++$$et{CHANGED};
            next;
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
                    Name     => $$tagInfo{Name},
                    DirID    => $tag,
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
                    # (each entry has 3-5 items: 0=atom type, 1=table offset, 2=table size,
                    #  3=optional base offset, 4=optional item ID)
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
                $newData = $et->WriteDirectory(\%subdirInfo, $subTable, $$subdir{WriteProc});
                if ($$et{DemoteErrors}) {
                    # just copy existing subdirectory if a non-quicktime error occurred
                    $$et{CHANGED} = $oldChanged if $$et{DemoteErrors} > 1;
                    delete $$et{DemoteErrors};
                }
                if (defined $newData and not length $newData and $$tagTablePtr{PERMANENT}) {
                    # do nothing if trying to delete tag from a PERMANENT table
                    $$et{CHANGED} = $oldChanged;
                    undef $newData;
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
                # get new value from Keys source tag if necessary
                if (not $nvHash and $$tagInfo{KeysInfo}) {
                    $nvHash = $et->GetNewValueHash($$tagInfo{KeysInfo});
                    # may be writing this as a language tag, so fill in $langTags for this ID
                    unless ($keysTags) {
                        $keysTags =  $et->GetNewTagInfoHash(GetTagTable('Image::ExifTool::QuickTime::Keys'));
                    }
                    foreach (keys %$keysTags) {
                        next unless $$keysTags{$_}{SrcTagInfo};
                        next unless $$keysTags{$_}{SrcTagInfo} eq $$tagInfo{KeysInfo};
                        $langTags{$tag} = { } unless $langTags{$tag};
                        $langTags{$tag}{$_} = $$keysTags{$_};
                    }
                }
                if ($nvHash or $langTags{$tag} or $delQt) {
                    my $nvHashNoLang = $nvHash;
                    my ($val, $len, $lang, $type, $flags, $ctry, $charsetQuickTime);
                    my $format = $$tagInfo{Format};
                    my $hasData = ($$dirInfo{HasData} and $buff =~ /\0...data\0/s);
                    my $langInfo = $tagInfo;
                    if ($hasData) {
                        my $pos = 0;
                        for (;;$pos+=$len) {
                            last if $pos + 16 > $size;
                            ($len, $type, $flags, $ctry, $lang) = unpack("x${pos}Na4Nnn", $buff);
                            $lang or $lang = $undLang;  # treat both 0 and 'und' as 'und'
                            $langInfo = $tagInfo;
                            my $delTag = $delQt;
                            my $newVal;
                            my $langCode = GetLangCode($lang, $ctry, 1);
                            for (;;) {
                                if ($$tagInfo{KeysInfo}) {
                                    $langInfo = GetLangInfo($$tagInfo{KeysInfo}, $langCode);
                                } else {
                                    $langInfo = GetLangInfo($tagInfo, $langCode);
                                }
                                $nvHash = $et->GetNewValueHash($langInfo);
                                last if $nvHash or not $ctry or $lang ne $undLang or length($langCode)==2;
                                # check to see if tag was written with a 2-char country code only
                                $langCode = lc unpack('a2',pack('n',$ctry));
                            }
                            # set flag to delete language tag when writing default
                            # (except for a default-language Keys entry)
                            if (not $nvHash and $nvHashNoLang) {
                                if ($lang eq $undLang and not $ctry and not $didTag{$nvHashNoLang}) {
                                    $nvHash = $nvHashNoLang;    # write existing default
                                } else {
                                    $delTag = 1;    # delete tag
                                }
                            }
                            last if $pos + $len > $size;
                            if ($type eq 'data' and $len >= 16) {
                                $pos += 16;
                                $len -= 16;
                                $val = substr($buff, $pos, $len);
                                # decode value (see QuickTime.pm for an explanation)
                                if ($stringEncoding{$flags}) {
                                    $val = $et->Decode($val, $stringEncoding{$flags});
                                    $val =~ s/\0$// unless $$tagInfo{Binary};
                                    $flags = 0x01;  # write all strings as UTF-8
                                } else {
                                    $format = $$tagInfo{Format};
                                    if ($format) {
                                        # update flags for the format we are writing
                                        $flags = $qtFormat{$format} if $qtFormat{$format};
                                    } else {
                                        $format = QuickTimeFormat($flags, $len);
                                    }
                                    $val = ReadValue(\$val, 0, $format, $$tagInfo{Count}, $len) if $format;
                                }
                                if (($nvHash and $et->IsOverwriting($nvHash, $val)) or $delTag) {
                                    $newVal = $et->GetNewValue($nvHash) if defined $nvHash;
                                    if ($delTag or (not defined $newVal or $didTag{$nvHash})) {
                                        if ($canCreate) {
                                            my $grp = $et->GetGroup($langInfo, 1);
                                            $et->VerboseValue("- $grp:$$langInfo{Name}", $val);
                                            $newData = substr($buff, 0, $pos-16) unless defined $newData;
                                            ++$$et{CHANGED};
                                            $pos += $len;
                                            next;
                                        }
                                        $newVal = '';
                                    }
                                    my $prVal = $newVal;
                                    # format new value for writing (and get new flags)
                                    $flags = FormatQTValue($et, \$newVal, $$tagInfo{Format});
                                    if (defined $newVal and not ($nvHash and $didTag{$nvHash})) {
                                        next if $newVal eq '' and $val eq '';
                                        ++$$et{CHANGED};
                                        my $grp = $et->GetGroup($langInfo, 1);
                                        $et->VerboseValue("- $grp:$$langInfo{Name}", $val);
                                        $et->VerboseValue("+ $grp:$$langInfo{Name}", $prVal);
                                        $didTag{$nvHash} = 1 if $nvHash;
                                        $newData = substr($buff, 0, $pos-16) unless defined $newData;
                                        $newData .= pack('Na4Nnn', length($newVal)+16, $type, $flags, $ctry, $lang);
                                        $newData .= $newVal;
                                    } elsif (defined $newData) {
                                        # copy data up to start of this tag to delete this value
                                        $newData .= substr($buff, $pos-16, $len+16);
                                    }
                                }
                            } elsif (defined $newData) {
                                $newData .= substr($buff, $pos, $len);
                            }
                        }
                        $newData .= substr($buff, $pos) if defined $newData and $pos < $size;
                        undef $val; # (already constructed $newData)
                    } elsif ($format) {
                        $val = ReadValue(\$buff, 0, $format, undef, $size);
                    } elsif (($tag =~ /^\xa9/ or $$tagInfo{IText}) and $size >= ($$tagInfo{IText} || 4)) {
                        if ($$tagInfo{IText} and $$tagInfo{IText} == 6) {
                            $lang = unpack('x4n', $buff);
                            $len = $size - 6;
                            $val = substr($buff, 6, $len);
                        } else {
                            ($len, $lang) = unpack('nn', $buff);
                            $len -= 4 if 4 + $len > $size; # (see QuickTime.pm for explanation)
                            $len = $size - 4 if $len > $size - 4 or $len < 0;
                            $val = substr($buff, 4, $len);
                        }
                        $lang or $lang = $undLang;  # treat both 0 and 'und' as 'und'
                        if ($lang < 0x400 and $val !~ /^\xfe\xff/) {
                            $charsetQuickTime = $et->Options('CharsetQuickTime');
                            $val = $et->Decode($val, $charsetQuickTime);
                        } else {
                            my $enc = $val=~s/^\xfe\xff// ? 'UTF16' : 'UTF8';
                            $val = $et->Decode($val, $enc);
                        }
                        $val =~ s/\0+$//;   # remove trailing nulls if they exist
                        my $langCode = UnpackLang($lang, 1);
                        $langInfo = GetLangInfo($tagInfo, $langCode);
                        # (no need to check $$tagInfo{KeysInfo} because Keys won't get here)
                        $nvHash = $et->GetNewValueHash($langInfo);
                        if (not $nvHash and $nvHashNoLang) {
                            if ($lang eq $undLang and not $didTag{$nvHashNoLang}) {
                                $nvHash = $nvHashNoLang;
                            } elsif ($canCreate) {
                                # delete other languages when writing default
                                my $grp = $et->GetGroup($langInfo, 1);
                                $et->VerboseValue("- $grp:$$langInfo{Name}", $val);
                                ++$$et{CHANGED};
                                next;
                            }
                        }
                    }
                    if ($nvHash and defined $val and $et->IsOverwriting($nvHash, $val)) {
                        $newData = $et->GetNewValue($nvHash);
                        $newData = '' unless defined $newData or $canCreate;
                        ++$$et{CHANGED};
                        my $grp = $et->GetGroup($langInfo, 1);
                        $et->VerboseValue("- $grp:$$langInfo{Name}", $val);
                        next unless defined $newData and not $didTag{$nvHash};
                        $et->VerboseValue("+ $grp:$$langInfo{Name}", $newData);
                        $didTag{$nvHash} = 1;   # set flag so we don't add this tag again
                        # add back necessary header and encode as necessary
                        if (defined $lang) {
                            $newData = $et->Encode($newData, $lang < 0x400 ? $charsetQuickTime : 'UTF8');
                            if ($$tagInfo{IText} and $$tagInfo{IText} == 6) {
                                $newData = pack('Nn', 0, $lang) . $newData . "\0";
                            } else {
                                $newData = pack('nn', length($newData), $lang) . $newData;
                            }
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
                $boxPos{$tag} = [ length($$outfile), length($newData) + 8 ];
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
        # save position of this box in the output buffer
        $boxPos{$tag} = [ length($$outfile), length($hdr) + length($buff) ];
        # copy the existing atom
        Write($outfile, $hdr, $buff) or $rtnVal=$rtnErr, $err=1, last;
    }
    # add new directories/tags at this level if necessary
    if (exists $$et{EDIT_DIRS}{$dirName} and $canCreate) {
        # get a hash of tagInfo references to add to this directory
        my $dirs = $et->GetAddDirHash($tagTablePtr, $dirName);
        # make sorted list of new tags to be added
        my @addTags = sort(keys(%$dirs), keys %$newTags);
        my $tag;
        foreach $tag (@addTags) {
            my $tagInfo = $$dirs{$tag} || $$newTags{$tag};
            next if $$tagInfo{KeysInfo};    # don't try to add keys tags (yet)
            my $subdir = $$tagInfo{SubDirectory};
            unless ($subdir) {
                my $nvHash = $et->GetNewValueHash($tagInfo);
                next unless $nvHash and not $didTag{$nvHash};
                next unless $$nvHash{IsCreating} and $et->IsOverwriting($nvHash);
                my $newVal = $et->GetNewValue($nvHash);
                next unless defined $newVal;
                my $prVal = $newVal;
                my $flags = FormatQTValue($et, \$newVal, $$tagInfo{Format});
                next unless defined $newVal;
                my ($ctry, $lang) = (0,0);
                if (length $tag > 4) { # (is there a language code appended to the tag ID?)
                    unless ($tag =~ s/(.{4})-([A-Z]{3})?[-_]?([A-Z]{2})?/$1/si) {
                        $et->Warn("Invalid language code for $$tagInfo{Name}");
                        next;
                    }
                    # pack language and country codes
                    if ($2 and $2 ne 'und') {
                        $lang = ($lang << 5) | ($_ - 0x60) foreach unpack 'C*', lc($2);
                    }
                    $ctry = unpack('n', pack('a2',uc($3))) if $3 and $3 ne 'ZZ';
                }
                if ($$dirInfo{HasData}) {
                    # add 'data' header
                    $newVal = pack('Na4Nnn',16+length($newVal),'data',$flags,$ctry,$lang).$newVal;
                } elsif ($tag =~ /^\xa9/ or $$tagInfo{IText}) {
                    if ($ctry) {
                        my $grp = $et->GetGroup($tagInfo,1);
                        $et->Warn("Can't use country code for $grp:$$tagInfo{Name}");
                        next;
                    } elsif ($$tagInfo{IText} and $$tagInfo{IText} == 6) {
                        # add 6-byte langText header and trailing null
                        $newVal = pack('Nn',0,$lang) . $newVal . "\0";
                    } else {
                        # add IText header
                        $newVal = pack('nn',length($newVal),$lang) . $newVal;
                    }
                } elsif ($ctry or $lang) {
                    my $grp = $et->GetGroup($tagInfo,1);
                    $et->Warn("Can't use language code for $grp:$$tagInfo{Name}");
                    next;
                }
                Write($outfile, Set32u(8+length($newVal)), $tag, $newVal) or $rtnVal=$rtnErr, $err=1;
                $et->VerboseValue("+ $dirName:$$tagInfo{Name}", $prVal);
                $didTag{$nvHash} = 1;
                ++$$et{CHANGED};
                next;
            }
            my $subName = $$subdir{DirName} || $$tagInfo{Name};
            # QuickTime hierarchy is complex, so check full directory path before adding
            next unless IsCurPath($et, $subName);
            my $buff = '';  # write from scratch
            my %subdirInfo = (
                Parent   => $dirName,
                DirName  => $subName,
                DataPt   => \$buff,
                DirStart => 0,
                HasData  => $$subdir{HasData},
                OutFile  => $outfile,
            );
            my $subTable = GetTagTable($$subdir{TagTable});
            my $newData = $et->WriteDirectory(\%subdirInfo, $subTable, $$subdir{WriteProc});
            if ($newData and length($newData) <= 0x7ffffff7) {
                my $prefix = '';
                # add atom version or ID if necessary
                if ($$subdir{Start}) {
                    if ($$subdir{Start} == 4) {
                        $prefix = "\0\0\0\0"; # a simple version number
                    } else {
                        # get UUID from Condition expression
                        my $cond = $$tagInfo{Condition};
                        $prefix = eval qq("$1") if $cond and $cond =~ m{=~\s*\/\^(.*)/};
                        length($prefix) == $$subdir{Start} or $et->Error('Internal UUID error');
                    }
                }
                my $newHdr = Set32u(8+length($newData)+length($prefix)) . $tag . $prefix;
                Write($outfile, $newHdr, $newData) or $rtnVal=$rtnErr, $err=1;
            }
            delete $$addDirs{$subName}; # add only once (must delete _after_ call to WriteDirectory())
        }
    }
    # write HEIC metadata after top-level 'meta' box has been processed if editing this information
    if ($dirName eq 'Meta' and $$et{EDIT_DIRS}{ItemInformation} and $curPath eq $writePath) {
        $$dirInfo{BoxPos} = \%boxPos;
        my $mdatEdit = WriteItemInfo($et, $dirInfo, $outfile);
        if ($mdatEdit) {
            $et->Error('Multiple top-level Meta containers') if $$et{mdatEdit};
            $$et{mdatEdit} = $mdatEdit;
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

    # edit mdat blocks as required
    # (0=old pos [0 if creating], 1=old end [0 if creating], 2=new data ref or undef to delete,
    #  3=new data item id)
    if ($$et{mdatEdit}) {
        @mdatEdit = @{$$et{mdatEdit}};
        delete $$et{mdatEdit};
    }
    foreach $edit (@mdatEdit) {
        my (@thisMdat, @newMdat, $changed);
        foreach $mdat (@mdat) {
            # keep track of all chunks for the mdat with this header
            if (length $$mdat[2]) {
                push @newMdat, @thisMdat;
                undef @thisMdat;
            }
            push @thisMdat, $mdat;
            # is this edit inside this mdat chunk?
            # - $$edit[0] and $$edit[1] will both be zero if we are creating a new chunk
            # - $$mdat[1] is zero if mdat runs to end of file
            # - $$edit[0] == $$edit[1] == $$mdat[0] if reviving a deleted chunk
            # - $$mdat[5] is defined if this was a newly added/edited chunk
            next if defined $$mdat[5] or $changed;  # don't replace a newly added chunk
            if (not $$edit[0] or    # (newly created chunk)
                # (edit is inside chunk)
                ((($$edit[0] < $$mdat[1] or not $$mdat[1]) and $$edit[1] > $$mdat[0]) or
                # (edit inserted at start or end of chunk)
                ($$edit[0] == $$edit[1] and ($$edit[0] == $$mdat[0] or $$edit[0] == $$mdat[1]))))
            {
                if (not $$edit[0]) {
                    $$edit[0] = $$edit[1] = $$mdat[0];  # insert at start of this mdat
                } elsif ($$edit[0] < $$mdat[0] or ($$edit[1] > $$mdat[1] and $$mdat[1])) {
                    $et->Error('ItemInfo runs across mdat boundary');
                    return $rtnVal;
                }
                my $hdrChunk = $thisMdat[0];
                $hdrChunk or $et->Error('Internal error finding mdat header'), return $rtnVal;
                # calculate difference in mdat size
                my $diff = ($$edit[2] ? length(${$$edit[2]}) : 0) - ($$edit[1] - $$edit[0]);
                # edit size of mdat in header if necessary
                if ($diff) {
                    if (length($$hdrChunk[2]) == 8) {
                        my $size = Get32u(\$$hdrChunk[2], 0) + $diff;
                        $size > 0xffffffff and $et->Error("Can't yet grow mdat across 4GB boundary"), return $rtnVal;
                        Set32u($size, \$$hdrChunk[2], 0);
                    } elsif (length($$hdrChunk[2]) == 16) {
                        my $size = Get64u(\$$hdrChunk[2], 8) + $diff;
                        Set64u($size, \$$hdrChunk[2], 8);
                    } else {
                        $et->Error('Internal error. Invalid mdat header');
                        return $rtnVal;
                    }
                }
                $changed = 1;
                # remove the edited section of this chunk (if any) and replace with new data (if any)
                if ($$edit[0] > $$mdat[0]) {
                    push @thisMdat, [ $$edit[0], $$edit[1], '', 0, $$edit[2], $$edit[3] ] if $$edit[2];
                    # add remaining data after edit (or empty stub in case it is referenced by an offset)
                    push @thisMdat, [ $$edit[1], $$mdat[1], '' ];
                    $$mdat[1] = $$edit[0];  # now ends at start of edit
                } else {
                    if ($$edit[2]) {
                        # insert the new chunk before this chunk, moving the header to the new chunk
                        splice @thisMdat, -1, 0, [ $$edit[0],$$edit[1],$$mdat[2],0,$$edit[2],$$edit[3] ];
                        $$mdat[2] = '';     # (header was moved to new chunk)
                        # initialize ChunkOffset pointer if necessary
                        if ($$edit[3]) {
                            my $n = 0;
                            foreach $co (@$off) {
                                next unless defined $$co[4] and $$co[4] == $$edit[3];
                                ++$n;
                                if ($$co[0] eq 'stco_iloc') {
                                    Set32u($$mdat[0], $outfile, $$co[1]);
                                } else {
                                    Set64u($$mdat[0], $outfile, $$co[1]);
                                }
                            }
                            $n == 1 or $et->Error('Internal error updating chunk offsets');
                        }
                    }
                    $$mdat[0] = $$edit[1];  # remove old data
                }
            }
        }
        if ($changed) {
            @mdat = ( @newMdat, @thisMdat );
            ++$$et{CHANGED};
        } else {
            $et->Error('Internal error modifying mdat');
        }
    }

    # determine our new mdat positions
    # (0=old pos, 1=old end, 2=mdat header, 3=new pos, 4=new data ref if changed, 5=new item ID)
    my $pos = length $$outfile;
    foreach $mdat (@mdat) {
        $pos += length $$mdat[2];
        $$mdat[3] = $pos;
        $pos += $$mdat[4] ? length(${$$mdat[4]}) : $$mdat[1] - $$mdat[0];
    }

    # fix up offsets for new mdat position(s)
    foreach $co (@$off) {
        my ($type, $ptr, $len, $base, $id) = @$co;
        $base = 0 unless $base;
        $type =~ /^(stco|co64)_?(.*)$/ or $et->Error('Internal error fixing offsets'), last;
        my $siz = $1 eq 'co64' ? 8 : 4;
        my ($n, $tag);
        if ($2) {   # is this an offset in an iloc or 'gps ' atom?
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
            my ($ok, $i);
            my $val = $type eq 'co64' ? Get64u($outfile, $ptr) : Get32u($outfile, $ptr);
            for ($i=0; $i<@mdat; ++$i) {
                $mdat = $mdat[$i];
                my $pos = $val + $base;
                if (defined $$mdat[5]) { # is this chunk associated with an item we edited?
                    # set offset only for the corresponding new chunk
                    unless (defined $id and $id == $$mdat[5]) {
                        # could have pointed to empty chunk before inserted chunk
                        next unless $pos == $$mdat[0] and $$mdat[0] != $$mdat[1];
                    }
                } else {
                    # (have seen $pos == $$mdat[1], which is a real PITA)
                    next unless $pos >= $$mdat[0] and ($pos <= $$mdat[1] or not $$mdat[1]);
                    # step to next chunk if contiguous and at the end of this one
                    next if $pos == $$mdat[1] and $i+1 < @mdat and $pos == $mdat[$i+1][0];
                }
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
        Write($outfile, $$mdat[2]) or $rtnVal = 0;  # write mdat header
        if ($$mdat[4]) {
            Write($outfile, ${$$mdat[4]}) or $rtnVal = 0;
        } else {
            $raf->Seek($$mdat[0], 0) or $et->Error('Seek error'), last;
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
    $et or return 1;    # allow dummy access to autoload this package
    my $raf = $$dirInfo{RAF} or return 0;
    my ($buff, $ftype);

    # read the first atom header
    return 0 unless $raf->Read($buff, 8) == 8;
    my ($size, $tag) = unpack('Na4', $buff);
    return 0 if $size < 8 and $size != 1;

    # validate the file format
    my $tagTablePtr = GetTagTable('Image::ExifTool::QuickTime::Main');
    return 0 unless $$tagTablePtr{$tag};

    # determine the file type (by default, assume MP4 if 'ftyp' exists
    # without 'qt  ' as a compatible brand, but HEIC is an exception)
    if ($tag eq 'ftyp' and $size >= 12 and $size < 100000 and
        $raf->Read($buff, $size-8) == $size-8 and
        $buff !~ /^(....)+(qt  )/s)
    {
        if ($buff =~ /^crx /) {
            $ftype = 'CR3',
        } elsif ($buff =~ /^(heic|mif1|msf1|heix|hevc|hevx)/) {
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
