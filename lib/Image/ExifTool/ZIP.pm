#------------------------------------------------------------------------------
# File:         ZIP.pm
#
# Description:  Read ZIP archive meta information
#
# Revisions:    10/28/2007 - P. Harvey Created
#
# References:   1) http://www.pkware.com/documents/casestudies/APPNOTE.TXT
#               2) http://www.cpanforum.com/threads/9046
#               3) http://www.gzip.org/zlib/rfc-gzip.html
#               4) http://DataCompression.info/ArchiveFormats/RAR202.txt
#               5) https://jira.atlassian.com/browse/CONF-21706
#               6) http://wwwimages.adobe.com/www.adobe.com/content/dam/Adobe/en/devnet/indesign/cs55-docs/IDML/idml-specification.pdf
#               7) https://www.rarlab.com/technote.htm
#------------------------------------------------------------------------------

package Image::ExifTool::ZIP;

use strict;
use vars qw($VERSION $warnString);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.32';

sub WarnProc($) { $warnString = $_[0]; }

# file types for recognized Open Document "mimetype" values
my %openDocType = (
    'application/vnd.oasis.opendocument.database'     => 'ODB', #5
    'application/vnd.oasis.opendocument.chart'        => 'ODC', #5
    'application/vnd.oasis.opendocument.formula'      => 'ODF', #5
    'application/vnd.oasis.opendocument.graphics'     => 'ODG', #5
    'application/vnd.oasis.opendocument.image'        => 'ODI', #5
    'application/vnd.oasis.opendocument.presentation' => 'ODP',
    'application/vnd.oasis.opendocument.spreadsheet'  => 'ODS',
    'application/vnd.oasis.opendocument.text'         => 'ODT',
    'application/vnd.adobe.indesign-idml-package'     => 'IDML', #6 (not open doc)
    'application/epub+zip' => 'EPUB', #PH (not open doc)
);

# iWork file types based on names of files found in the zip archive
my %iWorkFile = (
    'Index/Slide.iwa' => 'KEY',
    'Index/Tables/DataList.iwa' => 'NUMBERS',
);

my %iWorkType = (
    NUMBERS => 'NUMBERS',
    PAGES   => 'PAGES',
    KEY     => 'KEY',
    KTH     => 'KTH',
    NMBTEMPLATE => 'NMBTEMPLATE',
);

# ZIP metadata blocks
%Image::ExifTool::ZIP::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Other' },
    FORMAT => 'int16u',
    NOTES => q{
        The following tags are extracted from ZIP archives.  ExifTool also extracts
        additional meta information from compressed documents inside some ZIP-based
        files such Office Open XML (DOCX, PPTX and XLSX), Open Document (ODB, ODC,
        ODF, ODG, ODI, ODP, ODS and ODT), iWork (KEY, PAGES, NUMBERS), Capture One
        Enhanced Image Package (EIP), Adobe InDesign Markup Language (IDML),
        Electronic Publication (EPUB), and Sketch design files (SKETCH).  The
        ExifTool family 3 groups may be used to organize ZIP tags by embedded
        document number (ie. the exiftool C<-g3> option).
    },
    2 => 'ZipRequiredVersion',
    3 => {
        Name => 'ZipBitFlag',
        PrintConv => '$val ? sprintf("0x%.4x",$val) : $val',
    },
    4 => {
        Name => 'ZipCompression',
        PrintConv => {
            0 => 'None',
            1 => 'Shrunk',
            2 => 'Reduced with compression factor 1',
            3 => 'Reduced with compression factor 2',
            4 => 'Reduced with compression factor 3',
            5 => 'Reduced with compression factor 4',
            6 => 'Imploded',
            7 => 'Tokenized',
            8 => 'Deflated',
            9 => 'Enhanced Deflate using Deflate64(tm)',
           10 => 'Imploded (old IBM TERSE)',
           12 => 'BZIP2',
           14 => 'LZMA (EFS)',
           18 => 'IBM TERSE (new)',
           19 => 'IBM LZ77 z Architecture (PFS)',
           96 => 'JPEG recompressed', #2
           97 => 'WavPack compressed', #2
           98 => 'PPMd version I, Rev 1',
       },
    },
    5 => {
        Name => 'ZipModifyDate',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        ValueConv => sub {
            my $val = shift;
            return sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d',
                ($val >> 25) + 1980, # year
                ($val >> 21) & 0x0f, # month
                ($val >> 16) & 0x1f, # day
                ($val >> 11) & 0x1f, # hour
                ($val >> 5)  & 0x3f, # minute
                ($val        & 0x1f) * 2  # second
            );
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    7 => { Name => 'ZipCRC', Format => 'int32u', PrintConv => 'sprintf("0x%.8x",$val)' },
    9 => { Name => 'ZipCompressedSize',    Format => 'int32u' },
    11 => { Name => 'ZipUncompressedSize', Format => 'int32u' },
    13 => {
        Name => 'ZipFileNameLength',
        # don't store a tag -- just extract the value for use with ZipFileName
        Hidden => 1,
        RawConv => '$$self{ZipFileNameLength} = $val; undef',
    },
    # 14 => 'ZipExtraFieldLength',
    15 => {
        Name => 'ZipFileName',
        Format => 'string[$$self{ZipFileNameLength}]',
    },
    _com => 'ZipFileComment',
);

