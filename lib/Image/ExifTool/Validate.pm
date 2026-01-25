#------------------------------------------------------------------------------
# File:         Validate.pm
#
# Description:  Additional metadata validation
#
# Created:      2017/01/18 - P. Harvey
#
# Notes:        My apologies for the convoluted logic contained herein, but it
#               is done this way to retro-fit the Validate feature into the
#               existing ExifTool code while reducing the possibility of
#               introducing bugs or slowing down processing when this feature
#               is not used.
#------------------------------------------------------------------------------

package Image::ExifTool::Validate;

use strict;
use vars qw($VERSION %exifSpec);

$VERSION = '1.25';

use Image::ExifTool qw(:Utils);
use Image::ExifTool::Exif;

# EXIF table tag ID's which are part of the EXIF 2.32 specification
# (with ExifVersion numbers for tags where I can determine the version)
# (also used by BuildTagLookup to add underlines in HTML version of EXIF Tag Table)
%exifSpec = (
    0x1 => 210,
    0x100 => 1,  0x8298 => 1,   0x9207 => 1,   0xa217 => 1,
    0x101 => 1,  0x829a => 1,   0x9208 => 1,   0xa300 => 1,
    0x102 => 1,  0x829d => 1,   0x9209 => 1,   0xa301 => 1,
    0x103 => 1,  0x8769 => 1,   0x920a => 1,   0xa302 => 1,
    0x106 => 1,  0x8822 => 1,   0x9214 => 220, 0xa401 => 220,
    0x10e => 1,  0x8824 => 1,   0x927c => 1,   0xa402 => 220,
    0x10f => 1,  0x8825 => 200, 0x9286 => 1,   0xa403 => 220,
    0x110 => 1,  0x8827 => 1,   0x9290 => 1,   0xa404 => 220,
    0x111 => 1,  0x8828 => 1,   0x9291 => 1,   0xa405 => 220,
    0x112 => 1,  0x8830 => 230, 0x9292 => 1,   0xa406 => 220,
    0x115 => 1,  0x8831 => 230, 0x9400 => 231, 0xa407 => 220,
    0x116 => 1,  0x8832 => 230, 0x9401 => 231, 0xa408 => 220,
    0x117 => 1,  0x8833 => 230, 0x9402 => 231, 0xa409 => 220,
    0x11a => 1,  0x8834 => 230, 0x9403 => 231, 0xa40a => 220,
    0x11b => 1,  0x8835 => 230, 0x9404 => 231, 0xa40b => 220,
    0x11c => 1,  0x9000 => 1,   0x9405 => 231, 0xa40c => 220,
    0x128 => 1,  0x9003 => 1,   0xa000 => 1,   0xa460 => 232,
    0x12d => 1,  0x9004 => 1,   0xa001 => 1,   0xa461 => 232,
    0x131 => 1,  0x9010 => 231, 0xa002 => 1,   0xa462 => 232,
    0x132 => 1,  0x9011 => 231, 0xa003 => 1,   0xa420 => 220,
    0x13b => 1,  0x9012 => 231, 0xa004 => 1,   0xa430 => 230,
    0x13e => 1,  0x9101 => 1,   0xa005 => 210, 0xa431 => 230,
    0x13f => 1,  0x9102 => 1,   0xa20b => 1,   0xa432 => 230,
    0x201 => 1,  0x9201 => 1,   0xa20c => 1,   0xa433 => 230,
    0x202 => 1,  0x9202 => 1,   0xa20e => 1,   0xa434 => 230,
    0x211 => 1,  0x9203 => 1,   0xa20f => 1,   0xa435 => 230,
    0x212 => 1,  0x9204 => 1,   0xa210 => 1,   0xa500 => 221,
    0x213 => 1,  0x9205 => 1,   0xa214 => 1,
    0x214 => 1,  0x9206 => 1,   0xa215 => 1,

    # new Exif 3.0 tags
    0xa436 => 300,
    0xa437 => 300,
    0xa438 => 300,
    0xa439 => 300,
    0xa43a => 300,
    0xa43b => 300,
    0xa43c => 300,
);

# GPSVersionID numbers when each tag was introduced
my %gpsVer = (
    0x01 => 2000,  0x09 => 2000,  0x11 => 2000,  0x19 => 2000,
    0x02 => 2000,  0x0a => 2000,  0x12 => 2000,  0x1a => 2000,
    0x03 => 2000,  0x0b => 2000,  0x13 => 2000,  0x1b => 2200,
    0x04 => 2000,  0x0c => 2000,  0x14 => 2000,  0x1c => 2200,
    0x05 => 2000,  0x0d => 2000,  0x15 => 2000,  0x1d => 2200,
    0x06 => 2000,  0x0e => 2000,  0x16 => 2000,  0x1e => 2200,
    0x07 => 2000,  0x0f => 2000,  0x17 => 2000,  0x1f => 2300,
    0x08 => 2000,  0x10 => 2000,  0x18 => 2000,
);

