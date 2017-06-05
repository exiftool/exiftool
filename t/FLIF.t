# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/ZIP.t".

BEGIN {
    $| = 1; print "1..6\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::FLIF;
$loaded = 1;
print "ok 1\n";

my $testname = 'FLIF';
my $testnum = 1;

my @checkTags = qw(Artist Creator XResolution ProfileCMMType XMP);

# test 2: Extract information from FLIF.flif
{
    ++$testnum;
    my $skip = '';
    if (eval { require IO::Uncompress::RawInflate }) {
        my $exifTool = new Image::ExifTool;
        my $info = $exifTool->ImageInfo('t/images/FLIF.flif');
        print 'not ' unless check($exifTool, $info, $testname, $testnum);
    } else {
        $skip = ' # skip Requires IO::Uncompress::RawInflate';
    }
    print "ok $testnum$skip\n";
}

# test 3: Edit FLIF information
{
    ++$testnum;
    my $skip = '';
    if (eval { require IO::Uncompress::RawInflate and require IO::Compress::RawDeflate }) {
        my $exifTool = new Image::ExifTool;
        $exifTool->SetNewValuesFromFile('t/images/XMP.jpg','ICC_Profile');
        $exifTool->SetNewValue('EXIF:XResolution' => 234);
        $exifTool->SetNewValue('XMP:Creator' => 'just me');
        my $testfile = "t/${testname}_${testnum}_failed.flif";
        unlink $testfile;
        $exifTool->WriteInfo('t/images/FLIF.flif', $testfile);
        my $info = $exifTool->ImageInfo($testfile, @checkTags);
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile;
        } else {
            print 'not ';
        }
    } else {
        $skip = ' # skip Requires IO::Compress::RawDeflate';
    }
    print "ok $testnum$skip\n";
}

# test 4: Delete FLIF information
my $testfile;
{
    ++$testnum;
    my $skip = '';
    if (eval { require IO::Uncompress::RawInflate and require IO::Compress::RawDeflate }) {
        my $exifTool = new Image::ExifTool;
        $exifTool->SetNewValue(ICC_Profile => undef, Protected => 1);
        $exifTool->SetNewValue(EXIF => undef, Protected => 1);
        $exifTool->SetNewValue('XMP:all' => undef);
        $testfile = "t/${testname}_${testnum}_failed.flif";
        unlink $testfile;
        $exifTool->WriteInfo('t/images/FLIF.flif', $testfile);
        my $info = $exifTool->ImageInfo($testfile);
        unless (check($exifTool, $info, $testname, $testnum)) {
            print 'not ';
            undef $testfile;
        }
    } else {
        $skip = ' # skip Requires IO::Compress::RawDeflate';
    }
    print "ok $testnum$skip\n";
}

# test 5: Add back FLIF information
{
    ++$testnum;
    my $skip = '';
    if (defined $testfile) {
        my $exifTool = new Image::ExifTool;
        $exifTool->SetNewValuesFromFile('t/images/Photoshop.psd','ICC_Profile');
        $exifTool->SetNewValue('EXIF:XResolution' => 123);
        $exifTool->SetNewValue('XMP:Creator' => 'me again');
        my $testfile2 = "t/${testname}_${testnum}_failed.flif";
        unlink $testfile2;
        $exifTool->WriteInfo($testfile, $testfile2);
        my $info = $exifTool->ImageInfo($testfile2, @checkTags);
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile;
            unlink $testfile2;
        } else {
            print 'not ';
        }
    } else {
        $skip = ' # skip Requires test 4 pass';
    }
    print "ok $testnum$skip\n";
}

# test 6: Delete all then add back in one step
{
    ++$testnum;
    my $skip = '';
    if (eval { require IO::Uncompress::RawInflate and require IO::Compress::RawDeflate }) {
        my $exifTool = new Image::ExifTool;
        $exifTool->SetNewValue(all => undef);
        $exifTool->SetNewValuesFromFile('t/images/Photoshop.psd','ICC_Profile');
        $exifTool->SetNewValue('EXIF:XResolution' => 456);
        $exifTool->SetNewValue('XMP:Creator' => 'me too');
        $testfile = "t/${testname}_${testnum}_failed.flif";
        unlink $testfile;
        $exifTool->WriteInfo('t/images/FLIF.flif', $testfile);
        my $info = $exifTool->ImageInfo($testfile, @checkTags);
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile;
        } else {
            print 'not ';
        }
    } else {
        $skip = ' # skip Requires IO::Compress::RawDeflate';
    }
    print "ok $testnum$skip\n";
}

# end
