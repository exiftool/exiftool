#------------------------------------------------------------------------------
# File:         AES.pm
#
# Description:  AES encryption with cipher-block chaining
#
# Revisions:    2010/10/14 - P. Harvey Created
#
# References:   1) http://www.hoozi.com/Articles/AESEncryption.htm
#               2) http://www.csrc.nist.gov/publications/fips/fips197/fips-197.pdf
#               3) http://www.faqs.org/rfcs/rfc3602.html
#------------------------------------------------------------------------------

package Image::ExifTool::AES;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK);
require Exporter;

$VERSION = '1.01';
@ISA = qw(Exporter);
@EXPORT_OK = qw(Crypt);

my $seeded; # flag set if we already seeded random number generator
my $nr;     # number of rounds in AES cipher
my @cbc;    # cipher-block chaining bytes

# arrays (all unsigned character) to hold intermediate results during encryption
my @state = ([],[],[],[]);  # the 2-dimensional state array
my @RoundKey;               # round keys

my @sbox = (
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
);

# reverse sbox
my @rsbox = (
    0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb,
    0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb,
    0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,
    0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25,
    0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92,
    0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,
    0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06,
    0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b,
    0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,
    0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e,
    0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b,
    0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4,
    0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f,
    0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef,
    0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61,
    0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d,
);

# the round constant word array, $rcon[i], contains the values given by
# x to the power (i-1) being powers of x (x is denoted as {02}) in the field GF(2^8)
# Note that i starts at 1, not 0).
my @rcon = (
    0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a,
    0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39,
    0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a,
    0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8,
    0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef,
    0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc,
    0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b,
    0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3,
    0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94,
    0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20,
    0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63, 0xc6, 0x97, 0x35,
    0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd, 0x61, 0xc2, 0x9f,
    0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb, 0x8d, 0x01, 0x02, 0x04,
    0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36, 0x6c, 0xd8, 0xab, 0x4d, 0x9a, 0x2f, 0x5e, 0xbc, 0x63,
    0xc6, 0x97, 0x35, 0x6a, 0xd4, 0xb3, 0x7d, 0xfa, 0xef, 0xc5, 0x91, 0x39, 0x72, 0xe4, 0xd3, 0xbd,
    0x61, 0xc2, 0x9f, 0x25, 0x4a, 0x94, 0x33, 0x66, 0xcc, 0x83, 0x1d, 0x3a, 0x74, 0xe8, 0xcb,
);

#------------------------------------------------------------------------------
# This function produces 4*($nr+1) round keys.
# The round keys are used in each round to encrypt the states.
# Inputs: 0) key string (must be 16, 24 or 32 bytes long)
sub KeyExpansion($)
{
    my $key = shift;
    my @key = unpack 'C*', $key;        # convert the key into a byte array
    my $nk = int(length($key) / 4);     # number of 32-bit words in the key
    $nr = $nk + 6;                      # number of rounds

    # temporary variables (all unsigned characters)
    my ($i,@temp);

    # The first round key is the key itself.
    for ($i=0; $i<$nk; ++$i) {
        @RoundKey[$i*4..$i*4+3] = @key[$i*4..$i*4+3];
    }
    # All other round keys are found from the previous round keys.
    while ($i < (4 * ($nr+1))) {

        @temp[0..3] = @RoundKey[($i-1)*4..($i-1)*4+3];

        if ($i % $nk == 0) {
            # rotate the 4 bytes in a word to the left once
            # [a0,a1,a2,a3] becomes [a1,a2,a3,a0]
            @temp[0..3] = @temp[1,2,3,0];

            # take a four-byte input word and apply the S-box
            # to each of the four bytes to produce an output word.
            @temp[0..3] = @sbox[@temp[0..3]];

            $temp[0] = $temp[0] ^ $rcon[$i/$nk];

        } elsif ($nk > 6 && $i % $nk == 4) {

            @temp[0..3] = @sbox[@temp[0..3]];
        }
        $RoundKey[$i*4+0] = $RoundKey[($i-$nk)*4+0] ^ $temp[0];
        $RoundKey[$i*4+1] = $RoundKey[($i-$nk)*4+1] ^ $temp[1];
        $RoundKey[$i*4+2] = $RoundKey[($i-$nk)*4+2] ^ $temp[2];
        $RoundKey[$i*4+3] = $RoundKey[($i-$nk)*4+3] ^ $temp[3];
        ++$i;
    }
}

