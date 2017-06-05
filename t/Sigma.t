# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Sigma.t".

BEGIN {
    $| = 1; print "1..5\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Sigma;
$loaded = 1;
print "ok 1\n";

my $testname = 'Sigma';
my $testnum = 1;

# test 2: Extract information from Sigma.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Sigma.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        ['IPTCPixelWidth' => 200],
        ['Sharpness' => 2, 'Group' => 'MakerNotes'],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}

# test 4: Test reading X3F image
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Sigma.x3f');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 5: Test writing X3F image
{
    ++$testnum;
    my @writeInfo = (
        ['Artist' => 'Phil Harvey'],
        ['XMP:Title' => 'A title'],
        ['Keywords' => ['one','two']],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/SigmaDP2.x3f');
    print "ok $testnum\n";
}


# end
