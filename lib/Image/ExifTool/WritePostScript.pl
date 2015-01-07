#------------------------------------------------------------------------------
# File:         WritePostScript.pl
#
# Description:  Write PostScript meta information
#
# Revisions:    03/03/2006 - P. Harvey Created
#
# References:   (see references in PostScript.pm, plus:)
#               1) http://www.adobe.com/products/postscript/pdfs/PLRM.pdf
#               2) http://www-cdf.fnal.gov/offline/PostScript/PLRM2.pdf
#               3) http://partners.adobe.com/public/developer/en/acrobat/sdk/pdf/pdf_creation_apis_and_specs/pdfmarkReference.pdf
#               4) http://www.npes.org/standards/Tools/DCS20Spec.pdf
#
# Notes:        (see NOTES in POD doc below)
#------------------------------------------------------------------------------

package Image::ExifTool::PostScript;

use strict;

# Structure of a DSC PS/EPS document:
#
#   %!PS-Adobe-3.0     [plus " EPSF-3.0" for EPS]
#     <comments>
#   %%EndComments      [optional]
#   %%BeginXxxx
#     <stuff to ignore>
#   %%EndXxxx
#   %%BeginProlog
#     <prolog stuff>
#   %%EndProlog
#   %%BeginSetup
#     <setup stuff>
#   %%EndSetup
#   %ImageData x x x x  [written by Photoshop]
#   %BeginPhotoshop: xxxx
#     <ascii-hex IRB information>
#   %EndPhotosop
#   %%BeginICCProfile: (name) <num> <type>
#     <ICC Profile info>
#   %%EndICCProfile
#   %begin_xml_code
#     <postscript code to define and read the XMP stream object>
#   %begin_xml_packet: xxxx
#     <XMP data>
#   %end_xml_packet
#     <postscript code to add XMP stream to dictionary>
#   %end_xml_code
#   %%Page: x x         [PS only (optional?)]
#     <graphics commands>
#   %%PageTrailer
#   %%Trailer
#     <a bit more code to bracket EPS content for distiller>
#   %%EOF

# map of where information is stored in PS image
my %psMap = (
    XMP          => 'PostScript',
    Photoshop    => 'PostScript',
    IPTC         => 'Photoshop',
    EXIFInfo     => 'Photoshop',
    IFD0         => 'EXIFInfo',
    IFD1         => 'IFD0',
    ICC_Profile  => 'PostScript',
    ExifIFD      => 'IFD0',
    GPS          => 'IFD0',
    SubIFD       => 'IFD0',
    GlobParamIFD => 'IFD0',
    PrintIM      => 'IFD0',
    InteropIFD   => 'ExifIFD',
    MakerNotes   => 'ExifIFD',
);


#------------------------------------------------------------------------------
# Write XMP directory to file, with begin/end tokens if necessary
# Inputs: 0) outfile ref, 1) flags hash ref, 2-N) data to write
# Returns: true on success
sub WriteXMPDir($$@)
{
    my $outfile = shift;
    my $flags = shift;
    my $success = 1;
    Write($outfile, "%begin_xml_code$/") or $success = 0 unless $$flags{WROTE_BEGIN};
    Write($outfile, @_) or $success = 0;
    Write($outfile, "%end_xml_code$/") or $success = 0 unless $$flags{WROTE_BEGIN};
    return $success;
}

