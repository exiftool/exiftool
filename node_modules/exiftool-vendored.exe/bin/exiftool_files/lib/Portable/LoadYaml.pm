package Portable::LoadYaml;

### UGLY HACK: these functions where completely copied from Parse::CPAN::Meta

use 5.008;
use strict;
use warnings;

our $VERSION = '1.23';

sub load_file {
    my $file = shift;
    my $self = __PACKAGE__->_load_file($file);
    return $self->[-1];
}

#####################################################################
# Constants

# Printed form of the unprintable characters in the lowest range
# of ASCII characters, listed by ASCII ordinal position.
my @UNPRINTABLE = qw(
    0    x01  x02  x03  x04  x05  x06  a
    b    t    n    v    f    r    x0E  x0F
    x10  x11  x12  x13  x14  x15  x16  x17
    x18  x19  x1A  e    x1C  x1D  x1E  x1F
);

# Printable characters for escapes
my %UNESCAPES = (
    0 => "\x00", z => "\x00", N    => "\x85",
    a => "\x07", b => "\x08", t    => "\x09",
    n => "\x0a", v => "\x0b", f    => "\x0c",
    r => "\x0d", e => "\x1b", '\\' => '\\',
);

# These 3 values have special meaning when unquoted and using the
# default YAML schema. They need quotes if they are strings.
my %QUOTE = map { $_ => 1 } qw{
    null true false
};

