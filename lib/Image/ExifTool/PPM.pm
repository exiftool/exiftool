#------------------------------------------------------------------------------
# File:         PPM.pm
#
# Description:  Read and write PPM meta information
#
# Revisions:    09/03/2005 - P. Harvey Created
#
# References:   1) http://netpbm.sourceforge.net/doc/ppm.html
#               2) http://netpbm.sourceforge.net/doc/pgm.html
#               3) http://netpbm.sourceforge.net/doc/pbm.html
#------------------------------------------------------------------------------

package Image::ExifTool::PPM;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.07';

#------------------------------------------------------------------------------
# Read or write information in a PPM/PGM/PBM image
# Inputs: 0) ExifTool object reference, 1) Directory information reference
# Returns: 1 on success, 0 if this wasn't a valid PPM file, -1 on write error
sub ProcessPPM($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $outfile = $$dirInfo{OutFile};
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');
    my ($buff, $num, $type, %info);
#
# read as much of the image as necessary to extract the header and comments
#
    for (;;) {
        if (defined $buff) {
            # need to read some more data
            my $tmp;
            return 0 unless $raf->Read($tmp, 1024);
            $buff .= $tmp;
        } else {
            return 0 unless $raf->Read($buff, 1024);
        }
        # verify this is a valid PPM file
        return 0 unless $buff =~ /^P([1-6])\s+/g;
        $num = $1;
        # note: may contain comments starting with '#'
        if ($buff =~ /\G#/gc) {
            # must read more if we are in the middle of a comment
            next unless $buff =~ /\G ?(.*\n(#.*\n)*)\s*/g;
            $info{Comment} = $1;
            next if $buff =~ /\G#/gc;
        } else {
            delete $info{Comment};
        }
        next unless $buff =~ /\G(\S+)\s+(\S+)\s/g;
        $info{ImageWidth} = $1;
        $info{ImageHeight} = $2;
        $type = [qw{PPM PBM PGM}]->[$num % 3];
        last if $type eq 'PBM'; # (no MaxVal for PBM images)
        if ($buff =~ /\G\s*#/gc) {
            next unless $buff =~ /\G ?(.*\n(#.*\n)*)\s*/g;
            $info{Comment} = '' unless exists $info{Comment};
            $info{Comment} .= $1;
            next if $buff =~ /\G#/gc;
        }
        next unless $buff =~ /\G(\S+)\s/g;
        $info{MaxVal} = $1;
        last;
    }
    # validate numerical values
    foreach (keys %info) {
        next if $_ eq 'Comment';
        return 0 unless $info{$_} =~ /^\d+$/;
    }
    if (defined $info{Comment}) {
        $info{Comment} =~ s/^# ?//mg;   # remove "# " at the start of each line
        $info{Comment} =~ s/\n$//;      # remove trailing newline
    }
    $et->SetFileType($type);
    my $len = pos($buff);
#
# rewrite the file if requested
#
    if ($outfile) {
        my $nvHash;
        my $newComment = $et->GetNewValues('Comment', \$nvHash);
        my $oldComment = $info{Comment};
        if ($et->IsOverwriting($nvHash, $oldComment)) {
            ++$$et{CHANGED};
            $et->VerboseValue('- Comment', $oldComment) if defined $oldComment;
            $et->VerboseValue('+ Comment', $newComment) if defined $newComment;
        } else {
            $newComment = $oldComment;  # use existing comment
        }
        my $hdr = "P$num\n";
        if (defined $newComment) {
            $newComment =~ s/\n/\n# /g;
            $hdr .= "# $newComment\n";
        }
        $hdr .= "$info{ImageWidth} $info{ImageHeight}\n";
        $hdr .= "$info{MaxVal}\n" if $type ne 'PBM';
        # write header and start of image
        Write($outfile, $hdr, substr($buff, $len)) or return -1;
        # copy over the rest of the image
        while ($raf->Read($buff, 0x10000)) {
            Write($outfile, $buff) or return -1;
        }
        return 1;
    }
#
# save extracted information
#
    if ($verbose > 2) {
        print $out "$type header ($len bytes):\n";
        HexDump(\$buff, $len, Out => $out);
    }
    my $tag;
    foreach $tag (qw{Comment ImageWidth ImageHeight MaxVal}) {
        $et->FoundTag($tag, $info{$tag}) if defined $info{$tag};
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::PPM - Read and write PPM meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read and
write PPM (Portable Pixel Map), PGM (Portable Gray Map) and PBM (Portable
BitMap) images.

=head1 AUTHOR

Copyright 2003-2015, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://netpbm.sourceforge.net/doc/ppm.html>

=item L<http://netpbm.sourceforge.net/doc/pgm.html>

=item L<http://netpbm.sourceforge.net/doc/pbm.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PPM Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

