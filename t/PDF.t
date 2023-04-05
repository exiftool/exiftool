# Before "make install", this script should be runnable with "make test".
# After "make install" it should work as "perl t/PDF.t".

BEGIN {
    $| = 1; print "1..26\n"; $Image::ExifTool::configFile = '';
    require './t/TestLib.pm'; t::TestLib->import();
}
END {print "not ok 1\n" unless $loaded;}

# test 1: Load the module(s)
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::PDF;
$loaded = 1;
print "ok 1\n";

my $testname = 'PDF';
my $testnum = 1;

#------------------------------------------------------------------------------
# PDF decryption test
# Inputs: 0) Encrypt object reference, plus additional entries (see below),
#         1) Test number, 2) encrypt flag (false for decryption)
# Returns: nothing, but prints test result
# Additional encrypt hash entries used by this routine:
#   _id  - PDF file ID
#   _ref - PDF object reference string
#   _req - other module required for this test
#   _ciphertext - encrypted data
#   _plaintext  - expected decryption result
#   _password   - password for decryption (if used)
sub CryptTest($$;$)
{
    my ($cryptInfo, $testNum, $encrypt) = @_;
    my $skip = '';
    if (eval "require $$cryptInfo{_req}") {
        my $exifTool = Image::ExifTool->new;
        $exifTool->Options('Password', $$cryptInfo{_password});
        my $err = Image::ExifTool::PDF::DecryptInit($exifTool, $cryptInfo, $$cryptInfo{_id});
        unless ($err) {
            my $data = $$cryptInfo{$encrypt ? '_plaintext' : '_ciphertext'};
            Image::ExifTool::PDF::Crypt(\$data, $$cryptInfo{_ref} || '1 0 R', $encrypt);
            $err = $$cryptInfo{_error};
            if (not $err and $data ne $$cryptInfo{$encrypt ? '_ciphertext' : '_plaintext'}) {
                $err = "Test $testnum (decryption) returned wrong value:\n    " . unpack('H*',$data);
            }
        }
        if ($err) {
            warn "\n  $err\n";
            notOK();
        }
    } else {
        $skip = " # skip Requires $$cryptInfo{_req}";
    }
    print "ok $testnum$skip\n";
}

# test 2: Extract information from PDF.pdf
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $info = $exifTool->ImageInfo('t/images/PDF.pdf');
    notOK() unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Test Standard PDF decryption
{
    ++$testnum;
    my %cryptInfo = (
        Filter => '/Standard',
        P => -60,
        V => 1,
        R => 0,
        O => '<2055c756c72e1ad702608e8196acad447ad32d17cff583235f6dd15fed7dab67>',
        U => '<7150bd1da9d292af3627fca6a8dde1d696e25312041aed09059f9daee04353ae>',
        _id => pack('H*','12116a1a124ae4cd8179e8978f6ac88b'),
        _req => 'Digest::MD5',
        _ref => '4 0 R',
        _ciphertext => pack('N', 0x34a290d3),
        _plaintext => pack('N', 0x5924d335),
    );
    CryptTest(\%cryptInfo, $testNum);
}

