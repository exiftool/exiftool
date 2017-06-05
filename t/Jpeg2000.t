# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Jpeg2000.t".

BEGIN {
    $| = 1; print "1..4\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Jpeg2000;
$loaded = 1;
print "ok 1\n";

my $testname = 'Jpeg2000';
my $testnum = 1;

# test 2: Extract information from Jpeg2000.jp2
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Jpeg2000.jp2');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        ['IPTC:Keywords' => 'test keyword'],
        ['XMP:City' => 'a city'],
        ['EXIF:ImageDescription' => 'a description'],
        ['XML' => '<test>Yippee</test>', Protected => 1 ],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/Jpeg2000.jp2');
    print "ok $testnum\n";
}

# test 4: Extract information from Jpeg2000.j2c
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Jpeg2000.j2c');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# end
