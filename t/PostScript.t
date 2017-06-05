# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/PostScript.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::PostScript;
$loaded = 1;
print "ok 1\n";

my $testname = 'PostScript';
my $testnum = 1;

# test 2: Extract information from PostScript.eps
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/PostScript.eps');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write EPS information (and test ExtractEmbedded option)
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/IPTC.jpg','*:*');
    $exifTool->SetNewValuesFromFile('t/images/XMP.jpg','*:*');
    $exifTool->SetNewValue(Title => 'new title');
    $exifTool->SetNewValue(Copyright => 'my copyright');
    $exifTool->SetNewValue(Creator => 'phil made it', Replace => 1);
    my $testfile = "t/${testname}_${testnum}_failed.eps";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/PostScript.eps', $testfile);
    my $info = $exifTool->ImageInfo($testfile, {ExtractEmbedded => 1});
    if (check($exifTool, $info, $testname, $testnum, $testnum, 3)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}


# end
