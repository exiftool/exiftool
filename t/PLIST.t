# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/PLIST.t".

BEGIN {
    $| = 1; print "1..4\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::PLIST;
$loaded = 1;
print "ok 1\n";

my $testname = 'PLIST';
my $testnum = 1;

# tests 2-4: Extract information from PLIST files
{
    my $file;
    my $exifTool = Image::ExifTool->new;
    foreach $file ('PLIST-xml.plist', 'PLIST-bin.plist', 'PLIST.aae') {
        ++$testnum;
        my $info = $exifTool->ImageInfo("t/images/$file");
        notOK() unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}

done(); # end
