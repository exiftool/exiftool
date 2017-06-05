# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Geotag.t".

my $numTests;

BEGIN {
    $numTests = 11;
    $| = 1; print "1..$numTests\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
    # must create user-defined tags before loading ExifTool (used in test 8)
    %Image::ExifTool::UserDefined = (
        'Image::ExifTool::GPS::Main' => {
            0xd000 => {
                Name => 'GPSPitch',
                Writable => 'rational64s',
            },
            0xd001 => {
                Name => 'GPSRoll',
                Writable => 'rational64s',
            },
        },
    );
}
END {print "not ok 1\n" unless $loaded;}
# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Geotag;
$loaded = 1;
print "ok 1\n";

my $testname = 'Geotag';
my $testnum = 1;
my @testTags = ('Error', 'Warning', 'GPS:*', 'XMP:*');
my $testfile2;

unless (eval { require Time::Local }) {
    warn "Install Time::Local to use the Geotag feature\n";
    while (++$testnum <= $numTests) {
        print "ok $testnum # skip Requires Time::Local\n";
    }
    goto IgnoreAll;
}

# test 2: Geotag from GPX track log
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $testfile2 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile2;
    $exifTool->SetNewValue(Geotag => 't/images/Geotag.gpx');
    $exifTool->SetNewValue(Geotime => '2003:05:24 17:09:31Z');
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile2);
    my $info = $exifTool->ImageInfo($testfile2, @testTags);
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# tests 3-5: Geotag tests using Magellan track log
{
    # geotag to XMP
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->SetNewValue(Geotag => 't/images/Geotag.log');
    $exifTool->SetNewValue('XMP:Geotime' => '2009:04:03 06:11:30-05:00');
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, @testTags);
    if (check($exifTool, $info, $testname, $testnum, 3)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";

    # point too far outside track
    ++$testnum;
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    my ($num, $err) = $exifTool->SetNewValue(Geotime => '2009:04:03 08:00:00-05:00');
    $exifTool->WriteInfo($testfile2, $testfile);
    $info = $exifTool->ImageInfo($testfile, @testTags);
    if (check($exifTool, $info, $testname, $testnum, 2)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";

    # delete geotags
    ++$testnum;
    my $testfile5 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile5;
    ($num, $err) = $exifTool->SetNewValue(Geotime => undef);
    $exifTool->WriteInfo($testfile2, $testfile5);
    $info = $exifTool->ImageInfo($testfile5, 'Filename', @testTags);
    if (check($exifTool, $info, $testname, $testnum) and not $err) {
        unlink $testfile2;
        unlink $testfile5;
    } else {
        warn "\n  $err\n" if $err;
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 6: Geotag from Garmin XML track log and test Geosync too
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->SetNewValue(Geosync => '1:30');
    $exifTool->SetNewValue(Geotag => 't/images/Geotag.xml');
    $exifTool->SetNewValuesFromFile('t/images/Panasonic.jpg',
        'Geotime<${DateTimeOriginal}+02:00'
    );
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, @testTags);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 7: Geotag from IGC log with time drift correction
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    my $txtfile = "t/${testname}_${testnum}.failed";
    unlink $testfile;
    open GEOTAG_TEST_7, ">$txtfile" or warn "Error opening $txtfile\n";
    $exifTool->Options(Verbose => 2);
    $exifTool->Options(TextOut => \*GEOTAG_TEST_7);
    $exifTool->SetNewValue(Geosync => '2010:01:05 07:00:00Z@2001:08:01 12:00:00-02:00');
    $exifTool->SetNewValue(Geosync => '2010:01:05 09:01:00Z@2001:08:01 14:00:00-02:00');
    $exifTool->SetNewValue(Geotag => 't/images/Geotag.igc');
    $exifTool->SetNewValuesFromFile('t/images/Nikon.jpg',
        'Geotime<${DateTimeOriginal}-02:00'
    );
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile);
    close GEOTAG_TEST_7;
    if (testCompare('t/Geotag_7.out', $txtfile, $testnum)) {
        unlink $testfile;
        unlink $txtfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 8:  Geotag with attitude information from PTNTHPR sentence
# test 9:  Geotag from KML track log (obtained from Google Location),
# test 10: Geotag from Bramor gEO log
{
    my %dat = (
        8  => { file => 'Geotag2.log', geotime => '2010:04:24 06:27:30-05:00' },
        9  => { file => 'Geotag.kml',  geotime => '2013:11:13 09:04:31Z' },
        10 => { file => 'Geotag3.log', geotime => '2014:04:21 07:06:42Z' },
    );
    my $exifTool = new Image::ExifTool;
    while ($testnum < 10) {
        ++$testnum;
        $testfile = "t/${testname}_${testnum}_failed.jpg";
        unlink $testfile;
        $exifTool->SetNewValue(Geotag => 't/images/' . $dat{$testnum}{file});
        $exifTool->SetNewValue(Geotime => $dat{$testnum}{geotime});
        $exifTool->WriteInfo('t/images/Writer.jpg', $testfile);
        my $info = $exifTool->ImageInfo($testfile, @testTags);
        if (check($exifTool, $info, $testname, $testnum)) {
            unlink $testfile;
        } else {
            print 'not ';
        }
        print "ok $testnum\n";
    }
}

# test 11: Geotag date/time only with drift correction
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->SetNewValue(Geotag => 'DATETIMEONLY');
    $exifTool->SetNewValue(Geosync => '2009:01:01 01:00:00Z@2009:01:01 01:00:00Z');
    $exifTool->SetNewValue(Geosync => '2011:01:01 02:00:00Z@2011:01:01 01:00:00Z');
    $exifTool->SetNewValue(Geotime => '2010:01:01 01:00:00Z');
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, @testTags);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

IgnoreAll:

# end
