# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/DNG.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::DNG;
$loaded = 1;
print "ok 1\n";

my $testname = 'DNG';
my $testnum = 1;

# test 2: Extract information from DNG.dng
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/DNG.dng');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Test writing maker notes information
{
    ++$testnum;
    my @writeInfo = (
        [ OwnerName => 'Just Me' ],
        [ OriginalDecisionData => "\xff\xff\xff\xff\x03\0\0\0\0\0\0\0\0\0\0\0\x08\0\0\0Test", Protected => 1 ],
    );
    my @tags = qw(OwnerName OriginalDecisionData Warning Error);
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/DNG.dng', \@tags);
    print "ok $testnum\n";
}

done(); # end
