# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/PLUS.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::PLUS;
$loaded = 1;
print "ok 1\n";

my $testname = 'PLUS';
my $testnum = 1;

# test 2: Extract information from PLUS.xmp
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/PLUS.xmp', 'xmp:all');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Copy PLUS information to a new file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/PLUS.xmp','all:all');
    my $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    my $ok = writeInfo($exifTool,undef,$testfile);
    my $info = $exifTool->ImageInfo($testfile, 'xmp:all');
    if (check($exifTool, $info, $testname, $testnum, 2) and $ok) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}


# end