# lookup to check version numbers
my %verCheck = (
    ExifIFD    => { ExifVersion => \%exifSpec },
    InteropIFD => { ExifVersion => \%exifSpec },
    GPS        => { GPSVersionID => \%gpsVer },
);

# tags standard in various RAW file formats or IFD's
my %otherSpec = (
    CR2 => { 0xc5d8 => 1, 0xc5d9 => 1, 0xc5e0 => 1, 0xc640 => 1, 0xc6dc => 1, 0xc6dd => 1 },
    NEF => { 0x9216 => 1, 0x9217 => 1 },
    DNG => { 0x882a => 1, 0x9211 => 1, 0x9216 => 1 },
    ARW => { 0x7000 => 1, 0x7001 => 1, 0x7010 => 1, 0x7011 => 1, 0x7020 => 1, 0x7031 => 1,
             0x7032 => 1, 0x7034 => 1, 0x7035 => 1, 0x7036 => 1, 0x7037 => 1, 0x7038 => 1,
             0x7310 => 1, 0x7313 => 1, 0x7316 => 1, 0x74c7 => 1, 0x74c8 => 1, 0xa500 => 1 },
    RW2 => { All => 1 },    # ignore all unknown tags in RW2
    RWL => { All => 1 },
    RAF => { All => 1 },    # (temporary)
    DCR => { All => 1 },
    KDC => { All => 1 },
    JXR => { All => 1 },
    SRW => { 0xa010 => 1, 0xa011 => 1, 0xa101 => 1, 0xa102 => 1 },
    NRW => { 0x9216 => 1, 0x9217 => 1 },
    X3F => { 0xa500 => 1 },
    CameraIFD => { All => 1 }, # (exists in JPG and DNG of Leica Q3 images)
);

