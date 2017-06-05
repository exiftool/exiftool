# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Kodak.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Kodak;
$loaded = 1;
print "ok 1\n";

my $testname = 'Kodak';
my $testnum = 1;

# test 2: Extract information from Kodak.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Kodak.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        [YearCreated => '2005', Group => 'Kodak'],
        [MonthDayCreated => '03:31', Group => 'Kodak'],
        [DigitalZoom => '2'],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}


# end
