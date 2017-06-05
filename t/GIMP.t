# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/GIMP.t".

BEGIN {
    $| = 1; print "1..2\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::GIMP;
$loaded = 1;
print "ok 1\n";

my $testname = 'GIMP';
my $testnum = 1;

# test 2: Extract information from GIMP.xcf
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/GIMP.xcf');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# end
