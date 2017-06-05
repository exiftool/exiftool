# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/GE.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::GE;
$loaded = 1;
print "ok 1\n";

my $testname = 'GE';
my $testnum = 1;

# test 2: Extract information from GE.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Unknown => 1);
    my $info = $exifTool->ImageInfo('t/images/GE.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue(GEModel => 'test model');
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/GE.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile,{Duplicates=>1,Unknown=>1});
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}


# end
