# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/FotoStation.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::FotoStation;
$loaded = 1;
print "ok 1\n";

my $testname = 'FotoStation';
my $testnum = 1;

# test 2: Extract information from FotoStation.jpg
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/FotoStation.jpg', {Duplicates => 1});
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Test writing some information
{
    ++$testnum;
    my @writeInfo = (
        ['Rotation' => 0 ],
        ['Keywords' => 'FotoStation' ],
    );
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum, undef, 1);
    print "ok $testnum\n";
}

done(); # end
