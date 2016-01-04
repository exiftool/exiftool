#------------------------------------------------------------------------------
# File:         AFCP.pm
#
# Description:  Read/write AFCP trailer
#
# Revisions:    12/26/2005 - P. Harvey Created
#
# References:   1) http://web.archive.org/web/20080828211305/http://www.tocarte.com/media/axs_afcp_spec.pdf
#------------------------------------------------------------------------------

package Image::ExifTool::AFCP;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.07';

sub ProcessAFCP($$);

%Image::ExifTool::AFCP::Main = (
    PROCESS_PROC => \&ProcessAFCP,
    NOTES => q{
AFCP stands for AXS File Concatenation Protocol, and is a poorly designed
protocol for appending information to the end of files.  This can be used as
an auxiliary technique to store IPTC information in images, but is
incompatible with some file formats.

ExifTool will read and write (but not create) AFCP IPTC information in JPEG
and TIFF images.

See
L<http://web.archive.org/web/20080828211305/http://www.tocarte.com/media/axs_afcp_spec.pdf>
for the AFCP specification.
    },
    IPTC => { SubDirectory => { TagTable => 'Image::ExifTool::IPTC::Main' } },
    TEXT => 'Text',
    Nail => {
        Name => 'ThumbnailImage',
        Groups => { 2 => 'Preview' },
        # (the specification allows for a variable amount of padding before
        #  the image after a 10-byte header, so look for the JPEG SOI marker,
        #  otherwise assume a fixed 8 bytes of padding)
        RawConv => q{
            pos($val) = 10;
            my $start = ($val =~ /\xff\xd8\xff/g) ? pos($val) - 3 : 18;
            my $img = substr($val, $start);
            return $self->ValidateImage(\$img, $tag);
        },
    },
    PrVw => {
        Name => 'PreviewImage',
        Groups => { 2 => 'Preview' },
        RawConv => q{
            pos($val) = 10;
            my $start = ($val =~ /\xff\xd8\xff/g) ? pos($val) - 3 : 18;
            my $img = substr($val, $start);
            return $self->ValidateImage(\$img, $tag);
        },
    },
);

