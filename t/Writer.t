# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Writer.t".

BEGIN {
    $| = 1; print "1..58\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

my $testname = 'Writer';
my $testnum = 1;
my $testfile;

# tests 2/3: Test writing new comment to JPEG file and removing it again
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile1 = "t/${testname}_${testnum}_failed.jpg";
    -e $testfile1 and unlink $testfile1;
    $exifTool->SetNewValue('Comment','New comment in JPG file');
    writeInfo($exifTool, 't/images/Canon.jpg', $testfile1);
    my $info = ImageInfo($testfile1);
    print 'not ' unless check($info, $testname, $testnum);
    print "ok $testnum\n";

    ++$testnum;
    my $testfile2 = "t/${testname}_${testnum}_failed.jpg";
    -e $testfile2 and unlink $testfile2;
    $exifTool->SetNewValue('Comment');
    writeInfo($exifTool, $testfile1, $testfile2);
    if (binaryCompare($testfile2, 't/images/Canon.jpg')) {
        unlink $testfile1;
        unlink $testfile2;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 4/5: Test editing a TIFF in memory then changing it back again
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Duplicates => 1, Unknown => 1);
    my $newtiff;
    $exifTool->SetNewValue(Headline => 'A different headline');
    $exifTool->SetNewValue(ImageDescription => 'Modified TIFF');
    $exifTool->SetNewValue(Keywords => 'another keyword', AddValue => 1);
    $exifTool->SetNewValue('xmp:SupplementalCategories' => 'new XMP info');
    writeInfo($exifTool, 't/images/ExifTool.tif', \$newtiff);
    my $info = $exifTool->ImageInfo(\$newtiff);
    unless (check($exifTool, $info, $testname, $testnum)) {
        $testfile = "t/${testname}_${testnum}_failed.tif";
        open(TESTFILE,">$testfile");
        binmode(TESTFILE);
        print TESTFILE $newtiff;
        close(TESTFILE);
        print 'not ';
    }
    print "ok $testnum\n";

    ++$testnum;
    my $newtiff2;
    $exifTool->SetNewValue();   # clear all the changes
    $exifTool->SetNewValue(Headline => 'headline');
    $exifTool->SetNewValue(ImageDescription => 'The picture caption');
    $exifTool->SetNewValue(Keywords => 'another keyword', DelValue => 1);
    $exifTool->SetNewValue(SupplementalCategories);
    writeInfo($exifTool, \$newtiff, \$newtiff2);
    $testfile = "t/${testname}_${testnum}_failed.tif";
    open(TESTFILE,">$testfile");
    binmode(TESTFILE);
    print TESTFILE $newtiff2;
    close(TESTFILE);
    if (binaryCompare($testfile,'t/images/ExifTool.tif')) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 6/7: Test rewriting a JPEG file then changing it back again
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Duplicates => 1, Unknown => 1);
    my $testfile1 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile1;
    $exifTool->SetNewValue(DateTimeOriginal => '2005:01:01 00:00:00', Group => 'IFD0');
    $exifTool->SetNewValue(Contrast => '+2', Group => 'XMP');
    $exifTool->SetNewValue(ExposureCompensation => 999, Group => 'EXIF');
    $exifTool->SetNewValue(LightSource => 'cloud');
    $exifTool->SetNewValue('EXIF:Flash' => '0x1', Type => 'ValueConv');
    $exifTool->SetNewValue('Orientation#' => 3);
    $exifTool->SetNewValue(FocalPlaneResolutionUnit => 'mm');
    $exifTool->SetNewValue(Category => 'IPTC test');
    $exifTool->SetNewValue(Description => 'New description');
    $exifTool->SetNewValue(TimeCodes => '02:53:49:07 2009-11-19T12:38:35:21-03:00');
    writeInfo($exifTool, 't/images/Canon.jpg', $testfile1, undef, 1);
    my $info = $exifTool->ImageInfo($testfile1);
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";

    ++$testnum;
    $exifTool->SetNewValue();
    $exifTool->SetNewValue(DateTimeOriginal => '2003:12:04 06:46:52');
    $exifTool->SetNewValue(Contrast => undef, Group => 'XMP');
    $exifTool->SetNewValue(ExposureCompensation => 0, Group => 'EXIF');
    $exifTool->SetNewValue('LightSource');
    $exifTool->SetNewValue('EXIF:Flash' => '0x0', Type => 'ValueConv');
    $exifTool->SetNewValue('Orientation#' => 1);
    $exifTool->SetNewValue(FocalPlaneResolutionUnit => 'in');
    $exifTool->SetNewValue('Category');
    $exifTool->SetNewValue('Description');
    $exifTool->SetNewValue('TimeCodes');
    my $image;
    writeInfo($exifTool, $testfile1, \$image);
    $exifTool->Options(Composite => 0);
    $info = $exifTool->ImageInfo(\$image, '-filesize');
    my $testfile2 = "t/${testname}_${testnum}_failed.jpg";
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile1;
        unlink $testfile2;
    } else {
        # save bad file
        open(TESTFILE,">$testfile2");
        binmode(TESTFILE);
        print TESTFILE $image;
        close(TESTFILE);
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 8: Test rewriting everything in a JPEG file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Duplicates => 1, Binary => 1, ListJoin => undef);
    my $info = $exifTool->ImageInfo('t/images/Canon.jpg');
    my $tag;
    foreach $tag (keys %$info) {
        my $group = $exifTool->GetGroup($tag);
        # eat return values so warnings don't get printed
        my @rtns = $exifTool->SetNewValue($tag,$info->{$tag},Group=>$group);
    }
    undef $info;
    my $image;
    writeInfo($exifTool, 't/images/Canon.jpg', \$image);
    # (must drop Composite tags because their order may change)
    $exifTool->Options(Unknown => 1, Binary => 0, ListJoin => ', ', Composite => 0);
    # (must ignore filesize because it changes as null padding is discarded)
    $info = $exifTool->ImageInfo(\$image, '-filesize');
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    if (check($exifTool, $info, $testname, $testnum, 7)) {
        unlink $testfile;
    } else {
        # save bad file
        open(TESTFILE,">$testfile");
        binmode(TESTFILE);
        print TESTFILE $image;
        close(TESTFILE);
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 9: Test copying over information with SetNewValuesFromFile()
#         (including a transfer of the ICC_Profile record)
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/Canon.jpg');
    $exifTool->SetNewValuesFromFile('t/images/ExifTool.tif', 'ICC_Profile');
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Nikon.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 10: Another SetNewValuesFromFile() test
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(IgnoreMinorErrors => 1);
    $exifTool->SetNewValuesFromFile('t/images/Pentax.jpg');
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Canon.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 11/12: Try creating something from nothing and removing it again
#              (also test ListSplit and ListJoin options)
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(ListSplit => ';\\s*');
    $exifTool->Options(ListJoin => ' <<separator>> ');
    $exifTool->SetNewValue(DateTimeOriginal => '2005:01:19 13:37:22', Group => 'EXIF');
    $exifTool->SetNewValue(FileVersion => 12, Group => 'IPTC');
    $exifTool->SetNewValue(Contributor => 'Guess who', Group => 'XMP');
    $exifTool->SetNewValue(GPSLatitude => q{44 deg 14' 12.25"}, Group => 'GPS');
    $exifTool->SetNewValue('Ducky:Quality' => 50);
    $exifTool->SetNewValue(Keywords => 'this; that');
    my $testfile1 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile1;
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile1);
    my $info = $exifTool->ImageInfo($testfile1);
    my $success = check($exifTool, $info, $testname, $testnum);
    print 'not ' unless $success;
    print "ok $testnum\n";

    ++$testnum;
    $exifTool->SetNewValue('DateTimeOriginal');
    $exifTool->SetNewValue('FileVersion');
    $exifTool->SetNewValue('Contributor');
    $exifTool->SetNewValue('GPSLatitude');
    $exifTool->SetNewValue('Ducky:Quality');
    $exifTool->SetNewValue('Keywords');
    my $testfile2 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile2;
    writeInfo($exifTool, $testfile1, $testfile2);
    if (binaryCompare('t/images/Writer.jpg', $testfile2)) {
        unlink $testfile1 if $success;
        unlink $testfile2;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 13: Copy tags from CRW file to JPG
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/CanonRaw.crw');
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 14: Delete all information in a group
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('All' => undef, Group => 'MakerNotes');
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Canon.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 15: Copy a specific set of tags
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my @copyTags = qw(exififd:all -lightSource ifd0:software);
    # also test new regular expression feature (ExifTool 9.15)
    push @copyTags, 'comment<${ make ; tr{ ,.}{_}; s{__}{_} } {cool, huh?}';
    $exifTool->SetNewValuesFromFile('t/images/Olympus.jpg', @copyTags);
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Canon.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 16-18: Test SetNewValuesFromFile() order of operations
{
    my @argsList = (
        [ 'ifd0:xresolution>xmp:*', 'ifd1:xresolution>xmp:*' ],
        [ 'ifd1:xresolution>xmp:*', 'ifd0:xresolution>xmp:*' ],
        [ '*:xresolution', '-ifd0:xresolution', 'xresolution>xmp:*' ],
    );
    my $args;
    foreach $args (@argsList) {
        ++$testnum;
        my $exifTool = new Image::ExifTool;
        $exifTool->SetNewValuesFromFile('t/images/GPS.jpg', @$args);
        $testfile = "t/${testname}_${testnum}_failed.jpg";
        unlink $testfile;
        writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
        my $info = $exifTool->ImageInfo($testfile, 'xresolution');
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile;
        } else {
            print 'not ';
        }
        print "ok $testnum\n";
    }
}

# test 19: Test SaveNewValues()/RestoreNewValues()
my $testOK;
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue(ISO => 25);
    $exifTool->SetNewValue(Sharpness => '+1');
    $exifTool->SetNewValue(Artist => 'Phil', Group => 'IFD0');
    $exifTool->SetNewValue(Artist => 'Harvey', Group => 'ExifIFD');
    $exifTool->SetNewValue(DateTimeOriginal => '2006:03:27 16:25:00');
    $exifTool->SetNewValue(Keywords => ['one','two']);
    $exifTool->SaveNewValues();
    $exifTool->SetNewValue(Artist => 'nobody');
    $exifTool->SetNewValue(Keywords => 'three');
    $exifTool->SetNewValuesFromFile('t/images/FujiFilm.jpg');
    $exifTool->RestoreNewValues();
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        $testOK = 1;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 20/21: Test edit in place (using the file from the last test)
{
    my ($skip, $size);
    ++$testnum;
    $skip = '';
    if ($testOK) {
        my $exifTool = new Image::ExifTool;
        my $newComment = 'This is a new test comment';
        $exifTool->SetNewValue(Comment => $newComment);
        my $ok = writeInfo($exifTool, $testfile);
        my $info = $exifTool->ImageInfo($testfile, 'Comment');
        if ($$info{Comment} and $$info{Comment} eq $newComment and $ok) {
            $size = -s $testfile;
        } else {
            $testOK = 0;
            print 'not ';
        }
    } else {
        $skip = ' # skip Relies on previous test';
    }
    print "ok $testnum$skip\n";

    # test in-place edit of file passed by handle
    ++$testnum;
    $skip = '';
    if ($testOK) {
        my $exifTool = new Image::ExifTool;
        my $shortComment = 'short comment';
        $exifTool->SetNewValue(Comment => $shortComment);
        open FILE, "+<$testfile";   # open test file for update
        writeInfo($exifTool, \*FILE);
        close FILE;
        my $info = $exifTool->ImageInfo($testfile, 'Comment');
        if ($$info{Comment} and $$info{Comment} eq $shortComment) {
            my $newSize = -s $testfile;
            unless ($newSize < $size) {
                # test to see if the file got shorter as it should have
                $testOK = 0;
                $skip = ' # skip truncate() not supported on this system';
            }
        } else {
            $testOK = 0;
            print 'not ';
        }
    } else {
        $skip = ' # skip Relies on previous test';
    }
    print "ok $testnum$skip\n";
}

# test 22: Test time shift feature
{
    ++$testnum;
    my @writeInfo = (
        ['DateTimeOriginal' => '1:2', 'Shift' => 1],
        ['ModifyDate' => '2:1: 3:4', 'Shift' => 1],
        ['CreateDate' => '200 0', 'Shift' => -1],
        ['DateCreated' => '20:', 'Shift' => -1],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/XMP.jpg', 1);
    print "ok $testnum\n";
}

# test 23: Test renaming a file from the value of DateTimeOriginal
{
    ++$testnum;
    my $skip = '';
    if (not eval { require POSIX }) {
        $skip = ' # skip Requires POSIX';
    } elsif ($testOK) {
        my $newfile = "t/${testname}_${testnum}_20060327_failed.jpg";
        unlink $newfile;
        my $exifTool = new Image::ExifTool;
        $exifTool->Options(DateFormat => "${testname}_${testnum}_%Y%m%d_failed.jpg");
        $exifTool->SetNewValuesFromFile($testfile, 'FileName<DateTimeOriginal');
        writeInfo($exifTool, $testfile);
        if (-e $newfile and not -e $testfile) {
            $testfile = $newfile;
        } else {
            $testOK = 0;
            print 'not ';
        }
    } else {
        $skip = ' # skip Relies on test 21';
    }
    print "ok $testnum$skip\n";

    $testOK and unlink $testfile;   # erase test file if all tests passed
}

# test 24: Test redirection with expressions
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/FujiFilm.jpg',
        'Comment<ISO=$ISO Aperture=${EXIF:fnumber} Exposure=${shutterspeed}'
    );
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, 'Comment');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 25/26: Test order of delete operations
{
    my $i;
    for ($i=0; $i<2; ++$i) {
        ++$testnum;
        my $exifTool = new Image::ExifTool;
        $exifTool->SetNewValuesFromFile('t/images/Nikon.jpg', 'all:all', '-makernotes:all');
        $exifTool->SetNewValue(fnumber => 26) if $i == 1;
        $exifTool->SetNewValue('exififd:all'); # delete all exifIFD
        $exifTool->SetNewValue(fnumber => 25) if $i == 0;
        $testfile = "t/${testname}_${testnum}_failed.jpg";
        unlink $testfile;
        writeInfo($exifTool, 't/images/Canon.jpg', $testfile);
        my $info = $exifTool->ImageInfo($testfile);
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile;
        } else {
            print 'not ';
        }
        print "ok $testnum\n";
    }
}

