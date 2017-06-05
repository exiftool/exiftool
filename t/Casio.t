# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Casio.t".

BEGIN {
    $| = 1; print "1..6\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Casio;
$loaded = 1;
print "ok 1\n";

my $testname = 'Casio';
my $testnum = 1;

# test 2-4: Extract information from Casio images
{
    my $file;
    my $exifTool = new Image::ExifTool;
    foreach $file ('Casio.jpg', 'Casio2.jpg', 'CasioQVCI.jpg') {
        ++$testnum;
        my $info = $exifTool->ImageInfo("t/images/$file");
        print 'not ' unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}

# test 5: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        [MaxApertureValue => 4],
        [FocusMode => 'Macro'],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}

# test 6: Write some new information in type 2 file
{
    ++$testnum;
    my @writeInfo = (
        ['XResolution',300],
        ['YResolution',300],
        ['ObjectDistance','3.5'],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/Casio2.jpg');
    print "ok $testnum\n";
}


# end
