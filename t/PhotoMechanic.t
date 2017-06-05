# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/PhotoMechanic.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::PhotoMechanic;
$loaded = 1;
print "ok 1\n";

my $testname = 'PhotoMechanic';
my $testnum = 1;

# test 2: Extract information from PhotoMechanic.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/PhotoMechanic.jpg', {Duplicates => 1});
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Test writing some information
{
    ++$testnum;
    my @writeInfo = (
        ['Rotation' => 90 ],
        ['Keywords' => 'PhotoMechanic' ],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, undef, 1);
    print "ok $testnum\n";
}

# end
