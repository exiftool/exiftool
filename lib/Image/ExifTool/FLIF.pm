#------------------------------------------------------------------------------
# File:         FLIF.pm
#
# Description:  Read/write FLIF meta information
#
# Revisions:    2016/10/11 - P. Harvey Created
#               2016/10/14 - PH Added write support
#
# References:   1) http://flif.info/
#               2) https://github.com/FLIF-hub/FLIF/blob/master/doc/metadata
#------------------------------------------------------------------------------

package Image::ExifTool::FLIF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.02';

my %flifMap = (
    EXIF         => 'FLIF',
    XMP          => 'FLIF',
    ICC_Profile  => 'FLIF',
    IFD0         => 'EXIF',
    IFD1         => 'IFD0',
    ExifIFD      => 'IFD0',
    GPS          => 'IFD0',
    SubIFD       => 'IFD0',
    GlobParamIFD => 'IFD0',
    PrintIM      => 'IFD0',
    InteropIFD   => 'ExifIFD',
    MakerNotes   => 'ExifIFD',
);

# FLIF tags
%Image::ExifTool::FLIF::Main = (
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    VARS => { ID_FMT => 'dec' },
    NOTES => q{
        Information extracted from Free Lossless Image Format files.  See
        L<http://flif.info/> for more information.
    },
#
# header information
#
    0 => {
        Name => 'ImageType',
        PrintConv => {
            '1' => 'Grayscale (non-interlaced)',
            '3' => 'RGB (non-interlaced)',
            '4' => 'RGBA (non-interlaced)',
            'A' => 'Grayscale (interlaced)',
            'C' => 'RGB (interlaced)',
            'D' => 'RGBA (interlaced)',
            'Q' => 'Grayscale Animation (non-interlaced)',
            'S' => 'RGB Animation (non-interlaced)',
            'T' => 'RGBA Animation (non-interlaced)',
            'a' => 'Grayscale Animation (interlaced)',
            'c' => 'RGB Animation (interlaced)',
            'd' => 'RGBA Animation (interlaced)',
        },
    },
    1 => {
        Name => 'BitDepth',
        PrintConv => {
            '0' => 'Custom',
            '1' => 8,
            '2' => 16,
        },
    },
    2 => 'ImageWidth',
    3 => 'ImageHeight',
    4 => 'AnimationFrames',
    5 => {
        Name => 'Encoding',
        PrintConv => {
            0 => 'FLIF16',
        },
    },
#
# metadata chunks
#
    iCCP => {
        Name => 'ICC_Profile',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Main',
        },
    },
    eXif => {
        Name => 'EXIF',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            WriteProc => \&Image::ExifTool::WriteTIFF,
            Start => 6, # (skip "Exif\0\0" header)
            Header => "Exif\0\0",
        },
    },
    eXmp => {
        Name => 'XMP',
        SubDirectory => {
            TagTable => 'Image::ExifTool::XMP::Main',
        },
    },
    # tRko - list of truncation offsets
    # \0 - FLIF16-format image data
);

#------------------------------------------------------------------------------
# Read variable-length FLIF integer
# Inputs: 0) raf reference, 1) number to add to returned value
# Returns: integer, or undef on EOF
sub GetVarInt($;$)
{
    my ($raf, $add) = @_;
    my ($val, $buff);
    for ($val=0; ; $val<<=7) {
        $raf->Read($buff, 1) or return undef;
        my $byte = ord($buff);
        $val |= ($byte & 0x7f);
        last unless $byte & 0x80;
    }
    return $val + ($add || 0);
}

#------------------------------------------------------------------------------
# Construct variable-length FLIF integer
# Inputs: 0) integer
# Returns: FLIF variable-length integer byte stream
sub SetVarInt($)
{
    my $val = shift;
    my $buff = '';
    my $high = 0;
    for (;;) {
        $buff = chr(($val & 0x7f) | $high) . $buff;
        last unless $val >>= 7;
        $high = 0x80;
    }
    return $buff;
}

#------------------------------------------------------------------------------
# Read FLIF header
# Inputs: 0) RAF ref
# Returns: Scalar context: binary header block
#          List context: header values (4 or 5 elements: type,depth,width,height[,frames])
#          or undef if this isn't a valid FLIF file header
sub ReadFLIFHeader($)
{
    my $raf = shift;
    my ($buff, @vals);

    # verify this is a valid FLIF file
    return () unless $raf->Read($buff, 6) == 6 and $buff =~ /^FLIF([0-\x6f])([0-2])/;

    # decode header information ("FLIF" chunk)
    push @vals, $1, $2;                                 # type, depth
    push @vals, GetVarInt($raf,+1), GetVarInt($raf,+1); # width, height (+1 each)
    push @vals, GetVarInt($raf,+2) if $vals[0] gt 'H';  # frames (+2)

    return () unless defined $vals[-1];
    return @vals if wantarray;      # return the decoded header values

    # return the binary header block
    my $hdrLen = $raf->Tell();
    return () unless $raf->Seek(0,0) and $raf->Read($buff, $hdrLen) == $hdrLen;
    return $buff;
}