# tests 4-21: Test writing, deleting and reverting two different files
{
    # do a bunch of edits
    my @edits = ([  # (on file containing both PDF Info and XMP)
        [   # test 4: write PDF and XMP information
            [ 'PDF:Creator' => 'me'],
            [ 'XMP:Creator' => 'you' ],
            [ 'AllDates'    => '2:30', Shift => -1 ],
        ],[ # test 5: delete all PDF
            [ 'PDF:all' ],
        ],[ # test 6: write some XMP
            [ 'XMP:Author' => 'them' ],
        ],[ # test 7: create new PDF
            [ 'PDF:Keywords'  => 'one' ],
            [ 'PDF:Keywords'  => 'two' ],
            [ 'AppleKeywords' => 'three' ],
            [ 'AppleKeywords' => 'four' ],
        ],[ # test 8: delete all XMP
            [ 'XMP:all' ],
        ],[ # test 9: write some PDF
            [ 'PDF:Keywords'  => 'another one', AddValue => 1 ],
            [ 'AppleKeywords' => 'three',       DelValue => 1 ],
        ],[ # test 10: create new XMP
            [ 'XMP:Author' => 'us' ],
        ],[ # test 11: write some PDF
            [ 'PDF:Keywords'  => 'two',  DelValue => 1 ],
            [ 'AppleKeywords' => 'five', AddValue => 1 ],
        ],[ # test 12: delete re-added XMP
            [ 'XMP:all' ],
        ],
    ],[             # (on file without PDF Info or XMP)
        [   # test 14: create new XMP
            [ 'XMP:Author' => 'him' ],
        ],[ # test 15: create new PDF
            [ 'PDF:Author' => 'her' ],
        ],[ # test 16: delete XMP and PDF
            [ 'XMP:all' ],
            [ 'PDF:all' ],
        ],[ # test 17: delete XMP and PDF again
            [ 'XMP:all' ],
            [ 'PDF:all' ],
        ],[ # test 18: create new PDF
            [ 'PDF:Author' => 'it' ],
        ],[ # test 19: create new XMP
            [ 'XMP:Author' => 'thing' ],
        ],[ # test 20: delete all
            [ 'all' ],
        ],
    ]);
    my $testSet;
    foreach $testSet (0,1) {
        my ($edit, $testfile2, $lastOK);
        my $testfile = 't/images/' . ($testSet ? 'PDF2.pdf' : 'PDF.pdf');
        my $testfile1 = $testfile;
        my $exifTool = Image::ExifTool->new;
        $exifTool->Options(PrintConv => 0);
        foreach $edit (@{$edits[$testSet]}) {
            ++$testnum;
            $exifTool->SetNewValue();
            $exifTool->SetNewValue(@$_) foreach @$edit;
            $testfile2 = "t/${testname}_${testnum}_failed.pdf";
            unlink $testfile2;
            $exifTool->WriteInfo($testfile1, $testfile2);
            my $info = $exifTool->ImageInfo($testfile2,
                    qw{Filesize PDF:all XMP:Creator XMP:Author AllDates});
            my $ok = check($exifTool, $info, $testname, $testnum);
            notOK() unless $ok;
            print "ok $testnum\n";
            # erase source file if previous test was OK
            unlink $testfile1 if $lastOK;
            $lastOK = $ok;
            $testfile1 = $testfile2;    # use this file for the next test
        }
        # revert all edits and compare with original file
        ++$testnum;
        $exifTool->SetNewValue('PDF-update:all');
        $testfile2 = "t/${testname}_${testnum}_failed.pdf";
        unlink $testfile2;
        $exifTool->WriteInfo($testfile1, $testfile2);
        if (binaryCompare($testfile2, $testfile)) {
            unlink $testfile2;
        } else {
            notOK();
        }
        print "ok $testnum\n";
        unlink $testfile1 if $lastOK;
    }
}

# test 22: Delete all tags
{
    ++$testnum;
    my $exifTool = Image::ExifTool->new;
    my $testfile = "t/${testname}_${testnum}_failed.pdf";
    unlink $testfile;
    $exifTool->Options(IgnoreMinorErrors => 1);
    $exifTool->SetNewValue(all => undef);
    my $ok = writeInfo($exifTool, 't/images/PDF.pdf', $testfile);
    $exifTool->Options(IgnoreMinorErrors => 0);
    my $info = $exifTool->ImageInfo($testfile,'pdf:all','xmp:all',{Duplicates=>1,Unknown=>1});
    if ($ok and check($exifTool, $info, $testname, $testnum)) {
        unlink $testfile;
    } else {
        notOK();
    }
    print "ok $testnum\n";
}

# test 23: Test AES decryption alone (tests 24-26 require Digest::MD5 or Digest::SHA)
{
    ++$testnum;
    require Image::ExifTool::AES;
    my $data = pack('H*','6fdc3ca684348bc8f31379aa46455d7b60c0989e027c1d82e746f136d6e95b7485735793ff64310e5b9e367dcc26f564');
    my $err = Image::ExifTool::AES::Crypt(\$data, '11223344556677889900112233445566');
    if ($err) {
        warn "\n  $err\n";
        notOK();
    } elsif ($data ne 'ExifTool AES Test') {
        my $hex = unpack 'H*', $data;
        warn "\n  Incorrect result from AES decryption:\n";
        warn "    $hex\n";
        notOK();
    }
    print "ok $testnum\n";
}

