# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/VCard.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::VCard;
$loaded = 1;
print "ok 1\n";

my $testname = 'VCard';
my $testnum = 1;

# tests 2-3: Extract information from test files
{
    my $exifTool = new Image::ExifTool;
    my $ext;
    foreach $ext (qw(vcf ics)) {
        ++$testnum;
        my $info = $exifTool->ImageInfo("t/images/VCard.$ext");
        print 'not ' unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}


# end