# standard format for tags (not necessary for exifSpec or GPS tags where Writable is defined)
my %stdFormat = (
    ExifIFD => {
        0xa002 => 'int(16|32)u',
        0xa003 => 'int(16|32)u',
    },
    InteropIFD => {
        0x01   => 'string',
        0x02   => 'undef',
        0x1000 => 'string',
        0x1001 => 'int(16|32)u',
        0x1002 => 'int(16|32)u',
    },
    IFD => {
        # TIFF, EXIF, XMP, IPTC, ICC_Profile and PrintIM standard tags:
        0xfe  => 'int32u',      0x11f => 'rational64u', 0x14a => 'int32u',      0x205 => 'int16u',
        0xff  => 'int16u',      0x120 => 'int32u',      0x14c => 'int16u',      0x206 => 'int16u',
        0x100 => 'int(16|32)u', 0x121 => 'int32u',      0x14d => 'string',      0x207 => 'int32u',
        0x101 => 'int(16|32)u', 0x122 => 'int16u',      0x14e => 'int16u',      0x208 => 'int32u',
        0x107 => 'int16u',      0x123 => 'int16u',      0x150 => 'int(8|16)u',  0x209 => 'int32u',
        0x108 => 'int16u',      0x124 => 'int32u',      0x151 => 'string',      0x211 => 'rational64u',
        0x109 => 'int16u',      0x125 => 'int32u',      0x152 => 'int16u',      0x212 => 'int16u',
        0x10a => 'int16u',      0x129 => 'int16u',      0x153 => 'int16u',      0x213 => 'int16u',
        0x10d => 'string',      0x13c => 'string',      0x154 => '.*',          0x214 => 'rational64u',
        0x111 => 'int(16|32)u', 0x13d => 'int16u',      0x155 => '.*',          0x2bc => 'int8u',
        0x116 => 'int(16|32)u', 0x140 => 'int16u',      0x156 => 'int16u',      0x828d => 'int16u',
        0x117 => 'int(16|32)u', 0x141 => 'int16u',      0x15b => 'undef',       0x828e => 'int8u',
        0x118 => 'int16u',      0x142 => 'int(16|32)u', 0x200 => 'int16u',      0x83bb => 'int32u',
        0x119 => 'int16u',      0x143 => 'int(16|32)u', 0x201 => 'int32u',      0x8649 => 'int8u',
        0x11d => 'string',      0x144 => 'int32u',      0x202 => 'int32u',      0x8773 => 'undef',
        0x11e => 'rational64u', 0x145 => 'int(16|32)u', 0x203 => 'int16u',      0xc4a5 => 'undef',
        # Windows Explorer tags:
        0x9c9b => 'int8u',      0x9c9d => 'int8u',      0x9c9f => 'int8u',
        0x9c9c => 'int8u',      0x9c9e => 'int8u',
        # GeoTiff tags:
        0x830e => 'double',     0x8482 => 'double',     0x87af => 'int16u',     0x87b1 => 'string',
        0x8480 => 'double',     0x85d8 => 'double',     0x87b0 => 'double',
        # DNG tags: (use '' for non-DNG tags in the range 0xc612-0xcd48)
        0xc615 => '(string|int8u)',              0xc6f4 => '(string|int8u)',    0xcd49 => 'float',
        0xc61a => '(int16u|int32u|rational64u)', 0xc6f6 => '(string|int8u)',    0xcd4a => 'int32u',
        0xc61d => 'int(16|32)u',                 0xc6f8 => '(string|int8u)',    0xcd4b => 'int32u',
        0xc61f => '(int16u|int32u|rational64u)', 0xc6fe => '(string|int8u)',
        0xc620 => '(int16u|int32u|rational64u)', 0xc716 => '(string|int8u)',
        0xc628 => '(int16u|rational64u)',        0xc717 => '(string|int8u)',
        0xc634 => 'int8u',                       0xc718 => '(string|int8u)',
        0xc640 => '',                            0xc71e => 'int(16|32)u',
        0xc660 => '',                            0xc71f => 'int(16|32)u',
        0xc68b => '(string|int8u)',              0xc791 => 'int(16|32)u',
        0xc68d => 'int(16|32)u',                 0xc792 => 'int(16|32)u',
        0xc68e => 'int(16|32)u',                 0xc793 => '(int16u|int32u|rational64u)',
        0xc6d2 => '',                            0xcd43 => 'int(16|32)u',
        0xc6d3 => '',                            0xcd48 => '(string|int8u)',

        # Exif 3.0 spec
        0x10e  => 'string|utf8',  0xa430 => 'string|utf8',  0xa439 => 'string|utf8',
        0x10f  => 'string|utf8',  0xa433 => 'string|utf8',  0xa43a => 'string|utf8',
        0x110  => 'string|utf8',  0xa434 => 'string|utf8',  0xa43b => 'string|utf8',
        0x131  => 'string|utf8',  0xa436 => 'string|utf8',  0xa43c => 'string|utf8',
        0x13b  => 'string|utf8',  0xa437 => 'string|utf8',  0xa43a => 'string|utf8',
        0x8298 => 'string|utf8',  0xa438 => 'string|utf8',
    },
);

# generate lookup for any IFD
my %stdFormatAnyIFD = map { %{$stdFormat{$_}} } keys %stdFormat;