# test 27: Check that mandatory EXIF resolution tags get taken from JFIF
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('exif:all');     # delete all EXIF
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/ExifTool.jpg', $testfile);
    $exifTool->SetNewValue();
    $exifTool->SetNewValue('exif:datetimeoriginal', '2000:01:02 03:04:05');
    my $ok = writeInfo($exifTool, $testfile);
    $info = $exifTool->ImageInfo($testfile, 'XResolution', 'YResolution', 'DateTimeOriginal');
    if (check($exifTool, $info, $testname, $testnum) and $ok) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 28-30: Check cross delete behaviour when deleting tags
{
    my $group;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('IFD0:ISO',100);
    $exifTool->SetNewValue('ExifIFD:ISO',200);
    writeInfo($exifTool, 't/images/Writer.jpg', 't/tmp.jpg');
    foreach $group ('EXIF', 'IFD0', 'ExifIFD') {
        ++$testnum;
        $exifTool->SetNewValue();   # reset values
        $exifTool->SetNewValue("$group:ISO");     # delete ISO from specific group
        $testfile = "t/${testname}_${testnum}_failed.jpg";
        unlink $testfile;
        writeInfo($exifTool, 't/tmp.jpg', $testfile);
        my $info = $exifTool->ImageInfo($testfile, 'FileName', 'ISO');
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile;
        } else {
            print 'not ';
        }
        print "ok $testnum\n";
    }
    unlink 't/tmp.jpg';
}

