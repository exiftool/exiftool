#------------------------------------------------------------------------------
# File:         MinoltaRaw.pm
#
# Description:  Read/write Konica-Minolta RAW (MRW) meta information
#
# Revisions:    03/11/2006 - P. Harvey Split out from Minolta.pm
#
# References:   1) http://www.cybercom.net/~dcoffin/dcraw/
#               2) http://www.chauveau-central.net/mrw-format/
#               3) Igal Milchtaich private communication (A100)
#------------------------------------------------------------------------------

package Image::ExifTool::MinoltaRaw;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Minolta;

$VERSION = '1.15';

sub ProcessMRW($$;$);
sub WriteMRW($$;$);

# Minolta MRW tags
%Image::ExifTool::MinoltaRaw::Main = (
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    PROCESS_PROC => \&Image::ExifTool::MinoltaRaw::ProcessMRW,
    WRITE_PROC => \&Image::ExifTool::MinoltaRaw::WriteMRW,
    NOTES => 'These tags are used in Minolta RAW format (MRW) images.',
    "\0TTW" => { # TIFF Tags
        Name => 'MinoltaTTW',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            # this EXIF information starts with a TIFF header
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            WriteProc => \&Image::ExifTool::WriteTIFF,
        },
    },
    "\0PRD" => { # Raw Picture Dimensions
        Name => 'MinoltaPRD',
        SubDirectory => { TagTable => 'Image::ExifTool::MinoltaRaw::PRD' },
    },
    "\0WBG" => { # White Balance Gains
        Name => 'MinoltaWBG',
        SubDirectory => { TagTable => 'Image::ExifTool::MinoltaRaw::WBG' },
    },
    "\0RIF" => { # Requested Image Format
        Name => 'MinoltaRIF',
        SubDirectory => { TagTable => 'Image::ExifTool::MinoltaRaw::RIF' },
    },
    # "\0CSA" is padding
);

# Minolta MRW PRD information (ref 2)
%Image::ExifTool::MinoltaRaw::PRD = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    0 => {
        Name => 'FirmwareID',
        Format => 'string[8]',
    },
    8 => {
        Name => 'SensorHeight',
        Format => 'int16u',
    },
    10 => {
        Name => 'SensorWidth',
        Format => 'int16u',
    },
    12 => {
        Name => 'ImageHeight',
        Format => 'int16u',
    },
    14 => {
        Name => 'ImageWidth',
        Format => 'int16u',
    },
    16 => {
        Name => 'RawDepth',
        Format => 'int8u',
    },
    17 => {
        Name => 'BitDepth',
        Format => 'int8u',
    },
    18 => {
        Name => 'StorageMethod',
        Format => 'int8u',
        PrintConv => {
            82 => 'Padded',
            89 => 'Linear',
        },
    },
    23 => {
        Name => 'BayerPattern',
        Format => 'int8u',
        PrintConv => {
            # 0 - seen in some Sony A850 ARW images
            1 => 'RGGB',
            4 => 'GBRG',
        },
    },
);

# Minolta MRW WBG information (ref 2)
%Image::ExifTool::MinoltaRaw::WBG = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    FIRST_ENTRY => 0,
    0 => {
        Name => 'WBScale',
        Format => 'int8u[4]',
    },
    4 => [
        {
            Condition => '$$self{Model} =~ /DiMAGE A200\b/',
            Name => 'WB_GBRGLevels',
            Format => 'int16u[4]',
            Notes => 'DiMAGE A200',
        },
        {
            Name => 'WB_RGGBLevels',
            Format => 'int16u[4]',
            Notes => 'other models',
        },
    ],
);

