#------------------------------------------------------------------------------
# File:         TestLib.pm
#
# Description:  Utility routines for testing ExifTool modules
#
# Revisions:    Feb. 19/04 - P. Harvey Created
#               Feb. 26/04 - P. Harvey Name temporary file ".failed" and erase
#                            it if the test passes
#               Feb. 27/04 - P. Harvey Change print format and allow ExifTool
#                            object to be passed instead of tags hash ref.
#               Oct. 30/04 - P. Harvey Split testCompare() into separate sub.
#               May  18/05 - P. Harvey Tolerate round-off errors in floats.
#               Feb. 02/08 - P. Harvey Allow different timezones in time values
#               Sep. 16/08 - P. Harvey Improve timezone testing
#               Jul. 14/10 - P. Harvey Added writeInfo()
#               Jan. 06/12 - P. Harvey Patched MirBSD leap second "feature"
#------------------------------------------------------------------------------

package t::TestLib;

use strict;
require 5.002;
require Exporter;
use Image::ExifTool qw(ImageInfo);

use vars qw($VERSION @ISA @EXPORT);
$VERSION = '1.21';
@ISA = qw(Exporter);
@EXPORT = qw(check writeCheck writeInfo testCompare binaryCompare testVerbose);

my $noTimeLocal;

sub nearEnough($$);
sub nearTime($$$$);
sub formatValue($);
sub writeInfo($$;$$$);

#------------------------------------------------------------------------------
# Compare 2 binary files
# Inputs: 0) file name 1, 1) file name 2
# Returns: 1 if files are identical
sub binaryCompare($$)
{
    my ($file1, $file2) = @_;
    my $success = 1;
    open(TESTFILE1, $file1) or return 0;
    unless (open(TESTFILE2, $file2)) {
        close(TESTFILE1);
        return 0;
    }
    binmode(TESTFILE1);
    binmode(TESTFILE2);
    my ($buf1, $buf2);
    while (read(TESTFILE1, $buf1, 65536)) {
        read(TESTFILE2, $buf2, 65536) or $success = 0, last;
        $buf1 eq $buf2 or $success = 0, last;
    }
    read(TESTFILE2, $buf2, 65536) and $success = 0;
    close(TESTFILE1);
    close(TESTFILE2);
    return $success
}

#------------------------------------------------------------------------------
# Compare 2 files and return true and erase the 2nd file if they are the same
# Inputs: 0) file1, 1) file2, 2) test number, 3) flag to not erase test file
# Returns: true if files are the same
sub testCompare($$$;$)
{
    my ($stdfile, $testfile, $testnum, $keep) = @_;
    my $success = 0;
    my $linenum;
    
    my $oldSep = $/;   
    $/ = "\x0a";        # set input line separator
    if (open(FILE1, $stdfile)) {
        if (open(FILE2, $testfile)) {
            $success = 1;
            my ($line1, $line2);
            my $linenum = 0;
            for (;;) {
                $line1 = <FILE1>;
                last unless defined $line1;
                ++$linenum;
                $line2 = <FILE2>;
                if (defined $line2) {
                    next if $line1 eq $line2;
                    next if nearEnough($line1, $line2);
                }
                $success = 0;
                last;
            }
            if ($success) {
                # make sure there is nothing left in file2
                $line2 = <FILE2>;
                if ($line2) {
                    ++$linenum;
                    $success = 0;
                }
            }
            unless ($success) {
                warn "\n  Test $testnum differs beginning at line $linenum:\n";
                defined $line1 or $line1 = '(null)';
                defined $line2 or $line2 = '(null)';
                chomp($line1,$line2);
                warn qq{    Test gave: "$line2"\n};
                warn qq{    Should be: "$line1"\n};
            }
            close(FILE2);
        }
        close(FILE1);
    }
    $/ = $oldSep;       # restore input line separator
    
    # erase .failed file if test was successful
    $success and not $keep and unlink $testfile;

    return $success
}

