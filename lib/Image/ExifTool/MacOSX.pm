#------------------------------------------------------------------------------
# File:         MacOSX.pm
#
# Description:  Read/write Mac OS X system tags
#
# Revisions:    2017/03/01 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::MacOSX;
use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

sub MDItemLocalTime($);

# extra Mac OS X tags
my %extraTags = (
#
# "mdls" tags
#
    MDItemFinderComment => {
        Groups => { 1 => 'System', 2 => 'Other' },
        Writable => 1,
        Protected => 1, # (all writable pseudo tags must be protected)
        Notes => 'Mac OS X Finder comment.  See MDItemTags below for more information',
    },
    MDItemFSLabel => {
        Groups => { 1 => 'System', 2 => 'Other' },
        Writable => 1,
        Protected => 1, # (all writable pseudo tags must be protected)
        Notes => 'Mac OS X label number.  See MDItemTags below for more information',
        WriteCheck => '$val =~ /^[0-7]$/ ? undef : "Not an integer in the range 0-7"',
    },
    MDItemFSCreationDate => {
        Groups => { 1 => 'System', 2 => 'Time' },
        Writable => 1,
        DelCheck => q{"Can't delete"},
        Protected => 1, # (all writable pseudo tags must be protected)
        Shift => 'Time', # (but not supported yet)
        Notes => q{
            Mac OS X file creation date.  See MDItemTags below for more information.
            Requires "setfile" for writing
        },
        Groups => { 1 => 'System', 2 => 'Time' },
        ValueConv => \&MDItemLocalTime,
        ValueConvInv => sub {
            my $val = shift;
            # convert to local time if value has a time zone
            if ($val =~ /[-+Z]/) {
                my $time = Image::ExifTool::GetUnixTime($val, 1);
                $val = Image::ExifTool::ConvertUnixTime($time, 1) if $time;
            }
            $val =~ s{(\d{4}):(\d{2}):(\d{2})}{$2/$3/$1};   # reformat for setfile
            return $val;
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    MDItemTags => {
        Groups => { 1 => 'System', 2 => 'Other' },
        Notes => q{
            this entry is for documentation purposes only.  On Mac OS X, there are a
            number of additional tags with names beginning with "MDItem" that may be
            extracted if specifically requested, or if the MDItemTags API option is set
            or the RequestAll API option is set to 2 or higher.  Requires that the
            "mdls" utility is available.  Note that these tags do not necessarily
            reflect the current state of the file -- they are updated only when the file
            is indexed by Spotlight
        },
    },
#
# "xattr" tags
#
    XAttrFinderInfo => {
        Groups => { 1 => 'System', 2 => 'Other' },
        ConvertBinary => 1,
        Notes => 'Mac OS X finder information.  See XAttrTags below for more information',
        # ref https://opensource.apple.com/source/CarbonHeaders/CarbonHeaders-9A581/Finder.h
        ValueConv => q{
            my @a = unpack('a4a4n3x10nx2N', $$val);
            tr/\0//d, tr/ /\0/, $_="'$_'" foreach @a[0,1];
            return "@a";
        },
        PrintConv => q{
            my ($type, $creator, $flags, $y, $x, $exFlags, $putAway) = split ' ', $val;
            tr/\0/ / foreach $type, $creator;
            my $label = ($flags >> 1) & 0x07;
            my $flags = DecodeBits((($exFlags<<16) | $flags) & 0xfff1, {
                0 => 'OnDesk',
                6 => 'Shared',
                7 => 'HasNoInits',
                8 => 'Inited',
                10 => 'CustomIcon',
                11 => 'Stationery',
                12 => 'NameLocked',
                13 => 'HasBundle',
                14 => 'Invisible',
                15 => 'Alias',
                # extended flags
                22 => 'HasRoutingInfo',
                23 => 'ObjectBusy',
                24 => 'CustomBadge',
                31 => 'ExtendedFlagsValid',
            });
            my $str = "Type=$type Creator=$creator Flags=$flags Label=$label Pos=($x,$y)";
            $str .= " Putaway=$putAway" if $putAway;
            return $str;
        },
    },
    XAttrQuarantine => {
        Groups => { 1 => 'System', 2 => 'Other' },
        Writable => 1,
        WriteCheck => '"May only delete this tag"',
        Protected => 1,
        Notes => q{
            Mac OS X quarantine information for files downloaded from the internet. See
            XAttrTags below for more information.  May only be deleted when writing
        },
        PrintConv => q{
            my @a = split /;/, $val;
            $a[0] = 'Flags=' . $a[0];
            $a[1] = 'downloaded at ' . ConvertUnixTime(hex $a[1]);
            $a[2] = 'by ' . $a[2];
            return join ' ', @a;
        },
        PrintConvInv => '$val',
    },
    XAttrTags => {
        Groups => { 1 => 'System', 2 => 'Other' },
        Notes => q{
            this entry is for documentation purposes only.  On Mac OS X, there are a
            number of additional tags with names beginning with "XAttr" that may be
            extracted if specifically requested, or if the XAttrTags API option is set,
            or if the RequestAll API option is set to 2 or higher.  Requires that the
            "xattr" utility is available
        },
    },
);

# add our tags to the Extra table
my $tag;
foreach $tag (keys %extraTags) {
    # must add "Module" for writable tags so they can be loaded when needed
    $extraTags{$tag}{Writable} and $extraTags{$tag}{Module} = 'Image::ExifTool::MacOSX';
    AddTagToTable(\%Image::ExifTool::Extra, $tag => $extraTags{$tag}, 1);
}

#------------------------------------------------------------------------------
# Convert OS X MDItem time string to standard EXIF-formatted local time
# Inputs: 0) time string (eg. "2017-02-21 17:21:43 +0000")
# Returns: EXIF-formatted local time string with timezone
sub MDItemLocalTime($)
{
    my $val = shift;
    $val =~ tr/-/:/;
    $val =~ s/ ?([-+]\d{2}):?(\d{2})/$1:$2/;
    # convert from UTC to local time
    if ($val =~ /\+00:00$/) {
        my $time = Image::ExifTool::GetUnixTime($val);
        $val = Image::ExifTool::ConvertUnixTime($time, 1) if $time;
    }
    return $val;
}

#------------------------------------------------------------------------------
# Set Mac OS X tags from new tag values
# Inputs: 0) Exiftool ref, 1) file name
# Returns: 1=something was set OK, 0=didn't try, -1=error (and warning set)
# Notes: There may be errors even if 1 is returned
sub SetOSXTags($$)
{
    my ($et, $file) = @_;
    my $result = 0;
    my $tag;

    foreach $tag (qw(MDItemFinderComment MDItemFSCreationDate MDItemFSLabel XAttrQuarantine)) {
        my ($nvHash, $f, $v, $attr, $cmd, $silentErr);
        my $val = $et->GetNewValue($tag, \$nvHash);
        next unless $nvHash;
        my $overwrite = $et->IsOverwriting($nvHash) or next;
        if ($overwrite < 0) {
            my $operation = $$nvHash{Shift} ? 'Shifting' : 'Conditional replacement';
            $et->Warn("$operation of $tag not yet supported");
            next;
        }
        if ($tag eq 'MDItemFSCreationDate') {
            ($f = $file) =~ s/'/'\\''/g;
            $cmd = "setfile -d '$val' '$f'";
        } elsif ($tag eq 'XAttrQuarantine') {
            ($f = $file) =~ s/'/'\\''/g;
            $cmd = "xattr -d com.apple.quarantine '$f'";
            $silentErr = 256;   # (will get this error if attribute doesn't exist)
        } else {
            ($f = $file) =~ s/(["\\])/\\$1/g;   # escape necessary characters
            $f =~ s/'/'"'"'/g;
            if ($tag eq 'MDItemFinderComment') {
                # (write finder comment using osascript instead of xattr
                # because it is more work to construct the necessary bplist)
                $val = '' unless defined $val;  # set to empty string instead of deleting
                $v = $et->Encode($val, 'UTF8');
                $v =~ s/(["\\])/\\$1/g;
                $v =~ s/'/'"'"'/g;
                $attr = 'comment';
            } else { # $tag eq 'MDItemFSLabel'
                $v = $val ? 8 - $val : 0;       # convert from label to label index (0 for no label)
                $attr = 'label index';
            }
            $cmd = qq(osascript -e 'set fp to POSIX file "$f" as alias' -e \\
                'tell application "Finder" to set $attr of file fp to "$v"');
        }
        my $err = system $cmd . '>/dev/null 2>&1';  # (pipe all output to /dev/null)
        if (not $err) {
            $et->VerboseValue("+ $tag", $val);
            $result = 1;
        } elsif (not $silentErr or $err != $silentErr) {
            $cmd =~ s/ .*//s;
            $et->Warn(qq{Error $err running "$cmd" to set $tag});
            $result = -1 unless $result;
        }
    }
    return $result;
}

#------------------------------------------------------------------------------
# Extract OS X metadata item tags
# Inputs: 0) ExifTool object ref, 1) file name
sub ExtractMDItemTags($$)
{
    local $_;
    my ($et, $file) = @_;
    my ($fn, $tag, $val);

    ($fn = $file) =~ s/([`"\$\\])/\\$1/g;   # escape necessary characters
    my @mdls = `mdls "$fn" 2> /dev/null`;   # get OS X metadata
    if ($? or not @mdls) {
        $et->Warn('Error running "mdls" to extract MDItem tags');
        return;
    }
    my $extra = GetTagTable('Image::ExifTool::Extra');
    foreach (@mdls) {
        chomp;
        if (ref $val ne 'ARRAY') {
            s/^k(MDItem\w+)\s*= // or next;
            $tag = $1;
            $_ eq '(' and $val = [ ], next; # (start of a list)
            $_ = '' if $_ eq '(null)';
            s/^"// and s/"$//;  # remove quotes if they exist
            $val = $_;
        } elsif ($_ eq ')') {   # (end of a list)
            $_ = $$val[0];
            next unless defined $_;
        } else {
            # add item to list
            s/^    //;          # remove leading spaces
            s/,$//;             # remove trailing comma
            $_ = '' if $_ eq '(null)';
            s/^"// and s/"$//;  # remove quotes if they exist
            $_ = $et->Decode($_, 'UTF8');
            push @$val, $_;
            next;
        }
        # add to Extra tags if not done already
        unless ($$extra{$tag}) {
            # check for a date/time format
            my %tagInfo = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/ ? (
                Groups => { 1 => 'System', 2 => 'Time' },
                ValueConv => \&MDItemLocalTime,
                PrintConv => '$et->ConvertDateTime($val)',
            ) : ( Groups => { 1 => 'System', 2 => 'Other' } );
            $tagInfo{Name} = Image::ExifTool::MakeTagName($tag);
            $tagInfo{List} = 1 if ref $val eq 'ARRAY';
            $tagInfo{Groups}{2} = 'Audio' if $tag =~ /Audio/;
            $tagInfo{Groups}{2} = 'Author' if $tag =~ /(Copyright|Author)/;
            AddTagToTable($extra, $tag, \%tagInfo);
        }
        $val = $et->Decode($val, 'UTF8') unless ref $val;
        $et->FoundTag($tag, $val);
        undef $val;
    }
}

#------------------------------------------------------------------------------
# Extract OS X extended attribute tags
# Inputs: 0) ExifTool object ref, 1) file name
sub ExtractXAttrTags($$)
{
    local $_;
    my ($et, $file) = @_;
    my ($fn, $tag, $val, $warn);

    ($fn = $file) =~ s/([`"\$\\])/\\$1/g;       # escape necessary characters
    my @xattr = `xattr -lx "$fn" 2> /dev/null`; # get OS X extended attributes
    if ($? or not @xattr) {
        $? and $et->Warn('Error running "xattr" to extract XAttr tags');
        return;
    }
    my $extra = GetTagTable('Image::ExifTool::Extra');
    push @xattr, '';    # (for a list terminator)
    foreach (@xattr) {
        chomp;
        if (s/^[\dA-Fa-f]{8}//) {
            $tag or $warn = 1, next;
            s/\|.*//;
            tr/ //d;
            (/[^\dA-Fa-f]/ or length($_) & 1) and $warn = 2, next;
            $val = '' unless defined $val;
            $val .= pack('H*', $_);
            next;
        } elsif ($tag and defined $val) {
            # add to Extra tags if necessary
            unless ($$extra{$tag}) {
                my %tagInfo = (
                    Name => $tag,
                    Groups => { 1 => 'System', 2 => $tag=~/Date$/ ? 'Time' : 'Other' },
                );
                AddTagToTable($extra, $tag, \%tagInfo);
            }
            if ($val =~ /^bplist0/) {
                my %dirInfo = ( DataPt => \$val );
                require Image::ExifTool::PLIST;
                if (Image::ExifTool::PLIST::ProcessBinaryPLIST($et, \%dirInfo, $extra)) {
                    next if ref $dirInfo{Value} eq 'HASH';
                    $val = $dirInfo{Value}
                } else {
                    $et->Warn("Error decoding $$extra{$tag}{Name}");
                    next;
                }
            }
            if (not ref $val and ($val =~ /\0/ or length($val) > 200) or $tag eq 'XAttrMDLabel') {
                my $buff = $val;
                $val = \$buff;
            }
            $et->HandleTag($extra, $tag, $val);
            undef $tag;
            undef $val;
        }
        next unless length;
        s/:$// or $warn = 3, next;  # attribute name must have trailing ":"
        defined $val and $warn = 4, undef $val;
        # generate tag name from attribute name
        if (/^com\.apple\.(.*)$/) {
            ($tag = $1) =~ s/^metadata:_?k//;
            $tag =~ s/^MDLabel_.*/MDLabel/s;
        } else {
            ($tag = $_) =~ s/[.:]([a-z])/\U$1/g;                
        }
        $tag = 'XAttr' . ucfirst $tag;
    }
    $warn and $et->Warn(qq{Error $warn parsing "xattr" output});
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MacOSX - Read/write Mac OS X system tags

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract
extra MDItem* and XAttr* tags on Mac OS X systems using the "mdls" and
"xattr" utilities respectively.  Writable tags use "xattr", "setfile" or
"osascript" for writing.

=head1 AUTHOR

Copyright 2003-2017, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::ExifTool::TagNames/Extra Tags>

=cut

