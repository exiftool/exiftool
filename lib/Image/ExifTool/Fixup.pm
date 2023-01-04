#------------------------------------------------------------------------------
# File:         Fixup.pm
#
# Description:  Utility to handle pointer fixups
#
# Revisions:    01/19/2005 - P. Harvey Created
#               04/11/2005 - P. Harvey Allow fixups to be tagged with a marker,
#                            and add new marker-related routines
#               06/21/2006 - P. Harvey Patch to work with negative offsets
#               07/07/2006 - P. Harvey Added support for 16-bit pointers
#               02/19/2013 - P. Harvey Added IsEmpty()
#
# Data Members:
#
#   Start     - Position in data where a zero pointer points to.
#   Shift     - Amount to shift offsets (relative to Start).
#   Fixups    - List of Fixup object references to to shift relative to this Fixup.
#   Pointers  - Hash of references to fixup pointer arrays, keyed by ByteOrder
#               string (with "2" added if pointer is 16-bit [default is 32-bit],
#               plus "_$marker" suffix if tagged with a marker name).
#
# Procedure:
#
#            1. Create a Fixup object for each data block containing pointers
#            2. Call AddFixup with the offset of each pointer in the block
#               - pointer is assumed int32u with the current byte order
#               - may also be called with a fixup reference for contained blocks
#            3. Add the necessary pointer offset to $$fixup{Shift}
#            4. Add data size to $$fixup{Start} if data is added before the block
#               - automatically also shifts pointers by this amount
#            5. Call ApplyFixup to apply the fixup to all pointers
#               - resets Shift and Start to 0 after applying fixup
#------------------------------------------------------------------------------

package Image::ExifTool::Fixup;

use strict;
use Image::ExifTool qw(GetByteOrder SetByteOrder Get32u Get32s Set32u
                       Get16u Get16s Set16u);
use vars qw($VERSION);

$VERSION = '1.05';

sub AddFixup($$;$$);
sub ApplyFixup($$);
sub Dump($;$);

#------------------------------------------------------------------------------
# New - create new Fixup object
# Inputs: 0) reference to Fixup object or Fixup class name
sub new
{
    local $_;
    my $that = shift;
    my $class = ref($that) || $that || 'Image::ExifTool::Fixup';
    my $self = bless {}, $class;

    # initialize required members
    $self->{Start} = 0;
    $self->{Shift} = 0;

    return $self;
}

#------------------------------------------------------------------------------
# Clone this object
# Inputs: 0) reference to Fixup object or Fixup class name
# Returns: reference to new Fixup object
sub Clone($)
{
    my $self = shift;
    my $clone = new Image::ExifTool::Fixup;
    $clone->{Start} = $self->{Start};
    $clone->{Shift} = $self->{Shift};
    my $phash = $self->{Pointers};
    if ($phash) {
        $clone->{Pointers} = { };
        my $byteOrder;
        foreach $byteOrder (keys %$phash) {
            my @pointers = @{$phash->{$byteOrder}};
            $clone->{Pointers}->{$byteOrder} = \@pointers;
        }
    }
    if ($self->{Fixups}) {
        $clone->{Fixups} = [ ];
        my $subFixup;
        foreach $subFixup (@{$self->{Fixups}}) {
            push @{$clone->{Fixups}}, $subFixup->Clone();
        }
    }
    return $clone;
}

#------------------------------------------------------------------------------
# Add fixup pointer or another fixup object below this one
# Inputs: 0) Fixup object reference
#         1) Scalar for pointer offset, or reference to Fixup object
#         2) Optional marker name for the pointer
#         3) Optional pointer format ('int16u' or 'int32u', defaults to 'int32u')
# Notes: Byte ordering must be set properly for the pointer being added (must keep
# track of the byte order of each offset since MakerNotes may have different byte order!)
sub AddFixup($$;$$)
{
    my ($self, $pointer, $marker, $format) = @_;
    if (ref $pointer) {
        $self->{Fixups} or $self->{Fixups} = [ ];
        push @{$self->{Fixups}}, $pointer;
    } else {
        my $byteOrder = GetByteOrder();
        if (defined $format) {
            if ($format eq 'int16u') {
                $byteOrder .= '2';
            } elsif ($format ne 'int32u') {
                warn "Bad Fixup pointer format $format\n";
            }
        }
        $byteOrder .= "_$marker" if defined $marker;
        my $phash = $self->{Pointers};
        $phash or $phash = $self->{Pointers} = { };
        $phash->{$byteOrder} or $phash->{$byteOrder} = [ ];
        push @{$phash->{$byteOrder}}, $pointer;
    }
}

