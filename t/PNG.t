# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/PNG.t".

BEGIN {
    $| = 1; print "1..8\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::PNG;
$loaded = 1;
print "ok 1\n";

my $testname = 'PNG';
my $testnum = 1;

# test 2: Extract information from PNG.png
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/PNG.png');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write a bunch of new information to a PNG in memory
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValuesFromFile('t/images/IPTC.jpg');
    $exifTool->SetNewValuesFromFile('t/images/XMP.jpg');
    $exifTool->SetNewValue('PNG:Comment');  # and delete a tag
    $exifTool->SetNewValue('PixelsPerUnitX', 1234);
    my $image;  
    my $rtnVal = $exifTool->WriteInfo('t/images/PNG.png', \$image);
    # must ignore FileSize because size is variable (depends on Zlib availability)
    my $info = $exifTool->ImageInfo(\$image, '-filesize');
    my $testfile = "t/${testname}_${testnum}_failed.png";
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;   # erase results of any bad test
    } else {
        # save the bad image
        open(TESTFILE,">$testfile");
        binmode(TESTFILE);
        print TESTFILE $image;
        close(TESTFILE);
        notOK();
    }
    print "ok $testnum\n";
}

# test 4: Test group delete, alternate languages and special characters
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(Charset => 'Latin');
    $exifTool->SetNewValue('PNG:*');
    $exifTool->SetNewValue('XMP:*');
    $exifTool->SetNewValue('PNG:Comment-fr', "Commentaire fran\xe7aise");
    $exifTool->SetNewValue('PNG:Copyright', "\xa9 2010 Phil Harvey");
    $exifTool->SetNewValue('XMP:Description-bar' => "A Br\xfcn is a Gst\xf6");
    my $testfile = "t/${testname}_${testnum}_failed.png";
    unlink $testfile;
    my $rtnVal = $exifTool->WriteInfo('t/images/PNG.png', $testfile);
    $exifTool->Options(Charset => 'UTF8');
    my $info = $exifTool->ImageInfo($testfile, 'PNG:*', 'XMP:*');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;   # erase results of any bad test
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 5: Try moving XMP from after IDAT to before
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $image;  
    # delete all XMP then copy back again (should move to before IDAT)
    $exifTool->SetNewValue();
    my $txtfile = "t/${testname}_${testnum}.failed";
    open PNG_TEST_5, ">$txtfile" or warn "Error opening $txtfile\n";
    $exifTool->Options(Verbose => 2);
    $exifTool->Options(TextOut => \*PNG_TEST_5);
    $exifTool->SetNewValue('xmp:all');
    $exifTool->SetNewValuesFromFile('t/images/PNG.png', 'all:all<xmp:all');
    my $rtnVal = $exifTool->WriteInfo('t/images/PNG.png', \$image);
    close PNG_TEST_5;
    if (testCompare('t/PNG_5.out', $txtfile, $testnum)) {
        unlink $txtfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 6: Write EXIF
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValue('EXIF:Artist' => 'me');
    my $testfile = "t/${testname}_${testnum}_failed.png";
    unlink $testfile;
    my $rtnVal = $exifTool->WriteInfo('t/images/PNG.png', $testfile);
    $exifTool->Options(Charset => 'UTF8');
    my $info = $exifTool->ImageInfo($testfile, 'EXIF:*');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 7: Write ICC_Profile with a name
{
    ++$testnum;
    my $skip = '';
    if (eval 'require Compress::Zlib') {
        my $exifTool = Image::ExifTool->new;
        $exifTool->SetNewValuesFromFile('t/images/ICC_Profile.icc', 'ICC_Profile');
        $exifTool->SetNewValue('PNG:ProfileName' => 'Adobe RGB (1998)');
        my $testfile = "t/${testname}_${testnum}_failed.png";
        unlink $testfile;
        my $rtnVal = $exifTool->WriteInfo('t/images/PNG.png', $testfile);
        my $info = $exifTool->ImageInfo($testfile, 'ProfileName', 'ProfileCMMType');
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

# test 8: Read EXIF when an independent C2PA JUMBF chunk uses the same offsets
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValue('EXIF:UserComment' => 'Test: test123');
    my $image;
    my $rtnVal = $exifTool->WriteInfo('t/images/PNG.png', \$image);
    my $success = $rtnVal;

    my $jumdData = "c2pa\0\x11\0\x10\x80\0\0\xaa\0\x38\x9b\x71" .
                   pack('C', 3) . "c2pa\0";
    my $jumd = pack('Na4', length($jumdData) + 8, 'jumd') . $jumdData;
    my $jumb = pack('Na4', length($jumd) + 8, 'jumb') . $jumd;
    my $crcData = 'caBX' . $jumb;
    my $caBX = pack('Na4', length($jumb), 'caBX') . $jumb .
               pack('N', Image::ExifTool::PNG::CalculateCRC(\$crcData));
    my ($pos, %chunkEnd) = (8);
    while ($pos + 12 <= length $image) {
        my ($len, $id) = unpack('Na4', substr($image, $pos, 8));
        $pos += $len + 12;
        $chunkEnd{$id} = $pos;
    }
    foreach $pos ($chunkEnd{IHDR}, $chunkEnd{eXIf}) {
        my $testImage = substr($image, 0, $pos) . $caBX . substr($image, $pos);
        my $info = $exifTool->ImageInfo(\$testImage, 'UserComment', 'Warning');
        $success = 0 if $$info{UserComment} ne 'Test: test123' or $$info{Warning};
    }
    notOK() unless $success;
    print "ok $testnum\n";
}

done(); # end
