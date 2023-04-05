# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/IPTC.t".

BEGIN {
    $| = 1; print "1..8\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::IPTC;
$loaded = 1;
print "ok 1\n";

my $testname = 'IPTC';
my $testnum = 1;

# test 2: Extract information from IPTC.jpg
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/IPTC.jpg', {Duplicates => 1});
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Test GetValue() in list context
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->ExtractInfo('t/images/IPTC.jpg', {JoinLists => 0});
    my @values = $exifTool->GetValue('Keywords','ValueConv');
    my $values = join '-', @values;
    my $expected = 'ExifTool-Test-IPTC';
    unless ($values eq $expected) {
        warn "\n  Test $testnum differs with \"$values\"\n";
        notOK();
    }
    print "ok $testnum\n";
}

# test 4: Test rewriting everything with slightly different values
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(Duplicates => 1, Binary => 1, ListJoin => undef);
    my $info = $exifTool->ImageInfo('t/images/IPTC.jpg');
    my $tag;
    foreach $tag (keys %$info) {
        my $group = $exifTool->GetGroup($tag);
        my $val = $$info{$tag};
        if (ref $val eq 'ARRAY') {
            push @$val, 'v2';
        } elsif (ref $val eq 'SCALAR') {
            $val = 'v2';
        } elsif ($val =~ /^\d+(\.\d*)?$/) {
            # (add extra .001 to avoid problem with aperture of 4.85
            #  getting rounded to 4.8 or 4.9 and causing failed tests)
            $val += ($val / 10) + 1.001;
            $1 or $val = int($val);
        } else {
            $val .= '-v2';
        }
        # eat return values so warnings don't get printed
        my @x = $exifTool->SetNewValue($tag, $val, Group=>$group, Replace=>1);
    }
    # also try writing a few specific tags
    $exifTool->SetNewValue(CreatorCountry => 'Canada');
    $exifTool->SetNewValue(CodedCharacterSet => 'UTF8', Protected => 1);
    undef $info;
    my $image;
    my $ok = writeInfo($exifTool, 't/images/IPTC.jpg', \$image, undef, 1);
    # this is effectively what the RHEL 3 UTF8 LANG problem does:
    # $image = pack("U*", unpack("C*", $image));

    my $exifTool2 = Image::ExifTool->new;
    $exifTool2->Options(Duplicates => 1);
    $info = $exifTool2->ImageInfo(\$image);
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    if (check($exifTool2, $info, $testname, $testnum) and $ok) {
        unlink $testfile;
    } else {
        # save bad file
        open(TESTFILE,">$testfile");
        binmode(TESTFILE);
        print TESTFILE $image;
        close(TESTFILE);
        notOK();
    }
    print "ok $testnum\n";
}

# test 5: Test IPTC special characters
{
    ++$testnum;
    my @writeInfo = (
        # (don't put special character hex codes in string in an attempt to patch failed
        # test by dcollins on Perl 5.95 and i686-linux-thread-multi 2.6.28-11-generic)
        # ['IPTC:CopyrightNotice' => chr(0xc2) . chr(0xa9) . " 2008 Phil Harvey"],
        # - didn't fix it, so change it back again:
        # (dcollins is the only tester with this problem)
        ['IPTC:CopyrightNotice' => "\xc2\xa9 2008 Phil Harvey"],
    );
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/Writer.jpg', 1);
    print "ok $testnum\n";
}

# test 6: Write and read using different default IPTC encoding
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->Options(Charset => 'Cyrillic');
    $exifTool->SetNewValuesFromFile('t/images/MIE.mie', 'Comment-ru_RU>Caption-Abstract');
    $exifTool->Options(IPTCCharset => 'Cyrillic');
    my $ok = writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    $exifTool->Options(Charset => 'UTF8');
    my $info = $exifTool->ImageInfo($testfile, 'IPTC:*');
    if (check($exifTool, $info, $testname, $testnum) and $ok) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 7: Replace an entry in a list
{
    ++$testnum;
    my @writeInfo = (
        ['IPTC:Keywords' => 'Test', DelValue => 1],
        ['IPTC:Keywords' => 'One'],
        ['IPTC:Keywords' => 'Two'],
    );
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/IPTC.jpg', 1);
    print "ok $testnum\n";
}

# test 8: Write IPTC as a block
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->SetNewValuesFromFile('t/images/IPTC.jpg', 'IPTC');
    my $ok = writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, 'IPTC:*');
    if (check($exifTool, $info, $testname, $testnum) and $ok) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

done(); # end