# Minolta MRW RIF information (ref 2)
%Image::ExifTool::MinoltaRaw::RIF = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    WRITE_PROC => \&Image::ExifTool::WriteBinaryData,
    CHECK_PROC => \&Image::ExifTool::CheckBinaryData,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    FIRST_ENTRY => 0,
    1 => {
        Name => 'Saturation',
        Format => 'int8s',
    },
    2 => {
        Name => 'Contrast',
        Format => 'int8s',
    },
    3 => {
        Name => 'Sharpness',
        Format => 'int8s',
    },
    4 => {
        Name => 'WBMode',
        PrintConv => 'Image::ExifTool::MinoltaRaw::ConvertWBMode($val)',
    },
    5 => {
        Name => 'ProgramMode',
        PrintConv => {
            0 => 'None',
            1 => 'Portrait',
            2 => 'Text',
            3 => 'Night Portrait',
            4 => 'Sunset',
            5 => 'Sports',
            # have seen these values in Sony ARW images: - PH
            # 7, 128, 129, 160
        },
    },
    6 => {
        Name => 'ISOSetting',
        RawConv => '$val == 255 ? undef : $val',
        PrintConv => { #3
            0 => 'Auto',
            48 => 100,
            56 => 200,
            64 => 400,
            72 => 800,
            80 => 1600,
            174 => '80 (Zone Matching Low)',
            184 => '200 (Zone Matching High)',
            OTHER => sub {
                my ($val, $inv) = @_;
                return int(2 ** (($val-48)/8) * 100 + 0.5) unless $inv;
                # (must check for zero below in inverse conversion)
                return 48 + 8*log($val/100)/log(2) if Image::ExifTool::IsFloat($val) and $val != 0;
                return undef;
            },
        },
        #ValueConv => '2 ** (($val-48)/8) * 100',
        #ValueConvInv => '48 + 8*log($val/100)/log(2)',
        #PrintConv => 'int($val + 0.5)',
        #PrintConvInv => '$val',
    },
    7 => [
        {
            Name => 'ColorMode',
            Condition => '$$self{Make} !~ /^SONY/',
            Priority => 0,
            Writable => 'int32u',
            PrintConv => \%Image::ExifTool::Minolta::minoltaColorMode,
        },
        { #3
            Name => 'ColorMode',
            Condition => '$$self{Model} eq "DSLR-A100"',
            Writable => 'int32u',
            Notes => 'Sony A100',
            Priority => 0,
            PrintHex => 1,
            PrintConv => \%Image::ExifTool::Minolta::sonyColorMode,
        },
    ],
    # NOTE: some of these WB_RBLevels may apply to other models too...
    8  => { #3
        Name => 'WB_RBLevelsTungsten',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Format => 'int16u[2]',
        Notes => 'these WB_RBLevels currently decoded only for the Sony A100',
    },
    12 => { #3
        Name => 'WB_RBLevelsDaylight',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Format => 'int16u[2]',
    },
    16 => { #3
        Name => 'WB_RBLevelsCloudy',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Format => 'int16u[2]',
    },
    20 => { #3
        Name => 'WB_RBLevelsCoolWhiteF',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Format => 'int16u[2]',
    },
    24 => { #3
        Name => 'WB_RBLevelsFlash',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Format => 'int16u[2]',
    },
    28 => { #3
        Name => 'WB_RBLevelsUnknown',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Format => 'int16u[2]',
        Unknown => 1,
    },
    32 => { #3
        Name => 'WB_RBLevelsShade',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Format => 'int16u[2]',
    },
    36 => { #3
        Name => 'WB_RBLevelsDaylightF',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Format => 'int16u[2]',
    },
    40 => { #3
        Name => 'WB_RBLevelsDayWhiteF',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Format => 'int16u[2]',
    },
    44 => { #3
        Name => 'WB_RBLevelsWhiteF',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Format => 'int16u[2]',
    },
    56 => {
        Name => 'ColorFilter',
        Condition => '$$self{Make} !~ /^SONY/',
        Format => 'int8s',
        Notes => 'Minolta models',
    },
    57 => 'BWFilter',
    58 => {
        Name => 'ZoneMatching',
        Condition => '$$self{Make} !~ /^SONY/',
        Priority => 0,
        Notes => 'Minolta models',
        PrintConv => {
            0 => 'ISO Setting Used',
            1 => 'High Key',
            2 => 'Low Key',
        },
    },
    59 => {
        Name => 'Hue',
        Format => 'int8s',
    },
    60 => {
        Name => 'ColorTemperature',
        Condition => '$$self{Make} !~ /^SONY/',
        Notes => 'Minolta models',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
    },
    74 => { #3
        Name => 'ZoneMatching',
        Condition => '$$self{Make} =~ /^SONY/',
        Priority => 0,
        Notes => 'Sony models',
        PrintConv => {
            0 => 'ISO Setting Used',
            1 => 'High Key',
            2 => 'Low Key',
        },
    },
    76 => { #3
        Name => 'ColorTemperature',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Notes => 'A100',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
        PrintConv => '$val ? $val : "Auto"',
        PrintConvInv => '$val=~/Auto/i ? 0 : $val',
    },
    77 => { #3
        Name => 'ColorFilter',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Notes => 'A100',
    },
    78 => { #3
        Name => 'ColorTemperature',
        Condition => '$$self{Model} =~ /^DSLR-A(200|700)$/',
        Notes => 'A200 and A700',
        ValueConv => '$val * 100',
        ValueConvInv => '$val / 100',
        PrintConv => '$val ? $val : "Auto"',
        PrintConvInv => '$val=~/Auto/i ? 0 : $val',
    },
    79 => { #3
        Name => 'ColorFilter',
        Condition => '$$self{Model} =~ /^DSLR-A(200|700)$/',
        Notes => 'A200 and A700',
    },
    80 => { #3
        Name => 'RawDataLength',
        Condition => '$$self{Model} eq "DSLR-A100"',
        Format => 'int32u',
        Notes => 'A100',
        Writable => 0,
    },
);

