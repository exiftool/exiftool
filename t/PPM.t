# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/PPM.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::PPM;
$loaded = 1;
print "ok 1\n";

my $testname = 'PPM';
my $testnum = 1;

# test 2: Extract information from PPM.bmp
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/PPM.ppm');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write new comments to PPM in memory
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValue('Comment', 'A new comment');
    my $image;
    $exifTool->WriteInfo('t/images/PPM.ppm', \$image);
    $exifTool->Options(Unknown => 1, Binary => 0, ListJoin => ', ');
    my $info = $exifTool->ImageInfo(\$image);
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

done(); # end
