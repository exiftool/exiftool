# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/QuickTime.t".

BEGIN {
    $| = 1; print "1..17\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::QuickTime;
$loaded = 1;
print "ok 1\n";

my $testname = 'QuickTime';
my $testnum = 1;

# tests 2-3: Extract information from QuickTime.mov and QuickTime.m4a
{
    my $ext;
    foreach $ext (qw(mov m4a)) {
        ++$testnum;
        my $exifTool = Image::ExifTool->new;
        my $info = $exifTool->ImageInfo("t/images/QuickTime.$ext");
        notOK() unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}

# tests 4-5: Try writing XMP to the different file formats
{
    my $ext;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(SavePath => 1); # to save group 5 names
    $exifTool->SetNewValue('XMP:Title' => 'x');
    $exifTool->SetNewValue('TrackCreateDate' => '2000:01:02 03:04:05');
    $exifTool->SetNewValue('Track1:TrackModifyDate' => '2013:11:04 10:32:15');
    foreach $ext (qw(mov m4a)) {
        ++$testnum;
        unless (eval { require Time::Local }) {
            print "ok $testnum # skip Requires Time::Local\n";
            next;
        }
        my $testfile = "t/${testname}_${testnum}_failed.$ext";
        unlink $testfile;
        my $rtnVal = $exifTool->WriteInfo("t/images/QuickTime.$ext", $testfile);
        my $info = $exifTool->ImageInfo($testfile, 'title', 'time:all');
        if (check($exifTool, $info, $testname, $testnum, undef, 5)) {
            unlink $testfile;
        } else {
            notOK();
        }
        print "ok $testnum\n";
    }
}

# test 6: Write video rotation
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValue('Rotation' => '270', Protected => 1);
    my $testfile = "t/${testname}_${testnum}_failed.mov";
    unlink $testfile;
    my $rtnVal = $exifTool->WriteInfo('t/images/QuickTime.mov', $testfile);
    my $info = $exifTool->ImageInfo($testfile, 'Rotation', 'MatrixStructure');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 7: Add a bunch of new tags and delete one
{
    ++$testnum;
    my @writeInfo = (
        ['QuickTime:Artist' => 'me'],
        ['QuickTime:Model' => 'model'],
        ['UserData:Genre' => 'rock'],
        ['UserData:Album' => 'albumA'],
        ['ItemList:Album' => 'albumB'],
        ['ItemList:ID-albm:Album' => 'albumC'],
        ['QuickTime:Comment-fra-FR' => 'fr comment'],
        ['Keys:Director' => 'director'],
        ['Keys:CameraDirection' => '90'],
        ['Keys:Album' => undef ],
    );
    my @extract = ('ItemList:all', 'UserData:all', 'Keys:all');
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/QuickTime.mov', \@extract);
    print "ok $testnum\n";
}

# test 8-9: Delete everything then add back some tags in one step
{
    my $ext;
    my $exifTool = Image::ExifTool->new;
    my @writeInfo = (
        ['all' => undef],
        ['artist' => 'me'],
        ['keys:director' => 'dir'],
        ['userdata:arranger' => 'arr'],
    );
    my @extract = ('QuickTime:all', 'XMP:all');
    foreach $ext (qw(mov m4a)) {
        ++$testnum;
        notOK() unless writeCheck(\@writeInfo, $testname, $testnum, "t/images/QuickTime.$ext", \@extract);
        print "ok $testnum\n";
    }
}

# test 10: Delete everything then add back some tags in two steps
{
    ++$testnum;
    my $testfile = "t/${testname}_${testnum}a_failed.mov";
    unlink $testfile;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(QuickTimeHandler => 1);
    $exifTool->SetNewValue('all' => undef);
    writeInfo($exifTool, 't/images/QuickTime.mov', $testfile);
    my @writeInfo = (
        ['quicktime:artist' => 'me'],
        ['keys:director' => 'dir'],
        ['userdata:arranger' => 'arr'],
    );
    my @extract = ('QuickTime:all', 'XMP:all', '-Track1:all', '-Track2:all');
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum, $testfile, \@extract);
    print "ok $testnum\n";
}

# tests 11-13: HEIC write tests
{
    ++$testnum;
    my $testfile = "t/${testname}_${testnum}_failed.heic";
    unlink $testfile;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(Composite => 0);
    $exifTool->SetNewValue('XMP-dc:Title' => 'a title');
    writeInfo($exifTool, 't/images/QuickTime.heic', $testfile);
    my $info = $exifTool->ImageInfo($testfile, '-file:all');
    unless (check($exifTool, $info, $testname, $testnum)) {
        notOK();
    }
    print "ok $testnum\n";

    ++$testnum;
    my $testfile2 = "t/${testname}_${testnum}_failed.heic";
    unlink $testfile2;
    $exifTool->SetNewValue();
    $exifTool->SetNewValue('XMP:all' => undef);
    $exifTool->SetNewValue('EXIF:Artist' => 'an artist');
    writeInfo($exifTool, $testfile, $testfile2);
    $info = $exifTool->ImageInfo($testfile2, '-file:all');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";

    ++$testnum;
    $testfile = "t/${testname}_${testnum}_failed.heic";
    unlink $testfile;
    $exifTool->SetNewValue();
    $exifTool->SetNewValue('EXIF:all' => undef);
    $exifTool->SetNewValue('EXIF:UserComment' => 'a comment');
    $exifTool->SetNewValue('XMP:Subject' => 'a subject');
    $exifTool->SetNewValue('XMP:Subject' => 'another subject');
    writeInfo($exifTool, $testfile2, $testfile);
    $info = $exifTool->ImageInfo($testfile, '-file:all');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
        unlink $testfile2;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 14: Delete everything then add back a tag without specifying the group
{
    ++$testnum;
    my $testfile = "t/${testname}_10a_failed.mov";  # use source file from test 10
    my @writeInfo = ( ['publisher' => 'pub'] );
    my @extract = ('QuickTime:all', 'XMP:all', '-Track1:all', '-Track2:all');
    if (writeCheck(\@writeInfo, $testname, $testnum, $testfile, \@extract)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 15: Test WriteMode option with QuickTime tags
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(WriteMode => 'c');
    $exifTool->SetNewValue('ItemList:Composer' => 'WRONG');
    $exifTool->SetNewValue('ItemList:Author' => 'aut');
    $exifTool->SetNewValue('Keys:Artist' => 'WRONG');
    $exifTool->SetNewValue('UserData:Artist' => 'art');
    my $testfile = "t/${testname}_${testnum}_failed.m4a";
    unlink $testfile;
    my $rtnVal = $exifTool->WriteInfo('t/images/QuickTime.m4a', $testfile);
    my $info = $exifTool->ImageInfo($testfile, 'ItemList:all', 'Keys:all', 'UserData:all');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 16: Write some Microsoft Xtra tags
{
    ++$testnum;
    my @writeInfo = (
        ['Microsoft:Director' => 'dir1'],
        ['Microsoft:Director' => 'dir2'],
        ['Microsoft:SharedUserRating' => 75],
    );
    my @extract = ('Microsoft:all');
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/QuickTime.mov', \@extract);
    print "ok $testnum\n";
}

# test 17: Write some 3gp tags
{
    ++$testnum;
    my @writeInfo = (
        ['UserData:LocationInformation' => 'test comment role=Shooting lat=1.2 lon=-2.3 alt=100 body=earth notes=a note'],
        ['UserData:Rating' => 'entity=ABCD criteria=1234 a rating'],
    );
    notOK() unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/QuickTime.mov', 1);
    print "ok $testnum\n";
}

done(); # end
