# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/AFCP.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::AFCP;
$loaded = 1;
print "ok 1\n";

my $testname = 'AFCP';
my $testnum = 1;

# test 2: Extract information from AFCP.jpg
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/AFCP.jpg', {Duplicates => 1});
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Test writing a bunch of information
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValuesFromFile('t/images/IPTC.jpg');
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/AFCP.jpg',$testfile);
    my $info = $exifTool->ImageInfo($testfile, {Group1 => 'IPTC2'});
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

done(); # end
