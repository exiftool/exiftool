#------------------------------------------------------------------------------
# File:         Validate.pm
#
# Description:  Additional metadata validation
#
# Revisions:    2017/01/18 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Validate;

use strict;
use vars qw($VERSION %exifSpec);

$VERSION = '1.02';

use Image::ExifTool qw(:Utils);
use Image::ExifTool::Exif;

# EXIF table tag ID's which are part of the EXIF 2.31 specification
# (also used by BuildTagLookup to add underlines in HTML version of EXIF Tag Table)
%exifSpec = (
    0x100 => 1,  0x8298 => 1,  0x9207 => 1,  0xa217 => 1,
    0x101 => 1,  0x829a => 1,  0x9208 => 1,  0xa300 => 1,
    0x102 => 1,  0x829d => 1,  0x9209 => 1,  0xa301 => 1,
    0x103 => 1,  0x8769 => 1,  0x920a => 1,  0xa302 => 1,
    0x106 => 1,  0x8822 => 1,  0x9214 => 1,  0xa401 => 1,
    0x10e => 1,  0x8824 => 1,  0x927c => 1,  0xa402 => 1,
    0x10f => 1,  0x8825 => 1,  0x9286 => 1,  0xa403 => 1,
    0x110 => 1,  0x8827 => 1,  0x9290 => 1,  0xa404 => 1,
    0x111 => 1,  0x8828 => 1,  0x9291 => 1,  0xa405 => 1,
    0x112 => 1,  0x8830 => 1,  0x9292 => 1,  0xa406 => 1,
    0x115 => 1,  0x8831 => 1,  0x9400 => 1,  0xa407 => 1,
    0x116 => 1,  0x8832 => 1,  0x9401 => 1,  0xa408 => 1,
    0x117 => 1,  0x8833 => 1,  0x9402 => 1,  0xa409 => 1,
    0x11a => 1,  0x8834 => 1,  0x9403 => 1,  0xa40a => 1,
    0x11b => 1,  0x8835 => 1,  0x9404 => 1,  0xa40b => 1,
    0x11c => 1,  0x9000 => 1,  0x9405 => 1,  0xa40c => 1,
    0x128 => 1,  0x9003 => 1,  0xa000 => 1,  0xa420 => 1,
    0x12d => 1,  0x9004 => 1,  0xa001 => 1,  0xa430 => 1,
    0x131 => 1,  0x9010 => 1,  0xa002 => 1,  0xa431 => 1,
    0x132 => 1,  0x9011 => 1,  0xa003 => 1,  0xa432 => 1,
    0x13b => 1,  0x9012 => 1,  0xa004 => 1,  0xa433 => 1,
    0x13e => 1,  0x9101 => 1,  0xa005 => 1,  0xa434 => 1,
    0x13f => 1,  0x9102 => 1,  0xa20b => 1,  0xa435 => 1,
    0x201 => 1,  0x9201 => 1,  0xa20c => 1,
    0x202 => 1,  0x9202 => 1,  0xa20e => 1,
    0x211 => 1,  0x9203 => 1,  0xa20f => 1,
    0x212 => 1,  0x9204 => 1,  0xa210 => 1,
    0x213 => 1,  0x9205 => 1,  0xa214 => 1,
    0x214 => 1,  0x9206 => 1,  0xa215 => 1,
);

# standard format for tags (not necessary for exifSpec tags where Writable is defined)
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
    GPS => {
        All  => '', # all defined GPS tags are standard
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
        0x119 => 'int16u',      0x143 => 'int(16|32)u', 0x201 => 'int32u',      0x8773 => 'undef',
        0x11d => 'string',      0x144 => 'int32u',      0x202 => 'int32u',      0xc4a5 => 'undef',
        0x11e => 'rational64u', 0x145 => 'int(16|32)u', 0x203 => 'int16u',
        # Windows Explorer tags:
        0x9c9b => 'int8u',      0x9c9d => 'int8u',      0x9c9f => 'int8u',
        0x9c9c => 'int8u',      0x9c9e => 'int8u',
        # DNG tags:
        0xc615 => '(string|int8u)',              0xc6d3 => '',
        0xc61a => '(int16u|int32u|rational64u)', 0xc6f4 => '(string|int8u)',
        0xc61d => 'int(16|32)u',                 0xc6f6 => '(string|int8u)',
        0xc61f => '(int16u|int32u|rational64u)', 0xc6f8 => '(string|int8u)',
        0xc620 => '(int16u|int32u|rational64u)', 0xc6fe => '(string|int8u)',
        0xc628 => '(int16u|rational64u)',        0xc716 => '(string|int8u)',
        0xc634 => 'int8u',                       0xc717 => '(string|int8u)',
        0xc640 => '',                            0xc718 => '(string|int8u)',
        0xc660 => '',                            0xc71e => 'int(16|32)u',
        0xc68b => '(string|int8u)',              0xc71f => 'int(16|32)u',
        0xc68d => 'int(16|32)u',                 0xc791 => 'int(16|32)u',
        0xc68e => 'int(16|32)u',                 0xc792 => 'int(16|32)u',
        0xc6d2 => '',                            0xc793 => '(int16u|int32u|rational64u)',
    },
);