#------------------------------------------------------------------------------
# PrintConv for WBMode
sub ConvertWBMode($)
{
    my $val = shift;
    my %mrwWB = (
        0 => 'Auto',
        1 => 'Daylight',
        2 => 'Cloudy',
        3 => 'Tungsten',
        4 => 'Flash/Fluorescent',
        5 => 'Fluorescent',
        6 => 'Shade',
        7 => 'User 1',
        8 => 'User 2',
        9 => 'User 3',
        10 => 'Temperature',
    );
    my $lo = $val & 0x0f;
    my $wbstr = $mrwWB{$lo} || "Unknown ($lo)";
    my $hi = $val >> 4;
    $wbstr .= ' (' . ($hi - 8) . ')' if $hi >= 6 and $hi <=12;
    return $wbstr;
}

#------------------------------------------------------------------------------
# Write MRW directory (eg. in ARW images)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) optional tag table ref
# Returns: new MRW data or undef on error
sub WriteMRW($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;      # allow dummy access
    my $buff = '';
    $$dirInfo{OutFile} = \$buff;
    ProcessMRW($et, $dirInfo, $tagTablePtr) > 0 or undef $buff;
    return $buff;
}

#------------------------------------------------------------------------------
# Read or write Minolta MRW file
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) optional tag table ref
# Returns: 1 on success, 0 if this wasn't a valid MRW file, or -1 on write error
# Notes: File pointer must be set to start of MRW in RAF upon entry
sub ProcessMRW($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $raf = $$dirInfo{RAF};
    my $outfile = $$dirInfo{OutFile};
    my $verbose = $et->Options('Verbose');
    my $out = $et->Options('TextOut');
    my ($data, $err, $outBuff);

    if ($$dirInfo{DataPt}) {
        # make a RAF object for MRW information extracted from other file types
        $raf = new File::RandomAccess($$dirInfo{DataPt});
        # MRW information in DNG images may not start at beginning of data block
        $raf->Seek($$dirInfo{DirStart}, 0) if $$dirInfo{DirStart};
    }
    $raf->Read($data,8) == 8 or return 0;
    # "\0MRM" for big-endian (MRW images), and
    # "\0MRI" for little-endian (MRWInfo in ARW images)
    $data =~ /^\0MR([MI])/ or return 0;
    my $hdr = "\0MR$1";
    SetByteOrder($1 . $1);
    $et->SetFileType();
    $tagTablePtr = GetTagTable('Image::ExifTool::MinoltaRaw::Main');
    if ($outfile) {
        $et->InitWriteDirs('TIFF'); # use same write dirs as TIFF
        $outBuff = '';
    }
    my $pos = $raf->Tell();
    my $offset = Get32u(\$data, 4) + $pos;
    my $rtnVal = 1;
    $verbose and printf $out "  [MRW Data Offset: 0x%x]\n", $offset;
    # loop through MRW segments (ref 1)
    while ($pos < $offset) {
        $raf->Read($data,8) == 8 or $err = 1, last;
        $pos += 8;
        my $tag = substr($data, 0, 4);
        my $len = Get32u(\$data, 4);
        if ($verbose) {
            print $out "MRW ",$et->Printable($tag)," segment ($len bytes):\n";
            if ($verbose > 2) {
                $raf->Read($data,$len) == $len and $raf->Seek($pos,0) or $err = 1, last;
                $et->VerboseDump(\$data);
            }
        }
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if ($tagInfo and $$tagInfo{SubDirectory}) {
            my $subTable = GetTagTable($tagInfo->{SubDirectory}->{TagTable});
            my $buff;
            # save shift for values stored with wrong base offset
            $$et{MRW_WrongBase} = -($raf->Tell());
            $raf->Read($buff, $len) == $len or $err = 1, last;
            my %subdirInfo = (
                DataPt => \$buff,
                DataLen => $len,
                DataPos => $pos,
                DirStart => 0,
                DirLen => $len,
                DirName => $$tagInfo{Name},
                Parent => 'MRW',
                NoTiffEnd => 1, # no end-of-TIFF check
            );
            if ($outfile) {
                my $writeProc = $tagInfo->{SubDirectory}->{WriteProc};
                my $val = $et->WriteDirectory(\%subdirInfo, $subTable, $writeProc);
                if (defined $val and length $val) {
                    # pad to an even 4 bytes (can't hurt, and it seems to be the standard)
                    $val .= "\0" x (4 - (length($val) & 0x03)) if length($val) & 0x03;
                    $outBuff .= $tag . Set32u(length $val) . $val;
                } elsif (not defined $val) {
                    $outBuff .= $data . $buff;  # copy over original information
                }
            } else {
                my $processProc = $tagInfo->{SubDirectory}->{ProcessProc};
                $et->ProcessDirectory(\%subdirInfo, $subTable, $processProc);
            }
        } elsif ($outfile) {
            # add this segment to the output buffer
            my $buff;
            $raf->Read($buff, $len) == $len or $err = 1, last;
            $outBuff .= $data . $buff;
        } else {
            # skip this segment
            $raf->Seek($pos+$len, 0) or $err = 1, last;
        }
        $pos += $len;
    }
    $pos == $offset or $err = 1;    # meta information length check

    if ($outfile) {
        # write the file header then the buffered meta information
        Write($outfile, $hdr, Set32u(length $outBuff), $outBuff) or $rtnVal = -1;
        # copy over image data
        while ($raf->Read($outBuff, 65536)) {
            Write($outfile, $outBuff) or $rtnVal = -1;
        }
        # Sony IDC utility corrupts MRWInfo when writing ARW images,
        # so make this a minor error for these images
        $err and $et->Error("MRW format error", $$et{TIFF_TYPE} eq 'ARW');
    } else {
        $err and $et->Warn("MRW format error");
    }
    return $rtnVal;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MinoltaRaw - Read/write Konica-Minolta RAW (MRW) information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read and
write Konica-Minolta RAW (MRW) images.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.cybercom.net/~dcoffin/dcraw/>

=item L<http://www.chauveau-central.net/mrw-format/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MinoltaRaw Tags>,
L<Image::ExifTool::Minolta(3pm)|Image::ExifTool::Minolta>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