# GNU ZIP tags (ref 3)
%Image::ExifTool::ZIP::GZIP = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Other' },
    NOTES => q{
        These tags are extracted from GZIP (GNU ZIP) archives, but currently only
        for the first file in the archive.
    },
    2 => {
        Name => 'Compression',
        PrintConv => {
            8 => 'Deflated',
        },
    },
    3 => {
        Name => 'Flags',
        PrintConv => { BITMASK => {
            0 => 'Text',
            1 => 'CRC16',
            2 => 'ExtraFields',
            3 => 'FileName',
            4 => 'Comment',
        }},
    },
    4 => {
        Name => 'ModifyDate',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        ValueConv => 'ConvertUnixTime($val,1)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    8 => {
        Name => 'ExtraFlags',
        PrintConv => {
            0 => '(none)',
            2 => 'Maximum Compression',
            4 => 'Fastest Algorithm',
        },
    },
    9 => {
        Name => 'OperatingSystem',
        PrintConv => {
            0 => 'FAT filesystem (MS-DOS, OS/2, NT/Win32)',
            1 => 'Amiga',
            2 => 'VMS (or OpenVMS)',
            3 => 'Unix',
            4 => 'VM/CMS',
            5 => 'Atari TOS',
            6 => 'HPFS filesystem (OS/2, NT)',
            7 => 'Macintosh',
            8 => 'Z-System',
            9 => 'CP/M',
            10 => 'TOPS-20',
            11 => 'NTFS filesystem (NT)',
            12 => 'QDOS',
            13 => 'Acorn RISCOS',
            255 => 'unknown',
        },
    },
    10 => 'ArchivedFileName',
    11 => 'Comment',
);

# RAR v4 tags (ref 4)
%Image::ExifTool::ZIP::RAR = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Other' },
    NOTES => 'These tags are extracted from RAR archive files.',
    0 => {
        Name => 'CompressedSize',
        Format => 'int32u',
    },
    4 => {
        Name => 'UncompressedSize',
        Format => 'int32u',
    },
    8 => {
        Name => 'OperatingSystem',
        PrintConv => {
            0 => 'MS-DOS',
            1 => 'OS/2',
            2 => 'Win32',
            3 => 'Unix',
        },
    },
    13 => {
        Name => 'ModifyDate',
        Format => 'int32u',
        Groups => { 2 => 'Time' },
        ValueConv => sub {
            my $val = shift;
            return sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d',
                ($val >> 25) + 1980, # year
                ($val >> 21) & 0x0f, # month
                ($val >> 16) & 0x1f, # day
                ($val >> 11) & 0x1f, # hour
                ($val >> 5)  & 0x3f, # minute
                ($val        & 0x1f) * 2  # second
            );
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    18 => {
        Name => 'PackingMethod',
        PrintHex => 1,
        PrintConv => {
            0x30 => 'Stored',
            0x31 => 'Fastest',
            0x32 => 'Fast',
            0x33 => 'Normal',
            0x34 => 'Good Compression',
            0x35 => 'Best Compression',
        },
    },
    19 => {
        Name => 'FileNameLength',
        Format => 'int16u',
        Hidden => 1,
        RawConv => '$$self{FileNameLength} = $val; undef',
    },
    25 => {
        Name => 'ArchivedFileName',
        Format => 'string[$$self{FileNameLength}]',
    },
);

