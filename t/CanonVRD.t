# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/CanonVRD.t".

BEGIN {
    $| = 1; print "1..22\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::CanonVRD;
$loaded = 1;
print "ok 1\n";

my $testname = 'CanonVRD';
my $testnum = 1;

# short list of tags to check in tests
my @checkTags = qw(FileSize Warning VRDVersion VRDOffset);
my @checkDR4 = qw(FileSize Warning GammaBlackPoint RedHSL GreenHSL SharpnessAdjOn);

# test 2: Extract information from CanonVRD.vrd
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/CanonVRD.vrd');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Test writing some information
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/ExifTool.jpg');
    $exifTool->SetNewValue('xmp:*');
    my $testfile = "t/${testname}_${testnum}_failed.vrd";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/CanonVRD.vrd', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 4-8: Write CanonVRD as a block to various images
{
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/CanonVRD.vrd', 'CanonVRD');
    $exifTool->Options(PrintConv => 0);
    my ($file, $ext);
    foreach $file (qw(Writer.jpg ExifTool.jpg CanonRaw.cr2 CanonRaw.crw CanonVRD.vrd)) {
        ++$testnum;
        if ($file eq 'CanonVRD.vrd') {
            $exifTool->SetNewValuesFromFile('t/images/ExifTool.jpg', 'CanonVRD');
        }
        ($ext = $file) =~ s/^\w+//;
        my $testfile = "t/${testname}_${testnum}_failed$ext";
        unlink $testfile;
        $exifTool->WriteInfo("t/images/$file", $testfile);
        my $info = $exifTool->ImageInfo($testfile, @checkTags);
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile;
        } else {
            print 'not ';
        }
        print "ok $testnum\n";
    }
}

# test 9: Delete VRD as a block
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue(CanonVRD => undef, Protected => 1);
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/ExifTool.jpg', $testfile);
    $exifTool->Options(PrintConv => 0);
    my $info = $exifTool->ImageInfo($testfile, @checkTags);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 10: Create a VRD file from scratch
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/ExifTool.jpg', 'CanonVRD');
    $exifTool->Options(PrintConv => 0);
    my $testfile = "t/${testname}_${testnum}_failed.vrd";
    unlink $testfile;
    $exifTool->WriteInfo(undef, $testfile);
    my $info = $exifTool->ImageInfo($testfile, @checkTags);
    if (check($exifTool, $info, $testname, $testnum, 8)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 11-12: Add XMP to a VRD file
{
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('XMP:Title', 'XMP in VRD test');
    my $srcfile;
    foreach $srcfile ('t/images/CanonVRD.vrd', undef) {
        ++$testnum;
        my $testfile = "t/${testname}_${testnum}_failed.vrd";
        unlink $testfile;
        $exifTool->WriteInfo($srcfile, $testfile);
        my $info = $exifTool->ImageInfo($testfile);
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile;
        } else {
            print 'not ';
        }
        print "ok $testnum\n";
    }
}

# test 13: Extract information from CanonVRD.dr4
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/CanonVRD.dr4');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 14: Test writing to DR4
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(PrintConv => 0);
    $exifTool->SetNewValue(CropX => 123);
    $exifTool->SetNewValue(SharpnessAdjOn => 0);
    $exifTool->SetNewValue(RedHSL => '-4.3 1.2 3.8');
    $exifTool->SetNewValue('CanonVRD:GammaBlackPoint' => '1.234');
    my $testfile = "t/${testname}_${testnum}_failed.dr4";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/CanonVRD.dr4', $testfile);
    my $info = $exifTool->ImageInfo($testfile, '-filename');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# tests 15-20: Write CanonDR4 as a block to various images
{
    my $exifTool = new Image::ExifTool;
    my $srcfile = "t/${testname}_14_failed.dr4";
    $exifTool->SetNewValuesFromFile($srcfile, 'CanonDR4');
    $exifTool->Options(PrintConv => 0);
    my ($file, $ext);
    foreach $file (qw(Writer.jpg ExifTool.jpg CanonRaw.cr2 CanonRaw.crw CanonVRD.vrd CanonVRD.dr4)) {
        ++$testnum;
        ($ext = $file) =~ s/^\w+//;
        my $testfile = "t/${testname}_${testnum}_failed$ext";
        unlink $testfile;
        $exifTool->WriteInfo("t/images/$file", $testfile);
        my $info = $exifTool->ImageInfo($testfile, @checkDR4);
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile unless $testnum == 15 or $testnum == 17;
            unlink $srcfile if $testnum == 20;
        } else {
            print 'not ';
        }
        print "ok $testnum\n";
    }
}

# test 21: Delete DR4(VRD) as a block
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $srcfile = "t/${testname}_15_failed.jpg";
    $exifTool->SetNewValue(CanonDR4 => undef, Protected => 1);
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo($srcfile, $testfile);
    $exifTool->Options(PrintConv => 0);
    my $info = $exifTool->ImageInfo($testfile, @checkDR4);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
        unlink $srcfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 22: Create a DR4 file from scratch
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(PrintConv => 0);
    my $srcfile = "t/${testname}_17_failed.cr2";
    $exifTool->SetNewValuesFromFile($srcfile, 'CanonDR4');
    my $testfile = "t/${testname}_${testnum}_failed.dr4";
    unlink $testfile;
    $exifTool->WriteInfo(undef, $testfile);
    my $info = $exifTool->ImageInfo($testfile, '-filename');
    if (check($exifTool, $info, $testname, $testnum, 14)) {
        unlink $testfile;
        unlink $srcfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# end
