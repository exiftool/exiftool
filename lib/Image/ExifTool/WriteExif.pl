#------------------------------------------------------------------------------
# File:         WriteExif.pl
#
# Description:  Write EXIF meta information
#
# Revisions:    12/13/2004 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Exif;

use strict;
use vars qw($VERSION $AUTOLOAD @formatSize @formatName %formatNumber
            %compression %photometricInterpretation %orientation);

use Image::ExifTool::Fixup;

# some information may be stored in different IFD's with the same meaning.
# Use this lookup to decide when we should delete information that is stored
# in another IFD when we write it to the preferred IFD.
my %crossDelete = (
    ExifIFD => 'IFD0',
    IFD0    => 'ExifIFD',
);

# mandatory tag default values
my %mandatory = (
    IFD0 => {
        0x011a => 72,       # XResolution
        0x011b => 72,       # YResolution
        0x0128 => 2,        # ResolutionUnit (inches)
        0x0213 => 1,        # YCbCrPositioning (centered)
      # 0x8769 => ????,     # ExifOffset
    },
    IFD1 => {
        0x0103 => 6,        # Compression (JPEG)
        0x011a => 72,       # XResolution
        0x011b => 72,       # YResolution
        0x0128 => 2,        # ResolutionUnit (inches)
    },
    ExifIFD => {
        0x9000 => '0232',   # ExifVersion
        0x9101 => "1 2 3 0",# ComponentsConfiguration
        0xa000 => '0100',   # FlashpixVersion
        0xa001 => 0xffff,   # ColorSpace (uncalibrated)
      # 0xa002 => ????,     # ExifImageWidth
      # 0xa003 => ????,     # ExifImageHeight
    },
    GPS => {
        0x0000 => '2 3 0 0',# GPSVersionID
    },
    InteropIFD => {
        0x0002 => '0100',   # InteropVersion
    },
);

#------------------------------------------------------------------------------
# Inverse print conversion for OffsetTime tags
# Inputs: 0) input time zone or date/time value, 1) ExifTool ref
# Returns: Time zone string for writing to EXIF
sub InverseOffsetTime($$)
{
    my ($val, $et) = @_;
    $val = $et->TimeNow() if lc($val) eq 'now';
    return '+00:00' if $val =~ /Z$/;
    return sprintf('%s%.2d:%.2d',$1,$2,$3) if $val =~ /([-+])(\d{1,2}):?(\d{2})/;
    return undef;
}

#------------------------------------------------------------------------------
# Inverse print conversion for LensInfo
# Inputs: 0) lens info string
# Returns: PrintConvInv of string
sub ConvertLensInfo($)
{
    my $val = shift;
    my @a = GetLensInfo($val, 1); # (allow unknown "?" values)
    return @a ? join(' ', @a) : $val;
}

#------------------------------------------------------------------------------
# Get binary CFA Pattern from a text string
# Inputs: Print-converted CFA pattern (eg. '[Blue,Green][Green,Red]')
# Returns: CFA pattern as a string of numbers
sub GetCFAPattern($)
{
    my $val = shift;
    my @rows = split /\]\s*\[/, $val;
    @rows or warn("Rows not properly bracketed by '[]'\n"), return undef;
    my @cols = split /,/, $rows[0];
    @cols or warn("Colors not separated by ','\n"), return undef;
    my $ny = @cols;
    my @a = (scalar(@rows), scalar(@cols));
    my %cfaLookup = (red=>0, green=>1, blue=>2, cyan=>3, magenta=>4, yellow=>5, white=>6);
    my $row;
    foreach $row (@rows) {
        @cols = split /,/, $row;
        @cols == $ny or warn("Inconsistent number of colors in each row\n"), return undef;
        foreach (@cols) {
            tr/ \]\[//d;    # remove remaining brackets and any spaces
            my $c = $cfaLookup{lc($_)};
            defined $c or warn("Unknown color '${_}'\n"), return undef;
            push @a, $c;
        }
    }
    return "@a";
}

#------------------------------------------------------------------------------
# validate raw values for writing
# Inputs: 0) ExifTool ref, 1) tagInfo hash ref, 2) raw value ref
# Returns: error string or undef (and possibly changes value) on success
sub CheckExif($$$)
{
    my ($et, $tagInfo, $valPtr) = @_;
    my $format = $$tagInfo{Format} || $$tagInfo{Writable} || $$tagInfo{Table}{WRITABLE};
    if (not $format or $format eq '1') {
        if ($$tagInfo{Groups}{0} eq 'MakerNotes') {
            return undef;   # OK to have no format for makernotes
        } else {
            return 'No writable format';
        }
    }
    return Image::ExifTool::CheckValue($valPtr, $format, $$tagInfo{Count});
}

#------------------------------------------------------------------------------
# encode exif ASCII/Unicode text from UTF8 or Latin
# Inputs: 0) ExifTool ref, 1) text string
# Returns: encoded string
# Note: MUST be called Raw conversion time so the EXIF byte order is known!
sub EncodeExifText($$)
{
    my ($et, $val) = @_;
    # does the string contain special characters?
    if ($val =~ /[\x80-\xff]/) {
        my $order = $et->GetNewValue('ExifUnicodeByteOrder');
        return "UNICODE\0" . $et->Encode($val,'UTF16',$order);
    } else {
        return "ASCII\0\0\0$val";
    }
}

#------------------------------------------------------------------------------
# rebuild maker notes to properly contain all value data
# (some manufacturers put value data outside maker notes!!)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: new maker note data (and creates MAKER_NOTE_FIXUP), or undef on error
sub RebuildMakerNotes($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $rtnValue;
    my %subdirInfo = %$dirInfo;

    delete $$et{MAKER_NOTE_FIXUP};

    # don't need to rebuild text, BinaryData or PreviewImage maker notes
    my $tagInfo = $$dirInfo{TagInfo};
    my $subdir = $$tagInfo{SubDirectory};
    my $proc = $$subdir{ProcessProc} || $$tagTablePtr{PROCESS_PROC} || \&ProcessExif;
    if (($proc ne \&ProcessExif and $$tagInfo{Name} =~ /Text/) or
         $proc eq \&Image::ExifTool::ProcessBinaryData or
        ($$tagInfo{PossiblePreview} and $dirLen > 6 and
         substr($$dataPt, $dirStart, 3) eq "\xff\xd8\xff"))
    {
        return substr($$dataPt, $dirStart, $dirLen);
    }
    my $saveOrder = GetByteOrder();
    my $loc = Image::ExifTool::MakerNotes::LocateIFD($et,\%subdirInfo);
    if (defined $loc) {
        my $makerFixup = $subdirInfo{Fixup} = Image::ExifTool::Fixup->new;
        # create new exiftool object to rewrite the directory without changing it
        my $newTool = Image::ExifTool->new;
        $newTool->Options(
            IgnoreMinorErrors => $$et{OPTIONS}{IgnoreMinorErrors},
            FixBase           => $$et{OPTIONS}{FixBase},
        );
        $newTool->Init();   # must do this before calling WriteDirectory()!
        # don't copy over preview image
        $newTool->SetNewValue(PreviewImage => '');
        # copy all transient members over in case they are used for writing
        # (Make, Model, etc)
        foreach (grep /[a-z]/, keys %$et) {
            $$newTool{$_} = $$et{$_};
        }
        # fix base offsets if specified
        $newTool->Options(FixBase => $et->Options('FixBase'));
        # set GENERATE_PREVIEW_INFO flag so PREVIEW_INFO will be generated
        $$newTool{GENERATE_PREVIEW_INFO} = 1;
        # drop any large tags
        $$newTool{DropTags} = 1;
        # initialize other necessary data members
        $$newTool{FILE_TYPE} = $$et{FILE_TYPE};
        $$newTool{TIFF_TYPE} = $$et{TIFF_TYPE};
        # rewrite maker notes
        $rtnValue = $newTool->WriteDirectory(\%subdirInfo, $tagTablePtr);
        if (defined $rtnValue and length $rtnValue) {
            # add the dummy/empty preview image if necessary
            if ($$newTool{PREVIEW_INFO}) {
                $makerFixup->SetMarkerPointers(\$rtnValue, 'PreviewImage', length($rtnValue));
                $rtnValue .= $$newTool{PREVIEW_INFO}{Data};
                delete $$newTool{PREVIEW_INFO};
            }
            # add makernote header
            if ($loc) {
                my $hdr = substr($$dataPt, $dirStart, $loc);
                # special case: convert Pentax/Samsung DNG maker notes to JPEG style
                # (in JPEG, Pentax makernotes are absolute and start with "AOC\0" for some
                # models, but in DNG images they are stored in tag 0xc634 of IFD0 and
                # start with either "PENTAX \0" or "SAMSUNG\0")
                if ($$dirInfo{Parent} eq 'IFD0' and $hdr =~ /^(PENTAX |SAMSUNG)\0/) {
                    # convert to JPEG-style AOC maker notes if used by this model
                    # (Note: this expression also appears in Exif.pm)
                    if ($$et{Model} =~ /\b(K(-[57mrx]|(10|20|100|110|200)D|2000)|GX(10|20))\b/) {
                        $hdr =~ s/^(PENTAX |SAMSUNG)\0/AOC\0/;
                        # save fixup because AOC maker notes have absolute offsets
                        $$et{MAKER_NOTE_FIXUP} = $makerFixup;
                    }
                }
                $rtnValue = $hdr . $rtnValue;
                # adjust fixup for shift in start position
                $$makerFixup{Start} += length $hdr;
            }
            # shift offsets according to original position of maker notes,
            # and relative to the makernotes Base
            $$makerFixup{Shift} += $dataPos + $dirStart +
                                   $$dirInfo{Base} - $subdirInfo{Base};
            # repair incorrect offsets if offsets were fixed
            $$makerFixup{Shift} += $subdirInfo{FixedBy} || 0;
            # fix up pointers to the specified offset
            $makerFixup->ApplyFixup(\$rtnValue);
            # save fixup information unless offsets were relative
            unless ($subdirInfo{Relative}) {
                # set shift so offsets are all relative to start of maker notes
                $$makerFixup{Shift} -= $dataPos + $dirStart;
                $$et{MAKER_NOTE_FIXUP} = $makerFixup;    # save fixup for later
            }
        }
    }
    SetByteOrder($saveOrder);

    return $rtnValue;
}

#------------------------------------------------------------------------------
# Sort IFD directory entries
# Inputs: 0) data reference, 1) directory start, 2) number of entries,
#         3) flag to treat 0 as a valid tag ID (as opposed to an empty IFD entry)
sub SortIFD($$$;$)
{
    my ($dataPt, $dirStart, $numEntries, $allowZero) = @_;
    my ($index, %entries);
    # split the directory into separate entries
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + 2 + 12 * $index;
        my $tagID = Get16u($dataPt, $entry);
        my $entryData = substr($$dataPt, $entry, 12);
        # silly software can pad directories with zero entries -- put these at the end
        $tagID = 0x10000 unless $tagID or $index == 0 or $allowZero;
        # add new entry (allow for duplicate tag ID's, which shouldn't normally happen)
        if ($entries{$tagID}) {
            $entries{$tagID} .= $entryData;
        } else {
            $entries{$tagID} = $entryData;
        }
    }
    # sort the directory entries
    my @sortedTags = sort { $a <=> $b } keys %entries;
    # generate the sorted IFD
    my $newDir = '';
    foreach (@sortedTags) {
        $newDir .= $entries{$_};
    }
    # replace original directory with new, sorted one
    substr($$dataPt, $dirStart + 2, 12 * $numEntries) = $newDir;
}

