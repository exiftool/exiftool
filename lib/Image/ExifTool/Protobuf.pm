#------------------------------------------------------------------------------
# File:         Protobuf.pm
#
# Description:  Decode protocol buffer data
#
# Revisions:    2024-12-04 - P. Harvey Created
#
# Notes:        Tag definitions for Protobuf tags support 'signed', 'unsigned',
#               and 'int64s' formats for VARINT (type 0) values, 'int64u',
#               'int64s', 'rational64u', 'rational64s' and 'double' for I64
#               (type 1), 'undef', 'string' and 'rational' for LEN (type 2),
#               and 'int32u', 'int32s', 'rational32u', 'rational32s',
#               'fixed32u', 'fixed32s' and 'float' for I32 (type 5) values.
#
# References:   1) https://protobuf.dev/programming-guides/encoding/
#------------------------------------------------------------------------------

package Image::ExifTool::Protobuf;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.07';

sub ProcessProtobuf($$$;$);

# largest unsigned integer on this system (2^32 or 2^64 - 1)
my $intMax = ~0;

# smallest unsigned integer that we interpret as int64s (0xffffffff00000000)
my $int64sMin = 18446744069414584320;

#------------------------------------------------------------------------------
# Read bytes from dirInfo object
# Inputs: 0) dirInfo ref (with DataPt and Pos set), 1) number of bytes
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
# - sets $$dirInfo{Bit0} according to bit 0 of returned value
#   (necessary for cases where a signed integer exceeds $intMax)
sub VarInt($)
{
    my $dirInfo = shift;
    my $buff = GetBytes($dirInfo, 1);
    return undef unless defined $buff;
    my $val = ord($buff) & 0x7f;
    $$dirInfo{Bit0} = $val & 0x01;
    my $mult = 128;
    my $i = 0;
    for (;;) {
        last unless ord($buff) & 0x80;
        $buff = GetBytes($dirInfo, 1);
        return undef unless defined $buff;
        $val += (ord($buff) & 0x7f) * $mult;
        last unless ord($buff) & 0x80;
        return undef if ++$i > 32;    # set a reasonable limit
        $mult *= 128;   # (Note: don't use integer bit shift to avoid integer overflow)
    }
    return $val;
}