#------------------------------------------------------------------------------
# WriteFLIF : Write FLIF image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid FLIF file, or -1 if
#          an output file was specified and a write error occurred
sub WriteFLIF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $soi, @addTags, %doneTag);

    # verify FLIF header and copy it to the output file
    $buff = ReadFLIFHeader($raf) or return 0;
    my $outfile = $$dirInfo{OutFile};
    Write($outfile, $buff) or return -1;

    $et->InitWriteDirs(\%flifMap);
    my $tagTablePtr = GetTagTable('Image::ExifTool::FLIF::Main');

    # loop through the FLIF chunks
    for (;;) {
        my ($tag, $size, $inflated);
        # read new tag (or soi) unless we already hit the soi (start of image)
        if (not defined $soi) {
            $raf->Read($buff, 4) == 4 or $et->Error('Unexpected EOF'), last;
            if ($buff lt ' ') {
                $soi = $buff;   # we have hit the start of image (no more metadata)
                # make list of new tags to add
                foreach $tag ('eXif', 'eXmp', 'iCCP') {
                    push @addTags, $tag if $$et{ADD_DIRS}{$$tagTablePtr{$tag}{Name}} and not $doneTag{$tag};
                }
            }
        }
        if (not defined $soi) {
            $tag = $buff;
            $size = GetVarInt($raf);    # read the data size
        } elsif (@addTags) {
            $tag = shift @addTags;
            ($buff, $size) = ('', 0);   # create metadata from scratch
        } else {
            # finish copying file (no more metadata to add)
            Write($outfile, $soi) or return -1;
            Write($outfile, $buff) or return -1 while $raf->Read($buff, 65536);
            last;   # all done!
        }
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if ($tagInfo and $$tagInfo{SubDirectory} and $$et{EDIT_DIRS}{$$tagInfo{Name}}) {
            $doneTag{$tag} = 1;         # prevent adding this back again later
            unless (defined $soi) {
                $raf->Read($buff, $size) == $size or $et->Error("Truncated FLIF $tag chunk"), last;
            }
            # rewrite the compressed data
            if (eval { require IO::Uncompress::RawInflate } and eval { require IO::Compress::RawDeflate } ) {
                if (length $buff == 0) {
                    $inflated = $buff;  # (creating from scratch, so no need to inflate)
                } elsif (not IO::Uncompress::RawInflate::rawinflate(\$buff => \$inflated)) {
                    $et->Error("Error inflating FLIF $tag chunk"), last;
                }
                my $subdir = $$tagInfo{SubDirectory};
                my %subdirInfo = (
                    DirName  => $$tagInfo{Name},
                    DataPt   => \$inflated,
                    DirStart => length($inflated) ? $$subdir{Start} : undef,
                    ReadOnly => 1,      # (used only by WriteXMP)
                );
                my $subTable = GetTagTable($$subdir{TagTable});
                $inflated = $et->WriteDirectory(\%subdirInfo, $subTable, $$subdir{WriteProc});
                if (defined $inflated) {
                    next unless length $inflated; # (delete directory if length is zero)
                    $inflated = $$subdir{Header} . $inflated if $$subdir{Header}; # (add back header if necessary)
                    unless (IO::Compress::RawDeflate::rawdeflate(\$inflated => \$buff)) {
                        $et->Error("Error deflating FLIF $tag chunk"), last;
                    }
                }
            } else {
                $et->Warn('Install IO::Compress::RawDeflate to write FLIF metadata');
            }
            Write($outfile, $tag, SetVarInt(length $buff), $buff) or return -1;
        } elsif (not defined $soi) {
            Write($outfile, $tag, SetVarInt($size)) or return -1;
            Image::ExifTool::CopyBlock($raf, $outfile, $size) or return -1;
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from an FLIF file
# Inputs: 0) ExifTool object reference, 1) DirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid FLIF file
sub ProcessFLIF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $tag, $inflated);

    # verify this is a valid FLIF file and read the header
    my @vals = ReadFLIFHeader($raf) or return 0;

    $et->SetFileType();
    my $tagTablePtr = GetTagTable('Image::ExifTool::FLIF::Main');
    my $verbose = $et->Options('Verbose');

    # save the header information
    $et->VPrint(0, "FLIF header:\n") if $verbose;
    for ($tag=0; defined $vals[$tag]; ++$tag) {
        $et->HandleTag($tagTablePtr, $tag, $vals[$tag]);
    }

    # loop through the FLIF chunks
    for (;;) {
        $raf->Read($tag, 4) == 4 or $et->Warn('Unexpected EOF'), last;
        my $byte = ord substr($tag, 0, 1);
        # all done if we arrived at the image chunk
        $byte < 32 and $et->HandleTag($tagTablePtr, 5, $byte), last;
        my $size = GetVarInt($raf);
        $et->VPrint(0, "FLIF $tag ($size bytes):\n") if $verbose;
        if ($$tagTablePtr{$tag}) {
            $raf->Read($buff, $size) == $size or $et->Warn("Truncated FLIF $tag chunk"), last;
            $et->VerboseDump(\$buff, Addr => $raf->Tell() - $size) if $verbose > 2;
            # inflate the compressed data
            if (eval { require IO::Uncompress::RawInflate }) {
                if (IO::Uncompress::RawInflate::rawinflate(\$buff => \$inflated)) {
                    $et->HandleTag($tagTablePtr, $tag, $inflated,
                        DataPt => \$inflated,
                        Size => length $inflated,
                        Extra => ' inflated',
                    );
                } else {
                    $et->Warn("Error inflating FLIF $tag chunk");
                }
            } else {
                $et->Warn('Install IO::Uncompress::RawInflate to decode FLIF metadata');
            }
        } else {
            $raf->Seek($size, 1) or $et->Warn('Seek error'), last;
        }
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::FLIF - Read/write FLIF meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read and write
meta information in FLIF (Free Lossless Image Format) images.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://flif.info/>

=item L<https://github.com/FLIF-hub/FLIF/blob/master/doc/metadata>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/FLIF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

