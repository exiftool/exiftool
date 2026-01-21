#------------------------------------------------------------------------------
# File:         ICO.pm
#
# Description:  Read Windows ICO and CUR files
#
# Revisions:    2020-10-18 - P. Harvey Created
#
# References:   1) https://docs.fileformat.com/image/ico/
#------------------------------------------------------------------------------

package Image::ExifTool::ICO;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.01';

%Image::ExifTool::ICO::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    NOTES => 'Information extracted from Windows ICO (icon) and CUR (cursor) files.',
    2 => {
        Name => 'ImageType',
        Format => 'int16u',
        PrintConv => { 1 => 'Icon', 2 => 'Cursor' },
    },
    4 => {
        Name => 'ImageCount',
        Format => 'int16u',
        RawConv => '$$self{ImageCount} = $val',
    },
    6 => {
        Name => 'IconDir',
        SubDirectory => { TagTable => 'Image::ExifTool::ICO::IconDir' },
    },
);

%Image::ExifTool::ICO::IconDir = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    0 => {
        Name => 'ImageWidth',
        ValueConv => '$val or $val + 256',
    },
    1 => {
        Name => 'ImageHeight',
        ValueConv => '$val or $val + 256',
    },
    2 => 'NumColors',
    4 => [{
        Name => 'ColorPlanes',
        Condition => '$$self{FileType} eq "ICO"',
        Format => 'int16u',
        Notes => 'ICO files',
    },{
        Name => 'HotspotX',
        Format => 'int16u',
        Notes => 'CUR files',
    }],
    6 => [{
        Name => 'BitsPerPixel',
        Condition => '$$self{FileType} eq "ICO"',
        Format => 'int16u',
        Notes => 'ICO files',
    },{
        Name => 'HotspotY',
        Format => 'int16u',
        Notes => 'CUR files',
    }],
    8 => {
        Name => 'ImageLength',
        Format => 'int32u',
    },
);

#------------------------------------------------------------------------------
# Process ICO/CUR file
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid ICO/CUR file
sub ProcessICO($$$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($i, $buff);
    # verify this is a valid ICO/CUR file
    return 0 unless $raf->Read($buff, 6) == 6;
    return 0 unless $buff =~ /^\0\0([\x01\x02])\0[^0]\0/s;
    # (note: have seen cursor files in the wild with an 0x01 here,
    # but SetFileType will use the .cur extension to identify these)
    $et->SetFileType($1 eq "\x01" ? 'ICO' : 'CUR');
    SetByteOrder('II');
    my $tagTbl = GetTagTable('Image::ExifTool::ICO::Main');
    my $num = Get16u(\$buff, 4);
    $et->HandleTag($tagTbl, 4, $num);
    for ($i=0; $i<$num; ++$i) {
        $raf->Read($buff, 16) == 16 or $et->Warn('Truncated file'), last;
        $$et{DOC_NUM} = ++$$et{DOC_COUNT};
        $et->HandleTag($tagTbl, 6, $buff);
    }
    delete $$et{DOC_NUM};
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::ICO - Read ICO meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read
information from Windows ICO (icon) and CUR (cursor) files.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://docs.fileformat.com/image/ico/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/ICO Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

