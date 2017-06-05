# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/MOI.t".

BEGIN {
    $| = 1; print "1..2\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::MOI;
$loaded = 1;
print "ok 1\n";

my $testname = 'MOI';
my $testnum = 1;

# test 2: Extract information from a MOI file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/MOI.moi', '-system:*');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# end
