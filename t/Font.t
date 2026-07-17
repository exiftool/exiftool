# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/Font.t".

BEGIN {
    $| = 1; print "1..10\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Font;
$loaded = 1;
print "ok 1\n";

my $testname = 'Font';
my $testnum = 1;

# tests 2-7: Extract information from test Font files
{
    my $exifTool = Image::ExifTool->new;
    my $type;
    foreach $type (qw(afm dfont pfa pfb pfm ttf)) {
        ++$testnum;
        my $info = $exifTool->ImageInfo("t/images/Font.$type");
        notOK() unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}

# tests 8/10: Test bounded WOFF zlib decompression
{
    my $skip = '';
    if (eval { require Compress::Zlib }) {
        my $data = Compress::Zlib::compress('A' x 1024);
        my $exifTool = Image::ExifTool->new;
        ++$testnum;
        notOK() unless Image::ExifTool::Font::Uncompress($exifTool, \$data, 2048) and
                       $data eq 'A' x 1024;
        print "ok $testnum\n";

        $data = Compress::Zlib::compress('A' x 1024);
        $exifTool = Image::ExifTool->new;
        ++$testnum;
        notOK() unless not Image::ExifTool::Font::Uncompress($exifTool, \$data, 100) and
                       $exifTool->GetValue('Warning') eq 'Uncompressed metadata is too large';
        print "ok $testnum\n";
    } else {
        $skip = ' # skip Requires Compress::Zlib';
        ++$testnum;
        print "ok $testnum$skip\n";
        ++$testnum;
        print "ok $testnum$skip\n";
    }

    my $max = 100000001;
    my $head = pack('a4a4NnnNnnNNNNN', 'wOFF', "\0\1\0\0", 65, 1, 0,
                    $max, 1, 0, 0, 0, 0, 0, 0);
    my $dir = pack('a4NNNN', 'name', 64, 1, $max, 0);
    my $info = ImageInfo(\($head . $dir . "\0"));
    ++$testnum;
    notOK() unless $$info{FileType} eq 'WOFF' and
                   $$info{Warning} eq 'Font table too large';
    print "ok $testnum\n";
}

done(); # end