# "Validate" tag information
my %validateInfo = (
    Groups => { 0 => 'ExifTool', 1 => 'ExifTool', 2 => 'ExifTool' },
    Notes => q{
        [experimental] generated only if specifically requested.  Requesting this
        tag automatically enables the L<API Validate option|../ExifTool.html#Validate>,
        imposing additional validation checks when extracting metadata.  Returns the
        number of errors, warnings and minor warnings encountered
    },
    PrintConv => {
        '0 0 0' => 'OK',
        OTHER => sub {
            my @val = split ' ', shift;
            my @rtn;
            push @rtn, sprintf('%d Error%s', $val[0], $val[0] == 1 ? '' : 's') if $val[0];
            push @rtn, sprintf('%d Warning%s', $val[1], $val[1] == 1 ? '' : 's') if $val[1];
            $rtn[-1] .= sprintf(' (%s minor)', $val[1] == $val[2] ? 'all' : $val[2]) if $val[2];
            return join(' and ', @rtn);
        },
    },
);

# generate lookup for any IFD
my %stdFormatAnyIFD = map { %{$stdFormat{$_}} } keys %stdFormat;

# add "Validate" tag to Extra table
AddTagToTable(\%Image::ExifTool::Extra, Validate => \%validateInfo, 1);

#------------------------------------------------------------------------------
# Validate EXIF tag
# Inputs: 0) ExifTool ref, 1) tag table ref, 2) tag ID, 3) tagInfo ref,
#         4) previous tag ID, 5) IFD name, 6) number of values, 7) value format string
# Returns: Nothing, but sets Warning tags if any problems are found
sub ValidateExif($$$$$$$$)
{
    my ($et, $tagTablePtr, $tag, $tagInfo, $lastTag, $ifd, $count, $formatStr) = @_;

    $et->WarnOnce("Entries in $ifd are out of order") if $tag <= $lastTag;

    if (defined $tagInfo) {
        my $ti = $tagInfo || $$tagTablePtr{$tag};
        $ti = $$ti[-1] if ref $ti eq 'ARRAY';
        my $stdFmt = $stdFormat{$ifd} || $stdFormat{IFD};
        if (defined $$stdFmt{All} or ($tagTablePtr eq \%Image::ExifTool::Exif::Main and
            ($exifSpec{$tag} or $$stdFmt{$tag} or
            ($tag >= 0xc612 and $tag <= 0xc7b5 and not defined $$stdFmt{$tag})))) # (DNG tags)
        {
            my $wgp = $$ti{WriteGroup} || $$tagTablePtr{WRITE_GROUP};
            if ($wgp and $wgp ne $ifd and $wgp ne 'All' and not $$ti{OffsetPair} and
                ($ifd =~ /^(Sub|Profile)?IFD\d*$/ xor $wgp =~ /^(Sub)?IFD\d*$/))
            {
                $et->Warn(sprintf('Wrong IFD for 0x%.4x %s (should be %s not %s)', $tag, $$ti{Name}, $wgp, $ifd));
            }
            my $fmt = $$stdFmt{$tag} || $$ti{Writable};
            if ($fmt and $formatStr !~ /^$fmt$/) {
                $et->Warn(sprintf('Non-standard format (%s) for %s 0x%.4x %s', $formatStr, $ifd, $tag, $$ti{Name}))
            }
        } elsif ($stdFormatAnyIFD{$tag}) {
            my $wgp = $$ti{WriteGroup} || $$tagTablePtr{WRITE_GROUP};
            if ($wgp) {
                $et->Warn(sprintf('Wrong IFD for 0x%.4x %s (should be %s not %s)', $tag, $$ti{Name}, $wgp, $ifd));
            } else {
                $et->Warn(sprintf('Wrong IFD for 0x%.4x %s (found in %s)', $tag, $$ti{Name}, $ifd));
            }
        } else {
            $et->Warn(sprintf('Non-standard %s tag 0x%.4x %s', $ifd, $tag, $$ti{Name}), 1);
        }
        if ($$ti{Count} and $$ti{Count} > 0 and $count != $$ti{Count}) {
            $et->Warn(sprintf('Non-standard count (%d) for %s tag 0x%.4x %s', $count, $ifd, $tag, $$ti{Name}));
        }
    } else {
        $et->Warn(sprintf('Unknown %s tag 0x%.4x', $ifd, $tag), 1);
    }
}

