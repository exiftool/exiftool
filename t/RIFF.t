# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/RIFF.t".

BEGIN {
    $| = 1; print "1..4\n"; $Image::ExifTool::configFile = '';
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
        my $exifTool = new Image::ExifTool;
        my $info = $exifTool->ImageInfo("t/images/RIFF.$ext");
        print 'not ' unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}


# end
