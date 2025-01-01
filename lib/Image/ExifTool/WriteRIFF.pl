#------------------------------------------------------------------------------
# File:         WriteRIFF.pl
#
# Description:  Write RIFF-format files
#
# Revisions:    2020-09-26 - P. Harvey Created
#
# Notes:        Currently writes only WEBP files
#
# References:   https://developers.google.com/speed/webp/docs/riff_container
#------------------------------------------------------------------------------

package Image::ExifTool::RIFF;

use strict;

# map of where information is stored in WebP image
my %webpMap = (
   'XMP '        => 'RIFF', # (the RIFF chunk name is 'XMP ')
    EXIF         => 'RIFF',
    ICCP         => 'RIFF',
    C2PA         => 'RIFF',
    JUMBF        => 'C2PA',
    XMP          => 'XMP ',
    IFD0         => 'EXIF',
    IFD1         => 'IFD0',
    ICC_Profile  => 'ICCP',
    ExifIFD      => 'IFD0',
    GPS          => 'IFD0',
    SubIFD       => 'IFD0',
    GlobParamIFD => 'IFD0',
    PrintIM      => 'IFD0',
    InteropIFD   => 'ExifIFD',
    MakerNotes   => 'ExifIFD',
);

my %deletableGroup = (
    "XMP\0" => 'XMP', # delete incorrectly written "XMP\0" tag with XMP group
    SEAL => 'SEAL',   # delete SEAL tag with SEAL group
);

