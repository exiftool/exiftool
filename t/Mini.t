# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Mini.t".

BEGIN {
    $| = 1; print "1..4\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Mini;
$loaded = 1;
print "ok 1\n";

my $testname = 'Mini';
my $testnum = 1;

# test 2: Extract information from Mini.avif
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/Mini.avif');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write EXIF and delete XMP
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValue('EXIF:Artist' => 'you know who');
    $exifTool->SetNewValue('XMP:all' => undef);
    my $testfile = "t/${testname}_${testnum}_failed.avif";
    unlink $testfile;
    my $rtnVal = $exifTool->WriteInfo('t/images/Mini.avif', $testfile);
    my $info = $exifTool->ImageInfo($testfile, 'EXIF:*', 'XMP:*', 'FileSize');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 4: Compress EXIF and XMP
{
    ++$testnum;
    my $skip = '';
    if (eval 'require Compress::Zlib') {
        my $exifTool = Image::ExifTool->new;
        $exifTool->Options(Compress => 1);
        $exifTool->Options(Compact => 'all');
        $exifTool->SetNewValue(ForceWrite => 'xmp');
        my $testfile = "t/${testname}_${testnum}_failed.avif";
        unlink $testfile;
        my $rtnVal = $exifTool->WriteInfo('t/images/Mini.avif', $testfile);
        $exifTool->Options(Unknown => 1);
        my $info = $exifTool->ImageInfo($testfile, 'EXIF:*', 'XMP:*', 'Mini:*');
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile;
        } else {
            notOK();
        }
    } else {
        $skip = ' # skip Requires Compress::Zlib';
    }
    print "ok $testnum$skip\n";
}


done(); # end
