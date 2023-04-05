# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/Lang.t'

BEGIN {
    $| = 1; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}

use Image::ExifTool;

print "1..", scalar(@Image::ExifTool::langs), "\n";

my $testname = 'Lang';
my $testnum = 0;

# test 1: Test localized language description for a lang-alt tag
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    $exifTool->Options(Lang => 'de');
    my $info = $exifTool->ImageInfo('t/images/MIE.mie', 'Comment-fr_FR');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# tests 2-N: Test all languages
my $exifTool = Image::ExifTool->new;
my $lang;
foreach $lang (@Image::ExifTool::langs) {
    next if $lang eq 'en'; # skip english
    ++$testnum;
    my $not = 'not ';
    $exifTool->Options(Lang => $lang);
    if ($exifTool->Options('Lang') eq $lang) {
        my $info = $exifTool->ImageInfo('t/images/FujiFilm.jpg', 'Exif:All');
        $not = '' if check($exifTool, $info, $testname, $testnum);
    } else {
        warn "\n  Error loading language $lang\n";
    }
    notOK() if $not;
    print "ok $testnum\n";
}

done(); # end