#------------------------------------------------------------------------------
# Validate IFD entries (strict validation to test possible chained IFD's)
# Inputs: 0) dirInfo ref (must have RAF set), 1) optional DirStart
# Returns: true if IFD looks OK
sub ValidateIFD($;$)
{
    my ($dirInfo, $dirStart) = @_;
    my $raf = $$dirInfo{RAF} or return 0;
    my $base = $$dirInfo{Base};
    $dirStart = $$dirInfo{DirStart} || 0 unless defined $dirStart;
    my $offset = $dirStart + ($$dirInfo{DataPos} || 0);
    my ($buff, $index);
    $raf->Seek($offset + $base, 0) and $raf->Read($buff,2) == 2 or return 0;
    my $numEntries = Get16u(\$buff,0);
    $numEntries > 1 and $numEntries < 64 or return 0;
    my $len = 12 * $numEntries;
    $raf->Read($buff, $len) == $len or return 0;
    my $lastID = -1;
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = 12 * $index;
        my $tagID = Get16u(\$buff, $entry);
        $tagID > $lastID or $$dirInfo{AllowOutOfOrderTags} or return 0;
        my $format = Get16u(\$buff, $entry+2);
        $format > 0 and $format <= 13 or return 0;
        my $count = Get32u(\$buff, $entry+4);
        $count > 0 or return 0;
        $lastID = $tagID;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Get sorted list of offsets used in IFD
# Inputs: 0) data ref, 1) directory start, 2) dataPos, 3) IFD entries, 4) tag table ref
# Returns: 0) sorted list of offsets (only offsets after the end of the IFD)
#          1) hash of list indices keyed by offset value
# Notes: This is used in a patch to fix the count for tags in Kodak SubIFD3
sub GetOffList($$$$$)
{
    my ($dataPt, $dirStart, $dataPos, $numEntries, $tagTablePtr) = @_;
    my $ifdEnd = $dirStart + 2 + 12 * $numEntries + $dataPos;
    my ($index, $offset, %offHash);
    for ($index=0; $index<$numEntries; ++$index) {
        my $entry = $dirStart + 2 + 12 * $index;
        my $format = Get16u($dataPt, $entry + 2);
        next if $format < 1 or $format > 13;
        my $count = Get16u($dataPt, $entry + 4);
        my $size = $formatSize[$format] * $count;
        if ($size <= 4) {
            my $tagID = Get16u($dataPt, $entry);
            next unless ref $$tagTablePtr{$tagID} eq 'HASH' and $$tagTablePtr{$tagID}{FixCount};
        }
        my $offset = Get16u($dataPt, $entry + 8);
        $offHash{$offset} = 1 if $offset >= $ifdEnd;
    }
    # set offset hash values to indices in list
    my @offList = sort keys %offHash;
    $index = 0;
    foreach $offset (@offList) {
        $offHash{$offset} = $index++;
    }
    return(\@offList, \%offHash);
}

#------------------------------------------------------------------------------
# Update TIFF_END member if defined
# Inputs: 0) ExifTool ref, 1) end of valid TIFF data
sub UpdateTiffEnd($$)
{
    my ($et, $end) = @_;
    if (defined $$et{TIFF_END} and
        $$et{TIFF_END} < $end)
    {
        $$et{TIFF_END} = $end;
    }
}

#------------------------------------------------------------------------------
# Validate image data size
# Inputs: 0) ExifTool ref, 1) validate info hash ref,
#         2) flag to issue error (ie. we're writing)
# - issues warning or error if problems found
sub ValidateImageData($$$;$)
{
    local $_;
    my ($et, $vInfo, $dirName, $errFlag) = @_;

    # determine the expected size of the image data for an uncompressed image
    # (0x102 BitsPerSample, 0x103 Compression and 0x115 SamplesPerPixel
    #  all default to a value of 1 if they don't exist)
    if ((not defined $$vInfo{0x103} or $$vInfo{0x103} eq '1') and
        $$vInfo{0x100} and $$vInfo{0x101} and ($$vInfo{0x117} or $$vInfo{0x145}))
    {
        my $samplesPerPix = $$vInfo{0x115} || 1;
        my @bitsPerSample = $$vInfo{0x102} ? split(' ',$$vInfo{0x102}) : (1) x $samplesPerPix;
        my $byteCountInfo = $$vInfo{0x117} || $$vInfo{0x145};
        my $byteCounts = $$byteCountInfo[1];
        my $totalBytes = 0;
        $totalBytes += $_ foreach split ' ', $byteCounts;
        my $minor;
        $minor = 1 if $$et{DOC_NUM} or $$et{FILE_TYPE} ne 'TIFF';
        unless (@bitsPerSample == $samplesPerPix) {
            unless ($$et{FILE_TYPE} eq 'EPS' and @bitsPerSample == 1) {
                # (just a warning for this problem)
                my $s = $samplesPerPix eq '1' ? '' : 's';
                $et->Warn("$dirName BitsPerSample should have $samplesPerPix value$s", $minor);
            }
            push @bitsPerSample, $bitsPerSample[0] while @bitsPerSample < $samplesPerPix;
            foreach (@bitsPerSample) {
                $et->Warn("$dirName BitsPerSample values are different", $minor) if $_ ne $bitsPerSample[0];
                $et->Warn("Invalid $dirName BitsPerSample value", $minor) if $_ < 1 or $_ > 32;
            }
        }
        my $bitsPerPixel = 0;
        $bitsPerPixel += $_ foreach @bitsPerSample;
        my $expectedBytes = int(($$vInfo{0x100} * $$vInfo{0x101} * $bitsPerPixel + 7) / 8);
        if ($expectedBytes != $totalBytes and
            # (this problem seems normal for certain types of RAW files...)
            $$et{TIFF_TYPE} !~ /^(K25|KDC|MEF|ORF|SRF)$/)
        {
            my ($adj, $minor);
            if ($expectedBytes > $totalBytes) {
                $adj = 'Under'; # undersized is a bigger problem because we may lose data
                $minor = 0 unless $errFlag;
            } else {
                $adj = 'Over';
                $minor = 1;
            }
            my $msg = "${adj}sized $dirName $$byteCountInfo[0]{Name} ($totalBytes bytes, but expected $expectedBytes)";
            if (not defined $minor) {
                # this is a serious error if we are writing the file and there
                # is a chance that we may not copy all of the image data
                # (but make it minor to allow the file to be written anyway)
                $et->Error($msg, 1);
            } else {
                $et->Warn($msg, $minor);
            }
        }
    }
}

#------------------------------------------------------------------------------
# Add specified image data to ImageDataHash hash
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) lookup for [tagInfo,value] based on tagID
sub AddImageDataHash($$$)
{
    my ($et, $dirInfo, $offsetInfo) = @_;
    my ($tagID, $offset, $buff);

    my $verbose = $et->Options('Verbose');
    my $hash = $$et{ImageDataHash};
    my $raf = $$dirInfo{RAF};

    foreach $tagID (sort keys %$offsetInfo) {
        next unless ref $$offsetInfo{$tagID} eq 'ARRAY'; # ignore scalar tag values used for Validate
        my $tagInfo = $$offsetInfo{$tagID}[0];
        next unless $$tagInfo{IsImageData};     # only consider image data
        my $sizeID = $$tagInfo{OffsetPair};
        my @sizes;
        if ($$tagInfo{NotRealPair}) {
            @sizes = 999999999;     # (Panasonic hack: raw data runs to end of file)
        } elsif ($sizeID and $$offsetInfo{$sizeID}) {
            @sizes = split ' ', $$offsetInfo{$sizeID}[1];
        } else {
            next;
        }
        my @offsets = split ' ', $$offsetInfo{$tagID}[1];
        $sizes[0] = 999999999 if $$tagInfo{NotRealPair};
        my $total = 0;
        foreach $offset (@offsets) {
            my $size = shift @sizes;
            next unless $offset =~ /^\d+$/ and $size and $size =~ /^\d+$/ and $size;
            next unless $raf->Seek($offset, 0); # (offset is absolute)
            $total += $et->ImageDataHash($raf, $size);
        }
        if ($verbose) {
            my $name = "$$dirInfo{DirName}:$$tagInfo{Name}";
            $name =~ s/Offsets?|Start$//;
            $et->VPrint(0, "$$et{INDENT}(ImageDataHash: $total bytes of $name data)\n");
        }
    }
}

#------------------------------------------------------------------------------
# Handle error while writing EXIF
# Inputs: 0) ExifTool ref, 1) error string, 2) tag table ref
# Returns: undef on fatal error, or '' if minor error is ignored
sub ExifErr($$$)
{
    my ($et, $errStr, $tagTablePtr) = @_;
    # MakerNote errors are minor by default
    my $minor = ($$tagTablePtr{GROUPS}{0} eq 'MakerNotes' or $$et{FILE_TYPE} eq 'MOV');
    if ($$tagTablePtr{VARS} and $$tagTablePtr{VARS}{MINOR_ERRORS}) {
        $et->Warn("$errStr. IFD dropped.") and return '' if $minor;
        $minor = 1;
    }
    return undef if $et->Error($errStr, $minor);
    return '';
}

