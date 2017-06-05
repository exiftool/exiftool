# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/MIE.t".

BEGIN {
    $| = 1; print "1..6\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::MIE;
$loaded = 1;
print "ok 1\n";

my $testname = 'MIE';
my $testnum = 1;

# test 2: Extract information from MIE.mie
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/MIE.mie', '-filename', '-directory');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write MIE information (also test Escape option when writing)
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(IgnoreMinorErrors => 1); # to copy invalid thumbnail
    $exifTool->SetNewValuesFromFile('t/images/Nikon.jpg','*:*');
    $exifTool->SetNewValue('EXIF:XResolution' => 200);
    $exifTool->SetNewValue('MIE:FNumber' => 11);
    $exifTool->SetNewValue('XMP:Creator' => 'phil');
    $exifTool->SetNewValue('IPTC:Keywords' => 'cool');
    $exifTool->Options(Escape => 'HTML');
    $exifTool->SetNewValue('MIE:PhoneNumber' => 'k&uuml;hl');
    $exifTool->Options(Escape => undef);
    my $testfile = "t/${testname}_${testnum}_failed.mie";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/MIE.mie', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 4: Create a MIE file from scratch (also test Escape option when copying)
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(IgnoreMinorErrors => 1); # to copy invalid thumbnail
    $exifTool->Options(Escape => 'HTML');
    $exifTool->SetNewValuesFromFile('t/images/MIE.mie');
    my $testfile = "t/${testname}_${testnum}_failed.mie";
    unlink $testfile;
    $exifTool->WriteInfo(undef, $testfile);
    $exifTool->Options(Escape => undef); # reset Escape option
    my $info = $exifTool->ImageInfo($testfile, '-filename', '-directory');
    if (check($exifTool, $info, $testname, $testnum, 2)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 5-6: Test reading different Charsets
foreach (qw(Latin Cyrillic)) {
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Charset => $_);
    my $info = $exifTool->ImageInfo('t/images/MIE.mie', 'comment-ru_ru');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# end
