# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/HtmlDump.t".

BEGIN {
    $| = 1; print "1..2\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool::HtmlDump;
use File::RandomAccess;
$loaded = 1;
print "ok 1\n";

# test 2: Escape special characters in the HTML dump title
{
    my $data = 'test';
    my $html = '';
    my $raf = File::RandomAccess->new(\$data);
    my $dump = Image::ExifTool::HtmlDump->new;
    my $title = 'HTML Dump (</title><script>window.exiftoolPoc=1</script>)';
    $dump->Print($raf, undef, 0, \$html, 1, $title);
    notOK() unless ($html =~ /&lt;\/title&gt;&lt;script&gt;window\.exiftoolPoc=1&lt;\/script&gt;/ and
                     $html !~ /<script>window\.exiftoolPoc=1<\/script>/);
    print "ok 2\n";
}

done(); # end
