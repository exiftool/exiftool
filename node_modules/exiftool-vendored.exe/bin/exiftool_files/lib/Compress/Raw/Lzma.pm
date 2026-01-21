package Compress::Raw::Lzma;

use strict ;
use warnings ;

require 5.006 ;
require Exporter;
use AutoLoader;
use Carp ;

use bytes ;
our ($VERSION, $XS_VERSION, @ISA, @EXPORT, $AUTOLOAD);

$VERSION = '2.100';
$XS_VERSION = $VERSION;
$VERSION = eval $VERSION;

@ISA = qw(Exporter);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(

    LZMA_OK
    LZMA_STREAM_END
    LZMA_NO_CHECK
    LZMA_UNSUPPORTED_CHECK
    LZMA_GET_CHECK
    LZMA_MEM_ERROR
    LZMA_MEMLIMIT_ERROR
    LZMA_FORMAT_ERROR
    LZMA_OPTIONS_ERROR
    LZMA_DATA_ERROR
    LZMA_BUF_ERROR
    LZMA_PROG_ERROR

    LZMA_RUN
    LZMA_SYNC_FLUSH
    LZMA_FULL_FLUSH
    LZMA_FINISH

    LZMA_FILTER_X86
    LZMA_FILTER_POWERPC
    LZMA_FILTER_IA64
    LZMA_FILTER_ARM
    LZMA_FILTER_ARMTHUMB
    LZMA_FILTER_SPARC


    LZMA_BLOCK_HEADER_SIZE_MIN
    LZMA_BLOCK_HEADER_SIZE_MAX

    LZMA_CHECK_NONE
    LZMA_CHECK_CRC32
    LZMA_CHECK_CRC64
    LZMA_CHECK_SHA256

    LZMA_CHECK_ID_MAX
    LZMA_CHECK_SIZE_MAX

    LZMA_PRESET_DEFAULT
    LZMA_PRESET_LEVEL_MASK
    LZMA_PRESET_EXTREME

    LZMA_TELL_NO_CHECK
    LZMA_TELL_UNSUPPORTED_CHECK
    LZMA_TELL_ANY_CHECK
    LZMA_CONCATENATED


    LZMA_FILTER_DELTA
    LZMA_DELTA_DIST_MIN
    LZMA_DELTA_DIST_MAX
    LZMA_DELTA_TYPE_BYTE

    LZMA_FILTERS_MAX

    LZMA_FILTER_LZMA2

    LZMA_MF_HC3
    LZMA_MF_HC4
    LZMA_MF_BT2
    LZMA_MF_BT3
    LZMA_MF_BT4

    LZMA_MODE_FAST
    LZMA_MODE_NORMAL

    LZMA_DICT_SIZE_MIN
    LZMA_DICT_SIZE_DEFAULT

    LZMA_LCLP_MIN
    LZMA_LCLP_MAX
    LZMA_LC_DEFAULT

    LZMA_LP_DEFAULT

    LZMA_PB_MIN
    LZMA_PB_MAX
    LZMA_PB_DEFAULT

    LZMA_STREAM_HEADER_SIZE

    LZMA_BACKWARD_SIZE_MIN

    LZMA_FILTER_SUBBLOCK

    LZMA_SUBFILTER_NONE
    LZMA_SUBFILTER_SET
    LZMA_SUBFILTER_RUN
    LZMA_SUBFILTER_FINISH

    LZMA_SUBBLOCK_ALIGNMENT_MIN
    LZMA_SUBBLOCK_ALIGNMENT_MAX
    LZMA_SUBBLOCK_ALIGNMENT_DEFAULT

    LZMA_SUBBLOCK_DATA_SIZE_MIN
    LZMA_SUBBLOCK_DATA_SIZE_MAX
    LZMA_SUBBLOCK_DATA_SIZE_DEFAULT

    LZMA_SUBBLOCK_RLE_OFF
    LZMA_SUBBLOCK_RLE_MIN
    LZMA_SUBBLOCK_RLE_MAX

    LZMA_VERSION
    LZMA_VERSION_MAJOR
    LZMA_VERSION_MINOR
    LZMA_VERSION_PATCH
    LZMA_VERSION_STABILITY

    LZMA_VERSION_STABILITY_STRING
    LZMA_VERSION_STRING
    );

    #LZMA_VLI_MAX
    #LZMA_VLI_UNKNOWN
    #LZMA_VLI_BYTES_MAX

