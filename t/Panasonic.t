# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Panasonic.t".

BEGIN {
    $| = 1; print "1..5\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Panasonic;
$loaded = 1;
print "ok 1\n";

my $testname = 'Panasonic';
my $testnum = 1;

# test 2: Extract information from Panasonic.jpg
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/Panasonic.jpg');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        ['Keywords' => 'cool'],
        ['ShootingMode' => 'Panning'],
    );
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}

# test 4: Extract information from RW2 image
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/Panasonic.rw2');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 5: Write to RW2 image
{
    ++$testnum;
    my @writeInfo = (
        ['XMP:Title' => 'new title'],
        ['IPTC:Keywords' => 'a keyword'],
        ['ModifyDate' => '2009:03:25 12:11:46'],
    );
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum, "t/images/$testname.rw2");
    print "ok $testnum\n";
}

done(); # end