# The commented out form is simpler, but overloaded the Perl regex
# engine due to recursion and backtracking problems on strings
# larger than 32,000ish characters. Keep it for reference purposes.
# qr/\"((?:\\.|[^\"])*)\"/
my $re_capture_double_quoted = qr/\"([^\\"]*(?:\\.[^\\"]*)*)\"/;
my $re_capture_single_quoted = qr/\'([^\']*(?:\'\'[^\']*)*)\'/;
# unquoted re gets trailing space that needs to be stripped
my $re_capture_unquoted_key  = qr/([^:]+(?::+\S[^:]*)*)(?=\s*\:(?:\s+|$))/;
my $re_trailing_comment      = qr/(?:\s+\#.*)?/;
my $re_key_value_separator   = qr/\s*:(?:\s+(?:\#.*)?|$)/;

###
# Loader functions:

# Create an object from a file
sub _load_file {
    my $class = ref $_[0] ? ref shift : shift;

    # Check the file
    my $file = shift or $class->_error( 'You did not specify a file name' );
    $class->_error( "File '$file' does not exist" )
        unless -e $file;
    $class->_error( "'$file' is a directory, not a file" )
        unless -f _;
    $class->_error( "Insufficient permissions to read '$file'" )
        unless -r _;

    # Open unbuffered
    open( my $fh, "<:unix", $file );
    unless ( $fh ) {
        $class->_error("Failed to open file '$file': $!");
    }

    # slurp the contents
    my $contents = eval {
        use warnings FATAL => 'utf8';
        local $/;
        <$fh>
    };
    if ( my $err = $@ ) {
        $class->_error("Error reading from file '$file': $err");
    }

    # close the file (release the lock)
    unless ( close $fh ) {
        $class->_error("Failed to close file '$file': $!");
    }

    $class->_load_string( $contents );
}

# Create an object from a string
sub _load_string {
    my $class  = ref $_[0] ? ref shift : shift;
    my $self   = bless [], $class;
    my $string = $_[0];
    eval {
        unless ( defined $string ) {
            die \"Did not provide a string to load";
        }

        # Check if Perl has it marked as characters, but it's internally
        # inconsistent.  E.g. maybe latin1 got read on a :utf8 layer
        if ( utf8::is_utf8($string) && ! utf8::valid($string) ) {
            die \<<'...';
Read an invalid UTF-8 string (maybe mixed UTF-8 and 8-bit character set).
Did you decode with lax ":utf8" instead of strict ":encoding(UTF-8)"?
...
        }

        # Ensure Unicode character semantics, even for 0x80-0xff
        utf8::upgrade($string);

        # Check for and strip any leading UTF-8 BOM
        $string =~ s/^\x{FEFF}//;

        # Check for some special cases
        return $self unless length $string;

        # Split the file into lines
        my @lines = grep { ! /^\s*(?:\#.*)?\z/ }
                split /(?:\015{1,2}\012|\015|\012)/, $string;

        # Strip the initial YAML header
        @lines and $lines[0] =~ /^\%YAML[: ][\d\.]+.*\z/ and shift @lines;

        # A nibbling parser
        my $in_document = 0;
        while ( @lines ) {
            # Do we have a document header?
            if ( $lines[0] =~ /^---\s*(?:(.+)\s*)?\z/ ) {
                # Handle scalar documents
                shift @lines;
                if ( defined $1 and $1 !~ /^(?:\#.+|\%YAML[: ][\d\.]+)\z/ ) {
                    push @$self,
                        $self->_load_scalar( "$1", [ undef ], \@lines );
                    next;
                }
                $in_document = 1;
            }

            if ( ! @lines or $lines[0] =~ /^(?:---|\.\.\.)/ ) {
                # A naked document
                push @$self, undef;
                while ( @lines and $lines[0] !~ /^---/ ) {
                    shift @lines;
                }
                $in_document = 0;

            # XXX The final '-+$' is to look for -- which ends up being an
            # error later.
            } elsif ( ! $in_document && @$self ) {
                # only the first document can be explicit
                die \"failed to classify the line '$lines[0]'";
            } elsif ( $lines[0] =~ /^\s*\-(?:\s|$|-+$)/ ) {
                # An array at the root
                my $document = [ ];
                push @$self, $document;
                $self->_load_array( $document, [ 0 ], \@lines );

            } elsif ( $lines[0] =~ /^(\s*)\S/ ) {
                # A hash at the root
                my $document = { };
                push @$self, $document;
                $self->_load_hash( $document, [ length($1) ], \@lines );

            } else {
                # Shouldn't get here.  @lines have whitespace-only lines
                # stripped, and previous match is a line with any
                # non-whitespace.  So this clause should only be reachable via
                # a perlbug where \s is not symmetric with \S

                # uncoverable statement
                die \"failed to classify the line '$lines[0]'";
            }
        }
    };
    if ( ref $@ eq 'SCALAR' ) {
        $self->_error(${$@});
    } elsif ( $@ ) {
        $self->_error($@);
    }

    return $self;
}

sub _unquote_single {
    my ($self, $string) = @_;
    return '' unless length $string;
    $string =~ s/\'\'/\'/g;
    return $string;
}

sub _unquote_double {
    my ($self, $string) = @_;
    return '' unless length $string;
    $string =~ s/\\"/"/g;
    $string =~
        s{\\([Nnever\\fartz0b]|x([0-9a-fA-F]{2}))}
         {(length($1)>1)?pack("H2",$2):$UNESCAPES{$1}}gex;
    return $string;
}

# Load a YAML scalar string to the actual Perl scalar
sub _load_scalar {
    my ($self, $string, $indent, $lines) = @_;

    # Trim trailing whitespace
    $string =~ s/\s*\z//;

    # Explitic null/undef
    return undef if $string eq '~';

    # Single quote
    if ( $string =~ /^$re_capture_single_quoted$re_trailing_comment\z/ ) {
        return $self->_unquote_single($1);
    }

    # Double quote.
    if ( $string =~ /^$re_capture_double_quoted$re_trailing_comment\z/ ) {
        return $self->_unquote_double($1);
    }

    # Special cases
    if ( $string =~ /^[\'\"!&]/ ) {
        die \"does not support a feature in line '$string'";
    }
    return {} if $string =~ /^{}(?:\s+\#.*)?\z/;
    return [] if $string =~ /^\[\](?:\s+\#.*)?\z/;

    # Regular unquoted string
    if ( $string !~ /^[>|]/ ) {
        die \"found illegal characters in plain scalar: '$string'"
            if $string =~ /^(?:-(?:\s|$)|[\@\%\`])/ or
                $string =~ /:(?:\s|$)/;
        $string =~ s/\s+#.*\z//;
        return $string;
    }

    # Error
    die \"failed to find multi-line scalar content" unless @$lines;

    # Check the indent depth
    $lines->[0]   =~ /^(\s*)/;
    $indent->[-1] = length("$1");
    if ( defined $indent->[-2] and $indent->[-1] <= $indent->[-2] ) {
        die \"found bad indenting in line '$lines->[0]'";
    }

    # Pull the lines
    my @multiline = ();
    while ( @$lines ) {
        $lines->[0] =~ /^(\s*)/;
        last unless length($1) >= $indent->[-1];
        push @multiline, substr(shift(@$lines), length($1));
    }

    my $j = (substr($string, 0, 1) eq '>') ? ' ' : "\n";
    my $t = (substr($string, 1, 1) eq '-') ? ''  : "\n";
    return join( $j, @multiline ) . $t;
}

# Load an array
sub _load_array {
    my ($self, $array, $indent, $lines) = @_;

    while ( @$lines ) {
        # Check for a new document
        if ( $lines->[0] =~ /^(?:---|\.\.\.)/ ) {
            while ( @$lines and $lines->[0] !~ /^---/ ) {
                shift @$lines;
            }
            return 1;
        }

        # Check the indent level
        $lines->[0] =~ /^(\s*)/;
        if ( length($1) < $indent->[-1] ) {
            return 1;
        } elsif ( length($1) > $indent->[-1] ) {
            die \"found bad indenting in line '$lines->[0]'";
        }

        if ( $lines->[0] =~ /^(\s*\-\s+)[^\'\"]\S*\s*:(?:\s+|$)/ ) {
            # Inline nested hash
            my $indent2 = length("$1");
            $lines->[0] =~ s/-/ /;
            push @$array, { };
            $self->_load_hash( $array->[-1], [ @$indent, $indent2 ], $lines );

        } elsif ( $lines->[0] =~ /^\s*\-\s*\z/ ) {
            shift @$lines;
            unless ( @$lines ) {
                push @$array, undef;
                return 1;
            }
            if ( $lines->[0] =~ /^(\s*)\-/ ) {
                my $indent2 = length("$1");
                if ( $indent->[-1] == $indent2 ) {
                    # Null array entry
                    push @$array, undef;
                } else {
                    # Naked indenter
                    push @$array, [ ];
                    $self->_load_array(
                        $array->[-1], [ @$indent, $indent2 ], $lines
                    );
                }

            } elsif ( $lines->[0] =~ /^(\s*)\S/ ) {
                push @$array, { };
                $self->_load_hash(
                    $array->[-1], [ @$indent, length("$1") ], $lines
                );

            } else {
                die \"failed to classify line '$lines->[0]'";
            }

        } elsif ( $lines->[0] =~ /^\s*\-(\s*)(.+?)\s*\z/ ) {
            # Array entry with a value
            shift @$lines;
            push @$array, $self->_load_scalar(
                "$2", [ @$indent, undef ], $lines
            );

        } elsif ( defined $indent->[-2] and $indent->[-1] == $indent->[-2] ) {
            # This is probably a structure like the following...
            # ---
            # foo:
            # - list
            # bar: value
            #
            # ... so lets return and let the hash parser handle it
            return 1;

        } else {
            die \"failed to classify line '$lines->[0]'";
        }
    }

    return 1;
}

# Load a hash
sub _load_hash {
    my ($self, $hash, $indent, $lines) = @_;

    while ( @$lines ) {
        # Check for a new document
        if ( $lines->[0] =~ /^(?:---|\.\.\.)/ ) {
            while ( @$lines and $lines->[0] !~ /^---/ ) {
                shift @$lines;
            }
            return 1;
        }

        # Check the indent level
        $lines->[0] =~ /^(\s*)/;
        if ( length($1) < $indent->[-1] ) {
            return 1;
        } elsif ( length($1) > $indent->[-1] ) {
            die \"found bad indenting in line '$lines->[0]'";
        }

        # Find the key
        my $key;

        # Quoted keys
        if ( $lines->[0] =~
            s/^\s*$re_capture_single_quoted$re_key_value_separator//
        ) {
            $key = $self->_unquote_single($1);
        }
        elsif ( $lines->[0] =~
            s/^\s*$re_capture_double_quoted$re_key_value_separator//
        ) {
            $key = $self->_unquote_double($1);
        }
        elsif ( $lines->[0] =~
            s/^\s*$re_capture_unquoted_key$re_key_value_separator//
        ) {
            $key = $1;
            $key =~ s/\s+$//;
        }
        elsif ( $lines->[0] =~ /^\s*\?/ ) {
            die \"does not support a feature in line '$lines->[0]'";
        }
        else {
            die \"failed to classify line '$lines->[0]'";
        }

        # Do we have a value?
        if ( length $lines->[0] ) {
            # Yes
            $hash->{$key} = $self->_load_scalar(
                shift(@$lines), [ @$indent, undef ], $lines
            );
        } else {
            # An indent
            shift @$lines;
            unless ( @$lines ) {
                $hash->{$key} = undef;
                return 1;
            }
            if ( $lines->[0] =~ /^(\s*)-/ ) {
                $hash->{$key} = [];
                $self->_load_array(
                    $hash->{$key}, [ @$indent, length($1) ], $lines
                );
            } elsif ( $lines->[0] =~ /^(\s*)./ ) {
                my $indent2 = length("$1");
                if ( $indent->[-1] >= $indent2 ) {
                    # Null hash entry
                    $hash->{$key} = undef;
                } else {
                    $hash->{$key} = {};
                    $self->_load_hash(
                        $hash->{$key}, [ @$indent, length($1) ], $lines
                    );
                }
            }
        }
    }

    return 1;
}

1;