sub AUTOLOAD {
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    my ($error, $val) = constant($constname);
    Carp::croak $error if $error;
    no strict 'refs';
    *{$AUTOLOAD} = sub { $val };
    goto &{$AUTOLOAD};

}

use constant FLAG_APPEND             => 1 ;
use constant FLAG_CRC                => 2 ;
use constant FLAG_ADLER              => 4 ;
use constant FLAG_CONSUME_INPUT      => 8 ;
use constant FLAG_LIMIT_OUTPUT       => 16 ;

eval {
    require XSLoader;
    XSLoader::load('Compress::Raw::Lzma', $XS_VERSION);
    1;
}
or do {
    require DynaLoader;
    local @ISA = qw(DynaLoader);
    bootstrap Compress::Raw::Lzma $XS_VERSION ;
};

use constant Parse_any      => 0x01;
use constant Parse_unsigned => 0x02;
use constant Parse_signed   => 0x04;
use constant Parse_boolean  => 0x08;
use constant Parse_string   => 0x10;
use constant Parse_custom   => 0x12;

use constant Parse_store_ref => 0x100 ;

use constant OFF_PARSED     => 0 ;
use constant OFF_TYPE       => 1 ;
use constant OFF_DEFAULT    => 2 ;
use constant OFF_FIXED      => 3 ;
use constant OFF_FIRST_ONLY => 4 ;
use constant OFF_STICKY     => 5 ;



sub ParseParameters
{
    my $level = shift || 0 ;

    my $sub = (caller($level + 1))[3] ;
    #local $Carp::CarpLevel = 1 ;
    my $p = new Compress::Raw::Lzma::Parameters() ;
    $p->parse(@_)
        or croak "$sub: $p->{Error}" ;

    return $p;
}


sub Compress::Raw::Lzma::Parameters::new
{
    my $class = shift ;

    my $obj = { Error => '',
                Got   => {},
              } ;

    #return bless $obj, ref($class) || $class || __PACKAGE__ ;
    return bless $obj, 'Compress::Raw::Lzma::Parameters' ;
}

sub Compress::Raw::Lzma::Parameters::setError
{
    my $self = shift ;
    my $error = shift ;
    my $retval = @_ ? shift : undef ;

    $self->{Error} = $error ;
    return $retval;
}

#sub getError
#{
#    my $self = shift ;
#    return $self->{Error} ;
#}

