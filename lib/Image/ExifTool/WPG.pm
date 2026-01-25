#------------------------------------------------------------------------------
# File:         WPG.pm
#
# Description:  Read WordPerfect Graphics meta information
#
# Revisions:    2023-05-01 - P. Harvey Created
#
# References:   1) https://www.fileformat.info/format/wpg/egff.htm
#               2) https://archive.org/details/mac_Graphics_File_Formats_Second_Edition_1996/page/n991/mode/2up
#               3) http://libwpg.sourceforge.net/
#------------------------------------------------------------------------------

package Image::ExifTool::WPG;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

sub PrintRecord($$$);

# WPG metadata
%Image::ExifTool::WPG::Main = (
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    VARS => { ID_FMT => 'none' },
    NOTES => 'Tags extracted from WordPerfect Graphics (WPG) images.',
    WPGVersion => { },
    ImageWidthInches  => { PrintConv => 'sprintf("%.2f",$val)' },
    ImageHeightInches => { PrintConv => 'sprintf("%.2f",$val)' },
    Records => {
        Notes => 'records for version 1.0 files',
        List => 1,
        PrintHex => 2,
        PrintConvColumns => 2,
        PrintConv => {
            OTHER => \&PrintRecord,
            0x01 => 'Fill Attributes',
            0x02 => 'Line Attributes',
            0x03 => 'Marker Attributes',
            0x04 => 'Polymarker',
            0x05 => 'Line',
            0x06 => 'Polyline',
            0x07 => 'Rectangle',
            0x08 => 'Polygon',
            0x09 => 'Ellipse',
            0x0a => 'Reserved',
            0x0b => 'Bitmap (Type 1)',
            0x0c => 'Graphics Text (Type 1)',
            0x0d => 'Graphics Text Attributes',
            0x0e => 'Color Map',
            0x0f => 'Start WPG (Type 1)',
            0x10 => 'End WPG',
            0x11 => 'PostScript Data (Type 1)',
            0x12 => 'Output Attributes',
            0x13 => 'Curved Polyline',
            0x14 => 'Bitmap (Type 2)',
            0x15 => 'Start Figure',
            0x16 => 'Start Chart',
            0x17 => 'PlanPerfect Data',
            0x18 => 'Graphics Text (Type 2)',
            0x19 => 'Start WPG (Type 2)',
            0x1a => 'Graphics Text (Type 3)',
            0x1b => 'PostScript Data (Type 2)',
        },
    },
    RecordsV2 => {
        Notes => 'records for version 2.0 files',
        List => 1,
        PrintHex => 2,
        PrintConvColumns => 2,
        PrintConv => {
            OTHER => \&PrintRecord,
            0x00 => 'End Marker',
            0x01 => 'Start WPG',
            0x02 => 'End WPG',
            0x03 => 'Form Settings',
            0x04 => 'Ruler Settings',
            0x05 => 'Grid Settings',
            0x06 => 'Layer',
            0x08 => 'Pen Style Definition',
            0x09 => 'Pattern Definition',
            0x0a => 'Comment',
            0x0b => 'Color Transfer',
            0x0c => 'Color Palette',
            0x0d => 'DP Color Palette',
            0x0e => 'Bitmap Data',
            0x0f => 'Text Data',
            0x10 => 'Chart Style',
            0x11 => 'Chart Data',
            0x12 => 'Object Image',
            0x15 => 'Polyline',
            0x16 => 'Polyspline',
            0x17 => 'Polycurve',
            0x18 => 'Rectangle',
            0x19 => 'Arc',
            0x1a => 'Compound Polygon',
            0x1b => 'Bitmap',
            0x1c => 'Text Line',
            0x1d => 'Text Block',
            0x1e => 'Text Path',
            0x1f => 'Chart',
            0x20 => 'Group',
            0x21 => 'Object Capsule',
            0x22 => 'Font Settings',
            0x25 => 'Pen Fore Color',
            0x26 => 'DP Pen Fore Color',
            0x27 => 'Pen Back Color',
            0x28 => 'DP Pen Back Color',
            0x29 => 'Pen Style',
            0x2a => 'Pen Pattern',
            0x2b => 'Pen Size',
            0x2c => 'DP Pen Size',
            0x2d => 'Line Cap',
            0x2e => 'Line Join',
            0x2f => 'Brush Gradient',
            0x30 => 'DP Brush Gradient',
            0x31 => 'Brush Fore Color',
            0x32 => 'DP Brush Fore Color',
            0x33 => 'Brush Back Color',
            0x34 => 'DP Brush Back Color',
            0x35 => 'Brush Pattern',
            0x36 => 'Horizontal Line',
            0x37 => 'Vertical Line',
            0x38 => 'Poster Settings',
            0x39 => 'Image State',
            0x3a => 'Envelope Definition',
            0x3b => 'Envelope',
            0x3c => 'Texture Definition',
            0x3d => 'Brush Texture',
            0x3e => 'Texture Alignment',
            0x3f => 'Pen Texture ',
        }
    },
);

