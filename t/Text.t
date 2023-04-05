# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Text.t".

BEGIN {
    $| = 1; print "1..7\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Text;
$loaded = 1;
print "ok 1\n";

my $testname = 'Text';
my $testnum = 1;

# tests 2-7: Test various types of text files
{
    my $exifTool = Image::ExifTool->new;
    my $i;
    for (my $i=1; $i<=6; ++$i) {
        ++$testnum;
        my $fname = 't/images/' . ($i < 6 ? "Text$i.txt" : 'Text.csv');
        my $info = $exifTool->ImageInfo($fname, '-system:all');
        notOK() unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}

done(); # end
