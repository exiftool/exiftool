#------------------------------------------------------------------------------
# File:         Text.pm
#
# Description:  Deduce characteristics of TXT and CSV files
#
# Revisions:    2019-11-01 - P. Harvey Created
#               2020-02-13 - PH Added CSV file support
#
# References:   1) https://github.com/file/file
#------------------------------------------------------------------------------

package Image::ExifTool::Text;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.05';

# Text tags
%Image::ExifTool::Text::Main = (
    VARS => { ID_FMT => 'none' },
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Document' },
    NOTES => q{
        Although basic text files contain no metadata, the following tags are
        determined from a simple analysis of the data in TXT and CSV files. 
        Statistics are generated only for 8-bit encodings, but the L<FastScan|../ExifTool.html#FastScan> (-fast)
        option may be used to limit processing to the first 64 KiB in which case
        some tags are not produced.  To avoid long processing delays, ExifTool will
        issue a minor warning and process only the first 64 KiB of any file larger
        than 20 MiB unless the L<IgnoreMinorErrors|../ExifTool.html#IgnoreMinorErrors> (-m) option is used.
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
    Delimiter => { PrintConv => { '' => '(none)', ',' => 'Comma', ';' => 'Semicolon', "\t" => 'Tab' }},
    Quoting   => { PrintConv => { '' => '(none)', '"' => 'Double quotes', "'" => 'Single quotes' }},
    RowCount  => { },
    ColumnCount => { },
);

#------------------------------------------------------------------------------
# Extract some stats from a text file
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a text file
sub ProcessTXT($$)
{
    my ($et, $dirInfo) = @_;
    my $dataPt = $$dirInfo{TestBuff};
    my $raf = $$dirInfo{RAF};
    my $fast = $et->Options('FastScan') || 0;
    my ($buff, $enc, $isBOM, $isUTF8);
    my $nl = '';

    return 0 unless length $$dataPt; # can't call it a text file if it has no text

    # read more from the file if necessary
    if ($fast < 3 and length($$dataPt) == $Image::ExifTool::testLen) {
        $raf->Read($buff, 65536) or return 0;
        $dataPt = \$buff;
    }
#
# make our best guess at the character encoding (EBCDIC is not supported)
#
    if ($$dataPt =~ /([\0-\x06\x0e-\x1a\x1c-\x1f\x7f])/) {
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
        $isUTF8 = Image::ExifTool::IsUTF8($dataPt, 1);
        if ($isUTF8 == 0) {
            $enc = 'us-ascii';
        } elsif ($isUTF8 > 0) {
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

    return 1 if $fast == 3 or not $raf->Seek(0,0);

    $et->HandleTag($tagTablePtr, ByteOrderMark => $isBOM) if defined $isBOM;
    $et->HandleTag($tagTablePtr, Newlines => $nl);

    return 1 if $fast or not defined $isUTF8;
#
# generate stats for CSV files
#
    if ($$et{FileType} eq 'CSV') {
        my ($delim, $quot, $ncols);
        my $nrows = 0;
        while ($raf->ReadLine($buff)) {
            if (not defined $delim) {
                my %count = ( ',' => 0, ';' => 0, "\t" => 0 );
                ++$count{$_} foreach $buff =~ /[,;\t]/g;
                if ($count{','} > $count{';'} and $count{','} > $count{"\t"}) {
                    $delim = ',';
                } elsif ($count{';'} > $count{"\t"}) {
                    $delim = ';';
                } elsif ($count{"\t"}) {
                    $delim = "\t";
                } else {
                    $delim = '';
                    $ncols = 1;
                }
                unless ($ncols) {
                    # account for delimiters in quotes (simplistically)
                    while ($buff =~ /(^|$delim)(["'])(.*?)\2(?=$delim|$)/sg) {
                        $quot = $2;
                        my $field = $3;
                        $count{$delim} -= () = $field =~ /$delim/g;
                    }
                    $ncols = $count{$delim} + 1;
                }
            } elsif (not $quot) {
                $quot = $2 if $buff =~ /(^|$delim)(["'])(.*?)\2(?=$delim|$)/sg;
            }
            if (++$nrows == 1000 and $et->Warn('Not counting rows past 1000', 2)) {
                undef $nrows;
                last;
            }
        }
        $et->HandleTag($tagTablePtr, Delimiter => ($delim || ''));
        $et->HandleTag($tagTablePtr, Quoting => ($quot || ''));
        $et->HandleTag($tagTablePtr, ColumnCount => $ncols);
        $et->HandleTag($tagTablePtr, RowCount => $nrows) if $nrows;
        return 1;
    }
    return 1 if $$et{VALUE}{FileSize} and $$et{VALUE}{FileSize} > 20000000 and
        $et->Warn('Not counting lines/words in text file larger than 20 MB', 2);
#
# count lines/words and check encoding of the rest of the file
#
    my ($lines, $words) = (0, 0);
    my $oldNL = $/;
    $/ = $nl if $nl;
    while ($raf->ReadLine($buff)) {
        ++$lines;
        ++$words while $buff =~ /\S+/g;
        if (not $nl and $buff =~ /(\r\n|\r|\n)$/) {
            # (the first line must have been longer than 64 kB)
            $$et{VALUE}{Newlines} = $nl = $1;
        }
        next if $raf->Tell() < 65536;
        # continue to check encoding after the first 64 kB
        if ($isUTF8 >= 0) { # (if ascii or utf8)
            $isUTF8 = Image::ExifTool::IsUTF8(\$buff);
            if ($isUTF8 > 0) {
                $enc = 'utf-8';
            } elsif ($isUTF8 < 0) {
                $enc = $buff =~ /[\x80-\x9f]/ ? 'unknown-8bit' : 'iso-8859-1';
            }
        } elsif ($enc eq 'iso-8859-1' and $buff =~ /[\x80-\x9f]/) {
            $enc = 'unknown-8bit';
        }
    }
    # ($$et{VALUE}{MIMEEncoding} may be undef if it was ignored)
    if (defined $$et{VALUE}{MIMEEncoding} and $$et{VALUE}{MIMEEncoding} ne $enc) {
        $$et{VALUE}{MIMEEncoding} = $enc;
        $et->VPrint(0,"  MIMEEncoding [override] = $enc\n");
    }
    $/ = $oldNL;
    $et->HandleTag($tagTablePtr, LineCount => $lines);
    $et->HandleTag($tagTablePtr, WordCount => $words);
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
characteristics of TXT and CSV files.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

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