sub Compress::Raw::Lzma::Parameters::parse
{
    my $self = shift ;

    my $default = shift ;

    my $got = $self->{Got} ;
    my $firstTime = keys %{ $got } == 0 ;

    my (@Bad) ;
    my @entered = () ;

    # Allow the options to be passed as a hash reference or
    # as the complete hash.
    if (@_ == 0) {
        @entered = () ;
    }
    elsif (@_ == 1) {
        my $href = $_[0] ;
        return $self->setError("Expected even number of parameters, got 1")
            if ! defined $href or ! ref $href or ref $href ne "HASH" ;

        foreach my $key (keys %$href) {
            push @entered, $key ;
            push @entered, \$href->{$key} ;
        }
    }
    else {
        my $count = @_;
        return $self->setError("Expected even number of parameters, got $count")
            if $count % 2 != 0 ;

        for my $i (0.. $count / 2 - 1) {
            push @entered, $_[2* $i] ;
            push @entered, \$_[2* $i+1] ;
        }
    }


    while (my ($key, $v) = each %$default)
    {
        croak "need 4 params [@$v]"
            if @$v != 4 ;

        my ($first_only, $sticky, $type, $value) = @$v ;
        my $x ;
        $self->_checkType($key, \$value, $type, 0, \$x)
            or return undef ;

        $key = lc $key;

        if ($firstTime || ! $sticky) {
            $got->{$key} = [0, $type, $value, $x, $first_only, $sticky] ;
        }

        $got->{$key}[OFF_PARSED] = 0 ;
    }

    for my $i (0.. @entered / 2 - 1) {
        my $key = $entered[2* $i] ;
        my $value = $entered[2* $i+1] ;

        #print "Key [$key] Value [$value]" ;
        #print defined $$value ? "[$$value]\n" : "[undef]\n";

        $key =~ s/^-// ;
        my $canonkey = lc $key;

        if ($got->{$canonkey} && ($firstTime ||
                                  ! $got->{$canonkey}[OFF_FIRST_ONLY]  ))
        {
            my $type = $got->{$canonkey}[OFF_TYPE] ;
            my $s ;
            $self->_checkType($key, $value, $type, 1, \$s)
                or return undef ;
            #$value = $$value unless $type & Parse_store_ref ;
            $value = $$value ;
            $got->{$canonkey} = [1, $type, $value, $s] ;
        }
        else
          { push (@Bad, $key) }
    }

    if (@Bad) {
        my ($bad) = join(", ", @Bad) ;
        return $self->setError("unknown key value(s) @Bad") ;
    }

    return 1;
}

sub Compress::Raw::Lzma::Parameters::_checkType
{
    my $self = shift ;

    my $key   = shift ;
    my $value = shift ;
    my $type  = shift ;
    my $validate  = shift ;
    my $output  = shift;

    #local $Carp::CarpLevel = $level ;
    #print "PARSE $type $key $value $validate $sub\n" ;
    if ( $type & Parse_store_ref)
    {
        #$value = $$value
        #    if ref ${ $value } ;

        $$output = $value ;
        return 1;
    }

    $value = $$value ;

    if ($type & Parse_any)
    {
        $$output = $value ;
        return 1;
    }
    elsif ($type & Parse_unsigned)
    {
        return $self->setError("Parameter '$key' must be an unsigned int, got 'undef'")
            if $validate && ! defined $value ;
        return $self->setError("Parameter '$key' must be an unsigned int, got '$value'")
            if $validate && $value !~ /^\d+$/;

        $$output = defined $value ? $value : 0 ;
        return 1;
    }
    elsif ($type & Parse_signed)
    {
        return $self->setError("Parameter '$key' must be a signed int, got 'undef'")
            if $validate && ! defined $value ;
        return $self->setError("Parameter '$key' must be a signed int, got '$value'")
            if $validate && $value !~ /^-?\d+$/;

        $$output = defined $value ? $value : 0 ;
        return 1 ;
    }
    elsif ($type & Parse_boolean)
    {
        return $self->setError("Parameter '$key' must be an int, got '$value'")
            if $validate && defined $value && $value !~ /^\d*$/;
        $$output =  defined $value ? $value != 0 : 0 ;
        return 1;
    }
    elsif ($type & Parse_string)
    {
        $$output = defined $value ? $value : "" ;
        return 1;
    }

    $$output = $value ;
    return 1;
}



sub Compress::Raw::Lzma::Parameters::parsed
{
    my $self = shift ;
    my $name = shift ;

    return $self->{Got}{lc $name}[OFF_PARSED] ;
}

sub Compress::Raw::Lzma::Parameters::value
{
    my $self = shift ;
    my $name = shift ;

    if (@_)
    {
        $self->{Got}{lc $name}[OFF_PARSED]  = 1;
        $self->{Got}{lc $name}[OFF_DEFAULT] = $_[0] ;
        $self->{Got}{lc $name}[OFF_FIXED]   = $_[0] ;
    }

    return $self->{Got}{lc $name}[OFF_FIXED] ;
}


sub Compress::Raw::Lzma::Encoder::STORABLE_freeze
{
    my $type = ref shift;
    croak "Cannot freeze $type object\n";
}

sub Compress::Raw::Lzma::Encoder::STORABLE_thaw
{
    my $type = ref shift;
    croak "Cannot thaw $type object\n";
}


