# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/GPS.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::GPS;
$loaded = 1;
print "ok 1\n";

my $testname = 'GPS';
my $testnum = 1;

# test 2: Extract information from GPS.jpg with specified coordinate format
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(CoordFormat => '%d degrees %.2f minutes');
    my $info = $exifTool->ImageInfo('t/images/GPS.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    if (eval { require Time::Local }) {
        my @writeInfo = (
            ['GPSLatitude' => "12 deg 21' 23.345"],
            ['GPSLatitudeRef' => 'south' ],
            ['GPSTimeStamp' => '2007:03:02 18:46:10.55-05:30' ],
            ['GPSDateStamp' => '2007:03:02 18:46:10.55-05:30' ],
        );
        print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum);
        print "ok $testnum\n";
    } else {
        print "ok $testnum # skip Requires Time::Local\n";
    }
}


# end
