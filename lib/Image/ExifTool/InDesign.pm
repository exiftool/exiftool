#------------------------------------------------------------------------------
# File:         InDesign.pm
#
# Description:  Read/write meta information in Adobe InDesign files
#
# Revisions:    2009-06-17 - P. Harvey Created
#
# References:   1) http://www.adobe.com/devnet/xmp/pdfs/XMPSpecificationPart3.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::InDesign;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.06';

# map for writing metadata to InDesign files (currently only write XMP)
my %indMap = (
    XMP => 'IND',
);

# GUID's used in InDesign files
my $masterPageGUID    = "\x06\x06\xed\xf5\xd8\x1d\x46\xe5\xbd\x31\xef\xe7\xfe\x74\xb7\x1d";
my $objectHeaderGUID  = "\xde\x39\x39\x79\x51\x88\x4b\x6c\x8E\x63\xee\xf8\xae\xe0\xdd\x38";
my $objectTrailerGUID = "\xfd\xce\xdb\x70\xf7\x86\x4b\x4f\xa4\xd3\xc7\x28\xb3\x41\x71\x06";

#------------------------------------------------------------------------------
# Read or write meta information in an InDesign file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid InDesign file, or -1 on write error
sub ProcessIND($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $outfile = $$dirInfo{OutFile};
    my ($hdr, $buff, $buf2, $err, $writeLen, $foundXMP);

    # validate the InDesign file
    return 0 unless $raf->Read($hdr, 16) == 16;
    return 0 unless $hdr eq $masterPageGUID;
    return 0 unless $raf->Read($buff, 8) == 8;
    $et->SetFileType($buff eq 'DOCUMENT' ? 'INDD' : 'IND');   # set the FileType tag

    # read the master pages
    $raf->Seek(0, 0) or $err = 'Seek error', goto DONE;
    unless ($raf->Read($buff, 4096) == 4096 and
            $raf->Read($buf2, 4096) == 4096)
    {
        $err = 'Unexpected end of file';
        goto DONE; # (goto's can be our friend)
    }
    SetByteOrder('II');
    unless ($buf2 =~ /^\Q$masterPageGUID/) {
        $err = 'Second master page is invalid';
        goto DONE;
    }
    my $seq1 = Get64u(\$buff, 264);
    my $seq2 = Get64u(\$buf2, 264);
    # take the most current master page
    my $curPage = $seq2 > $seq1 ? \$buf2 : \$buff;
    # byte order of stream data may be different than headers
    my $streamInt32u = Get8u($curPage, 24);
    if ($streamInt32u == 1) {
        $streamInt32u = 'V'; # little-endian int32u
    } elsif ($streamInt32u == 2) {
        $streamInt32u = 'N'; # big-endian int32u
    } else {
        $err = 'Invalid stream byte order';
        goto DONE;
    }
    my $pages = Get32u($curPage, 280);
    $pages < 2 and $err = 'Invalid page count', goto DONE;
    my $pos = $pages * 4096;
    if ($pos > 0x7fffffff and not $et->Options('LargeFileSupport')) {
        $err = 'InDesign files larger than 2 GB not supported (LargeFileSupport not set)';
        goto DONE;
    }
    if ($outfile) {
        # make XMP the preferred group for writing
        $et->InitWriteDirs(\%indMap, 'XMP');

        Write($outfile, $buff, $buf2) or $err = 1, goto DONE;
        my $result = Image::ExifTool::CopyBlock($raf, $outfile, $pos - 8192);
        unless ($result) {
            $err = defined $result ? 'Error reading InDesign database' : 1;
            goto DONE;
        }
        $writeLen = 0;
    } else {
        $raf->Seek($pos, 0) or $err = 'Seek error', goto DONE;
    }
    # scan through the contiguous objects for XMP
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');
    for (;;) {
        $raf->Read($hdr, 32) or last;
        unless (length($hdr) == 32 and $hdr =~ /^\Q$objectHeaderGUID/) {
            # this must be null padding or we have an error
            $hdr =~ /^\0+$/ or $err = 'Corrupt file or unsupported InDesign version';
            last;
        }
        my $len = Get32u(\$hdr, 24);
        if ($verbose) {
            printf $out "Contiguous object at offset 0x%x (%d bytes):\n", $raf->Tell(), $len;
            if ($verbose > 2) {
                my $len2 = $len < 1024000 ? $len : 1024000;
                $raf->Seek(-$raf->Read($buff, $len2), 1) or $err = 1;
                $et->VerboseDump(\$buff, Addr => $raf->Tell());
            }
        }
        # check for XMP if stream data is long enough
        # (56 bytes is just enough for XMP header)
        if ($len > 56) {
            $raf->Read($buff, 56) == 56 or $err = 'Unexpected end of file', last;
            if ($buff =~ /^(....)<\?xpacket begin=(['"])\xef\xbb\xbf\2 id=(['"])W5M0MpCehiHzreSzNTczkc9d\3/s) {
                my $lenWord = $1;   # save length word for writing later
                $len -= 4;          # get length of XMP only
                $foundXMP = 1;
                # I have a sample where the XMP is 107 MB, and ActivePerl may run into
                # memory troubles (with its apparent 1 GB limit) if the XMP is larger
                # than about 400 MB, so guard against this
                if ($len > 300 * 1024 * 1024) {
                    my $msg = sprintf('Insanely large XMP (%.0f MB)', $len / (1024 * 1024));
                    if ($outfile) {
                        $et->Error($msg, 2) and $err = 1, last;
                    } elsif ($et->Options('IgnoreMinorErrors')) {
                        $et->Warn($msg);
                    } else {
                        $et->Warn("$msg. Ignored.", 1);
                        $err = 1;
                        last;
                    }
                }
                # load and parse the XMP data
                unless ($raf->Seek(-52, 1) and $raf->Read($buff, $len) == $len) {
                    $err = 'Error reading XMP stream';
                    last;
                }
                my %dirInfo = (
                    DataPt  => \$buff,
                    Parent  => 'IND',
                    NoDelete => 1, # do not allow this to be deleted when writing
                );
                # validate xmp data length (should be same as length in header - 4)
                my $xmpLen = unpack($streamInt32u, $lenWord);
                unless ($xmpLen == $len) {
                    if ($xmpLen < $len) {
                        $dirInfo{DirLen} = $xmpLen;
                    } else {
                        $err = 'Truncated XMP stream (missing ' . ($xmpLen - $len) . ' bytes)';
                    }
                }
                my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
                if ($outfile) {
                    last if $err;
                    # make sure that XMP is writable
                    my $classID = Get32u(\$hdr, 20);
                    $classID & 0x40000000 or $err = 'XMP stream is not writable', last;
                    my $xmp = $et->WriteDirectory(\%dirInfo, $tagTablePtr);
                    if ($xmp and length $xmp) {
                        # write new xmp with leading length word
                        $buff = pack($streamInt32u, length $xmp) . $xmp;
                        # update header with new length and invalid checksum
                        Set32u(length($buff), \$hdr, 24);
                        Set32u(0xffffffff, \$hdr, 28);
                    } else {
                        $$et{CHANGED} = 0;    # didn't change anything
                        $et->Warn("Can't delete XMP as a block from InDesign file") if defined $xmp;
                        # put length word back at start of stream
                        $buff = $lenWord . $buff;
                    }
                } else {
                    $et->ProcessDirectory(\%dirInfo, $tagTablePtr);
                }
                $len = 0;   # we got the full stream (nothing left to read)
            } else {
                $len -= 56; # we got 56 bytes of the stream
            }
        } else {
            $buff = '';     # must reset this for writing later
        }
        if ($outfile) {
            # write object header and data
            Write($outfile, $hdr, $buff) or $err = 1, last;
            my $result = Image::ExifTool::CopyBlock($raf, $outfile, $len);
            unless ($result) {
                $err = defined $result ? 'Truncated stream data' : 1;
                last;
            }
            $writeLen += 32 + length($buff) + $len;
        } elsif ($len) {
            # skip over remaining stream data
            $raf->Seek($len, 1) or $err = 'Seek error', last;
        }
        $raf->Read($buff, 32) == 32 or $err = 'Unexpected end of file', last;
        unless ($buff =~ /^\Q$objectTrailerGUID/) {
            $err = 'Invalid object trailer';
            last;
        }
        if ($outfile) {
            # make sure object UID and ClassID are the same in the trailer
            substr($hdr,16,8) eq substr($buff,16,8) or $err = 'Non-matching object trailer', last;
            # write object trailer
            Write($outfile, $objectTrailerGUID, substr($hdr,16)) or $err = 1, last;
            $writeLen += 32;
        }
    }
    if ($outfile) {
        # write null padding if necessary
        # (InDesign files must be an even number of 4096-byte blocks)
        my $part = $writeLen % 4096;
        Write($outfile, "\0" x (4096 - $part)) or $err = 1 if $part;
    }
DONE:
    if (not $err) {
        $et->Warn('No XMP stream to edit') if $outfile and not $foundXMP;
        return 1;       # success!
    } elsif (not $outfile) {
        # issue warning on read error
        $et->Warn($err) unless $err eq '1';
    } elsif ($err ne '1') {
        # set error and return success code
        $et->Error($err);
    } else {
        return -1;      # write error
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::InDesign - Read/write meta information in Adobe InDesign files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read XMP
meta information from Adobe InDesign (.IND, .INDD and .INDT) files.

=head1 LIMITATIONS

1) Only XMP meta information is processed.

2) A new XMP stream may not be created, so XMP tags may only be written to
InDesign files which previously contained XMP.

3) File sizes of greater than 2 GB are supported only if the system supports
them and the LargeFileSupport option is enabled.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.adobe.com/devnet/xmp/pdfs/XMPSpecificationPart3.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