@Compress::Raw::Lzma::EasyEncoder::ISA = qw(Compress::Raw::Lzma::Encoder);

sub Compress::Raw::Lzma::EasyEncoder::new
{
    my $pkg = shift ;
    my ($got) = ParseParameters(0,
            {
                'AppendOutput'  => [1, 1, Parse_boolean,  0],
                'Bufsize'       => [1, 1, Parse_unsigned, 16 * 1024],

                'Preset'        => [1, 1, Parse_unsigned, LZMA_PRESET_DEFAULT()],
                'Extreme'       => [1, 1, Parse_boolean, 0],
                'Check'         => [1, 1, Parse_unsigned, LZMA_CHECK_CRC32()],
            }, @_) ;


#    croak "Compress::Raw::Lzma::EasyEncoder::new: Bufsize must be >= 1, you specified " .
#            $got->value('Bufsize')
#        unless $got->value('Bufsize') >= 1;

    my $flags = 0 ;
    $flags |= FLAG_APPEND if $got->value('AppendOutput') ;

    my $preset = $got->value('Preset');

    if ($got->value('Extreme')) {
        $preset |= LZMA_PRESET_EXTREME();
    }

    lzma_easy_encoder($pkg, $flags,
                $got->value('Bufsize'),
                $preset,
                $got->value('Check')) ;

}

@Compress::Raw::Lzma::AloneEncoder::ISA = qw(Compress::Raw::Lzma::Encoder);

sub Compress::Raw::Lzma::AloneEncoder::new
{
    my $pkg = shift ;
    my ($got) = ParseParameters(0,
            {
                'AppendOutput'  => [1, 1, Parse_boolean,  0],
                'Bufsize'       => [1, 1, Parse_unsigned, 16 * 1024],
                'Filter'        => [1, 1, Parse_any, [] ],

            }, @_) ;


    my $flags = 0 ;
    $flags |= FLAG_APPEND if $got->value('AppendOutput') ;

    my $filters = Lzma::Filters::validateFilters(1, 0, $got->value('Filter')) ;
    # TODO - check max of 1 filter & it is a reference to Lzma::Filter::Lzma1

    lzma_alone_encoder($pkg, $flags,
                       $got->value('Bufsize'),
                       $filters);

}

@Compress::Raw::Lzma::StreamEncoder::ISA = qw(Compress::Raw::Lzma::Encoder);

sub Compress::Raw::Lzma::StreamEncoder::new
{
    my $pkg = shift ;
    my ($got) = ParseParameters(0,
            {
                'AppendOutput'  => [1, 1, Parse_boolean,  0],
                'Bufsize'       => [1, 1, Parse_unsigned, 16 * 1024],
                'Filter'        => [1, 1, Parse_any, [] ],
                'Check'         => [1, 1, Parse_unsigned, LZMA_CHECK_CRC32()],

            }, @_) ;


    my $flags = 0 ;
    $flags |= FLAG_APPEND if $got->value('AppendOutput') ;

    my $filters = Lzma::Filters::validateFilters(1, 1, $got->value('Filter')) ;

    lzma_stream_encoder($pkg, $flags,
                        $got->value('Bufsize'),
                        $filters,
                        $got->value('Check'));

}

@Compress::Raw::Lzma::RawEncoder::ISA = qw(Compress::Raw::Lzma::Encoder);

sub Compress::Raw::Lzma::RawEncoder::new
{
    my $pkg = shift ;
    my ($got) = ParseParameters(0,
            {
                'ForZip'        => [1, 1, Parse_boolean,  0],
                'AppendOutput'  => [1, 1, Parse_boolean,  0],
                'Bufsize'       => [1, 1, Parse_unsigned, 16 * 1024],
                'Filter'        => [1, 1, Parse_any, [] ],

            }, @_) ;


    my $flags = 0 ;
    $flags |= FLAG_APPEND if $got->value('AppendOutput') ;

    my $forZip = $got->value('ForZip');

    my $filters = Lzma::Filters::validateFilters(1, ! $forZip, $got->value('Filter')) ;

    lzma_raw_encoder($pkg, $flags,
                        $got->value('Bufsize'),
                        $filters,
                        $forZip);

}