#------------------------------------------------------------------------------
# This function adds the round key to state.
# The round key is added to the state by an XOR function.
sub AddRoundKey($)
{
    my $round = shift;
    my ($i,$j);
    for ($i=0; $i<4; ++$i) {
        my $k = $round*16 + $i*4;
        for ($j=0; $j<4; ++$j) {
            $state[$j][$i] ^= $RoundKey[$k + $j];
        }
    }
}

#------------------------------------------------------------------------------
# Substitute the values in the state matrix with values in an S-box
sub SubBytes()
{
    my $i;
    for ($i=0; $i<4; ++$i) {
        @{$state[$i]}[0..3] = @sbox[@{$state[$i]}[0..3]];
    }
}

sub InvSubBytes()
{
    my $i;
    for ($i=0; $i<4; ++$i) {
        @{$state[$i]}[0..3] = @rsbox[@{$state[$i]}[0..3]];
    }
}

#------------------------------------------------------------------------------
# Shift the rows in the state to the left.
# Each row is shifted with different offset.
# Offset = Row number. So the first row is not shifted.
sub ShiftRows()
{
    # rotate first row 1 columns to left
    @{$state[1]}[0,1,2,3] = @{$state[1]}[1,2,3,0];

    # rotate second row 2 columns to left
    @{$state[2]}[0,1,2,3] = @{$state[2]}[2,3,0,1];

    # rotate third row 3 columns to left
    @{$state[3]}[0,1,2,3] = @{$state[3]}[3,0,1,2];
}

sub InvShiftRows()
{
    # rotate first row 1 columns to right
    @{$state[1]}[0,1,2,3] = @{$state[1]}[3,0,1,2];

    # rotate second row 2 columns to right
    @{$state[2]}[0,1,2,3] = @{$state[2]}[2,3,0,1];

    # rotate third row 3 columns to right
    @{$state[3]}[0,1,2,3] = @{$state[3]}[1,2,3,0];
}

#------------------------------------------------------------------------------
# Find the product of {02} and the argument to xtime modulo 0x1b
# Note: returns an integer which may need to be trimmed to 8 bits
sub xtime($)
{
    return ($_[0]<<1) ^ ((($_[0]>>7) & 1) * 0x1b);
}

#------------------------------------------------------------------------------
# Multiply numbers in the field GF(2^8)
sub Mult($$)
{
    my ($x, $y) = @_;
    return (($y & 1) * $x) ^
           (($y>>1 & 1) * xtime($x)) ^
           (($y>>2 & 1) * xtime(xtime($x))) ^
           (($y>>3 & 1) * xtime(xtime(xtime($x)))) ^
           (($y>>4 & 1) * xtime(xtime(xtime(xtime($x)))));
}

#------------------------------------------------------------------------------
# Mix the columns of the state matrix
sub MixColumns()
{
    my ($i,$t0,$t1,$t2);
    for ($i=0; $i<4; ++$i) {
        $t0 = $state[0][$i];
        $t2 = $state[0][$i] ^ $state[1][$i] ^ $state[2][$i] ^ $state[3][$i];
        $t1 = $state[0][$i] ^ $state[1][$i] ; $t1 = xtime($t1) & 0xff; $state[0][$i] ^= $t1 ^ $t2 ;
        $t1 = $state[1][$i] ^ $state[2][$i] ; $t1 = xtime($t1) & 0xff; $state[1][$i] ^= $t1 ^ $t2 ;
        $t1 = $state[2][$i] ^ $state[3][$i] ; $t1 = xtime($t1) & 0xff; $state[2][$i] ^= $t1 ^ $t2 ;
        $t1 = $state[3][$i] ^ $t0 ;           $t1 = xtime($t1) & 0xff; $state[3][$i] ^= $t1 ^ $t2 ;
    }
}

