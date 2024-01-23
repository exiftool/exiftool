#------------------------------------------------------------------------------
# File:         PostScript.pm
#
# Description:  Read PostScript meta information
#
# Revisions:    07/08/2005 - P. Harvey Created
#
# References:   1) http://partners.adobe.com/public/developer/en/ps/5002.EPSF_Spec.pdf
#               2) http://partners.adobe.com/public/developer/en/ps/5001.DSC_Spec.pdf
#               3) http://partners.adobe.com/public/developer/en/illustrator/sdk/AI7FileFormat.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::PostScript;

use strict;
use vars qw($VERSION $AUTOLOAD);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.45';

sub WritePS($$);
sub ProcessPS($$;$);

# PostScript tag table
%Image::ExifTool::PostScript::Main = (
    PROCESS_PROC => \&ProcessPS,
    WRITE_PROC => \&WritePS,
    PREFERRED => 1, # always add these tags when writing
    GROUPS => { 2 => 'Image' },
    # Note: Make all of these tags priority 0 since the first one found at
    # the start of the file should take priority (in case multiples exist)
    Author      => { Priority => 0, Groups => { 2 => 'Author' }, Writable => 'string' },
    BoundingBox => { Priority => 0 },
    Copyright   => { Priority => 0, Writable => 'string' }, #2
    CreationDate => {
        Name => 'CreateDate',
        Priority => 0,
        Groups => { 2 => 'Time' },
        Writable => 'string',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    Creator     => { Priority => 0, Writable => 'string' },
    ImageData   => { Priority => 0 },
    For         => { Priority => 0, Writable => 'string', Notes => 'for whom the document was prepared'},
    Keywords    => { Priority => 0, Writable => 'string' },
    ModDate => {
        Name => 'ModifyDate',
        Priority => 0,
        Groups => { 2 => 'Time' },
        Writable => 'string',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    Pages       => { Priority => 0 },
    Routing     => { Priority => 0, Writable => 'string' }, #2
    Subject     => { Priority => 0, Writable => 'string' },
    Title       => { Priority => 0, Writable => 'string' },
    Version     => { Priority => 0, Writable => 'string' }, #2
    # these subdirectories for documentation only
    BeginPhotoshop => {
        Name => 'PhotoshopData',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Photoshop::Main',
        },
    },
    BeginICCProfile => {
        Name => 'ICC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    begin_xml_packet => {
        Name => 'XMP',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
    TIFFPreview => {
        Groups => { 2 => 'Preview' },
        Binary => 1,
        Notes => q{
            not a real tag ID, but used to represent the TIFF preview extracted from DOS
            EPS images
        },
    },
    BeginDocument => {
        Name => 'EmbeddedFile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::PostScript::Main',
        },
        Notes => 'extracted with L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded> option',
    },
    EmbeddedFileName => {
        Notes => q{
            not a real tag ID, but the file name from a BeginDocument statement.
            Extracted with document metadata when L<ExtractEmbedded|../ExifTool.html#ExtractEmbedded> option is used
        },
    },
    # AI metadata (most with a single leading '%')
    AI9_ColorModel => {
        Name => 'AIColorModel',
        PrintConv => {
            1 => 'RGB',
            2 => 'CMYK',
        },
    },
    AI3_ColorUsage       => { Name => 'AIColorUsage' },
    AI5_RulerUnits       => {
        Name => 'AIRulerUnits',
        PrintConv => {
            0 => 'Inches',
            1 => 'Millimeters',
            2 => 'Points',
            3 => 'Picas',
            4 => 'Centimeters',
            6 => 'Pixels',
        },
    },
    AI5_TargetResolution => { Name => 'AITargetResolution' },
    AI5_NumLayers        => { Name => 'AINumLayers' },
    AI5_FileFormat       => { Name => 'AIFileFormat' },
    AI8_CreatorVersion   => { Name => 'AICreatorVersion' }, # (double leading '%')
    AI12_BuildNumber     => { Name => 'AIBuildNumber' },
);

# composite tags
%Image::ExifTool::PostScript::Composite = (
    GROUPS => { 2 => 'Image' },
    # BoundingBox is in points, not pixels,
    # but use it anyway if ImageData is not available
    ImageWidth => {
        Desire => {
            0 => 'Main:PostScript:ImageData',
            1 => 'PostScript:BoundingBox',
        },
        ValueConv => 'Image::ExifTool::PostScript::ImageSize(\@val, 0)',
    },
    ImageHeight => {
        Desire => {
            0 => 'Main:PostScript:ImageData',
            1 => 'PostScript:BoundingBox',
        },
        ValueConv => 'Image::ExifTool::PostScript::ImageSize(\@val, 1)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::PostScript');

#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Is this a PC system
# Returns: true for PC systems
my %isPC = (MSWin32 => 1, os2 => 1, dos => 1, NetWare => 1, symbian => 1, cygwin => 1);
sub IsPC()
{
    return $isPC{$^O};
}

#------------------------------------------------------------------------------
# Get image width or height
# Inputs: 0) value list ref (ImageData, BoundingBox), 1) true to get height
sub ImageSize($$)
{
    my ($vals, $getHeight) = @_;
    my ($w, $h);
    if ($$vals[0] and $$vals[0] =~ /^(\d+) (\d+)/) {
        ($w, $h) = ($1, $2);
    } elsif ($$vals[1] and $$vals[1] =~ /^(\d+) (\d+) (\d+) (\d+)/) {
        ($w, $h) = ($3 - $1, $4 - $2);
    }
    return $getHeight ? $h : $w;
}

#------------------------------------------------------------------------------
# Set PostScript format error warning
# Inputs: 0) ExifTool object reference, 1) error string
# Returns: 1
sub PSErr($$)
{
    my ($et, $str) = @_;
    # set file type if not done already
    my $ext = $$et{FILE_EXT};
    $et->SetFileType(($ext and $ext eq 'AI') ? 'AI' : 'PS');
    $et->Warn("PostScript format error ($str)");
    return 1;
}

#------------------------------------------------------------------------------
# Return input record separator to use for the specified file
# Inputs: 0) RAF reference
# Returns: Input record separator or undef on error
sub GetInputRecordSeparator($)
{
    my $raf = shift;
    my $pos = $raf->Tell(); # save current position
    my ($data, $sep);
    $raf->Read($data,256) or return undef;
    my ($a, $d) = (999,999);
    $a = pos($data), pos($data) = 0 if $data =~ /\x0a/g;
    $d = pos($data) if $data =~ /\x0d/g;
    my $diff = $a - $d;
    if ($diff == 1) {
        $sep = "\x0d\x0a";
    } elsif ($diff == -1) {
        $sep = "\x0a\x0d";
    } elsif ($diff > 0) {
        $sep = "\x0d";
    } elsif ($diff < 0) {
        $sep = "\x0a";
    } # else error
    $raf->Seek($pos, 0);    # restore original position
    return $sep;
}

#------------------------------------------------------------------------------
# Split into lines ending in any CR, LF or CR+LF combination
# (this is annoying, and could be avoided if EPS files didn't mix linefeeds!)
# Inputs: 0) data pointer, 1) reference to lines array
# Notes: Fills @$lines with lines from splitting $$dataPt
sub SplitLine($$)
{
    my ($dataPt, $lines) = @_;
    for (;;) {
        my $endl;
        # find the position of the first LF (\x0a)
        $endl = pos($$dataPt), pos($$dataPt) = 0 if $$dataPt =~ /\x0a/g;
        if ($$dataPt =~ /\x0d/g) { # find the first CR (\x0d)
            if (defined $endl) {
                # (remember, CR+LF is a DOS newline...)
                $endl = pos($$dataPt) if pos($$dataPt) < $endl - 1;
            } else {
                $endl = pos($$dataPt);
            }
        } elsif (not defined $endl) {
            push @$lines, $$dataPt;
            last;
        }
        if (length $$dataPt == $endl) {
            push @$lines, $$dataPt;
            last;
        } else {
            # continue to split into separate lines
            push @$lines, substr($$dataPt, 0, $endl);
            $$dataPt = substr($$dataPt, $endl);
        }
    }
}

#------------------------------------------------------------------------------
# check to be sure we haven't read past end of PS data in DOS-style file
# Inputs: 0) RAF ref (with PSEnd member), 1) data ref
# - modifies data and sets RAF to EOF if end of PS is reached
sub CheckPSEnd($$)
{
    my ($raf, $dataPt) = @_;
    my $pos = $raf->Tell();
    if ($pos >= $$raf{PSEnd}) {
        $raf->Seek(0, 2);   # seek to end of file so we can't read any more
        $$dataPt = substr($$dataPt, 0, length($$dataPt) - $pos + $$raf{PSEnd}) if $pos > $$raf{PSEnd};
    }
}

#------------------------------------------------------------------------------
# Read next line from EPS file
# Inputs: 0) RAF ref (with PSEnd member if Postscript ends before end of file)
#         1) array of lines from file
# Returns: true on success
sub GetNextLine($$)
{
    my ($raf, $lines) = @_;
    my ($data, $changedNL);
    my $altnl = ($/ eq "\x0d") ? "\x0a" : "\x0d";
    for (;;) {
        $raf->ReadLine($data) or last;
        $$raf{PSEnd} and CheckPSEnd($raf, \$data);
        # split line if it contains other newline sequences
        if ($data =~ /$altnl/) {
            if (length($data) > 500000 and IsPC()) {
                # patch for Windows memory problem
                unless ($changedNL) {
                    $changedNL = $/;
                    $/ = $altnl;
                    $altnl = $changedNL;
                    $raf->Seek(-length($data), 1);
                    next;
                }
            } else {
                    # split into separate lines
                #    push @$lines, split /$altnl/, $data, -1;
                #    if (@$lines == 2 and $$lines[1] eq $/) {
                #        # handle case of DOS newline data inside file using Unix newlines
                #        $$lines[0] .= pop @$lines;
                #    }
                # split into separate lines if necessary
               SplitLine(\$data, $lines);
            }
        } else {
            push @$lines, $data;
        }
        $/ = $changedNL if $changedNL;
        return 1;
    }
    return 0;
}

#------------------------------------------------------------------------------
# Decode comment from PostScript file
# Inputs: 0) comment string, 1) RAF ref, 2) reference to lines array
#         3) optional data reference for extra lines read from file
# Returns: Decoded comment string (may be an array reference)
# - handles multi-line comments and escape sequences
sub DecodeComment($$$;$)
{
    my ($val, $raf, $lines, $dataPt) = @_;
    $val =~ s/\x0d*\x0a*$//;        # remove trailing CR, LF or CR/LF
    # check for continuation comments
    for (;;) {
        @$lines or GetNextLine($raf, $lines) or last;
        last unless $$lines[0] =~ /^%%\+/;  # is the next line a continuation?
        $$dataPt .= $$lines[0] if $dataPt;  # add to data if necessary
        $$lines[0] =~ s/\x0d*\x0a*$//;      # remove trailing CR, LF or CR/LF
        $val .= substr(shift(@$lines), 3);  # add to value (without leading "%%+")
    }
    my @vals;
    # handle bracketed string values
    if ($val =~ s/^\((.*)\)$/$1/) { # remove brackets if necessary
        # split into an array of strings if necessary
        my $nesting = 1;
        while ($val =~ /(\(|\))/g) {
            my $bra = $1;
            my $pos = pos($val) - 2;
            my $backslashes = 0;
            while ($pos and substr($val, $pos, 1) eq '\\') {
                --$pos;
                ++$backslashes;
            }
            next if $backslashes & 0x01;    # escaped if odd number
            if ($bra eq '(') {
                ++$nesting;
            } else {
                --$nesting;
                unless ($nesting) {
                    push @vals, substr($val, 0, pos($val)-1);
                    $val = substr($val, pos($val));
                    ++$nesting if $val =~ s/\s*\(//;
                }
            }
        }
        push @vals, $val;
        foreach $val (@vals) {
            # decode escape sequences in bracketed strings
            # (similar to code in PDF.pm, but without line continuation)
            while ($val =~ /\\(.)/sg) {
                my $n = pos($val) - 2;
                my $c = $1;
                my $r;
                if ($c =~ /[0-7]/) {
                    # get up to 2 more octal digits
                    $c .= $1 if $val =~ /\G([0-7]{1,2})/g;
                    # convert octal escape code
                    $r = chr(oct($c) & 0xff);
                } else {
                    # convert escaped characters
                    ($r = $c) =~ tr/nrtbf/\n\r\t\b\f/;
                }
                substr($val, $n, length($c)+1) = $r;
                # continue search after this character
                pos($val) = $n + length($r);
            }
        }
        $val = @vals > 1 ? \@vals : $vals[0];
    }
    return $val;
}

#------------------------------------------------------------------------------
# Unescape PostScript string
# Inputs: 0) string
# Returns: unescaped string
sub UnescapePostScript($)
{
    my $str = shift;
    # decode escape sequences in literal strings
    while ($str =~ /\\(.)/sg) {
        my $n = pos($str) - 2;
        my $c = $1;
        my $r;
        if ($c =~ /[0-7]/) {
            # get up to 2 more octal digits
            $c .= $1 if $str =~ /\G([0-7]{1,2})/g;
            # convert octal escape code
            $r = chr(oct($c) & 0xff);
        } elsif ($c eq "\x0d") {
            # the string is continued if the line ends with '\'
            # (also remove "\x0d\x0a")
            $c .= $1 if $str =~ /\G(\x0a)/g;
            $r = '';
        } elsif ($c eq "\x0a") {
            $r = '';
        } else {
            # convert escaped characters
            ($r = $c) =~ tr/nrtbf/\n\r\t\b\f/;
        }
        substr($str, $n, length($c)+1) = $r;
        # continue search after this character
        pos($str) = $n + length($r);
    }
    return $str;
}

#------------------------------------------------------------------------------
# Extract information from EPS, PS or AI file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference, 2) optional tag table ref
# Returns: 1 if this was a valid PostScript file
sub ProcessPS($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $embedded = $et->Options('ExtractEmbedded');
    my ($data, $dos, $endDoc, $fontTable, $comment);

    # allow read from data
    unless ($raf) {
        $raf = File::RandomAccess->new($$dirInfo{DataPt});
        $et->VerboseDir('PostScript');
    }
#
# determine if this is a postscript file
#
    $raf->Read($data, 4) == 4 or return 0;
    # accept either ASCII or DOS binary postscript file format
    return 0 unless $data =~ /^(%!PS|%!Ad|%!Fo|\xc5\xd0\xd3\xc6)/;
    if ($data =~ /^%!Ad/) {
        # I've seen PS files start with "%!Adobe-PS"...
        return 0 unless $raf->Read($data, 6) == 6 and $data eq "obe-PS";
    } elsif ($data =~ /^\xc5\xd0\xd3\xc6/) {
        # process DOS binary file header
        # - save DOS header then seek ahead and check PS header
        $raf->Read($dos, 26) == 26 or return 0;
        SetByteOrder('II');
        my $psStart = Get32u(\$dos, 0);
        unless ($raf->Seek($psStart, 0) and
                $raf->Read($data, 4) == 4 and $data eq '%!PS')
        {
            return PSErr($et, 'invalid header');
        }
        $$raf{PSEnd} = $psStart + Get32u(\$dos, 4); # set end of PostScript data in RAF
    } else {
        # check for PostScript font file (PFA or PFB)
        my $d2;
        $data .= $d2 if $raf->Read($d2,12);
        if ($data =~ /^%!(PS-(AdobeFont-|Bitstream )|FontType1-)/) {
            $et->SetFileType('PFA');  # PostScript ASCII font file
            $fontTable = GetTagTable('Image::ExifTool::Font::PSInfo');
            # PostScript font files may contain an unformatted comments which may
            # contain useful information, so accumulate these for the Comment tag
            $comment = 1;
        }
        $raf->Seek(-length($data), 1);
    }
#
# set the newline type based on the first newline found in the file
#
    local $/ = GetInputRecordSeparator($raf);
    $/ or return PSErr($et, 'invalid PS data');

    # set file type (PostScript or EPS)
    $raf->ReadLine($data) or $data = '';
    my $type;
    if ($data =~ /EPSF/) {
        $type = 'EPS';
    } else {
        # read next line to see if this is an Illustrator file
        my $line2;
        my $pos = $raf->Tell();
        if ($raf->ReadLine($line2) and $line2 =~ /^%%Creator: Adobe Illustrator/) {
            $type = 'AI';
        } else {
            $type = 'PS';
        }
        $raf->Seek($pos, 0);
    }
    $et->SetFileType($type);
    return 1 if $$et{OPTIONS}{FastScan} and $$et{OPTIONS}{FastScan} == 3;
#
# extract TIFF information from DOS header
#
    $tagTablePtr or $tagTablePtr = GetTagTable('Image::ExifTool::PostScript::Main');
    if ($dos) {
        my $base = Get32u(\$dos, 16);
        if ($base) {
            my $pos = $raf->Tell();
            # extract the TIFF preview
            my $len = Get32u(\$dos, 20);
            my $val = $et->ExtractBinary($base, $len, 'TIFFPreview');
            if (defined $val and $val =~ /^(MM\0\x2a|II\x2a\0|Binary)/) {
                $et->HandleTag($tagTablePtr, 'TIFFPreview', $val);
            } else {
                $et->Warn('Bad TIFF preview image');
            }
            # extract information from TIFF in DOS header
            # (set Parent to '' to avoid setting FileType tag again)
            my %dirInfo = (
                Parent => '',
                RAF => $raf,
                Base => $base,
            );
            $et->ProcessTIFF(\%dirInfo) or $et->Warn('Bad embedded TIFF');
            # position file pointer to extract PS information
            $raf->Seek($pos, 0);
        }
    }
#
# parse the postscript
#
    my ($buff, $mode, $beginToken, $endToken, $docNum, $subDocNum, $changedNL);
    my (@lines, $altnl);
    if ($/ eq "\x0d") {
        $altnl = "\x0a";
    } else {
        $/ = "\x0a";        # end on any LF (even if DOS CR+LF)
        $altnl = "\x0d";
    }
    for (;;) {
        if (@lines) {
            $data = shift @lines;
        } else {
            $raf->ReadLine($data) or last;
            # check for alternate newlines as efficiently as possible
            if ($data =~ /$altnl/) {
                if (length($data) > 500000 and IsPC()) {
                    # Windows can't split very long lines due to poor memory handling,
                    # so re-read the file with the other newline character instead
                    # (slower but uses less memory)
                    unless ($changedNL) {
                        $changedNL = 1;
                        my $t = $/;
                        $/ = $altnl;
                        $altnl = $t;
                        $raf->Seek(-length($data), 1);
                        next;
                    }
                } else {
                    # split into separate lines
                    @lines = split /$altnl/, $data, -1;
                    $data = shift @lines;
                    if (@lines == 1 and $lines[0] eq $/) {
                        # handle case of DOS newline data inside file using Unix newlines
                        $data .= $lines[0];
                        undef @lines;
                    }
                }
            }
        }
        undef $changedNL;
        if ($mode) {
            if (not $endToken) {
                $buff .= $data;
                next unless $data =~ m{<\?xpacket end=.(w|r).\?>(\n|\r|$)};
            } elsif ($data !~ /^$endToken/i) {
                if ($mode eq 'XMP') {
                    $buff .= $data;
                } elsif ($mode eq 'Document') {
                    # ignore embedded documents, but keep track of nesting level
                    $docNum .= '-1' if $data =~ /^$beginToken/;
                } else {
                    # data is ASCII-hex encoded
                    $data =~ tr/0-9A-Fa-f//dc;  # remove all but hex characters
                    $buff .= pack('H*', $data); # translate from hex
                }
                next;
            } elsif ($mode eq 'Document') {
                $docNum =~ s/-?\d+$//;  # decrement document nesting level
                # done with Document mode if we are back at the top level
                undef $mode unless $docNum;
                next;
            }
        } elsif ($endDoc and $data =~ /^$endDoc/i) {
            $docNum =~ s/-?(\d+)$//;        # decrement nesting level
            $subDocNum = $1;                # remember our last sub-document number
            $$et{DOC_NUM} = $docNum;
            undef $endDoc unless $docNum;   # done with document if top level
            next;
        } elsif ($data =~ /^(%{1,2})(Begin)(_xml_packet|Photoshop|ICCProfile|Document|Binary)/i) {
            # the beginning of a data block
            my %modeLookup = (
                _xml_packet => 'XMP',
                photoshop   => 'Photoshop',
                iccprofile  => 'ICC_Profile',
                document    => 'Document',
                binary      => undef, # (we will try to skip this)
            );
            $mode = $modeLookup{lc $3};
            unless ($mode) {
                if (not @lines and $data =~ /^%{1,2}BeginBinary:\s*(\d+)/i) {
                    $raf->Seek($1, 1) or last;  # skip binary data
                }
                next;
            }
            $buff = '';
            $beginToken = $1 . $2 . $3;
            $endToken = $1 . ($2 eq 'begin' ? 'end' : 'End') . $3;
            if ($mode eq 'Document') {
                # this is either the 1st sub-document or Nth document
                if ($docNum) {
                    # increase nesting level
                    $docNum .= '-' . (++$subDocNum);
                } else {
                    # this is the Nth document
                    $docNum = $$et{DOC_COUNT} + 1;
                }
                $subDocNum = 0; # new level, so reset subDocNum
                next unless $embedded;  # skip over this document
                # set document number for family 4-7 group names
                $$et{DOC_NUM} = $docNum;
                $$et{LIST_TAGS} = { };  # don't build lists across different documents
                $$et{PROCESSED} = { }; # re-initialize processed directory lookup too
                $endDoc = $endToken;          # parse to EndDocument token
                # reset mode to allow parsing into sub-directories
                undef $endToken;
                undef $mode;
                # save document name if available
                if ($data =~ /^$beginToken:\s+([^\n\r]+)/i) {
                    my $docName = $1;
                    # remove brackets if necessary
                    $docName = $1 if $docName =~ /^\((.*)\)$/;
                    $et->HandleTag($tagTablePtr, 'EmbeddedFileName', $docName);
                }
            }
            next;
        } elsif ($data =~ /^<\?xpacket begin=.{7,13}W5M0MpCehiHzreSzNTczkc9d/) {
            # pick up any stray XMP data
            $mode = 'XMP';
            $buff = $data;
            undef $endToken;    # no end token (just look for xpacket end)
            # XMP could be contained in a single line (if newlines are different)
            next unless $data =~ m{<\?xpacket end=.(w|r).\?>(\n|\r|$)};
        } elsif ($data =~ /^%%?(\w+): ?(.*)/s and $$tagTablePtr{$1}) {
            my ($tag, $val) = ($1, $2);
            # only allow 'ImageData' and AI tags to have single leading '%'
            next unless $data =~ /^%(%|AI\d+_)/ or $tag eq 'ImageData';
            # decode comment string (reading continuation lines if necessary)
            $val = DecodeComment($val, $raf, \@lines);
            $et->HandleTag($tagTablePtr, $tag, $val);
            next;
        } elsif ($embedded and $data =~ /^%AI12_CompressedData/) {
            # the rest of the file is compressed
            unless (eval { require Compress::Zlib }) {
                $et->Warn('Install Compress::Zlib to extract compressed embedded data');
                last;
            }
            # seek back to find the start of the compressed data in the file
            my $tlen = length($data) + @lines;
            $tlen += length $_ foreach @lines;
            my $backTo = $raf->Tell() - $tlen - 64;
            $backTo = 0 if $backTo < 0;
            last unless $raf->Seek($backTo, 0) and $raf->Read($data, 2048);
            last unless $data =~ s/.*?%AI12_CompressedData//;
            my $inflate = Compress::Zlib::inflateInit();
            $inflate or $et->Warn('Error initializing inflate'), last;
            # generate a PS-like file in memory from the compressed data
            my $verbose = $et->Options('Verbose');
            if ($verbose > 1) {
                $et->VerboseDir('AI12_CompressedData (first 4kB)');
                $et->VerboseDump(\$data);
            }
            # remove header if it exists (Windows AI files only)
            $data =~ s/^.{0,256}EndData[\x0d\x0a]+//s;
            my $val;
            for (;;) {
                my ($v2, $stat) = $inflate->inflate($data);
                $stat == Compress::Zlib::Z_STREAM_END() and $val .= $v2, last;
                $stat != Compress::Zlib::Z_OK() and undef($val), last;
                if (defined $val) {
                    $val .= $v2;
                } elsif ($v2 =~ /^%!PS/) {
                    $val = $v2;
                } else {
                    # add postscript header (for file recognition) if it doesn't exist
                    $val = "%!PS-Adobe-3.0$/" . $v2;
                }
                $raf->Read($data, 65536) or last;
            }
            defined $val or $et->Warn('Error inflating AI compressed data'), last;
            if ($verbose > 1) {
                $et->VerboseDir('Uncompressed AI12 Data');
                $et->VerboseDump(\$val);
            }
            # extract information from embedded images in the uncompressed data
            $val =  # add PS header in case it needs one
            ProcessPS($et, { DataPt => \$val });
            last;
        } elsif ($fontTable) {
            if (defined $comment) {
                # extract initial comments from PostScript Font files
                if ($data =~ /^%\s+(.*?)[\x0d\x0a]/) {
                    $comment .= "\n" if $comment;
                    $comment .= $1;
                    next;
                } elsif ($data !~ /^%/) {
                    # stop extracting comments at the first non-comment line
                    $et->FoundTag('Comment', $comment) if length $comment;
                    undef $comment;
                }
            }
            if ($data =~ m{^\s*/(\w+)\s*(.*)} and $$fontTable{$1}) {
                my ($tag, $val) = ($1, $2);
                if ($val =~ /^\((.*)\)/) {
                    $val = UnescapePostScript($1);
                } elsif ($val =~ m{/?(\S+)}) {
                    $val = $1;
                }
                $et->HandleTag($fontTable, $tag, $val);
            } elsif ($data =~ /^currentdict end/) {
                # only extract tags from initial FontInfo dict
                undef $fontTable;
            }
            next;
        } else {
            next;
        }
        # extract information from buffered data
        my %dirInfo = (
            DataPt => \$buff,
            DataLen => length $buff,
            DirStart => 0,
            DirLen => length $buff,
            Parent => 'PostScript',
        );
        my $subTablePtr = GetTagTable("Image::ExifTool::${mode}::Main");
        unless ($et->ProcessDirectory(\%dirInfo, $subTablePtr)) {
            $et->Warn("Error processing $mode information in PostScript file");
        }
        undef $buff;
        undef $mode;
    }
    $mode = 'Document' if $endDoc and not $mode;
    $mode and PSErr($et, "unterminated $mode data");
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from EPS file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 if this was a valid PostScript file
sub ProcessEPS($$)
{
    return ProcessPS($_[0],$_[1]);
}

1; # end


__END__

=head1 NAME

Image::ExifTool::PostScript - Read PostScript meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This code reads meta information from EPS (Encapsulated PostScript), PS
(PostScript) and AI (Adobe Illustrator) files.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://partners.adobe.com/public/developer/en/ps/5002.EPSF_Spec.pdf>

=item L<http://partners.adobe.com/public/developer/en/ps/5001.DSC_Spec.pdf>

=item L<http://partners.adobe.com/public/developer/en/illustrator/sdk/AI7FileFormat.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PostScript Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
