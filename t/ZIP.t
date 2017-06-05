# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/ZIP.t".

BEGIN {
    $| = 1; print "1..7\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::ZIP;
$loaded = 1;
print "ok 1\n";

my $testname = 'ZIP';
my $testnum = 1;
my $failed;

# tests 2-3: Extract information from test ZIP and GZIP files
{
    my $exifTool = new Image::ExifTool;
    my $type;
    foreach $type (qw(zip gz)) {
        ++$testnum;
        my $info = $exifTool->ImageInfo("t/images/ZIP.$type");
        print 'not ' and $failed = 1 unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}

# tests 4-7: Extract information from other ZIP-based files (requires Archive::Zip)
{
    my $exifTool = new Image::ExifTool;
    my $file;
    foreach $file ('OOXML.docx', 'CaptureOne.eip', 'iWork.numbers', 'OpenDoc.ods') {
        ++$testnum;
        my $skip = '';
        if (eval 'require Archive::Zip') {
            my $info = $exifTool->ImageInfo("t/images/$file");
            print 'not ' and $failed = 1 unless check($exifTool, $info, $testname, $testnum);
        } else {
            $skip = ' # skip Requires Archive::Zip';
        }
        print "ok $testnum$skip\n";
    }
}

# pass on any Archive::Zip warning
if ($Image::ExifTool::ZIP::warnString) {
    warn $Image::ExifTool::ZIP::warnString;
}

# print module versions if anything failed
if ($failed) {
    my $mod;
    warn "\n";
    foreach $mod ('Archive::Zip', 'Compress::Raw::Zlib', 'IO::String') {
        my $v;
        if (eval "require $mod") {
            my $var = $mod . '::VERSION';
            no strict 'refs';
            $v = $$var;
        }
        my $w = $v ? "version is $v" : 'is not installed';
        warn "    ($mod $w)\n";
    }
}

# end
