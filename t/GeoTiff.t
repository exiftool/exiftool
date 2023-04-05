# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/GeoTiff.t".

BEGIN {
    $| = 1; print "1..4\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::GeoTiff;
$loaded = 1;
print "ok 1\n";

my $testname = 'GeoTiff';
my $testnum = 1;

# test 2: Extract information from GeoTiff.tif
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/GeoTiff.tif');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (['ResolutionUnit','cm']);
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/GeoTiff.tif');
    print "ok $testnum\n";
}

# test 4: Copy GeoTiff information
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $testfile = "t/${testname}_${testnum}_failed.out";
    unlink $testfile;
    $exifTool->SetNewValuesFromFile('t/images/GeoTiff.tif', 'GeoTiff*');
    my $ok = writeInfo($exifTool,'t/images/ExifTool.tif',$testfile);
    my $info = $exifTool->ImageInfo($testfile, 'GeoTiff:*');
    if (check($exifTool, $info, $testname, $testnum) and $ok) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

done(); # end