#------------------------------------------------------------------------------
# fix up pointer offsets
# Inputs: 0) Fixup object reference, 1) data reference
# Outputs: Collapses fixup hierarchy into linear lists of fixup pointers
sub ApplyFixup($$)
{
    my ($self, $dataPt) = @_;

    my $start = $self->{Start};
    my $shift = $self->{Shift} + $start;   # make shift relative to start
    my $phash = $self->{Pointers};

    # fix up pointers in this fixup
    if ($phash and ($start or $shift)) {
        my $saveOrder = GetByteOrder(); # save original byte ordering
        my ($byteOrder, $ptr);
        foreach $byteOrder (keys %$phash) {
            SetByteOrder(substr($byteOrder,0,2));
            # apply the fixup offset shift (must get as signed integer
            # to avoid overflow in case it was negative before)
            my ($get, $set) = ($byteOrder =~ /^(II2|MM2)/) ?
                              (\&Get16s, \&Set16u) : (\&Get32s, \&Set32u);
            foreach $ptr (@{$phash->{$byteOrder}}) {
                $ptr += $start;         # update pointer to new start location
                next unless $shift;
                &$set(&$get($dataPt, $ptr) + $shift, $dataPt, $ptr);
            }
        }
        SetByteOrder($saveOrder);       # restore original byte ordering
    }
    # recurse into contained fixups
    if ($self->{Fixups}) {
        # create our pointer hash if it doesn't exist
        $phash or $phash = $self->{Pointers} = { };
        # loop through all contained fixups
        my $subFixup;
        foreach $subFixup (@{$self->{Fixups}}) {
            # adjust the subfixup start and shift
            $subFixup->{Start} += $start;
            $subFixup->{Shift} += $shift - $start;
            # recursively apply contained fixups
            ApplyFixup($subFixup, $dataPt);
            my $shash = $subFixup->{Pointers} or next;
            # add all pointers to our collapsed lists
            my $byteOrder;
            foreach $byteOrder (keys %$shash) {
                $phash->{$byteOrder} or $phash->{$byteOrder} = [ ];
                push @{$phash->{$byteOrder}}, @{$shash->{$byteOrder}};
                delete $shash->{$byteOrder};
            }
            delete $subFixup->{Pointers};
        }
        delete $self->{Fixups};    # remove our contained fixups
    }
    # reset our Start/Shift for the collapsed fixup
    $self->{Start} = $self->{Shift} = 0;
}

