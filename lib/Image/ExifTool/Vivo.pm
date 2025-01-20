#------------------------------------------------------------------------------
# File:         Vivo.pm
#
# Description:  Read trailer written by Vivo phones
#
# Revisions:    2025-01-13 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Vivo;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::XMP;

$VERSION = '1.00';

%Image::ExifTool::Vivo::Main = (
    GROUPS => { 0 => 'Trailer', 1 => 'Vivo', 2 => 'Image' },
    VARS => { NO_ID => 1 },
    NOTES => 'Proprietary information written by some Vivo phones.',
    # (don't know for sure what type of image this is, but it is in JPEG format)
    HDRImage => {
        Notes => 'highlights of HDR image',
        Groups => { 2 => 'Preview' },
        Binary => 1,
    },
    JSONInfo => { },
    HiddenData => {
        Notes => 'hidden in EXIF, not in trailer.  This data is lost if the file is edited',
        Groups => { 0 => 'EXIF' },
    },
);

#------------------------------------------------------------------------------
# Process Vivo trailer
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, -1 if we must scan for the start of the trailer
# - takes Offset as positive offset from end of trailer to end of file,
#   and returns DataPos and DirLen, and updates OutFile when writing
sub ProcessVivo($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;

    # return now unless we are at a position to scan for the trailer
    # (must scan because the trailer footer doesn't indicate the trailer length)
    return -1 unless $$dirInfo{ScanForTrailer};

    my $pos = $raf->Tell();
    $raf->Seek(0, 2) or return 0;
    my $len = $raf->Tell() - $pos - $$dirInfo{Offset};
    $raf->Seek($pos, 0) or return 0;
    return 0 unless $len > 0 and $len < 1e7 and $raf->Read($buff, $len) == $len and
        $buff =~ /\xff{4}\x1b\*9HWfu\x84\x93\xa2\xb1$/ and # validate footer
        $buff =~ /(streamdata|vivo\{")/g;   # find start
    my $start = pos($buff) - length($1);
    if ($start) {
        $pos += $start;
        $len -= $start;
        $buff = substr($buff, $start);
    }
    # set trailer position and length 
    @$dirInfo{'DataPos','DirLen'} = ($pos, $len);

    if ($$dirInfo{OutFile}) {
        if ($$et{DEL_GROUP}{Vivo}) {
            $et->VPrint(0, "  Deleting Vivo trailer ($len bytes)\n");
            ++$$et{CHANGED};
        } else {
            $et->VPrint(0, "  Copying Vivo trailer ($len bytes)\n");
            Write($$dirInfo{OutFile}, $buff);
        }
    } else {
        $et->DumpTrailer($dirInfo) if $$et{OPTIONS}{Verbose} or $$et{HTML_DUMP};
        my $tbl = GetTagTable('Image::ExifTool::Vivo::Main');
        pos($buff) = 0; # rewind search to start of buffer
        if ($buff =~ /^streamdata\xff\xd8\xff/ and $buff =~ /\xff\xd9stream(info|coun)/g) {
            $et->HandleTag($tbl, HDRImage => substr($buff, 10, pos($buff)-20));
        }
        # continue looking for Vivo JSON data
        if ($buff =~ /vivo\{"/g) {
            my $jsonStart = pos($buff) - 2;
            if ($buff =~ /\}\0/g) {
                my $jsonLen = pos($buff) - 1 - $jsonStart;
                $et->HandleTag($tbl, JSONInfo => substr($buff, $jsonStart, $jsonLen));
            }
        }
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Vivo - Read trailer written by Vivo phones

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read
metadata the trailer written by some Vivo phones.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Vivo Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