# test 31: Delete all but EXIF (excluding IFD1) and IPTC information
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('*');
    $exifTool->SetNewValue('EXIF:*', undef, Replace => 2);
    $exifTool->SetNewValue('ifd1:all');
    $exifTool->SetNewValue('IPTC:*', undef, Replace => 2);
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/ExifTool.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 32-33: Read/Write ICC Profile tags
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(IgnoreMinorErrors => 1);
    my $hdr = "\0\0\0\x18ADBE\x02\x10\0\0mntrRGB XYZ ";
    $exifTool->SetNewValue(AsShotICCProfile => $hdr . '<dummy>', Protected => 1);
    $exifTool->SetNewValue(CurrentICCProfile => $hdr . '<dummy 2>', Protected => 1);
    $testfile = "t/${testname}_${testnum}_failed.tif";
    unlink $testfile;
    my @tags = qw(ICC_Profile AsShotICCProfile CurrentICCProfile);
    writeInfo($exifTool, 't/images/ExifTool.tif', $testfile);
    my $info = $exifTool->ImageInfo($testfile, @tags);
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";

    ++$testnum;
    my $srcfile = $testfile;
    $exifTool->SetNewValue();
    $exifTool->SetNewValue(ICC_Profile => $hdr . '<another dummy>', Protected => 1);
    $testfile = "t/${testname}_${testnum}_failed.tif";
    unlink $testfile;
    writeInfo($exifTool, $srcfile, $testfile);
    $info = $exifTool->ImageInfo($testfile, @tags);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $srcfile;
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 34: copy list tag to list and non-list tags with different options
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(ListJoin => undef);
    $exifTool->SetNewValuesFromFile('t/images/IPTC.jpg',
            { Replace => 1 },
            'xmp:subject<filename',
            'xmp:subject<iptc:keywords',
            'comment<iptc:keywords',
            { Replace => 0 },
            'xmp:HierarchicalSubject<filename',
            'xmp:HierarchicalSubject<iptc:keywords',
    );
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    $info = $exifTool->ImageInfo($testfile, 'xmp:subject', 'comment', 'HierarchicalSubject');
    my $err;
    if (check($exifTool, $info, $testname, $testnum)) {
        # make sure it was an array reference
        my $val = $$info{Subject} || '';
        my $err;
        if (ref $val ne 'ARRAY') {
            $err = "Subject is not an ARRAY: '$val'";
        } elsif (@$val != 3) {
            $err = "Subject does not contain 3 values: '" . join(', ', @$val) . "'";
        }
        if ($err) {
            warn "\n  $err\n";
        } else {
            unlink $testfile;
        }
    } else {
        $err = 1;
    }
    print 'not ' if $err;
    print "ok $testnum\n";
}

