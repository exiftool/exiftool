# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Geolocation.t".

BEGIN {
    $| = 1; print "1..8\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Geolocation;
$loaded = 1;
print "ok 1\n";

my $testname = 'Geolocation';
my $testnum = 1;

# test 2: Test Geolocation option
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(Geolocation => 1);
    $exifTool->Options(GeolocMinPop => 5000);
    my $info = $exifTool->ImageInfo('t/images/GPS.jpg', 'Geolocation*');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Test writing Geolocate with GPS
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(GeolocMinPop => 1000000);
    $exifTool->SetNewValue(Geolocate => '44,-72');
    $exifTool->SetNewValue('IPTC:Geolocate' => '48.338, 2.074');
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, '-file:all');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 4: Test writing Geolocate with city name
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->SetNewValue(Geolocate => 'Kingston,Ontario');
    $exifTool->Options(Composite => 0);
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    writeInfo($exifTool, 't/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, '-file:all');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 5: Geotag with Geolocation
{
    my @testTags = ('Error', 'Warning', 'GPS:*', 'XMP:*', 'IPTC:*');
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->SetNewValue('IPTC:XMP:Geolocate' => 'Geotag');
    $exifTool->SetNewValue(Geotag => 't/images/Geotag.gpx');
    $exifTool->SetNewValue(Geotime => '2003:05:24 17:09:31Z');
    $exifTool->WriteInfo('t/images/Writer.jpg', $testfile);
    my $info = $exifTool->ImageInfo($testfile, @testTags);
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 6: Generate geolocation information from dummy file in memory,
#         returning the two nearest cities, avoiding PPLX features
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(Geolocation => '48.1375,11.5755,num=2');
    $exifTool->Options(GeolocFeature => '-PPLX');
    my $dat = '';
    my $info = $exifTool->ImageInfo(\$dat, 'geolocation*');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# tests 7-8: Test regular expression with combined search with user-defined
#            database entry
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    Image::ExifTool::Geolocation::AddEntry('Sinemorets','burgas','Obshtina Tsarevo',
        'BG','','Europe/Sofia','',400,42.06115,27.97833,'abcde,fghij,klmno');
    $exifTool->Options(Geolocation => '1,2,co/Canada/');
    my $dat = '';
    my $info = $exifTool->ImageInfo(\$dat, 'geolocation*');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";

    ++$testnum;
    $exifTool->Options(Geolocation => 'fghij');
    $info = $exifTool->ImageInfo(\$dat, 'geolocation*');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

done(); # end
