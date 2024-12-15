#------------------------------------------------------------------------------
# File:         Protobuf.pm
#
# Description:  Decode protocol buffer data
#
# Revisions:    2024-12-04 - P. Harvey Created
#
# Notes:        Tag definitions for Protobuf tags support additional 'signed'
#               and 'unsigned' formats for varInt (type 0) values
#
# References:   1) https://protobuf.dev/programming-guides/encoding/
#------------------------------------------------------------------------------

package Image::ExifTool::Protobuf;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

sub ProcessProtobuf($$$;$);

#------------------------------------------------------------------------------
# Read bytes from dirInfo object
# Inputs: 0) dirInfo ref, 1) number of bytes
# Returns: binary data or undef on error
sub GetBytes($$)
{
    my ($dirInfo, $n) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{Pos};
    return undef if $pos + $n > length $$dataPt;
    $$dirInfo{Pos} += $n;
    return substr($$dataPt, $pos, $n);
}

#------------------------------------------------------------------------------
# Read variable-length integer
# Inputs: 0) dirInfo ref
# Returns: integer value
sub VarInt($)
{
    my $dirInfo = shift;
    my $val = 0;
    my $shift = 0;
    for (;;) {
        my $buff = GetBytes($dirInfo, 1);
        defined $buff or return undef;
        $val += (ord($buff) & 0x7f) << $shift;
        last unless ord($buff) & 0x80;
        $shift += 7;
    }
    return $val;
}

#------------------------------------------------------------------------------
# Read protobuf record
# Inputs: 0) dirInfo ref
# Returns: 0) record payload (plus tag id and format type in list context)
# Notes: Updates dirInfo Pos to start of next record
sub ReadRecord($)
{
    my $dirInfo = shift;
    my $val = VarInt($dirInfo);
    return undef unless defined $val;
    my $id = $val >> 3;
    my $type = $val & 0x07;
    my $buff;

    if ($type == 0) {       # varInt
        $buff = VarInt($dirInfo);
    } elsif ($type == 1) {  # 64-bit number
        $buff = GetBytes($dirInfo, 8);
    } elsif ($type == 2) {  # string, bytes or protobuf
        my $len = VarInt($dirInfo);
        if ($len) {
            $buff = GetBytes($dirInfo, $len);
        } else {
            $buff = '';
        }
    } elsif ($type == 3) {  # (deprecated start group)
        $buff = '';
    } elsif ($type == 4) {  # (deprecated end group)
        $buff = '';
    } elsif ($type == 5) {  # 32-bit number
        $buff = GetBytes($dirInfo, 4);
    }
    return wantarray ? ($buff, $id, $type) : $buff;
}

#------------------------------------------------------------------------------
# Check to see if this could be a protobuf object
# Inputs: 0) data reference
# Retursn: true if this looks like a protobuf
sub IsProtobuf($)
{
    my $pt = shift;
    my $dirInfo = { DataPt => $pt, Pos => 0 };
    for (;;) {
        return 0 unless defined ReadRecord($dirInfo);
        return 1 if $$dirInfo{Pos} == length $$pt;
    }
}

