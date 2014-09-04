# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/CanonVRD.t".

BEGIN { $| = 1; print "1..12\n"; $Image::ExifTool::noConfig = 1; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::CanonVRD;
$loaded = 1;
print "ok 1\n";

use t::TestLib;

my $testname = 'CanonVRD';
my $testnum = 1;

# short list of tags to check in tests
my @checkTags = qw(FileSize Warning VRDVersion VRDOffset);

# test 2: Extract information from CanonVRD.vrd
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/CanonVRD.vrd', {Duplicates => 1});
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

# end