#------------------------------------------------------------------------------
# Return true if two test lines are close enough
# Inputs: 0) line1, 1) line2
# Returns: true if lines are similar enough to pass test
sub nearEnough($$)
{
    my ($line1, $line2) = @_;

    # of course, the version number will change...
    return 1 if $line1 =~ /^(.*ExifTool.*)\b\d{1,2}\.\d{2}\b(.*)/s and
               ($line2 eq "$1$Image::ExifTool::VERSION$Image::ExifTool::RELEASE$2" or
                $line2 eq "$1$Image::ExifTool::VERSION$2");

    # allow different FileModifyDate, FileAccessDate, FileCreateDate/FileInodeChangeDate and FilePermissions
    return 1 if $line1 =~ /(File\s?(Modif.*Date|Access\s?Date|Inode\s?Change\s?Date|Permissions))/ and
               ($line2 =~ /$1/ or $line2 =~ /File\s?Creat.*Date/);

    # allow CurrentIPTCDigest to be zero if Digest::MD5 isn't installed
    return 1 if $line1 =~ /Current IPTC Digest/ and
                $line2 =~ /Current IPTC Digest: (0|#){32}/ and
                not eval 'require Digest::MD5';

    # analyze every token in the line, and allow rounding
    # or format differences in floating point numbers
    my @toks1 = split /\s+/, $line1;
    my @toks2 = split /\s+/, $line2;
    my $lenChanged = 0;
    my $i;
    for ($i=0; ; ++$i) {
        return 1 if $i >= @toks1 and $i >= @toks2;  # all tokens were OK
        my $tok1 = $toks1[$i];
        my $tok2 = $toks2[$i];
        last unless defined $tok1 and defined $tok2;
        next if $tok1 eq $tok2;
        # can't compare any more if either line was truncated (ie. ends with '[...]' or '[snip]')
        if ($tok1 =~ /\[(\.{3}|snip)\]$/ or $tok2 =~ /\[(\.{3}|snip)\]$/) {
            return 1 if $tok1=~ /^[-+]?\d+\./ or $tok2=~/^[-+]?\d+\./;  # check for float
            return $lenChanged
        }
        if ($tok1 =~ /^(\d{2}|\d{4}):\d{2}:\d{2}/ and $tok2 =~ /^(\d{2}|\d{4}):\d{2}:\d{2}/ and
            not eval { require Time::Local })
        {
            unless ($noTimeLocal) {
                warn "Ignored time difference(s) because Time::Local is not installed\n";
                $noTimeLocal = 1;
            }
            next;   # ignore times if Time::Local not available
        # account for different timezones
        } elsif ($tok1 =~ /^(\d{2}:\d{2}:\d{2})(Z|[-+]\d{2}:\d{2})$/i) {
            my $time = $1;  # remove timezone
            # timezone may be wrong if writing date/time value in a different timezone
            next if $tok2 =~ /^(\d{2}:\d{2}:\d{2})(Z|[-+]\d{2}:\d{2})$/i and $time eq $1;
            # date/time may be wrong to if converting GMT value to local time
            last unless $i and $toks1[$i-1] =~ /^\d{4}:\d{2}:\d{2}$/ and
                               $toks2[$i-1] =~ /^\d{4}:\d{2}:\d{2}$/;
            $tok1 = $toks1[$i-1] . ' ' . $tok1; # add date to give date/time value
            $tok2 = $toks2[$i-1] . ' ' . $tok2;
            last unless nearTime($tok1, $tok2, $line1, $line2);
        # date may be different if timezone shifted into next day
        } elsif ($tok1 =~ /^\d{4}:\d{2}:\d{2}$/ and $tok2 =~ /^\d{4}:\d{2}:\d{2}$/ and
                 defined $toks1[$i+1] and defined $toks2[$i+1] and
                 $toks1[$i+1] =~ /^(\d{2}:\d{2}:\d{2})(Z|[-+]\d{2}:\d{2})$/i and
                 $toks2[$i+1] =~ /^(\d{2}:\d{2}:\d{2})(Z|[-+]\d{2}:\d{2})$/i)
        {
            ++$i;
            $tok1 .= ' ' . $toks1[$i];      # add time to give date/time value
            $tok2 .= ' ' . $toks2[$i];
            last unless nearTime($tok1, $tok2, $line1, $line2);
        # handle floating point numbers filtered by ExifTool test 29
        } elsif ($tok1 =~ s/(\.#)#*(e[-+]\#+)?/$1/g or $tok2 =~ s/(\.#)#*(e[-+]\#+)?/$1/g) {
            $tok2 =~ s/(\.#)#*(e[-+]\#+)?/$1/g;
            last if $tok1 ne $tok2;
        } else {
            # check to see if both tokens are floating point numbers (with decimal points!)
            if ($tok1 =~ s/([^\d.]+)$//) {  # remove trailing units
                my $a = $1;
                last unless $tok2 =~ s/\Q$a\E$//;
            }
            if ($tok1 =~ s/^(\d+:\d+:)//) { # remove leading HH:MM:
                my $a = $1;
                last unless $tok2 =~ s/^\Q$a//;
            }
            if ($tok1 =~ s/^'//) {          # remove leading quote
                last unless $tok2 =~ s/^'//;
            }
            last unless Image::ExifTool::IsFloat($tok1) and
                        Image::ExifTool::IsFloat($tok2) and
                        $tok1 =~ /\./ and $tok2 =~ /\./;
            last if $tok1 == 0 or $tok2 == 0;
            # numbers are bad if not the same to 5 significant figures
            if (abs(($tok1-$tok2)/($tok1+$tok2)) > 1e-5) {
                # (but allow last digit to be different due to round-off errors)
                my ($int1, $int2);
                ($int1 = $tok1) =~ tr/0-9//dc;
                ($int2 = $tok2) =~ tr/0-9//dc;
                my $dlen = length($int1) - length($int2);
                if ($dlen > 0) {
                    $int2 .= '0' x $dlen;
                } elsif ($dlen < 0) {
                    $int1 .= '0' x (-$dlen);
                }
                last if abs($int1-$int2) > 1.00001;
            }
        }
        # set flag if length changed
        $lenChanged = 1 if length($tok1) ne length($tok2);
    }
    return 0;
}

#------------------------------------------------------------------------------
# Check two time strings to see if they are the same
# Inputs: 0) time1, 1) time2, 2) line1, 3) line2
# Returns: true on success
sub nearTime($$$$)
{
    my ($tok1, $tok2, $line1, $line2) = @_;
    my $t1 = Image::ExifTool::GetUnixTime($tok1, 'local') or return 0;
    my $t2 = Image::ExifTool::GetUnixTime($tok2, 'local') or return 0;
    my $td = $t2 - $t1;
    if ($td) {
        # patch for the MirBSD leap-second unconformity
        # (120 leap seconds should cover us until _well_ into the future)
        return 0 unless $^O eq 'mirbsd' and $td < 0 and $td > -120;
        warn "\n  Ignoring $td second error due to MirBSD leap-second \"feature\":\n";
        chomp($line1,$line2);
        warn qq{    Test gave: "$line2"\n};
        warn qq{    Should be: "$line1"\n};
    }
    return 1;
}

#------------------------------------------------------------------------------
# Format value for printing
# Inputs: 0) value
# Returns: string for printing
sub formatValue($)
{
    local $_;
    my $val = shift;
    my ($str, @a);
    if (ref $val eq 'SCALAR') {
        if ($$val =~ /^Binary data/) {
            $str = "($$val)";
        } else {
            $str = '(Binary data ' . length($$val) . ' bytes)';
        }
    } elsif (ref $val eq 'ARRAY') {
        foreach (@$val) {
            push @a, formatValue($_);
        }
        $str = '[' . join(',', @a) . ']';
    } elsif (ref $val eq 'HASH') {
        my $key;
        foreach $key (sort keys %$val) {
            push @a, $key . '=' . formatValue($$val{$key});
        }
        $str = '{' . join(',', @a) . '}';
    } elsif (defined $val) {
        # make sure there are no linefeeds in output
        ($str = $val) =~ tr/\x0a\x0d/;/;
        # translate unknown characters
       # $str =~ tr/\x01-\x1f\x80-\xff/\./;
        $str =~ tr/\x01-\x1f\x7f/./;
        # remove NULL chars
        $str =~ s/\x00//g;
    } else {
        $str = '';
    }
    return $str;
}

#------------------------------------------------------------------------------
# Compare extracted information against a standard output file
# Inputs: 0) [optional] ExifTool object reference
#         1) tag hash reference, 2) test name, 3) test number
#         4) test number for comparison file (if different than this test)
#         5) top group number to test (2 by default)
# Returns: 1 if check passed
sub check($$$;$$$)
{
    my $exifTool = shift if ref $_[0] ne 'HASH';
    my ($info, $testname, $testnum, $stdnum, $topGroup) = @_;
    return 0 unless $info;
    $stdnum = $testnum unless defined $stdnum;
    my $testfile = "t/${testname}_$testnum.failed";
    my $stdfile = "t/${testname}_$stdnum.out";
    open(FILE, ">$testfile") or return 0;
    
    # use one type of linefeed so this test works across platforms
    my $oldSep = $\;
    $\ = "\x0a";        # set output line separator
    
    # get a list of found tags
    my @tags;
    if ($exifTool) {
        if ($$exifTool{NO_SORT}) {
            @tags = $exifTool->GetFoundTags();
        } else {
            # sort tags by group to make it a bit prettier
            @tags = $exifTool->GetTagList($info, 'Group0');
        }
    } else {
        @tags = sort keys %$info;
    }
#
# Write information to file (with filename "TESTNAME_#.failed")
#
    foreach (@tags) {
        my $val = formatValue($$info{$_});
        # (no "\n" needed since we set the output line separator above)
        if ($exifTool) {
            my @groups = $exifTool->GetGroup($_);
            my $groups = join ', ', @groups[0..($topGroup||2)];
            my $tagID = $exifTool->GetTagID($_);
            my $desc = $exifTool->GetDescription($_);
            print FILE "[$groups] $tagID - $desc: $val";
        } else {
            print FILE "$_: $val";
        }
    }
    close(FILE);
    
    $\ = $oldSep;       # restore output line separator
#
# Compare the output file to the output from the standard test (TESTNAME_#.out)
#
    return testCompare($stdfile, $testfile, $testnum);
}

#------------------------------------------------------------------------------
# Test writing feature by writing specified information to JPEG file
# Inputs: 0) list reference to lists of SetNewValue arguments
#         1) test name, 2) test number, 3) optional source file name,
#         4) true to only check tags which were written (or list ref for tags to check)
#         5) flag set if nothing is expected to change in the output file
# Returns: 1 if check passed
sub writeCheck($$$;$$$)
{
    my ($writeInfo, $testname, $testnum, $srcfile, $onlyWritten, $same) = @_;
    $srcfile or $srcfile = "t/images/$testname.jpg";
    my ($ext) = ($srcfile =~ /\.(.+?)$/);
    my $testfile = "t/${testname}_${testnum}_failed.$ext";
    my $exifTool = new Image::ExifTool;
    my @tags;
    if (ref $onlyWritten eq 'ARRAY') {
        @tags = @$onlyWritten;
        undef $onlyWritten;
    }
    foreach (@$writeInfo) {
        $exifTool->SetNewValue(@$_);
        push @tags, $$_[0] if $onlyWritten;
    }
    unlink $testfile;
    my $ok = writeInfo($exifTool, $srcfile, $testfile, $same);
    my $info = $exifTool->ImageInfo($testfile,{Duplicates=>1,Unknown=>1},@tags);
    my $rtnVal = check($exifTool, $info, $testname, $testnum);
    return 0 unless $ok and $rtnVal;
    unlink $testfile;
    return 1;
}

#------------------------------------------------------------------------------
# Call Image::ExifTool::WriteInfo with error checking
# Inputs: 0) ExifTool ref, 1) src file, 2) dst file, 3) true if nothing should change
#         4) true to ignore warnings
# Return: true on success
sub writeInfo($$;$$$)
{
    my ($exifTool, $src, $dst, $same, $ignore) = @_;
    # erase temporary file created by WriteInfo() if no destination file is given
    # (may be left over from previous crashed tests)
    unlink "${src}_exiftool_tmp" if not defined $dst and not ref $src;
    my $result = $exifTool->WriteInfo($src, $dst);
    my $err = '';
    $err .= "  Error: WriteInfo() returned $result\n" if $result != ($same ? 2 : 1);
    my $info = $exifTool->GetInfo('Warning', 'Error');
    foreach (sort keys %$info) {
        next if $ignore and $_ eq 'Warning';
        my $tag = Image::ExifTool::GetTagName($_);
        $err .= "  $tag: $$info{$_}\n";
    }
    return 1 unless $err;
    warn "\n$err";
    return 0;
}

#------------------------------------------------------------------------------
# Test verbose output
# Inputs: 0) test name, 1) test number, 2) Input file, 3) verbose level
# Returns: true if test passed
sub testVerbose($$$$)
{
    my ($testname, $testnum, $infile, $verbose) = @_;
    my $testfile = "t/${testname}_$testnum";
    # capture verbose output by redirecting STDOUT
    return 0 unless open(TMPFILE,">$testfile.tmp");
    ImageInfo($infile, { Verbose => $verbose, TextOut => \*TMPFILE });
    close(TMPFILE);
    # re-write output file to change newlines to be same as standard test file
    # (if I was a Perl guru, maybe I would know a better way to do this)
    open(TMPFILE,"$testfile.tmp");
    open(TESTFILE,">$testfile.failed");
    my $oldSep = $\;
    $\ = "\x0a";        # set output line separator
    while (<TMPFILE>) {
        chomp;          # remove existing newline
        print TESTFILE $_;  # re-write line using \x0a for newlines
    }
    $\ = $oldSep;       # restore output line separator
    close(TESTFILE);
    unlink("$testfile.tmp");
    return testCompare("$testfile.out","$testfile.failed",$testnum);
}


1; #end