#------------------------------------------------------------------------------
# Process protobuf data (eg. DJI djmd timed data from Action4 videos) (ref 1)
# Inputs: 0) ExifTool ref, 1) dirInfo ref with DataPt, DirName and Base,
#         2) tag table ptr, 3) prefix of parent protobuf ID's
# Returns: true on success
sub ProcessProtobuf($$$;$)
{
    my ($et, $dirInfo, $tagTbl, $prefix) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirName = $$dirInfo{DirName};
    my $unknown = $et->Options('Unknown') || $et->Options('Verbose');

    $$dirInfo{Pos} = $$dirInfo{DirStart} || 0; # initialize buffer Pos

    unless ($prefix) {
        $prefix = '';
        $$et{ProtocolName}{$dirName} = '*' unless defined $$et{ProtocolName}{$dirName};
        SetByteOrder('II');
    }
    # loop through protobuf records
    for (;;) {
        my $pos = $$dirInfo{Pos};
        last if $pos >= length $$dataPt;
        my ($buff, $id, $type) = ReadRecord($dirInfo);
        defined $buff or $et->Warn('Protobuf format error'), last;
        if ($type == 2 and $buff =~ /\.proto$/) {
            # save protocol name separately for directory type
            $$et{ProtocolName}{$dirName} = substr($buff, 0, -6);
            $et->HandleTag($tagTbl, Protocol => $buff);
        }
        my $tag = "$$et{ProtocolName}{$dirName}_$prefix$id";
        my $tagInfo = $$tagTbl{$tag};
        if ($tagInfo) {
            next if $type != 2 and $$tagInfo{Unknown} and not $unknown;
        } else {
            next unless $type == 2 or $unknown;
            $tagInfo = AddTagToTable($tagTbl, $tag, { Unknown => 1 });
        }
        # set IsProtobuf flag (only for Unknown tags) if necessary
        if ($type == 2 and $$tagInfo{Unknown}) {
            if ($$tagInfo{IsProtobuf}) {
                $$tagInfo{IsProtobuf} = 0 unless IsProtobuf(\$buff);
            } elsif (not defined $$tagInfo{IsProtobuf} and $buff =~ /[^\x20-\x7e]/ and
                IsProtobuf(\$buff))
            {
                $$tagInfo{IsProtobuf} = 1;
            }
            next unless $$tagInfo{IsProtobuf} or $unknown;
        }
        # format binary payload into a useful value
        my $val;
        if ($$tagInfo{Format}) {
            if ($type == 0) {
                $val = $buff;
                $val = ($val & 1) ? -($val >> 1)-1 : ($val >> 1) if $$tagInfo{Format} eq 'signed';
            } else {
                $val = ReadValue(\$buff, 0, $$tagInfo{Format}, undef, length($buff));
            }
        } elsif ($type == 0) {
            $val = $buff;
            my $signed = ($val & 1) ? -($val >> 1)-1 : ($val >> 1);
            $val .= sprintf(" (0x%x, signed $signed)", $val);
        } elsif ($type == 1) {
            $val = '0x' . unpack('H*', $buff) . ' (double ' . GetDouble(\$buff,0) . ')';
        } elsif ($type == 2) {
            if ($$tagInfo{IsProtobuf}) {
                $et->VPrint(1, "+ Protobuf $tag (" . length($buff) . " bytes)\n");
                my $addr = $$dirInfo{Base} + $$dirInfo{Pos} - length($buff);
                $et->VerboseDump(\$buff, Addr => $addr);
                my %subdir = ( DataPt => \$buff, Base => $addr, DirName => $dirName );
                ProcessProtobuf($et, \%subdir, $tagTbl, "$prefix$id-");
                next;
            } elsif ($buff !~ /[^\x20-\x7e]/) {
                $val = $buff;   # assume this is an ASCII string
            } elsif (length($buff) % 4) {
                $val = '0x' . unpack('H*', $buff);
            } else {
                $val = '0x' . join(' ', unpack('(H8)*', $buff)); # (group in 4-byte blocks)
            }
        } elsif ($type == 5) {
            $val = '0x' . unpack('H*', $buff) . ' (int32u ' . Get32u(\$buff, 0);
            $val .= ', int32s ' . Get32s(\$buff, 0) if ord(substr($buff,3,1)) & 0x80;
            $val .= ', float ' . GetFloat(\$buff, 0) . ')';
        } else {
            $val = $buff;
        }
        # get length of data in the record
        my $start = $type == 0 ? $pos + 1 : $$dirInfo{Pos} - length $buff;
        $et->HandleTag($tagTbl, $tag, $val,
            DataPt => $dataPt,
            DataPos=> $$dirInfo{Base},
            Start  => $start,
            Size   => $$dirInfo{Pos} - $start,
            Extra  => ", type=$type",
            Format => $$tagInfo{Format},
        );
    }
    # warn if we didn't finish exactly at the end of the buffer
    $et->Warn('Truncated protobuf data') unless $prefix or $$dirInfo{Pos} == length $$dataPt;
    return 1;
}

__END__

=head1 NAME

Image::ExifTool::Protobuf - Decode protocol buffer information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to decode
information in protocol buffer (protobuf) format.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://protobuf.dev/programming-guides/encoding/>

=back

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
