#-*- perl -*-

package Unicode::LineBreak;
require 5.008;

### Pragmas:
use strict;
use warnings;
use vars qw($VERSION @EXPORT_OK @ISA $Config @Config);

### Exporting:
use Exporter;
our @EXPORT_OK = qw(UNICODE_VERSION SOMBOK_VERSION context);
our %EXPORT_TAGS = ('all' => [@EXPORT_OK]);

### Inheritance:
our @ISA = qw(Exporter);

### Other modules:
use Carp qw(croak carp);
use Encode qw(is_utf8);
use MIME::Charset;
use Unicode::GCString;

### Globals

### The package version
our $VERSION = '2019.001';

### Public Configuration Attributes
our @Config = (
    BreakIndent => 'YES',
    CharMax => 998,
    ColMax => 76,
    ColMin => 0,
    ComplexBreaking => 'YES',
    Context => 'NONEASTASIAN',
    EAWidth => undef,
    Format => 'SIMPLE',
    HangulAsAL => 'NO',
    LBClass => undef,
    LegacyCM => 'YES',
    Newline => "\n",
    Prep => undef,
    Sizing => 'UAX11',
    Urgent => undef,
    ViramaAsJoiner => 'YES',
);
our $Config = {};
eval { require Unicode::LineBreak::Defaults; };
push @Config, (%$Config);

### Exportable constants
use Unicode::LineBreak::Constants;
use constant 1.01;
my $package = __PACKAGE__;
my @consts = grep { s/^${package}::(\w\w+)$/$1/ } keys %constant::declared;
push @EXPORT_OK, @consts;
push @{$EXPORT_TAGS{'all'}}, @consts;

### Load XS module
require XSLoader;
XSLoader::load('Unicode::LineBreak', $VERSION);

### Load dynamic constants
foreach my $p ((['EA', EAWidths()], ['LB', LBClasses()])) {
    my $prop = shift @{$p};
    my $idx = 0;
    foreach my $val (@{$p}) {
        no strict;
        my $const = "${prop}_${val}";
        *{$const} = eval "sub { $idx }";
        push @EXPORT_OK, $const;
        push @{$EXPORT_TAGS{'all'}}, $const;
        $idx++;
    }
}

### Privates
my $EASTASIAN_CHARSETS = qr{
    ^BIG5 |
    ^CP9\d\d |
    ^EUC- |
    ^GB18030 | ^GB2312 | ^GBK |
    ^HZ |
    ^ISO-2022- |
    ^KS_C_5601 |
    ^SHIFT_JIS
}ix;

my $EASTASIAN_LANGUAGES = qr{
    ^AIN |
    ^JA\b | ^JPN |
    ^KO\b | ^KOR |
    ^ZH\b | ^CHI
}ix;

use overload
    '%{}' => \&as_hashref,
    '${}' => \&as_scalarref,
    '""' => \&as_string,
    ;

sub new {
    my $class = shift;

    my $self = __PACKAGE__->_new();
    $self->config(@Config);
    $self->config(@_);
    bless $self, $class;
}

sub config ($@) {
    my $self = shift;

    # Get config.
    if (scalar @_ == 1) {
        my $k = shift;
        my $ret;

        if (uc $k eq uc 'CharactersMax') {
            return $self->_config('CharMax');
        } elsif (uc $k eq uc 'ColumnsMax') {
            return $self->_config('ColMax');
        } elsif (uc $k eq uc 'ColumnsMin') {
            return $self->_config('ColMin');
        } elsif (uc $k eq uc 'SizingMethod') {
            return $self->_config('Sizing');
        } elsif (uc $k eq uc 'TailorEA') {
            carp "$k is obsoleted.  Use EAWidth";
            $ret = $self->_config('EAWidth');
            if (! defined $ret) {
                return [];
            } else {
                return [map { ($_->[0] => $_->[1]) } @{$ret}];
            }
        } elsif (uc $k eq uc 'TailorLB') {
            carp "$k is obsoleted.  Use LBClass";
            $ret = $self->_config('LBClass');
            if (! defined $ret) {
                return [];
            } else {
                return [map { ($_->[0] => $_->[1]) } @{$ret}];
            }
        } elsif (uc $k eq uc 'UrgentBreaking') {
            return $self->_config('Urgent');
        } elsif (uc $k eq uc 'UserBreaking') {
            carp "$k is obsoleted.  Use Prep";
            $ret = $self->_config('Prep');
            if (! defined $ret) {
                return [];
            } else {
                return $ret;
            }
        } else {
            return $self->_config($k);
        }
    }

    # Set config.
    my @config = ();
    while (0 < scalar @_) {
        my $k = shift;
        my $v = shift;

        if (uc $k eq uc 'CharactersMax') {
            push @config, 'CharMax' => $v;
        } elsif (uc $k eq uc 'ColumnsMax') {
            push @config, 'ColMax' => $v;
        } elsif (uc $k eq uc 'ColumnsMin') {
            push @config, 'ColMin' => $v;
        } elsif (uc $k eq uc 'SizingMethod') {
            push @config, 'Sizing' => $v;
        } elsif (uc $k eq uc 'TailorLB') {
            carp "$k is obsoleted.  Use LBClass";
            push @config, 'LBClass' => undef;
            if (! defined $v) {
                ;
            } else {
                my @v = @{$v};
                while (scalar(@v)) {
                    my $k = shift @v;
                    my $v = shift @v;
                    push @config, 'LBClass' => [ $k => $v ];
                }
            }
        } elsif (uc $k eq uc 'TailorEA') {
            carp "$k is obsoleted.  Use EAWidth";
            push @config, 'EAWidth' => undef;
            if (! defined $v) {
                ;
            } else {
                my @v = @{$v};
                while (scalar(@v)) {
                    my $k = shift @v;
                    my $v = shift @v;
                    push @config, 'EAWidth' => [ $k => $v ];
                }
            }
        } elsif (uc $k eq uc 'UserBreaking') {
            carp "$k is obsoleted.  Use Prep";
            push @config, 'Prep' => undef;
            if (! defined $v) {
                ;
            } elsif (ref $v eq 'ARRAY') {
                push @config, map { ('Prep' => $_) } @{$v};
            } else {
                push @config, 'Prep' => $v;
            }
        } elsif (uc $k eq uc 'UrgentBreaking') {
            push @config, 'Urgent' => $v;
        } else {
            push @config, $k => $v;
        }
    }

    $self->_config(@config) if scalar @config;
}

sub context (@) {
    my %opts = @_;

    my $charset;
    my $language;
    my $context;
    foreach my $k (keys %opts) {
        if (uc $k eq 'CHARSET') {
            if (ref $opts{$k}) {
                $charset = $opts{$k}->as_string;
            } else {
                $charset = MIME::Charset->new($opts{$k})->as_string;
            }
        } elsif (uc $k eq 'LANGUAGE') {
            $language = uc $opts{$k};
            $language =~ s/_/-/;
        }
    }
    if ($charset and $charset =~ /$EASTASIAN_CHARSETS/) {
        $context = 'EASTASIAN';
    } elsif ($language and $language =~ /$EASTASIAN_LANGUAGES/) {
        $context = 'EASTASIAN';
    } else {
        $context = 'NONEASTASIAN';
    }
    $context;
}

1;