@Compress::Raw::Lzma::AutoDecoder::ISA = qw(Compress::Raw::Lzma::Decoder);

sub Compress::Raw::Lzma::AutoDecoder::new
{
    my $pkg = shift ;
    my ($got) = ParseParameters(0,
                    {
                        'AppendOutput'  => [1, 1, Parse_boolean,  0],
                        'LimitOutput'   => [1, 1, Parse_boolean,  0],
                        'ConsumeInput'  => [1, 1, Parse_boolean,  1],
                        'Bufsize'       => [1, 1, Parse_unsigned, 16 * 1024],

                        'MemLimit'      => [1, 1, Parse_unsigned, 128 *1024 *1024],

            }, @_) ;


    my $flags = 0 ;
    $flags |= FLAG_APPEND if $got->value('AppendOutput') ;
    $flags |= FLAG_CONSUME_INPUT if $got->value('ConsumeInput') ;
    $flags |= FLAG_LIMIT_OUTPUT if $got->value('LimitOutput') ;

    lzma_auto_decoder($pkg, $flags, $got->value('MemLimit'));
}

@Compress::Raw::Lzma::AloneDecoder::ISA = qw(Compress::Raw::Lzma::Decoder);

sub Compress::Raw::Lzma::AloneDecoder::new
{
    my $pkg = shift ;
    my ($got) = ParseParameters(0,
                    {
                        'AppendOutput'  => [1, 1, Parse_boolean,  0],
                        'LimitOutput'   => [1, 1, Parse_boolean,  0],
                        'ConsumeInput'  => [1, 1, Parse_boolean,  1],
                        'Bufsize'       => [1, 1, Parse_unsigned, 16 * 1024],

                        'MemLimit'      => [1, 1, Parse_unsigned, 128 *1024 *1024],

            }, @_) ;


    my $flags = 0 ;
    $flags |= FLAG_APPEND if $got->value('AppendOutput') ;
    $flags |= FLAG_CONSUME_INPUT if $got->value('ConsumeInput') ;
    $flags |= FLAG_LIMIT_OUTPUT if $got->value('LimitOutput') ;

    lzma_alone_decoder($pkg,
                       $flags,
                       $got->value('Bufsize'),
                       $got->value('MemLimit'));
}

@Compress::Raw::Lzma::StreamDecoder::ISA = qw(Compress::Raw::Lzma::Decoder);

sub Compress::Raw::Lzma::StreamDecoder::new
{
    my $pkg = shift ;
    my ($got) = ParseParameters(0,
                    {
                        'AppendOutput'  => [1, 1, Parse_boolean,  0],
                        'LimitOutput'   => [1, 1, Parse_boolean,  0],
                        'ConsumeInput'  => [1, 1, Parse_boolean,  1],
                        'Bufsize'       => [1, 1, Parse_unsigned, 16 * 1024],

                        'MemLimit'      => [1, 1, Parse_unsigned, 128 *1024 *1024],
                        'Flags'         => [1, 1, Parse_unsigned, 0],

            }, @_) ;


    my $flags = 0 ;
    $flags |= FLAG_APPEND if $got->value('AppendOutput') ;
    $flags |= FLAG_CONSUME_INPUT if $got->value('ConsumeInput') ;
    $flags |= FLAG_LIMIT_OUTPUT if $got->value('LimitOutput') ;

    lzma_stream_decoder($pkg,
                        $flags,
                        $got->value('Bufsize'),
                        $got->value('MemLimit'),
                        $got->value('Flags'));
}

@Compress::Raw::Lzma::RawDecoder::ISA = qw(Compress::Raw::Lzma::Decoder);

