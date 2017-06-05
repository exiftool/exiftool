# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Canon.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Canon;
$loaded = 1;
print "ok 1\n";

my $testname = 'Canon';
my $testnum = 1;

# test 2: Extract information from Canon1DmkIII.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Canon1DmkIII.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write CanonCustom2 information
{
    ++$testnum;
    my @writeInfo = (
        [ISOSpeedRange => 'Enable; 1600; 200'],
        [TimerLength => 'Enable; 6 sec: 5; 16 sec: 20; After release: 6'],
    );
    my @check = qw(ISOSpeedRange TimerLength OriginalDecisionData Warning);
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum,
                                   't/images/Canon1DmkIII.jpg', \@check);
    print "ok $testnum\n";
}


# end
