#------------------------------------------------------------------------------
# File:         BZZ.pm
#
# Description:  Utility to decode BZZ compressed data
#
# Revisions:    09/22/2008 - P. Harvey Created
#
# References:   1) http://djvu.sourceforge.net/
#               2) http://www.djvu.org/
#
# Notes:        This code based on ZPCodec and BSByteStream of DjVuLibre 3.5.21
#               (see NOTES documentation below for license/copyright details)
#------------------------------------------------------------------------------

package Image::ExifTool::BZZ;

use strict;
use integer;    # IMPORTANT!!  use integer arithmetic throughout
require Exporter;
use vars qw($VERSION @ISA @EXPORT_OK);

$VERSION = '1.00';
@ISA = qw(Exporter);
@EXPORT_OK = qw(Decode);

# constants
sub FREQMAX { 4 }
sub CTXIDS  { 3 }
sub MAXBLOCK { 4096 }

# This table has been designed for the ZPCoder
# by running the following command in file 'zptable.sn':
# (fast-crude (steady-mat 0.0035  0.0002) 260)))
my @default_ztable_p = (
    0x8000, 0x8000, 0x8000, 0x6bbd, 0x6bbd, 0x5d45, 0x5d45, 0x51b9, 0x51b9, 0x4813,
    0x4813, 0x3fd5, 0x3fd5, 0x38b1, 0x38b1, 0x3275, 0x3275, 0x2cfd, 0x2cfd, 0x2825,
    0x2825, 0x23ab, 0x23ab, 0x1f87, 0x1f87, 0x1bbb, 0x1bbb, 0x1845, 0x1845, 0x1523,
    0x1523, 0x1253, 0x1253, 0x0fcf, 0x0fcf, 0x0d95, 0x0d95, 0x0b9d, 0x0b9d, 0x09e3,
    0x09e3, 0x0861, 0x0861, 0x0711, 0x0711, 0x05f1, 0x05f1, 0x04f9, 0x04f9, 0x0425,
    0x0425, 0x0371, 0x0371, 0x02d9, 0x02d9, 0x0259, 0x0259, 0x01ed, 0x01ed, 0x0193,
    0x0193, 0x0149, 0x0149, 0x010b, 0x010b, 0x00d5, 0x00d5, 0x00a5, 0x00a5, 0x007b,
    0x007b, 0x0057, 0x0057, 0x003b, 0x003b, 0x0023, 0x0023, 0x0013, 0x0013, 0x0007,
    0x0007, 0x0001, 0x0001, 0x5695, 0x24ee, 0x8000, 0x0d30, 0x481a, 0x0481, 0x3579,
    0x017a, 0x24ef, 0x007b, 0x1978, 0x0028, 0x10ca, 0x000d, 0x0b5d, 0x0034, 0x078a,
    0x00a0, 0x050f, 0x0117, 0x0358, 0x01ea, 0x0234, 0x0144, 0x0173, 0x0234, 0x00f5,
    0x0353, 0x00a1, 0x05c5, 0x011a, 0x03cf, 0x01aa, 0x0285, 0x0286, 0x01ab, 0x03d3,
    0x011a, 0x05c5, 0x00ba, 0x08ad, 0x007a, 0x0ccc, 0x01eb, 0x1302, 0x02e6, 0x1b81,
    0x045e, 0x24ef, 0x0690, 0x2865, 0x09de, 0x3987, 0x0dc8, 0x2c99, 0x10ca, 0x3b5f,
    0x0b5d, 0x5695, 0x078a, 0x8000, 0x050f, 0x24ee, 0x0358, 0x0d30, 0x0234, 0x0481,
    0x0173, 0x017a, 0x00f5, 0x007b, 0x00a1, 0x0028, 0x011a, 0x000d, 0x01aa, 0x0034,
    0x0286, 0x00a0, 0x03d3, 0x0117, 0x05c5, 0x01ea, 0x08ad, 0x0144, 0x0ccc, 0x0234,
    0x1302, 0x0353, 0x1b81, 0x05c5, 0x24ef, 0x03cf, 0x2b74, 0x0285, 0x201d, 0x01ab,
    0x1715, 0x011a, 0x0fb7, 0x00ba, 0x0a67, 0x01eb, 0x06e7, 0x02e6, 0x0496, 0x045e,
    0x030d, 0x0690, 0x0206, 0x09de, 0x0155, 0x0dc8, 0x00e1, 0x2b74, 0x0094, 0x201d,
    0x0188, 0x1715, 0x0252, 0x0fb7, 0x0383, 0x0a67, 0x0547, 0x06e7, 0x07e2, 0x0496,
    0x0bc0, 0x030d, 0x1178, 0x0206, 0x19da, 0x0155, 0x24ef, 0x00e1, 0x320e, 0x0094,
    0x432a, 0x0188, 0x447d, 0x0252, 0x5ece, 0x0383, 0x8000, 0x0547, 0x481a, 0x07e2,
    0x3579, 0x0bc0, 0x24ef, 0x1178, 0x1978, 0x19da, 0x2865, 0x24ef, 0x3987, 0x320e,
    0x2c99, 0x432a, 0x3b5f, 0x447d, 0x5695, 0x5ece, 0x8000, 0x8000, 0x5695, 0x481a,
    0x481a, 0, 0, 0, 0, 0
);
my @default_ztable_m = (
    0x0000, 0x0000, 0x0000, 0x10a5, 0x10a5, 0x1f28, 0x1f28, 0x2bd3, 0x2bd3, 0x36e3,
    0x36e3, 0x408c, 0x408c, 0x48fd, 0x48fd, 0x505d, 0x505d, 0x56d0, 0x56d0, 0x5c71,
    0x5c71, 0x615b, 0x615b, 0x65a5, 0x65a5, 0x6962, 0x6962, 0x6ca2, 0x6ca2, 0x6f74,
    0x6f74, 0x71e6, 0x71e6, 0x7404, 0x7404, 0x75d6, 0x75d6, 0x7768, 0x7768, 0x78c2,
    0x78c2, 0x79ea, 0x79ea, 0x7ae7, 0x7ae7, 0x7bbe, 0x7bbe, 0x7c75, 0x7c75, 0x7d0f,
    0x7d0f, 0x7d91, 0x7d91, 0x7dfe, 0x7dfe, 0x7e5a, 0x7e5a, 0x7ea6, 0x7ea6, 0x7ee6,
    0x7ee6, 0x7f1a, 0x7f1a, 0x7f45, 0x7f45, 0x7f6b, 0x7f6b, 0x7f8d, 0x7f8d, 0x7faa,
    0x7faa, 0x7fc3, 0x7fc3, 0x7fd7, 0x7fd7, 0x7fe7, 0x7fe7, 0x7ff2, 0x7ff2, 0x7ffa,
    0x7ffa, 0x7fff, 0x7fff, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
);
my @default_ztable_up = (
     84,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15,  16,  17,
     18,  19,  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,  30,  31,  32,  33,
     34,  35,  36,  37,  38,  39,  40,  41,  42,  43,  44,  45,  46,  47,  48,  49,
     50,  51,  52,  53,  54,  55,  56,  57,  58,  59,  60,  61,  62,  63,  64,  65,
     66,  67,  68,  69,  70,  71,  72,  73,  74,  75,  76,  77,  78,  79,  80,  81,
     82,  81,  82,   9,  86,   5,  88,  89,  90,  91,  92,  93,  94,  95,  96,  97,
     82,  99,  76, 101,  70, 103,  66, 105, 106, 107,  66, 109,  60, 111,  56,  69,
    114,  65, 116,  61, 118,  57, 120,  53, 122,  49, 124,  43,  72,  39,  60,  33,
     56,  29,  52,  23,  48,  23,  42, 137,  38,  21, 140,  15, 142,   9, 144, 141,
    146, 147, 148, 149, 150, 151, 152, 153, 154, 155,  70, 157,  66,  81,  62,  75,
     58,  69,  54,  65,  50, 167,  44,  65,  40,  59,  34,  55,  30, 175,  24, 177,
    178, 179, 180, 181, 182, 183, 184,  69, 186,  59, 188,  55, 190,  51, 192,  47,
    194,  41, 196,  37, 198, 199,  72, 201,  62, 203,  58, 205,  54, 207,  50, 209,
     46, 211,  40, 213,  36, 215,  30, 217,  26, 219,  20,  71,  14,  61,  14,  57,
      8,  53, 228,  49, 230,  45, 232,  39, 234,  35, 138,  29,  24,  25, 240,  19,
     22,  13,  16,  13,  10,   7, 244, 249,  10,  89, 230, 0, 0, 0, 0, 0
);
my @default_ztable_dn = (
    145,   4,   3,   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,
     14,  15,  16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,  27,  28,  29,
     30,  31,  32,  33,  34,  35,  36,  37,  38,  39,  40,  41,  42,  43,  44,  45,
     46,  47,  48,  49,  50,  51,  52,  53,  54,  55,  56,  57,  58,  59,  60,  61,
     62,  63,  64,  65,  66,  67,  68,  69,  70,  71,  72,  73,  74,  75,  76,  77,
     78,  79,  80,  85, 226,   6, 176, 143, 138, 141, 112, 135, 104, 133, 100, 129,
     98, 127,  72, 125, 102, 123,  60, 121, 110, 119, 108, 117,  54, 115,  48, 113,
    134,  59, 132,  55, 130,  51, 128,  47, 126,  41,  62,  37,  66,  31,  54,  25,
     50, 131,  46,  17,  40,  15, 136,   7,  32, 139, 172,   9, 170,  85, 168, 248,
    166, 247, 164, 197, 162,  95, 160, 173, 158, 165, 156, 161,  60, 159,  56,  71,
     52, 163,  48,  59,  42, 171,  38, 169,  32,  53,  26,  47, 174, 193,  18, 191,
    222, 189, 218, 187, 216, 185, 214,  61, 212,  53, 210,  49, 208,  45, 206,  39,
    204, 195, 202,  31, 200, 243,  64, 239,  56, 237,  52, 235,  48, 233,  44, 231,
     38, 229,  34, 227,  28, 225,  22, 223,  16, 221, 220,  63,   8,  55, 224,  51,
      2,  47,  87,  43, 246,  37, 244,  33, 238,  27, 236,  21,  16,  15,   8, 241,
    242,   7,  10, 245,   2,   1,  83, 250,   2, 143, 246, 0, 0, 0, 0, 0
);