#------------------------------------------------------------------------------
# Write a directory inside a PS document
# Inputs: 0) ExifTool object ref, 1) output file reference,
#         2) Directory name, 3) data reference, 4) flags hash ref
# Returns: 0=error, 1=nothing written, 2=dir written ok
sub WritePSDirectory($$$$$)
{
    my ($et, $outfile, $dirName, $dataPt, $flags) = @_;
    my $success = 2;
    my $len = $dataPt ? length($$dataPt) : 0;
    my $create = $len ? 0 : 1;
    my %dirInfo = (
        DataPt => $dataPt,
        DataLen => $len,
        DirStart => 0,
        DirLen => $len,
        DirName => $dirName,
        Parent => 'PostScript',
    );
    # Note: $$flags{WROTE_BEGIN} may be 1 for XMP (it is always 0 for
    # other dirs, but if 1, the begin/end markers were already written)
#
# prepare necessary postscript code to support embedded XMP
#
    my ($beforeXMP, $afterXMP, $reportedLen);
    if ($dirName eq 'XMP' and $len) {
        # isolate the XMP
        pos($$dataPt) = 0;
        unless ($$dataPt =~ /(.*)(<\?xpacket begin=.{7,13}W5M0MpCehiHzreSzNTczkc9d)/sg) {
            $et->Warn('No XMP packet start');
            return WriteXMPDir($outfile, $flags, $$dataPt);
        }
        $beforeXMP = $1;
        my $xmp = $2;
        my $p1 = pos($$dataPt);
        unless ($$dataPt =~ m{<\?xpacket end=.(w|r).\?>}sg) {
            $et->Warn('No XMP packet end');
            return WriteXMPDir($outfile, $flags, $$dataPt);
        }
        my $p2 = pos($$dataPt);
        $xmp .= substr($$dataPt, $p1, $p2-$p1);
        $afterXMP = substr($$dataPt, $p2);
        # determine if we can adjust the XMP size
        if ($beforeXMP =~ /%begin_xml_packet: (\d+)/s) {
            $reportedLen = $1;
            my @matches= ($beforeXMP =~ /\b$reportedLen\b/sg);
            undef $reportedLen unless @matches == 2;
        }
        # must edit in place if we can't reliably change the XMP length
        $dirInfo{InPlace} = 1 unless $reportedLen;
        # process XMP only
        $dirInfo{DataLen} = $dirInfo{DirLen} = length $xmp;
        $dirInfo{DataPt} = \$xmp;
    }
    my $tagTablePtr = Image::ExifTool::GetTagTable("Image::ExifTool::${dirName}::Main");
    my $val = $et->WriteDirectory(\%dirInfo, $tagTablePtr);
    if (defined $val) {
        $dataPt = \$val;    # use modified directory
        $len = length $val;
    } elsif ($dirName eq 'XMP') {
        return 1 unless $len;
        # just write the original XMP
        return WriteXMPDir($outfile, $flags, $$dataPt);
    }
    unless ($len) {
        return 1 if $create or $dirName ne 'XMP';   # nothing to create
        # it would be really difficult to delete the XMP,
        # so instead we write a blank XMP record
        $val = <<EMPTY_XMP;
<?xpacket begin='﻿' id='W5M0MpCehiHzreSzNTczkc9d'?>
<x:xmpmeta xmlns:x='adobe:ns:meta/' x:xmptk='Image::ExifTool $Image::ExifTool::VERSION'>
</x:xmpmeta>
EMPTY_XMP
        $val .= ((' ' x 100) . "\n") x 24 unless $et->Options('Compact');
        $val .= q{<?xpacket end='w'?>};
        $dataPt = \$val;
        $len = length $val;
    }
#
# write XMP directory
#
    if ($dirName eq 'XMP') {
        if ($create) {
            # create necessary PS/EPS code to support XMP
            $beforeXMP = <<HDR_END;
/pdfmark where {pop true} {false} ifelse
/currentdistillerparams where {pop currentdistillerparams
/CoreDistVersion get 5000 ge } {false} ifelse
and not {userdict /pdfmark /cleartomark load put} if
[/NamespacePush pdfmark
[/_objdef {exiftool_metadata_stream} /type /stream /OBJ pdfmark
[{exiftool_metadata_stream} 2 dict begin /Type /Metadata def
  /Subtype /XML def currentdict end /PUT pdfmark
/MetadataString $len string def % exact length of metadata
/TempString 100 string def
/ConsumeMetadata {
currentfile TempString readline pop pop
currentfile MetadataString readstring pop pop
} bind def
ConsumeMetadata
%begin_xml_packet: $len
HDR_END
            # note: use q() to get necessary linefeed before %end_xml_packet
            $afterXMP = q(
%end_xml_packet
[{exiftool_metadata_stream} MetadataString /PUT pdfmark
);
            if ($$flags{EPS}) {
                $afterXMP .= <<EPS_AFTER;
[/Document 1 dict begin
  /Metadata {exiftool_metadata_stream} def currentdict end /BDC pdfmark
[/NamespacePop pdfmark
EPS_AFTER
                # write this at end of file
                $$flags{TRAILER} = "[/EMC pdfmark$/";
            } else { # PS
                $afterXMP .= <<PS_AFTER;
[{Catalog} {exiftool_metadata_stream} /Metadata pdfmark
[/NamespacePop pdfmark
PS_AFTER
            }
            $beforeXMP =~ s{\n}{$/}sg;  # use proper newline characters
            $afterXMP =~ s{\n}{$/}sg;
        } else {
            # replace xmp size in PS code
            $reportedLen and $beforeXMP =~ s/\b$reportedLen\b/$len/sg;
        }
        WriteXMPDir($outfile, $flags, $beforeXMP, $$dataPt, $afterXMP) or $success = 0;
#
# Write Photoshop or ICC_Profile directory
#
    } elsif ($dirName eq 'Photoshop' or $dirName eq 'ICC_Profile') {
        my ($startToken, $endToken);
        if ($dirName eq 'Photoshop') {
            $startToken = "%BeginPhotoshop: $len";
            $endToken = '%EndPhotoshop';
        } else {
            $startToken = '%%BeginICCProfile: (Photoshop Profile) -1 Hex';
            $endToken = '%%EndICCProfile';
        }
        Write($outfile, $startToken, $/) or $success = 0;
        # write as an ASCII-hex comment
        my $i;
        my $wid = 32;
        for ($i=0; $i<$len; $i+=$wid) {
            $wid > $len-$i and $wid = $len-$i;
            my $dat = substr($$dataPt, $i, $wid);
            Write($outfile, "% ", uc(unpack('H*',$dat)), $/) or $success = 0;
        }
        Write($outfile, $endToken, $/) or $success = 0;
    } else {
        $et->Warn("Can't write PS directory $dirName");
    }
    undef $val;
    return $success;
}

#------------------------------------------------------------------------------
# Encode postscript tag/value
# Inputs: 0) tag ID, 1) value
# Returns: postscript comment
# - adds brackets, escapes special characters, and limits line length
sub EncodeTag($$)
{
    my ($tag, $val) = @_;
    unless ($val =~ /^\d+$/) {
        $val =~ s/([()\\])/\\$1/g;  # escape brackets and backslashes
        $val =~ s/\n/\\n/g;         # escape newlines
        $val =~ s/\r/\\r/g;         # escape carriage returns
        $val =~ s/\t/\\t/g;         # escape tabs
        # use octal escape codes for other control characters
        $val =~ s/([\x00-\x1f\x7f\xff])/sprintf("\\%.3o",ord($1))/ge;
        $val = "($val)";
    }
    my $line = "%%$tag: $val";
    # postscript line limit is 255 characters (but it seems that
    # the limit may be 254 characters if the DOS CR/LF is used)
    # --> split if necessary using continuation comment "%%+"
    my $n;
    for ($n=254; length($line)>$n; $n+=254+length($/)) {
        substr($line, $n, 0) = "$/%%+";
    }
    return $line . $/;
}

#------------------------------------------------------------------------------
# Write new tags information in comments section
# Inputs: 0) ExifTool object ref, 1) output file ref, 2) reference to new tag hash
# Returns: true on success
sub WriteNewTags($$$)
{
    my ($et, $outfile, $newTags) = @_;
    my $success = 1;
    my $tag;

    # get XMP hint and remove from tags hash
    my $xmpHint = $$newTags{XMP_HINT};
    delete $$newTags{XMP_HINT};

    foreach $tag (sort keys %$newTags) {
        my $tagInfo = $$newTags{$tag};
        my $nvHash = $et->GetNewValueHash($tagInfo);
        next unless $$nvHash{IsCreating};
        my $val = $et->GetNewValues($nvHash);
        $et->VerboseValue("+ PostScript:$$tagInfo{Name}", $val);
        Write($outfile, EncodeTag($tag, $val)) or $success = 0;
        ++$$et{CHANGED};
    }
    # write XMP hint if necessary
    Write($outfile, "%ADO_ContainsXMP: MainFirst$/") or $success = 0 if $xmpHint;

    %$newTags = ();     # all done with new tags
    return $success;
}

#------------------------------------------------------------------------------
# check to be sure we haven't read past end of PS data in DOS-style file
# Inputs: 0) RAF ref, 1) pointer to end of PS, 2) data
# - modifies data and sets RAF to EOF if end of PS is reached
sub CheckPSEnd($$$)
{
    my $pos = $_[0]->Tell();
    if ($pos >= $_[1]) {
        $_[0]->Seek(0, 2);   # seek to end of file so we can't read any more
        $_[2] = substr($_[2], 0, length($_[2]) - $pos + $_[1]) if $pos > $_[1];
    }
}

#------------------------------------------------------------------------------
# Split into lines ending in any CR, LF or CR+LF combination
# (this is annoying, and could be avoided if EPS files didn't mix linefeeds!)
# Inputs: 0) data pointer, 1) reference to lines array
# Notes: Updates data to contain next line and fills list with remaining lines
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
        # split into separate lines
        if (length $$dataPt == $endl) {
            push @$lines, $$dataPt;
            last;
        } else {
            push @$lines, substr($$dataPt, 0, $endl);
            $$dataPt = substr($$dataPt, $endl);
        }
    }
    $$dataPt = shift @$lines;   # set $$dataPt to first line
}

#------------------------------------------------------------------------------
# Write PS file
# Inputs: 0) ExifTool object reference, 1) source dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid PS file,
#          or -1 if a write error occurred
sub WritePS($$)
{
    my ($et, $dirInfo) = @_;
    $et or return 1;    # allow dummy access to autoload this package
    my $tagTablePtr = Image::ExifTool::GetTagTable('Image::ExifTool::PostScript::Main');
    my $raf = $$dirInfo{RAF};
    my $outfile = $$dirInfo{OutFile};
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');
    my ($data, $buff, %flags, $err, $mode, $endToken);
    my ($dos, $psStart, $psEnd, $psNewStart, $xmpHint);

    $raf->Read($data, 4) == 4 or return 0;
    return 0 unless $data =~ /^(%!PS|%!Ad|\xc5\xd0\xd3\xc6)/;

    if ($data =~ /^%!Ad/) {
        # I've seen PS files start with "%!Adobe-PS"...
        return 0 unless $raf->Read($buff, 6) == 6 and $buff eq "obe-PS";
        $data .= $buff;

    } elsif ($data =~ /^\xc5\xd0\xd3\xc6/) {
#
# process DOS binary PS files
#
        # save DOS header then seek ahead and check PS header
        $raf->Read($dos, 26) == 26 or return 0;
        $dos = $data . $dos;
        SetByteOrder('II');
        $psStart = Get32u(\$dos, 4);
        unless ($raf->Seek($psStart, 0) and
                $raf->Read($data, 4) == 4 and $data eq '%!PS')
        {
            $et->Error('Invalid PS header');
            return 1;
        }
        $psEnd = $psStart + Get32u(\$dos, 8);
        my $base = Get32u(\$dos, 20);
        Set16u(0xffff, \$dos, 28);  # ignore checksum
        if ($base) {
            my %dirInfo = (
                Parent => 'PS',
                RAF => $raf,
                Base => $base,
                NoTiffEnd => 1, # no end-of-TIFF check
            );
            $buff = $et->WriteTIFF(\%dirInfo);
            SetByteOrder('II'); # (WriteTIFF may change this)
            if ($buff) {
                $buff = substr($buff, $base);   # remove header written by WriteTIFF()
            } else {
                # error rewriting TIFF, so just copy over original data
                my $len = Get32u(\$dos, 24);
                unless ($raf->Seek($base, 0) and $raf->Read($buff, $len) == $len) {
                    $et->Error('Error reading embedded TIFF');
                    return 1;
                }
                $et->Warn('Bad embedded TIFF');
            }
            Set32u(0, \$dos, 12);                   # zero metafile pointer
            Set32u(0, \$dos, 16);                   # zero metafile length
            Set32u(length($dos), \$dos, 20);        # set TIFF pointer
            Set32u(length($buff), \$dos, 24);       # set TIFF length
        } elsif (($base = Get32u(\$dos, 12)) != 0) {
            # copy over metafile section
            my $len = Get32u(\$dos, 16);
            unless ($raf->Seek($base, 0) and $raf->Read($buff, $len) == $len) {
                $et->Error('Error reading metafile section');
                return 1;
            }
            Set32u(length($dos), \$dos, 12);        # set metafile pointer
        } else {
            $buff = '';
        }
        $psNewStart = length($dos) + length($buff);
        Set32u($psNewStart, \$dos, 4);  # set pointer to start of PS
        Write($outfile, $dos, $buff) or $err = 1;
        $raf->Seek($psStart + 4, 0);    # seek back to where we were
    }
#
# rewrite PostScript data
#
    local $/ = GetInputRecordSeparator($raf);
    unless ($/ and $raf->ReadLine($buff)) {
        $et->Error('Invalid PostScript data');
        return 1;
    }
    $data .= $buff;
    unless ($data =~ /^%!PS-Adobe-3\.(\d+)\b/ and $1 < 2) {
        if ($et->Error("Document does not conform to DSC spec. Metadata may be unreadable by other apps", 2)) {
            return 1;
        }
    }
    my $psRev = $1; # save PS revision number (3.x)
    Write($outfile, $data) or $err = 1;
    $flags{EPS} = 1 if $data =~ /EPSF/;

    # get hash of new information keyed by tagID and directories to add/edit
    my $newTags = $et->GetNewTagInfoHash($tagTablePtr);

    # figure out which directories we need to write (PostScript takes priority)
    $et->InitWriteDirs(\%psMap, 'PostScript');
    my $addDirs = $$et{ADD_DIRS};
    my $editDirs = $$et{EDIT_DIRS};
    my %doneDir;

    # set XMP hint flag (1 for adding, 0 for deleting, undef for no change)
    $xmpHint = 1 if $$addDirs{XMP};
    $xmpHint = 0 if $$et{DEL_GROUP}{XMP};
    $$newTags{XMP_HINT} = $xmpHint if $xmpHint;  # add special tag to newTags list

    my (@lines, $changedNL);
    my $altnl = ($/ eq "\x0d") ? "\x0a" : "\x0d";

    for (;;) {
        if (@lines) {
            $data = shift @lines;
        } else {
            $raf->ReadLine($data) or last;
            $dos and CheckPSEnd($raf, $psEnd, $data);
            # split line if it contains other newline sequences
            if ($data =~ /$altnl/) {
                if (length($data) > 500000 and IsPC()) {
                    # patch for Windows memory problem
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
                    SplitLine(\$data, \@lines);
                }
            }
        }
        undef $changedNL;
        if ($endToken) {
            # look for end token
            if ($data =~ m/^$endToken\s*$/is) {
                undef $endToken;
                # found end: process this information
                if ($mode) {
                    $doneDir{$mode} and $et->Error("Multiple $mode directories", 1);
                    $doneDir{$mode} = 1;
                    WritePSDirectory($et, $outfile, $mode, \$buff, \%flags) or $err = 1;
                    # write end token if we wrote the begin token
                    Write($outfile, $data) or $err = 1 if $flags{WROTE_BEGIN};
                    undef $buff;
                } else {
                    Write($outfile, $data) or $err = 1;
                }
            } else {
                # buffer data in current begin/end block
                if (not defined $mode) {
                    # pick up XMP in unrecognized blocks for editing in place
                    if ($data =~ /^<\?xpacket begin=.{7,13}W5M0MpCehiHzreSzNTczkc9d/ and
                        $$editDirs{XMP})
                    {
                        $buff = $data;
                        $mode = 'XMP';
                    } else {
                        Write($outfile, $data) or $err = 1;
                    }
                } elsif ($mode eq 'XMP') {
                    $buff .= $data;
                } else {
                    # data is ASCII-hex encoded
                    $data =~ tr/0-9A-Fa-f//dc;  # remove all but hex characters
                    $buff .= pack('H*', $data); # translate from hex
                }
            }
            next;
        } elsif ($data =~ m{^(%{1,2})(Begin)(?!Object:)(.*?)[:\x0d\x0a]}i) {
            # comments section is over... write any new tags now
            WriteNewTags($et, $outfile, $newTags) or $err = 1 if %$newTags;
            undef $xmpHint;
            # the beginning of a data block (can only write XMP and Photoshop)
            my %modeLookup = (
                _xml_code => 'XMP',
                photoshop => 'Photoshop',
                iccprofile => 'ICC_Profile',
            );
            $verbose > 1 and print $out "$2$3\n";
            $endToken = $1 . ($2 eq 'begin' ? 'end' : 'End') . $3;
            $mode = $modeLookup{lc($3)};
            if ($mode and $$editDirs{$mode}) {
                $buff = '';     # initialize buffer for this block
                $flags{WROTE_BEGIN} = 0;
            } else {
                undef $mode;    # not editing this directory
                Write($outfile, $data) or $err = 1;
                $flags{WROTE_BEGIN} = 1;
            }
            next;
        } elsif ($data =~ /^%%(?!Page:|PlateFile:|BeginObject:)(\w+): ?(.*)/s) {
            # rewrite information from PostScript tags in comments
            my ($tag, $val) = ($1, $2);
            # handle Adobe Illustrator files specially
            # - EVENTUALLY IT WOULD BE BETTER TO FIND ANOTHER IDENTIFICATION METHOD
            #   (because Illustrator doesn't care if the Creator is changed)
            if ($tag eq 'Creator' and $val =~ /^Adobe Illustrator/) {
                # disable writing XMP to PS-format Adobe Illustrator files and
                # older Illustrator EPS files becaues it confuses Illustrator
                # (Illustrator 8 and older write PS-Adobe-3.0, newer write PS-Adobe-3.1)
                if ($$editDirs{XMP} and $psRev == 0) {
                    if ($flags{EPS}) {
                        $et->Warn("Can't write XMP to Illustrator 8 or older EPS files");
                    } else {
                        $et->Warn("Can't write XMP to PS-format AI files");
                    }
                    # pretend like we wrote it already so we won't try to add it later
                    $doneDir{XMP} = 1;
                }
                # don't allow "Creator" to be changed in Illustrator files
                # (we need it to be able to recognize these files)
                # --> find a better way to do this!
                if ($$newTags{$tag}) {
                    $et->Warn("Can't change Postscript:Creator of Illustrator files");
                    delete $$newTags{$tag};
                }
            }
            if ($$newTags{$tag}) {
                my $tagInfo = $$newTags{$tag};
                delete $$newTags{$tag}; # write it then forget it
                next unless ref $tagInfo;
                # decode comment string (reading continuation lines if necessary)
                $val = DecodeComment($val, $raf, \@lines, \$data);
                $val = join $et->Options('ListSep'), @$val if ref $val eq 'ARRAY';
                my $nvHash = $et->GetNewValueHash($tagInfo);
                if ($et->IsOverwriting($nvHash, $val)) {
                    $et->VerboseValue("- PostScript:$$tagInfo{Name}", $val);
                    $val = $et->GetNewValues($nvHash);
                    ++$$et{CHANGED};
                    next unless defined $val;   # next if tag is being deleted
                    $et->VerboseValue("+ PostScript:$$tagInfo{Name}", $val);
                    $data = EncodeTag($tag, $val);
                }
            }
        # (note: Adobe InDesign doesn't put colon after %ADO_ContainsXMP -- doh!)
        } elsif (defined $xmpHint and $data =~ m{^%ADO_ContainsXMP:? ?(.+?)[\x0d\x0a]*$}s) {
            # change the XMP hint if necessary
            if ($xmpHint) {
                $data = "%ADO_ContainsXMP: MainFirst$/" if $1 eq 'NoMain';
            } else {
                $data = "%ADO_ContainsXMP: NoMain$/";
            }
            # delete XMP hint flags
            delete $$newTags{XMP_HINT};
            undef $xmpHint;
        } else {
            # look for end of comments section
            if (%$newTags and ($data !~ /^%\S/ or
                $data =~ /^%(%EndComments|%Page:|%PlateFile:|%BeginObject:|.*BeginLayer)/))
            {
                # write new tags at end of comments section
                WriteNewTags($et, $outfile, $newTags) or $err = 1;
                undef $xmpHint;
            }
            # look for start of drawing commands (AI uses "%AI5_BeginLayer",
            # and Helios uses "%%BeginObject:")
            if ($data =~ /^%(%Page:|%PlateFile:|%BeginObject:|.*BeginLayer)/ or
                $data !~ m{^(%.*|\s*)$}s)
            {
                # we have reached the first page or drawing command, so create necessary
                # directories and copy the rest of the file, then all done
                my $dir;
                my $plateFile = ($data =~ /^%%PlateFile:/);
                # create Photoshop first, then XMP if necessary
                foreach $dir (qw{Photoshop ICC_Profile XMP}) {
                    next unless $$editDirs{$dir} and not $doneDir{$dir};
                    if ($plateFile) {
                        # PlateFile comments may contain offsets so we can't edit these files!
                        $et->Warn("Can only edit PostScript information DCS Plate files");
                        last;
                    }
                    next unless $$addDirs{$dir} or $dir eq 'XMP';
                    $flags{WROTE_BEGIN} = 0;
                    WritePSDirectory($et, $outfile, $dir, undef, \%flags) or $err = 1;
                    $doneDir{$dir} = 1;
                }
                # copy rest of file
                if ($flags{TRAILER}) {
                    # write trailer before %%EOF
                    for (;;) {
                        Write($outfile, $data) or $err = 1;
                        if (@lines) {
                            $data = shift @lines;
                        } else {
                            $raf->ReadLine($data) or undef($data), last;
                            $dos and CheckPSEnd($raf, $psEnd, $data);
                            if ($data =~ /[\x0d\x0a]%%EOF\b/g) {
                                # split data before "%%EOF"
                                # (necessary if data contains other newline sequences)
                                my $pos = pos($data) - 5;
                                push @lines, substr($data, $pos);
                                $data = substr($data, 0, $pos);
                            }
                        }
                        last if $data =~ /^%%EOF\b/;
                    }
                    Write($outfile, $flags{TRAILER}) or $err = 1;
                }
                # simply copy the rest of the file if any data is left
                if (defined $data) {
                    Write($outfile, $data) or $err = 1;
                    Write($outfile, @lines) or $err = 1 if @lines;
                    while ($raf->Read($data, 65536)) {
                        $dos and CheckPSEnd($raf, $psEnd, $data);
                        Write($outfile, $data) or $err = 1;
                    }
                }
                last;   # all done!
            }
        }
        # write new information or copy existing line
        Write($outfile, $data) or $err = 1;
    }
    if ($dos and not $err) {
        # must go back and set length of PS section in DOS header (very dumb design)
        if (ref $outfile eq 'SCALAR') {
            Set32u(length($$outfile) - $psNewStart, $outfile, 8);
        } else {
            my $pos = tell $outfile;
            unless (seek($outfile, 8, 0) and
                    print $outfile Set32u($pos - $psNewStart) and
                    seek($outfile, $pos, 0))
            {
                $et->Error("Can't write DOS-style PS files in non-seekable stream");
                $err = 1;
            }
        }
    }
    # issue warning if we couldn't write any information
    unless ($err) {
        my (@notDone, $dir);
        delete $$newTags{XMP_HINT};
        push @notDone, 'PostScript' if %$newTags;
        foreach $dir (qw{Photoshop ICC_Profile XMP}) {
            push @notDone, $dir if $$editDirs{$dir} and not $doneDir{$dir} and
                                   not $$et{DEL_GROUP}{$dir};
        }
        @notDone and $et->Warn("Couldn't write ".join('/',@notDone).' information');
    }
    $endToken and $et->Error("File missing $endToken");
    return $err ? -1 : 1;
}


1; # end

__END__

=head1 NAME

Image::ExifTool::WritePostScript.pl - Write PostScript meta information

=head1 SYNOPSIS

This file is autoloaded by Image::ExifTool::PostScript.

=head1 DESCRIPTION

This file contains routines to write meta information in PostScript
documents.  Six forms of meta information may be written:

    1) PostScript comments (Adobe DSC specification)
    2) XMP information embedded in a document-level XMP stream
    3) EXIF information embedded in a Photoshop record
    4) IPTC information embedded in a PhotoShop record
    5) ICC_Profile information embedded in an ICCProfile record
    6) TIFF information embedded in DOS-style binary header

=head1 NOTES

Currently, information is written only in the outer-level document.

Photoshop will discard meta information in a PostScript document if it has
to rasterize the image, and it will rasterize anything that doesn't contain
the Photoshop-specific 'ImageData' tag.  So don't expect Photoshop to read
any meta information added to EPS images that it didn't create.

The following two acronyms may be confusing since they are so similar and
have different meanings with respect to PostScript documents:

    DSC = Document Structuring Conventions
    DCS = Desktop Color Separation

=head1 REFERENCES

See references in L<PostScript.pm|Image::ExifTool::PostScript>, plus:

=over 4

=item L<http://www.adobe.com/products/postscript/pdfs/PLRM.pdf>

=item L<http://www-cdf.fnal.gov/offline/PostScript/PLRM2.pdf>

=item L<http://partners.adobe.com/public/developer/en/acrobat/sdk/pdf/pdf_creation_apis_and_specs/pdfmarkReference.pdf>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Tim Kordick for his help testing the EPS writer.

=head1 AUTHOR

Copyright 2003-2015, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::PostScript(3pm)|Image::ExifTool::PostScript>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