sub Compress::Raw::Lzma::RawDecoder::new
{
    my $pkg = shift ;
    my ($got) = ParseParameters(0,
                    {
                        'AppendOutput'  => [1, 1, Parse_boolean,  0],
                        'LimitOutput'   => [1, 1, Parse_boolean,  0],
                        'ConsumeInput'  => [1, 1, Parse_boolean,  1],
                        'Bufsize'       => [1, 1, Parse_unsigned, 16 * 1024],
                        'Filter'        => [1, 1, Parse_any, [] ],
                        'Properties'    => [1, 1, Parse_any,  undef],
            }, @_) ;


    my $flags = 0 ;
    $flags |= FLAG_APPEND if $got->value('AppendOutput') ;
    $flags |= FLAG_CONSUME_INPUT if $got->value('ConsumeInput') ;
    $flags |= FLAG_LIMIT_OUTPUT if $got->value('LimitOutput') ;

    my $filters = Lzma::Filters::validateFilters(0, ! defined $got->value('Properties'),
                            $got->value('Filter')) ;

    lzma_raw_decoder($pkg,
                        $flags,
                        $got->value('Bufsize'),
                        $filters,
                        $got->value('Properties'));
}

# LZMA1/2
#   Preset
#   Dict
#   Lc
#   Lp
#   Pb
#   Mode LZMA_MODE_FAST, LZMA_MODE_NORMAL
#   Nice
#   Mf LZMA_MF_HC3 LZMA_MF_HC4 LZMA_MF_BT2 LZMA_MF_BT3 LZMA_MF_BT4
#   Depth

# BCJ
#   LZMA_FILTER_X86
#   LZMA_FILTER_POWERPC
#   LZMA_FILTER_IA64
#   LZMA_FILTER_ARM
#   LZMA_FILTER_ARMTHUMB
#   LZMA_FILTER_SPARC
#
#   BCJ => LZMA_FILTER_X86 -- this assumes offset is 0
#   BCJ => [LZMA_FILTER_X86, offset]

# Delta
#    Dist 1 - 256, 1

# Subblock
#    Size
#    RLE
#    Align

# Preset (0-9) LZMA_PRESET_EXTREME LZMA_PRESET_DEFAULT -- call lzma_lzma_preset

# Memory

# Check => LZMA_CHECK_NONE, LZMA_CHECK_CRC32, LZMA_CHECK_CRC64, LZMA_CHECK_SHA256

# my $bool = lzma_check_is_supported(LZMA_CHECK_CRC32);
# my $int = lzma_check_size(LZMA_CHECK_CRC32);
# my $int = $lzma->lzma_get_check();




#sub Compress::Raw::Lzma::new
#{
#    my $class = shift ;
#    my ($ptr, $status) = _new(@_);
#    return wantarray ? (undef, $status) : undef
#        unless $ptr ;
#    my $obj = bless [$ptr], $class ;
#    return wantarray ? ($obj, $status) : $obj;
#}
#
#package Compress::Raw::UnLzma ;
#
#sub Compress::Raw::UnLzma::new
#{
#    my $class = shift ;
#    my ($ptr, $status) = _new(@_);
#    return wantarray ? (undef, $status) : undef
#        unless $ptr ;
#    my $obj = bless [$ptr], $class ;
#    return wantarray ? ($obj, $status) : $obj;
#}