# tag values to validate based on file type (from EXIF specification)
# - validation code may access $val and %val, and returns 1 on success,
#   or error message otherwise ('' for a generic message)
# - entry is undef if tag must not exist (same as 'not defined $val' in code)
my %validValue = (
    JPEG => {
        IFD0 => {
            0x100 => undef,     # ImageWidth
            0x101 => undef,     # ImageLength
            0x102 => undef,     # BitsPerSample
            0x103 => undef,     # Compression
            0x106 => undef,     # PhotometricInterpretation
            0x111 => undef,     # StripOffsets
            0x115 => undef,     # SamplesPerPixel
            0x116 => undef,     # RowsPerStrip
            0x117 => undef,     # StripByteCounts
            # (optional as of 3.0) 0x11a => 'defined $val',        # XResolution
            # (optional as of 3.0) 0x11b => 'defined $val',        # YResolution
            0x11c => undef,     # PlanarConfiguration
            # (optional as of 3.0) 0x128 => '$val =~ /^[123]$/',   # ResolutionUnit
            0x201 => undef,     # JPEGInterchangeFormat
            0x202 => undef,     # JPEGInterchangeFormatLength
            0x212 => undef,     # YCbCrSubSampling
            0x213 => '$val =~ /^[12]$/',    # YCbCrPositioning
        },
        IFD1 => {
            0x100 => undef,     # ImageWidth
            0x101 => undef,     # ImageLength
            0x102 => undef,     # BitsPerSample
            0x103 => '$val == 6',     # Compression
            0x106 => undef,     # PhotometricInterpretation
            0x111 => undef,     # StripOffsets
            0x115 => undef,     # SamplesPerPixel
            0x116 => undef,     # RowsPerStrip
            0x117 => undef,     # StripByteCounts
            0x11a => 'defined $val',        # XResolution
            0x11b => 'defined $val',        # YResolution
            0x11c => undef,     # PlanarConfiguration
            0x128 => '$val =~ /^[123]$/',   # ResolutionUnit
            0x201 => 'defined $val',        # JPEGInterchangeFormat
            0x202 => 'defined $val',        # JPEGInterchangeFormatLength
            0x212 => undef,     # YCbCrSubSampling
        },
        ExifIFD => {
            0x9000 => 'defined $val and $val =~ /^\d{4}$/', # ExifVersion
            0x9101 => 'defined $val',       # ComponentsConfiguration
            # (optional as of 3.0) 0xa000 => 'defined $val',       # FlashpixVersion
            0xa001 => '$val == 1 or $val == 0xffff',    # ColorSpace
            0xa002 => 'defined $val',       # PixelXDimension
            0xa003 => 'defined $val',       # PixelYDimension
        },
        GPS => {
            0x00 => 'defined $val and $val =~ /^\d \d \d \d$/', # GPSVersionID
            0x1b => 'not defined $val or $val =~ /^(GPS|CELLID|WLAN|MANUAL)$/', # GPSProcessingMethod
        },
        InteropIFD => { },      # (needed for ExifVersion check)
    },
    TIFF => {
        IFD0 => {
            0x100 => 'defined $val',        # ImageWidth
            0x101 => 'defined $val',        # ImageLength
            # (default is 1) 0x102 => 'defined $val',        # BitsPerSample
            0x103 => q{
                not defined $val or $val =~ /^(1|5|6|32773)$/ or
                    ($val == 2 and (not defined $val{0x102} or $val{0x102} == 1));
            }, # Compression
            0x106 => '$val =~ /^[0123]$/',  # PhotometricInterpretation
            0x111 => 'defined $val',        # StripOffsets
            # SamplesPerPixel
            0x115 => q{
                my $pi = $val{0x106} || 0;
                my $xtra = ($val{0x152} ? scalar(split ' ', $val{0x152}) : 0);
                if ($pi == 2 or $pi == 6) {
                    return $val == 3 + $xtra;
                } elsif ($pi == 5) {
                    return $val == 4 + $xtra;
                } else {
                    return 1;
                }
            },
            0x116 => 'defined $val',        # RowsPerStrip
            0x117 => 'defined $val',        # StripByteCounts
            0x11a => 'defined $val',        # XResolution
            0x11b => 'defined $val',        # YResolution
            0x128 => 'not defined $val or $val =~ /^[123]$/',   # ResolutionUnit
            # ColorMap (must be palette image with correct number of colors)
            0x140 => q{
                return '' if defined $val{0x106} and $val{0x106} == 3 xor defined $val;
                return 1 if not defined $val or length($val) == 6 * 2 ** ($val{0x102} || 0);
                return 'Invalid count for';
            },
            0x201 => undef,     # JPEGInterchangeFormat
            0x202 => undef,     # JPEGInterchangeFormatLength
        },
        ExifIFD => {
            0x9000 => 'defined $val',       # ExifVersion
            0x9101 => undef,                # ComponentsConfiguration
            0x9102 => undef,                # CompressedBitsPerPixel
            0xa000 => 'defined $val',       # FlashpixVersion
            0xa001 => '$val == 1 or $val == 0xffff',    # ColorSpace
            0xa002 => undef,                # PixelXDimension
            0xa003 => undef,                # PixelYDimension
        },
        InteropIFD => {
            0x0001 => undef,                # InteropIndex
        },
        GPS => {
            0x00 => 'defined $val and $val =~ /^\d \d \d \d$/', # GPSVersionID
            0x1b => '$val =~ /^(GPS|CELLID|WLAN|MANUAL)$/', # GPSProcessingMethod
        },
    },
);

# validity ranges for constrained date/time fields
my @validDateField = (
    [ 'Month',   1, 12 ],
    [ 'Day',     1, 31 ],
    [ 'Hour',    0, 23 ],
    [ 'Minutes', 0, 59 ],
    [ 'Seconds', 0, 59 ],
    [ 'TZhr',    0, 14 ],
    [ 'TZmin',   0, 59 ],
);

