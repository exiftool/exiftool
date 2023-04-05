# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/JSON.t".

BEGIN {
    $| = 1; print "1..2\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::JSON;
$loaded = 1;
print "ok 1\n";

my $testname = 'JSON';
my $testnum = 1;

# test 2: Extract information from JSON.json
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(Struct => 2);
    $exifTool->Options(MissingTagValue => 'null');
    my $info = $exifTool->ImageInfo('t/images/JSON.json');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

done(); # end