#------------------------------------------------------------------------------
# New - create new BZZ object
# Inputs: 0) reference to BZZ object or BZZ class name
# Returns: blessed BZZ object ref
sub new
{
    local $_;
    my $that = shift;
    my $class = ref($that) || $that || 'Image::ExifTool::BZZ';
    return bless {}, $class;
}

#------------------------------------------------------------------------------
# Initialize BZZ object
# Inputs: 0) BZZ object ref, 1) data ref, 2) true for DjVu compatibility
sub Init($$)
{
    my ($self, $dataPt, $djvucompat) = @_;
    # Create machine independent ffz table
    my $ffzt = $$self{ffzt} = [ ];
    my ($i, $j);
    for ($i=0; $i<256; $i++) {
        $$ffzt[$i] = 0;
        for ($j=$i; $j&0x80; $j<<=1) {
            $$ffzt[$i] += 1;
        }
    }
    # Initialize table
    $$self{p} = [ @default_ztable_p ];
    $$self{'m'} = [ @default_ztable_m ];
    $$self{up} = [ @default_ztable_up ];
    $$self{dn} = [ @default_ztable_dn ];
    # Patch table (and lose DjVu compatibility)
    unless ($djvucompat) {
        my ($p, $m, $dn) = ($$self{p}, $$self{'m'}, $$self{dn});
        for ($j=0; $j<256; $j++) {
            my $a = (0x10000 - $$p[$j]) & 0xffff;
            while ($a >= 0x8000) { $a = ($a<<1) & 0xffff }
            if ($$m[$j]>0 && $a+$$p[$j]>=0x8000 && $a>=$$m[$j]) {
                $$dn[$j] = $default_ztable_dn[$default_ztable_dn[$j]];
            }
        }
    }
    $$self{ctx} = [ (0) x 300 ];
    $$self{DataPt} = $dataPt;
    $$self{Pos} = 0;
    $$self{DataLen} = length $$dataPt;
    $$self{a} = 0;
    $$self{buffer} = 0;
    $$self{fence} = 0;
    $$self{blocksize} = 0;
    # Read first 16 bits of code
    if (length($$dataPt) >= 2) {
        $$self{code} = unpack('n', $$dataPt);
        $$self{Pos} += 2;
    } elsif (length($$dataPt) >= 1) {
        $$self{code} = (unpack('C', $$dataPt) << 8) | 0xff;
        $$self{Pos}++;
    } else {
        $$self{code} = 0xffff;
    }
    $$self{byte} = $$self{code} & 0xff;
    # Preload buffer
    $$self{delay} = 25;
    $$self{scount} = 0;
    # Compute initial fence
    $$self{fence} = $$self{code} >= 0x8000 ? 0x7fff : $$self{code};
}