# "Validate" tag information
my %validateInfo = (
    Groups => { 0 => 'ExifTool', 1 => 'ExifTool', 2 => 'ExifTool' },
    Notes => q{
        generated only if specifically requested.  Requesting this tag automatically
        enables the API L<Validate|../ExifTool.html#Validate> option, imposing
        additional validation checks when extracting metadata.  Returns the number
        of errors, warnings and minor warnings encountered.  Note that the Validate
        feature focuses mainly on validation of EXIF/TIFF metadata
    },
    PrintConv => {
        '0 0 0' => 'OK',
        OTHER => sub {
            my @val = split ' ', shift;
            my @rtn;
            push @rtn, sprintf('%d Error%s', $val[0], $val[0] == 1 ? '' : 's') if $val[0];
            push @rtn, sprintf('%d Warning%s', $val[1], $val[1] == 1 ? '' : 's') if $val[1];
            if ($val[2]) {
                my $str = ($val[1] == $val[2] ? ($val[1] == 1 ? '' : 'all ') : "$val[2] ");
                $rtn[-1] .= " (${str}minor)";
            }
            return join(' and ', @rtn);
        },
    },
);

# add "Validate" tag to Extra table
AddTagToTable(\%Image::ExifTool::Extra, Validate => \%validateInfo, 1);

#------------------------------------------------------------------------------
# Validate the raw value of a tag
# Inputs: 0) ExifTool ref, 1) tag key, 2) raw tag value
# Returns: nothing, but issues a minor Warning if a problem was detected
sub ValidateRaw($$$)
{
    my ($self, $tag, $val) = @_;
    my $tagInfo = $$self{TAG_INFO}{$tag};
    my $wrn;

    # evaluate Validate code if specified
    if ($$tagInfo{Validate}) {
        local $SIG{'__WARN__'} = \&Image::ExifTool::SetWarning;
        undef $Image::ExifTool::evalWarning;
        #### eval Validate ($self, $val, $tagInfo)
        my $wrn = eval $$tagInfo{Validate};
        my $err = $Image::ExifTool::evalWarning || $@;
        if ($wrn or $err) {
            my $name = $$tagInfo{Table}{GROUPS}{0} . ':' . Image::ExifTool::GetTagName($tag);
            $self->Warn("Validate $name: $err", 1) if $err;
            $self->Warn("$wrn for $name", 1) if $wrn;
        }
    }
    # check for unknown values in PrintConv lookup for all standard EXIF tags
    if (ref $$tagInfo{PrintConv} eq 'HASH' and ($$tagInfo{Table}{SHORT_NAME} eq 'GPS::Main' or
        ($$tagInfo{Table} eq \%Image::ExifTool::Exif::Main and $exifSpec{$$tagInfo{TagID}})))
    {
        my $prt = $self->GetValue($tag, 'PrintConv');
        $wrn = 'Unknown value for' if $prt and $prt =~ /^Unknown \(/;
    }
    $wrn = 'Undefined value for' if $val eq 'undef';
    if ($wrn) {
        my $name = $$self{DIR_NAME} . ':' . Image::ExifTool::GetTagName($tag);
        $self->Warn("$wrn $name", 1);
    }
}

#------------------------------------------------------------------------------
# Validate raw EXIF date/time value
# Inputs: 0) date/time value
# Returns: error string
sub ValidateExifDate($)
{
    my $val = shift;
    if ($val =~ /^\d{4}:(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$/) {
        my @a = ($1,$2,$3,$4,$5);
        my ($i, @bad);
        for ($i=0; $i<@a; ++$i) {
            next if $a[$i] eq '  ' or ($a[$i] >= $validDateField[$i][1] and $a[$i] <= $validDateField[$i][2]);
            push @bad, $validDateField[$i][0];
        }
        return join('+', @bad) . ' out of range' if @bad;
    # the EXIF specification allows blank fields or an entire blank value
    } elsif ($val ne '    :  :     :  :  ' and $val ne '                   ') {
        return 'Invalid date/time format';
    }
    return undef;   # OK!
}

#------------------------------------------------------------------------------
# Validate EXIF-reformatted XMP date/time value
# Inputs: 0) date/time value
# Returns: error string
sub ValidateXMPDate($)
{
    my $val = shift;
    if ($val =~ /^\d{4}$/ or
        $val =~ /^\d{4}:(\d{2})$/ or
        $val =~ /^\d{4}:(\d{2}):(\d{2})$/ or
        $val =~ /^\d{4}:(\d{2}):(\d{2}) (\d{2}):(\d{2})()(Z|[-+](\d{2}):(\d{2}))?$/ or
        $val =~ /^\d{4}:(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})(Z|[-+](\d{2}):(\d{2}))?$/ or
        $val =~ /^\d{4}:(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})\.?\d*(Z|[-+](\d{2}):(\d{2}))?$/)
    {
        my @a = ($1,$2,$3,$4,$5,$7,$8);
        my ($i, @bad);
        for ($i=0; $i<@a; ++$i) {
            last unless defined $a[$i];
            next if $a[$i] eq '' or ($a[$i] >= $validDateField[$i][1] and $a[$i] <= $validDateField[$i][2]);
            push @bad, $validDateField[$i][0];
        }
        return join('+', @bad) . ' out of range' if @bad;
    } else {
        return 'Invalid date/time format';
    }
    return undef;   # OK!
}

