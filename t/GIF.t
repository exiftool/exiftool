# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/GIF.t".

BEGIN {
    $| = 1; print "1..5\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::GIF;
$loaded = 1;
print "ok 1\n";

my $testname = 'GIF';
my $testnum = 1;

# test 2: GIF file using data in memory
{
    ++$testnum;
    open(TESTFILE, 't/images/GIF.gif');
    binmode(TESTFILE);
    my $gifImage;
    read(TESTFILE, $gifImage, 100000);
    close(TESTFILE);
    my $info = ImageInfo(\$gifImage);
    print 'not ' unless check($info, $testname, $testnum);
    print "ok $testnum\n";
}

# tests 3-5: Test adding/editing/deleting various types of metadata for GIF images in memory
{
    ++$testnum;
    open(TESTFILE, 't/images/GIF.gif');
    binmode(TESTFILE);
    my $gifImage;
    read(TESTFILE, $gifImage, 100000);
    close(TESTFILE);
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue(Comment => 'a new comment');
    $exifTool->SetNewValue(City => 'Kingston');
    my $image1;
    $exifTool->WriteInfo(\$gifImage, \$image1);
    $info = ImageInfo(\$image1);
    print 'not ' unless check($info, $testname, $testnum);
    print "ok $testnum\n";

    ++$testnum;
    $exifTool->SetNewValue();       # clear previous new values
    $exifTool->SetNewValue('all');  # delete everything...
    # add back some XMP tags
    $exifTool->SetNewValue(Comment => 'x');
    $exifTool->SetNewValue(Subject => ['one','two','three']);
    $exifTool->SetNewValue(Country => 'Canada');
    my $image2;
    $exifTool->WriteInfo(\$image1, \$image2);
    $info = ImageInfo(\$image2);
    print 'not ' unless check($info, $testname, $testnum);
    print "ok $testnum\n";

    ++$testnum;
    $info = ImageInfo(\$gifImage, 'Comment', 'XMP', 'ICC_Profile');
    $exifTool->SetNewValue();       # clear previous new values
    $exifTool->SetNewValue(Comment => $$info{Comment});
    $exifTool->SetNewValue(XMP => $$info{XMP}, Protected => 1);
    $exifTool->SetNewValue(ICC_Profile => $$info{ICC_Profile}, Protected => 1);
    my $image3;
    $exifTool->WriteInfo(\$image2, \$image3);
    my $testfile = "t/${testname}_${testnum}_failed.gif";
    if ($image3 eq $gifImage) {
        unlink $testfile;
    } else {
        # save the bad image
        open(TESTFILE,">$testfile");
        binmode(TESTFILE);
        print TESTFILE $image3;
        close(TESTFILE);
        print 'not ';
    }
    print "ok $testnum\n";
}

# end