# test 35: Add back all information after deleting everything
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('*');
    $exifTool->SetNewValuesFromFile('t/images/ExifTool.jpg', 'all:all',
                                    'icc_profile', 'canonvrd');
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/ExifTool.jpg', $testfile, undef, 1);
    $exifTool->Options(Composite => 0);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 36: Test adding and deleting from the same list
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('IPTC:Keywords', 'out', DelValue => 1);
    $exifTool->SetNewValue('IPTC:Keywords', 'in', AddValue => 1);
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, 'IPTC:all');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 37-38: Create EXIF file from EXIF block and individual tags
{
    my $i;
    for ($i=0; $i<2; ++$i) {
        ++$testnum;
        my $exifTool = new Image::ExifTool;
        my @tags;
        if ($i == 0) {
            $exifTool->SetNewValuesFromFile('t/images/Sony.jpg', 'EXIF');
            $exifTool->Options(PrintConv => 0);
            @tags = qw(FileSize Compression);
        } else {
            $exifTool->SetNewValuesFromFile('t/images/Sony.jpg');
            $exifTool->Options(PrintConv => 1, Unknown => 1);
        }
        $testfile = "t/${testname}_${testnum}_failed.exif";
        unlink $testfile;
        writeInfo($exifTool, undef, $testfile);
        my $info = $exifTool->ImageInfo($testfile, @tags);
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile;
        } else {
            print 'not ';
        }
        print "ok $testnum\n";
    }
}