# test 24-26: Test AESV2 and AESV3 decryption
{
    my @encrypt = (
    # AESV2 without password
    {
        Filter => '/Standard',
        V => 4,
        R => 4,
        P => -1340,
        Length => 128,
        StmF => '/StdCF',
        StrF => '/StdCF',
        CF => {
            StdCF => {
                AuthEvent => '/DocOpen',
                CFM => '/AESV2',
                Length => 16,
            },
        },
        EncryptMetadata => 'false',
        O => '<181ee8e93a99fa1c2a534dd68a5ab07c54268cfe8fbf28c468316b6f732674c1>',
        U => '<a3525aef4143f4419c78b109317f0e5200000000000000000000000000000000>',
        _req => 'Digest::MD5',
        _ref => '4 0 R',
        _id => pack('H*','d0a736f05faf64c6b52dea82a2ad53e0'),
        _plaintext => 'This was a test',
        _ciphertext => pack('H*', 'a86b5e00d9c7e4455cf5d8cedf195c2060e1467ea6d698876a77e9a66cb7867c'),
    },
    # AESV3 without password
    {
        Filter => '/Standard',
        V => 5,
        R => 5,
        P => -1028,
        Length => 256,
        StmF => '/StdCF',
        StrF => '/StdCF',
        CF => {
            StdCF => {
                AuthEvent => '/DocOpen',
                CFM => '/AESV3',
                Length => 32,
            },
        },
        Perms => '<014ee28fe2b91e2198a593b7c3b22f50>',
        O => '<83e5edfcdecbe2ebe6d519dbafe80fd453028dda119eb76d0216e1344392320d60e1467ea6d698876a77e9a66cb7867c>',
        U => '<e5e7ade8aebdc9413a0fd176efc4081bdbad3b16a67ece7a01fadb24010a003ea86b5e00d9c7e4455cf5d8cedf195c20>',
        OE => '<a29f37f1f085b575d9016daad05ca466dd073ba5d067cc7ffa8ef7d1605e460e>',
        UE => '<47ea891b25af77aaceccf8f2fdeff0c09e9d0f67275f059dbfabbb18fcbf848d>',
        _req => 'Digest::SHA',
        _ref => 'dummy',
        _id => pack('H*','618cb5be1d82fceea9a501b62d408296'),
        _plaintext => 'This was a test',
        _ciphertext => pack('H*', 'e90756e8fd60fb7390c34d931e3e3d61898cd133e613e8cf86cd40f7b207a62d'),
    },
    # AESV3 with a password
    {
        Filter => '/Standard',
        V => 5,
        R => 5,
        P => -1028,
        Length => 256,
        StmF => '/StdCF',
        StrF => '/StdCF',
        CF => {
            StdCF => {
                AuthEvent => '/DocOpen',
                CFM => '/AESV3',
                Length => 32,
            },
        },
        Perms => '<014ee28fe2b91e2198a593b7c3b22f50>',
        O => '<31eefe924a298d8bf19eafc9be6abdfa65a97478f94e907dccff5ac000b83fa521167b86cf70bf77d4a054bc9a59573d>',
        U => '<6525a788c2ebf27baa45f526bcdb9d2f96c3c67ae1c62324135cac0b823451ba9ad8edb68d167d2d8370d799c41d17d7>',
        OE => '<ea58e3c731999cdc0f8a395c7391836c2b2db0b4ac86439b3fe5692ddc71671a>',
        UE => '<f6818f43e176dfe8912f62717032169cf48854f540f7b7641be363ef50371f07>',
        _req => 'Digest::SHA',
        _ref => 'dummy',
        _id => pack('H*','b5f9d17b07152a45bc0a939727c389ad'),
        _plaintext => 'This was a test',
        _password => 'ExifTool',
        _ciphertext => pack('H*', '8bb3565d8c4b9df8cc350954d9f91a46aa47e40eeb5a0cff559acd5ec3e94244'),
    });
    my $exifTool = Image::ExifTool->new;
    my $cryptInfo;
    foreach $cryptInfo (@encrypt) {
        ++$testnum;
        my $encrypt = 0;    # (set to 1 to generate ciphertext strings)
        CryptTest($cryptInfo, $testNum, $encrypt);
    }
}

done(); # end
