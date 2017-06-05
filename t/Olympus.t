# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Olympus.t".

BEGIN {
    $| = 1; print "1..8\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Olympus;
$loaded = 1;
print "ok 1\n";

my $testname = 'Olympus';
my $testnum = 1;

# test 2: Extract information from Olympus.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Olympus.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        [Software => 'ExifTool', Group => 'XMP'],
        [Macro => 'On'],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}

# test 4: Extract information from OlympusE1.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/OlympusE1.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 5: Rewrite Olympus E1 image
{
    ++$testnum;
    my @writeInfo = (
        [LensSerialNumber => '012345678'],
        [CoringFilter => 0],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/OlympusE1.jpg');
    print "ok $testnum\n";
}

# test 6: Test reading Olympus type 2 maker notes
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Olympus2.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 7: Rewrite type 2 maker notes
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->SetNewValue(FocusDistance => 100);
    $exifTool->SetNewValue(Macro => 'On');
    $exifTool->WriteInfo('t/images/Olympus2.jpg', $testfile);
    if (testVerbose($testname, $testnum, $testfile, 2)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 8: Extract information from Olympus.dss
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Olympus.dss');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}


# end