# tests 39-40: Test writing only if the tag didn't already exist
{
    ++$testnum;
    my @writeInfo = (
        [DateTimeOriginal => '', DelValue => 1],
        [DateTimeOriginal => '1999:99:99 99:99:99'],
        [XResolution => '', DelValue => 1],
        [XResolution => '123'],
        [ResolutionUnit => '', DelValue => 1],
        [ResolutionUnit => 'cm'],
    );
    my @check = qw(FileName DateTimeOriginal XResolution ResolutionUnit);
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum,
                                   't/images/Writer.jpg', \@check);
    print "ok $testnum\n";

    ++$testnum;
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum,
                                   't/images/Canon.jpg', \@check, 1);
    print "ok $testnum\n";
}

# test 41: Test writing Kodak APP3 and Canon CIFF Meta information
{
    ++$testnum;
    my @writeInfo = (
        ['Meta:SerialNumber' => '12345'],
        ['CIFF:OwnerName' => 'CIFF Write Test'],
    );
    my @check = qw(SerialNumber OwnerName);
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum,
                                   't/images/ExifTool.jpg', \@check);
    print "ok $testnum\n";
}

# test 42: Test SetNewValuesFromFile with wildcards
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/ExifTool.jpg', 'ifd0:*<jfif:?resolution');
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    $exifTool->Options(Composite => 0);
    my $info = $exifTool->ImageInfo($testfile, '-file:all');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 43: Test increment feature EXIF
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    my @writeInfo = (
        [ExposureTime => '1.5', Shift => 1],
        [SerialNumber => '-9', Shift => -1], # (two negatives make a positive)
        [MeteringMode => '1', Shift => 0, AddValue => 1],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/Canon.jpg', 1);
    print "ok $testnum\n";
}