sub InvMixColumns()
{
    my $i;
    for ($i=0; $i<4; ++$i) {
        my $a = $state[0][$i];
        my $b = $state[1][$i];
        my $c = $state[2][$i];
        my $d = $state[3][$i];
        $state[0][$i] = (Mult($a,0x0e) ^ Mult($b,0x0b) ^ Mult($c,0x0d) ^ Mult($d,0x09)) & 0xff;
        $state[1][$i] = (Mult($a,0x09) ^ Mult($b,0x0e) ^ Mult($c,0x0b) ^ Mult($d,0x0d)) & 0xff;
        $state[2][$i] = (Mult($a,0x0d) ^ Mult($b,0x09) ^ Mult($c,0x0e) ^ Mult($d,0x0b)) & 0xff;
        $state[3][$i] = (Mult($a,0x0b) ^ Mult($b,0x0d) ^ Mult($c,0x09) ^ Mult($d,0x0e)) & 0xff;
    }
}

#------------------------------------------------------------------------------
# Encrypt (Cipher) or decrypt (InvCipher) a block of data with CBC
# Inputs: 0) string to cipher (must be 16 bytes long)
# Returns: cipher'd string
sub Cipher($)
{
    my @in = unpack 'C*', $_[0];    # unpack input plaintext
    my ($i, $j, $round);

    # copy the input PlainText to state array and apply the CBC
    for ($i=0; $i<4; ++$i) {
        for ($j=0; $j<4; ++$j) {
            my $k = $i*4 + $j;
            $state[$j][$i] = $in[$k] ^ $cbc[$k];
        }
    }

    # add the First round key to the state before starting the rounds
    AddRoundKey(0);

    # there will be $nr rounds; the first $nr-1 rounds are identical
    for ($round=1; ; ++$round) {
        SubBytes();
        ShiftRows();
        if ($round < $nr) {
            MixColumns();
            AddRoundKey($round);
        } else {
            # MixColumns() is not used in the last round
            AddRoundKey($nr);
            last;
        }
    }

    # the encryption process is over
    # copy the state array to output array (and save for CBC)
    for ($i=0; $i<4; ++$i) {
        for ($j=0; $j<4; ++$j) {
            $cbc[$i*4+$j] = $state[$j][$i];
        }
    }
    return pack 'C*', @cbc; # return packed ciphertext
}

sub InvCipher($)
{
    my @in = unpack 'C*', $_[0];    # unpack input ciphertext
    my (@out, $i, $j, $round);

    # copy the input CipherText to state array
    for ($i=0; $i<4; ++$i) {
        for ($j=0; $j<4; ++$j) {
            $state[$j][$i] = $in[$i*4 + $j];
        }
    }

    # add the First round key to the state before starting the rounds
    AddRoundKey($nr);

    # there will be $nr rounds; the first $nr-1 rounds are identical
    for ($round=$nr-1; ; --$round) {
        InvShiftRows();
        InvSubBytes();
        AddRoundKey($round);
        # InvMixColumns() is not used in the last round
        last if $round <= 0;
        InvMixColumns();
    }

    # copy the state array to output array and reverse the CBC
    for ($i=0; $i<4; ++$i) {
        for ($j=0; $j<4; ++$j) {
            my $k = $i*4 + $j;
            $out[$k] = $state[$j][$i] ^ $cbc[$k];
        }
    }
    @cbc = @in;             # update CBC for next block
    return pack 'C*', @out; # return packed plaintext
}

