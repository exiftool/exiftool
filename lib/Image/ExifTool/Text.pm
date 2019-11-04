#------------------------------------------------------------------------------
# File:         Text.pm
#
# Description:  Deduce characteristics of a text file
#
# Revisions:    2019-11-01 - P. Harvey Created
#
# References:   1) https://github.com/file/file
#------------------------------------------------------------------------------

package Image::ExifTool::Text;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::XMP;

$VERSION = '1.00';

# Text tags
%Image::ExifTool::Text::Main = (
    VARS => { NO_ID => 1 },
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Document' },
    NOTES => q{
        Although basic text files contain no metadata, the following tags are
        determined from a simple analysis of the text data.  LineCount and WordCount
        are generated only for 8-bit character sets if the FastScan option is not
        used.
    },
    MIMEEncoding => { Groups => { 2 => 'Other' } },
    Newlines => {
        PrintConv => {
            "\r\n" => 'Windows CRLF',
            "\r"   => 'Macintosh CR',
            "\n"   => 'Unix LF',
            ''     => '(none)',
        },
    },
    ByteOrderMark => { PrintConv => { 0 => 'No', 1 => 'Yes' } },
    LineCount => { },
    WordCount => { },
);

#------------------------------------------------------------------------------
# Extract some stats from a text file
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a text file
sub ProcessTXT($$)
{
    my ($et, $dirInfo) = @_;
    my $dataPt = $$dirInfo{TestBuff};
    my $fast = $et->Options('FastScan') || 0;
    my ($buff, $enc, $isBOM);
    my $nl = '';

    return 0 unless length $$dataPt; # can't call it a text file if it has no text

    if ($$dataPt =~ /[\0-\x06\x0e-\x1f\x7f\xff]/) {
        # file contains weird control characters, could be multi-byte Unicode
        if ($$dataPt =~ /^(\xff\xfe\0\0|\0\0\xfe\xff)/) {
            if ($1 eq "\xff\xfe\0\0") {
                $enc = 'utf-32le';
                $nl = $1 if $$dataPt =~ /(\r\0\0\0\n|\r|\n)\0\0\0/;
            } else {
                $enc = 'utf-32be';
                $nl = $1 if $$dataPt =~ /\0\0\0(\r\0\0\0\n|\r|\n)/;
            }
        } elsif ($$dataPt =~ /^(\xff\xfe|\xfe\xff)/) {
            if ($1 eq "\xff\xfe") {
                $enc = 'utf-16le';
                $nl = $1 if $$dataPt =~ /(\r\0\n|\r|\n)\0/;
            } else {
                $enc = 'utf-16be';
                $nl = $1 if $$dataPt =~ /\0(\r\0\n|\r|\n)/;
            }
        } else {
            return 0;       # probably not a text file
        }
        $nl =~ tr/\0//d;    # remove nulls from newline sequence
        $isBOM = 1;         # (we don't recognize UTF-16/UTF-32 without one)
    } else {
        if ($$dataPt !~ /[\x80-\xff]/) {
            $enc = 'us-ascii';
        } elsif (Image::ExifTool::XMP::IsUTF8($dataPt,1) > 0) {
            $enc = 'utf-8';
            $isBOM = ($$dataPt =~ /^\xef\xbb\xbf/ ? 1 : 0);
        } elsif ($$dataPt !~ /[\x80-\x9f]/) {
            $enc = 'iso-8859-1';
        } else {
            $enc = 'unknown-8bit';
        }
        $nl = $1 if $$dataPt =~ /(\r\n|\r|\n)/;
    }
    
    my $tagTablePtr = GetTagTable('Image::ExifTool::Text::Main');
    $et->SetFileType();
    $et->HandleTag($tagTablePtr, MIMEEncoding => $enc);
    return 1 if $fast == 3;
    $et->HandleTag($tagTablePtr, ByteOrderMark => $isBOM) if defined $isBOM;
    $et->HandleTag($tagTablePtr, Newlines => $nl);
    unless ($enc =~ /^utf-(16|32)/ or $fast) {
        my $raf = $$dirInfo{RAF};
        my ($lines, $words) = (0, 0);
        my $oldNL = $/;
        $/ = $nl if $nl;
        while ($raf->ReadLine($buff)) {
            if (not $nl and $buff =~ /(\r\n|\r|\n)$/) {
                # (the first line must have been longer than 1024 characters)
                $$et{VALUE}{Newlines} = $nl = $1;
            }
            ++$lines;
            ++$words while $buff =~ /\S+/g;
        }
        $/ = $oldNL;
        $et->HandleTag($tagTablePtr, LineCount => $lines);
        $et->HandleTag($tagTablePtr, WordCount => $words);
    }
    return 1;
}


1;  # end

__END__

=head1 NAME

Image::ExifTool::Text - Read Text meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to deduce some
characteristics of Text files.

=head1 AUTHOR

Copyright 2003-2019, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://github.com/file/file>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Text Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