#------------------------------------------------------------------------------
# Is this Fixup empty?
# Inputs: 0) Fixup object ref
# Returns: True if there are no offsets to fix
sub IsEmpty($)
{
    my $self = shift;
    my $phash = $self->{Pointers};
    if ($phash) {
        my $key;
        foreach $key (keys %$phash) {
            next unless ref $$phash{$key} eq 'ARRAY';
            return 0 if @{$$phash{$key}};
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Does specified marker exist?
# Inputs: 0) Fixup object reference, 1) marker name
# Returns: True if fixup contains specified marker name
sub HasMarker($$)
{
    my ($self, $marker) = @_;
    my $phash = $self->{Pointers};
    return 0 unless $phash;
    return 1 if grep /_$marker$/, keys %$phash;
    return 0 unless $self->{Fixups};
    my $subFixup;
    foreach $subFixup (@{$self->{Fixups}}) {
        return 1 if $subFixup->HasMarker($marker);
    }
    return 0;
}

#------------------------------------------------------------------------------
# Set all marker pointers to specified value
# Inputs: 0) Fixup object reference, 1) data reference
#         2) marker name, 3) pointer value, 4) offset to start of data
sub SetMarkerPointers($$$$;$)
{
    my ($self, $dataPt, $marker, $value, $startOffset) = @_;
    my $start = $self->{Start} + ($startOffset || 0);
    my $phash = $self->{Pointers};

    if ($phash) {
        my $saveOrder = GetByteOrder(); # save original byte ordering
        my ($byteOrder, $ptr);
        foreach $byteOrder (keys %$phash) {
            next unless $byteOrder =~ /^(II|MM)(2?)_$marker$/;
            SetByteOrder($1);
            my $set = $2 ? \&Set16u : \&Set32u;
            foreach $ptr (@{$phash->{$byteOrder}}) {
                &$set($value, $dataPt, $ptr + $start);
            }
        }
        SetByteOrder($saveOrder);       # restore original byte ordering
    }
    if ($self->{Fixups}) {
        my $subFixup;
        foreach $subFixup (@{$self->{Fixups}}) {
            $subFixup->SetMarkerPointers($dataPt, $marker, $value, $start);
        }
    }
}

#------------------------------------------------------------------------------
# Get pointer values for specified marker
# Inputs: 0) Fixup object reference, 1) data reference,
#         2) marker name, 3) offset to start of data
# Returns: List of marker pointers in list context, or first marker pointer otherwise
sub GetMarkerPointers($$$;$)
{
    my ($self, $dataPt, $marker, $startOffset) = @_;
    my $start = $self->{Start} + ($startOffset || 0);
    my $phash = $self->{Pointers};
    my @pointers;

    if ($phash) {
        my $saveOrder = GetByteOrder();
        my ($byteOrder, $ptr);
        foreach $byteOrder (grep /_$marker$/, keys %$phash) {
            SetByteOrder(substr($byteOrder,0,2));
            my $get = ($byteOrder =~ /^(II2|MM2)/) ? \&Get16u : \&Get32u;
            foreach $ptr (@{$phash->{$byteOrder}}) {
                push @pointers, &$get($dataPt, $ptr + $start);
            }
        }
        SetByteOrder($saveOrder);       # restore original byte ordering
    }
    if ($self->{Fixups}) {
        my $subFixup;
        foreach $subFixup (@{$self->{Fixups}}) {
            push @pointers, $subFixup->GetMarkerPointers($dataPt, $marker, $start);
        }
    }
    return @pointers if wantarray;
    return $pointers[0];
}

#------------------------------------------------------------------------------
# Dump fixup to console for debugging
# Inputs: 0) Fixup object reference, 1) optional initial indent string
sub Dump($;$)
{
    my ($self, $indent) = @_;
    $indent or $indent = '';
    printf "${indent}Fixup start=0x%x shift=0x%x\n", $self->{Start}, $self->{Shift};
    my $phash = $self->{Pointers};
    if ($phash) {
        my $byteOrder;
        foreach $byteOrder (sort keys %$phash) {
            print "$indent  $byteOrder: ", join(' ',@{$phash->{$byteOrder}}),"\n";
        }
    }
    if ($self->{Fixups}) {
        my $subFixup;
        foreach $subFixup (@{$self->{Fixups}}) {
            Dump($subFixup, $indent . '  ');
        }
    }
}


1; # end

__END__

=head1 NAME

Image::ExifTool::Fixup - Utility to handle pointer fixups

=head1 SYNOPSIS

    use Image::ExifTool::Fixup;

    $fixup = new Image::ExifTool::Fixup;

    # add a new fixup to a pointer at the specified offset in data
    $fixup->AddFixup($offset);

    # add a new Fixup object to the tree
    $fixup->AddFixup($subFixup);

    $fixup->{Start} += $shift1;   # shift pointer offsets and values

    $fixup->{Shift} += $shift2;   # shift pointer values only

    # recursively apply fixups to the specified data
    $fixup->ApplyFixups(\$data);

    $fixup->Dump();               # dump debugging information

    $fixup->IsEmpty();            # return true if no offsets to fix

=head1 DESCRIPTION

This module contains the code to keep track of pointers in memory and to
shift these pointers as required.  It is used by ExifTool to maintain the
pointers in image file directories (IFD's).

=head1 NOTES

Keeps track of pointers with different byte ordering, and relies on
Image::ExifTool::GetByteOrder() to determine the current byte ordering
when adding new pointers to a fixup.

Maintains a hierarchical list of fixups so that the whole hierarchy can
be shifted by a simple shift at the base.  Hierarchy is collapsed to a
linear list when ApplyFixups() is called.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
