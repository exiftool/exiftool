# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/PhaseOne.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::PhaseOne;
$loaded = 1;
print "ok 1\n";

my $testname = 'PhaseOne';
my $testnum = 1;

# test 2: Extract information from PhaseOne.iiq
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/PhaseOne.iiq');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        ['SerialNumber' => '1234'],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/PhaseOne.iiq');
    print "ok $testnum\n";
}


# end