#------------------------------------------------------------------------------
# Generate Validate tag
# Inputs: 0) ExifTool ref
sub MakeValidateTag($)
{
    my $et = shift;
    my (@num, $key);
    push @num, $$et{VALUE}{Error}   ? ($$et{DUPL_TAG}{Error}   || 0) + 1 : 0,
               $$et{VALUE}{Warning} ? ($$et{DUPL_TAG}{Warning} || 0) + 1 : 0, 0;
    for ($key = 'Warning'; ; ) {
        ++$num[2] if $$et{VALUE}{$key} and $$et{VALUE}{$key} =~ /^\[minor\]/i;
        $key = $et->NextTagKey($key) or last;
    }
    $et->FoundTag(Validate => "@num");
}

# validation code for each image type
# FileType->Group1->Validation code
# - validation code may access $val and %val, and returns 1 on success,
#   or error message otherwise ('' for a generic message)
my %validate = (
    TIFF => {
        IFD0 => {
            0x103 => q{
                not defined $val or $val =~ /^(1|6|32773)$/ or
                    ($val == 2 and (not defined $val{0x102} or $val{0x102} == 1));
            },  # Compression
            0x106 => '$val =~ /^[0123]$/',  # PhotometricInterpretation
            0x100 => 'defined $val',        # ImageWidth
            0x101 => 'defined $val',        # ImageLength
            0x111 => 'defined $val',        # StripOffsets
            0x117 => 'defined $val',        # StripByteCounts
            0x11a => 'defined $val',        # XResolution
            0x11b => 'defined $val',        # YResolution
            0x128 => 'not defined $val or $val =~ /^[123]$/',   # ResolutionUnit
            # ColorMap (must be palette image with correct number of colors)
            0x140 => q{
                return '' if defined $val{0x106} and $val{0x106} == 3 xor defined $val;
                return 1 if not defined $val or scalar(split ' ', $val) == 3 * 2 ** ($val{0x102} || 0);
                return 'Invalid count for';
            },
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
        },
    },
);

#------------------------------------------------------------------------------
# Finish Validating tags
# Inputs: 0) ExifTool ref, 1) True to generate Validate tag
sub FinishValidate($$)
{
    my ($et, $mkTag) = @_;

    my $fileType = $$et{FILE_TYPE};
    $fileType = $$et{TIFF_TYPE} if $fileType eq 'TIFF';

    if ($validate{$fileType}) {
        my ($grp, $tag, %val);
        local $SIG{'__WARN__'} = \&Image::ExifTool::SetWarning;
        foreach $grp (sort keys %{$validate{$fileType}}) {
            # get all tags in this group
            my ($key, %val, %info);
            foreach $key (keys %{$$et{VALUE}}) {
                next unless $et->GetGroup($key, 1) eq $grp;
                # fill in %val lookup with values based on tag ID
                my $tag = $$et{TAG_INFO}{$key}{TagID};
                $val{$tag} = $$et{VALUE}{$key};
                # save TagInfo ref for later
                $info{$tag} = $$et{TAG_INFO}{$key};
            }
            # make quick lookup for values based on tag ID
            my $validateTags = $validate{$fileType}{$grp};
            foreach $tag (sort { $a <=> $b } keys %$validateTags) {
                my $val = $val{$tag};
                #### eval ($val, %val)
                my $result = eval $$validateTags{$tag};
                if (not defined $result) {
                    $result = 'Internal error validating';
                } elsif ($result eq '') {
                    $result = defined $val ? 'Invalid value for' : 'Missing required';
                } elsif ($result eq '1') {
                    next;
                }
                my $name;
                if ($info{$tag}) {
                    $name = $info{$tag}{Name};
                } else {
                    my $tagInfo = $Image::ExifTool::Exif::Main{$tag};
                    $tagInfo = $$tagInfo[0] if ref $tagInfo eq 'ARRAY';
                    $name = $tagInfo ? $$tagInfo{Name} : '<unknown>';
                }
                $et->Warn(sprintf('%s %s tag 0x%.4x %s', $result, $grp, $tag, $name));
            }
        }
    }
    MakeValidateTag($et) if $mkTag;
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

Copyright 2003-2017, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::ExifTool::TagNames/Extra Tags>

=cut
