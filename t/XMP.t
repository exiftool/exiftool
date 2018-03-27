# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/XMP.t".

BEGIN {
    $| = 1; print "1..46\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# definitions for user-defined tag test (#26)
%Image::ExifTool::UserDefined = (
    'Image::ExifTool::XMP::Main' => {
        myXMPns => {
            SubDirectory => {
                TagTable => 'Image::ExifTool::UserDefined::myXMPns',
                # (see the definition of this table below)
            },
        },
    },
);
use vars %Image::ExifTool::UserDefined::myXMPns;    # avoid "typo" warning
%Image::ExifTool::UserDefined::myXMPns = (
    GROUPS    => { 0 => 'XMP', 1 => 'XMP-myXMPns'},
    NAMESPACE => { 'myXMPns' => 'http://ns.exiftool.ca/t/XMP.t' },
    WRITABLE  => 'string',
    ATestTag  => { List => 'Bag', Resource => 1 },
    BTestTag  => {
        Struct => {
            TYPE => 'myXMPns:SomeFunnyType',
            Field1 => { Writable => 'lang-alt', List => 'Bag' },
        }
    },
    BTestTagField1 => { Name => 'Renamed', Flat => 1 },
);

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::XMP;
$loaded = 1;
print "ok 1\n";

my $testname = 'XMP';
my $testnum = 1;

# test 2: Extract information from XMP.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/XMP.jpg', {Duplicates => 1});
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Test rewriting everything with slightly different values
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(Duplicates => 1, Binary => 1, ListJoin => undef);
    my $info = $exifTool->ImageInfo('t/images/XMP.jpg');
    my $tag;
    foreach $tag (keys %$info) {
        my $group = $exifTool->GetGroup($tag);
        my $val = $$info{$tag};
        if (ref $val eq 'ARRAY') {
            push @$val, 'v2';
        } elsif (ref $val eq 'SCALAR') {
            $val = 'v2';
        } elsif ($val =~ /^\d+(\.\d*)?$/) {
            # (add extra .001 to avoid problem with aperture of 4.85
            #  getting rounded to 4.8 or 4.9 and causing failed tests)
            $val += ($val / 10) + 1.001;
            $1 or $val = int($val);
        } else {
            $val .= '-v2';
        }
        # eat return values so warning don't get printed
        my @x = $exifTool->SetNewValue($tag, $val, Group=>$group, Replace=>1);
    }
    # also try writing a few specific tags
    $exifTool->SetNewValue(CreatorCountry => 'Canada');
    $exifTool->SetNewValue(CodedCharacterSet => 'UTF8', Protected => 1);
    undef $info;
    my $image;
    my $ok = writeInfo($exifTool,'t/images/XMP.jpg',\$image);
    # this is effectively what the RHEL 3 UTF8 LANG problem does:
    # $image = pack("U*", unpack("C*", $image));

    my $exifTool2 = new Image::ExifTool;
    $exifTool2->Options(Duplicates => 1);
    $info = $exifTool2->ImageInfo(\$image);
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    if (check($exifTool2, $info, $testname, $testnum) and $ok) {
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

# tests 4/5: Test extracting then reading XMP data as a block
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/XMP.jpg','XMP');
    print 'not ' unless $$info{XMP};
    print "ok $testnum\n";

    ++$testnum;
    my $pass;
    if ($$info{XMP}) {
        $info = $exifTool->ImageInfo($$info{XMP});
        $pass = check($exifTool, $info, $testname, $testnum);
    }
    print 'not ' unless $pass;
    print "ok $testnum\n";
}

# test 6: Test copying information to a new XMP data file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->SetNewValuesFromFile('t/images/XMP.jpg');
    my $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    my $ok = writeInfo($exifTool,undef,$testfile);
    my $info = $exifTool->ImageInfo($testfile);
    if (check($exifTool, $info, $testname, $testnum) and $ok) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 7: Test rewriting CS2 XMP information
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    $exifTool->SetNewValue(Label => 'Blue');
    $exifTool->SetNewValue(Rating => 3);
    $exifTool->SetNewValue(Subject => q{char test: & > < ' "}, AddValue => 1);
    $exifTool->SetNewValue('Rights' => "\xc2\xa9 Copyright Someone Else");
    my $ok = writeInfo($exifTool,'t/images/XMP.xmp',$testfile);
    print 'not ' unless testCompare("t/XMP_$testnum.out",$testfile,$testnum) and $ok;
    print "ok $testnum\n";
}

# test 8-11: Test reading/writing XMP with blank nodes and some problems that need correcting
{
    my $file;
    foreach $file ('XMP2.xmp', 'XMP3.xmp') {
        ++$testnum;
        my $exifTool = new Image::ExifTool;
        my $info = $exifTool->ImageInfo("t/images/$file", {Duplicates => 1});
        print 'not ' unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";

        ++$testnum;
        my $testfile = "t/${testname}_${testnum}_failed.xmp";
        unlink $testfile;
        $exifTool->SetNewValue('XMP:Creator' => 'Phil', AddValue => 1);
        $exifTool->SetNewValue('manifestplacedXResolution' => 1);
        $exifTool->SetNewValue('attributionname' => 'something else');
        $exifTool->WriteInfo("t/images/$file", $testfile);
        my $err = $exifTool->GetValue('Error');
        warn "\n  $err\n" if $err;
        print 'not ' unless testCompare("t/XMP_$testnum.out",$testfile,$testnum);
        print "ok $testnum\n";
    }
}

# tests 12-17: Test writing/deleting XMP alternate languages
{
    my @writeList = (
        [ ['Rights-x-default' => "\xc2\xa9 Copyright Another One"] ], # should overwrite x-default only
        [ ['Rights-de-DE' => "\xc2\xa9 Urheberrecht Phil Harvey"] ],  # should create de-DE only
        [ ['Rights-x-default' => undef] ],  # should delete x-default only
        [ ['Rights-fr' => undef] ],         # should delete fr only
        [ ['Title-fr' => 'Test fr title'] ],# should not create x-default
        [ ['Title-fr' => 'Test fr title'],
          ['Title-x-default' => 'dTitle'] ],# should create x-default before fr
    );
    my $writeListRef;
    foreach $writeListRef (@writeList) {
        ++$testnum;
        my $exifTool = new Image::ExifTool;
        my $testfile = "t/${testname}_${testnum}_failed.xmp";
        unlink $testfile;
        print 'not ' unless writeCheck($writeListRef, $testname, $testnum,
                                       't/images/XMP.xmp', ['XMP-dc:*']);
        print "ok $testnum\n";
    }
}

# test 18: Delete some family 1 XMP groups
{
    ++$testnum;
    my @writeInfo = (
        [ 'xmp-xmpmm:all' => undef ],
        [ 'XMP-PHOTOSHOP:all' => undef ],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum,
                                   't/images/XMP.jpg', ['XMP:all']);
    print "ok $testnum\n";
}

# test 19-20: Copy from XMP to EXIF with and without PrintConv enabled
{
    my $exifTool = new Image::ExifTool;
    while ($testnum < 20) {
        ++$testnum;
        my $testfile = "t/${testname}_${testnum}_failed.jpg";
        unlink $testfile;
        $exifTool->SetNewValue();
        $exifTool->SetNewValuesFromFile('t/images/XMP.xmp', 'XMP:all>EXIF:all');
        my $ok = writeInfo($exifTool, "t/images/Writer.jpg", $testfile);
        my $info = $exifTool->ImageInfo($testfile, 'EXIF:all');
        if (check($exifTool, $info, $testname, $testnum) and $ok) {
            unlink $testfile;
        } else {
            print 'not ';
        }
        print "ok $testnum\n";
        $exifTool->Options(PrintConv => 0);
    }
}

# test 21-22: Copy from EXIF to XMP with and without PrintConv enabled
{
    my $exifTool = new Image::ExifTool;
    while ($testnum < 22) {
        ++$testnum;
        my $testfile = "t/${testname}_${testnum}_failed.xmp";
        unlink $testfile;
        $exifTool->SetNewValue();
        $exifTool->SetNewValuesFromFile('t/images/Canon.jpg', 'EXIF:* > XMP:*');
        my $ok = writeInfo($exifTool, undef, $testfile);
        my $info = $exifTool->ImageInfo($testfile, 'XMP:*');
        if (check($exifTool, $info, $testname, $testnum) and $ok) {
            unlink $testfile;
        } else {
            print 'not ';
        }
        print "ok $testnum\n";
        $exifTool->Options(PrintConv => 0);
    }
}

# test 23: Delete all tags except two specific XMP family 1 groups
{
    ++$testnum;
    my @writeInfo = (
        [ 'all' => undef ],
        [ 'xmp-dc:all'  => undef, Replace => 2 ],
        [ 'xmp-xmprights:all' => undef, Replace => 2 ],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum,
                                   't/images/XMP.jpg', ['XMP:all']);
    print "ok $testnum\n";
}

# test 24: Delete all tags except XMP
{
    ++$testnum;
    my @writeInfo = (
        [ 'all' => undef ],
        [ 'xmp:all' => undef, Replace => 2 ],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum,
                                   't/images/XMP.jpg', ['-file:all']);
    print "ok $testnum\n";
}

# test 25: Extract information from SVG image
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/XMP.svg', {Duplicates => 1});
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 26: Test creating a variety of XMP information
#          (including x:xmptk, rdf:about and rdf:resource attributes)
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    my @writeInfo = (
        [ 'XMP-x:XMPToolkit' => "What's this?", Protected => 1 ],
        [ 'XMP-rdf:About' => "http://www.exiftool.ca/t/$testname.t#$testnum", Protected => 1 ],
        [ 'XMP:ImageType' => 'Video' ],
        [ 'LicenseeImageNotes-en' => 'english notes' ],
        [ 'LicenseeImageNotes-de' => 'deutsche anmerkungen' ],
        [ 'LicenseeImageNotes' => 'default notes' ],
        [ 'LicenseeName' => 'Phil' ],
        [ 'CopyrightStatus' => 'public' ],
        [ 'Custom1-en' => 'a' ],
        [ 'Custom1-en' => 'b' ],
        [ 'ATestTag' => "http://www.exiftool.ca/t/$testname.t#$testnum-one" ],
        [ 'ATestTag' => "http://www.exiftool.ca/t/$testname.t#$testnum-two" ],
    );
    $exifTool->SetNewValue(@$_) foreach @writeInfo;
    my $ok = writeInfo($exifTool, undef, $testfile);
    print 'not ' unless testCompare("t/XMP_$testnum.out",$testfile,$testnum) and $ok;
    print "ok $testnum\n";
}

# test 27: Extract information from exiftool RDF/XML output file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/XMP.xml', {Duplicates => 1});
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 28: Write information to exiftool RDF/XML output file
{
    ++$testnum;
    my @writeInfo = (
        [ 'all' => undef ],
        [ 'ifd0:all' => undef, Replace => 2 ],
        [ 'XML-file:all' => undef, Replace => 2 ],
        [ 'author' => 'Phil' ],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/XMP.xml');
    print "ok $testnum\n";
}

# test 29: Rewrite extended XMP segment
{
    ++$testnum;
    my @writeInfo = ( [ 'author' => 'Test' ] );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/ExtendedXMP.jpg');
    print "ok $testnum\n";
}

# test 30: Test mass copy with deletion of specific XMP family 1 groups in shorthand format
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(XMPShorthand => 1);
    my $testfile = "t/${testname}_${testnum}_failed.out";
    unlink $testfile;
    $exifTool->SetNewValuesFromFile('t/images/XMP.jpg');
    $exifTool->SetNewValue('xmp-exif:all');
    $exifTool->SetNewValue('XMP-TIFF:*');
    $exifTool->WriteInfo(undef,$testfile,'XMP'); #(also test output file type option)
    print 'not ' unless testCompare("t/XMP_$testnum.out",$testfile,$testnum);
    print "ok $testnum\n";
}

# test 31: Extract structured information
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/XMP4.xmp', {Struct => 1});
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# tests 32-34: Conditionally add XMP lang-alt tag
{
    # write title only if it doesn't exist
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile;
    $exifTool->SetNewValue('XMP-dc:Title-de' => '', DelValue => 1);
    $exifTool->SetNewValue('XMP-dc:Title-de' => 'A');
    my $ok = writeInfo($exifTool,'t/images/Writer.jpg',$testfile);
    my $info = $exifTool->ImageInfo($testfile,'XMP:*');
    print 'not ' unless check($exifTool, $info, $testname, $testnum) and $ok;
    print "ok $testnum\n";
    
    # try again when title already exists
    ++$testnum;
    my $testfile2 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile2;
    $exifTool->SetNewValue('XMP-dc:Title-de' => 'B');
    $exifTool->WriteInfo($testfile,$testfile2);
    $info = $exifTool->ImageInfo($testfile2,'XMP:*');
    if (check($exifTool, $info, $testname, $testnum, 32)) {
        unlink $testfile2
    } else {
        print 'not ';
    }
    print "ok $testnum\n";

    # one final time replacing an existing title
    ++$testnum;
    $testfile2 = "t/${testname}_${testnum}_failed.jpg";
    unlink $testfile2;
    $exifTool->SetNewValue('XMP-dc:Title-de' => 'A', DelValue => 1);
    $exifTool->SetNewValue('XMP-dc:Title-de' => 'C');
    $ok = writeInfo($exifTool,$testfile,$testfile2);
    $info = $exifTool->ImageInfo($testfile2,'XMP:*');
    if (check($exifTool, $info, $testname, $testnum) and $ok) {
        unlink $testfile;
        unlink $testfile2
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 35: Test various features of writing structured information
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    my @writeInfo = (
        # write as flattened string
        [ HierarchicalKeywords => '{keyWORD=A-1,childREN={keyword=A-2}}' ],
        # write as HASH reference
        [ HierarchicalKeywords => [{kEyWoRd=>'B-1', cHiLdReN=>{keyword=>'B-2'}},{keyword=>'C-1'}] ],
        # write a type'd structure
        [ licensee => {licenseename=>'Phil'} ],
        # write a region, including a 'seeAlso' resource
        [ 'RegionList', {
            Area => {X=>0,Y=>0,W=>8,H=>8},
            Name => 'Region 1',
            type => 'Face',
            seeAlso => 'plus:Licensee',
        }],
        # write alternate language structure elements
        [ ArtworkOrObject => "{AOTitle=test,aotitle-de=pr\xc3\xbcfung,AOTitle_FR=\xc3\xa9preuve}" ],
        # disable print conversion for a single structure element
        [ 'XMP:Flash' => '{Return=no,mode#=2}' ],
        # write a complex user-defined lang-alt structure
        [ BTestTag => "{Field1-en-CA=[eh?],Field1-en-US=[huh?,groovy],Field1-fr=[,ing\xc3\xa9nieux]}" ],
        # write some dynamic structure elements
        [ RegionList => { Extensions => {
            # may mix-and-match flattened and structured tags when writing!...
           'XMP-exif:FlashReturn' => 'not', # flattened tag with group name
            Flash => { 'Mode#' => 1 },      # structured tag with disabled conversion
           'UsageTerms-fr' => 'libre',      # lang-alt tag
           'ArtworkTitle-de' => "verf\xc3\xa4nglich", # renamed lang-alt tag in a list
            Renamed => 'this is wild',      # user-defined renamed flattened tag with TYPE
        }}],
    );
    $exifTool->SetNewValue(@$_) foreach @writeInfo;
    my $ok = writeInfo($exifTool,undef,$testfile);
    print 'not ' unless testCompare("t/images/XMP5.xmp",$testfile,$testnum) and $ok;
    print "ok $testnum\n";
}

# tests 36-37: Test reading structures with and without the Struct option
{
    my $i;
    for ($i=0; $i<2; ++$i) {
        ++$testnum;
        my $exifTool = new Image::ExifTool;
        $exifTool->Options(Struct => 1 - $i);
        $exifTool->Options(Escape => 'HTML');   # test escaping of structure fields too
        my $info = $exifTool->ImageInfo("t/images/XMP5.xmp");
        print 'not ' unless check($exifTool, $info, $testname, $testnum);
        print "ok $testnum\n";
    }
}

# test 38: Copy complex structured information
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    $exifTool->SetNewValuesFromFile('t/images/XMP5.xmp', 'xmp:all');
    my $ok = writeInfo($exifTool,undef,$testfile);
    print 'not ' unless testCompare("t/images/XMP5.xmp",$testfile,$testnum) and $ok;
    print "ok $testnum\n";
}

# test 39: Extract information from an INX file
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/XMP.inx', {Duplicates => 1});
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 40: Copy by flattened tag name and structure at the same time
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    $exifTool->SetNewValuesFromFile('t/images/XMP5.xmp', 'HierarchicalKeywords1', 'Licensee');
    my $ok = writeInfo($exifTool,undef,$testfile);
    my $info = $exifTool->ImageInfo($testfile, 'XMP:*');
    if (check($exifTool, $info, $testname, $testnum) and $ok) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 41: Rest writing/reading all DarwinCore tags
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    $exifTool->SetNewValue('xmp-dwc:*' => 2013);
    my $ok = writeInfo($exifTool, undef, $testfile);
    my $info = $exifTool->ImageInfo($testfile, {Duplicates => 1});
    if (check($exifTool, $info, $testname, $testnum) and $ok) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# test 42: Read extended XMP
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/ExtendedXMP.jpg', 'xmp:all');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 43: Read XMP with unusual namespace prefixes
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/XMP6.xmp', 'xmp:all');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 44: Write XMP with unusual namespace prefixes
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    $exifTool->SetNewValue('xmp-dc:subject' => 'changed');
    $exifTool->WriteInfo("t/images/XMP6.xmp", $testfile);
    my $err = $exifTool->GetValue('Error');
    warn "\n  $err\n" if $err;
    print 'not ' unless testCompare("t/XMP_$testnum.out",$testfile,$testnum);
    print "ok $testnum\n";
}

# test 45: Write empty structures
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    $exifTool->SetNewValue('regioninfo' => '{RegionList=[,]}');
    $exifTool->SetNewValue('xmp:flash' => '{}');
    $exifTool->WriteInfo(undef, $testfile);
    print 'not ' unless testCompare("t/XMP_$testnum.out",$testfile,$testnum);
    print "ok $testnum\n";
}

# test 46: Test the advanced-formatting '@' feature on an XMP:Subject list
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(ListSplit => ', ');
    my $cpy = 'subject<${subject@;/^Test/ ? $_=undef : s/Tool$//}';
    $exifTool->SetNewValuesFromFile('t/images/XMP.jpg', $cpy);
    $testfile = "t/${testname}_${testnum}_failed.xmp";
    unlink $testfile;
    writeInfo($exifTool, undef, $testfile);
    $exifTool->Options(ListSep => ' // ');
    my $info = $exifTool->ImageInfo($testfile, 'Subject');
    if (check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        print 'not ';
    }
    print "ok $testnum\n";
}

# end
