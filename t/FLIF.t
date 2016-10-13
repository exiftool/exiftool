# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/ZIP.t".

BEGIN { $| = 1; print "1..2\n"; $Image::ExifTool::noConfig = 1; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::FLIF;
$loaded = 1;
print "ok 1\n";

use t::TestLib;

my $testname = 'FLIF';
my $testnum = 1;

# test 2: Extract information from FLIF.flif
{
    my $exifTool = new Image::ExifTool;
    ++$testnum;
    my $skip = '';
    if (eval { require IO::Uncompress::RawInflate }) {
        my $info = $exifTool->ImageInfo('t/images/FLIF.flif');
        print 'not ' unless check($exifTool, $info, $testname, $testnum);
    } else {
        $skip = ' # skip Requires IO::Uncompress::RawInflate';
    }
    print "ok $testnum$skip\n";
}

# end