#------------------------------------------------------------------------------
# Read/write AFCP information in a file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# (Set 'ScanForAFCP' member in dirInfo to scan from current position for AFCP)
# Returns: 1 on success, 0 if this file didn't contain AFCP information
#          -1 on write error or if the offsets were incorrect on reading
# - updates DataPos to point to actual AFCP start if ScanForAFCP is set
# - updates DirLen to trailer length
# - returns Fixup reference in dirInfo hash when writing
sub ProcessAFCP($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $curPos = $raf->Tell();
    my $offset = $$dirInfo{Offset} || 0;    # offset from end of file
    my $rtnVal = 0;

NoAFCP: for (;;) {
        my ($buff, $fix, $dirBuff, $valBuff, $fixup, $vers);
        # look for AXS trailer
        last unless $raf->Seek(-12-$offset, 2) and
                    $raf->Read($buff, 12) == 12 and
                    $buff =~ /^(AXS(!|\*))/;
        my $endPos = $raf->Tell();
        my $hdr = $1;
        SetByteOrder($2 eq '!' ? 'MM' : 'II');
        my $startPos = Get32u(\$buff, 4);
        if ($raf->Seek($startPos, 0) and $raf->Read($buff, 12) == 12 and $buff =~ /^$hdr/) {
            $fix = 0;
        } else {
            $rtnVal = -1;
            # look for start of AXS trailer if 'ScanForAFCP'
            last unless $$dirInfo{ScanForAFCP} and $raf->Seek($curPos, 0);
            my $actualPos = $curPos;
            # first look for header right at current position
            for (;;) {
                last if $raf->Read($buff, 12) == 12 and $buff =~ /^$hdr/;
                last NoAFCP if $actualPos != $curPos;
                # scan for AXS header (could be after preview image)
                for (;;) {
                    my $buf2;
                    $raf->Read($buf2, 65536) or last NoAFCP;
                    $buff .= $buf2;
                    if ($buff =~ /$hdr/g) {
                        $actualPos += pos($buff) - length($hdr);
                        last;   # ok, now go back and re-read header
                    }
                    $buf2 = substr($buf2, -3);  # only need last 3 bytes for next test
                    $actualPos += length($buff) - length($buf2);
                    $buff = $buf2;
                }
                last unless $raf->Seek($actualPos, 0);  # seek to start of AFCP
            }
            # calculate shift for fixing AFCP offsets
            $fix = $actualPos - $startPos;
        }
        # set variables returned in dirInfo hash
        $$dirInfo{DataPos} = $startPos + $fix;  # actual start position
        $$dirInfo{DirLen} = $endPos - ($startPos + $fix);

        $rtnVal = 1;
        my $verbose = $et->Options('Verbose');
        my $out = $et->Options('TextOut');
        my $outfile = $$dirInfo{OutFile};
        if ($outfile) {
            # allow all AFCP information to be deleted
            if ($$et{DEL_GROUP}{AFCP}) {
                $verbose and print $out "  Deleting AFCP\n";
                ++$$et{CHANGED};
                last;
            }
            $dirBuff = $valBuff = '';
            require Image::ExifTool::Fixup;
            $fixup = $$dirInfo{Fixup};
            $fixup or $fixup = $$dirInfo{Fixup} = new Image::ExifTool::Fixup;
            $vers = substr($buff, 4, 2); # get version number
        } else {
            $et->DumpTrailer($dirInfo) if $verbose or $$et{HTML_DUMP};
        }
        # read AFCP directory data
        my $numEntries = Get16u(\$buff, 6);
        my $dir;
        unless ($raf->Read($dir, 12 * $numEntries) == 12 * $numEntries) {
            $et->Error('Error reading AFCP directory', 1);
            last;
        }
        if ($verbose > 2 and not $outfile) {
            my $dat = $buff . $dir;
            print $out "  AFCP Directory:\n";
            HexDump(\$dat, undef,
                Addr   => $$dirInfo{DataPos},
                Width  => 12,
                Prefix => $$et{INDENT},
                Out => $out,
            );
        }
        $fix and $et->Warn("Adjusted AFCP offsets by $fix", 1);
#
# process AFCP directory
#
        my $tagTablePtr = GetTagTable('Image::ExifTool::AFCP::Main');
        my ($index, $entry);
        for ($index=0; $index<$numEntries; ++$index) {
            my $entry = 12 * $index;
            my $tag = substr($dir, $entry, 4);
            my $size = Get32u(\$dir, $entry + 4);
            my $offset = Get32u(\$dir, $entry + 8);
            if ($size < 0x80000000 and
                $raf->Seek($offset+$fix, 0) and
                $raf->Read($buff, $size) == $size)
            {
                if ($outfile) {
                    # rewrite this information
                    my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
                    if ($tagInfo and $$tagInfo{SubDirectory}) {
                        my %subdirInfo = (
                            DataPt => \$buff,
                            DirStart => 0,
                            DirLen => $size,
                            DataPos => $offset + $fix,
                            Parent => 'AFCP',
                        );
                        my $subTable = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                        my $newDir = $et->WriteDirectory(\%subdirInfo, $subTable);
                        if (defined $newDir) {
                            $size = length $newDir;
                            $buff = $newDir;
                        }
                    }
                    $fixup->AddFixup(length($dirBuff) + 8);
                    $dirBuff .= $tag . Set32u($size) . Set32u(length $valBuff);
                    $valBuff .= $buff;
                } else {
                    # extract information
                    $et->HandleTag($tagTablePtr, $tag, $buff,
                        DataPt => \$buff,
                        Size => $size,
                        Index => $index,
                        DataPos => $offset + $fix,
                    );
                }
            } else {
                $et->Warn("Bad AFCP directory");
                $rtnVal = -1 if $outfile;
                last;
            }
        }
        if ($outfile and length($dirBuff)) {
            my $outPos = Tell($outfile);    # get current outfile position
            # apply fixup to directory pointers
            my $valPos = $outPos + 12;      # start of value data
            $fixup->{Shift} += $valPos + length($dirBuff);
            $fixup->ApplyFixup(\$dirBuff);
            # write the AFCP header, directory, value data and EOF record (with zero checksums)
            Write($outfile, $hdr, $vers, Set16u(length($dirBuff)/12), Set32u(0),
                  $dirBuff, $valBuff, $hdr, Set32u($outPos), Set32u(0)) or $rtnVal = -1;
            # complete fixup so the calling routine can apply further shifts
            $fixup->AddFixup(length($dirBuff) + length($valBuff) + 4);
            $fixup->{Start} += $valPos;
            $fixup->{Shift} -= $valPos;
        }
        last;
    }
    return $rtnVal;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::AFCP - Read/write AFCP trailer

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract
information from the AFCP trailer.  Although the AFCP specification is
compatible with various file formats, ExifTool currently only processes AFCP
in JPEG images.

=head1 NOTES

AFCP is a specification which allows meta information (including IPTC) to be
appended to the end of a file.

It is a poorly designed protocol because (like TIFF) it uses absolute
offsets to specify data locations.  This is a huge blunder because it makes
the AFCP information dependent on the file length, so it is easily
invalidated by image editing software which doesn't recognize the AFCP
trailer to fix up these offsets when the file length changes.  ExifTool will
attempt to fix these invalid offsets if possible.

Scanning for AFCP information may be time consuming, especially when reading
from a sequential device, since the information is at the end of the file.
In these instances, the ExifTool FastScan option may be used to disable
scanning for AFCP information.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.tocarte.com/media/axs_afcp_spec.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/AFCP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