#------------------------------------------------------------------------------
# Validate EXIF tag
# Inputs: 0) ExifTool ref, 1) tag table ref, 2) tag ID, 3) tagInfo ref,
#         4) previous tag ID, 5) IFD name, 6) number of values, 7) value format string
# Returns: Nothing, but sets Warning tags if any problems are found
sub ValidateExif($$$$$$$$)
{
    my ($et, $tagTablePtr, $tag, $tagInfo, $lastTag, $ifd, $count, $formatStr) = @_;

    $et->Warn("Entries in $ifd are out of order") if $tag <= $lastTag;

    # (get tagInfo for unknown tags if Unknown option not used)
    if (not defined $tagInfo and $$tagTablePtr{$tag} and ref $$tagTablePtr{$tag} eq 'HASH') {
        $tagInfo = $$tagTablePtr{$tag};
    }
    if (defined $tagInfo) {
        my $ti = $tagInfo || $$tagTablePtr{$tag};
        $ti = $$ti[-1] if ref $ti eq 'ARRAY';
        my $stdFmt = $stdFormat{$ifd} || $stdFormat{IFD};
        if (defined $$stdFmt{All} or ($tagTablePtr eq \%Image::ExifTool::Exif::Main and
            ($exifSpec{$tag} or $$stdFmt{$tag} or
            ($tag >= 0xc612 and $tag <= 0xcd48 and not defined $$stdFmt{$tag}))) or # (DNG tags)
            $$tagTablePtr{SHORT_NAME} eq 'GPS::Main')
        {
            my $wgp = $$ti{WriteGroup} || $$tagTablePtr{WRITE_GROUP};
            if ($wgp and $wgp ne $ifd and $wgp ne 'All' and not $$ti{OffsetPair} and
                ($ifd =~ /^(Sub|Profile)?IFD\d*$/ xor $wgp =~ /^(Sub)?IFD\d*$/) and
                ($$ti{Writable} or $$ti{WriteGroup}) and $ifd !~ /^SRF\d+$/)
            {
                $et->Warn(sprintf('Wrong IFD for 0x%.4x %s (should be %s not %s)', $tag, $$ti{Name}, $wgp, $ifd));
            }
            my $fmt = $$stdFmt{$tag} || $$ti{Writable};
            if ($fmt and $formatStr !~ /^$fmt$/ and (not $tagInfo or
                not $$tagInfo{IsOffset} or $Image::ExifTool::Exif::intFormat{$formatStr}))
            {
                $et->Warn(sprintf('Non-standard format (%s) for %s 0x%.4x %s', $formatStr, $ifd, $tag, $$ti{Name}))
            }
        } elsif ($stdFormatAnyIFD{$tag}) {
            if ($$ti{Writable} || $$ti{WriteGroup}) {
                my $wgp = $$ti{WriteGroup} || $$tagTablePtr{WRITE_GROUP};
                if ($wgp and $wgp ne $ifd) {
                    $et->Warn(sprintf('Wrong IFD for 0x%.4x %s (should be %s not %s)', $tag, $$ti{Name}, $wgp, $ifd));
                }
            }
        } elsif (not $otherSpec{$$et{FileType}} or
            (not $otherSpec{$$et{FileType}}{$tag} and not $otherSpec{$$et{FileType}}{All}))
        {
            if ($tagTablePtr eq \%Image::ExifTool::Exif::Main or $$ti{Unknown}) {
                $et->Warn(sprintf('Non-standard %s tag 0x%.4x %s', $ifd, $tag, $$ti{Name}), 1) unless $otherSpec{$ifd};
            }
        }
        # change expected count from read Format to Writable size
        my $tiCount = $$ti{Count};
        if ($tiCount) {
            if ($$ti{Format} and $$ti{Writable} and
                $Image::ExifTool::Exif::formatNumber{$$ti{Format}} and
                $Image::ExifTool::Exif::formatNumber{$$ti{Writable}})
            {
                my $s1 = $Image::ExifTool::Exif::formatSize[$Image::ExifTool::Exif::formatNumber{$$ti{Format}}];
                my $s2 = $Image::ExifTool::Exif::formatSize[$Image::ExifTool::Exif::formatNumber{$$ti{Writable}}];
                $tiCount = int($tiCount * $s1 / $s2);
            }
            if ($tiCount > 0 and $count != $tiCount) {
                $et->Warn(sprintf('Non-standard count (%d) for %s 0x%.4x %s', $count, $ifd, $tag, $$ti{Name}));
            }
        }
    } elsif (not $otherSpec{$$et{FileType}} or
        (not $otherSpec{$$et{FileType}}{$tag} and not $otherSpec{$$et{FileType}}{All}))
    {
        $et->Warn(sprintf('Unknown %s tag 0x%.4x', $ifd, $tag), 1) unless $otherSpec{$ifd};
    }
}

