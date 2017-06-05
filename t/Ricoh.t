# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Ricoh.t".

BEGIN {
    $| = 1; print "1..4\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Ricoh;
$loaded = 1;
print "ok 1\n";

my $testname = 'Ricoh';
my $testnum = 1;

# test 2: Extract information from Ricoh.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Ricoh.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        ['Ricoh:Sharpness' => 'Soft'],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}

# test 4: Test extracting Ricoh APP5 RMETA information
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Ricoh2.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}


# end
