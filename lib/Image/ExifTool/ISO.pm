#------------------------------------------------------------------------------
# File:         ISO.pm
#
# Description:  Read information from ISO 9660 disk images
#
# Revisions:    2016-04-07 - P. Harvey created
#
# References:   1) http://wiki.osdev.org/ISO_9660
#------------------------------------------------------------------------------

package Image::ExifTool::ISO;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.01';

# trim trailing spaces and ignore tag if empty
my %rawStr = (
    RawConv => sub {
        my $val = shift;
        $val =~ s/ +$//;
        return length($val) ? $val : undef;
    },
);

# tag info for date/time tags
my %dateInfo = (
    Format => 'undef[17]',
    Groups => { 2 => 'Time' },
    ValueConv => q{
        return undef if $val !~ /[^0\0 ]/; # ignore if empty
        if ($val =~ s/(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(.)/$1:$2:$3 $4:$5:$6.$7/s) {
            $val .= TimeZoneString(unpack('c', $8) * 15);
        }
        return $val;
    },
    PrintConv => '$self->ConvertDateTime($val)',
);

# lookup for volume descriptor types
my %volumeDescriptorType = (
    0 => 'Boot Record',
    1 => 'Primary Volume',
    2 => 'Supplementary Volume',
    3 => 'Volume Partition',
    255 => 'Terminator',
);

# ISO tags
%Image::ExifTool::ISO::Main = (
    GROUPS => { 2 => 'Other' },
    NOTES => 'Tags extracted from ISO 9660 disk images.',
    0 => {
        Name => 'BootRecord',
        SubDirectory => { TagTable => 'Image::ExifTool::ISO::BootRecord' },
    },
    1 => {
        Name => 'PrimaryVolume',
        SubDirectory => { TagTable => 'Image::ExifTool::ISO::PrimaryVolume' },
    },
);

%Image::ExifTool::ISO::BootRecord = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    # 0 => { Name => 'VolumeType', PrintConv => \%volumeDescriptorType }, # (0 for boot record)
    # 1 => { Name => 'Identifier',      Format => 'undef[5]' }, # (always "CD001")
    # 6 => 'VolumeDesriptorVersion', # (always 1)
    # always extract BootSystem, even if empty, as an indication that this is bootable
      7 => { Name => 'BootSystem',      Format => 'string[32]', ValueConv => '$val=~s/ +$//; $val' },
    39  => { Name => 'BootIdentifier',  Format => 'string[32]', %rawStr },
);

%Image::ExifTool::ISO::PrimaryVolume = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    # 0 => { Name => 'VolumeType', PrintConv => \%volumeDescriptorType }, # (1 for primary volume)
    # 1 => { Name => 'Identifier',          Format => 'undef[5]' }, # (always "CD001")
    # 6 => 'VolumeDesriptorVersion', # (always 1)
      8 => { Name => 'System',              Format => 'string[32]', %rawStr },
     40 => { Name => 'VolumeName',          Format => 'string[32]', %rawStr },
     80 => { Name => 'VolumeBlockCount',    Format => 'int32u' },
    120 => { Name => 'VolumeSetDiskCount',  Format => 'int16u', Unknown => 1 },
    124 => { Name => 'VolumeSetDiskNumber', Format => 'int16u', Unknown => 1 },
    128 => { Name => 'VolumeBlockSize',     Format => 'int16u' },
    132 => { Name => 'PathTableSize',       Format => 'int32u', Unknown => 1 },
    140 => { Name => 'PathTableLocation',   Format => 'int32u', Unknown => 1 },
    174 => {
        Name => 'RootDirectoryCreateDate',
        Format => 'undef[7]',
        Groups => { 2 => 'Time' },
        ValueConv => q{
            my @a = unpack('C6c', $val);
            $a[0] += 1900;
            $a[6] = TimeZoneString($a[6] * 15);
            return sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d%s', @a);
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    190 => { Name => 'VolumeSetName',       Format => 'string[128]', %rawStr },
    318 => { Name => 'Publisher',           Format => 'string[128]', %rawStr },
    446 => { Name => 'DataPreparer',        Format => 'string[128]', %rawStr },
    574 => { Name => 'Software',            Format => 'string[128]', %rawStr },
    702 => { Name => 'CopyrightFileName',   Format => 'string[38]', %rawStr },
    740 => { Name => 'AbstractFileName',    Format => 'string[36]', %rawStr },
    776 => { Name => 'BibligraphicFileName',Format => 'string[37]', %rawStr },
    813 => { Name => 'VolumeCreateDate',    %dateInfo },
    830 => { Name => 'VolumeModifyDate',    %dateInfo },
    847 => { Name => 'VolumeExpirationDate',%dateInfo },
    864 => { Name => 'VolumeEffectiveDate', %dateInfo },
   #881 => 'FileStructureVersion', # (always 1)
);

# ISO Composite tags
%Image::ExifTool::ISO::Composite = (
    GROUPS => { 2 => 'Other' },
    VolumeSize => {
        Require => {
            0 => 'ISO:VolumeBlockCount',
            1 => 'ISO:VolumeBlockSize',
        },
        ValueConv => '$val[0] * $val[1]',
        PrintConv => \&Image::ExifTool::ConvertFileSize,
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::ISO');

#------------------------------------------------------------------------------
# Extract information from an ISO 9660 disk image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid ISO 9660 image
sub ProcessISO($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $tagTablePtr);

    # verify this is a valid ISO file
    return 0 unless $raf->Seek(32768, 0);

    while ($raf->Read($buff, 2048) == 2048) {
        last unless $buff =~ /^[\0-\x03\xff]CD001/;
        unless ($tagTablePtr) {
            $et->SetFileType(); # set the FileType tag
            SetByteOrder('II'); # read little-endian values only
            $tagTablePtr = GetTagTable('Image::ExifTool::ISO::Main');
        }
        my $type = unpack('C', $buff);
        $et->VPrint(0, "Volume descriptor type $type ($volumeDescriptorType{$type})\n");
        last if $type == 255;   # stop at terminator
        next unless $$tagTablePtr{$type};
        my $subTablePtr = GetTagTable($$tagTablePtr{$type}{SubDirectory}{TagTable});
        my %dirInfo = (
            DataPt   => \$buff,
            DataPos  => $raf->Tell() - 2048,
            DirStart => 0,
            DirLen   => length($buff),
        );
        $et->ProcessDirectory(\%dirInfo, $subTablePtr);
    }
    return $tagTablePtr ? 1 : 0;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::ISO - Read information from ISO 9660 disk images

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read
information from ISO 9660 disk images.

=head1 AUTHOR

Copyright 2003-2020, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://wiki.osdev.org/ISO_9660>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/ISO Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