#------------------------------------------------------------------------------
# Decode data block
# Inputs: 0) optional BZZ object ref, 1) optional data ref
# Returns: decoded data or undefined on error
# Notes: If called without a data ref, an input BZZ object ref must be given and
#        the BZZ object must have been initialized by a previous call to Init()
sub Decode($;$)
{
    # Decode input stream
    local $_;
    my $self;
    if (ref $_[0] and UNIVERSAL::isa($_[0],'Image::ExifTool::BZZ')) {
        $self = shift;
    } else {
        $self = new Image::ExifTool::BZZ;
    }
    my $dataPt = shift;
    if ($dataPt) {
        $self->Init($dataPt, 1);
    } else {
        $dataPt = $$self{DataPt} or return undef;
    }
    # Decode block size
    my $n = 1;
    my $m = (1 << 24);
    while ($n < $m) {
        my $b = $self->decode_sub(0x8000 + ($$self{a}>>1));
        $n = ($n<<1) | $b;
    }
    $$self{size} = $n - $m;

    return '' unless $$self{size};
    return undef if $$self{size} > MAXBLOCK()*1024;
    # Allocate
    if ($$self{blocksize} < $$self{size}) {
        $$self{blocksize} = $$self{size};
    }
    # Decode Estimation Speed
    my $fshift = 0;
    if ($self->decode_sub(0x8000 + ($$self{a}>>1))) {
        $fshift += 1;
        $fshift += 1 if $self->decode_sub(0x8000 + ($$self{a}>>1));
    }
    # Prepare Quasi MTF
    my @mtf = (0..255);
    my @freq = (0) x FREQMAX();
    my $fadd = 4;
    # Decode
    my $mtfno = 3;
    my $markerpos = -1;
    my $cx = $$self{ctx};
    my ($i, @dat);
byte: for ($i=0; $i<$$self{size}; $i++) {
        # dummy loop avoids use of "goto" statement
dummy:  for (;;) {
            my $ctxid = CTXIDS() - 1;
            $ctxid = $mtfno if $ctxid > $mtfno;
            my $cp = 0;
            my ($imtf, $bits);
            for ($imtf=0; $imtf<2; ++$imtf) {
                if ($self->decoder($$cx[$cp+$ctxid])) {
                    $mtfno = $imtf;
                    $dat[$i] = $mtf[$mtfno];
                    # (a "goto" here could give a segfault due to a Perl bug)
                    last dummy; # do rotation
                }
                $cp += CTXIDS();
            }
            for ($bits=1; $bits<8; ++$bits, $imtf<<=1) {
                if ($self->decoder($$cx[$cp])) {
                    my $n = 1;
                    my $m = (1 << $bits);
                    while ($n < $m) {
                        my $b = $self->decoder($$cx[$cp+$n]);
                        $n = ($n<<1) | $b;
                    }
                    $mtfno = $imtf + $n - $m;
                    $dat[$i] = $mtf[$mtfno];
                    last dummy; # do rotation
                }
                $cp += $imtf;
            }
            $mtfno=256;
            $dat[$i] = 0;
            $markerpos=$i;
            next byte;  # no rotation necessary
        }
        # Rotate mtf according to empirical frequencies (new!)
        # Adjust frequencies for overflow
        $fadd = $fadd + ($fadd >> $fshift);
        if ($fadd > 0x10000000)  {
            $fadd >>= 24;
            $_ >>= 24 foreach @freq;
        }
        # Relocate new char according to new freq
        my $fc = $fadd;
        $fc += $freq[$mtfno] if $mtfno < FREQMAX();
        my $k;
        for ($k=$mtfno; $k>=FREQMAX(); $k--) {
            $mtf[$k] = $mtf[$k-1];
        }
        for (; $k>0 && $fc>=$freq[$k-1]; $k--) {
            $mtf[$k] = $mtf[$k-1];
            $freq[$k] = $freq[$k-1];
        }
        $mtf[$k] = $dat[$i];
        $freq[$k] = $fc;
        # when "goto" was used, Perl 5.8.6 could segfault here
        # unless "next" was explicitly stated
    }
#
# Reconstruct the string
#
    return undef if $markerpos<1 || $markerpos>=$$self{size};
    # Allocate pointers
    # Prepare count buffer
    my @count = (0) x 256;
    my @posn;
    # Fill count buffer
    no integer;
    for ($i=0; $i<$markerpos; $i++) {
        my $c = $dat[$i];
        $posn[$i] = ($c<<24) | ($count[$c]++ & 0xffffff);
    }
    $posn[$i++] = 0; # (initialize marker entry just to be safe)
    for ( ; $i<$$self{size}; $i++) {
        my $c = $dat[$i];
        $posn[$i] = ($c<<24) | ($count[$c]++ & 0xffffff);
    }
    use integer;
    # Compute sorted char positions
    my $last = 1;
    for ($i=0; $i<256; $i++) {
        my $tmp = $count[$i];
        $count[$i] = $last;
        $last += $tmp;
    }
    # Undo the sort transform
    $i = 0;
    $last = $$self{size}-1;
    while ($last > 0) {
        my $n = $posn[$i];
        no integer;
        my $c = $n >> 24;
        use integer;
        $dat[--$last] = $c;
        $i = $count[$c] + ($n & 0xffffff);
    }
    # Final check and return decoded data
    return undef if $i != $markerpos;
    pop @dat;   # (last byte isn't real)
    return pack 'C*', @dat;
}