#------------------------------------------------------------------------------
# Write RIFF file (currently WebP-type only)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid RIFF file, or -1 if
#          an output file was specified and a write error occurred
sub WriteRIFF($$)
{
    my ($et, $dirInfo) = @_;
    $et or return 1;    # allow dummy access to autoload this package
    my $outfile = $$dirInfo{OutFile};
    my $outsize = 0;
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my ($buff, $err, $pass, %has, %dirDat, $imageWidth, $imageHeight);

    # do this in 2 passes so we can set the size of the containing RIFF chunk
    # without having to buffer the output (also to set the WebP_Flags)
    for ($pass=0; ; ++$pass) {
        my %doneDir;
        # verify this is a valid RIFF file
        return 0 unless $raf->Read($buff, 12) == 12;
        return 0 unless $buff =~ /^(RIFF|RF64)....(.{4})/s;

        unless ($1 eq 'RIFF' and $2 eq 'WEBP') {
            my $type = $2;
            $type =~ tr/-_a-zA-Z//dc;
            $et->Error("Can't currently write $1 $type files");
            return 1;
        }
        SetByteOrder('II');

        # determine which directories we must write for this file type
        $et->Options(Verbose => 0) if $pass;    # (avoid duplicate Verbose options here)
        $et->InitWriteDirs(\%webpMap);
        my $addDirs = $$et{ADD_DIRS};
        my $editDirs = $$et{EDIT_DIRS};
        $$addDirs{IFD0} = 'EXIF' if $$addDirs{EXIF}; # set flag to add IFD0 if adding EXIF (don't ask)
        my ($createVP8X, $deleteVP8X);

        # write header
        if ($pass) {
            $et->Options(Verbose => $verbose);
            my $needsVP8X = ($has{ANIM} or $has{'XMP '} or $has{EXIF} or
                             $has{ALPH} or $has{ICCP});
            if ($has{VP8X} and not $needsVP8X and $$et{CHANGED}) {
                $deleteVP8X = 1;    # delete the VP8X chunk
                $outsize -= 18;     # account for missing VP8X
            } elsif ($needsVP8X and not $has{VP8X}) {
                if (defined $imageWidth) {
                    ++$$et{CHANGED};
                    $createVP8X = 1;    # add VP8X chunk
                    $outsize += 18;     # account for VP8X size
                } else {
                    $et->Warn('Error getting image size for required VP8X chunk');
                }
            }
            # finally we can set the overall RIFF chunk size:
            Set32u($outsize - 8, \$buff, 4);
            Write($outfile, $buff) or $err = 1;
            # create VP8X chunk if necessary
            if ($createVP8X) {
                $et->VPrint(0,"  Adding required VP8X chunk (Extended WEBP)\n");
                my $flags = 0;
                $flags |= 0x02 if $has{ANIM};
                $flags |= 0x04 if $has{'XMP '};
                $flags |= 0x08 if $has{EXIF};
                $flags |= 0x10 if $has{ALPH};
                $flags |= 0x20 if $has{ICCP};
                Write($outfile, 'VP8X', pack('V3v', 10, $flags,
                    ($imageWidth-1) | ((($imageHeight-1) & 0xff) << 24),
                    ($imageHeight-1) >> 8));
                # write ICCP after VP8X
                Write($outfile, $dirDat{ICCP}) or $err = 1 if $dirDat{ICCP};
            }
        } else {
            $outsize += length $buff;
        }
        my $pos = 12;
#
# Read chunks in RIFF image
#
        for (;;) {
            my ($tag, $len);
            my $num = $raf->Read($buff, 8);
            if ($num < 8) {
                $num and $et->Error('RIFF format error'), return 1;
                # all done if we hit end of file unless we need to add EXIF or XMP
                last unless $$addDirs{EXIF} or $$addDirs{'XMP '} or $$addDirs{ICCP};
                # continue to add required EXIF or XMP chunks
                $num = $len = 0;
                $buff = $tag = '';
            } else {
                $pos += 8;
                ($tag, $len) = unpack('a4V', $buff);
                if ($len <= 0) {
                    if ($len < 0) {
                        $et->Error('Invalid chunk length');
                        return 1;
                    } elsif ($tag eq "\0\0\0\0") {
                        # avoid reading through corrupted files filled with nulls because it takes forever
                        $et->Error('Encountered empty null chunk. Processing aborted');
                        return 1;
                    } else { # (just in case a tag may have no data)
                        if ($pass) {
                            Write($outfile, $buff) or $err = 1;
                        } else {
                            $outsize += length $buff;
                        }
                        next;
                    }
                }
            }
            # RIFF chunks are padded to an even number of bytes
            my $len2 = $len + ($len & 0x01);
            # handle incorrect "XMP\0" chunk ID written by Google software
            if ($deletableGroup{$tag}) {
                if ($$et{DEL_GROUP}{$deletableGroup{$tag}}) {
                    # just ignore this chunk if deleting the associated group
                    $raf->Seek($len2, 1) or $et->Error('Seek error'), last;
                    $et->VPrint(0, "  Deleting $deletableGroup{$tag}\n") if $pass;
                    ++$$et{CHANGED};
                    next;
                } elsif ($tag eq "XMP\0") {
                    $et->Warn('Incorrect XMP tag ID',1) if $pass;
                }
            }
            # edit/add/delete necessary metadata chunks (EXIF must come before XMP)
            if ($$editDirs{$tag} or $tag eq '' or ($tag eq 'XMP ' and $$addDirs{EXIF})) {
                my $handledTag;
                if ($len2) {
                    $et->Warn("Duplicate '${tag}' chunk") if $doneDir{$tag} and not $pass;
                    $doneDir{$tag} = 1;
                    $raf->Read($buff, $len2) == $len2 or $et->Error("Truncated '${tag}' chunk"), last;
                    $pos += $len2;  # update current position
                } else {
                    $buff = '';
                }
#
# add/edit/delete EXIF/XMP/ICCP (note: EXIF must come before XMP, and ICCP is written elsewhere)
#
                my %dirName = ( EXIF => 'IFD0', 'XMP ' => 'XMP', ICCP => 'ICC_Profile', C2PA => 'JUMBF' );
                my %tblName = ( EXIF => 'Exif', 'XMP ' => 'XMP', ICCP => 'ICC_Profile', C2PA => 'Jpeg2000' );
                my $dir;
                foreach $dir ('EXIF', 'XMP ', 'ICCP', 'C2PA' ) {
                    next unless $tag eq $dir or ($$addDirs{$dir} and
                        ($tag eq '' or ($tag eq 'XMP ' and $dir eq 'EXIF')));
                    my $start;
                    unless ($pass) {
                        # write the EXIF and save the result for the next pass
                        my $dataPt = \$buff;
                        if ($tag eq 'EXIF') {
                            # (only need to set directory $start for EXIF)
                            if ($buff =~ /^Exif\0\0/) {
                                if ($$et{DEL_GROUP}{EXIF}) {
                                    # remove incorrect header if rewriting anyway
                                    $buff = substr($buff, 6);
                                    $len -= 6;
                                    $len2 -= 6;
                                } else {
                                    $et->Warn('Improper EXIF header',1) unless $pass;
                                    $start = 6;
                                }
                            } else {
                                $start = 0;
                            }
                        } elsif ($dir ne $tag) {
                            # create from scratch
                            my $buf2 = '';
                            $dataPt = \$buf2;
                        }
                        # write the new directory to memory
                        my %dirInfo = (
                            DataPt   => $dataPt,
                            DataPos  => 0,      # (relative to Base)
                            DirStart => $start,
                            Base     => $pos - $len2,
                            Parent   => $dir,
                            DirName  => $dirName{$dir},
                        );
                        # must pass the TagInfo to enable deletion of C2PA information
                        if (ref $Image::ExifTool::RIFF::Main{$dir} eq 'HASH') {
                            $dirInfo{TagInfo} = $Image::ExifTool::RIFF::Main{$dir};
                        }
                        my $tagTablePtr = GetTagTable("Image::ExifTool::$tblName{$dir}::Main");
                        # (override writeProc for EXIF because it has the TIFF header)
                        my $writeProc = $dir eq 'EXIF' ? \&Image::ExifTool::WriteTIFF : undef;
                        $dirDat{$dir} = $et->WriteDirectory(\%dirInfo, $tagTablePtr, $writeProc);
                    }
                    delete $$addDirs{$dir}; # (don't try to add again)
                    if (defined $dirDat{$dir}) {
                        if ($dir eq $tag) {
                            $handledTag = 1;    # set flag indicating we edited this tag
                            # increment CHANGED count if we are deleting the directory
                            ++$$et{CHANGED} unless length $dirDat{$dir};
                        }
                        if (length $dirDat{$dir}) {
                            if ($pass) {
                                # write metadata chunk now (but not ICCP because it was added earlier)
                                Write($outfile, $dirDat{$dir}) or $err = 1 unless $dir eq 'ICCP';
                            } else {
                                # preserve (incorrect EXIF) header if it existed
                                my $hdr = $start ? substr($buff,0,$start) : '';
                                # (don't overwrite $len here because it may be XMP length)
                                my $dirLen = length($dirDat{$dir}) + length($hdr);
                                # add chunk header and padding
                                my $pad = $dirLen & 0x01 ? "\0" : '';
                                $dirDat{$dir} = $dir . Set32u($dirLen) . $hdr . $dirDat{$dir} . $pad;
                                $outsize += length($dirDat{$dir});
                                $has{$dir} = 1;
                            }
                        }
                    }
                }
#
# just copy XMP, EXIF or ICC if nothing changed
#
                if (not $handledTag and length $buff) {
                    # write the chunk without changes
                    if ($pass) {
                        Write($outfile, $tag, Set32u($len), $buff) or $err = 1;
                    } else {
                        $outsize += 8 + length($buff);
                        $has{$tag} = 1;
                    }
                }
                next;
            }
            $pos += $len2;  # set read position at end of chunk data
#
# update necessary flags in VP8X chunk
#
            if ($tag eq 'VP8X') {
                my $buf2;
                if ($len2 < 10 or $raf->Read($buf2, $len2) != $len2) {
                    $et->Error('Truncated VP8X chunk');
                    return 1;
                }
                if ($pass) {
                    if ($deleteVP8X) {
                        $et->VPrint(0,"  Deleting unnecessary VP8X chunk (Standard WEBP)\n");
                        next;
                    }
                    # ...but first set the VP8X flags
                    my $flags = Get32u(\$buf2, 0);
                    $flags &= ~0x2c; # (reset flags for everything we can write)
                    $flags |= 0x04 if $has{'XMP '};
                    $flags |= 0x08 if $has{EXIF};
                    $flags |= 0x20 if $has{ICCP};
                    Set32u($flags, \$buf2, 0);
                    Write($outfile, $buff, $buf2) or $err = 1;
                } else {
                    # get the image size
                    $imageWidth  = (Get32u(\$buf2, 4) & 0xffffff) + 1;
                    $imageHeight = (Get32u(\$buf2, 6) >> 8) + 1;
                    $outsize += 8 + $len2;
                    $has{$tag} = 1;
                }
                # write ICCP after VP8X
                Write($outfile, $dirDat{ICCP}) or $err = 1 if $dirDat{ICCP};
                next;
            }
#
# just copy all other chunks
#
            if ($pass) {
                # write chunk header (still in $buff)
                Write($outfile, $buff) or $err = 1;
            } else {
                $outsize += length $buff;
                $has{$tag} = 1;
            }
            unless ($pass or defined $imageWidth) {
                # get WebP image size from VP8 or VP8L header
                if ($tag eq 'VP8 ' and $len2 >= 16) {
                    $raf->Read($buff, 16) == 16 or $et->Error('Truncated VP8 chunk'), return 1;
                    $outsize += 16;
                    if ($buff =~ /^...\x9d\x01\x2a/s) {
                        $imageWidth  = Get16u(\$buff, 6) & 0x3fff;
                        $imageHeight = Get16u(\$buff, 8) & 0x3fff;
                    }
                    $len2 -= 16;
                } elsif ($tag eq 'VP8L' and $len2 >= 6) {
                    $raf->Read($buff, 6) == 6 or $et->Error('Truncated VP8L chunk'), return 1;
                    $outsize += 6;
                    if ($buff =~ /^\x2f/s) {
                        $imageWidth  =  (Get16u(\$buff, 1) & 0x3fff) + 1;
                        $imageHeight = ((Get32u(\$buff, 2) >> 6) & 0x3fff) + 1;
                    }
                    $len2 -= 6;
                }
            }
            if ($pass) {
                # copy the chunk data in 64k blocks
                while ($len2) {
                    my $num = $len2;
                    $num = 65536 if $num > 65536;
                    $raf->Read($buff, $num) == $num or $et->Error('Truncated RIFF chunk'), last;
                    Write($outfile, $buff) or $err = 1, last;
                    $len2 -= $num;
                }
            } else {
                $raf->Seek($len2, 1) or $et->Error('Seek error'), last;
                $outsize += $len2;
            }
        }
        last if $pass;
        $raf->Seek(0,0) or $et->Error('Seek error'), last;
    }
    return $err ? -1 : 1;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::WriteRIFF.pl - Write RIFF-format files

=head1 SYNOPSIS

This file is autoloaded by Image::ExifTool::RIFF.

=head1 DESCRIPTION

This file contains routines to write metadata to RIFF-format files.

=head1 NOTES

Currently writes only WebP files.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://developers.google.com/speed/webp/docs/riff_container>

=back

=head1 SEE ALSO

L<Image::ExifTool::Photoshop(3pm)|Image::ExifTool::RIFF>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
