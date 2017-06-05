# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Pentax.t".

BEGIN {
    $| = 1; print "1..4\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Pentax;
$loaded = 1;
print "ok 1\n";

my $testname = 'Pentax';
my $testnum = 1;

# test 2: Extract information from Pentax.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Pentax.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        ['ThumbnailImage'],     # delete thumbnail image
        ['WhiteBalance' => 'Tungsten', 'Group' => 'MakerNotes'],
        ['FocalLength' => 22 ],
        ['MaxAperture' => 2.0 ],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}

# test 4: Extract information from a Pentax AVI video
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Pentax.avi');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}


# end
