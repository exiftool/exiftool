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
    QuickTime => 'ItemList',    # (default location for QuickTime tags)
    ItemList  => 'Meta',        # MOV-Movie-UserData-Meta-ItemList
    Keys      => 'Movie',       # MOV-Movie-Meta-Keys !! (hack due to different Meta location)
    AudioKeys => 'Track',       # MOV-Movie-Track-Meta-Keys !!
    VideoKeys => 'Track',       # MOV-Movie-Track-Meta-Keys !!
    Meta      => 'UserData',
    XMP       => 'UserData',    # MOV-Movie-UserData-XMP
    Microsoft => 'UserData',    # MOV-Movie-UserData-Microsoft
    UserData  => 'Movie',       # MOV-Movie-UserData
    Movie     => 'MOV',
    GSpherical => 'SphericalVideoXML', # MOV-Movie-Track-SphericalVideoXML
    SphericalVideoXML => 'Track',      # (video track specifically, don't create if it doesn't exist)
    Track     => 'Movie',
);
my %mp4Map = (
    # MP4 ('ftyp' compatible brand 'mp41', 'mp42' or 'f4v ') -> XMP at top level
    QuickTime => 'ItemList',    # (default location for QuickTime tags)
    ItemList  => 'Meta',        # MOV-Movie-UserData-Meta-ItemList
    Keys      => 'Movie',       # MOV-Movie-Meta-Keys !! (hack due to different Meta location)
    AudioKeys => 'Track',       # MOV-Movie-Track-Meta-Keys !!
    VideoKeys => 'Track',       # MOV-Movie-Track-Meta-Keys !!
    Meta      => 'UserData',
    UserData  => 'Movie',       # MOV-Movie-UserData
    Microsoft => 'UserData',    # MOV-Movie-UserData-Microsoft
    Movie     => 'MOV',
    XMP       => 'MOV',         # MOV-XMP
    GSpherical => 'SphericalVideoXML', # MOV-Movie-Track-SphericalVideoXML
    SphericalVideoXML => 'Track',      # (video track specifically, don't create if it doesn't exist)
    Track     => 'Movie',
);
my %heicMap = (
    # HEIC/HEIF/AVIF ('ftyp' compatible brand 'heic','mif1','avif') -> XMP/EXIF in top level 'meta'
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
   'UUID-Canon2' => 'MOV',
    CanonVRD  => 'UUID-Canon2',
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
    int8s  => 0x15,  int16s => 0x15,  int32s => 0x15,  int64s => 0x15,
    int8u  => 0x16,  int16u => 0x16,  int32u => 0x16,  int64u => 0x16,
    float  => 0x17,  double => 0x18,
);
my $undLang = 0x55c4;   # numeric code for default ('und') language

my $maxReadLen = 100000000; # maximum size of atom to read into memory (100 MB)

# boxes that may exist in an "empty" Meta box:
my %emptyMeta = (
    hdlr => 'Handler', 'keys' => 'Keys', lang => 'Language', ctry => 'Country', free => 'Free',
);

# lookup for CTBO ID number based on uuid for Canon CR3 files
my %ctboID = (
    "\xbe\x7a\xcf\xcb\x97\xa9\x42\xe8\x9c\x71\x99\x94\x91\xe3\xaf\xac" => 1, # XMP
    "\xea\xf4\x2b\x5e\x1c\x98\x4b\x88\xb9\xfb\xb7\xdc\x40\x6e\x4d\x16" => 2, # PreviewImage
    # ID 3 is used for 'mdat' atom (not a uuid)
    # (haven't seen ID 4 yet)
    "\x57\x66\xb8\x29\xbb\x6a\x47\xc5\xbc\xfb\x8b\x9f\x22\x60\xd0\x6d" => 5, # something to do with burst-roll image
);

# mark UserData tags that don't have ItemList counterparts as Preferred
# - and set Preferred to 0 for any Avoid-ed tag
# - also, for now, set Writable to 0 for any tag with a RawConv and no RawConvInv
{
    my $itemList = \%Image::ExifTool::QuickTime::ItemList;
    my $userData = \%Image::ExifTool::QuickTime::UserData;
    my (%pref, $tag);
    foreach $tag (TagTableKeys($itemList)) {
        my $tagInfo = $$itemList{$tag};
        if (ref $tagInfo ne 'HASH') {
            next if ref $tagInfo;
            $tagInfo = $$itemList{$tag} = { Name => $tagInfo };
        } else {
            $$tagInfo{Writable} = 0 if $$tagInfo{RawConv} and not $$tagInfo{RawConvInv};
            $$tagInfo{Avoid} and $$tagInfo{Preferred} = 0, next;
            next if defined $$tagInfo{Preferred} and not $$tagInfo{Preferred};
        }
        $pref{$$tagInfo{Name}} = 1;
    }
    foreach $tag (TagTableKeys($userData)) {
        my $tagInfo = $$userData{$tag};
        if (ref $tagInfo ne 'HASH') {
            next if ref $tagInfo;
            $tagInfo = $$userData{$tag} = { Name => $tagInfo };
        } else {
            $$tagInfo{Writable} = 0 if $$tagInfo{RawConv} and not $$tagInfo{RawConvInv};
            $$tagInfo{Avoid} and $$tagInfo{Preferred} = 0, next;
            next if defined $$tagInfo{Preferred} or $pref{$$tagInfo{Name}};
        }
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
    return $val if $val =~ /^([-+]?\d+(\.\d*)?)\s+([-+]?\d+(\.\d*)?)$/; # already 2 floats?
    return $val if $val =~ /^([-+]\d+(\.\d*)?){2,3}(CRS.*)?\/?$/; # already in ISO6709 format?
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
        # latitude must have 2 digits before the decimal, and longitude 3,
        # and all values must start with a "+" or "-", and Google Photos
        # requires at least 3 digits after the decimal point
        # (and as of Apr 2021, Google Photos doesn't accept coordinats
        #  with more than 5 digits after the decimal place:
        #  https://exiftool.org/forum/index.php?topic=11055.msg67171#msg67171 
        #  still a problem Apr 2024: https://exiftool.org/forum/index.php?msg=85761)
        my @fmt = ('%s%02d.%s%s','%s%03d.%s%s','%s%d.%s%s');
        my @limit = (90,180);
        foreach (@a) {
            return undef unless Image::ExifTool::IsFloat($_);
            my $lim = shift @limit;
            warn((@limit ? 'Lat' : 'Long') . "itude out of range\n") if $lim and abs($_) > $lim;
            $_ =~ s/^([-+]?)(\d+)\.?(\d*)/sprintf(shift(@fmt),$1||'+',$2,$3,length($3)<3 ? '0'x(3-length($3)) : '')/e;
        }
        return join '', @a, '/';
    }
    return $val if $val =~ /^([-+]\d+(\.\d*)?){2,3}(CRS.*)?\/?$/; # already in ISO6709 format?
    return undef;
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
    my $format = $$tagInfo{Format} || $$tagInfo{Writable} || $$tagInfo{Table}{FORMAT};
    return undef unless $format;
    return Image::ExifTool::CheckValue($valPtr, $format, $$tagInfo{Count});
}

