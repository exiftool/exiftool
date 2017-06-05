# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/FlashPix.t".

BEGIN {
    $| = 1; print "1..2\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::FlashPix;
$loaded = 1;
print "ok 1\n";

my $testname = 'FlashPix';
my $testnum = 1;

# test 2: Extract information from FlashPix.ppt
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    # omit FileSize since file is 9.5kB exactly and rounding errors
    # in Windows Cygwin Perl 5.8.2 round this down to 9kB in printout
    my $info = $exifTool->ImageInfo('t/images/FlashPix.ppt','-filesize');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}


# end
