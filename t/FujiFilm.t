# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/FujiFilm.t".

BEGIN {
    $| = 1; print "1..6\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::FujiFilm;
$loaded = 1;
print "ok 1\n";

my $testname = 'FujiFilm';
my $testnum = 1;

# test 2: Extract information from FujiFilm.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/FujiFilm.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        ['CreateDate','2005:01:06 11:51:09'],
        ['WhiteBalance', 'day white', 'Group', 'MakerNotes'],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}

# test 4: Extract information from FujiFilm.raf
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my @tags = qw(-filename -directory -filemodifydate -fileaccessdate
                  -filecreatedate -fileinodechangedate -filepermissions);
    my $info = $exifTool->ImageInfo('t/images/FujiFilm.raf', @tags, {Duplicates=>1});
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# tests 5-6: Write writing a RAF and changing it back again in memory
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    # set IgnoreMinorErrors option to allow invalid JpgFromRaw to be written
    $exifTool->SetNewValue(UserComment => 'test comment');
    my $testfile = "t/${testname}_${testnum}_failed.raf";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/FujiFilm.raf', $testfile);
    my $info = $exifTool->ImageInfo($testfile, 'UserComment');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";

    ++$testnum;
    my $outfile;
    # pad out comment to make image the same size as the original
    $exifTool->SetNewValue(UserComment => ' ' x 248);
    $exifTool->WriteInfo($testfile, \$outfile);
    $info = $exifTool->ImageInfo(\$outfile, {Duplicates=>1});
    if (check($exifTool, $info, $testname, $testnum, 4)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}



# end
