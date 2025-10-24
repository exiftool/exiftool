# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/LNK.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::LNK;
$loaded = 1;
print "ok 1\n";

my $testname = 'LNK';
my $testnum = 1;

# test 2: Extract information from LNK file
{
    my $exifTool = Image::ExifTool->new;
    ++$testnum;
    my $info = $exifTool->ImageInfo('t/images/LNK.lnk');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Extract information from URL file
{
    my $exifTool = Image::ExifTool->new;
    ++$testnum;
    my $info = $exifTool->ImageInfo('t/images/LNK.url', '-system:all');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

done(); # end
