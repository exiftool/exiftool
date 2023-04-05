# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Unknown.t".

BEGIN {
    $| = 1; print "1..3\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Unknown;
$loaded = 1;
print "ok 1\n";

my $testname = 'Unknown';
my $testnum = 1;

# test 2: Extract information from Unknown.jpg
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/Unknown.jpg', {Unknown => 1});
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = ( ['FocalLength',200] );
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}

done(); # end
