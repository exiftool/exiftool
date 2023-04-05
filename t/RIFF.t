# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/RIFF.t".

BEGIN {
    $| = 1; print "1..7\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::RIFF;
$loaded = 1;
print "ok 1\n";

my $testname = 'RIFF';
my $testnum = 1;

# tests 2-4: Extract information from RIFF.wav, RIFF.avi and RIFF.webp
{
    my $ext;
    foreach $ext (qw(wav avi webp)) {
        ++$testnum;
        my $exifTool = Image::ExifTool->new;
        my $info = $exifTool->ImageInfo("t/images/RIFF.$ext");
        notOK() unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}

# test 5: Edit EXIF and XMP
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValue('exif:usercomment' => 'test comment');
    $exifTool->SetNewValue('xmp:description' => 'test description');
    $testfile = "t/${testname}_${testnum}_failed.webp";
    unlink $testfile;
    writeInfo($exifTool, 't/images/RIFF.webp', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 6: Delete all metadata from a WebP file
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValue('all');
    $testfile = "t/${testname}_${testnum}_failed.webp";
    unlink $testfile;
    writeInfo($exifTool, 't/images/RIFF.webp', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 7: Add back WebP information
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValue('exif:usercomment' => 'test comment 2');
    $exifTool->SetNewValue('xmp:description' => 'test description 2');
    my $testfile2 = "t/${testname}_${testnum}_failed.webp";
    unlink $testfile2;
    writeInfo($exifTool, $testfile, $testfile2);
    my $info = $exifTool->ImageInfo($testfile2);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
        unlink $testfile2;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

done(); # end
