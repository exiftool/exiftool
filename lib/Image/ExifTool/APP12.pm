#------------------------------------------------------------------------------
# File:         APP12.pm
#
# Description:  Read APP12 meta information
#
# Revisions:    10/18/2005 - P. Harvey Created
#
# References:   1) Heinrich Giesen private communication
#------------------------------------------------------------------------------

package Image::ExifTool::APP12;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.13';

sub ProcessAPP12($$$);
sub ProcessDucky($$$);
sub WriteDucky($$$);

# APP12 tags (ref PH)
%Image::ExifTool::APP12::PictureInfo = (
    PROCESS_PROC => \&ProcessAPP12,
    GROUPS => { 0 => 'APP12', 1 => 'PictureInfo', 2 => 'Image' },
    PRIORITY => 0,
    NOTES => q{
        The JPEG APP12 "Picture Info" segment was used by some older cameras, and
        contains ASCII-based meta information.  Below are some tags which have been
        observed Agfa and Polaroid images, however ExifTool will extract information
        from any tags found in this segment.
    },
    FNumber => {
        ValueConv => '$val=~s/^[A-Za-z ]*//;$val',  # Agfa leads with an 'F'
        PrintConv => 'sprintf("%.1f",$val)',
    },
    Aperture => {
        PrintConv => 'sprintf("%.1f",$val)',
    },
    TimeDate => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        ValueConv => '$val=~/^\d+$/ ? ConvertUnixTime($val) : $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Shutter => {
        Name => 'ExposureTime',
        ValueConv => '$val * 1e-6',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
    shtr => {
        Name => 'ExposureTime',
        ValueConv => '$val * 1e-6',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
    },
   'Serial#'    => {
        Name => 'SerialNumber',
        Groups => { 2 => 'Camera' },
    },
    Flash       => { PrintConv => { 0 => 'Off', 1 => 'On' } },
    Macro       => { PrintConv => { 0 => 'Off', 1 => 'On' } },
    StrobeTime  => { },
    Ytarget     => { Name => 'YTarget' },
    ylevel      => { Name => 'YLevel' },
    FocusPos    => { },
    FocusMode   => { },
    Quality     => { },
    ExpBias     => 'ExposureCompensation',
    FWare       => 'FirmwareVersion',
    StrobeTime  => { },
    Resolution  => { },
    Protect     => { },
    ConTake     => { },
    ImageSize   => { PrintConv => '$val=~tr/-/x/;$val' },
    ColorMode   => { },
    Zoom        => { },
    ZoomPos     => { },
    LightS      => { },
    Type        => {
        Name => 'CameraType',
        Groups => { 2 => 'Camera' },
        DataMember => 'CameraType',
        RawConv => '$self->{CameraType} = $val',
    },
    Version     => { Groups => { 2 => 'Camera' } },
    ID          => { Groups => { 2 => 'Camera' } },
);

# APP12 segment written in Photoshop "Save For Web" images
# (from tests with Photoshop 7 files - PH/1)
%Image::ExifTool::APP12::Ducky = (
    PROCESS_PROC => \&ProcessDucky,
    WRITE_PROC => \&WriteDucky,
    GROUPS => { 0 => 'Ducky', 1 => 'Ducky', 2 => 'Image' },
    WRITABLE => 'string',
    NOTES => q{
        Photoshop uses the JPEG APP12 "Ducky" segment to store some information in
        "Save for Web" images.
    },
    1 => { #PH
        Name => 'Quality',
        Priority => 0,
        Avoid => 1,
        Writable => 'int32u',
        ValueConv => 'unpack("N",$val)',    # 4-byte integer
        ValueConvInv => 'pack("N",$val)',
        PrintConv => '"$val%"',
        PrintConvInv => '$val=~/(\d+)/ ? $1 : undef',
    },
    2 => { #1
        Name => 'Comment',
        Priority => 0,
        Avoid => 1,
        # (ignore 4-byte character count at start of value)
        ValueConv => '$self->Decode(substr($val,4),"UCS2","MM")',
        ValueConvInv => 'pack("N",length $val) . $self->Encode($val,"UCS2","MM")',
    },
    3 => { #PH
        Name => 'Copyright',
        Priority => 0,
        Avoid => 1,
        Groups => { 2 => 'Author' },
        # (ignore 4-byte character count at start of value)
        ValueConv => '$self->Decode(substr($val,4),"UCS2","MM")',
        ValueConvInv => 'pack("N",length $val) . $self->Encode($val,"UCS2","MM")',
    },
);