#------------------------------------------------------------------------------
# Validate image data offsets/sizes
# Inputs: 0) ExifTool ref, 1) offset info hash ref (arrays of tagInfo/value pairs, keyed by tagID)
#         2) directory name, 3) optional flag for minor warning
sub ValidateOffsetInfo($$$;$)
{
    local $_;
    my ($et, $offsetInfo, $dirName, $minor) = @_;

    my $fileSize = $$et{VALUE}{FileSize} or return;

    # (don't test RWZ files and some other file types)
    return if $$et{DontValidateImageData};
    # (Minolta A200 uses wrong byte order for these)
    return if $$et{TIFF_TYPE} eq 'MRW' and $dirName eq 'IFD0' and $$et{Model} =~ /^DiMAGE A200/;
    # (don't test 3FR, RWL or RW2 files)
    return if $$et{TIFF_TYPE} =~ /^(3FR|RWL|RW2)$/;

    Image::ExifTool::Exif::ValidateImageData($et, $offsetInfo, $dirName);

    # loop through all offsets
    while (%$offsetInfo) {
        my ($id1) = sort keys %$offsetInfo;
        my $offsets = $$offsetInfo{$id1};
        delete $$offsetInfo{$id1};
        next unless ref $offsets eq 'ARRAY';
        my $id2 = $$offsets[0]{OffsetPair};
        unless (defined $id2 and $$offsetInfo{$id2}) {
            unless ($$offsets[0]{NotRealPair} or (defined $id2 and $id2 == -1)) {
                my $corr = $$offsets[0]{IsOffset} ? 'size' : 'offset';
                $et->Warn("$dirName:$$offsets[0]{Name} is missing the corresponding $corr tag") unless $minor;
            }
            next;
        }
        my $sizes = $$offsetInfo{$id2};
        delete $$offsetInfo{$id2};
        ($sizes, $offsets) = ($offsets, $sizes) if $$sizes[0]{IsOffset};
        my @offsets = split ' ', $$offsets[1];
        my @sizes = split ' ', $$sizes[1];
        if (@sizes != @offsets) {
            $et->Warn(sprintf('Wrong number of values in %s 0x%.4x %s',
                              $dirName, $$offsets[0]{TagID}, $$offsets[0]{Name}), $minor);
            next;
        }
        while (@offsets) {
            my $start = pop @offsets;
            my $end = $start + pop @sizes;
            $et->Warn("$dirName:$$offsets[0]{Name} is zero", $minor) if $start == 0;
            $et->Warn("$dirName:$$sizes[0]{Name} is zero", $minor) if $start == $end;
            next unless $end > $fileSize;
            if ($start >= $fileSize) {
                if ($start == 0xffffffff) {
                    $et->Warn("$dirName:$$offsets[0]{Name} is invalid (0xffffffff)", $minor);
                } else {
                    $et->Warn("$dirName:$$offsets[0]{Name} is past end of file", $minor);
                }
            } else {
                $et->Warn("$dirName:$$offsets[0]{Name}+$$sizes[0]{Name} runs past end of file", $minor);
            }
            last;
        }
    }
}