sub Lzma::Filters::validateFilters
{
    use UNIVERSAL ;
    use Scalar::Util qw(blessed );

    my $encoding = shift; # not decoding
    my $lzma2 = shift;

    # my $objType = $lzma2 ? "Lzma::Filter::Lzma2"
    #                      : "Lzma::Filter::Lzma" ;

    my $objType =  "Lzma::Filter::Lzma" ;

    # if only one, convert into an array reference
    if (blessed $_[0] )  {
        die "filter object $_[0] is not an $objType object"
            unless UNIVERSAL::isa($_[0], $objType);

            #$_[0] = [ $_[0] ] ;
        return [ $_[0] ] ;
    }

    if (ref $_[0] ne 'ARRAY')
      { die "$_[0] not Lzma::Filter object or ARRAY ref" }

    my $filters = $_[0] ;
    my $count = @$filters;

    # check number of filters
    die sprintf "Too many filters ($count), max is %d", LZMA_FILTERS_MAX()
        if $count > LZMA_FILTERS_MAX();

    # TODO - add more tests here
    # Check that all filters inherit from Lzma::Filter
    # check that filters are supported
    # check memory requirements
    # need exactly one lzma1/2 filter
    # lzma1/2 is the last thing in the list
    for (my $i = 0; $i <  @$filters ; ++$i)
    {
        my $filt = $filters->[$i];
        die "filter is not an Lzma::Filter object"
            unless UNIVERSAL::isa($filt, 'Lzma::Filter');
        die "Lzma filter must be last"
            if UNIVERSAL::isa($filt, 'Lzma::Filter::Lzma') && $i < $count -1 ;

        #die "xxx" unless lzma_filter_encoder_is_supported($filt->id());
    }

    if (@$filters == 0)
    {
        push @$filters, $lzma2 ? Lzma::Filter::Lzma2()
                               : Lzma::Filter::Lzma1();
    }

    return $filters;
}

#package Lzma::Filter;
#package Lzma::Filter::Lzma;

#our ($VERSION, @ISA, @EXPORT, $AUTOLOAD);
@Lzma::Filter::Lzma::ISA = qw(Lzma::Filter);

sub Lzma::Filter::Lzma::mk
{
    my $type = shift;

    my $got = Compress::Raw::Lzma::ParseParameters(0,
        {
            'DictSize' => [1, 1, Parse_unsigned(), LZMA_DICT_SIZE_DEFAULT()],
            'PresetDict' => [1, 1, Parse_string(), undef],
            'Lc'    => [1, 1, Parse_unsigned(), LZMA_LC_DEFAULT()],
            'Lp'    => [1, 1, Parse_unsigned(), LZMA_LP_DEFAULT()],
            'Pb'    => [1, 1, Parse_unsigned(), LZMA_PB_DEFAULT()],
            'Mode'  => [1, 1, Parse_unsigned(), LZMA_MODE_NORMAL()],
            'Nice'  => [1, 1, Parse_unsigned(), 64],
            'Mf'    => [1, 1, Parse_unsigned(), LZMA_MF_BT4()],
            'Depth' => [1, 1, Parse_unsigned(), 0],
        }, @_) ;

    my $pkg = (caller(1))[3] ;

    my $DictSize = $got->value('DictSize');
    die "Dictsize $DictSize not in range 4KiB - 1536Mib"
        if $DictSize < 1024 * 4 ||
           $DictSize > 1024 * 1024 * 1536 ;

    my $Lc = $got->value('Lc');
    die "Lc $Lc not in range 0-4"
        if $Lc < 0 || $Lc > 4;

    my $Lp = $got->value('Lp');
    die "Lp $Lp not in range 0-4"
        if $Lp < 0 || $Lp > 4;

    die "Lc + Lp must be <= 4"
        if $Lc + $Lp > 4;

    my $Pb = $got->value('Pb');
    die "Pb $Pb not in range 0-4"
        if $Pb < 0 || $Pb > 4;

    my $Mode = $got->value('Mode');
    die "Mode $Mode not LZMA_MODE_FAST or LZMA_MODE_NORMAL"
        if $Mode != LZMA_MODE_FAST() && $Mode != LZMA_MODE_NORMAL();

    my $Mf = $got->value('Mf');
    die "Mf $Mf not valid"
        if ! grep { $Mf == $_ }
             ( LZMA_MF_HC3(),
               LZMA_MF_HC4(),
               LZMA_MF_BT2(),
               LZMA_MF_BT3(),
               LZMA_MF_BT4());

    my $Nice = $got->value('Nice');
    die "Nice $Nice not in range 2-273"
        if $Nice < 2 || $Nice > 273;

    my $obj = Lzma::Filter::Lzma::_mk($type,
                            $DictSize,
                            $Lc,
                            $Lp,
                            $Pb,
                            $Mode,
                            $Nice,
                            $Mf,
                            $got->value('Depth'),
                            $got->value('PresetDict'),
                        );

    bless $obj, $pkg
        if defined $obj;

    $obj;
}