#------------------------------------------------------------------------------
# Print record type
# Inputs: 0) record type and count, 1) inverse flag, 2) PrintConv hash ref
# Returns: converted record name
sub PrintRecord($$$)
{
    my ($val, $inv, $printConv) = @_;
    my ($type, $count) = split 'x', $val;
    my $prt = $$printConv{$type} || sprintf('Unknown (0x%.2x)', $type);
    $prt .= " x $count" if $count;
    return $prt;
}

#------------------------------------------------------------------------------
# Read variable-length integer
# Inputs: 0) RAF ref
# Returns: integer value
sub ReadVarInt($)
{
    my $raf = shift;
    my $buff;
    $raf->Read($buff, 1) or return 0;
    my $val = ord($buff);
    if ($val == 0xff) {
        $raf->Read($buff, 2) == 2 or return 0;
        $val = unpack('v', $buff);
        if ($val & 0x8000) {
            $raf->Read($buff, 2) == 2 or return 0;
            $val = (($val & 0x7fff) << 16) | unpack('v', $buff);
        }
    }
    return $val;
}

#------------------------------------------------------------------------------
# Read WPG version 1 or 2 image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid WPG file
sub ProcessWPG($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $lastType, $count);

    # verify this is a valid WPG file
    return 0 unless $raf->Read($buff, 16) == 16;
    return 0 unless $buff =~ /^\xff\x57\x50\x43/;
    $et->SetFileType();
    SetByteOrder('II');
    my $tagTablePtr = GetTagTable('Image::ExifTool::WPG::Main');
    my $offset = Get32u(\$buff, 4);
    my ($ver, $rev) = unpack('x10CC', $buff);
    $et->HandleTag($tagTablePtr, WPGVersion => "$ver.$rev");
    if ($ver < 1 or $ver > 2) {
        # currently support only version 1 and 2 formats
        $et->Warn('Unsupported WPG version');
        return 1;
    }
    my $tag = $ver == 1 ? 'Records' : 'RecordsV2';
    $raf->Seek($offset - 16, 1) or return 1 if $offset > 16;
    # loop through records
    for (;;) {
        my ($type, $len, $getSize);
        if ($raf->Read($buff, $ver) == $ver) {  # read 1 or 2 bytes, based on version
            if ($ver == 1) {
                # read version 1 record header
                $type = ord($buff);
                $len = ReadVarInt($raf);
                $getSize = 1 if $type == 0x0f;  # Start WPG (Type 1)
            } else {
                # read version 2 record header
                $type = unpack('xC', $buff);
                ReadVarInt($raf);   # skip extensions
                $len = ReadVarInt($raf);
                $getSize = 1 if $type == 0x01;  # Start WPG
                undef $type if $type > 0x3f;
            }
            if ($getSize) {
                # read Start record to obtain image size
                $raf->Read($buff, $len) == $len or $et->Warn('File format error'), last;
                my ($w, $h, $xres, $yres);
                if ($ver == 1) {
                    ($w, $h) = unpack('x2vv', $buff);
                } else {
                    my ($precision, $format);
                    ($xres, $yres, $precision) = unpack('vvC', $buff);
                    if ($precision == 0 and $len >= 21) {
                        $format = 'int16s';
                    } elsif ($precision == 1 and $len >= 29) {
                        $format = 'int32s';
                    } else {
                        $et->Warn('Invalid integer precision');
                        next;
                    }
                    my ($x1,$y1,$x2,$y2) = ReadValue(\$buff, 13, $format, 4, $len-13);
                    $w = abs($x2 - $x1);
                    $h = abs($y2 - $y1);
                }
                $et->HandleTag($tagTablePtr, ImageWidthInches  => $w / ($xres || 1200));
                $et->HandleTag($tagTablePtr, ImageHeightInches => $h / ($yres || 1200));
            } else {
                $raf->Seek($len, 1) or last; # skip to the next record
            }
        }
        # go to some trouble to collapse identical sequential entries in record list
        # (trying to keep the length of the list managable for complex images)
        $lastType and $type and $type == $lastType and ++$count, next;
        if ($lastType) {
            my $val = $count > 1 ? "${lastType}x$count" : $lastType;
            $et->HandleTag($tagTablePtr, $tag => $val);
        }
        last unless $type;
        $lastType = $type;
        $count = 1;
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::WPG - Read WPG meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read WPG
(WordPerfect Graphics) images.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://www.fileformat.info/format/wpg/egff.htm>

=item L<https://archive.org/details/mac_Graphics_File_Formats_Second_Edition_1996/page/n991/mode/2up>

=item L<http://libwpg.sourceforge.net/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/WPG Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
