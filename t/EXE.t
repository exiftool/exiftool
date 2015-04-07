# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/EXE.t".

BEGIN { $| = 1; print "1..4\n"; $Image::ExifTool::noConfig = 1; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::EXE;
$loaded = 1;
print "ok 1\n";

use t::TestLib;

my $testname = 'EXE';
my $testnum = 1;

# tests 2-4: Extract information from Windows PE, Mac OS X Mach-O and Unix ELF executables
{
    my $exifTool = new Image::ExifTool;
    my $ext;
    foreach $ext ('exe', 'macho', 'elf') {
        ++$testnum;
        my $info = $exifTool->ImageInfo("t/images/EXE.$ext");
        print 'not ' unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}


# end