# test 44: Test increment feature with XMP
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my @writeInfo = (
        ['XMP:ApertureValue' => '-0.1', Shift => 1], # increment
        ['XMP:FNumber' => '28/10', DelValue => 1], # conditional delete
        ['XMP:DateTimeOriginal' => '3', Shift => 0, AddValue => 1], # shift
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/XMP.xmp', 1);
    print "ok $testnum\n";
}

# test 45: Test writing different EXIF string encoding
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(CharsetEXIF => 'Latin');
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->SetNewValue(Artist => "P\xc3\xaaro", Group => 'EXIF');
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    $exifTool->Options(CharsetEXIF => undef);
    my $info = $exifTool->ImageInfo($testfile, 'artist');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 46: Test writing with wildcards
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->SetNewValue('A*' => '7');
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 47: Test various WriteMode settings
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;                               # Should the tag be written?
    $exifTool->Options(WriteMode => 'w');           # --- write existing tags only:
    $exifTool->SetNewValue(ISO => 150);             # yes (already exists)
    $exifTool->SetNewValue(ImageDescription => 'N');# no  (doesn't already exist)
    $exifTool->Options(WriteMode => 'c');           # --- create new tags only:
    $exifTool->SetNewValue(ApertureValue => 8.0);   # no  (already exists)
    $exifTool->SetNewValue(UserComment => 'No');    # no  (exists, albeit empty)
    $exifTool->SetNewValue(Artist => 'Phil');       # yes (doesn't already exist)
    $exifTool->SetNewValue('XMP:Subject' => 'No');  # no  (shouldn't create new group)
    $exifTool->Options(WriteMode => 'cg');          # --- also create new groups:
    $exifTool->SetNewValue('IPTC:Keywords' => 'Y'); # yes (should create new group)
    $exifTool->Options(Composite => 0, FastScan => 2);
    writeInfo($exifTool, 't/images/Canon.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, '-time:all');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 48-50: More WriteMode 'cg' tests, and test AddUserDefinedTags()
{
    ++$testnum;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(WriteMode => 'cg');
    $exifTool->SetNewValue('XMP-dc:Title' => 'A');
    $exifTool->SetNewValue('XMP:Subject' => 'A');
    $exifTool->SetNewValue('XMP:LocationCreated' => '{city=A}');
    $exifTool->SetNewValue('XMP:Flash' => '{fired=true}');
    $exifTool->SetNewValue('IPTC:Keywords' => 'A');
    $exifTool->SetNewValue('IPTC:City' => 'A');
    $exifTool->SetNewValue('EXIF:Artist' => 'A');
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, '-time:all', '-filename');
    unless (check($exifTool, $info, $testname, $testnum)) {
        print 'not ';
    }
    print "ok $testnum\n";

    ++$testnum;
    my $testfile2 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile2;
    $exifTool->SetNewValue();
    $exifTool->SetNewValue('XMP-dc:Title' => 'B');
    $exifTool->SetNewValue('XMP:Subject' => 'B');
    $exifTool->SetNewValue('XMP:LocationCreated' => '{city=B}');
    $exifTool->SetNewValue('XMP:Flash' => '{fired=false}');
    $exifTool->SetNewValue('IPTC:Keywords' => 'B');
    $exifTool->SetNewValue('IPTC:City' => 'B');
    $exifTool->SetNewValue('EXIF:Artist' => 'B');
    if (writeInfo($exifTool, $testfile, $testfile2, 1)) {
        unlink $testfile;
        unlink $testfile2;
    } else {
        $info = $exifTool->ImageInfo($testfile2, '-time:all', '-filename');
        check($exifTool, $info, $testname, $testnum, $testnum-1);
        print 'not ';
    }
    print "ok $testnum\n";

    ++$testnum;
    $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    Image::ExifTool::AddUserDefinedTags('Image::ExifTool::XMP::dc', test => {} );
    $exifTool->SetNewValue();
    $exifTool->SetNewValue('XMP-dc:Title' => 'A');
    $exifTool->SetNewValue('XMP-dc:Test' => 'B');
    writeInfo($exifTool, undef, $testfile);
    $info = $exifTool->ImageInfo($testfile, 'xmp:all');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 51: Delete a unknown JPEG APP segment
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('APP6:*' => undef);
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/ExifTool.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 52: Delete groups by family 2 group name
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue('Image:*');
    $exifTool->SetNewValue('Camera:*');
    $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    writeInfo($exifTool, 't/images/XMP.xmp', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 53: Exclude groups when copying
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/Canon.jpg', '-Exif:All', '-Canon:All');
    $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 54: Specify multiple groups when copying, excluding a single tag
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/Canon.jpg', 'Exif:Time:All', '-createdate');
    $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, 'exif:*', '-image:all');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# tests 55-56: Create and edit EXV file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValue(Artist => 'me');
    $exifTool->SetNewValue(Keywords => ['one','two']);
    $testfile = "t/${testname}_${testnum}_failed.exv";
    unlink $testfile;
    writeInfo($exifTool, undef, $testfile);
    my $info = $exifTool->ImageInfo($testfile, 'exif:*', 'iptc:*', 'xmp:*');
    unless (check($exifTool, $info, $testname, $testnum)) {
        print 'not ';
    }
    print "ok $testnum\n";

    ++$testnum;
    $exifTool->SetNewValue();
    $exifTool->SetNewValue(Artist);
    $exifTool->SetNewValue(Title => 'Test');
    my $testfile2 = "t/${testname}_${testnum}_failed.exv";
    unlink $testfile2;
    writeInfo($exifTool, $testfile, $testfile2);
    $info = $exifTool->ImageInfo($testfile2, 'exif:*', 'iptc:*', 'xmp:*');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
        unlink $testfile2;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 57: Test setting Composite PreviewImage using various groups
{
    ++$testnum;
    my $ok = 1;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(IgnoreMinorErrors => 1);
    my %try = (
        'previewimage'              => 1,
        'composite:previewimage'    => 0,   # (shouldn't be in the Composite group)
        'composite:thumbnailimage'  => 0,
        'composite:jpgfromraw'      => 0,
        'composite:otherimage'      => 0,
        'ifd0:previewimage'         => 1,
        '0ifd0:previewimage'        => 0,
        '1ifd0:previewimage'        => 1,
        '2ifd0:previewimage'        => 0,
        'exif:previewimage'         => 1,
        '0exif:previewimage'        => 1,
        '1exif:previewimage'        => 0,
        '2exif:previewimage'        => 0,
        'preview:previewimage'      => 1,
        '0preview:previewimage'     => 0,
        '1preview:previewimage'     => 0,
        '2preview:previewimage'     => 1,
        'makernotes:previewimage'   => 1,
        '0makernotes:previewimage'  => 1,
        '1makernotes:previewimage'  => 0,
        '2makernotes:previewimage'  => 0,
        'xxx:previewimage'          => 0,
        '0xxx:previewimage'         => 0,
        '1xxx:previewimage'         => 0,
        '2xxx:previewimage'         => 0,
        'ifd0:exif:preview:previewimage'    => 1,
        '0ifd0:exif:preview:previewimage'   => 0,
        '1ifd0:exif:preview:previewimage'   => 1,
        '2ifd0:exif:preview:previewimage'   => 0,
        'ifd0:0exif:preview:previewimage'   => 1,
        'ifd0:1exif:preview:previewimage'   => 0,
        'ifd0:2exif:preview:previewimage'   => 0,
        'ifd0:exif:0preview:previewimage'   => 0,
        'ifd0:exif:1preview:previewimage'   => 0,
        'ifd0:exif:2preview:previewimage'   => 1,
        '1ifd0:0exif:2preview:previewimage' => 1,
        'exif:makernotes:previewimage'      => 1,   # (but wouldn't write anything)
    );
    my $tag;
    foreach $tag (sort keys %try) {
        my ($num, $err) = $exifTool->SetNewValue($tag => 'test');
        next unless $num xor $try{$tag};
        warn "\nError setting $tag\n";
        $ok = 0;
    }
    print 'not ' unless $ok;
    print "ok $testnum\n";
}

# test 58: Set ICC_Profile from an external file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    open IN, 't/images/ICC_Profile.icc' or die;
    binmode IN;
    my $buff;
    read IN, $buff, 1000;
    close IN;
    my @writeInfo = (
        [ICC_Profile => \$buff, Protected => 1],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}

# end