# RAR v5 tags (ref 7, github#203)
%Image::ExifTool::ZIP::RAR5 = (
    GROUPS => { 2 => 'Other' },
    VARS => { NO_ID => 1 },
    NOTES => 'These tags are extracted from RAR v5 and 7z archive files.',
    FileVersion     => { },
    CompressedSize  => { },
    ModifyDate => {
        Groups => { 2 => 'Time' },
        ValueConv => 'ConvertUnixTime($val,1)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    UncompressedSize => { },
    OperatingSystem => {
        PrintConv => { 0 => 'Win32', 1 => 'Unix' },
    },
    ArchivedFileName => { },
);

#------------------------------------------------------------------------------
# Read unsigned LEB (Little Endian Base) from file
# Inputs: 0) RAF ref
# Returns: integer value
sub ReadULEB($)
{
    my $raf = shift;
    my ($i, $buff);
    my $rtnVal = 0;
    for ($i=0; ; ++$i) {
        $raf->Read($buff, 1) or last;
        my $num = ord($buff);
        $rtnVal += ($num & 0x7f) << ($i * 7);
        $num & 0x80 or last;
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Extract information from a RAR file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid RAR file
sub ProcessRAR($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($flags, $buff);
    my $docNum = 0;

    return 0 unless $raf->Read($buff, 7) and $buff =~ "Rar!\x1a\x07[\0\x01]";

    if ($buff eq "Rar!\x1a\x07\0") { # RARv4 (ref 4)

        $et->SetFileType();
        SetByteOrder('II');
        my $tagTablePtr = GetTagTable('Image::ExifTool::ZIP::RAR5');
        $et->HandleTag($tagTablePtr, 'FileVersion', 'RAR v4');
        $tagTablePtr = GetTagTable('Image::ExifTool::ZIP::RAR');

        for (;;) {
            # read block header
            $raf->Read($buff, 7) == 7 or last;
            my ($type, $flags, $size) = unpack('xxCvv', $buff);
            $size -= 7;
            if ($flags & 0x8000) {
                $raf->Read($buff, 4) == 4 or last;
                $size += unpack('V',$buff) - 4;
            }
            last if $size < 0;
            next unless $size;  # ignore blocks with no data
            # don't try to read very large blocks unless LargeFileSupport is enabled
            if ($size >= 0x80000000) {
                if (not $et->Options('LargeFileSupport')) {
                    $et->Warn('Large block encountered. Aborting.');
                    last;
                } elsif ($et->Options('LargeFileSupport') eq '2') {
                    $et->Warn('Processing large block (LargeFileSupport is 2)');
                }
            }
            # process the block
            if ($type == 0x74) { # file block
                # read maximum 4 KB from a file block
                my $n = $size > 4096 ? 4096 : $size;
                $raf->Read($buff, $n) == $n or last;
                # add compressed size to start of data so we can extract it with the other tags
                $buff = pack('V',$size) . $buff;
                $$et{DOC_NUM} = ++$docNum;
                $et->ProcessDirectory({ DataPt => \$buff }, $tagTablePtr);
                $size -= $n;
            } elsif ($type == 0x75 and $size > 6) { # comment block
                $raf->Read($buff, $size) == $size or last;
                # save comment, only if "Stored" (this is untested)
                if (Get8u(\$buff, 3) == 0x30) {
                    $et->FoundTag('Comment', substr($buff, 6));
                }
                next;
            }
            # seek to the start of the next block
            $raf->Seek($size, 1) or last if $size;
        }

    } else { # RARv5 (ref 7, github#203)

        return 0 unless $raf->Read($buff, 1) and $buff eq "\0";
        $et->SetFileType();
        my $tagTablePtr = GetTagTable('Image::ExifTool::ZIP::RAR5');
        $et->HandleTag($tagTablePtr, 'FileVersion', 'RAR v5');
        $$et{INDENT} .= '| ';

        # loop through header blocks
        for (;;) {
            $raf->Seek(4, 1);                   # skip header CRC
            my $headSize = ReadULEB($raf);
            last if $headSize == 0;
            # read the header and create new RAF object for reading it
            my $header;
            $raf->Read($header, $headSize) == $headSize or last;
            my $rafHdr = File::RandomAccess->new(\$header);
            my $headType = ReadULEB($rafHdr);   # get header type

            if ($headType == 4) {  # encryption block
                $et->Warn("File is encrypted.", 0);
                last;
            }
            # skip over all headers except file or service header
            next unless $headType == 2 or $headType == 3;
            $et->VerboseDir('RAR5 file', undef, $headSize) if $headType == 2;
            
            my $headFlag = ReadULEB($rafHdr);
            ReadULEB($rafHdr);                  # skip extraSize
            my $dataSize;
            if ($headFlag & 0x0002) {
                $dataSize = ReadULEB($rafHdr);  # compressed data size
                if ($headType == 2) {
                    $et->HandleTag($tagTablePtr, 'CompressedSize', $dataSize);
                } else {
                    $raf->Seek($dataSize, 1);   # skip service data section
                    next;
                }
            } else {
                next if $headType == 3;         # all done with service header
                $dataSize = 0;
            }
            my $fileFlag = ReadULEB($rafHdr);
            my $uncompressedSize = ReadULEB($rafHdr);
            $et->HandleTag($tagTablePtr, 'UncompressedSize', $uncompressedSize) unless $fileFlag & 0x0008;
            ReadULEB($rafHdr);                  # skip file attributes
            if ($fileFlag & 0x0002) {
                $rafHdr->Read($buff, 4) == 4 or last;
                # (untested)
                $et->HandleTag($tagTablePtr, 'ModifyDate', unpack('V', $buff));
            }
            $rafHdr->Seek(4, 1) if $fileFlag & 0x0004;  # skip CRC if present

            ReadULEB($rafHdr);                  # skip compressionInfo

            # get operating system
            my $os = ReadULEB($rafHdr);
            $et->HandleTag($tagTablePtr, 'OperatingSystem', $os);

            # get filename
            $rafHdr->Read($buff, 1) == 1 or last;
            my $nameLen = ord($buff);
            $rafHdr->Read($buff, $nameLen) == $nameLen or last;
            $buff =~ s/\0+$//;  # remove trailing nulls (if any)
            $et->HandleTag($tagTablePtr, 'ArchivedFileName', $buff);

            $$et{DOC_NUM} = ++$docNum;

            $raf->Seek($dataSize, 1);           # skip data section
        }
        $$et{INDENT} = substr($$et{INDENT}, 0, -2);
    }

    $$et{DOC_NUM} = 0;
    if ($docNum > 1 and not $et->Options('Duplicates')) {
        $et->Warn("Use the Duplicates option to extract tags for all $docNum files", 1);
    }

    return 1;
}

#------------------------------------------------------------------------------
# Extract information from a GNU ZIP file (ref 3)
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid GZIP file
sub ProcessGZIP($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($flags, $buff);

    return 0 unless $raf->Read($buff, 10) and $buff =~ /^\x1f\x8b\x08/;

    $et->SetFileType();
    SetByteOrder('II');

    my $tagTablePtr = GetTagTable('Image::ExifTool::ZIP::GZIP');
    $et->HandleTag($tagTablePtr, 2, Get8u(\$buff, 2));
    $et->HandleTag($tagTablePtr, 3, $flags = Get8u(\$buff, 3));
    $et->HandleTag($tagTablePtr, 4, Get32u(\$buff, 4));
    $et->HandleTag($tagTablePtr, 8, Get8u(\$buff, 8));
    $et->HandleTag($tagTablePtr, 9, Get8u(\$buff, 9));

    # extract file name and comment if they exist
    if ($flags & 0x18) {
        if ($flags & 0x04) {
            # skip extra field
            $raf->Read($buff, 2) == 2 or return 1;
            my $len = Get16u(\$buff, 0);
            $raf->Read($buff, $len) == $len or return 1;
        }
        $raf->Read($buff, 4096) or return 1;
        my $pos = 0;
        my $tagID;
        # loop for ArchivedFileName (10) and Comment (11) tags
        foreach $tagID (10, 11) {
            my $mask = $tagID == 10 ? 0x08 : 0x10;
            next unless $flags & $mask;
            my $end = $buff =~ /\0/g ? pos($buff) - 1 : length($buff);
            # (the doc specifies the string should be ISO 8859-1,
            # but in OS X it seems to be UTF-8, so don't translate
            # it because I could just as easily screw it up)
            my $str = substr($buff, $pos, $end - $pos);
            $et->HandleTag($tagTablePtr, $tagID, $str);
            last if $end >= length $buff;
            $pos = $end + 1;
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Call HandleTags for attributes of an Archive::Zip member
# Inputs: 0) ExifTool object ref, 1) member ref, 2) optional tag table ref
sub HandleMember($$;$)
{
    my ($et, $member, $tagTablePtr) = @_;
    $tagTablePtr or  $tagTablePtr = GetTagTable('Image::ExifTool::ZIP::Main');
    $et->HandleTag($tagTablePtr, 2, $member->versionNeededToExtract());
    $et->HandleTag($tagTablePtr, 3, $member->bitFlag());
    $et->HandleTag($tagTablePtr, 4, $member->compressionMethod());
    $et->HandleTag($tagTablePtr, 5, $member->lastModFileDateTime());
    $et->HandleTag($tagTablePtr, 7, $member->crc32());
    $et->HandleTag($tagTablePtr, 9, $member->compressedSize());
    $et->HandleTag($tagTablePtr, 11, $member->uncompressedSize());
    $et->HandleTag($tagTablePtr, 15, $member->fileName());
    my $com = $member->fileComment();
    $et->HandleTag($tagTablePtr, '_com', $com) if defined $com and length $com;
}

#------------------------------------------------------------------------------
# Extract file from ZIP archive
# Inputs: 0) ExifTool ref, 1) Zip object ref, 2) file name
# Returns: zip member or undef it it didn't exist
sub ExtractFile($$$)
{
    my ($et, $zip, $file) = @_;
    my $result = $zip->memberNamed($file);
    $et->VPrint(1, "  (Extracting '${file}' from zip archive)\n");
    return $result;
}

#------------------------------------------------------------------------------
# Extract information from a ZIP file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid ZIP file
sub ProcessZIP($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $buf2, $zip);

    return 0 unless $raf->Read($buff, 30) == 30 and $buff =~ /^PK\x03\x04/;

    my $tagTablePtr = GetTagTable('Image::ExifTool::ZIP::Main');
    my $docNum = 0;

    # use Archive::Zip if available
    for (;;) {
        unless (eval { require Archive::Zip } and eval { require IO::File }) {
            if ($$et{FILE_EXT} and $$et{FILE_EXT} ne 'ZIP') {
                $et->Warn("Install Archive::Zip to decode compressed ZIP information");
            }
            last;
        }
        # Archive::Zip requires a seekable IO::File object
        my $fh;
        if ($raf->{TESTED} >= 0) {
            unless (eval { require IO::File }) {
                # (this shouldn't happen because IO::File is a prerequisite of Archive::Zip)
                $et->Warn("Install IO::File to decode compressed ZIP information");
                last;
            }
            $raf->Seek(0,0);
            $fh = $raf->{FILE_PT};
            bless $fh, 'IO::File';  # Archive::Zip expects an IO::File object
        } elsif (eval { require IO::String }) {
            # read the whole file into memory (what else can I do?)
            $raf->Slurp();
            $fh = IO::String->new(${$raf->{BUFF_PT}});
        } else {
            my $type = $raf->{FILE_PT} ? 'pipe or socket' : 'scalar reference';
            $et->Warn("Install IO::String to decode compressed ZIP information from a $type");
            last;
        }
        $et->VPrint(1, "  --- using Archive::Zip ---\n");
        $zip = Archive::Zip->new;
        # catch all warnings! (Archive::Zip is bad for this)
        local $SIG{'__WARN__'} = \&WarnProc;
        my $status = $zip->readFromFileHandle($fh);
        if ($status eq '4' and $raf->{TESTED} >= 0 and eval { require IO::String } and
            $raf->Seek(0,2) and $raf->Tell() < 100000000)
        {
            # try again, reading it ourself this time in an attempt to avoid
            # a failed test with Perl 5.6.2 GNU/Linux 2.6.32-5-686 i686-linux-64int-ld
            $raf->Seek(0,0);
            $raf->Slurp();
            $fh = IO::String->new(${$raf->{BUFF_PT}});
            $zip = Archive::Zip->new;
            $status = $zip->readFromFileHandle($fh);
        }
        if ($status) {
            undef $zip;
            my %err = ( 1=>'Stream end error', 3=>'Format error', 4=>'IO error' );
            my $err = $err{$status} || "Error $status";
            $et->Warn("$err reading ZIP file");
            last;
        }
        # extract zip file comment
        my $comment = $zip->zipfileComment();
        $et->FoundTag(Comment => $comment) if defined $comment and length $comment;

        $$dirInfo{ZIP} = $zip;

        # check for an Office Open file (DOCX, etc)
        # --> read '[Content_Types].xml' to determine the file type
        my ($mime, @members);
        my $cType = ExtractFile($et, $zip, '[Content_Types].xml');
        if ($cType) {
            ($buff, $status) = $zip->contents($cType);
            if (not $status and (
                # first look for the main document with the expected name
                $buff =~ m{\sPartName\s*=\s*['"](?:/ppt/presentation.xml|/word/document.xml|/xl/workbook.xml)['"][^>]*\sContentType\s*=\s*(['"])([^"']+)\.main(\+xml)?\1} or
                # then look for the main part
                $buff =~ /<Override[^>]*\sPartName[^<]+\sContentType\s*=\s*(['"])([^"']+)\.main(\+xml)?\1/ or
                # and if all else fails, use the default main
                $buff =~ /ContentType\s*=\s*(['"])([^"']+)\.main(\+xml)?\1/))
            {
                $mime = $2;
            }
        }
        # check for docProps if we couldn't find a MIME type
        $mime or @members = $zip->membersMatching('^docProps/.*\.(xml|XML)$');
        if ($mime or @members) {
            $$dirInfo{MIME} = $mime;
            require Image::ExifTool::OOXML;
            Image::ExifTool::OOXML::ProcessDOCX($et, $dirInfo);
            delete $$dirInfo{MIME};
            last;
        }

        # check for an EIP file
        @members = $zip->membersMatching('^CaptureOne/.*\.(cos|COS)$');
        if (@members) {
            require Image::ExifTool::CaptureOne;
            Image::ExifTool::CaptureOne::ProcessEIP($et, $dirInfo);
            last;
        }

        # check for an iWork file
        @members = $zip->membersMatching('(?i)^(index\.(xml|apxl)|QuickLook/Thumbnail\.jpg|[^/]+\.(pages|numbers|key)/Index.(zip|xml|apxl))$');
        if (@members) {
            require Image::ExifTool::iWork;
            Image::ExifTool::iWork::Process_iWork($et, $dirInfo);
            last;
        }

        # check for an Open Document, IDML or EPUB file
        my $mType = ExtractFile($et, $zip, 'mimetype');
        if ($mType) {
            ($mime, $status) = $zip->contents($mType);
            if (not $status and $mime =~ /([\x21-\xfe]+)/s) {
                # clean up MIME type just in case (note that MIME is case insensitive)
                $mime = lc $1;
                $et->SetFileType($openDocType{$mime} || 'ZIP', $mime);
                $et->Warn("Unrecognized MIMEType $mime") unless $openDocType{$mime};
                # extract Open Document metadata from "meta.xml"
                my $meta = ExtractFile($et, $zip, 'meta.xml');
                # IDML files have metadata in a different place (ref 6)
                $meta or $meta = ExtractFile($et, $zip, 'META-INF/metadata.xml');
                if ($meta) {
                    ($buff, $status) = $zip->contents($meta);
                    unless ($status) {
                        my %dirInfo = (
                            DirName => 'XML',
                            DataPt  => \$buff,
                            DirLen  => length $buff,
                            DataLen => length $buff,
                        );
                        # (avoid structure warnings when copying from XML)
                        my $oldWarn = $$et{NO_STRUCT_WARN};
                        $$et{NO_STRUCT_WARN} = 1;
                        $et->ProcessDirectory(\%dirInfo, GetTagTable('Image::ExifTool::XMP::Main'));
                        $$et{NO_STRUCT_WARN} = $oldWarn;
                    }
                }
                # process rootfile of EPUB container if applicable
                for (;;) {
                    last if $meta and $mime ne 'application/epub+zip';
                    my $container = ExtractFile($et, $zip, 'META-INF/container.xml');
                    ($buff, $status) = $zip->contents($container);
                    last if $status;
                    $buff =~ /<rootfile\s+[^>]*?\bfull-path=(['"])(.*?)\1/s or last;
                    # load the rootfile data (OPF extension; contains XML metadata)
                    my $meta2 = $zip->memberNamed($2) or last;
                    $meta = $meta2;
                    ($buff, $status) = $zip->contents($meta);
                    last if $status;
                    # use opf:event to generate more meaningful tag names for dc:date
                    while ($buff =~ s{<dc:date opf:event="(\w+)">([^<]+)</dc:date>}{<dc:${1}Date>$2</dc:${1}Date>}s) {
                        my $dcTable = GetTagTable('Image::ExifTool::XMP::dc');
                        my $tag = "${1}Date";
                        AddTagToTable($dcTable, $tag, {
                            Name => ucfirst $tag,
                            Groups => { 2 => 'Time' },
                            List => 'Seq',
                            %Image::ExifTool::XMP::dateTimeInfo
                        }) unless $$dcTable{$tag};
                    }
                    my %dirInfo = (
                        DataPt => \$buff,
                        DirLen => length $buff,
                        DataLen => length $buff,
                        IgnoreProp => { 'package' => 1, metadata => 1 },
                    );
                    # (avoid structure warnings when copying from XML)
                    my $oldWarn = $$et{NO_STRUCT_WARN};
                    $$et{NO_STRUCT_WARN} = 1;
                    $et->ProcessDirectory(\%dirInfo, GetTagTable('Image::ExifTool::XMP::XML'));
                    $$et{NO_STRUCT_WARN} = $oldWarn;
                    last;
                }
                if ($openDocType{$mime} or $meta) {
                    # extract preview image(s) from "Thumbnails" directory if they exist
                    my $type;
                    my %tag = ( jpg => 'PreviewImage', png => 'PreviewPNG' );
                    foreach $type ('jpg', 'png') {
                        my $thumb = ExtractFile($et, $zip, "Thumbnails/thumbnail.$type");
                        next unless $thumb;
                        ($buff, $status) = $zip->contents($thumb);
                        $et->FoundTag($tag{$type}, $buff) unless $status;
                    }
                    last;   # all done since we recognized the MIME type or found metadata
                }
                # continue on to list ZIP contents...
            }
        }

        # otherwise just extract general ZIP information
        $et->SetFileType();
        @members = $zip->members();
        my ($member, $iWorkType);
        # special files to extract
        my %extract = (
            'meta.json' => 1,
            'previews/preview.png' => 'PreviewPNG',
            'preview.jpg' => 'PreviewImage', # (iWork 2013 files)
            'preview-web.jpg' => 'OtherImage', # (iWork 2013 files)
            'preview-micro.jpg' => 'ThumbnailImage', # (iWork 2013 files)
            'QuickLook/Thumbnail.jpg' => 'ThumbnailImage', # (iWork 2009 files)
            'QuickLook/Preview.pdf' => 'PreviewPDF', # (iWork 2009 files)
        );
        foreach $member (@members) {
            $$et{DOC_NUM} = ++$docNum;
            HandleMember($et, $member, $tagTablePtr);
            my $file = $member->fileName();
            # extract things from Sketch files
            if ($extract{$file}) {
                ($buff, $status) = $zip->contents($member);
                $status and $et->Warn("Error extracting $file"), next;
                if ($file eq 'meta.json') {
                    $et->ExtractInfo(\$buff, { ReEntry => 1 });
                    if ($$et{VALUE}{App} and $$et{VALUE}{App} =~ /sketch/i) {
                        $et->OverrideFileType('SKETCH');
                    }
                } else {
                    $et->FoundTag($extract{$file} => $buff);
                }
            } elsif ($file eq 'Index/Document.iwa' and not $iWorkType) {
                my $type = $iWorkType{$$et{FILE_EXT} || ''};
                $iWorkType = $type || 'PAGES';
            } elsif ($iWorkFile{$file}) {
                $iWorkType = $iWorkFile{$file};
            }
        }
        $et->OverrideFileType($iWorkType) if $iWorkType;
        last;
    }
    # all done if we processed this using Archive::Zip
    if ($zip) {
        delete $$dirInfo{ZIP};
        delete $$et{DOC_NUM};
        if ($docNum > 1 and not $et->Options('Duplicates')) {
            $et->Warn("Use the Duplicates option to extract tags for all $docNum files", 1);
        }
        return 1;
    }
#
# process the ZIP file by hand (funny, but this seems easier than using Archive::Zip)
#
    $et->VPrint(1, "  -- processing as binary data --\n");
    $raf->Seek(30, 0);
    $et->SetFileType();
    SetByteOrder('II');

    #  A.  Local file header:
    #  local file header signature     0) 4 bytes  (0x04034b50)
    #  version needed to extract       4) 2 bytes
    #  general purpose bit flag        6) 2 bytes
    #  compression method              8) 2 bytes
    #  last mod file time             10) 2 bytes
    #  last mod file date             12) 2 bytes
    #  crc-32                         14) 4 bytes
    #  compressed size                18) 4 bytes
    #  uncompressed size              22) 4 bytes
    #  file name length               26) 2 bytes
    #  extra field length             28) 2 bytes
    for (;;) {
        my $len = Get16u(\$buff, 26) + Get16u(\$buff, 28);
        $raf->Read($buf2, $len) == $len or last;

        $$et{DOC_NUM} = ++$docNum;
        $buff .= $buf2;
        my %dirInfo = (
            DataPt => \$buff,
            DataPos => $raf->Tell() - 30 - $len,
            DataLen => 30 + $len,
            DirStart => 0,
            DirLen => 30 + $len,
            MixedTags => 1, # (to ignore FileComment tag)
        );
        $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
        my $flags = Get16u(\$buff, 6);
        if ($flags & 0x08) {
            # we don't yet support skipping stream mode data
            # (when this happens, the CRC, compressed size and uncompressed
            #  sizes are set to 0 in the header.  Instead, they are stored
            #  after the compressed data with an optional header of 0x08074b50)
            $et->Warn('Stream mode data encountered, file list may be incomplete');
            last;
        }
        $len = Get32u(\$buff, 18);      # file data length
        $raf->Seek($len, 1) or last;    # skip file data
        $raf->Read($buff, 30) == 30 and $buff =~ /^PK\x03\x04/ or last;
    }
    delete $$et{DOC_NUM};
    if ($docNum > 1 and not $et->Options('Duplicates')) {
        $et->Warn("Use the Duplicates option to extract tags for all $docNum files", 1);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::ZIP - Read ZIP archive meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information from ZIP, GZIP and RAR archives.  This includes ZIP-based file
types like Office Open XML (DOCX, PPTX and XLSX), Open Document (ODB, ODC,
ODF, ODG, ODI, ODP, ODS and ODT), iWork (KEY, PAGES, NUMBERS), Capture One
Enhanced Image Package (EIP), Adobe InDesign Markup Language (IDML),
Electronic Publication (EPUB), and Sketch design files (SKETCH).

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.pkware.com/documents/casestudies/APPNOTE.TXT>

=item L<http://www.gzip.org/zlib/rfc-gzip.html>

=item L<http://DataCompression.info/ArchiveFormats/RAR202.txt>

=item L<https://www.rarlab.com/technote.htm>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/ZIP Tags>,
L<Image::ExifTool::TagNames/OOXML Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

