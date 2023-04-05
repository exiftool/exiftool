# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/MWG.t".

BEGIN {
    $| = 1; print "1..7\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::MWG;
Image::ExifTool::MWG::Load();
$loaded = 1;
print "ok 1\n";

my $testname = 'MWG';
my $testnum = 1;

# test 2: Extract MWG information from test image
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(Duplicates => 0);
    my $info = $exifTool->ImageInfo('t/images/MWG.jpg', 'MWG:*');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# tests 3-4: Write some MWG tags
{
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValue('MWG:DateTimeOriginal' => '2009:10:25 15:13:44.567-04:00');
    $exifTool->SetNewValue('MWG:Creator' => 'Creator One');
    $exifTool->SetNewValue('MWG:Creator' => 'Creator Two');
    $exifTool->SetNewValue('MWG:City' => 'Some city');
    my @tags = qw(
        EXIF:DateTimeOriginal EXIF:SubSecTimeOriginal
        IPTC:DateCreated IPTC:TimeCreated XMP-photoshop:DateCreated
        EXIF:Artist IPTC:By-line XMP-dc:Creator IPTC:City
        XMP-photoshop:City XMP-iptcExt:LocationShownCity
    );
    my $src;
    foreach $src('MWG.jpg', 'Writer.jpg') {
        ++$testnum;
        my $testfile = "t/${testname}_${testnum}_failed.jpg";
        unlink $testfile;
        $exifTool->WriteInfo("t/images/$src", $testfile);
        my $info = $exifTool->GetInfo('Warning');
        if ($$info{Warning}) {
            warn "\n    Warning: $$info{Warning}\n";
            notOK();
        } else {
            $info = $exifTool->ImageInfo($testfile, @tags);
            if (check($exifTool, $info, $testname, $testnum)) {
                unlink $testfile;
            } else {
                notOK();
            }
        }
        print "ok $testnum\n";
    }
}

# test 5: Extract IPTC information from non-standard image while in strict MWG mode
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/ExifTool.jpg', 'IPTC:*', 'Warning');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 6: Copy a tag with MWG feature active
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValuesFromFile('t/images/MWG.jpg', 'Creator');
    my $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    $exifTool->WriteInfo(undef, $testfile);
    my $info = $exifTool->ImageInfo($testfile, 'Creator');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 7: Extract MWG information from ExifTool.jpg
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/ExifTool.jpg', 'MWG:*');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

done(); # end