#------------------------------------------------------------------------------
# Inputs: 0) BZZ object ref, 1) ctx
# Returns: decoded bit
sub decoder($$)
{
    my ($self, $ctx) = @_;
    my $z = $$self{a} + $self->{p}[$ctx];
    if ($z <= $$self{fence}) {
        $$self{a} = $z;
        return ($ctx & 1);
    }
    # must pass $_[1] so subroutine can modify value (darned C++ pass-by-reference!)
    return $self->decode_sub($z, $_[1]);
}

#------------------------------------------------------------------------------
# Inputs: 0) BZZ object ref, 1) z, 2) ctx (or undef)
# Returns: decoded bit
sub decode_sub($$;$)
{
    my ($self, $z, $ctx) = @_;

    # ensure that we have at least 16 bits of encoded data available
    if ($$self{scount} < 16) {
        # preload byte by byte until we have at least 24 bits
        while ($$self{scount} <= 24) {
            if ($$self{Pos} < $$self{DataLen}) {
                $$self{byte} = ord(substr(${$$self{DataPt}}, $$self{Pos}, 1));
                ++$$self{Pos};
            } else {
                $$self{byte} = 0xff;
                if (--$$self{delay} < 1) {
                    # setting size to zero forces error return from Decode()
                    $$self{size} = 0;
                    return 0;
                }
            }
            $$self{buffer} = ($$self{buffer}<<8) | $$self{byte};
            $$self{scount} += 8;
        }
    }
    # Save bit
    my $a = $$self{a};
    my ($bit, $code);
    if (defined $ctx) {
        $bit = ($ctx & 1);
        # Avoid interval reversion
        my $d = 0x6000 + (($z+$a)>>2);
        $z = $d if $z > $d;
    } else {
        $bit = 0;
    }
    # Test MPS/LPS
    if ($z > ($code = $$self{code})) {
        $bit ^= 1;
        # LPS branch
        $z = 0x10000 - $z;
        $a += $z;
        $code += $z;
        # LPS adaptation
        $_[2] = $self->{dn}[$ctx] if defined $ctx;
        # LPS renormalization
        my $sft = $a>=0xff00 ? $self->{ffzt}[$a&0xff] + 8 : $self->{ffzt}[($a>>8)&0xff];
        $$self{scount} -= $sft;
        $$self{a} = ($a<<$sft) & 0xffff;
        $code = (($code<<$sft) & 0xffff) | (($$self{buffer}>>$$self{scount}) & ((1<<$sft)-1));
    } else {
        # MPS adaptation
        $_[2] = $self->{up}[$ctx] if defined $ctx and $a >= $self->{'m'}[$ctx];
        # MPS renormalization
        $$self{scount} -= 1;
        $$self{a} = ($z<<1) & 0xffff;
        $code = (($code<<1) & 0xffff) | (($$self{buffer}>>$$self{scount}) & 1);
    }
    # Adjust fence and save new code
    $$self{fence} = $code >= 0x8000 ? 0x7fff : $code;
    $$self{code} = $code;
    return $bit;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::BZZ - Utility to decode BZZ compressed data

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to decode BZZ
compressed data in DjVu images.

=head1 NOTES

This code is based on ZPCodec and BSByteStream of DjVuLibre 3.5.21 (see
additional copyrights and the first reference below), which are covered
under the GNU GPL license.

This is implemented as Image::ExifTool::BZZ instead of Compress::BZZ because
I am hoping that someone else will write a proper Compress::BZZ module (with
compression ability).

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)
Copyright 2002, Leon Bottou and Yann Le Cun
Copyright 2001, AT&T
Copyright 1999-2001, LizardTech Inc.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://djvu.sourceforge.net/>

=item L<http://www.djvu.org/>

=back

=head1 SEE ALSO

L<Image::ExifTool::DjVu(3pm)|Image::ExifTool::DjVu>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