#------------------------------------------------------------------------------
# Encrypt/Decrypt using AES-CBC algorithm (with fixed 16-byte blocks)
# Inputs: 0) data reference (with leading 16-byte initialization vector when decrypting)
#         1) encryption key (16, 24 or 32 bytes for AES-128, AES-192 or AES-256)
#         2) encrypt flag (false for decryption, true with length 16 bytes to
#            encrypt using this as the CBC IV, or true with other length to
#            encrypt with a randomly-generated IV)
#         3) flag to disable padding
# Returns: error string, or undef on success
# Notes: encrypts/decrypts data in place (encrypted data returned with leading IV)
sub Crypt($$;$$)
{
    my ($dataPt, $key, $encrypt, $noPad) = @_;

    # validate key length
    my $keyLen = length $key;
    unless ($keyLen == 16 or $keyLen == 24 or $keyLen == 32) {
        return "Invalid AES key length ($keyLen)";
    }
    my $partLen = length($$dataPt) % 16;
    my ($pos, $i);
    if ($encrypt) {
        if (length($encrypt) == 16) {
            @cbc = unpack 'C*', $encrypt;
        } else {
            # generate a random 16-byte CBC initialization vector
            unless ($seeded) {
                srand(time() & ($$ + ($$<<15)));
                $seeded = 1;
            }
            for ($i=0; $i<16; ++$i) {
                $cbc[$i] = int(rand(256));
            }
            $encrypt = pack 'C*', @cbc;
        }
        $$dataPt = $encrypt . $$dataPt; # add IV to the start of the data
        # add required padding so we can recover the
        # original string length after decryption
        # (padding bytes have value set to padding length)
        my $padLen = 16 - $partLen;
        $$dataPt .= (chr($padLen)) x $padLen unless $padLen == 16 and $noPad;
        $pos = 16;      # start encrypting at byte 16 (after the IV)
    } elsif ($partLen) {
        return 'Invalid AES ciphertext length';
    } elsif (length $$dataPt >= 32) {
        # take the CBC initialization vector from the start of the data
        @cbc = unpack 'C16', $$dataPt;
        $$dataPt = substr($$dataPt, 16);
        $pos = 0;       # start decrypting from byte 0 (now that IV is removed)
    } else {
        $$dataPt = '';  # empty text
        return undef;
    }
    # the KeyExpansion routine must be called before encryption
    KeyExpansion($key);

    # loop through the data and convert in blocks
    my $dataLen = length $$dataPt;
    my $last = $dataLen - 16;
    my $func = $encrypt ? \&Cipher : \&InvCipher;
    while ($pos <= $last) {
        # cipher this block
        substr($$dataPt, $pos, 16) = &$func(substr($$dataPt, $pos, 16));
        $pos += 16;
    }
    unless ($encrypt or $noPad) {
        # remove padding if necessary (padding byte value gives length of padding)
        my $padLen = ord(substr($$dataPt, -1, 1));
        return 'AES decryption error (invalid pad byte)' if $padLen > 16;
        $$dataPt = substr($$dataPt, 0, $dataLen - $padLen);
    }
    return undef;
}

1; # end


__END__

=head1 NAME

Image::ExifTool::AES - AES encryption with cipher-block chaining

=head1 SYNOPSIS

  use Image::ExifTool::AES qw(Crypt);

  $err = Crypt(\$plaintext, $key, 1);   # encryption

  $err = Crypt(\$ciphertext, $key);     # decryption

=head1 DESCRIPTION

This module contains an implementation of the AES encryption/decryption
algorithms with cipher-block chaining (CBC) and RFC 2898 PKCS #5 padding.
This is the AESV2 and AESV3 encryption mode used in PDF documents.

=head1 EXPORTS

Exports nothing by default, but L</Crypt> may be exported.

=head1 METHODS

=head2 Crypt

Implement AES encryption/decryption with cipher-block chaining.

=over 4

=item Inputs:

0) Scalar reference for data to encrypt/decrypt.

1) Encryption key string (must have length 16, 24 or 32).

2) [optional] Encrypt flag (false to decrypt).

3) [optional] Flag to avoid removing padding after decrypting, or to avoid
adding 16 bytes of padding before encrypting when data length is already a
multiple of 16 bytes.

=item Returns:

On success, the return value is undefined and the data is encrypted or
decrypted as specified.  Otherwise returns an error string and the data is
left in an indeterminate state.

=item Notes:

The length of the encryption key dictates the AES mode, with lengths of 16,
24 and 32 bytes resulting in AES-128, AES-192 and AES-256.

When encrypting, the input data may be any length and will be padded to an
even 16-byte block size using the specified padding technique.  If the
encrypt flag has length 16, it is used as the initialization vector for
the cipher-block chaining, otherwise a random IV is generated.  Upon
successful return the data will be encrypted, with the first 16 bytes of
the data being the CBC IV.

When decrypting, the input data begins with the 16-byte CBC initialization
vector.

=back

=head1 BUGS

This code is blindingly slow.  But in truth, slowing down processing is the
main purpose of encryption, so this really can't be considered a bug.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.hoozi.com/Articles/AESEncryption.htm>

=item L<http://www.csrc.nist.gov/publications/fips/fips197/fips-197.pdf>

=item L<http://www.faqs.org/rfcs/rfc3602.html>

=back

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