#------------------------------------------------------------------------------
# Format QuickTime value for writing
# Inputs: 0) ExifTool ref, 1) value ref, 2) tagInfo ref, 3) Format (or undef)
# Returns: Flags for QT data type, and reformats value as required (sets to undef on error)
sub FormatQTValue($$;$$)
{
    my ($et, $valPt, $tagInfo, $format) = @_;
    my $writable = $$tagInfo{Writable};
    my $count = $$tagInfo{Count};
    my $flags;
    $format or $format = $$tagInfo{Format};
    if ($format and $format ne 'string' or not $format and $writable and $writable ne 'string') {
        $$valPt = WriteValue($$valPt, $format || $writable, $count);
        if ($writable and $qtFormat{$writable}) {
            $flags = $qtFormat{$writable};
        } else {
            $flags = $qtFormat{$format || 0} || 0;
        }
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
    defined $$valPt or $et->Warn("Error converting value for $$tagInfo{Name}");
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
# Write Nextbase infi atom (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: updated infi data
sub WriteNextbase($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;
    $$et{DEL_GROUP}{Nextbase} and ++$$et{CHANGED}, return '';
    return ${$$dirInfo{DataPt}};
}

#------------------------------------------------------------------------------
# Write Meta Keys to add/delete entries as necessary ('mdta' handler) (ref PH)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: updated keys box data
# Note: Residual entries may be left in the 'keys' directory when deleting tags
#       with language codes because the language code(s) are not known until the
#       corresponding ItemList entry(s) are processed
sub WriteKeys($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;      # allow dummy access to autoload this package
    my $dataPt = $$dirInfo{DataPt};
    my $dirLen = length $$dataPt;
    my $outfile = $$dirInfo{OutFile};
    my ($tag, %done, %remap, %info, %add, $i);

    my $keysGrp = $avType{$$et{MediaType}} ? "$avType{$$et{MediaType}}Keys" : 'Keys';
    $dirLen < 8 and $et->Warn('Short Keys box'), $dirLen = 8, $$dataPt = "\0" x 8;
    if ($$et{DEL_GROUP}{$keysGrp}) {
        $dirLen = 8;    # delete all existing keys
        # deleted keys are identified by a zero entry in the Remap lookup
        my $n = Get32u($dataPt, 4);
        for ($i=1; $i<=$n; ++$i) { $remap{$i} = 0; }
        $et->VPrint(0, "  [deleting $n $keysGrp entr".($n==1 ? 'y' : 'ies')."]\n");
        ++$$et{CHANGED};
    }
    my $pos = 8;
    my $newTags = $et->GetNewTagInfoHash($tagTablePtr);
    my $newData = substr($$dataPt, 0, $pos);

    my $newIndex = 1;
    my $index = 1;
    while ($pos < $dirLen - 4) {
        my $len = unpack("x${pos}N", $$dataPt);
        last if $len < 8 or $pos + $len > $dirLen;
        my $ns  = substr($$dataPt, $pos + 4, 4);
        $tag = substr($$dataPt, $pos + 8, $len - 8);
        $tag =~ s/\0.*//s; # truncate at null
        $tag =~ s/^com\.apple\.quicktime\.// if $ns eq 'mdta'; # remove apple quicktime domain
        $tag = "Tag_$ns" unless $tag;
        $done{$tag} = 1;    # set flag to avoid creating this tag
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if ($tagInfo) {
            $info{$index} = $tagInfo;
            if ($$newTags{$tag}) {
                my $nvHash = $et->GetNewValueHash($tagInfo);
                # drop this tag if it is being deleted
                if ($nvHash and $et->IsOverwriting($nvHash) > 0 and not defined $et->GetNewValue($nvHash)) {
                    # don't delete this key if we could be writing any alternate-language version of this tag
                    my ($t, $dontDelete);
                    foreach $t (keys %$newTags) {
                        next unless $$newTags{$t}{SrcTagInfo} and $$newTags{$t}{SrcTagInfo} eq $tagInfo;
                        my $nv = $et->GetNewValueHash($$newTags{$t});
                        next unless $et->IsOverwriting($nv) and defined $et->GetNewValue($nv);
                        $dontDelete = 1;
                        last;
                    }
                    unless ($dontDelete) {
                        # delete this key
                        $et->VPrint(1, "$$et{INDENT}\[deleting $keysGrp entry $index '${tag}']\n");
                        $pos += $len;
                        $remap{$index++} = 0;
                        ++$$et{CHANGED};
                        next;
                    }
                }
            }
        }
        # add to the Keys box data
        $newData .= substr($$dataPt, $pos, $len);
        $remap{$index++} = $newIndex++;
        $pos += $len;
    }
    # add keys for any tags we need to create
    foreach $tag (sort keys %$newTags) {
        my $tagInfo = $$newTags{$tag};
        my $id;
        if ($$tagInfo{LangCode} and $$tagInfo{SrcTagInfo}) {
            $id = $$tagInfo{SrcTagInfo}{TagID};
        } else {
            $id = $tag;
        }
        next if $done{$id};
        my $nvHash = $et->GetNewValueHash($tagInfo);
        next unless $$nvHash{IsCreating} and $et->IsOverwriting($nvHash) and
            defined $et->GetNewValue($nvHash);
        # add new entry to 'keys' data
        my $val = $id =~ /^com\./ ? $id : "com.apple.quicktime.$id";
        $newData .= Set32u(8 + length($val)) . 'mdta' . $val;
        $et->VPrint(1, "$$et{INDENT}\[adding $keysGrp entry $newIndex '${id}']\n");
        $add{$newIndex++} = $tagInfo;
        ++$$et{CHANGED};
    }
    my $num = $newIndex - 1;
    if ($num) {
        Set32u($num, \$newData, 4);     # update count in header
    } else {
        $newData = '';  # delete empty Keys box
    }
    # save temporary variables for use when writing ItemList:
    #   Remap - lookup for remapping Keys ID numbers (0 if item is deleted)
    #   Info  - Keys tag information, based on old index value
    #   Add   - Keys items deleted, based on old index value
    #   Num   - Number of items in edited Keys box
    $$et{$keysGrp} = { Remap => \%remap, Info => \%info, Add => \%add, Num => $num };

    return $newData;    # return updated Keys box
}

#------------------------------------------------------------------------------
# Write ItemInformation in HEIC files
# Inputs: 0) ExifTool ref, 1) dirInfo ref (with BoxPos entry), 2) output buffer ref
# Returns: mdat edit list ref (empty if nothing changed)
sub WriteItemInfo($$$)
{
    my ($et, $dirInfo, $outfile) = @_;
    my $boxPos = $$dirInfo{BoxPos}; # hash of [position,length,irefVer(iref only)] for box in $outfile
    my $raf = $$et{RAF};
    my $items = $$et{ItemInfo};
    my (%did, @mdatEdit, $name, $tmap);

    return () unless $items and $raf;

    # extract information from EXIF/XMP metadata items
    my $primary = $$et{PrimaryItem};
    my $curPos = $raf->Tell();
    my $lastID = 0;
    my $id;
    foreach $id (sort { $a <=> $b } keys %$items) {
        $lastID = $id;
        $primary = $id unless defined $primary; # assume primary is lowest-number item if pitm missing
        my $item = $$items{$id};
        # only edit primary EXIF/XMP metadata
        next unless $$item{RefersTo} and $$item{RefersTo}{$primary};
        my $type = $$item{ContentType} || $$item{Type} || next;
        $tmap = $id if $type eq 'tmap'; # save ID of primary 'tmap' item (tone-mapped image)
        # get ExifTool name for this item
        $name = { Exif => 'EXIF', 'application/rdf+xml' => 'XMP' }->{$type};
        next unless $name;  # only care about EXIF and XMP
        next unless $$et{EDIT_DIRS}{$name};
        $did{$name} = 1;    # set flag to prevent creating this metadata
        my ($warn, $extent, $buff, @edit);
        $warn = 'Missing iloc box' unless $$boxPos{iloc};
        $warn = "No Extents for $type item" unless $$item{Extents} and @{$$item{Extents}};
        if ($$item{ContentEncoding}) {
            if ($$item{ContentEncoding} ne 'deflate') {
                $warn = "Can't currently decode $$item{ContentEncoding} encoded $type metadata";
            } elsif (not eval { require Compress::Zlib }) {
                $warn = "Install Compress::Zlib to decode deflated $type metadata";
            }
        }
        $warn = "Can't currently decode protected $type metadata" if $$item{ProtectionIndex};
        $warn = "Can't currently extract $type with construction method $$item{ConstructionMethod}" if $$item{ConstructionMethod};
        $warn = "$type metadata is not in this file" if $$item{DataReferenceIndex};
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
        my $comp = $et->Options('Compress');
        if (defined $comp and ($comp xor $$item{ContentEncoding})) {
            #TODO: add ability to edit infe entry in iinf to change encoding according to Compress option if set
            $et->Warn("Can't currently change compression when rewriting $name in HEIC",1);
        }
        my $wasDeflated;
        if ($$item{ContentEncoding}) {
            my ($v2, $stat);
            my $inflate = Compress::Zlib::inflateInit();
            $inflate and ($v2, $stat) = $inflate->inflate($buff);
            $et->VPrint(0, "  (Inflating stored $name metadata)\n");
            if ($inflate and $stat == Compress::Zlib::Z_STREAM_END()) {
                $buff = $v2;
                $wasDeflated = 1;
            } else {
                $et->Warn("Error inflating $name metadata");
                next;
            }
        }
        my ($hdr, $subTable, $proc);
        my $strt = 0;
        if ($name eq 'EXIF') {
            if (not length $buff) {
                # create EXIF from scratch
                $hdr = "\0\0\0\x06Exif\0\0";
            } elsif ($buff =~ /^(MM\0\x2a|II\x2a\0)/) {
                $et->Warn('Missing Exif header');
                $hdr = '';
            } elsif (length($buff) >= 4 and length($buff) >= 4 + unpack('N',$buff)) {
                $hdr = substr($buff, 0, 4 + unpack('N',$buff));
                $strt = length $hdr;
            } else {
                $et->Warn('Invalid Exif header');
                next;
            }
            $subTable = GetTagTable('Image::ExifTool::Exif::Main');
            $proc = \&Image::ExifTool::WriteTIFF;
        } else {
            $hdr = '';
            $subTable = GetTagTable('Image::ExifTool::XMP::Main');
        }
        my %dirInfo = (
            DataPt   => \$buff,
            DataLen  => length $buff,
            DirStart => $strt,
            DirLen   => length($buff) - $strt,
        );
        my $changed = $$et{CHANGED};
        my $newVal = $et->WriteDirectory(\%dirInfo, $subTable, $proc);
        if (defined $newVal and $changed ne $$et{CHANGED} and
            # nothing changed if deleting an empty directory
            ($dirInfo{DirLen} or length $newVal))
        {
            $newVal = $hdr . $newVal if length $hdr and length $newVal;
            if ($wasDeflated) {
                my $deflate = Compress::Zlib::deflateInit();
                if ($deflate) {
                    $et->VPrint(0, "  (Re-deflating new $name metadata)\n");
                    $buff = $deflate->deflate($newVal);
                    if (defined $buff) {
                        $buff .= $deflate->flush();
                        $newVal = $buff;
                    }
                }
            }
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
                    $et->Error("Can't yet promote iloc length to 64 bits");
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

    # add necessary metadata types if they didn't already exist
    my ($countNew, %add, %usedID);
    foreach $name ('EXIF','XMP') {
        next if $did{$name} or not $$et{ADD_DIRS}{$name};
        my @missing;
        $$boxPos{$_} or push @missing, $_ foreach qw(iinf iloc);
        if (@missing) {
            my $str = @missing > 1 ? join(' and ', @missing) . ' boxes' : "@missing box";
            $et->Warn("Can't create $name. Missing expected $str");
            last;
        }
        unless (defined $$et{PrimaryItem}) {
            unless (defined $primary) {
                $et->Warn("Can't create $name. No items to reference");
                last;
            }
            # add new primary item reference box after hdrl box
            if ($primary < 0x10000) {
                $add{hdlr} = pack('Na4Nn', 14, 'pitm', 0, $primary);
            } else {
                $add{hdlr} = pack('Na4CCCCN', 16, 'pitm', 1, 0, 0, 0, $primary);
            }
            $et->Warn("Added missing PrimaryItemReference (for item $primary)", 1);
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
            my $irefVer;
            if ($$boxPos{iref}) {
                $irefVer = Get8u($outfile, $$boxPos{iref}[0] + 8);
            } else {
                # create iref box after end of iinf box (and save version in boxPos list)
                $irefVer = ($primary < 0x10000 ? 0 : 1);
                $$boxPos{iref} = [ $$boxPos{iinf}[0] + $$boxPos{iinf}[1], 0, $irefVer ];
            }
            $newVal = $hdr . $newVal if length $hdr;
            # add new infe to iinf
            $add{iinf} = $add{iref} = $add{iloc} = '' unless defined $add{iinf};
            my ($type, $mime);
            my $enc = '';
            if ($name eq 'XMP') {
                $type = "mime\0";
                $mime = "application/rdf+xml\0";
                # write compressed XMP if Compress option is set
                if ($et->Options('Compress') and length $newVal) {
                    if (not eval { require Compress::Zlib }) {
                        $et->Warn('Install Compress::Zlib to write compressed metadata');
                    } else {
                        my $deflate = Compress::Zlib::deflateInit();
                        if ($deflate) {
                            $et->VPrint(0, "  (Deflating new $name metadata)\n");
                            my $buff = $deflate->deflate($newVal);
                            if (defined $buff) {
                                $newVal = $buff . $deflate->flush();
                                $enc = "deflate\0";
                            }
                        }
                    }
                }
            } else {
                $type = "Exif\0";
                $mime = '';
            }
            my $id = ++$lastID; # use next highest available ID (so ID's in iinf are in order)
            #[retracted] # create new item information hash to save infe box in case we need it for sorting
            #[retracted] my $item = $$items{$id} = { };
            # add new infe entry to iinf box
            my $n = length($type) + length($mime) + length($enc) + 16;
            if ($id < 0x10000) {
                $add{iinf} .= pack('Na4CCCCnn', $n, 'infe', 2, 0, 0, 1, $id, 0) . $type . $mime . $enc;
            } else {
                $n += 2;
                $add{iinf} .= pack('Na4CCCCNn', $n, 'infe', 3, 0, 0, 1, $id, 0) . $type . $mime . $enc;
            }
            #[retracted] $add{iinf} .= $$item{infe};
            # add new cdsc to iref (also refer to primary 'tmap' if it exists)
            if ($irefVer) {
                my ($fmt, $siz, $num) = defined $tmap ? ('N', 22, 2) : ('', 18, 1);
                $add{iref} .= pack('Na4NnN'.$fmt, $siz, 'cdsc', $id, $num, $primary, $tmap);
            } else {
                my ($fmt, $siz, $num) = defined $tmap ? ('n', 16, 2) : ('', 14, 1);
                $add{iref} .= pack('Na4nnn'.$fmt, $siz, 'cdsc', $id, $num, $primary, $tmap);
            }
            # add new entry to iloc table (see ISO14496-12:2015 pg.79)
            my $ilocVer = Get8u($outfile, $$boxPos{iloc}[0] + 8);
            my $siz = Get16u($outfile, $$boxPos{iloc}[0] + 12);  # get size information
            my $noff = ($siz >> 12);
            my $nlen = ($siz >> 8) & 0x0f;
            my $nbas = ($siz >> 4) & 0x0f;
            my $nind = $siz & 0x0f;
            my ($pbas, $poff);
            if ($ilocVer == 0) {
                # set offset to 0 as flag that this is a new idat chunk being added
                $pbas = length($add{iloc}) + 4;
                $poff = $pbas + $nbas + 2;
                $add{iloc} .= pack('nn',$id,0) . SetVarInt(0,$nbas) . Set16u(1) .
                            SetVarInt(0,$noff) . SetVarInt(length($newVal),$nlen);
            } elsif ($ilocVer == 1) {
                $pbas = length($add{iloc}) + 6;
                $poff = $pbas + $nbas + 2 + $nind;
                $add{iloc} .= pack('nnn',$id,0,0) . SetVarInt(0,$nbas) . Set16u(1) . SetVarInt(0,$nind) .
                            SetVarInt(0,$noff) . SetVarInt(length($newVal),$nlen);
            } elsif ($ilocVer == 2) {
                $pbas = length($add{iloc}) + 8;
                $poff = $pbas + $nbas + 2 + $nind;
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
                $newOff = [ 'stco_iloc', $$boxPos{iloc}[0] + $$boxPos{iloc}[1] + $poff, $noff, 0, $id ];
            } elsif ($noff == 8) {
                $newOff = [ 'co64_iloc', $$boxPos{iloc}[0] + $$boxPos{iloc}[1] + $poff, $noff, 0, $id ];
            } elsif ($noff == 0) {
                # offset_size is zero, so store the offset in base_offset instead
                if ($nbas == 4) {
                    $newOff = [ 'stco_iloc', $$boxPos{iloc}[0] + $$boxPos{iloc}[1] + $pbas, $nbas, 0, $id ];
                } elsif ($nbas == 8) {
                    $newOff = [ 'co64_iloc', $$boxPos{iloc}[0] + $$boxPos{iloc}[1] + $pbas, $nbas, 0, $id ];
                } else {
                    $et->Warn("Can't create $name. Invalid iloc offset+base size");
                    last;
                }
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
        # insert new entries into iinf, iref and iloc boxes,
        # and add new pitm box after hdlr if necessary
        my $added = 0;
        my $tag;
        foreach $tag (sort { $$boxPos{$a}[0] <=> $$boxPos{$b}[0] } keys %$boxPos) {
            $$boxPos{$tag}[0] += $added;
            next unless $add{$tag};
            my $pos = $$boxPos{$tag}[0];
            unless ($$boxPos{$tag}[1]) {
                $tag eq 'iref' or $et->Error('Internal error adding iref box'), last;
                # create new iref box
                $add{$tag} = Set32u(12 + length $add{$tag}) . $tag .
                             Set8u($$boxPos{$tag}[2]) . "\0\0\0" . $add{$tag};
            } elsif ($tag ne 'hdlr') {
                my $n = Get32u($outfile, $pos) +  length($add{$tag});
                Set32u($n, $outfile, $pos);    # increase box size
            }
            if ($tag eq 'iinf') {
                my $iinfVer = Get8u($outfile, $pos + 8);
                if ($iinfVer == 0) {
                    my $n = Get16u($outfile, $pos + 12) + $countNew;
                    if ($n > 0xffff) {
                        $et->Error("Can't currently handle rollover to long item count");
                        return undef;
                    }
                    Set16u($n, $outfile, $pos + 12);    # incr count
                } else {
                    my $n = Get32u($outfile, $pos + 12) + $countNew;
                    Set32u($n, $outfile, $pos + 12);    # incr count
                }
            } elsif ($tag eq 'iref') {
                # nothing more to do
            } elsif ($tag eq 'iloc') {
                my $ilocVer = Get8u($outfile, $pos + 8);
                if ($ilocVer < 2) {
                    my $n = Get16u($outfile, $pos + 14) + $countNew;
                    Set16u($n, $outfile, $pos + 14);    # incr count
                    if ($n > 0xffff) {
                        $et->Error("Can't currently handle rollover to long item count");
                        return undef;
                    }
                } else {
                    my $n = Get32u($outfile, $pos + 14) + $countNew;
                    Set32u($n, $outfile, $pos + 14);    # incr count
                }
                # must also update pointer locations in this box
                if ($added) {
                    $$_[1] += $added foreach @{$$dirInfo{ChunkOffset}};
                }
            } elsif ($tag ne 'hdlr') {
                next;
            }
            # add new entries to this box (or add pitm after hdlr)
            substr($$outfile, $pos + $$boxPos{$tag}[1], 0) = $add{$tag};
            $$boxPos{$tag}[1] += length $add{$tag};
            $added += length $add{$tag};    # positions are shifted by length of new entries
        }
    }
    #[This sorting idea was retracted because just sorting 'iinf' wasn't sufficient to
    # repair the problem where an out-of-order ID was added -- Apple Preview still
    # ignores the gain-map image.  It looks like either or both 'iref' and 'iloc' must
    # also be sorted by ID, although the spec doesn't mention this]
    #[retracted] # sort infe entries in iinf box if necessary
    #[retracted] if ($$et{ItemsNotSorted}) {
    #[retracted]     if ($$boxPos{iinf}) {
    #[retracted]         my $iinfVer = Get8u($outfile, $$boxPos{iinf}[0] + 8);
    #[retracted]         my $off = $iinfVer == 0 ? 14 : 16;  # offset to first infe item
    #[retracted]         my $sorted = '';    # sorted iinf payload
    #[retracted]         $sorted .= $$items{$_}{infe} || '' foreach sort { $a <=> $b } keys %$items;
    #[retracted]         if (length $sorted == $$boxPos{iinf}[1]-$off) {
    #[retracted]             # replace with sorted infe entries
    #[retracted]             substr($$outfile, $$boxPos{iinf}[0] + $off, length $sorted) = $sorted;
    #[retracted]             $et->Warn('Item info entries are out of order. Fixed.');
    #[retracted]             ++$$et{CHANGED};
    #[retracted]         } else {
    #[retracted]             $et->Warn('Error sorting item info entries');
    #[retracted]         }
    #[retracted]     } else {
    #[retracted]         $et->Warn('Item info entries are out of order');
    #[retracted]     }
    #[retracted]     delete $$et{ItemsNotSorted};
    #[retracted] }
    delete $$et{ItemInfo};
    return @mdatEdit ? \@mdatEdit : undef;
}

#------------------------------------------------------------------------------
# Write a series of QuickTime atoms from file or in memory
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: A) if dirInfo contains DataPt: new directory data
#          B) otherwise: true on success, 0 if a write error occurred
#             (true but sets an Error on a file format error)
# Notes: Yes, this is a real mess.  Just like the QuickTime metadata situation.
sub WriteQuickTime($$$)
{
    local $_;
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access to autoload this package
    my ($mdat, @mdat, @mdatEdit, $edit, $track, $outBuff, $co, $term, $delCount);
    my (%langTags, $canCreate, $delGrp, %boxPos, %didDir, $writeLast, $err, $atomCount);
    my ($tag, $lastTag, $lastPos, $errStr, $trailer, $buf2, $keysGrp, $keysPath);
    my $outfile = $$dirInfo{OutFile} || return 0;
    my $raf = $$dirInfo{RAF};       # (will be null for lower-level atoms)
    my $dataPt = $$dirInfo{DataPt}; # (will be null for top-level atoms)
    my $dirName = $$dirInfo{DirName};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $parent = $$dirInfo{Parent};
    my $addDirs = $$et{ADD_DIRS};
    my $didTag = $$et{DidTag};
    my $newTags = { };
    my $createKeys = 0;
    my ($rtnVal, $rtnErr) = $dataPt ? (undef, undef) : (1, 0);

    # check for trailer at end of file
    if ($raf) {
        $trailer = IdentifyTrailers($raf);
        $trailer and not ref $trailer and $et->Error($trailer), return 1;
    }
    if ($dataPt) {
        $raf = File::RandomAccess->new($dataPt);
    } else {
        return 0 unless $raf;
    }
    # use buffered output for everything but 'mdat' atoms
    $outBuff = '';
    $outfile = \$outBuff;

    $raf->Seek($dirStart, 1) if $dirStart;  # skip header if it exists

    if ($avType{$$et{MediaType}}) {
        # (note: these won't be correct now if we haven't yet processed the Media box,
        # but in this case they won't be needed until after we set them properly below)
        ($keysGrp, $keysPath) = ("$avType{$$et{MediaType}}Keys", 'MOV-Movie-Track');
    } else {
        ($keysGrp, $keysPath) = ('Keys', 'MOV-Movie');
    }
    my $curPath = join '-', @{$$et{PATH}};
    my ($dir, $writePath) = ($dirName, $dirName);
    $writePath = "$dir-$writePath" while defined($dir = $$et{DirMap}{$dir});
    # hack to create Keys directories if necessary (its containing Meta is in a different location)
    if (($$addDirs{Keys} and $curPath =~ /^MOV-Movie(-Meta)?$/)) {
        $createKeys = 1;    # create new Keys directories
    } elsif (($$addDirs{AudioKeys} or $$addDirs{VideoKeys}) and $curPath =~ /^MOV-Movie-Track(-Meta)?$/) {
        $createKeys = -1;   # (must wait until MediaType is known)
    } elsif (($curPath eq 'MOV-Movie-Meta-ItemList') or
             ($curPath eq 'MOV-Movie-Track-Meta-ItemList' and $avType{$$et{MediaType}}))
    {
        $createKeys = 2;    # create new Keys tags
        my $keys = $$et{$keysGrp};
        if ($keys) {
            # add new tag entries for existing Keys tags, now that we know their ID's
            # - first make lookup to convert Keys tagInfo ref to index number
            my ($index, %keysInfo);
            foreach $index (keys %{$$keys{Info}}) {
                $keysInfo{$$keys{Info}{$index}} = $index if $$keys{Remap}{$index};
            }
            my $keysTable = GetTagTable("Image::ExifTool::QuickTime::$keysGrp");
            my $newKeysTags = $et->GetNewTagInfoHash($keysTable);
            foreach (keys %$newKeysTags) {
                my $tagInfo = $$newKeysTags{$_};
                $index = $keysInfo{$tagInfo} || ($$tagInfo{SrcTagInfo} and $keysInfo{$$tagInfo{SrcTagInfo}});
                next unless $index;
                my $id = Set32u($index);
                if ($$tagInfo{LangCode}) {
                    # add to lookup of language tags we are writing with this ID
                    $langTags{$id} = { } unless $langTags{$id};
                    $langTags{$id}{$_} = $tagInfo;
                    $id .= '-' . $$tagInfo{LangCode};
                }
                $$newTags{$id} = $tagInfo;
            }
        }
    } else {
        # get hash of new tags to edit/create in this directory
        $newTags = $et->GetNewTagInfoHash($tagTablePtr);
        # make lookup of language tags for each ID
        foreach (keys %$newTags) {
            next unless $$newTags{$_}{LangCode} and $$newTags{$_}{SrcTagInfo};
            my $id = $$newTags{$_}{SrcTagInfo}{TagID};
            $langTags{$id} = { } unless $langTags{$id};
            $langTags{$id}{$_} = $$newTags{$_};
        }
    }
    if ($curPath eq $writePath or $createKeys) {
        $canCreate = 1;
        # (must check the appropriate Keys delete flag if this is a Keys ItemList)
        $delGrp = $$et{DEL_GROUP}{$createKeys ? $keysGrp : $dirName};
    }
    $atomCount = $$tagTablePtr{VARS}{ATOM_COUNT} if $$tagTablePtr{VARS};

    $tag = $lastTag = '';

    for (;;) {      # loop through all atoms at this level
        $lastPos = $raf->Tell();
        # stop processing if we reached a known trailer
        if ($trailer and $lastPos >= $$trailer[1]) {
            $errStr = "Corrupted $$trailer[0] trailer" if $lastPos != $$trailer[1];
            last;
        }
        $lastTag = $tag if $$tagTablePtr{$tag};    # keep track of last known tag
        if (defined $atomCount and --$atomCount < 0 and $dataPt) {
            # stop processing now and just copy the rest of the atom
            Write($outfile, substr($$dataPt, $raf->Tell())) or $rtnVal=$rtnErr, $err=1;
            last;
        }
        my ($hdr, $buff, $keysIndex);
        my $n = $raf->Read($hdr, 8);
        unless ($n == 8) {
            if ($n == 4 and $hdr eq "\0\0\0\0") {
                # "for historical reasons" the udta is optionally terminated by 4 zeros (ref 1)
                # --> hold this terminator to the end
                $term = $hdr;
            } elsif ($n != 0) {
                # warn unless this is 1-3 pad bytes
                $et->Error("Unknown $n bytes at end of file", 1) if $n > 3 or $hdr ne "\0" x $n;
            }
            last;
        }
        my $size = Get32u(\$hdr, 0) - 8;    # (atom size without 8-byte header)
        $tag = substr($hdr, 4, 4);
        if ($size == -7) {
            # read the extended size
            $raf->Read($buff, 8) == 8 or $errStr = 'Truncated extended atom', last;
            $hdr .= $buff;
            my ($hi, $lo) = unpack('NN', $buff);
            if ($hi or $lo > 0x7fffffff) {
                if ($hi > 0x7fffffff) {
                    $errStr = 'Invalid atom size';
                    last;
                } elsif (not $et->Options('LargeFileSupport')) {
                    $et->Error('End of processing at large atom (LargeFileSupport not enabled)');
                    last;
                } elsif ($et->Options('LargeFileSupport') eq '2') {
                    $et->Warn('Processing large atom (LargeFileSupport is 2)');
                }
            }
            $size = $hi * 4294967296 + $lo - 16;
            $size < 0 and $errStr = 'Invalid extended atom size', last;
        } elsif ($size == -8) {
            if ($dataPt) {
                last if $$dirInfo{DirName} eq 'CanonCNTH';  # (this is normal for Canon CNTH atom)
                my $pos = $raf->Tell() - 4;
                $raf->Seek(0,2);
                my $str = $$dirInfo{DirName} . ' with ' . ($raf->Tell() - $pos) . ' bytes';
                $et->Error("Terminator found in $str remaining", 1);
            } else {
                # size of zero is only valid for top-level atom, and
                # indicates the atom extends to the end of file
                # (save in mdat list to write later; with zero end position to copy rest of file)
                push @mdat, [ $raf->Tell(), 0, $hdr ];
            }
            last;
        } elsif ($size < 0) {
            $errStr = 'Invalid atom size';
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
            if ($size) {
                $et->Warn("Incorrect size for 'wide' atom ($size bytes)");
                $raf->Seek($size, 1) or $et->Error('Truncated wide atom');
            }
            next;   # drop 'wide' tag
        }

        # read the atom data
        my $got;
        if (not $size) {
            $buff = '';
            $got = 0;
        } else {
            # read the atom data (but only first 64kB if data is huge)
            $got = $raf->Read($buff, $size > $maxReadLen ? 0x10000 : $size);
        }
        if ($got != $size) {
            # ignore up to 256 bytes of garbage at end of file
            if ($got <= 256 and $size >= 1024 and $tag ne 'mdat') {
                my $bytes = $got + length $hdr;
                if ($$et{OPTIONS}{IgnoreMinorErrors}) {
                    $et->Warn("Deleted garbage at end of file ($bytes bytes)");
                    $buff = $hdr = '';
                } else {
                    $et->Error("Possible garbage at end of file ($bytes bytes)", 1);
                    return $rtnVal;
                }
            } else {
                $tag = PrintableTagID($tag,3);
                if ($size > $maxReadLen and $got == 0x10000) {
                    my $mb = int($size / 0x100000 + 0.5);
                    $errStr = "'${tag}' atom is too large for rewriting ($mb MB)";
                } else {
                    $errStr = "Truncated '${tag}' atom";
                }
                last;
            }
        }
        # save the handler type of the track media
        if ($tag eq 'hdlr' and length $buff >= 12 and
            @{$$et{PATH}} and $$et{PATH}[-1] eq 'Media')
        {
            $$et{MediaType} = substr($buff,8,4);
        }
        # if this atom stores offsets, save its location so we can fix up offsets later
        # (are there any other atoms that may store absolute file offsets?)
        if ($tag =~ /^(stco|co64|iloc|mfra|moof|sidx|saio|gps |CTBO|uuid)$/) {
            # (note that we only need to do this if the media data is stored in this file)
            my $flg = $$et{QtDataFlg};
            if ($tag eq 'mfra' or $tag eq 'moof') {
                $et->Error("Can't yet handle movie fragments when writing");
                return $rtnVal;
            } elsif ($tag eq 'sidx' or $tag eq 'saio') {
                $et->Error("Can't yet handle $tag box when writing");
                return $rtnVal;
            } elsif ($tag eq 'iloc') {
                Handle_iloc($et, $dirInfo, \$buff, $outfile) or $et->Error('Error parsing iloc atom');
            } elsif ($tag eq 'gps ') {
                # (only care about the 'gps ' box in 'moov')
                if ($$dirInfo{DirID} and $$dirInfo{DirID} eq 'moov' and length $buff > 8) {
                    my $off = $$dirInfo{ChunkOffset};
                    my $num = Get32u(\$buff, 4);
                    $num = int((length($buff) - 8) / 8) if $num * 8 + 8 > length($buff);
                    my $i;
                    for ($i=0; $i<$num; ++$i) {
                        push @$off, [ 'stco_gps ', length($$outfile) + length($hdr) + 8 + $i * 8, 4 ];
                    }
                }
            } elsif ($tag eq 'CTBO' or $tag eq 'uuid') { # hack for updating CR3 CTBO offsets
                push @{$$dirInfo{ChunkOffset}}, [ $tag, length($$outfile), length($hdr) + $size ];
            } elsif (not $flg or $flg == 1) {
                # assume "1" if stsd is yet to be read
                $flg or $$et{AssumedDataRef} = 1;
                # must update offsets since the data is in this file
                push @{$$dirInfo{ChunkOffset}}, [ $tag, length($$outfile) + length($hdr), $size ];
            } elsif ($flg == 3) {
                $et->Error("Can't write files with mixed internal/external media data");
                return $rtnVal;
            }
        }

        # rewrite this atom
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag, \$buff);

        # call write hook if it exists
        &{$$tagInfo{WriteHook}}($buff,$et) if $tagInfo and $$tagInfo{WriteHook};

        # allow numerical tag ID's (ItemList entries defined by Keys)
        if (not $tagInfo and $dirName eq 'ItemList' and $$et{$keysGrp}) {
            $keysIndex = unpack('N', $tag);
            my $newIndex = $$et{$keysGrp}{Remap}{$keysIndex};
            if (defined $newIndex) {
                $tagInfo = $$et{$keysGrp}{Info}{$keysIndex};
                unless ($newIndex) {
                    if ($tagInfo) {
                        $et->VPrint(1,"    - Keys:$$tagInfo{Name}");
                    } else {
                        $delCount = ($delCount || 0) + 1;
                    }
                    ++$$et{CHANGED};
                    next;
                }
                # use the new Keys index of this item if it changed
                unless ($keysIndex == $newIndex) {
                    $tag = Set32u($newIndex);
                    substr($hdr, 4, 4) = $tag;
                }
            } else {
                undef $keysIndex;
            }
        }
        # delete all ItemList tags when deleting group, but take care not to delete UserData Meta
        if ($delGrp) {
            if ($dirName eq 'ItemList') {
                $delCount = ($delCount || 0) + 1;
                ++$$et{CHANGED};
                next;
            } elsif ($dirName eq 'UserData' and (not $tagInfo or not $$tagInfo{SubDirectory})) {
                $delCount = ($delCount || 0) + 1;
                ++$$et{CHANGED};
                next;
            }
        }
        undef $tagInfo if $tagInfo and $$tagInfo{AddedUnknown};

        if ($tagInfo and (not defined $$tagInfo{Writable} or $$tagInfo{Writable})) {
            my $subdir = $$tagInfo{SubDirectory};
            my ($newData, @chunkOffset);

            if ($subdir) {  # process atoms in this container from a buffer in memory

                if ($tag eq 'trak') {
                    $$et{MediaType} = '';  # init media type for this track
                    delete $$et{AssumedDataRef};
                }
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
                    TagInfo  => $tagInfo,
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
                    NoRefTest=> 1,     # don't check directory references
                    WriteGroup => $$tagInfo{WriteGroup},
                    # initialize array to hold details about chunk offset table
                    # (each entry has 3-5 items: 0=atom type, 1=table offset, 2=table size,
                    #  3=optional base offset, 4=optional item ID)
                    ChunkOffset => \@chunkOffset,
                );
                # set InPlace flag so XMP will be padded properly when
                # QuickTimePad is used if this is an XMP directory
                $subdirInfo{InPlace} = 2 if $et->Options('QuickTimePad');
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
                if (defined $newData and not length $newData and ($$tagInfo{Permanent} or
                    ($$tagTablePtr{PERMANENT} and not defined $$tagInfo{Permanent})))
                {
                    # do nothing if trying to delete tag from a PERMANENT table
                    $$et{CHANGED} = $oldChanged;
                    undef $newData;
                }
                if ($tag eq 'trak') {
                    $$et{MediaType} = '';     # reset media type at end of track
                    if ($$et{AssumedDataRef}) {
                        my $grp = $$et{CUR_WRITE_GROUP} || $dirName;
                        $et->Error("Can't locate data reference to update offsets for $grp");
                        delete $$et{AssumedDataRef};
                    }
                }
                $$et{CUR_WRITE_GROUP} = $oldWriteGroup;
                SetByteOrder('MM');
                # add back header if necessary
                if ($start and defined $newData and (length $newData or
                    (defined $$tagInfo{Permanent} and not $$tagInfo{Permanent})))
                {
                    $newData = substr($buff,0,$start) . $newData;
                    $$_[1] += $start foreach @chunkOffset;
                }
                # the directory exists, so we don't need to add it
                if ($curPath eq $writePath and $$addDirs{$subName} and $$addDirs{$subName} eq $dirName) {
                    delete $$addDirs{$subName};
                }
                $didDir{$tag} = 1; # (note: keyed by tag ID)

            } else {    # modify existing QuickTime tags in various formats

                my $nvHash = $et->GetNewValueHash($tagInfo);
                if ($nvHash or $langTags{$tag} or $delGrp) {
                    my $nvHashNoLang = $nvHash;
                    my ($val, $len, $lang, $type, $flags, $ctry, $charsetQuickTime);
                    my $format = $$tagInfo{Format};
                    my $hasData = ($$dirInfo{HasData} and $buff =~ /\0...data\0/s);
                    my $langInfo = $tagInfo;
                    if ($hasData) {
                        my $pos = 0;
                        for (;;$pos+=$len) {
                            if ($pos + 16 > $size) {
                                # add any new alternate language tags now
                                if ($langTags{$tag}) {
                                    my $tg;
                                    foreach $tg ('', sort keys %{$langTags{$tag}}) {
                                        my $ti = $tg ? $langTags{$tag}{$tg} : $nvHashNoLang;
                                        $nvHash = $et->GetNewValueHash($ti);
                                        next unless $nvHash and not $$didTag{$nvHash};
                                        $$didTag{$nvHash} = 1;
                                        next unless $$nvHash{IsCreating} and $et->IsOverwriting($nvHash);
                                        my $newVal = $et->GetNewValue($nvHash);
                                        next unless defined $newVal;
                                        my $prVal = $newVal;
                                        my $flags = FormatQTValue($et, \$newVal, $tagInfo, $format);
                                        next unless defined $newVal;
                                        my ($ctry, $lang) = (0, 0);
                                        if ($$ti{LangCode}) {
                                            unless ($$ti{LangCode} =~ /^([A-Z]{3})?[-_]?([A-Z]{2})?$/i) {
                                                $et->Warn("Invalid language code for $$ti{Name}");
                                                next;
                                            }
                                            # pack language and country codes
                                            if ($1 and $1 ne 'und') {
                                                $lang = ($lang << 5) | ($_ - 0x60) foreach unpack 'C*', lc($1);
                                            }
                                            $ctry = unpack('n', pack('a2',uc($2))) if $2 and $2 ne 'ZZ';
                                        }
                                        $newData = substr($buff, 0, $pos) unless defined $newData;
                                        $newData .= pack('Na4Nnn',16+length($newVal),'data',$flags,$ctry,$lang).$newVal;
                                        my $grp = $et->GetGroup($ti, 1);
                                        $et->VerboseValue("+ $grp:$$ti{Name}", $prVal);
                                        ++$$et{CHANGED};
                                    }
                                }
                                last;
                            }
                            ($len, $type, $flags, $ctry, $lang) = unpack("x${pos}Na4Nnn", $buff);
                            $lang or $lang = $undLang;  # treat both 0 and 'und' as 'und'
                            $langInfo = $tagInfo;
                            my $delTag = $delGrp;
                            my $newVal;
                            my $langCode = GetLangCode($lang, $ctry, 1);
                            for (;;) {
                                $langInfo = GetLangInfo($tagInfo, $langCode);
                                $nvHash = $et->GetNewValueHash($langInfo);
                                last if $nvHash or not $ctry or $lang ne $undLang or length($langCode)==2;
                                # check to see if tag was written with a 2-char country code only
                                $langCode = lc unpack('a2',pack('n',$ctry));
                            }
                            # set flag to delete language tag when writing default
                            # (except for a default-language Keys entry)
                            if (not $nvHash and $nvHashNoLang) {
                                if ($lang eq $undLang and not $ctry and not $$didTag{$nvHashNoLang}) {
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
                                    if ($format) {
                                        # update flags for the format we are writing
                                        if ($$tagInfo{Writable} and $qtFormat{$$tagInfo{Writable}}) {
                                            $flags = $qtFormat{$$tagInfo{Writable}};
                                        } elsif ($qtFormat{$format}) {
                                            $flags = $qtFormat{$format};
                                        }
                                    } else {
                                        $format = QuickTimeFormat($flags, $len);
                                    }
                                    $val = ReadValue(\$val, 0, $format, $$tagInfo{Count}, $len) if $format;
                                }
                                if (($nvHash and $et->IsOverwriting($nvHash, $val)) or $delTag) {
                                    $newVal = $et->GetNewValue($nvHash) if defined $nvHash;
                                    if ($delTag or not defined $newVal or $$didTag{$nvHash}) {
                                        # delete the tag
                                        my $grp = $et->GetGroup($langInfo, 1);
                                        $et->VerboseValue("- $grp:$$langInfo{Name}", $val);
                                        # copy data up to start of this tag to delete this value
                                        $newData = substr($buff, 0, $pos-16) unless defined $newData;
                                        ++$$et{CHANGED};
                                        next;
                                    }
                                    my $prVal = $newVal;
                                    # format new value for writing (and get new flags)
                                    $flags = FormatQTValue($et, \$newVal, $tagInfo, $format);
                                    next unless defined $newVal;
                                    my $grp = $et->GetGroup($langInfo, 1);
                                    $et->VerboseValue("- $grp:$$langInfo{Name}", $val);
                                    $et->VerboseValue("+ $grp:$$langInfo{Name}", $prVal);
                                    $newData = substr($buff, 0, $pos-16) unless defined $newData;
                                    my $wLang = $lang eq $undLang ? 0 : $lang;
                                    $newData .= pack('Na4Nnn', length($newVal)+16, $type, $flags, $ctry, $wLang);
                                    $newData .= $newVal;
                                    ++$$et{CHANGED};
                                } elsif (defined $newData) {
                                    $newData .= substr($buff, $pos-16, $len+16);
                                }
                            } elsif (defined $newData) {
                                $newData .= substr($buff, $pos, $len);
                            }
                            $$didTag{$nvHash} = 1 if $nvHash;
                        }
                        $newData .= substr($buff, $pos) if defined $newData and $pos < $size;
                        undef $val; # (already constructed $newData)
                    } elsif ($format) {
                        $val = ReadValue(\$buff, 0, $format, undef, $size);
                    } elsif (($tag =~ /^\xa9/ or $$tagInfo{IText}) and $size >= ($$tagInfo{IText} || 4)) {
                        my $hdr;
                        if ($$tagInfo{IText} and $$tagInfo{IText} >= 6) {
                            my $iText = $$tagInfo{IText};
                            my $pos = $iText - 2;
                            $lang = unpack("x${pos}n", $buff);
                            $hdr = substr($buff,4,$iText-6);
                            $len = $size - $iText;
                            $val = substr($buff, $iText, $len);
                        } else {
                            ($len, $lang) = unpack('nn', $buff);
                            $len -= 4 if 4 + $len > $size; # (see QuickTime.pm for explanation)
                            $len = $size - 4 if $len > $size - 4 or $len < 0;
                            $val = substr($buff, 4, $len);
                        }
                        $lang or $lang = $undLang;  # treat both 0 and 'und' as 'und'
                        my $enc;
                        if ($lang < 0x400 and $val !~ /^\xfe\xff/) {
                            $charsetQuickTime = $et->Options('CharsetQuickTime');
                            $enc = $charsetQuickTime;
                        } else {
                            $enc = $val=~s/^\xfe\xff// ? 'UTF16' : 'UTF8';
                        }
                        unless ($$tagInfo{NoDecode}) {
                            $val = $et->Decode($val, $enc);
                            $val =~ s/\0+$//;   # remove trailing nulls if they exist
                        }
                        $val = $hdr . $val if defined $hdr;
                        my $langCode = UnpackLang($lang, 1);
                        $langInfo = GetLangInfo($tagInfo, $langCode);
                        $nvHash = $et->GetNewValueHash($langInfo);
                        if (not $nvHash and $nvHashNoLang) {
                            if ($lang eq $undLang and not $$didTag{$nvHashNoLang}) {
                                $nvHash = $nvHashNoLang;
                            } elsif ($canCreate) {
                                # delete other languages when writing default
                                my $grp = $et->GetGroup($langInfo, 1);
                                $et->VerboseValue("- $grp:$$langInfo{Name}", $val);
                                ++$$et{CHANGED};
                                next;
                            }
                        }
                    } else {
                        $val = $buff;
                        if ($tag =~ /^\xa9/ or $$tagInfo{IText}) {
                            $et->Warn("Corrupted $$tagInfo{Name} value");
                        }
                    }
                    if ($nvHash and defined $val) {
                        if ($et->IsOverwriting($nvHash, $val)) {
                            $newData = $et->GetNewValue($nvHash);
                            $newData = '' unless defined $newData or $canCreate;
                            ++$$et{CHANGED};
                            my $grp = $et->GetGroup($langInfo, 1);
                            $et->VerboseValue("- $grp:$$langInfo{Name}", $val);
                            next unless defined $newData and not $$didTag{$nvHash};
                            $et->VerboseValue("+ $grp:$$langInfo{Name}", $newData);
                            # add back necessary header and encode as necessary
                            if (defined $lang) {
                                my $iText = $$tagInfo{IText} || 0;
                                my $hdr;
                                if ($iText > 6) {
                                    $newData .= ' 'x($iText-6) if length($newData) < $iText-6;
                                    $hdr = substr($newData, 0, $iText-6);
                                    $newData = substr($newData, $iText-6);
                                }
                                unless ($$tagInfo{NoDecode}) {
                                    $newData = $et->Encode($newData, $lang < 0x400 ? $charsetQuickTime : 'UTF8');
                                }
                                my $wLang = $lang eq $undLang ? 0 : $lang;
                                if ($iText < 6) {
                                    $newData = pack('nn', length($newData), $wLang) . $newData;
                                } elsif ($iText == 6) {
                                    $newData = pack('Nn', 0, $wLang) . $newData . "\0";
                                } else {
                                    $newData = "\0\0\0\0" . $hdr . pack('n', $wLang) . $newData . "\0";
                                }
                            } elsif (not $format or $format =~ /^string/ and
                                     not $$tagInfo{Binary} and not $$tagInfo{ValueConv})
                            {
                                # write all strings as UTF-8
                                $newData = $et->Encode($newData, 'UTF8');
                            } elsif ($format and not $$tagInfo{Binary}) {
                                # format new value for writing
                                $newData = WriteValue($newData, $format);
                            }
                        }
                        $$didTag{$nvHash} = 1;   # set flag so we don't add this tag again
                    }
                }
            }
            # write the new atom if it was modified
            if (defined $newData) {
                my $sizeDiff = length($buff) - length($newData);
                # pad to original size if specified, otherwise give verbose message about the changed size
                if ($sizeDiff > 0 and $$tagInfo{PreservePadding} and $et->Options('QuickTimePad')) {
                    $newData .= "\0" x $sizeDiff;
                    $et->VPrint(1, "    ($$tagInfo{Name} padded to original size)");
                } elsif ($sizeDiff) {
                    $et->VPrint(1, "    ($$tagInfo{Name} changed size)");
                }
                my $len = length($newData) + 8;
                $len > 0x7fffffff and $et->Error("$$tagInfo{Name} to large to write"), last;
                # update size in ChunkOffset list for modified 'uuid' atom
                $$dirInfo{ChunkOffset}[-1][2] = $len if $tag eq 'uuid';
                next unless $len > 8;   # don't write empty atom header
                # maintain pointer to chunk offsets if necessary
                if (@chunkOffset) {
                    $$_[1] += 8 + length $$outfile foreach @chunkOffset;
                    push @{$$dirInfo{ChunkOffset}}, @chunkOffset;
                }
                if ($$tagInfo{WriteLast}) {
                    $writeLast = ($writeLast || '') . Set32u($len) . $tag . $newData;
                } else {
                    $boxPos{$tag} = [ length($$outfile), length($newData) + 8 ];
                    # write the updated directory with its atom header
                    Write($outfile, Set32u($len), $tag, $newData) or $rtnVal=$rtnErr, $err=1, last;
                }
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
            my ($i, $msg);
            for ($i=0; $i<$n; ++$i) {       # loop through sample descriptions
                $pos + 16 <= length($buff) or $msg = 'Truncated sample table', last;
                my $siz = Get32u(\$buff, $pos);
                $pos + $siz <= length($buff) or $msg = 'Truncated sample table', last;
                my $drefIdx = Get16u(\$buff, $pos + 14);
                my $drefTbl = $$et{QtDataRef};
                if (not $drefIdx) {
                    $flg |= 0x01;   # in this file if data reference index is 0 (if like iloc)
                } elsif ($drefTbl and $$drefTbl[$drefIdx-1]) {
                    my $dref = $$drefTbl[$drefIdx-1];
                    # $flg = 0x01-in this file, 0x02-in some other file
                    $flg |= ($$dref[1] == 1 and $$dref[0] ne 'rsrc') ? 0x01 : 0x02;
                } else {
                    $msg = "No data reference for sample description $i";
                    last;
                }
                $pos += $siz;
            }
            if ($msg) {
                # (allow empty sample description for non-audio/video handler types, eg. 'url ', 'meta')
                if ($$et{MediaType}) {
                    my $grp = $$et{CUR_WRITE_GROUP} || $parent;
                    $et->Error("$msg for $grp");
                    return $rtnErr;
                }
                $flg = 1; # (this seems to be the case)
            }
            $$et{QtDataFlg} = $flg;
            if ($$et{AssumedDataRef}) {
                if ($flg != $$et{AssumedDataRef}) {
                    my $grp = $$et{CUR_WRITE_GROUP} || $parent;
                    $et->Error("Assumed incorrect data reference for $grp (was $flg)");
                }
                delete $$et{AssumedDataRef};
            }
        }
        if ($tagInfo and $$tagInfo{WriteLast}) {
            $writeLast = ($writeLast || '') . $hdr . $buff;
        } else {
            # save position of this box in the output buffer
#TODO do this:
#TODO            my $bp = $boxPos{$tag} || ($boxPos{$tag} = [ ]);
#TODO            push @$bp, length($$outfile), length($hdr) + length($buff);
#TODO instead of this:
            $boxPos{$tag} = [ length($$outfile), length($hdr) + length($buff) ];
#TODO then we have the positions of all the infe boxes -- we then only need
#TODO to know the index of the box to edit if the encoding changes for one of them
            # copy the existing atom
            Write($outfile, $hdr, $buff) or $rtnVal=$rtnErr, $err=1, last;
        }
    }
    # ($errStr is set if there was an error that could possibly be due to an unknown trailer)
    if ($errStr) {
        if (($lastTag eq 'mdat' or $lastTag eq 'moov') and not $dataPt and (not $$tagTablePtr{$tag} or
            ref $$tagTablePtr{$tag} eq 'HASH' and $$tagTablePtr{$tag}{Unknown}))
        {
            # identify other known trailers from their first bytes
            $buf2 = '';
            $raf->Seek($lastPos,0) and $raf->Read($buf2,8);
            my ($type, $len);
            if ($buf2 eq 'CCCCCCCC') {
                $type = 'Kenwood';
            } elsif ($buf2 =~ /^(gpsa|gps0|gsen|gsea)...\0/s) {
                $type = 'RIFF';
            } else {
                $type = 'Unknown';
            }
            # determine length of this trailer
            if ($trailer) {
                $len = $$trailer[1] - $lastPos; # runs to start of next trailer
            } else {
                $raf->Seek(0, 2) or $et->Error('Seek error'), return $dataPt ? undef : 1;
                $len = $raf->Tell() - $lastPos; # runs to end of file
            }
            # add to start of linked list of trailers
            $trailer = [ $type, $lastPos, $len, $trailer ];
        } else {
            $et->Error($errStr);
            return $dataPt ? undef : 1;
        }
    }
    $et->VPrint(0, "  [deleting $delCount $dirName tag".($delCount==1 ? '' : 's')."]\n") if $delCount;

    # can finally set necessary variables for creating Video/AudioKeys tags
    if ($createKeys < 0) {
        if ($avType{$$et{MediaType}}) {
            $createKeys = 1;
            ($keysGrp, $keysPath) = ("$avType{$$et{MediaType}}Keys", 'MOV-Movie-Track');
        } else {
            $canCreate = 0;
        }
    }
    $createKeys &= ~0x01 unless $$addDirs{$keysGrp};   # (Keys may have been written)

    # add new directories/tags at this level if necessary
    if ($canCreate and (exists $$et{EDIT_DIRS}{$dirName} or $createKeys)) {
        # get a hash of tagInfo references to add to this directory
        my $dirs = $et->GetAddDirHash($tagTablePtr, $dirName);
        # make sorted list of new tags to be added
        my @addTags = sort(keys(%$dirs), keys %$newTags);
        my ($tag, $index);
        # add Keys tags if necessary
        if ($createKeys) {
            if ($curPath eq $keysPath) {
                # add Meta for Keys if necessary
                unless ($didDir{meta}) {
                    $$dirs{meta} = $Image::ExifTool::QuickTime::Movie{meta};
                    push @addTags, 'meta';
                }
            } elsif ($curPath eq "$keysPath-Meta") {
                # special case for Keys Meta -- reset directories and start again
                undef @addTags;
                $dirs = { };
                foreach ('keys','ilst') {
                    next if $didDir{$_};  # don't add again
                    $$dirs{$_} = $Image::ExifTool::QuickTime::Meta{$_};
                    push @addTags, $_;
                }
            } elsif ($curPath eq "$keysPath-Meta-ItemList" and $$et{$keysGrp}) {
                foreach $index (sort { $a <=> $b } keys %{$$et{$keysGrp}{Add}}) {
                    my $id = Set32u($index);
                    $$newTags{$id} = $$et{$keysGrp}{Add}{$index};
                    push @addTags, $id;
                }
            } else {
                $dirs = $et->GetAddDirHash($tagTablePtr, $dirName);
                push @addTags, sort keys %$dirs;
            }
        }
        # (note that $tag may be a binary Keys index here)
        foreach $tag (@addTags) {
            my $tagInfo = $$dirs{$tag} || $$newTags{$tag};
            next if defined $$tagInfo{CanCreate} and not $$tagInfo{CanCreate};
            next if defined $$tagInfo{MediaType} and $$et{MediaType} ne $$tagInfo{MediaType};
            my $subdir = $$tagInfo{SubDirectory};
            unless ($subdir) {
                my $nvHash = $et->GetNewValueHash($tagInfo);
                next unless $nvHash and not $$didTag{$nvHash};
                next unless $$nvHash{IsCreating} and $et->IsOverwriting($nvHash);
                my $newVal = $et->GetNewValue($nvHash);
                next unless defined $newVal;
                my $prVal = $newVal;
                my $flags = FormatQTValue($et, \$newVal, $tagInfo);
                next unless defined $newVal;
                my ($ctry, $lang) = (0, 0);
                # handle alternate languages
                if ($$tagInfo{LangCode}) {
                    $tag = substr($tag, 0, 4);  # strip language code from tag ID
                    unless ($$tagInfo{LangCode} =~ /^([A-Z]{3})?[-_]?([A-Z]{2})?$/i) {
                        $et->Warn("Invalid language code for $$tagInfo{Name}");
                        next;
                    }
                    # pack language and country codes
                    if ($1 and $1 ne 'und') {
                        $lang = ($lang << 5) | ($_ - 0x60) foreach unpack 'C*', lc($1);
                    }
                    $ctry = unpack('n', pack('a2',uc($2))) if $2 and $2 ne 'ZZ';
                }
                if ($$dirInfo{HasData}) {
                    # add 'data' header
                    $newVal = pack('Na4Nnn',16+length($newVal),'data',$flags,$ctry,$lang).$newVal;
                } elsif ($tag =~ /^\xa9/ or $$tagInfo{IText}) {
                    if ($ctry) {
                        my $grp = $et->GetGroup($tagInfo,1);
                        $et->Warn("Can't use country code for $grp:$$tagInfo{Name}");
                        next;
                    } elsif ($$tagInfo{IText} and $$tagInfo{IText} >= 6) {
                        # add 6-byte langText header and trailing null
                        # (with extra junk before language code if IText > 6)
                        my $n = $$tagInfo{IText} - 6;
                        $newVal .= ' ' x $n if length($newVal) < $n;
                        $newVal = "\0\0\0\0" . substr($newVal,0,$n) . pack('n',0,$lang) . substr($newVal,$n) . "\0";
                    } else {
                        # add IText header
                        $newVal = pack('nn',length($newVal),$lang) . $newVal;
                    }
                } elsif ($ctry or $lang) {
                    my $grp = $et->GetGroup($tagInfo,1);
                    $et->Warn("Can't use language code for $grp:$$tagInfo{Name}");
                    next;
                }
                if ($$tagInfo{WriteLast}) {
                    $writeLast = ($writeLast || '') .  Set32u(8+length($newVal)) . $tag . $newVal;
                } else {
                    $boxPos{$tag} = [ length($$outfile), 8 + length($newVal) ];
                    Write($outfile, Set32u(8+length($newVal)), $tag, $newVal) or $rtnVal=$rtnErr, $err=1;
                }
                my $grp = $et->GetGroup($tagInfo, 1);
                $et->VerboseValue("+ $grp:$$tagInfo{Name}", $prVal);
                $$didTag{$nvHash} = 1;
                ++$$et{CHANGED};
                next;
            }
            my $subName = $$subdir{DirName} || $$tagInfo{Name};
            # QuickTime hierarchy is complex, so check full directory path before adding
            if ($createKeys and $curPath eq $keysPath and $subName eq 'Meta') {
                $et->VPrint(0, "  Creating Meta with mdta Handler and Keys\n");
                # init Meta box for Keys tags with mdta Handler and empty Keys+ItemList
                $buf2 = "\0\0\0\x20hdlr\0\0\0\0\0\0\0\0mdta\0\0\0\0\0\0\0\0\0\0\0\0" .
                        "\0\0\0\x10keys\0\0\0\0\0\0\0\0" .
                        "\0\0\0\x08ilst";
            } elsif ($createKeys and $curPath eq "$keysPath-Meta") {
                $buf2 = ($subName eq 'Keys' ? "\0\0\0\0\0\0\0\0" : '');
            } elsif ($subName eq 'Meta' and $$et{OPTIONS}{QuickTimeHandler}) {
                $et->VPrint(0, "  Creating Meta with mdir Handler\n");
                # init Meta box for ItemList tags with mdir Handler
                $buf2 = "\0\0\0\x20hdlr\0\0\0\0\0\0\0\0mdir\0\0\0\0\0\0\0\0\0\0\0\0";
            } else {
                next unless $curPath eq $writePath and $$addDirs{$subName} and $$addDirs{$subName} eq $dirName;
                $buf2 = '';  # write from scratch
            }
            my %subdirInfo = (
                Parent   => $dirName,
                DirName  => $subName,
                DataPt   => \$buf2,
                DirStart => 0,
                HasData  => $$subdir{HasData},
                OutFile  => $outfile,
                ChunkOffset => [ ], # (just to be safe)
                WriteGroup => $$tagInfo{WriteGroup},
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
                if ($$tagInfo{WriteLast}) {
                    $writeLast = ($writeLast || '') . $newHdr . $newData;
                } else {
                    if ($tag eq 'uuid') {
                        # add offset for new uuid (needed for CR3 CTBO offsets)
                        my $off = $$dirInfo{ChunkOffset};
                        push @$off, [ $tag, length($$outfile), length($newHdr) + length($newData) ];
                    }
                    $boxPos{$tag} = [ length($$outfile), length($newHdr) + length($newData) ];
                    Write($outfile, $newHdr, $newData) or $rtnVal=$rtnErr, $err=1;
                }
            }
            # add only once (must delete _after_ call to WriteDirectory())
            # (Keys tags are a special case, and are handled separately)
            delete $$addDirs{$subName} unless $createKeys;
        }
    }
    # write HEIC metadata after top-level 'meta' box has been processed if editing this information
    if ($curPath eq 'MOV-Meta' and $$et{EDIT_DIRS}{ItemInformation}) {
        $$dirInfo{BoxPos} = \%boxPos;
        my $mdatEdit = WriteItemInfo($et, $dirInfo, $outfile);
        if ($mdatEdit) {
            $et->Error('Multiple top-level Meta containers') if $$et{mdatEdit};
            $$et{mdatEdit} = $mdatEdit;
        }
    }
    # write out any necessary terminator
    Write($outfile, $term) or $rtnVal=$rtnErr, $err=1 if $term and length $$outfile;

    # delete temporary Keys variables after Meta is processed
    if ($dirName eq 'Meta') {
        # delete any Meta box with no useful information (ie. only 'hdlr','keys','lang','ctry')
        my $isEmpty = 1;
        $emptyMeta{$_} or $isEmpty = 0, last foreach keys %boxPos;
        if ($isEmpty) {
            $et->VPrint(0,'  Deleting ' . join('+', sort map { $emptyMeta{$_} } keys %boxPos)) if %boxPos;
            $$outfile = '';
            # (could report a file if editing nothing when it contained an empty Meta atom)
            # ++$$et{CHANGED};
        }
        if ($curPath eq "$keysPath-Meta") {
            delete $$addDirs{$keysGrp}; # prevent creation of another Meta for Keys tags
            delete $$et{$keysGrp};
        }
    }

    # return now if writing subdirectory
    if ($dataPt) {
        $et->Error("Internal error: WriteLast not on top-level atom!\n") if $writeLast;
        return $err ? undef : $$outfile;
    }

    # issue minor error if we didn't find an 'mdat' atom
    my $off = $$dirInfo{ChunkOffset};
    if (not @mdat) {
        foreach $co (@$off) {
            next if $$co[0] eq 'uuid';
            $et->Error('Media data referenced but not found');
            return $rtnVal;
        }
        $et->Warn('No media data', 1);
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
                        my $size = Get32u(\$$hdrChunk[2], 0);
                        if ($size) { # (0 size = extends to end of file)
                            $size += $diff;
                            $size > 0xffffffff and $et->Error("Can't yet grow mdat across 4GB boundary"), return $rtnVal;
                            Set32u($size, \$$hdrChunk[2], 0);
                        }
                    } elsif (length($$hdrChunk[2]) == 16) {
                        my $size = Get64u(\$$hdrChunk[2], 8);
                        if ($size) {
                            $size += $diff;
                            Set64u($size, \$$hdrChunk[2], 8);
                        }
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

    # fix up offsets for new mdat position(s) (and uuid positions in CR3 images)
    foreach $co (@$off) {
        my ($type, $ptr, $len, $base, $id) = @$co;
        $base = 0 unless $base;
        unless ($type =~ /^(stco|co64)_?(.*)$/) {
            next if $type eq 'uuid';
            $type eq 'CTBO' or $et->Error('Internal error fixing offsets'), last;
            # update 'CTBO' item offsets/sizes in Canon CR3 images
            $$co[2] > 12 or $et->Error('Invalid CTBO atom'), last;
            @mdat or $et->Error('Missing CR3 image data'), last;
            my $n = Get32u($outfile, $$co[1] + 8);
            $$co[2] < $n * 20 + 12 and $et->Error('Truncated CTBO atom'), last;
            my (%ctboOff, $i);
            # determine uuid types, and build an offset lookup based on CTBO ID number
            foreach (@$off) {
                next unless $$_[0] eq 'uuid' and $$_[2] >= 24; # (ignore undersized and deleted uuid boxes)
                my $pos = $$_[1];
                next if $pos + 24 > length $$outfile;   # (will happen for WriteLast uuid tags)
                my $siz = Get32u($outfile, $pos);       # get size of uuid atom
                if ($siz == 1) {                        # check for extended (8-byte) size
                    next unless $$_[2] >= 32;
                    $pos += 8;
                }
                # get CTBO entry ID based on 16-byte UUID identifier
                my $id = $ctboID{substr($$outfile, $pos+8, 16)};
                $ctboOff{$id} = $_ if defined $id;
            }
            # calculate new offset for the first mdat (size of -1 indicates it didn't change)
            $ctboOff{3} = [ 'mdat', $mdat[0][3] - length $mdat[0][2], -1 ];
            for ($i=0; $i<$n; ++$i) {
                my $pos = $$co[1] + 12 + $i * 20;
                my $id = Get32u($outfile, $pos);
                # ignore if size is zero unless we can add this entry
                # (note: can't yet add/delete PreviewImage, but leave this possibility open)
                next unless Get64u($outfile, $pos + 12) or $id == 1 or $id == 2;
                if (not defined $ctboOff{$id}) {
                    $id==1 or $id==2 or $et->Error("Can't handle CR3 CTBO ID number $id"), last;
                    # XMP or PreviewImage was deleted -- set offset and size to zero
                    $ctboOff{$id} = [ 'uuid', 0, 0 ];
                }
                # update the new offset and size of this entry
                Set64u($ctboOff{$id}[1], $outfile, $pos + 4);
                Set64u($ctboOff{$id}[2], $outfile, $pos + 12) unless $ctboOff{$id}[2] < 0;
            }
            next;
        }
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
                $et->Error("Chunk offset in $tag atom is outside media data");
                return $rtnVal;
            }
        }
    }

    # switch back to actual output file
    $outfile = $$dirInfo{OutFile};

    # write the metadata
    Write($outfile, $outBuff) or $rtnVal = 0;

    # write the media data
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
                while ($raf->Read($buf2, 65536)) {
                    Write($outfile, $buf2) or $rtnVal = 0, last;
                }
            }
        }
    }

    # write the stuff that must come last
    Write($outfile, $writeLast) or $rtnVal = 0 if $writeLast;

    # copy trailers if necessary
    while ($rtnVal and $trailer) {
        # are we deleting the trailers?
        my $nvTrail = $et->GetNewValueHash($Image::ExifTool::Extra{Trailer});
        if ($$et{DEL_GROUP}{Trailer} or $$et{DEL_GROUP}{$$trailer[0]} or
            ($nvTrail and not ($$nvTrail{Value} and $$nvTrail{Value}[0])))
        {
            $et->Warn("Deleted $$trailer[0] trailer", 1);
            ++$$et{CHANGED};
            $trailer = $$trailer[3];
            next;
        }
        $raf->Seek($$trailer[1], 0) or $rtnVal = 0, last;
        if ($$trailer[0] eq 'MIE') {
            require Image::ExifTool::MIE;
            my %dirInfo = ( RAF => $raf, OutFile => $outfile );
            my $result = Image::ExifTool::MIE::ProcessMIE($et, \%dirInfo);
            $result > 0 or $et->Error('Error writing MIE trailer'), $rtnVal = 0, last;
        } else {
            $et->Warn(sprintf('Copying %s trailer from offset 0x%x (%d bytes)', @$trailer[0..2]), 1);
            my $len = $$trailer[2];
            while ($len) {
                my $n = $len > 65536 ? 65536 : $len;
                $raf->Read($buf2, $n) == $n and Write($outfile, $buf2) or $rtnVal = 0, last;
                $len -= $n;
            }
            $rtnVal or $et->Error("Error copying $$trailer[0] trailer"), last;
        }
        $trailer = $$trailer[3];    # step to next trailer in linked list
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
        } elsif ($buff =~ /^(heic|mif1|msf1|heix|hevc|hevx|avif)/) {
            $ftype = 'HEIC';
        } else {
            $ftype = 'MP4';
        }
    } else {
        $ftype = 'MOV';
    }
    $et->SetFileType($ftype); # need to set "FileType" tag for a Condition
    if ($ftype eq 'HEIC') {
        # EXIF is preferred in HEIC files
        $et->InitWriteDirs($dirMap{$ftype}, 'EXIF', 'QuickTime');
    } else {
        $et->InitWriteDirs($dirMap{$ftype}, 'XMP', 'QuickTime');
    }
    $$et{DirMap} = $dirMap{$ftype};     # need access to directory map when writing
    # track tags globally to avoid creating multiple tags in the case of duplicate directories
    $$et{DidTag} = { };
    SetByteOrder('MM');
    $raf->Seek(0,0);

    # write the file
    $$et{MediaType} = '';
    $$dirInfo{Parent} = '';
    $$dirInfo{DirName} = 'MOV';
    $$dirInfo{ChunkOffset} = [ ]; # (just to be safe)
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

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::QuickTime(3pm)|Image::ExifTool::QuickTime>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
