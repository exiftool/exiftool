# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Nikon.t".

BEGIN {
    $| = 1; print "1..9\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Nikon;
$loaded = 1;
print "ok 1\n";

my $testname = 'Nikon';
my $testnum = 1;

# test 2: Extract information from Nikon.jpg
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/Nikon.jpg');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        [ Creator => 'Phil' ],
        [ ImageAdjustment => 'Yes, lots of it' ],
    );
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}

# test 4: Test writing all D70 image information
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValuesFromFile('t/images/NikonD70.jpg');
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 5: Extract information from a D2Hs image
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/NikonD2Hs.jpg');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 6: Test Nikon decryption
{
    ++$testnum;
    my $data = pack('N', 0x34a290d3);
    $data = Image::ExifTool::Nikon::Decrypt(\$data, undef, undef, 0x12345678, 0x00000123);
    my $expected = 0xcae17d2f;
    my $got = unpack('N', $data);
    unless ($got == $expected) {
        warn "\n  Test $testnum (decryption) returned wrong value:\n";
        warn sprintf("    Expected 0x%x but got 0x%x\n", $expected, $got);
        notOK();
    }
    print "ok $testnum\n";
}

# test 7: Test reading NEF image
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(Duplicates => 1);
    my $info = $exifTool->ImageInfo('t/images/Nikon.nef');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 8: Test writing Nikon Capture information in NEF image
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(IgnoreMinorErrors => 1);
    $exifTool->SetNewValue('PhotoEffects' => 'Off');
    $exifTool->SetNewValue('Caption-abstract' => 'A new caption');
    $exifTool->SetNewValue('VignetteControlIntensity' => '70');
    my $testfile = "t/${testname}_${testnum}_failed.nef";
    unlink $testfile;
    $exifTool->WriteInfo('t/images/Nikon.nef', $testfile);
    my $info = $exifTool->ImageInfo($testfile, qw(PhotoEffects Caption-abstract VignetteControlIntensity));
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 9: Validate Nikon LensID values (internal check)
{
    ++$testnum;
    my $lensIDs = $Image::ExifTool::Nikon::Composite{LensID}->{PrintConv};
    foreach (sort keys %$lensIDs) {
        next if /^(([0-9A-F]{2} ){7}[0-9A-F]{2}(\.\d+)?|Notes|OTHER)$/;
        warn "\n  Bad LensID '$_' in test $testnum\n";
        notOK();
        last;
    }
    print "ok $testnum\n";
}

done(); # end