sub Lzma::Filter::Lzma::mkPreset
{
    my $type = shift;

    my $preset = shift;
    my $pkg = (caller(1))[3] ;

    my $obj = Lzma::Filter::Lzma::_mkPreset($type, $preset);

    bless $obj, $pkg
        if defined $obj;

    $obj;
}

@Lzma::Filter::Lzma1::ISA = qw(Lzma::Filter::Lzma);
sub Lzma::Filter::Lzma1
{
    Lzma::Filter::Lzma::mk(0, @_);
}

@Lzma::Filter::Lzma1::Preset::ISA = qw(Lzma::Filter::Lzma);
sub Lzma::Filter::Lzma1::Preset
{
    Lzma::Filter::Lzma::mkPreset(0, @_);
}

@Lzma::Filter::Lzma2::ISA = qw(Lzma::Filter::Lzma);
sub Lzma::Filter::Lzma2
{
    Lzma::Filter::Lzma::mk(1, @_);
}

@Lzma::Filter::Lzma2::Preset::ISA = qw(Lzma::Filter::Lzma);
sub Lzma::Filter::Lzma2::Preset
{
    Lzma::Filter::Lzma::mkPreset(1, @_);
}

@Lzma::Filter::BCJ::ISA = qw(Lzma::Filter);

sub Lzma::Filter::BCJ::mk
{
    my $type = shift;
    my $got = Compress::Raw::Lzma::ParseParameters(0,
            {
                'Offset' => [1, 1, Parse_unsigned(), 0],
            }, @_) ;

    my $pkg = (caller(1))[3] ;
    my $obj = Lzma::Filter::BCJ::_mk($type, $got->value('Offset')) ;
    bless $obj, $pkg
        if defined $obj;

    $obj;
}

@Lzma::Filter::X86::ISA = qw(Lzma::Filter::BCJ);

sub Lzma::Filter::X86
{
    Lzma::Filter::BCJ::mk(LZMA_FILTER_X86(), @_);
}

@Lzma::Filter::PowerPC::ISA = qw(Lzma::Filter::BCJ);

sub Lzma::Filter::PowerPC
{
    Lzma::Filter::BCJ::mk(LZMA_FILTER_POWERPC(), @_);
}

@Lzma::Filter::IA64::ISA = qw(Lzma::Filter::BCJ);

sub Lzma::Filter::IA64
{
    Lzma::Filter::BCJ::mk(LZMA_FILTER_IA64(), @_);
}

@Lzma::Filter::ARM::ISA = qw(Lzma::Filter::BCJ);

sub Lzma::Filter::ARM
{
    Lzma::Filter::BCJ::mk(LZMA_FILTER_ARM(), @_);
}

@Lzma::Filter::ARMThumb::ISA = qw(Lzma::Filter::BCJ);

sub Lzma::Filter::ARMThumb
{
    Lzma::Filter::BCJ::mk(LZMA_FILTER_ARMTHUMB(), @_);
}

@Lzma::Filter::Sparc::ISA = qw(Lzma::Filter::BCJ);

sub Lzma::Filter::Sparc
{
    Lzma::Filter::BCJ::mk(LZMA_FILTER_SPARC(), @_);
}


@Lzma::Filter::Delta::ISA = qw(Lzma::Filter);
sub Lzma::Filter::Delta
{
    #my $pkg = shift ;
    my ($got) = Compress::Raw::Lzma::ParseParameters(0,
            {
                'Type'   => [1, 1, Parse_unsigned,  LZMA_DELTA_TYPE_BYTE()],
                'Distance' => [1, 1, Parse_unsigned, LZMA_DELTA_DIST_MIN()],
            }, @_) ;

    Lzma::Filter::Delta::_mk($got->value('Type'),
                             $got->value('Distance')) ;
}

#package Lzma::Filter::SubBlock;


package Compress::Raw::Lzma;

1;

__END__


#line 1721