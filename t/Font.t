# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Font.t".

BEGIN {
    $| = 1; print "1..7\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Font;
$loaded = 1;
print "ok 1\n";

my $testname = 'Font';
my $testnum = 1;

# tests 2-7: Extract information from test Font files
{
    my $exifTool = Image::ExifTool->new;
    my $type;
    foreach $type (qw(afm dfont pfa pfb pfm ttf)) {
        ++$testnum;
        my $info = $exifTool->ImageInfo("t/images/Font.$type");
        notOK() unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}

done(); # end
