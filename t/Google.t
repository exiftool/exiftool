# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Google.t".

BEGIN {
    $| = 1; print "1..2\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Google;
$loaded = 1;
print "ok 1\n";

my $testname = 'Google';
my $testnum = 1;

# test 2: Extract information from Google.jpg
{
    ++$testnum;
    my $skip = '';
    if (eval 'require IO::Uncompress::Gunzip') {
        my $exifTool = Image::ExifTool->new;
        my $info = $exifTool->ImageInfo('t/images/Google.jpg');
        notOK() unless check($exifTool, $info, $testname, $testnum);
    } else {
        $skip = ' # skip Requires IO::Uncompress::Gunzip';
    }
    print "ok $testnum$skip\n";
}

done(); # end
