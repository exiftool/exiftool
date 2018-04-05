# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/QuickTime.t".

BEGIN {
    $| = 1; print "1..6\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::QuickTime;
$loaded = 1;
print "ok 1\n";

my $testname = 'QuickTime';
my $testnum = 1;

# tests 2-3: Extract information from QuickTime.mov and QuickTime.m4a
{
    my $ext;
    foreach $ext (qw(mov m4a)) {
        ++$testnum;
        my $exifTool = new Image::ExifTool;
        my $info = $exifTool->ImageInfo("t/images/QuickTime.$ext");
        print 'not ' unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}

# tests 4-5: Try writing XMP to the different file formats
{
    my $ext;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(SavePath => 1); # to save group 5 names
    $exifTool->SetNewValue('XMP:Title' => 'x');
    $exifTool->SetNewValue('TrackCreateDate' => '2000:01:02 03:04:05');
    $exifTool->SetNewValue('Track1:TrackModifyDate' => '2013:11:04 10:32:15');
    foreach $ext (qw(mov m4a)) {
        ++$testnum;
        unless (eval { require Time::Local }) {
            print "ok $testnum # skip Requires Time::Local\n";
            next;
        }
        my $testfile = "t/${testname}_${testnum}_failed.$ext";
        unlink $testfile;
        my $rtnVal = $exifTool->WriteInfo("t/images/QuickTime.$ext", $testfile);
        my $info = $exifTool->ImageInfo($testfile, 'title', 'time:all');
        if (check($exifTool, $info, $testname, $testnum, undef, 5)) {
            unlink $testfile;
        } else {
            print 'not ';
        }
        print "ok $testnum\n";
    }
}

# test 6: Write video rotation
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('Rotation' => '270');
    my $testfile = "t/${testname}_${testnum}_failed.mov";
    unlink $testfile;
    my $rtnVal = $exifTool->WriteInfo('t/images/QuickTime.mov', $testfile);
    my $info = $exifTool->ImageInfo($testfile, 'Rotation', 'MatrixStructure');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}


# end
