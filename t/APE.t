# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/APE.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::APE;
$loaded = 1;
print "ok 1\n";

my $testname = 'APE';
my $testnum = 1;

# test 2: Extract information from APE test file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/APE.ape');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Extract information from MCP test file containing 3 different
#         types of meta information: ID3v1, ID3v2 and APE
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/APE.mpc');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}


# end