#------------------------------------------------------------------------------
# Read/Write IFD with TIFF-like header (used by DNG 1.2)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: Reading: 1 on success, otherwise returns 0 and sets a Warning
#          Writing: new data block or undef on error
sub ProcessTiffIFD($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access
    my $raf = $$dirInfo{RAF};
    my $base = $$dirInfo{Base} || 0;
    my $dirName = $$dirInfo{DirName};
    my $magic = $$dirInfo{Subdir}{Magic} || 0x002a;
    my $buff;

    # structured with a TIFF-like header and relative offsets
    $raf->Seek($base, 0) and $raf->Read($buff, 8) == 8 or return 0;
    unless (SetByteOrder(substr($buff,0,2)) and Get16u(\$buff, 2) == $magic) {
        my $msg = "Invalid $dirName header";
        if ($$dirInfo{IsWriting}) {
            $et->Error($msg);
            return undef;
        } else {
            $et->Warn($msg);
            return 0;
        }
    }
    my $offset = Get32u(\$buff, 4);
    my %dirInfo = (
        DirName  => $$dirInfo{DirName},
        Parent   => $$dirInfo{Parent},
        Base     => $base,
        DataPt   => \$buff,
        DataLen  => length $buff,
        DataPos  => 0,
        DirStart => $offset,
        DirLen   => length($buff) - $offset,
        RAF      => $raf,
        NewDataPos => 8,
    );
    if ($$dirInfo{IsWriting}) {
        # rewrite the Camera Profile IFD
        my $newDir = WriteExif($et, \%dirInfo, $tagTablePtr);
        # don't add header if error writing directory ($newDir is undef)
        # or if directory is being deleted ($newDir is empty)
        return $newDir unless $newDir;
        # return directory with TIFF-like header
        return GetByteOrder() . Set16u($magic) . Set32u(8) . $newDir;
    }
    if ($$et{HTML_DUMP}) {
        my $tip = sprintf("Byte order: %s endian\nIdentifier: 0x%.4x\n%s offset: 0x%.4x",
                          (GetByteOrder() eq 'II') ? 'Little' : 'Big', $magic, $dirName, $offset);
        $et->HDump($base, 8, "$dirName header", $tip, 0);
    }
    return ProcessExif($et, \%dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Write EXIF directory
# Inputs: 0) ExifTool object ref, 1) source dirInfo ref, 2) tag table ref
# Returns: Exif data block (may be empty if no Exif data) or undef on error
# Notes: Increments ExifTool CHANGED flag for each tag changed.  Also updates
#        TIFF_END if defined with location of end of original TIFF image.
# Returns IFD data in the following order:
#   1. IFD0 directory followed by its data
#   2. SubIFD directory followed by its data, thumbnail and image
#   3. GlobalParameters, EXIF, GPS, Interop IFD's each with their data
#   4. IFD1,IFD2,... directories each followed by their data
#   5. Thumbnail and/or image data for each IFD, with IFD0 image last
sub WriteExif($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;      # allow dummy access to autoload this package
    my $origDirInfo = $dirInfo; # save original dirInfo
    my $dataPt = $$dirInfo{DataPt};
    unless ($dataPt) {
        my $emptyData = '';
        $dataPt = \$emptyData;
    }
    my $dataPos = $$dirInfo{DataPos} || 0;
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dataLen = $$dirInfo{DataLen} || length($$dataPt);
    my $dirLen = $$dirInfo{DirLen} || ($dataLen - $dirStart);
    my $base = $$dirInfo{Base} || 0;
    my $firstBase = $base;
    my $raf = $$dirInfo{RAF};
    my $dirName = $$dirInfo{DirName} || 'unknown';
    my $fixup = $$dirInfo{Fixup} || Image::ExifTool::Fixup->new;
    my $imageDataFlag = $$dirInfo{ImageData} || '';
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');
    my $noMandatory = $et->Options('NoMandatory');
    my ($nextIfdPos, %offsetData, $inMakerNotes);
    my (@offsetInfo, %validateInfo, %xDelete, $strEnc);
    my $deleteAll = 0;
    my $newData = '';   # initialize buffer to receive new directory data
    my @imageData;      # image data blocks to copy later if requested
    my $name = $$dirInfo{Name};
    $name = $dirName unless $name and $dirName eq 'MakerNotes' and $name !~ /^MakerNote/;

    # save byte order of existing EXIF
    $$et{SaveExifByteOrder} = GetByteOrder() if $dirName eq 'IFD0' or $dirName eq 'ExifIFD';

    # set encoding for strings
    $strEnc = $et->Options('CharsetEXIF') if $$tagTablePtr{GROUPS}{0} eq 'EXIF';

    # allow multiple IFD's in IFD0-IFD1-IFD2... chain
    $$dirInfo{Multi} = 1 if $dirName =~ /^(IFD0|SubIFD)$/ and not defined $$dirInfo{Multi};
    $inMakerNotes = 1 if $$tagTablePtr{GROUPS}{0} eq 'MakerNotes';
    my $ifd;

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# loop through each IFD
#
    for ($ifd=0; ; ++$ifd) {  # loop through multiple IFD's

        # make sure that Compression and SubfileType are defined for this IFD (for Condition's)
        $$et{Compression} = $$et{SubfileType} = '';

        # save pointer to start of this IFD within the newData
        my $newStart = length($newData);
        my @subdirs;    # list of subdirectory data and tag table pointers
        # determine if directory is contained within our data
        my $mustRead;
        if ($dirStart < 0 or $dirStart > $dataLen-2) {
            $mustRead = 1;
        } elsif ($dirLen >= 2) {
            my $len = 2 + 12 * Get16u($dataPt, $dirStart);
            $mustRead = 1 if $dirStart + $len > $dataLen;
        }
        # read IFD from file if necessary
        if ($mustRead) {
            if ($raf) {
                # read the count of entries in this IFD
                my $offset = $dirStart + $dataPos;
                my ($buff, $buf2);
                unless ($raf->Seek($offset + $base, 0) and $raf->Read($buff,2) == 2) {
                    return ExifErr($et, "Bad IFD or truncated file in $name", $tagTablePtr);
                }
                my $len = 12 * Get16u(\$buff,0);
                # (also read next IFD pointer if available)
                unless ($raf->Read($buf2, $len+4) >= $len) {
                    return ExifErr($et, "Error reading $name", $tagTablePtr);
                }
                $buff .= $buf2;
                # make copy of dirInfo since we're going to modify it
                my %newDirInfo = %$dirInfo;
                $dirInfo = \%newDirInfo;
                # update directory parameters for the newly loaded IFD
                $dataPt = $$dirInfo{DataPt} = \$buff;
                $dirStart = $$dirInfo{DirStart} = 0;
                $dataPos = $$dirInfo{DataPos} = $offset;
                $dataLen = $$dirInfo{DataLen} = length $buff;
                $dirLen = $$dirInfo{DirLen} = $dataLen;
                # only account for nextIFD pointer if we are going to use it
                $len += 4 if $dataLen==$len+6 and ($$dirInfo{Multi} or $buff =~ /\0{4}$/);
                UpdateTiffEnd($et, $offset+$base+2+$len);
            } elsif ($dirLen and $dirStart + 4 >= $dataLen) {
                # error if we can't load IFD (unless we are creating
                # from scratch, in which case dirLen will be zero)
                my $str = $et->Options('IgnoreMinorErrors') ? 'Deleted bad' : 'Bad';
                $et->Error("$str $name directory", 1);
            }
        }
        my ($index, $dirEnd, $numEntries, %hasOldID, $unsorted);
        if ($dirStart + 4 < $dataLen) {
            $numEntries = Get16u($dataPt, $dirStart);
            $dirEnd = $dirStart + 2 + 12 * $numEntries;
            if ($dirEnd > $dataLen) {
                my $n = int(($dataLen - $dirStart - 2) / 12);
                my $rtn = ExifErr($et, "Truncated $name directory", $tagTablePtr);
                return undef unless $n and defined $rtn;
                $numEntries = $n;   # continue processing the entries we have
            }
            # create lookup for existing tag ID's and determine if directory is sorted
            my $lastID = -1;
            for ($index=0; $index<$numEntries; ++$index) {
                my $tagID = Get16u($dataPt, $dirStart + 2 + 12 * $index);
                $hasOldID{$tagID} = 1;
                # check for proper sequence (but ignore null entries at end)
                $unsorted = 1 if $tagID < $lastID and ($tagID or $$tagTablePtr{0});
                $lastID = $tagID;
            }
            # sort entries if out-of-order (but not in maker notes IFDs or RAW files)
            if ($unsorted and not ($inMakerNotes or $et->IsRawType())) {
                SortIFD($dataPt, $dirStart, $numEntries, $$tagTablePtr{0});
                $et->Warn("Entries in $name were out of sequence. Fixed.",1);
                $unsorted = 0;
            }
        } else {
            $numEntries = 0;
            $dirEnd = $dirStart;
        }

        # loop through new values and accumulate all information for this IFD
        my (%set, %mayDelete, $tagInfo, %hasNewID);
        my $wrongDir = $crossDelete{$dirName};
        my @newTagInfo = $et->GetNewTagInfoList($tagTablePtr);
        foreach $tagInfo (@newTagInfo) {
            my $tagID = $$tagInfo{TagID};
            $hasNewID{$tagID} = 1;
            # must evaluate Condition later when we have all DataMember's available
            $set{$tagID} = (ref $$tagTablePtr{$tagID} eq 'ARRAY' or $$tagInfo{Condition}) ? '' : $tagInfo;
        }

        # fix base offsets (some cameras incorrectly write maker notes in IFD0)
        if ($dirName eq 'MakerNotes' and $$dirInfo{Parent} =~ /^(ExifIFD|IFD0)$/ and
            $$et{TIFF_TYPE} !~ /^(ARW|SR2)$/ and not $$et{LeicaTrailerPos} and
            Image::ExifTool::MakerNotes::FixBase($et, $dirInfo))
        {
            # update local variables from fixed values
            $base = $$dirInfo{Base};
            $dataPos = $$dirInfo{DataPos};
            # changed if ForceWrite tag was was set to "FixBase"
            ++$$et{CHANGED} if $$et{FORCE_WRITE}{FixBase};
            if ($$et{TIFF_TYPE} eq 'SRW' and $$et{Make} eq 'SAMSUNG' and $$et{Model} eq 'EK-GN120') {
                $et->Error("EK-GN120 SRW files are too buggy to write");
            }
        }

        # initialize variables to handle mandatory tags
        my ($mandatory, $allMandatory, $addMandatory);
        $mandatory = $mandatory{$dirName} unless $noMandatory;
        if ($mandatory) {
            # use X/Y resolution values from JFIF if available
            if ($dirName eq 'IFD0' and defined $$et{JFIFYResolution}) {
                my %ifd0Vals = %$mandatory;
                $ifd0Vals{0x011a} = $$et{JFIFXResolution};
                $ifd0Vals{0x011b} = $$et{JFIFYResolution};
                $ifd0Vals{0x0128} = $$et{JFIFResolutionUnit} + 1;
                $mandatory = \%ifd0Vals;
            }
            $allMandatory = $addMandatory = 0; # initialize to zero
            # add mandatory tags if creating a new directory
            unless ($numEntries) {
                foreach (keys %$mandatory) {
                    defined $set{$_} or $set{$_} = $$tagTablePtr{$_};
                }
            }
        } else {
            undef $deleteAll;   # don't remove directory (no mandatory entries)
        }
        my ($addDirs, @newTags);
        if ($inMakerNotes) {
            $addDirs = { };     # can't currently add new directories in MakerNotes
            # allow non-permanent makernotes tags to be added
            # (note: we may get into trouble if there are too many of these
            #  because we allow out-of-order tags in MakerNote IFD's but our
            #  logic to add new tags relies on ordered entries)
            foreach (keys %set) {
                next unless $set{$_};
                my $perm = $set{$_}{Permanent};
                push @newTags, $_ if defined $perm and not $perm;
            }
            @newTags = sort { $a <=> $b } @newTags if @newTags > 1;
        } else {
            # get a hash of directories we will be writing in this one
            $addDirs = $et->GetAddDirHash($tagTablePtr, $dirName);
            # make a union of tags & dirs (can set whole dirs, like MakerNotes)
            my %allTags = ( %set, %$addDirs );
            # make sorted list of new tags to be added
            @newTags = sort { $a <=> $b } keys(%allTags);
        }
        my $dirBuff = '';   # buffer for directory data
        my $valBuff = '';   # buffer for value data
        my @valFixups;      # list of fixups for offsets in valBuff
        # fixup for offsets in dirBuff
        my $dirFixup = Image::ExifTool::Fixup->new;
        my $entryBasedFixup;
        my $lastTagID = -1;
        my ($oldInfo, $oldFormat, $oldFormName, $oldCount, $oldSize, $oldValue, $oldImageData);
        my ($readFormat, $readFormName, $readCount); # format for reading old value(s)
        my ($entry, $valueDataPt, $valueDataPos, $valueDataLen, $valuePtr, $valEnd);
        my ($offList, $offHash, $ignoreCount, $fixCount);
        my $oldID = -1;
        my $newID = -1;

        # patch for Canon EOS 40D firmware 1.0.4 bug (incorrect directory counts)
        if ($inMakerNotes and $$et{Model} eq 'Canon EOS 40D') {
            my $fmt = Get16u($dataPt, $dirStart + 2 + 12 * ($numEntries - 1) + 2);
            if ($fmt < 1 or $fmt > 13) {
                # adjust the number of directory entries
                --$numEntries;
                $dirEnd -= 12;
                $ignoreCount = 1;
            }
        }
#..............................................................................
# loop through entries in new directory
#
        $index = 0;
Entry:  for (;;) {

            if (defined $oldID and $oldID == $newID) {
#
# read next entry from existing directory
#
                if ($index < $numEntries) {
                    $entry = $dirStart + 2 + 12 * $index;
                    $oldID = Get16u($dataPt, $entry);
                    $readFormat = $oldFormat = Get16u($dataPt, $entry+2);
                    $readCount = $oldCount = Get32u($dataPt, $entry+4);
                    undef $oldImageData;
                    if (($oldFormat < 1 or $oldFormat > 13) and $oldFormat != 129 and not ($oldFormat == 16 and $$et{Make} eq 'Apple' and $inMakerNotes)) {
                        my $msg = "Bad format ($oldFormat) for $name entry $index";
                        # patch to preserve invalid directory entries in SubIFD3 of
                        # various Kodak Z-series cameras (Z812, Z1085IS, Z1275)
                        # and some Sony cameras such as the DSC-P10
                        if ($dirName eq 'MakerNotes' and (($$et{Make}=~/KODAK/i and
                            $$dirInfo{Name} and $$dirInfo{Name} eq 'SubIFD3') or
                            ($numEntries == 12 and $$et{Make} eq 'SONY' and $index >= 8)))
                        {
                            $dirBuff .= substr($$dataPt, $entry, 12);
                            ++$index;
                            $newID = $oldID;    # we wrote this
                            $et->Warn($msg, 1);
                            next;
                        }
                        # don't write out null directory entry
                        if ($oldFormat==0 and $index and $oldCount==0) {
                            $ignoreCount = ($ignoreCount || 0) + 1;
                            # must keep same directory size to avoid messing up our fixed offsets
                            $dirBuff .= ("\0" x 12) if $$dirInfo{FixBase};
                            ++$index;
                            $newID = $oldID;    # pretend we wrote this
                            next;
                        }
                        return ExifErr($et, $msg, $tagTablePtr);
                    }
                    $readFormName = $oldFormName = $formatName[$oldFormat];
                    $valueDataPt = $dataPt;
                    $valueDataPos = $dataPos;
                    $valueDataLen = $dataLen;
                    $valuePtr = $entry + 8;
                    # try direct method first for speed
                    $oldInfo = $$tagTablePtr{$oldID};
                    if (ref $oldInfo ne 'HASH' or $$oldInfo{Condition}) {
                        # must get unknown tags too
                        # (necessary so we don't miss a tag we want to Drop)
                        my $unk = $et->Options(Unknown => 1);
                        $oldInfo = $et->GetTagInfo($tagTablePtr, $oldID);
                        $et->Options(Unknown => $unk);
                    }
                    # patch incorrect count in Kodak SubIFD3 tags
                    if ($oldCount < 2 and $oldInfo and $$oldInfo{FixCount}) {
                        $offList or ($offList, $offHash) = GetOffList($dataPt, $dirStart, $dataPos,
                                                                      $numEntries, $tagTablePtr);
                        my $i = $$offHash{Get32u($dataPt, $valuePtr)};
                        if (defined $i and $i < $#$offList) {
                            $oldCount = int(($$offList[$i+1] - $$offList[$i]) / $formatSize[$oldFormat]);
                            $fixCount = ($fixCount || 0) + 1 if $oldCount != $readCount;
                        }
                    }
                    $oldSize = $oldCount * $formatSize[$oldFormat];
                    my $readFromFile;
                    if ($oldSize > 4) {
                        $valuePtr = Get32u($dataPt, $valuePtr);
                        # fix valuePtr if necessary
                        if ($$dirInfo{FixOffsets}) {
                            $valEnd or $valEnd = $dataPos + $dirStart + 2 + 12 * $numEntries + 4;
                            my ($tagID, $size, $wFlag) = ($oldID, $oldSize, 1);
                            #### eval FixOffsets ($valuePtr, $valEnd, $size, $tagID, $wFlag)
                            eval $$dirInfo{FixOffsets};
                            unless (defined $valuePtr) {
                                unless ($$et{DropTags}) {
                                    my $tagStr = $oldInfo ? $$oldInfo{Name} : sprintf("tag 0x%.4x",$oldID);
                                    return undef if $et->Error("Bad $name offset for $tagStr", $inMakerNotes);
                                }
                                ++$index;  $oldID = $newID;  next;  # drop this tag
                            }
                        }
                        # offset shouldn't point into TIFF or IFD header
                        my $suspect = ($valuePtr < 8);
                        # convert offset to pointer in $$dataPt
                        if ($$dirInfo{EntryBased} or (ref $$tagTablePtr{$oldID} eq 'HASH' and
                            $$tagTablePtr{$oldID}{EntryBased}))
                        {
                            $valuePtr += $entry;
                        } else {
                            $valuePtr -= $dataPos;
                        }
                        # value shouldn't overlap our directory
                        $suspect = 1 if $valuePtr < $dirEnd and $valuePtr+$oldSize > $dirStart;
                        # get value by seeking in file if we are allowed
                        if ($valuePtr < 0 or $valuePtr+$oldSize > $dataLen) {
                            my ($pos, $tagStr, $invalidPreview, $tmpInfo, $leicaTrailer);
                            if ($oldInfo) {
                                $tagStr = $$oldInfo{Name};
                                $leicaTrailer = $$oldInfo{LeicaTrailer};
                            } elsif (defined $oldInfo) {
                                $tmpInfo = $et->GetTagInfo($tagTablePtr, $oldID, \ '', $oldFormName, $oldCount);
                                if ($tmpInfo) {
                                    $tagStr = $$tmpInfo{Name};
                                    $leicaTrailer = $$tmpInfo{LeicaTrailer};
                                }
                            }
                            $tagStr or $tagStr = sprintf("tag 0x%.4x",$oldID);
                            # allow PreviewImage to run outside EXIF segment in JPEG images
                            if (not $raf) {
                                if ($tagStr eq 'PreviewImage') {
                                    $raf = $$et{RAF};
                                    if ($raf) {
                                        $pos = $raf->Tell();
                                        if ($oldInfo and $$oldInfo{ChangeBase}) {
                                            # adjust base offset for this tag only
                                            #### eval ChangeBase ($dirStart,$dataPos)
                                            my $newBase = eval $$oldInfo{ChangeBase};
                                            $valuePtr += $newBase;
                                        }
                                    } else {
                                        $invalidPreview = 1;
                                    }
                                } elsif ($leicaTrailer) {
                                    # save information about Leica makernote trailer
                                    $$et{LeicaTrailer} = {
                                        TagInfo => $oldInfo || $tmpInfo,
                                        Offset  => $base + $valuePtr + $dataPos,
                                        Size    => $oldSize,
                                        Fixup   => Image::ExifTool::Fixup->new,
                                    },
                                    $invalidPreview = 2;
                                    # remove SubDirectory to prevent processing (for now)
                                    my %copy = %{$oldInfo || $tmpInfo};
                                    delete $copy{SubDirectory};
                                    delete $copy{MakerNotes};
                                    $oldInfo = \%copy;
                                }
                            }
                            if ($oldSize > BINARY_DATA_LIMIT and $$origDirInfo{ImageData} and
                                (not defined $oldInfo or ($oldInfo and
                                (not $$oldInfo{SubDirectory} or $$oldInfo{ReadFromRAF}))))
                            {
                                # copy huge data blocks later instead of loading into memory
                                $oldValue = ''; # dummy empty value
                                # copy this value later unless writing a new value
                                unless (defined $set{$oldID}) {
                                    my $pad = $oldSize & 0x01 ? 1 : 0;
                                    # save block information to copy later (set directory offset later)
                                    $oldImageData = [$base+$valuePtr+$dataPos, $oldSize, $pad];
                                }
                            } elsif ($raf) {
                                my $success = ($raf->Seek($base+$valuePtr+$dataPos, 0) and
                                               $raf->Read($oldValue, $oldSize) == $oldSize);
                                if (defined $pos) {
                                    $raf->Seek($pos, 0);
                                    undef $raf;
                                    # (sony A700 has 32-byte header on PreviewImage)
                                    unless ($success and $oldValue =~ /^(\xff\xd8\xff|(.|.{33})\xd8\xff\xdb)/s) {
                                        $invalidPreview = 1;
                                        $success = 1;   # continue writing directory anyway
                                    }
                                }
                                unless ($success) {
                                    my $wrn = sprintf("Error reading value for $name entry $index, ID 0x%.4x", $oldID);
                                    my $truncOK;
                                    if ($oldInfo and not $$oldInfo{Unknown}) {
                                        $wrn .= " $$oldInfo{Name}";
                                        $truncOK = $$oldInfo{TruncateOK};
                                    }
                                    return undef if $et->Error($wrn, $inMakerNotes || $truncOK);
                                    unless ($truncOK) {
                                        ++$index;  $oldID = $newID;  next;  # drop this tag
                                    }
                                }
                            } elsif (not $invalidPreview) {
                                return undef if $et->Error("Bad $name offset for $tagStr", $inMakerNotes);
                                ++$index;  $oldID = $newID;  next;  # drop this tag
                            }
                            if ($invalidPreview) {
                                # set value for invalid preview
                                if ($$et{FILE_TYPE} eq 'JPEG') {
                                    # define dummy value for preview (or Leica MakerNote) to write later
                                    # (value must be larger than 4 bytes to generate PREVIEW_INFO,
                                    # and an even number of bytes so it won't be padded)
                                    $oldValue = 'LOAD_PREVIEW';
                                } else {
                                    $oldValue = 'none';
                                    $oldSize = length $oldValue;
                                }
                                $valuePtr = 0;
                            } else {
                                UpdateTiffEnd($et, $base+$valuePtr+$dataPos+$oldSize);
                            }
                            # update pointers for value just read from file
                            $valueDataPt = \$oldValue;
                            $valueDataPos = $valuePtr + $dataPos;
                            $valueDataLen = $oldSize;
                            $valuePtr = 0;
                            $readFromFile = 1;
                        }
                        if ($suspect) {
                            my $tagStr = $oldInfo ? $$oldInfo{Name} : sprintf('tag 0x%.4x', $oldID);
                            my $str = "Suspicious $name offset for $tagStr";
                            if ($inMakerNotes) {
                                $et->Warn($str, 1);
                            } else {
                                return undef if $et->Error($str, 1);
                            }
                        }
                    }
                    # read value if we haven't already
                    $oldValue = substr($$valueDataPt, $valuePtr, $oldSize) unless $readFromFile;
                    # get tagInfo using value if necessary
                    if (defined $oldInfo and not $oldInfo) {
                        my $unk = $et->Options(Unknown => 1);
                        $oldInfo = $et->GetTagInfo($tagTablePtr, $oldID, \$oldValue, $oldFormName, $oldCount);
                        $et->Options(Unknown => $unk);
                        # now that we have the value, we can resolve the Condition to finally
                        # determine whether we want to delete this tag or not
                        if ($mayDelete{$oldID} and $oldInfo and (not @newTags or $newTags[0] != $oldID)) {
                            my $nvHash = $et->GetNewValueHash($oldInfo, $dirName);
                            if (not $nvHash and $wrongDir) {
                                # delete from wrong directory if necessary
                                $nvHash = $et->GetNewValueHash($oldInfo, $wrongDir);
                                $nvHash and $xDelete{$oldID} = 1;
                            }
                            if ($nvHash) {
                                # we want to delete this tag after all, so insert it into our list
                                $set{$oldID} = $oldInfo;
                                unshift @newTags, $oldID;
                            }
                        }
                    }
                    # make sure we are handling the 'ifd' format properly
                    if (($oldFormat == 13 or $oldFormat == 18) and
                        (not $oldInfo or not $$oldInfo{SubIFD}))
                    {
                        my $str = sprintf('%s tag 0x%.4x IFD format not handled', $name, $oldID);
                        $et->Error($str, $inMakerNotes);
                    }
                    # override format we use to read the value if specified
                    if ($oldInfo) {
                        # check for tags which must be integers
                        if (($$oldInfo{IsOffset} or $$oldInfo{SubIFD}) and
                            not $intFormat{$oldFormName})
                        {
                            $et->Error("Invalid format ($oldFormName) for $name $$oldInfo{Name}", $inMakerNotes);
                            ++$index;  $oldID = $newID;  next;  # drop this tag
                        }
                        if ($$oldInfo{Drop} and $$et{DropTags} and
                            ($$oldInfo{Drop} == 1 or $$oldInfo{Drop} < $oldSize))
                        {
                            ++$index;  $oldID = $newID;  next;  # drop this tag
                        }
                        if ($$oldInfo{Format}) {
                            $readFormName = $$oldInfo{Format};
                            $readFormat = $formatNumber{$readFormName};
                            unless ($readFormat) {
                                # we aren't reading in a standard EXIF format, so rewrite in old format
                                $readFormName = $oldFormName;
                                $readFormat = $oldFormat;
                            }
                            if ($$oldInfo{FixedSize}) {
                                $oldSize = $$oldInfo{FixedSize} if $$oldInfo{FixedSize};
                                $oldValue = substr($$valueDataPt, $valuePtr, $oldSize);
                            }
                            # adjust number of items to read if format size changed
                            $readCount = $oldSize / $formatSize[$readFormat];
                        }
                    }
                    if ($oldID <= $lastTagID and not ($inMakerNotes or $et->IsRawType())) {
                        my $str = $oldInfo ? "$$oldInfo{Name} tag" : sprintf('tag 0x%x',$oldID);
                        if ($oldID == $lastTagID) {
                            $et->Warn("Duplicate $str in $name");
                            # put this tag back into the newTags list if necessary
                            unshift @newTags, $oldID if defined $set{$oldID};
                        } else {
                            $et->Warn("\u$str out of sequence in $name");
                        }
                    }
                    $lastTagID = $oldID;
                    ++$index;               # increment index for next time
                } else {
                    undef $oldID;           # no more existing entries
                }
            }
#
# write out all new tags, up to and including this one
#
            $newID = $newTags[0];
            my $isNew;  # -1=tag is old, 0=tag same as existing, 1=tag is new
            if (not defined $oldID) {
                last unless defined $newID;
                $isNew = 1;
            } elsif (not defined $newID) {
                # maker notes will have no new tags defined
                if (defined $set{$oldID}) {
                    $newID = $oldID;
                    $isNew = 0;
                } else {
                    $isNew = -1;
                }
            } else {
                $isNew = $oldID <=> $newID;
                # special logic needed if directory has out-of-order entries
                if ($unsorted and $isNew) {
                    if ($isNew > 0 and $hasOldID{$newID}) {
                        # we wanted to create the new tag, but an old tag
                        # does exist with this ID, so defer writing the new tag
                        $isNew = -1;
                    }
                    if ($isNew < 0 and $hasNewID{$oldID}) {
                        # we wanted to write the old tag, but we have
                        # a new tag with this ID, so move it up in the order
                        my @tmpTags = ( $oldID );
                        $_ == $oldID or push @tmpTags, $_ foreach @newTags;
                        @newTags = @tmpTags;
                        $newID = $oldID;
                        $isNew = 0;
                    }
                }
            }
            my $newInfo = $oldInfo;
            my $newFormat = $oldFormat;
            my $newFormName = $oldFormName;
            my $newCount = $oldCount;
            my $ifdFormName;
            my $newValue;
            my $newValuePt = $isNew >= 0 ? \$newValue : \$oldValue;
            my $isOverwriting;

            if ($isNew >= 0) {
                # add, edit or delete this tag
                shift @newTags; # remove from list
                my $curInfo = $set{$newID};
                # don't allow MakerNotes to be added to ExifIFD of CR3 file
                next if $newID == 0x927c and $isNew > 0 and $$et{FileType} eq 'CR3';
                unless ($curInfo or $$addDirs{$newID}) {
                    # we can finally get the specific tagInfo reference for this tag
                    # (because we can now evaluate the Condition statement since all
                    #  DataMember's have been obtained for tags up to this one)
                    $curInfo = $et->GetTagInfo($tagTablePtr, $newID);
                    if (defined $curInfo and not $curInfo) {
                        # need value to evaluate the condition
                        # (tricky because we need the tagInfo ref to get the value,
                        #  so we must loop through all new tagInfo's...)
                        foreach $tagInfo (@newTagInfo) {
                            next unless $$tagInfo{TagID} == $newID;
                            my $val = $et->GetNewValue($tagInfo);
                            defined $val or $mayDelete{$newID} = 1, next;
                            # must convert to binary for evaluating in Condition
                            my $fmt = $$tagInfo{Format} || $$tagInfo{Writable};
                            if ($fmt) {
                                $val = WriteValue($val, $fmt, $$tagInfo{Count});
                                defined $val or $mayDelete{$newID} = 1, next;
                            }
                            $curInfo = $et->GetTagInfo($tagTablePtr, $newID, \$val, $oldFormName, $oldCount);
                            if ($curInfo) {
                                last if $curInfo eq $tagInfo;
                                undef $curInfo;
                            }
                        }
                        # may want to delete this, but we need to see the old value first
                        $mayDelete{$newID} = 1 unless $curInfo;
                    }
                    # don't set this tag unless valid for the current condition
                    if ($curInfo and $$et{NEW_VALUE}{$curInfo}) {
                        $set{$newID} = $curInfo;
                    } else {
                        next if $isNew > 0;
                        $isNew = -1;
                        undef $curInfo;
                    }
                }
                if ($curInfo) {
                    if ($$curInfo{WriteCondition}) {
                        my $self = $et;   # set $self to be used in eval
                        #### eval WriteCondition ($self)
                        unless (eval $$curInfo{WriteCondition}) {
                            $@ and warn $@;
                            goto NoWrite;   # GOTO !
                        }
                    }
                    my $nvHash;
                    $nvHash = $et->GetNewValueHash($curInfo, $dirName) if $isNew >= 0;
                    unless ($nvHash or (defined $$mandatory{$newID} and not $noMandatory)) {
                        goto NoWrite unless $wrongDir;  # GOTO !
                        # delete stuff from the wrong directory if setting somewhere else
                        $nvHash = $et->GetNewValueHash($curInfo, $wrongDir);
                        # don't cross delete if not overwriting
                        goto NoWrite unless $et->IsOverwriting($nvHash);    # GOTO !
                        # don't cross delete if specifically deleting from the other directory
                        # (Note: don't call GetValue() here because it shouldn't be called
                        #  if IsOverwriting returns < 0 -- eg. when shifting)
                        if (not defined $$nvHash{Value} and $$nvHash{WantGroup} and
                                lc($$nvHash{WantGroup}) eq lc($wrongDir))
                        {
                            goto NoWrite;   # GOTO !
                        } else {
                            # remove this tag if found in this IFD
                            $xDelete{$newID} = 1;
                        }
                    }
                } elsif (not $$addDirs{$newID}) {
NoWrite:            next if $isNew > 0;
                    delete $set{$newID};
                    $isNew = -1;
                }
                if ($set{$newID}) {
#
# set the new tag value (or 'next' if deleting tag)
#
                    $newInfo = $set{$newID};
                    $newCount = $$newInfo{Count};
                    my ($val, $newVal, $n);
                    my $nvHash = $et->GetNewValueHash($newInfo, $dirName);
                    if ($isNew > 0) {
                        # don't create new entry unless requested
                        if ($nvHash) {
                            next unless $$nvHash{IsCreating};
                            if ($$newInfo{IsOverwriting}) {
                                my $proc = $$newInfo{IsOverwriting};
                                $isOverwriting = &$proc($et, $nvHash, $val, \$newVal);
                            } else {
                                $isOverwriting = $et->IsOverwriting($nvHash);
                            }
                        } else {
                            next if $xDelete{$newID};       # don't create if cross deleting
                            $newVal = $$mandatory{$newID};  # get value for mandatory tag
                            $isOverwriting = 1;
                        }
                        # convert using new format
                        if ($$newInfo{Format}) {
                            $newFormName = $$newInfo{Format};
                            # use Writable flag to specify IFD format code
                            $ifdFormName = $$newInfo{Writable};
                        } else {
                            $newFormName = $$newInfo{Writable};
                            unless ($newFormName) {
                                warn("No format for $name $$newInfo{Name}\n");
                                next;
                            }
                        }
                        $newFormat = $formatNumber{$newFormName};
                    } elsif ($nvHash or $xDelete{$newID}) {
                        unless ($nvHash) {
                            $nvHash = $et->GetNewValueHash($newInfo, $wrongDir);
                        }
                        # read value
                        if (length $oldValue >= $oldSize) {
                            $val = ReadValue(\$oldValue, 0, $readFormName, $readCount, $oldSize);
                        } else {
                            $val = '';
                        }
                        # determine write format (by default, use 'Writable' format)
                        my $writable = $$newInfo{Writable};
                        # (or use existing format if 'Writable' not specified)
                        $writable = $oldFormName unless $writable and $writable ne '1';
                        # (and override write format with 'Format' if specified)
                        my $writeForm = $$newInfo{Format} || $writable;
                        if ($writeForm ne $newFormName) {
                            # write in specified format
                            $newFormName = $writeForm;
                            $newFormat = $formatNumber{$newFormName};
                            # use different IFD format code if necessary
                            if ($inMakerNotes) {
                                # always preserve IFD format in maker notes
                                $ifdFormName = $oldFormName;
                            } elsif ($writable ne $newFormName) {
                                # use specified IFD format
                                $ifdFormName = $writable;
                            }
                        }
                        if ($inMakerNotes and $readFormName ne 'string' and $readFormName ne 'undef') {
                            # keep same size in maker notes unless string or binary
                            $newCount = $oldCount * $formatSize[$oldFormat] / $formatSize[$newFormat];
                        }
                        if ($$newInfo{IsOverwriting}) {
                            my $proc = $$newInfo{IsOverwriting};
                            $isOverwriting = &$proc($et, $nvHash, $val, \$newVal);
                        } else {
                            $isOverwriting = $et->IsOverwriting($nvHash, $val);
                        }
                    }
                    if ($isOverwriting) {
                        $newVal = $et->GetNewValue($nvHash) unless defined $newVal;
                        # value undefined if deleting this tag
                        # (also delete tag if cross-deleting and this isn't a date/time shift)
                        if (not defined $newVal or ($xDelete{$newID} and not defined $$nvHash{Shift})) {
                            if (not defined $newVal and $$newInfo{RawConvInv} and defined $$nvHash{Value}) {
                                # error in RawConvInv, so rewrite existing tag
                                goto NoOverwrite; # GOTO!
                            }
                            unless ($isNew) {
                                ++$$et{CHANGED};
                                $et->VerboseValue("- $dirName:$$newInfo{Name}", $val);
                            }
                            next;
                        }
                        if ($newCount and $newCount < 0) {
                            # set count to number of values if variable
                            my @vals = split ' ',$newVal;
                            $newCount = @vals;
                        }
                        # convert to binary format
                        $newValue = WriteValue($newVal, $newFormName, $newCount);
                        unless (defined $newValue) {
                            $et->Warn("Invalid value for $dirName:$$newInfo{Name}");
                            goto NoOverwrite; # GOTO!
                        }
                        if (length $newValue) {
                            # limit maximum value length in JPEG images
                            # (max segment size is 65533 bytes and the min EXIF size is 96 incl an additional IFD entry)
                            if ($$et{FILE_TYPE} eq 'JPEG' and length($newValue) > 65436 and
                                $$newInfo{Name} ne 'PreviewImage')
                            {
                                my $name = $$newInfo{MakerNotes} ? 'MakerNotes' : $$newInfo{Name};
                                $et->Warn("Writing large value for $name",1);
                            }
                            # re-code if necessary
                            if ($newFormName eq 'utf8') {
                                $newValue = $et->Encode($newValue, 'UTF8');
                            } elsif ($strEnc and $newFormName eq 'string') {
                                $newValue = $et->Encode($newValue, $strEnc);
                            }
                        } else {
                            $et->Warn("Can't write zero length $$newInfo{Name} in $$tagTablePtr{GROUPS}{1}");
                            goto NoOverwrite; # GOTO!
                        }
                        if ($isNew >= 0) {
                            $newCount = length($newValue) / $formatSize[$newFormat];
                            ++$$et{CHANGED};
                            if (defined $allMandatory) {
                                # not all mandatory if we are writing any tag specifically
                                if ($nvHash) {
                                    undef $allMandatory;
                                    undef $deleteAll;
                                } else {
                                    ++$addMandatory;    # count mandatory tags that we added
                                }
                            }
                            if ($verbose > 1) {
                                $et->VerboseValue("- $dirName:$$newInfo{Name}", $val) unless $isNew;
                                if ($$newInfo{OffsetPair} and $newVal eq '4277010157') { # (0xfeedfeed)
                                    print { $$et{OPTIONS}{TextOut} } "    + $dirName:$$newInfo{Name} = <tbd>\n";
                                } else {
                                    my $str = $nvHash ? '' : ' (mandatory)';
                                    $et->VerboseValue("+ $dirName:$$newInfo{Name}", $newVal, $str);
                                }
                            }
                        }
                    } else {
NoOverwrite:            next if $isNew > 0;
                        $isNew = -1;        # rewrite existing tag
                    }
                    # set format for EXIF IFD if different than conversion format
                    if ($ifdFormName) {
                        $newFormName = $ifdFormName;
                        $newFormat = $formatNumber{$newFormName};
                    }

                } elsif ($isNew > 0) {
#
# create new subdirectory
#
                    # newInfo may not be defined if we try to add a mandatory tag
                    # to a directory that doesn't support it (eg. IFD1 in RW2 images)
                    $newInfo = $$addDirs{$newID} or next;
                    # make sure we don't try to generate a new MakerNotes directory
                    # or a SubIFD
                    next if $$newInfo{MakerNotes} or $$newInfo{Name} eq 'SubIFD';
                    my $subTable;
                    if ($$newInfo{SubDirectory}{TagTable}) {
                        $subTable = Image::ExifTool::GetTagTable($$newInfo{SubDirectory}{TagTable});
                    } else {
                        $subTable = $tagTablePtr;
                    }
                    # create empty source directory
                    my %sourceDir = (
                        Parent => $dirName,
                        Fixup => Image::ExifTool::Fixup->new,
                    );
                    $sourceDir{DirName} = $$newInfo{Groups}{1} if $$newInfo{SubIFD};
                    $newValue = $et->WriteDirectory(\%sourceDir, $subTable);
                    # only add new directory if it isn't empty
                    next unless defined $newValue and length($newValue);
                    # set the fixup start location
                    if ($$newInfo{SubIFD}) {
                        # subdirectory is referenced by an offset in value buffer
                        my $subdir = $newValue;
                        $newValue = Set32u(0xfeedf00d);
                        push @subdirs, {
                            DataPt => \$subdir,
                            Table => $subTable,
                            Fixup => $sourceDir{Fixup},
                            Offset => length($dirBuff) + 8,
                            Where => 'dirBuff',
                        };
                        $newFormName = 'int32u';
                        $newFormat = $formatNumber{$newFormName};
                    } else {
                        # subdirectory goes directly into value buffer
                        $sourceDir{Fixup}{Start} += length($valBuff);
                        # use Writable to set format, otherwise 'undef'
                        $newFormName = $$newInfo{Writable};
                        unless ($newFormName and $formatNumber{$newFormName}) {
                            $newFormName = 'undef';
                        }
                        $newFormat = $formatNumber{$newFormName};
                        push @valFixups, $sourceDir{Fixup};
                    }
                } elsif ($$newInfo{Format} and $$newInfo{Writable} and $$newInfo{Writable} ne '1') {
                    # use specified write format
                    $newFormName = $$newInfo{Writable};
                    $newFormat = $formatNumber{$newFormName};
                } elsif ($$addDirs{$newID} and $newInfo ne $$addDirs{$newID}) {
                    # this can happen if we are trying to add a directory that doesn't exist
                    # in this type of file (eg. try adding a SubIFD tag to an A100 image)
                    $isNew = -1;
                }
            }
            if ($isNew < 0) {
                # just rewrite existing tag
                $newID = $oldID;
                $newValue = $oldValue;
                $newFormat = $oldFormat; # (just in case it changed)
                $newFormName = $oldFormName;
                # set offset of this entry in the directory so we can update the pointer
                # and save block information to copy this large block later
                if ($oldImageData) {
                    $$oldImageData[3] = $newStart + length($dirBuff) + 2;
                    push @imageData, $oldImageData;
                    $$origDirInfo{ImageData} = \@imageData;
                }
            }
            if ($newInfo) {
#
# load necessary data for this tag (thumbnail image, etc)
#
                if ($$newInfo{DataTag} and $isNew >= 0) {
                    my $dataTag = $$newInfo{DataTag};
                    # load data for this tag
                    unless (defined $offsetData{$dataTag} or $dataTag eq 'LeicaTrailer') {
                        # prefer tag from Composite table if it exists (otherwise
                        # PreviewImage data would be taken from Extra tag)
                        my $compInfo = Image::ExifTool::GetCompositeTagInfo($dataTag);
                        $offsetData{$dataTag} = $et->GetNewValue($compInfo || $dataTag);
                        my $err;
                        if (defined $offsetData{$dataTag}) {
                            my $len = length $offsetData{$dataTag};
                            if ($dataTag eq 'PreviewImage') {
                                # must set DEL_PREVIEW flag now if preview fit into IFD
                                $$et{DEL_PREVIEW} = 1 if $len <= 4;
                            }
                        } else {
                            $err = "$dataTag not found";
                        }
                        if ($err) {
                            $et->Warn($err) if $$newInfo{IsOffset};
                            delete $set{$newID};    # remove from list of tags we are setting
                            next;
                        }
                    }
                }
#
# write maker notes
#
                if ($$newInfo{MakerNotes}) {
                    # don't write new makernotes if we are deleting this group
                    if ($$et{DEL_GROUP}{MakerNotes} and
                       ($$et{DEL_GROUP}{MakerNotes} != 2 or $isNew <= 0))
                    {
                        if ($et->IsRawType() and not ($et->IsRawType() == 2 and $dirName eq 'ExifIFD')) {
                            $et->Warn("Can't delete MakerNotes from $$et{FileType}",1);
                        } else {
                            if ($isNew <= 0) {
                                ++$$et{CHANGED};
                                $verbose and print $out "  Deleting MakerNotes\n";
                            }
                            next;
                        }
                    }
                    my $saveOrder = GetByteOrder();
                    if ($isNew >= 0 and defined $set{$newID}) {
                        # we are writing a whole new maker note block
                        # --> add fixup information if necessary
                        my $nvHash = $et->GetNewValueHash($newInfo, $dirName);
                        if ($nvHash and $$nvHash{MAKER_NOTE_FIXUP}) {
                            # must clone fixup because we will be shifting it
                            my $makerFixup = $$nvHash{MAKER_NOTE_FIXUP}->Clone();
                            my $valLen = length($valBuff);
                            $$makerFixup{Start} += $valLen;
                            push @valFixups, $makerFixup;
                        }
                    } else {
                        # update maker notes if possible
                        my %subdirInfo = (
                            Base     => $base,
                            DataPt   => $valueDataPt,
                            DataPos  => $valueDataPos,
                            DataLen  => $valueDataLen,
                            DirStart => $valuePtr,
                            DirLen   => $oldSize,
                            DirName  => 'MakerNotes',
                            Name     => $$newInfo{Name},
                            Parent   => $dirName,
                            TagInfo  => $newInfo,
                            RAF      => $raf,
                        );
                        my ($subTable, $subdir, $loc, $writeProc, $notIFD);
                        if ($$newInfo{SubDirectory}) {
                            my $sub = $$newInfo{SubDirectory};
                            $subdirInfo{FixBase} = 1 if $$sub{FixBase};
                            $subdirInfo{FixOffsets} = $$sub{FixOffsets};
                            $subdirInfo{EntryBased} = $$sub{EntryBased};
                            $subdirInfo{NoFixBase} = 1 if defined $$sub{Base};
                            $subdirInfo{AutoFix} = $$sub{AutoFix};
                            SetByteOrder($$sub{ByteOrder}) if $$sub{ByteOrder};
                        }
                        # get the proper tag table for these maker notes
                        if ($oldInfo and $$oldInfo{SubDirectory}) {
                            $subTable = $$oldInfo{SubDirectory}{TagTable};
                            $subTable and $subTable = Image::ExifTool::GetTagTable($subTable);
                            $writeProc = $$oldInfo{SubDirectory}{WriteProc};
                            $notIFD = $$oldInfo{NotIFD};
                        } else {
                            $et->Warn('Internal problem getting maker notes tag table');
                        }
                        $writeProc or $writeProc = $$subTable{WRITE_PROC} if $subTable;
                        $subTable or $subTable = $tagTablePtr;
                        if ($writeProc and
                            $writeProc eq \&Image::ExifTool::MakerNotes::WriteUnknownOrPreview and
                            $oldValue =~ /^\xff\xd8\xff/)
                        {
                            $loc = 0;
                        } elsif (not $notIFD) {
                            # look for IFD-style maker notes
                            $loc = Image::ExifTool::MakerNotes::LocateIFD($et,\%subdirInfo);
                        }
                        if (defined $loc) {
                            # we need fixup data for this subdirectory
                            $subdirInfo{Fixup} = Image::ExifTool::Fixup->new;
                            # rewrite maker notes
                            my $changed = $$et{CHANGED};
                            $subdir = $et->WriteDirectory(\%subdirInfo, $subTable, $writeProc);
                            if ($changed == $$et{CHANGED} and $subdirInfo{Fixup}->IsEmpty()) {
                                # return original data if nothing changed and no fixups
                                undef $subdir;
                            }
                        } elsif ($$subTable{PROCESS_PROC} and
                                 $$subTable{PROCESS_PROC} eq \&Image::ExifTool::ProcessBinaryData)
                        {
                            my $sub = $$oldInfo{SubDirectory};
                            if (defined $$sub{Start}) {
                                #### eval Start ($valuePtr)
                                my $start = eval $$sub{Start};
                                $loc = $start - $valuePtr;
                                $subdirInfo{DirStart} = $start;
                                $subdirInfo{DirLen} -= $loc;
                            } else {
                                $loc = 0;
                            }
                            # rewrite maker notes
                            $subdir = $et->WriteDirectory(\%subdirInfo, $subTable);
                        } elsif ($notIFD) {
                            if ($writeProc) {
                                $loc = 0;
                                $subdir = $et->WriteDirectory(\%subdirInfo, $subTable);
                            }
                        } else {
                            my $msg = 'Maker notes could not be parsed';
                            if ($$et{FILE_TYPE} eq 'JPEG') {
                                $et->Warn($msg, 1);
                            } else {
                                $et->Error($msg, 1);
                            }
                        }
                        if (defined $subdir) {
                            length $subdir or SetByteOrder($saveOrder), next;
                            my $valLen = length($valBuff);
                            # restore existing header and substitute the new
                            # maker notes for the old value
                            $newValue = substr($oldValue, 0, $loc) . $subdir;
                            my $makerFixup = $subdirInfo{Fixup};
                            my $previewInfo = $$et{PREVIEW_INFO};
                            if ($subdirInfo{Relative}) {
                                # apply a one-time fixup to $loc since offsets are relative
                                $$makerFixup{Start} += $loc;
                                # shift all offsets to be relative to new base
                                my $baseShift = $valueDataPos + $valuePtr + $base - $subdirInfo{Base};
                                $$makerFixup{Shift} += $baseShift;
                                $makerFixup->ApplyFixup(\$newValue);
                                if ($previewInfo) {
                                    # remove all but PreviewImage fixup (since others shouldn't change)
                                    foreach (keys %{$$makerFixup{Pointers}}) {
                                        /_PreviewImage$/ or delete $$makerFixup{Pointers}{$_};
                                    }
                                    # zero pointer so we can see how it gets shifted later
                                    $makerFixup->SetMarkerPointers(\$newValue, 'PreviewImage', 0);
                                    # set the pointer to the start of the EXIF information
                                    # add preview image fixup to list of value fixups
                                    $$makerFixup{Start} += $valLen;
                                    push @valFixups, $makerFixup;
                                    $$previewInfo{BaseShift} = $baseShift;
                                    $$previewInfo{Relative} = 1;
                                }
                            # don't shift anything if relative flag set to zero (Pentax patch)
                            } elsif (not defined $subdirInfo{Relative}) {
                                # shift offset base if shifted in the original image or if FixBase
                                # was used, but be careful of automatic FixBase with negative shifts
                                # since they may lead to negative (invalid) offsets (casio_edit_problem.jpg)
                                my $baseShift = $base - $subdirInfo{Base};
                                if ($subdirInfo{AutoFix}) {
                                    $baseShift = 0;
                                } elsif ($subdirInfo{FixBase} and $baseShift < 0 and
                                    # allow negative base shift if offsets are bigger (PentaxOptioWP.jpg)
                                    (not $subdirInfo{MinOffset} or $subdirInfo{MinOffset} + $baseShift < 0))
                                {
                                    my $fixBase = $et->Options('FixBase');
                                    if (not defined $fixBase) {
                                        my $str = $et->Options('IgnoreMinorErrors') ? 'ignored' : 'fix or ignore?';
                                        $et->Error("MakerNotes offsets may be incorrect ($str)", 1);
                                    } elsif ($fixBase eq '') {
                                        $et->Warn('Fixed incorrect MakerNotes offsets');
                                        $baseShift = 0;
                                    }
                                }
                                $$makerFixup{Start} += $valLen + $loc;
                                $$makerFixup{Shift} += $baseShift;
                                # permanently fix makernote offset errors
                                $$makerFixup{Shift} += $subdirInfo{FixedBy} || 0;
                                push @valFixups, $makerFixup;
                                if ($previewInfo and not $$previewInfo{NoBaseShift}) {
                                    $$previewInfo{BaseShift} = $baseShift;
                                }
                            }
                            $newValuePt = \$newValue;   # write new value
                        }
                    }
                    SetByteOrder($saveOrder);

                # process existing subdirectory unless we are overwriting it entirely
                } elsif ($$newInfo{SubDirectory} and $isNew <= 0 and not $isOverwriting
                    # don't edit directory if Writable is set to 0
                    and (not defined $$newInfo{Writable} or $$newInfo{Writable}) and
                    not $$newInfo{ReadFromRAF})
                {

                    my $subdir = $$newInfo{SubDirectory};
                    if ($$newInfo{SubIFD}) {
#
# rewrite existing sub IFD's
#
                        my $subTable = $tagTablePtr;
                        if ($$subdir{TagTable}) {
                            $subTable = Image::ExifTool::GetTagTable($$subdir{TagTable});
                        }
                        # determine directory name for this IFD
                        my $subdirName = $$newInfo{Groups}{1} || $$newInfo{Name};
                        # all makernotes directory names must be 'MakerNotes'
                        $subdirName = 'MakerNotes' if $$subTable{GROUPS}{0} eq 'MakerNotes';
                        # must handle sub-IFD's specially since the values
                        # are actually offsets to subdirectories
                        unless ($readCount) {   # can't have zero count
                            return undef if $et->Error("$name entry $index has zero count", 2);
                            next;
                        }
                        my $writeCount = 0;
                        my $i;
                        $newValue = '';    # reset value because we regenerate it below
                        for ($i=0; $i<$readCount; ++$i) {
                            my $off = $i * $formatSize[$readFormat];
                            my $val = ReadValue($valueDataPt, $valuePtr + $off,
                                                $readFormName, 1, $oldSize - $off);
                            my $subdirStart = $val - $dataPos;
                            my $subdirBase = $base;
                            my $hdrLen;
                            if (defined $$subdir{Start}) {
                                #### eval Start ($val)
                                my $newStart = eval $$subdir{Start};
                                unless (Image::ExifTool::IsInt($newStart)) {
                                    $et->Error("Bad subdirectory start for $$newInfo{Name}");
                                    next;
                                }
                                $newStart -= $dataPos;
                                $hdrLen = $newStart - $subdirStart;
                                $subdirStart = $newStart;
                            }
                            if ($$subdir{Base}) {
                                my $start = $subdirStart + $dataPos;
                                #### eval Base ($start,$base)
                                $subdirBase += eval $$subdir{Base};
                            }
                            # add IFD number if more than one
                            $subdirName =~ s/\d*$/$i/ if $i;
                            my %subdirInfo = (
                                Base     => $subdirBase,
                                DataPt   => $dataPt,
                                DataPos  => $dataPos - $subdirBase + $base,
                                DataLen  => $dataLen,
                                DirStart => $subdirStart,
                                DirName  => $subdirName,
                                Name     => $$newInfo{Name},
                                TagInfo  => $newInfo,
                                Parent   => $dirName,
                                Fixup    => Image::ExifTool::Fixup->new,
                                RAF      => $raf,
                                Subdir   => $subdir,
                                # set ImageData only for 1st level SubIFD's
                                ImageData=> $imageDataFlag eq 'Main' ? 'SubIFD' : undef,
                            );
                            # pass on header pointer only for certain sub IFD's
                            $subdirInfo{HeaderPtr} = $$dirInfo{HeaderPtr} if $$newInfo{SubIFD} == 2;
                            if ($$subdir{RelativeBase}) {
                                # apply one-time fixup if offsets are relative (Sony IDC hack)
                                delete $subdirInfo{Fixup};
                                delete $subdirInfo{ImageData};
                            }
                            # is the subdirectory outside our current data?
                            if ($subdirStart < 0 or $subdirStart + 2 > $dataLen) {
                                if ($raf) {
                                    # reset SubDirectory buffer (we will load it later)
                                    my $buff = '';
                                    $subdirInfo{DataPt} = \$buff;
                                    $subdirInfo{DataLen} = 0;
                                } else {
                                    my @err = ("Can't read $subdirName data", $inMakerNotes);
                                    if ($$subTable{VARS} and $$subTable{VARS}{MINOR_ERRORS}) {
                                        $et->Warn($err[0] . '. Ignored.');
                                    } elsif ($et->Error(@err)) {
                                        return undef;
                                    }
                                    next Entry; # don't write this directory
                                }
                            }
                            my $subdirData = $et->WriteDirectory(\%subdirInfo, $subTable, $$subdir{WriteProc});
                            unless (defined $subdirData) {
                                # WriteDirectory should have issued an error, but check just in case
                                $et->Error("Error writing $subdirName") unless $$et{VALUE}{Error};
                                return undef;
                            }
                            # add back original header if necessary (eg. Ricoh GR)
                            if ($hdrLen and $hdrLen > 0 and $subdirStart <= $dataLen) {
                                $subdirData = substr($$dataPt, $subdirStart - $hdrLen, $hdrLen) . $subdirData;
                                $subdirInfo{Fixup}{Start} += $hdrLen;
                            }
                            unless (length $subdirData) {
                                next unless $inMakerNotes;
                                # don't delete MakerNote Sub-IFD's, write empty IFD instead
                                $subdirData = "\0" x 6;
                                # reset SubIFD ImageData and Fixup just to be safe
                                delete $subdirInfo{ImageData};
                                delete $subdirInfo{Fixup};
                            }
                            # handle data blocks that we will transfer later
                            if (ref $subdirInfo{ImageData}) {
                                push @imageData, @{$subdirInfo{ImageData}};
                                $$origDirInfo{ImageData} = \@imageData;
                            }
                            # temporarily set value to subdirectory index
                            # (will set to actual offset later when we know what it is)
                            $newValue .= Set32u(0xfeedf00d);
                            my ($offset, $where);
                            if ($readCount > 1) {
                                $offset = length($valBuff) + $i * 4;
                                $where = 'valBuff';
                            } else {
                                $offset = length($dirBuff) + 8;
                                $where = 'dirBuff';
                            }
                            # add to list of subdirectories we will append later
                            push @subdirs, {
                                DataPt    => \$subdirData,
                                Table     => $subTable,
                                Fixup     => $subdirInfo{Fixup},
                                Offset    => $offset,
                                Where     => $where,
                                ImageData => $subdirInfo{ImageData},
                            };
                            ++$writeCount;  # count number of subdirs written
                        }
                        next unless length $newValue;
                        # must change location of subdir offset if we deleted
                        # a directory and only one remains
                        if ($writeCount < $readCount and $writeCount == 1) {
                            $subdirs[-1]{Where} = 'dirBuff';
                            $subdirs[-1]{Offset} = length($dirBuff) + 8;
                        }
                        # set new format to int32u for IFD
                        $newFormName = $$newInfo{FixFormat} || 'int32u';
                        $newFormat = $formatNumber{$newFormName};
                        $newValuePt = \$newValue;

                    } elsif ((not defined $$subdir{Start} or
                             $$subdir{Start} =~ /\$valuePtr/) and
                             $$subdir{TagTable})
                    {
#
# rewrite other existing subdirectories ('$valuePtr' type only)
#
                        # set subdirectory Start and Base
                        my $subdirStart = $valuePtr;
                        if ($$subdir{Start}) {
                            #### eval Start ($valuePtr)
                            $subdirStart = eval $$subdir{Start};
                            # must adjust directory size if start changed
                            $oldSize -= $subdirStart - $valuePtr;
                        }
                        my $subdirBase = $base;
                        if ($$subdir{Base}) {
                            my $start = $subdirStart + $valueDataPos;
                            #### eval Base ($start,$base)
                            $subdirBase += eval $$subdir{Base};
                        }
                        my $subFixup = Image::ExifTool::Fixup->new;
                        my %subdirInfo = (
                            Base     => $subdirBase,
                            DataPt   => $valueDataPt,
                            DataPos  => $valueDataPos - $subdirBase + $base,
                            DataLen  => $valueDataLen,
                            DirStart => $subdirStart,
                            DirName  => $$subdir{DirName},
                            DirLen   => $oldSize,
                            Parent   => $dirName,
                            Fixup    => $subFixup,
                            RAF      => $raf,
                            TagInfo  => $newInfo,
                        );
                        unless ($oldSize) {
                            # replace with dummy data if empty to prevent WriteDirectory
                            # routines from accessing data they shouldn't
                            my $tmp = '';
                            $subdirInfo{DataPt} = \$tmp;
                            $subdirInfo{DataLen} = 0;
                            $subdirInfo{DirStart} = 0;
                            $subdirInfo{DataPos} += $subdirStart;
                        }
                        my $subTable = Image::ExifTool::GetTagTable($$subdir{TagTable});
                        my $oldOrder = GetByteOrder();
                        SetByteOrder($$subdir{ByteOrder}) if $$subdir{ByteOrder};
                        $newValue = $et->WriteDirectory(\%subdirInfo, $subTable, $$subdir{WriteProc});
                        SetByteOrder($oldOrder);
                        if (defined $newValue) {
                            my $hdrLen = $subdirStart - $valuePtr;
                            if ($hdrLen) {
                                $newValue = substr($$valueDataPt, $valuePtr, $hdrLen) . $newValue;
                                $$subFixup{Start} += $hdrLen;
                            }
                            $newValuePt = \$newValue;
                        } else {
                            $newValuePt = \$oldValue;
                        }
                        unless (length $$newValuePt) {
                            # don't delete a previously empty makernote directory
                            next if $oldSize or not $inMakerNotes;
                        }
                        if ($$subFixup{Pointers} and $subdirInfo{Base} == $base) {
                            $$subFixup{Start} += length $valBuff;
                            push @valFixups, $subFixup;
                        } else {
                            # apply fixup in case we added a header ($hdrLen above)
                            $subFixup->ApplyFixup(\$newValue);
                        }
                    }

                } elsif ($$newInfo{OffsetPair}) {
#
# keep track of offsets
#
                    my $dataTag = $$newInfo{DataTag} || '';
                    if ($dataTag eq 'CanonVRD') {
                        # must decide now if we will write CanonVRD information
                        my $hasVRD;
                        if ($$et{NEW_VALUE}{$Image::ExifTool::Extra{CanonVRD}}) {
                            # adding or deleting as a block
                            $hasVRD = $et->GetNewValue('CanonVRD') ? 1 : 0;
                        } elsif ($$et{DEL_GROUP}{CanonVRD} or
                                 $$et{DEL_GROUP}{Trailer})
                        {
                            $hasVRD = 0;    # deleting as a group
                        } else {
                            $hasVRD = ($$newValuePt ne "\0\0\0\0");
                        }
                        if ($hasVRD) {
                            # add a fixup, and set this offset later
                            $dirFixup->AddFixup(length($dirBuff) + 8, $dataTag);
                        } else {
                            # there is (or will soon be) no VRD information, so set pointer to zero
                            $newValue = "\0" x length($$newValuePt);
                            $newValuePt = \$newValue;
                        }
                    } elsif ($dataTag eq 'OriginalDecisionData') {
                        # handle Canon OriginalDecisionData (no associated length tag)
                        # - I'm going out of my way here to preserve data which is
                        #   invalidated anyway by our edits
                        my $odd;
                        my $oddInfo = Image::ExifTool::GetCompositeTagInfo('OriginalDecisionData');
                        if ($oddInfo and $$et{NEW_VALUE}{$oddInfo}) {
                            $odd = $et->GetNewValue($dataTag);
                            if ($verbose > 1) {
                                print $out "    - $dirName:$dataTag\n" if $$newValuePt ne "\0\0\0\0";
                                print $out "    + $dirName:$dataTag\n" if $odd;
                            }
                            ++$$et{CHANGED};
                        } elsif ($$newValuePt ne "\0\0\0\0") {
                            if (length($$newValuePt) == 4) {
                                require Image::ExifTool::Canon;
                                my $offset = Get32u($newValuePt,0);
                                # absolute offset in JPEG images only
                                $offset += $base unless $$et{FILE_TYPE} eq 'JPEG';
                                $odd = Image::ExifTool::Canon::ReadODD($et, $offset);
                                $odd = $$odd if ref $odd;
                            } else {
                                $et->Error("Invalid $$newInfo{Name}",1);
                            }
                        }
                        if ($odd) {
                            my $newOffset = length($valBuff);
                            # (ODD offset is absolute in JPEG, so add base offset!)
                            $newOffset += $base if $$et{FILE_TYPE} eq 'JPEG';
                            $newValue = Set32u($newOffset);
                            $dirFixup->AddFixup(length($dirBuff) + 8, $dataTag);
                            $valBuff .= $odd;   # add original decision data
                        } else {
                            $newValue = "\0\0\0\0";
                        }
                        $newValuePt = \$newValue;
                    } else {
                        my $offsetInfo = $offsetInfo[$ifd];
                        # save original values (for updating TIFF_END later)
                        my @vals;
                        if ($isNew <= 0) {
                            my $oldOrder = GetByteOrder();
                            # Minolta A200 stores these in the wrong byte order!
                            SetByteOrder($$newInfo{ByteOrder}) if $$newInfo{ByteOrder};
                            @vals = ReadValue(\$oldValue, 0, $readFormName, $readCount, $oldSize);
                            SetByteOrder($oldOrder);
                            $validateInfo{$newID} = [$newInfo, join(' ',@vals)] unless $$newInfo{IsOffset};
                        }
                        # only support int32 pointers (for now)
                        if ($formatSize[$newFormat] != 4 and $$newInfo{IsOffset}) {
                            $isNew > 0 and warn("Internal error (Offset not int32)"), return undef;
                            $newCount != $readCount and warn("Wrong count!"), return undef;
                            # change to int32
                            $newFormName = 'int32u';
                            $newFormat = $formatNumber{$newFormName};
                            $newValue = WriteValue(join(' ',@vals), $newFormName, $newCount);
                            unless (defined $newValue) {
                                warn "Internal error writing offsets for $$newInfo{Name}\n";
                                return undef;
                            }
                            $newValuePt = \$newValue;
                        }
                        $offsetInfo or $offsetInfo = $offsetInfo[$ifd] = { };
                        # save location of valuePtr in new directory
                        # (notice we add 10 instead of 8 for valuePtr because
                        # we will put a 2-byte count at start of directory later)
                        my $ptr = $newStart + length($dirBuff) + 10;
                        $newCount or $newCount = 1; # make sure count is set for offsetInfo
                        # save value pointer and value count for each tag
                        $$offsetInfo{$newID} = [$newInfo, $ptr, $newCount, \@vals, $newFormat];
                    }

                } elsif ($$newInfo{DataMember}) {

                    # save any necessary data members (Make, Model, etc)
                    my $formatStr = $newFormName;
                    my $count = $newCount;
                    # change to specified format if necessary
                    if ($$newInfo{Format} and $$newInfo{Format} ne $formatStr) {
                        $formatStr = $$newInfo{Format};
                        my $format = $formatNumber{$formatStr};
                        # adjust number of items for new format size
                        $count = int(length($$newValuePt) / $formatSize[$format]) if $format;
                    }
                    my $val = ReadValue($newValuePt,0,$formatStr,$count,length($$newValuePt));
                    my $conv = $$newInfo{RawConv};
                    if ($conv) {
                        # let the RawConv store the (possibly converted) data member
                        if (ref $conv eq 'CODE') {
                            &$conv($val, $et);
                        } else {
                            my ($priority, @grps);
                            my ($self, $tag, $tagInfo) = ($et, $$newInfo{Name}, $newInfo);
                            #### eval RawConv ($self, $val, $tag, $tagInfo, $priority, @grps)
                            eval $conv;
                        }
                    } else {
                        $$et{$$newInfo{DataMember}} = $val;
                    }
                }
            }
#
# write out the directory entry
#
            my $newSize = length($$newValuePt);
            my $fsize = $formatSize[$newFormat];
            my $offsetVal;
            # set proper count
            $newCount = int(($newSize + $fsize - 1) / $fsize) unless $oldInfo and $$oldInfo{FixedSize};
            if ($saveForValidate{$newID} and $tagTablePtr eq \%Image::ExifTool::Exif::Main) {
                my @vals = ReadValue(\$newValue, 0, $newFormName, $newCount, $newSize);
                $validateInfo{$newID} = join ' ',@vals;
            }
            if ($newSize > 4) {
                # zero-pad to an even number of bytes (required by EXIF standard)
                # and make sure we are a multiple of the format size
                while ($newSize & 0x01 or $newSize < $newCount * $fsize) {
                    $$newValuePt .= "\0";
                    ++$newSize;
                }
                my $entryBased;
                if ($$dirInfo{EntryBased} or ($newInfo and $$newInfo{EntryBased})) {
                    $entryBased = 1;
                    $offsetVal = Set32u(length($valBuff) - length($dirBuff));
                } else {
                    $offsetVal = Set32u(length $valBuff);
                }
                my ($dataTag, $putFirst);
                ($dataTag, $putFirst) = @$newInfo{'DataTag','PutFirst'} if $newInfo;
                if ($dataTag) {
                    if ($dataTag eq 'PreviewImage' and ($$et{FILE_TYPE} eq 'JPEG' or
                        $$et{GENERATE_PREVIEW_INFO}))
                    {
                        # hold onto the PreviewImage until we can determine if it fits
                        $$et{PREVIEW_INFO} or $$et{PREVIEW_INFO} = {
                            Data => $$newValuePt,
                            Fixup => Image::ExifTool::Fixup->new,
                        };
                        $$et{PREVIEW_INFO}{ChangeBase} = 1 if $$newInfo{ChangeBase};
                        if ($$newInfo{IsOffset} and $$newInfo{IsOffset} eq '2') {
                            $$et{PREVIEW_INFO}{NoBaseShift} = 1;
                        }
                        # use original preview size if we will attempt to load it later
                        $newCount = $oldCount if $$newValuePt eq 'LOAD_PREVIEW';
                        $$newValuePt = '';
                    } elsif ($dataTag eq 'LeicaTrailer' and $$et{LeicaTrailer}) {
                        $$newValuePt = '';
                    }
                }
                if ($putFirst and $$dirInfo{HeaderPtr}) {
                    my $hdrPtr = $$dirInfo{HeaderPtr};
                    # place this value immediately after the TIFF header (eg. IIQ maker notes)
                    $offsetVal = Set32u(length $$hdrPtr);
                    $$hdrPtr .= $$newValuePt;
                } else {
                    $valBuff .= $$newValuePt;       # add value data to buffer
                    # must save a fixup pointer for every pointer in the directory
                    if ($entryBased) {
                        $entryBasedFixup or $entryBasedFixup = Image::ExifTool::Fixup->new;
                        $entryBasedFixup->AddFixup(length($dirBuff) + 8, $dataTag);
                    } else {
                        $dirFixup->AddFixup(length($dirBuff) + 8, $dataTag);
                    }
                }
            } else {
                $offsetVal = $$newValuePt;      # save value in offset if 4 bytes or less
                # must pad value with zeros if less than 4 bytes
                $newSize < 4 and $offsetVal .= "\0" x (4 - $newSize);
            }
            # write the directory entry
            $dirBuff .= Set16u($newID) . Set16u($newFormat) .
                        Set32u($newCount) . $offsetVal;
            # update flag to keep track of mandatory tags
            while (defined $allMandatory) {
                if (defined $$mandatory{$newID}) {
                    # values must correspond to mandatory values
                    my $form = $$newInfo{Format} || $newFormName;
                    my $mandVal = WriteValue($$mandatory{$newID}, $form, $newCount);
                    if (defined $mandVal and $mandVal eq $$newValuePt) {
                        ++$allMandatory;        # count mandatory tags
                        last;
                    }
                }
                undef $deleteAll;
                undef $allMandatory;
            }
        }
        if (%validateInfo) {
            ValidateImageData($et, \%validateInfo, $dirName, 1);
            undef %validateInfo;
        }
        if ($ignoreCount) {
            my $y = $ignoreCount > 1 ? 'ies' : 'y';
            my $verb = $$dirInfo{FixBase} ? 'Ignored' : 'Removed';
            $et->Warn("$verb $ignoreCount invalid entr$y from $name", 1);
        }
        if ($fixCount) {
            my $s = $fixCount > 1 ? 's' : '';
            $et->Warn("Fixed invalid count$s for $fixCount $name tag$s", 1);
        }
#..............................................................................
# write directory counts and nextIFD pointer and add value data to end of IFD
#
        # determine now if there is or will be another IFD after this one
        my $nextIfdOffset;
        if ($dirEnd + 4 <= $dataLen) {
            $nextIfdOffset = Get32u($dataPt, $dirEnd);
        } else {
            $nextIfdOffset = 0;
        }
        my $isNextIFD = ($$dirInfo{Multi} and ($nextIfdOffset or
                        # account for the case where we will create the next IFD
                        # (IFD1 only, but not in TIFF-format images)
                        ($dirName eq 'IFD0' and $$et{ADD_DIRS}{'IFD1'} and
                         $$et{FILE_TYPE} ne 'TIFF')));
        # calculate number of entries in new directory
        my $newEntries = length($dirBuff) / 12;
        # delete entire directory if we deleted a tag and only mandatory tags remain or we
        # attempted to create a directory with only mandatory tags and there is no nextIFD
        if ($allMandatory and not $isNextIFD and ($newEntries < $numEntries or $numEntries == 0)) {
            $newEntries = 0;
            $dirBuff = '';
            $valBuff = '';
            undef $dirFixup;    # no fixups in this directory
            ++$deleteAll if defined $deleteAll;
            $verbose > 1 and print $out "    - $allMandatory mandatory tag(s)\n";
            $$et{CHANGED} -= $addMandatory;    # didn't change these after all
        }
        if ($ifd and not $newEntries) {
            $verbose and print $out "  Deleting IFD1\n";
            last;   # don't write IFD1 if empty
        }
        # apply one-time fixup for entry-based offsets
        if ($entryBasedFixup) {
            $$entryBasedFixup{Shift} = length($dirBuff) + 4;
            $entryBasedFixup->ApplyFixup(\$dirBuff);
            undef $entryBasedFixup;
        }
        # initialize next IFD pointer to zero
        my $nextIFD = Set32u(0);
        # some cameras use a different amount of padding after the makernote IFD
        if ($dirName eq 'MakerNotes' and $$dirInfo{Parent} =~ /^(ExifIFD|IFD0)$/) {
            my ($rel, $pad) = Image::ExifTool::MakerNotes::GetMakerNoteOffset($et);
            $nextIFD = "\0" x $pad if defined $pad and ($pad==0 or ($pad>4 and $pad<=32));
        }
        # add directory entry count to start of IFD and next IFD pointer to end
        $newData .= Set16u($newEntries) . $dirBuff . $nextIFD;
        # get position of value data in newData
        my $valPos = length($newData);
        # go back now and set next IFD pointer if this isn't the first IFD
        if ($nextIfdPos) {
            # set offset to next IFD
            Set32u($newStart, \$newData, $nextIfdPos);
            $fixup->AddFixup($nextIfdPos,'NextIFD');    # add fixup for this offset in newData
        }
        # remember position of 'next IFD' pointer so we can set it next time around
        $nextIfdPos = length($nextIFD) ? $valPos - length($nextIFD) : undef;
        # add value data after IFD
        $newData .= $valBuff;
#
# add any subdirectories, adding fixup information
#
        if (@subdirs) {
            my $subdir;
            foreach $subdir (@subdirs) {
                my $len = length($newData);         # position of subdirectory in data
                my $subdirFixup = $$subdir{Fixup};
                if ($subdirFixup) {
                    $$subdirFixup{Start} += $len;
                    $fixup->AddFixup($subdirFixup);
                }
                my $imageData = $$subdir{ImageData};
                my $blockSize = 0;
                # must also update start position for ImageData fixups
                if (ref $imageData) {
                    my $blockInfo;
                    foreach $blockInfo (@$imageData) {
                        my ($pos, $size, $pad, $entry, $subFix) = @$blockInfo;
                        if ($subFix) {
                            $$subFix{Start} += $len;
                            # save expected image data offset for calculating shift later
                            $$subFix{BlockLen} = length(${$$subdir{DataPt}}) + $blockSize;
                        }
                        $blockSize += $size + $pad;
                    }
                }
                $newData .= ${$$subdir{DataPt}};    # add subdirectory to our data
                undef ${$$subdir{DataPt}};          # free memory now
                # set the pointer
                my $offset = $$subdir{Offset};
                # if offset is in valBuff, it was added to the end of dirBuff
                # (plus 4 bytes for nextIFD pointer)
                $offset += length($dirBuff) + 4 if $$subdir{Where} eq 'valBuff';
                $offset += $newStart + 2;           # get offset in newData
                # check to be sure we got the right offset
                unless (Get32u(\$newData, $offset) == 0xfeedf00d) {
                    $et->Error("Internal error while rewriting $name");
                    return undef;
                }
                # set the offset to the subdirectory data
                Set32u($len, \$newData, $offset);
                $fixup->AddFixup($offset);  # add fixup for this offset in newData
            }
        }
        # add fixup for all offsets in directory according to value data position
        # (which is at the end of this directory)
        if ($dirFixup) {
            $$dirFixup{Start} = $newStart + 2;
            $$dirFixup{Shift} = $valPos - $$dirFixup{Start};
            $fixup->AddFixup($dirFixup);
        }
        # add valueData fixups, adjusting for position of value data
        my $valFixup;
        foreach $valFixup (@valFixups) {
            $$valFixup{Start} += $valPos;
            $fixup->AddFixup($valFixup);
        }
        # stop if no next IFD pointer
        last unless $isNextIFD;   # stop unless scanning for multiple IFD's
        if ($nextIfdOffset) {
            # continue with next IFD
            $dirStart = $nextIfdOffset - $dataPos;
        } else {
            # create IFD1 if necessary
            $verbose and print $out "  Creating IFD1\n";
            my $ifd1 = "\0" x 2;  # empty IFD1 data (zero entry count)
            $dataPt = \$ifd1;
            $dirStart = 0;
            $dirLen = $dataLen = 2;
        }
        # increment IFD name
        my $ifdNum = $dirName =~ s/(\d+)$// ? $1 : 0;
        $dirName .= $ifdNum + 1;
        $name =~ s/\d+$//;
        $name .= $ifdNum + 1;
        $$et{DIR_NAME} = $$et{PATH}[-1] = $dirName;
        next unless $nextIfdOffset;

        # guard against writing the same directory twice
        my $addr = $nextIfdOffset + $base;
        if ($$et{PROCESSED}{$addr}) {
            $et->Error("$name pointer references previous $$et{PROCESSED}{$addr} directory", 1);
            last;
        }
        $$et{PROCESSED}{$addr} = $name;

        if ($dirName eq 'SubIFD1' and not ValidateIFD($dirInfo, $dirStart)) {
            if ($$et{TIFF_TYPE} eq 'TIFF') {
                $et->Error('Ignored bad IFD linked from SubIFD', 1);
            } elsif ($verbose) {
                $et->Warn('Ignored bad IFD linked from SubIFD');
            }
            last;   # don't write bad IFD
        }
        if ($$et{DEL_GROUP}{$dirName}) {
            $verbose and print $out "  Deleting $dirName\n";
            $raf and $et->Error("Deleting $dirName also deletes subsequent" .
                                      " IFD's and possibly image data", 1);
            ++$$et{CHANGED};
            if ($$et{DEL_GROUP}{$dirName} == 2 and
                $$et{ADD_DIRS}{$dirName})
            {
                my $emptyIFD = "\0" x 2;    # start with empty IFD
                $dataPt = \$emptyIFD;
                $dirStart = 0;
                $dirLen = $dataLen = 2;
            } else {
                last;   # don't write this IFD (or any subsequent IFD)
            }
        } else {
            $verbose and print $out "  Rewriting $name\n";
        }
    }
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    # do our fixups now so we can more easily calculate offsets below
    $fixup->ApplyFixup(\$newData);
    # write Sony HiddenData now if this is an ARW file
    if ($$et{HiddenData} and not $$dirInfo{Fixup} and $$et{FILE_TYPE} eq 'TIFF') {
        $fixup->SetMarkerPointers(\$newData, 'HiddenData', length($newData));
        my $hbuf;
        my $hd = $$et{HiddenData};
        if ($raf->Seek($$hd{Offset}, 0) and $raf->Read($hbuf, $$hd{Size}) == $$hd{Size} and
            $hbuf =~ /^\x55\x26\x11\x05\0/)
        {
            $newData .= $hbuf;
        } else {
            $et->Error('Error copying hidden data', 1);
        }
    }
#
# determine total block size for deferred data
#
    my $numBlocks = scalar @imageData;  # save this so we scan only existing blocks later
    my $blockSize = 0;  # total size of blocks to copy later
    my $blockInfo;
    foreach $blockInfo (@imageData) {
        my ($pos, $size, $pad) = @$blockInfo;
        $blockSize += $size + $pad;
    }
#
# copy over image data for IFD's, starting with the last IFD first
#
    if (@offsetInfo) {
        my $ttwLen;     # length of MRW TTW segment
        my @writeLater; # write image data last
        for ($ifd=$#offsetInfo; $ifd>=-1; --$ifd) {
            # build list of offsets to process
            my @offsetList;
            if ($ifd >= 0) {
                my $offsetInfo = $offsetInfo[$ifd] or next;
                if ($$offsetInfo{0x111} and $$offsetInfo{0x144}) {
                    # SubIFD may contain double-referenced data as both strips and tiles
                    # for Sony ARW files when SonyRawFileType is "Lossless Compressed RAW 2"
                    if ($dirName eq 'SubIFD' and $$et{TIFF_TYPE} eq 'ARW' and
                        $$offsetInfo{0x117} and $$offsetInfo{0x145} and
                        $$offsetInfo{0x111}[2]==1) # (must be a single strip or the tile offsets could get out of sync)
                    {
                        # check the start offsets to see if they are the same
                        if ($$offsetInfo{0x111}[3][0] == $$offsetInfo{0x144}[3][0]) {
                            # some Sony ARW images contain double-referenced raw data stored as both strips
                            # and tiles.  Copy the data using only the strip tags, but store the TileOffets
                            # information for updating later (see PanasonicRaw:PatchRawDataOffset for a
                            # description of offsetInfo elements)
                            $$offsetInfo{0x111}[5] = $$offsetInfo{0x144}; # hack to save TileOffsets
                            # delete tile information from offsetInfo because we will copy as strips
                            delete $$offsetInfo{0x144};
                            delete $$offsetInfo{0x145};
                        }
                    } else {
                        $et->Error("TIFF $dirName contains both strip and tile data");
                    }
                }
                # patch Panasonic RAW/RW2 StripOffsets/StripByteCounts if necessary
                my $stripOffsets = $$offsetInfo{0x111};
                my $rawDataOffset = $$offsetInfo{0x118};
                if ($stripOffsets and $$stripOffsets[0]{PanasonicHack} or
                    $rawDataOffset and $$rawDataOffset[0]{PanasonicHack})
                {
                    require Image::ExifTool::PanasonicRaw;
                    my $err = Image::ExifTool::PanasonicRaw::PatchRawDataOffset($offsetInfo, $raf, $ifd);
                    $err and $et->Error($err);
                }
                my $tagID;
                # loop through all tags in reverse numerical order so we save thumbnail
                # data before main image data if both exist in the same IFD
                foreach $tagID (reverse sort { $a <=> $b } keys %$offsetInfo) {
                    my $tagInfo = $$offsetInfo{$tagID}[0];
                    next unless $$tagInfo{IsOffset}; # handle byte counts with offsets
                    my $sizeInfo = $$offsetInfo{$$tagInfo{OffsetPair}};
                    $sizeInfo or $et->Error("No size tag for $dirName:$$tagInfo{Name}"), next;
                    my $dataTag = $$tagInfo{DataTag};
                    # write TIFF image data (strips or tiles) later if requested
                    if ($raf and defined $$origDirInfo{ImageData} and
                        ($tagID == 0x111 or $tagID == 0x144 or
                          # also defer writing of other big data such as JpgFromRaw in NEF
                          ($$sizeInfo[3][0] and
                           # (calculate approximate combined size of all blocks)
                           $$sizeInfo[3][0] * scalar(@{$$sizeInfo[3]}) > 1000000)) and
                        # but don't defer writing if replacing with new value
                        (not defined $dataTag or not defined $offsetData{$dataTag}))
                    {
                        push @writeLater, [ $$offsetInfo{$tagID}, $sizeInfo ];
                    } else {
                        push @offsetList, [ $$offsetInfo{$tagID}, $sizeInfo ];
                    }
                }
            } else {
                last unless @writeLater;
                # finally, copy all deferred data
                @offsetList = @writeLater;
            }
            my $offsetPair;
            foreach $offsetPair (@offsetList) {
                my ($tagInfo, $offsets, $count, $oldOffset) = @{$$offsetPair[0]};
                my ($cntInfo, $byteCounts, $count2, $oldSize, $format) = @{$$offsetPair[1]};
                # must be the same number of offset and byte count values
                unless ($count == $count2) {
                    $et->Error("Offsets/ByteCounts disagree on count for $$tagInfo{Name}");
                    return undef;
                }
                my $formatStr = $formatName[$format];
                # follow pointer to value data if necessary
                $count > 1 and $offsets = Get32u(\$newData, $offsets);
                my $n = $count * $formatSize[$format];
                $n > 4 and $byteCounts = Get32u(\$newData, $byteCounts);
                if ($byteCounts < 0 or $byteCounts + $n > length($newData)) {
                    $et->Error("Error reading $$tagInfo{Name} byte counts");
                    return undef;
                }
                # get offset base and data pos (abnormal for some preview images)
                my ($dbase, $dpos, $wrongBase, $subIfdDataFixup);
                if ($$tagInfo{IsOffset} eq '2') {
                    $dbase = $firstBase;
                    $dpos = $dataPos + $base - $firstBase;
                } else {
                    $dbase = $base;
                    $dpos = $dataPos;
                }
                # use different base if necessary for some offsets (Minolta A200)
                if ($$tagInfo{WrongBase}) {
                    my $self = $et;
                    #### eval WrongBase ($self)
                    $wrongBase = eval $$tagInfo{WrongBase} || 0;
                    $dbase += $wrongBase;
                    $dpos -= $wrongBase;
                } else {
                    $wrongBase = 0;
                }
                my $oldOrder = GetByteOrder();
                my $dataTag = $$tagInfo{DataTag};
                # use different byte order for values of this offset pair if required (Minolta A200)
                SetByteOrder($$tagInfo{ByteOrder}) if $$tagInfo{ByteOrder};
                # transfer the data referenced by all offsets of this tag
                for ($n=0; $n<$count; ++$n) {
                    my ($oldEnd, $size);
                    if (@$oldOffset and @$oldSize) {
                        # calculate end offset of this block
                        $oldEnd = $$oldOffset[$n] + $$oldSize[$n];
                        # update TIFF_END as if we read this data from file
                        UpdateTiffEnd($et, $oldEnd + $dbase);
                    }
                    my $offsetPos = $offsets + $n * 4;
                    my $byteCountPos = $byteCounts + $n * $formatSize[$format];
                    if ($$tagInfo{PanasonicHack}) {
                        # use actual raw data length (may be different than StripByteCounts!)
                        $size = $$oldSize[$n];
                    } else {
                        # use size of new data
                        $size = ReadValue(\$newData, $byteCountPos, $formatStr, 1, 4);
                    }
                    my $offset = $$oldOffset[$n];
                    if (defined $offset) {
                        $offset -= $dpos;
                    } elsif ($size != 0xfeedfeed) {
                        $et->Error('Internal error (no offset)');
                        return undef;
                    }
                    my $newOffset = length($newData) - $wrongBase;
                    my $buff;
                    # look for 'feed' code to use our new data
                    if ($size == 0xfeedfeed) {
                        unless (defined $dataTag) {
                            $et->Error("No DataTag defined for $$tagInfo{Name}");
                            return undef;
                        }
                        unless (defined $offsetData{$dataTag}) {
                            $et->Error("Internal error (no $dataTag)");
                            return undef;
                        }
                        if ($count > 1) {
                            $et->Error("Can't modify $$tagInfo{Name} with count $count");
                            return undef;
                        }
                        $buff = $offsetData{$dataTag};
                        if ($formatSize[$format] != 4) {
                            $et->Error("$$cntInfo{Name} is not int32");
                            return undef;
                        }
                        # set the data size
                        $size = length($buff);
                        Set32u($size, \$newData, $byteCountPos);
                    } elsif ($ifd < 0) {
                        # hack for fixed-offset data (Panasonic GH6)
                        if ($$offsetPair[0][6]) {
                            if ($count > 1) {
                                $et->Error("Can't handle fixed offsets with count > 1");
                            } else {
                                my $fixedOffset = Get32u(\$newData, $offsets);
                                my $padToFixedOffset = $fixedOffset - ($newOffset + $dpos);
                                if ($padToFixedOffset < 0) {
                                    $et->Error('Metadata too large to fit before fixed-offset image data');
                                } else {
                                    # add necessary padding before raw data
                                    push @imageData, [$offset+$dbase+$dpos, 0, $padToFixedOffset];
                                    $newOffset += $padToFixedOffset;
                                    $et->Warn("Adding $padToFixedOffset bytes of padding before fixed-offset image data", 1);
                                }
                            }
                        }
                        # pad if necessary (but don't pad contiguous image blocks)
                        my $pad = 0;
                        ++$pad if ($blockSize + $size) & 0x01 and ($n+1 >= $count or
                                  not $oldEnd or $oldEnd != $$oldOffset[$n+1]);
                        # preserve original image padding if specified
                        if ($$origDirInfo{PreserveImagePadding} and $n+1 < $count and
                            $oldEnd and $$oldOffset[$n+1] > $oldEnd)
                        {
                            $pad = $$oldOffset[$n+1] - $oldEnd;
                        }
                        # copy data later
                        push @imageData, [$offset+$dbase+$dpos, $size, $pad];
                        $newOffset += $blockSize;   # data comes after other deferred data
                        # create fixup for SubIFD ImageData
                        if ($imageDataFlag eq 'SubIFD' and not $subIfdDataFixup) {
                            $subIfdDataFixup = Image::ExifTool::Fixup->new;
                            $imageData[-1][4] = $subIfdDataFixup;
                        }
                        $size += $pad; # account for pad byte if necessary
                        # return ImageData list
                        $$origDirInfo{ImageData} = \@imageData;
                    } elsif ($offset >= 0 and $offset+$size <= $dataLen) {
                        # take data from old dir data buffer
                        $buff = substr($$dataPt, $offset, $size);
                    } elsif ($$et{TIFF_TYPE} eq 'MRW') {
                        # TTW segment must be an even 4 bytes long, so pad now if necessary
                        my $n = length $newData;
                        $buff = ($n & 0x03) ? "\0" x (4 - ($n & 0x03)) : '';
                        $size = length($buff);
                        # data exists after MRW TTW segment
                        $ttwLen = length($newData) + $size unless defined $ttwLen;
                        $newOffset = $offset + $dpos + $ttwLen - $dataLen;
                    } elsif ($raf and $raf->Seek($offset+$dbase+$dpos,0) and
                             $raf->Read($buff,$size) == $size)
                    {
                        # (data was read OK)
                        # patch incorrect ThumbnailOffset in Sony A100 1.00 ARW images
                        if ($$et{TIFF_TYPE} eq 'ARW' and $$tagInfo{Name} eq 'ThumbnailOffset' and
                            $$et{Model} eq 'DSLR-A100' and $buff !~ /^\xff\xd8\xff/)
                        {
                            my $pos = $offset + $dbase + $dpos;
                            my $try;
                            if ($pos < 0x10000 and $raf->Seek($pos+0x10000,0) and
                                $raf->Read($try,$size) == $size and $try =~ /^\xff\xd8\xff/)
                            {
                                $buff = $try;
                                $et->Warn('Adjusted incorrect A100 ThumbnailOffset', 1);
                            } else {
                                $et->Error('Invalid ThumbnailImage');
                            }
                        }
                    } elsif ($$tagInfo{Name} eq 'ThumbnailOffset' and $offset>=0 and $offset<$dataLen) {
                        # Grrr.  The Canon 350D writes the thumbnail with an incorrect byte count
                        my $diff = $offset + $size - $dataLen;
                        $et->Warn("ThumbnailImage runs outside EXIF data by $diff bytes (truncated)",1);
                        # set the size to the available data
                        $size -= $diff;
                        unless (WriteValue($size, $formatStr, 1, \$newData, $byteCountPos)) {
                            warn 'Internal error writing thumbnail size';
                        }
                        # get the truncated image
                        $buff = substr($$dataPt, $offset, $size);
                    } elsif ($$tagInfo{Name} eq 'PreviewImageStart' and $$et{FILE_TYPE} eq 'JPEG') {
                        # try to load the preview image using the specified offset
                        undef $buff;
                        my $r = $$et{RAF};
                        if ($r and not $raf) {
                            my $tell = $r->Tell();
                            # read and validate
                            undef $buff unless $r->Seek($offset+$base+$dataPos,0) and
                                               $r->Read($buff,$size) == $size and
                                               $buff =~ /^.\xd8\xff[\xc4\xdb\xe0-\xef]/s;
                            $r->Seek($tell, 0) or $et->Error('Seek error'), return undef;
                        }
                        # set flag if we must load PreviewImage
                        $buff = 'LOAD_PREVIEW' unless defined $buff;
                    } else {
                        my $dataName = $dataTag || $$tagInfo{Name};
                        return undef if $et->Error("Error reading $dataName data in $name", $inMakerNotes);
                        $buff = '';
                    }
                    if ($$tagInfo{Name} eq 'PreviewImageStart') {
                        if ($$et{FILE_TYPE} eq 'JPEG' and not $$tagInfo{MakerPreview}) {
                            # hold onto the PreviewImage until we can determine if it fits
                            $$et{PREVIEW_INFO} or $$et{PREVIEW_INFO} = {
                                Data => $buff,
                                Fixup => Image::ExifTool::Fixup->new,
                            };
                            if ($$tagInfo{IsOffset} and $$tagInfo{IsOffset} eq '2') {
                                $$et{PREVIEW_INFO}{NoBaseShift} = 1;
                            }
                            if ($offset >= 0 and $offset+$size <= $dataLen) {
                                # set flag indicating this preview wasn't in a trailer
                                $$et{PREVIEW_INFO}{WasContained} = 1;
                            }
                            $buff = '';
                        } elsif ($$et{TIFF_TYPE} eq 'ARW' and $$et{Model}  eq 'DSLR-A100') {
                            # the A100 double-references the same preview, so ignore the
                            # second one (the offset and size will be patched later)
                            next if $$et{A100PreviewLength};
                            $$et{A100PreviewLength} = length $buff if defined $buff;
                        }
                    }
                    # update offset accordingly and add to end of new data
                    Set32u($newOffset, \$newData, $offsetPos);
                    # add a pointer to fix up this offset value (marked with DataTag name)
                    $fixup->AddFixup($offsetPos, $dataTag);
                    # also add to subIfdDataFixup if necessary
                    $subIfdDataFixup->AddFixup($offsetPos, $dataTag) if $subIfdDataFixup;
                    # must also (sometimes) update StripOffsets in Panasonic RW2 images
                    # and TileOffsets in Sony ARW images
                    my $otherPos = $$offsetPair[0][5];
                    if ($otherPos) {
                        if ($$tagInfo{PanasonicHack}) {
                            Set32u($newOffset, \$newData, $otherPos);
                            $fixup->AddFixup($otherPos, $dataTag);
                        } elsif (ref $otherPos eq 'ARRAY') {
                            # the image data was copied as one large strip, and is double-referenced
                            # as tile data, so all we need to do now is properly update the tile offsets
                            my $oldRawDataOffset = $$offsetPair[0][3][0];
                            my $count = $$otherPos[2];
                            my $i;
                            # point to offsets in value data if more than one pointer
                            $$otherPos[1] = Get32u(\$newData, $$otherPos[1]) if $count > 1;
                            for ($i=0; $i<$count; ++$i) {
                                my $oldTileOffset = $$otherPos[3][$i];
                                my $ptrPos = $$otherPos[1] + 4 * $i;
                                Set32u($newOffset + $oldTileOffset - $oldRawDataOffset, \$newData, $ptrPos);
                                $fixup->AddFixup($ptrPos, $dataTag);
                                $subIfdDataFixup->AddFixup($ptrPos, $dataTag) if $subIfdDataFixup;
                            }
                        }
                    }
                    if ($ifd >= 0) {
                        # buff length must be even (Note: may have changed since $size was set)
                        $buff .= "\0" if length($buff) & 0x01;
                        $newData .= $buff;      # add this strip to the data
                    } else {
                        $blockSize += $size;    # keep track of total size
                    }
                }
                SetByteOrder($oldOrder);
            }
        }
        # verify that nothing else got written after determining TTW length
        if (defined $ttwLen and $ttwLen != length($newData)) {
            $et->Error('Internal error writing MRW TTW');
        }
    }
#
# set offsets and generate fixups for tag values which were too large for memory
#
    $blockSize = 0;
    foreach $blockInfo (@imageData) {
        my ($pos, $size, $pad, $entry, $subFix) = @$blockInfo;
        if (defined $entry) {
            my $format = Get16u(\$newData, $entry + 2);
            if ($format < 1 or $format > 13) {
                $et->Error('Internal error copying huge value');
                last;
            } else {
                # set count and offset in directory entry
                Set32u($size / $formatSize[$format], \$newData, $entry + 4);
                Set32u(length($newData)+$blockSize, \$newData, $entry + 8);
                $fixup->AddFixup($entry + 8);
                # create special fixup for SubIFD data
                if ($imageDataFlag eq 'SubIFD') {
                    my $subIfdDataFixup = Image::ExifTool::Fixup->new;
                    $subIfdDataFixup->AddFixup($entry + 8);
                    # save fixup in imageData list
                    $$blockInfo[4] = $subIfdDataFixup;
                }
                # must reset entry pointer so we don't use it again in a parent IFD!
                $$blockInfo[3] = undef;
            }
        }
        # apply additional shift required for contained SubIFD image data offsets
        if ($subFix and defined $$subFix{BlockLen} and $numBlocks > 0) {
            # our offset expects the data at the end of the SubIFD block (BlockLen + Start),
            # but it will actually be at length($newData) + $blockSize.  So adjust
            # accordingly (and subtract an extra Start because this shift is applied later)
            $$subFix{Shift} += length($newData) - $$subFix{BlockLen} - 2 * $$subFix{Start} + $blockSize;
            $subFix->ApplyFixup(\$newData);
        }
        $blockSize += $size + $pad;
        --$numBlocks;
    }
#
# apply final shift to new data position if this is the top level IFD
#
    unless ($$dirInfo{Fixup}) {
        my $hdrPtr = $$dirInfo{HeaderPtr};
        my $newDataPos = $hdrPtr ? length $$hdrPtr : $$dirInfo{NewDataPos} || 0;
        # adjust CanonVRD offset to point to end of regular TIFF if necessary
        # (NOTE: This will be incorrect if multiple trailers exist,
        #  but it is unlikely that it could ever be correct in this case anyway.
        #  Also, this doesn't work for JPEG images (but CanonDPP doesn't set
        #  this when editing JPEG images anyway))
        $fixup->SetMarkerPointers(\$newData, 'CanonVRD', length($newData) + $blockSize);
        if ($newDataPos) {
            $$fixup{Shift} += $newDataPos;
            $fixup->ApplyFixup(\$newData);
        }
        # save fixup for adjusting Leica trailer and Sony HiddenData offsets if necessary
        $$et{LeicaTrailer}{Fixup}->AddFixup($fixup) if $$et{LeicaTrailer};
        $$et{HiddenData}{Fixup}->AddFixup($fixup) if $$et{HiddenData};
        # save fixup for PreviewImage in JPEG file if necessary
        my $previewInfo = $$et{PREVIEW_INFO};
        if ($previewInfo) {
            my $pt = \$$previewInfo{Data}; # image data or 'LOAD_PREVIEW' flag
            # now that we know the size of the EXIF data, first test to see if our new image fits
            # inside the EXIF segment (remember about the TIFF and EXIF headers: 8+6 bytes)
            if (($$pt ne 'LOAD_PREVIEW' and length($$pt) + length($newData) + 14 <= 0xfffd and
                not $$previewInfo{IsTrailer}) or
                $$previewInfo{IsShort}) # must fit in this segment if using short pointers
            {
                # It fits! (or must exist in EXIF segment), so fixup the
                # PreviewImage pointers and stuff the preview image in here
                my $newPos = length($newData) + $newDataPos;
                $newPos += ($$previewInfo{BaseShift} || 0);
                if ($$previewInfo{Relative}) {
                    # calculate our base by looking at how far the pointer got shifted
                    $newPos -= ($fixup->GetMarkerPointers(\$newData, 'PreviewImage') || 0);
                }
                $fixup->SetMarkerPointers(\$newData, 'PreviewImage', $newPos);
                $newData .= $$pt;
                # set flag to delete old preview unless it was contained in the EXIF
                $$et{DEL_PREVIEW} = 1 unless $$et{PREVIEW_INFO}{WasContained};
                delete $$et{PREVIEW_INFO};   # done with our preview data
            } else {
                # Doesn't fit, or we still don't know, so save fixup information
                # and put the preview at the end of the file
                $$previewInfo{Fixup} or $$previewInfo{Fixup} = Image::ExifTool::Fixup->new;
                $$previewInfo{Fixup}->AddFixup($fixup);
            }
        } elsif (defined $newData and $deleteAll) {
            $newData = '';  # delete both IFD0 and IFD1 since only mandatory tags remain
        } elsif ($$et{A100PreviewLength}) {
            # save preview image start for patching A100 quirks later
            $$et{A100PreviewStart} = $fixup->GetMarkerPointers(\$newData, 'PreviewImage');
        }
        # save location of last IFD for use in Canon RAW header
        if ($newDataPos == 16) {
            my @ifdPos = $fixup->GetMarkerPointers(\$newData,'NextIFD');
            $$origDirInfo{LastIFD} = pop @ifdPos;
        }
        # recrypt SR2 SubIFD data if necessary
        my $key = $$et{SR2SubIFDKey};
        if ($key) {
            my $start = $fixup->GetMarkerPointers(\$newData, 'SR2SubIFDOffset');
            my $len = $$et{SR2SubIFDLength};
            # (must subtract 8 for size of TIFF header)
            if ($start and $start - 8 + $len <= length $newData) {
                require Image::ExifTool::Sony;
                Image::ExifTool::Sony::Decrypt(\$newData, $start - 8, $len, $key);
            }
        }
    }
    # return empty string if no entries in directory
    # (could be up to 10 bytes and still be empty)
    $newData = '' if defined $newData and length($newData) < 12;

    # set changed if ForceWrite tag was set to "EXIF"
    ++$$et{CHANGED} if defined $newData and length $newData and $$et{FORCE_WRITE}{EXIF};

    return $newData;    # return our directory data
}

1; # end

__END__

=head1 NAME

Image::ExifTool::WriteExif.pl - Write EXIF meta information

=head1 SYNOPSIS

This file is autoloaded by Image::ExifTool::Exif.

=head1 DESCRIPTION

This file contains routines to write EXIF metadata.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::Exif(3pm)|Image::ExifTool::Exif>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