#------------------------------------------------------------------------------
# Read protobuf record
# Inputs: 0) dirInfo ref
# Returns: 0) record payload (plus tag id and format type in list context) or undef on error
# Notes: Updates $$dirInfo{Pos} to start of next record, and sets $$dirInfo{Bit0}
#        according to the least significant bit of type 0 (varInt) records
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
# Inputs: 0) ExifTool ref, 1) dirInfo ref with DataPt, DataPos, DirName and Base,
#         2) tag table ptr, 3) prefix of parent protobuf ID's
# Returns: true on success
sub ProcessProtobuf($$$;$)
{
    my ($et, $dirInfo, $tagTbl, $prefix) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirName = $$dirInfo{DirName};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || (length($$dataPt) - $dirStart);
    my $dirEnd = $dirStart + $dirLen;
    my $dataPos = ($$dirInfo{Base} || 0) + ($$dirInfo{DataPos} || 0);
    my $unknown = $et->Options('Unknown') || $et->Options('Verbose');

    $$dirInfo{Pos} = $$dirInfo{DirStart} || 0; # initialize buffer Pos
    $et->VerboseDir('Protobuf', undef, $dirLen);
    unless ($prefix) {
        $prefix = '';
        $$et{ProtoPrefix}{$dirName} = '' unless defined $$et{ProtoPrefix}{$dirName};
        SetByteOrder('II');
    }
    # prefix for unknown tags
    my $unkPre = $$tagTbl{TAG_PREFIX} ? $$tagTbl{TAG_PREFIX} . '_' : 'Protobuf ';

    # loop through protobuf records
    for (;;) {
        my $pos = $$dirInfo{Pos};
        last if $pos >= $dirEnd;
        my ($buff, $id, $type) = ReadRecord($dirInfo);
        defined $buff or $et->Warn('Protobuf format error'), last;
        if ($type == 2 and $buff =~ /\.proto$/) {
            # save protocol name separately for directory type
            $$et{ProtoPrefix}{$dirName} = substr($buff, 0, -6) . '_';
            $et->HandleTag($tagTbl, Protocol => $buff);
        }
        my $tag = "$$et{ProtoPrefix}{$dirName}$prefix$id";
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
                if ($$tagInfo{Format} eq 'signed') {
                    if ($val > $intMax) {
                        # use double math (15 decimal digits precision)
                        $val = $$dirInfo{Bit0} ? -int($val / 2) - 1 : $val / 2;
                    } else {
                        # use integer math
                        $val = ($val & 1) ? -($val >> 1)-1 : ($val >> 1);
                    }
                } elsif ($$tagInfo{Format} eq 'int64s' and $val >= $int64sMin) {
                    # hack for DJI drones which store 64-bit signed integers improperly
                    # (just toss upper 32 bits which should be all 1's anyway)
                    # Note: do the two subtractions because $int64sMin + 4294967296
                    # is too large for a 64-bit integer
                    $val = $val - $int64sMin - 4294967296;
                }
            } elsif ($type == 2 and $$tagInfo{Format} eq 'rational') {
                my $dir = { DataPt => \$buff, Pos => 0 };
                my $num = VarInt($dir);
                my $den = VarInt($dir);
                $val = (defined $num and $den) ? $num/$den : 'err';
            } else {
                $val = ReadValue(\$buff, 0, $$tagInfo{Format}, undef, length($buff));
            }
        } elsif ($type == 0) { # varInt
            $val = $buff;
            my $hex = sprintf('%x', $val);
            if ($val >= $int64sMin) {
                my $s64 = $val - $int64sMin - 4294967296;
                $val .= " (0x$hex, int64s $s64)";
            } else {
                my $signed;
                if ($val > $intMax) {
                    $signed = $$dirInfo{Bit0} ? -int($val / 2) - 1 : $val / 2;
                } else {
                    $signed = ($val & 1) ? -($val >> 1)-1 : ($val >> 1);
                }
                $val .= " (0x$hex, signed $signed)";
            }
        } elsif ($type == 1) { # 64-bit number
            $val = '0x' . unpack('H*', $buff) . ' (double ' . GetDouble(\$buff,0) . ')';
        } elsif ($type == 2) { # string, bytes or protobuf
            if ($$tagInfo{SubDirectory}) {
                # (fall through to process known SubDirectory)
            } elsif ($$tagInfo{IsProtobuf}) {
                # process Unknown protobuf directories
                $et->VPrint(1, "$$et{INDENT}${unkPre}$tag (" . length($buff) . " bytes) -->\n");
                my $addr = $dataPos + $$dirInfo{Pos} - length($buff);
                $et->VerboseDump(\$buff, Addr => $addr, Prefix => $$et{INDENT});
                my %subdir = ( DataPt => \$buff, DataPos => $addr, DirName => $dirName );
                $$et{INDENT} .= '| ';
                ProcessProtobuf($et, \%subdir, $tagTbl, "$prefix$id-");
                $$et{INDENT} = substr($$et{INDENT}, 0, -2);
                next;
            } else {
                # check for rational value (2 varInt values)
                my $rat;
                my %dir = ( DataPt => \$buff, Pos => 0 );
                my $num = VarInt(\%dir);
                if (defined $num) {
                    my $denom = VarInt(\%dir);
                    $rat = " (rational $num/$denom)" if $denom and $dir{Pos} == length($buff);
                }
                if ($buff !~ /[^\r\n\t\x20-\x7e]/) {
                    $val = $buff;   # assume this is an ASCII string
                } elsif (length($buff) % 4) {
                    $val = '0x' . unpack('H*', $buff);
                } else {
                    my $n = length($buff) / 4;
                    # (do this instead of '(H8)*' because older Perl version didn't support this)
                    $val = '0x' . join(' ', unpack("(H8)$n", $buff)); # (group in 4-byte blocks)
                }
                $val .= $rat if $rat;
            }
        } elsif ($type == 5) { # 32-bit number
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
            DataPos=> $dataPos,
            Start  => $start,
            Size   => $$dirInfo{Pos} - $start,
            Extra  => ", type=$type",
            Format => $$tagInfo{Format},
        );
    }
    # warn if we didn't finish exactly at the end of the buffer
    $et->Warn('Truncated protobuf data') unless $prefix or $$dirInfo{Pos} == $dirEnd;
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

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://protobuf.dev/programming-guides/encoding/>

=back

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