#------------------------------------------------------------------------------
# Finish Validating tags
# Inputs: 0) ExifTool ref, 1) True to generate Validate tag
sub FinishValidate($$)
{
    local $_;
    my ($et, $mkTag) = @_;

    my $fileType = $$et{FILE_TYPE} || '';
    $fileType = $$et{TIFF_TYPE} if $fileType eq 'TIFF';

    if ($validValue{$fileType}) {
        my ($grp, $tag, %val);
        local $SIG{'__WARN__'} = \&Image::ExifTool::SetWarning;
        foreach $grp (sort keys %{$validValue{$fileType}}) {
            next unless $$et{FOUND_DIR}{$grp};
            my ($key, %val, %info, $minor, $verTag, $ver, $vstr);
            my $verCheck = $verCheck{$grp};
            if ($verCheck) {
                ($verTag) = keys %$verCheck;
                ($ver = $$et{VALUE}{$verTag}) =~ tr/0-9//dc; # (remove non-digits)
                undef $ver unless $ver =~ /^\d{4}$/; # (already warned if invalid version)
            }
            # get all tags in this group
            foreach $key (sort keys %{$$et{VALUE}}) {
                next unless $et->GetGroup($key, 1) eq $grp;
                next if $$et{TAG_EXTRA}{$key}{G3}; # ignore sub-documents
                # fill in %val lookup with values based on tag ID
                my $tag = $$et{TAG_INFO}{$key}{TagID};
                $val{$tag} = $$et{VALUE}{$key};
                # save TagInfo ref for later
                $info{$tag} = $$et{TAG_INFO}{$key};
                next unless defined $ver;
                my $chk = $$verCheck{$verTag};
                next if not defined $$chk{$tag} or $$chk{$tag} == 1 or $ver >= $$chk{$tag};
                if ($verTag eq 'GPSVersionID') {
                    ($vstr = $$chk{$tag}) =~ s/^(\d)(\d)(\d)/$1.$2.$3./;
                } else {
                    $vstr = sprintf('%.4d', $$chk{$tag});
                }
                $et->Warn(sprintf('%s tag 0x%.4x %s requires %s %s or higher',
                          $grp, $tag, $$et{TAG_INFO}{$key}{Name}, $verTag, $vstr));
            }
            # make quick lookup for values based on tag ID
            my $validValue = $validValue{$fileType}{$grp};
            foreach $tag (sort { $a <=> $b } keys %$validValue) {
                my $val = $val{$tag};
                my ($pre, $post);
                if (defined $$validValue{$tag}) {
                    #### eval ($val, %val)
                    my $result = eval $$validValue{$tag};
                    if (not defined $result) {
                        $pre = 'Internal error validating';
                    } elsif ($result eq '') {
                        $pre = defined $val ? 'Invalid value for' : "Missing required $fileType";
                    } else {
                        next if $result eq '1';
                        $pre = $result;
                    }
                } else {
                    next unless defined $val;
                    $post = "is not allowed in $fileType";
                    $minor = 1;
                }
                my $name;
                if ($info{$tag}) {
                    $name = $info{$tag}{Name};
                } else {
                    my $table = 'Image::ExifTool::'.($grp eq 'GPS' ? 'GPS' : 'Exif').'::Main';
                    my $tagInfo = GetTagTable($table)->{$tag};
                    $tagInfo = $$tagInfo[0] if ref $tagInfo eq 'ARRAY';
                    $name = $tagInfo ? $$tagInfo{Name} : '<unknown>';
                }
                next if $$et{WrongFormat} and $$et{WrongFormat}{"$grp:$name"};
                $pre ? ($pre .= ' ') : ($pre = '');
                $post ? ($post = ' '.$post) : ($post = '');
                $et->Warn(sprintf('%s%s tag 0x%.4x %s%s', $pre, $grp, $tag, $name, $post), $minor);
            }
        }
    }
    # validate file extension
    if ($$et{FILENAME} ne '') {
        my $fileExt = ($$et{FILENAME} =~ /^.*\.([^.]+)$/s) ? uc($1) : '';
        my $extFileType = Image::ExifTool::GetFileType($fileExt);
        if ($extFileType and $extFileType ne $fileType) {
            my $normExt = $$et{VALUE}{FileTypeExtension};
            if ($normExt and $normExt ne $fileExt) {
                my $lkup = $Image::ExifTool::fileTypeLookup{$fileExt};
                if (ref $lkup or $lkup ne $normExt) {
                    $et->Warn("File has wrong extension (should be $normExt, not $fileExt)");
                }
            }
        }
    }
    # issue warning if FastScan option used
    $et->Warn('Validation incomplete because FastScan option used') if $et->Options('FastScan');

    # generate Validate tag if necessary
    if ($mkTag) {
        my (@num, $key);
        push @num, $$et{VALUE}{Error}   ? ($$et{DUPL_TAG}{Error}   || 0) + 1 : 0,
                   $$et{VALUE}{Warning} ? ($$et{DUPL_TAG}{Warning} || 0) + 1 : 0, 0;
        for ($key = 'Warning'; ; ) {
            ++$num[2] if $$et{VALUE}{$key} and $$et{VALUE}{$key} =~ /^\[minor\]/i;
            $key = $et->NextTagKey($key) or last;
        }
        $et->FoundTag(Validate => "@num");
    }
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Validate - Additional metadata validation

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains additional routines and definitions used when the
ExifTool Validate option is enabled.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::ExifTool::TagNames/Extra Tags>

=cut