#------------------------------------------------------------------------------
# Write APP12 Ducky segment
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: New directory data or undefined on error
sub WriteDucky($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access to autoload this package
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart};
    my $newTags = $et->GetNewTagInfoHash($tagTablePtr);
    my @addTags = sort { $a <=> $b } keys(%$newTags);
    my ($dirEnd, %doneTags);
    if ($dataPt) {
        $dirEnd = $pos + $$dirInfo{DirLen};
    } else {
        my $tmp = '';
        $dataPt = \$tmp;
        $pos = $dirEnd = 0;
    }
    my $newData = '';
    SetByteOrder('MM');
    # process all data blocks in Ducky segment
    for (;;) {
        my ($tag, $len, $val);
        if ($pos + 4 <= $dirEnd) {
            $tag = Get16u($dataPt, $pos);
            $len = Get16u($dataPt, $pos + 2);
            $pos += 4;
            if ($pos + $len > $dirEnd) {
                $et->Warn('Invalid Ducky block length');
                return undef;
            }
            $val = substr($$dataPt, $pos, $len);
            $pos += $len;
        } else {
            last unless @addTags;
            $tag = pop @addTags;
            next if $doneTags{$tag};
        }
        $doneTags{$tag} = 1;
        my $tagInfo = $$newTags{$tag};
        if ($tagInfo) {
            my $nvHash = $et->GetNewValueHash($tagInfo);
            my $isNew;
            if (defined $val) {
                if ($et->IsOverwriting($nvHash, $val)) {
                    $et->VerboseValue("- Ducky:$$tagInfo{Name}", $val);
                    $isNew = 1;
                }
            } else {
                next unless $$nvHash{IsCreating};
                $isNew = 1;
            }
            if ($isNew) {
                $val = $et->GetNewValue($nvHash);
                ++$$et{CHANGED};
                next unless defined $val;   # next if tag is being deleted
                $et->VerboseValue("+ Ducky:$$tagInfo{Name}", $val);
            }
        }
        $newData .= pack('nn', $tag, length $val) . $val;
    }
    $newData .= "\0\0" if length $newData;
    return $newData;
}

#------------------------------------------------------------------------------
# Process APP12 Ducky segment (ref PH)
# Inputs: 0) ExifTool object reference, 1) Directory information ref, 2) tag table ref
# Returns: 1 on success, 0 if this wasn't a recognized Ducky segment
# Notes: This segment has the following format:
#   1) 5 bytes: "Ducky"
#   2) multiple data blocks (all integers are big endian):
#      a) 2 bytes: block type (0=end, 1=Quality, 2=Comment, 3=Copyright)
#      b) 2 bytes: block length (N)
#      c) N bytes: block data
sub ProcessDucky($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $pos = $$dirInfo{DirStart};
    my $dirEnd = $pos + $$dirInfo{DirLen};
    SetByteOrder('MM');
    # process all data blocks in Ducky segment
    for (;;) {
        last if $pos + 4 > $dirEnd;
        my $tag = Get16u($dataPt, $pos);
        my $len = Get16u($dataPt, $pos + 2);
        $pos += 4;
        if ($pos + $len > $dirEnd) {
            $et->Warn('Invalid Ducky block length');
            last;
        }
        my $val = substr($$dataPt, $pos, $len);
        $et->HandleTag($tagTablePtr, $tag, $val,
            DataPt => $dataPt,
            DataPos => $$dirInfo{DataPos},
            Start => $pos,
            Size => $len,
        );
        $pos += $len;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Process APP12 Picture Info segment (ref PH)
# Inputs: 0) ExifTool object reference, 1) Directory information ref, 2) tag table ref
# Returns: 1 on success, 0 if this wasn't a recognized APP12
sub ProcessAPP12($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || (length($$dataPt) - $dirStart);
    if ($dirLen != $dirStart + length($$dataPt)) {
        my $buff = substr($$dataPt, $dirStart, $dirLen);
        $dataPt = \$buff;
    } else {
        pos($$dataPt) = $$dirInfo{DirStart};
    }
    my $verbose = $et->Options('Verbose');
    my $success = 0;
    my $section = '';
    pos($$dataPt) = 0;

    # this regular expression is a bit complex, but basically we are looking for
    # section headers (eg. "[Camera Info]") and tag/value pairs (eg. "tag=value",
    # where "value" may contain white space), separated by spaces or CR/LF.
    # (APP12 uses CR/LF, but Olympus TextualInfo is similar and uses spaces)
    while ($$dataPt =~ /(\[.*?\]|[\w#-]+=[\x20-\x7e]+?(?=\s*([\n\r\0]|[\w#-]+=|\[|$)))/g) {
        my $token = $1;
        # was this a section name?
        if ($token =~ /^\[(.*)\]/) {
            $et->VerboseDir($1) if $verbose;
            $section = ($token =~ /\[(\S+) ?Info\]/i) ? $1 : '';
            $success = 1;
            next;
        }
        $et->VerboseDir($$dirInfo{DirName}) if $verbose and not $success;
        $success = 1;
        my ($tag, $val) = ($token =~ /(\S+)=(.+)/);
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        $verbose and $et->VerboseInfo($tag, $tagInfo, Value => $val);
        unless ($tagInfo) {
            # add new tag to table
            $tagInfo = { Name => ucfirst $tag };
            # put in Camera group if information in "Camera" section
            $$tagInfo{Groups} = { 2 => 'Camera' } if $section =~ /camera/i;
            AddTagToTable($tagTablePtr, $tag, $tagInfo);
        }
        $et->FoundTag($tagInfo, $val);
    }
    return $success;
}


1;  #end

__END__

=head1 NAME

Image::ExifTool::APP12 - Read APP12 meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
APP12 meta information.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 ACKNOWLEDGEMENTS

Thanks to Heinrich Giesen for his help decoding APP12 "Ducky" information.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/APP12 Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
