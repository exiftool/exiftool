#------------------------------------------------------------------------------
# File:         Mini.pm
#
# Description:  Read/write mif3 low-overhead SlimHEIF 'mini' information
#
# Revisions:    2026-11-06 - P. Harvey Created
#
# References:   1) https://github.com/MediaArea/MediaInfoLib
#------------------------------------------------------------------------------

package Image::ExifTool::Mini;

use strict;
use vars qw($VERSION $AUTOLOAD %stringEncoding %avType %dontInherit %eeBox);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

sub Process_mini($$$);
sub Write_mini($$$);

# SlimHEIF 'mini' tags
%Image::ExifTool::Mini::Main = (
    PROCESS_PROC => \&Process_mini,
    WRITE_PROC => \&Write_mini,
    WRITE_GROUP => 'Mini',
    NOTES => q{
        Tags extracted by default from a mif3 low-overhead SlimHEIF 'mini' box. More
        tags (flags, etc.) are extracted from the mini header when the Unknown
        option is used. The family 1 group name for these tags is "Mini".

        When writing, by default new EXIF and XMP blocks are not compressed unless
        compressed data already exists, but EXIF and XMP are compressed if the API
        Compress option is set to 1, or uncompressed if set to 0. Compress::Zlib
        is required to enable this feature.
    },
    GROUPS => { 0 => 'QuickTime', 1 => 'Mini', 2 => 'Image' },
    TAG_PREFIX => '',
    VARS => { ID_FMT => 'none' },
    width_minus1 => { Name => 'ImageWidth', ValueConv => '$val + 1' },
    height_minus1 => { Name => 'ImageHeight', ValueConv => '$val + 1' },
    orientation_minus1 => {
        Name => 'Orientation',
        Writable => 1,
        ValueConv => '$val + 1',
        ValueConvInv => '$val - 1',
        PrintConv => \%Image::ExifTool::Exif::orientation,
        SeparateTable => 'EXIF Orientation',
    },
    chroma_subsampling => {
        Name => 'ChromaSubampling',
        PrintConv => {
            0 => '4:0:0',
            1 => '4:2:0',
            2 => '4:2:2',
            3 => '4:4:4',
        },
    },
    icc => {
        Name => 'ICC_Profile',
        SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::Main' },
    },
    exif => {
        Name => 'EXIF',
        SubDirectory => {
            TagTable => 'Image::ExifTool::Exif::Main',
            ProcessProc => \&Image::ExifTool::ProcessTIFF,
            WriteProc => \&Image::ExifTool::WriteTIFF,
        },
    },
    xmp => {
        Name => 'XMP',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Main' },
    },
);

#------------------------------------------------------------------------------
# Get bits from current position in data block
# Inputs: 0) Bits object (Pos,DataPt,Vars,ExifTool), 1) number of bits to read,
#         2) tag id (undef to skip bits)
# Returns: true on success and stores as tag in $$bits{Vars} and as an ExifTool
#          tag if the ExifTool element set in %$bits
sub GetBits($$;$)
{
    my ($bits, $num, $id) = @_;
    my $end = int(($$bits{Pos} + $num - 1) / 8); # end byte
    if ($end >= length(${$$bits{DataPt}})) {
        $$bits{Error} = 1;
        return 0;
    }
    my $i = int($$bits{Pos} / 8);   # index to current byte in data block
    my $b = $$bits{Pos} - $i * 8;   # position of current bit (0=msb, 7=lsb)
    $$bits{Pos} += $num;
    my $byte = Get8u($$bits{DataPt}, $i);
    my $val = 0;
    for (;;) {
        my $n = $num;
        $n = 8 - $b if $n + $b > 8; # num bits available in this byte
        my $mask = 0xff >> $b;
        my $shft = 8 - $n - $b;
        $val = ($val << $n) | (($byte & $mask) >> $shft);
        $num -= $n;
        last unless $num;
        $byte = Get8u($$bits{DataPt}, ++$i);  # get next byte
        $b = 0;
    }
    if ($id) {
        $$bits{Vars}{$id} = $val;
        if ($$bits{ExifTool}) {
            $$bits{ExifTool}->HandleTag($$bits{Table}, $id, $val, MakeTagInfo => 2);
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Set bits at current position in data block
# Inputs: 0) Bits object (Pos,DataPt,Vars), 1) number of bits to set,
#         2) tag id (undef to zero bits)
# Returns: true on success and writes the bit stream to DataPt
sub SetBits($$;$)
{
    my ($bits, $num, $id) = @_;
    my $i = int($$bits{Pos} / 8);
    my $b = $$bits{Pos} - $i * 8;
    $$bits{Pos} += $num;
    my $dataPt = $$bits{DataPt};
    my $byte = $i < length($$dataPt) ? Get8u($dataPt, $i) : 0;
    my $val = $id ? $$bits{Vars}{$id} : 0;
    for (;;) {
        my $n = $num;
        $n = 8 - $b if $n + $b > 8;     # num bits to write in this byte
        $num -= $n;                     # num bits remaining to write
        my $mask = 0xff >> (8 - $n);    # mask for bits to use
        # add bits to current byte
        $byte |= (($val >> $num) & $mask) << (8 - $n - $b);
        if ($i < length($$dataPt)) {
            Set8u($byte, $dataPt, $i);
        } else {
            $$dataPt .= chr($byte);
        }
        last unless $num;
        ++$i;
        $byte = 0;
        $b = 0;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Inflate data block
# Inputs: 0) ExifTool ref, 1) block info ref (Name, DataPt, Start, Size)
# Returns: true on success and updates block info, otherwise sets Size to 0
sub Inflate($$)
{
    my ($et, $block) = @_;
    if (eval { require Compress::Zlib }) {
        my $inflate = Compress::Zlib::inflateInit();
        if ($inflate) {
            $et->VPrint(0, "$$et{INDENT}\[Inflating compressed $$block{Name}]\n");
            if ($$block{Start}) {
                my $dat = substr(${$$block{DataPt}}, $$block{Start}, $$block{Size});
                $$block{DataPt} = \$dat;
            }
            my ($buff, $stat) = $inflate->inflate(${$$block{DataPt}});
            if ($stat == Compress::Zlib::Z_STREAM_END()) {
                $$block{DataPt} = \$buff;
                $$block{Start} = 0;
                $$block{Size} = length $buff;
                return 1;
            }
        }
        $et->Warn("Error inflating $$block{Name}");
    } else {
        $et->Warn("Install Compress::Zlib to process compressed $$block{Name}");
    }
    return $$block{Size} = 0;
}

#------------------------------------------------------------------------------
# Deflate data block
# Inputs: 0) ExifTool ref, 1) block info ref (Name, DataPt)
# Returns: true on success and updates block DataPt
sub Deflate($$)
{
    my ($et, $block) = @_;
    if (eval { require Compress::Zlib }) {
        my $deflate = Compress::Zlib::deflateInit();
        if ($deflate) {
            $et->VPrint(0, "$$et{INDENT}\[Deflating $$block{Name} metadata]\n");
            my $buff = $deflate->deflate($$block{DataPt});
            if (defined $buff) {
                $buff .= $deflate->flush();
                $$block{DataPt} = \$buff;
                return 1;
            }
        }
        $et->Warn("Error deflating $$block{Name}");
    } else {
        $et->Warn("Install Compress::Zlib to write compressed $$block{Name}");
    }
    return 0;
}

#------------------------------------------------------------------------------
# Read SlimHEIC 'mini' box from mif3 file, or write 'mini' box header
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# The dirInfo inputs are:
#   DataPt      - input 'mini' data or output when writing
#   HeaderOnly  - process only the header (not metadata chunks)
#   Vars        - input header variables for writing
#   BitsProc    - set to \&SetBits when writing
# The dirInfo outputs are (returned only when HeaderOnly is set):
#   Vars        - bitstream header variable keyed by name
#   Offsets     - metadata chunk offsets (chunk 0 is the bitstream header)
#   Sizes       - metadata chunk sizes
sub Process_mini($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    my $dataPt = $$dirInfo{DataPt};
    $et->VerboseDir('Mini', undef, length($$dataPt)) unless $$dirInfo{HeaderOnly};
    # initialize "bits" object for reading bitstream
    my $vars = $$dirInfo{Vars} || { };
    my $bits = {
        DataPt => $dataPt,
        Pos    => 0,
        Table  => $tagTbl,
        Vars   => $vars,
    };
    unless ($$dirInfo{HeaderOnly}) {  
        # need documentation for the msf3 mini box
        $$et{FileType} eq 'MSF3' and $et->Warn("Can't yet read msf3 mini metadata"), return 1;
        $$bits{ExifTool} = $et;
    }
    my $proc = $$dirInfo{BitsProc} || \&GetBits;
    &$proc($bits, 2, 'mini_version');
    &$proc($bits, 1, 'explicit_codec_types_flag');
    &$proc($bits, 1, 'float_flag');
    &$proc($bits, 1, 'full_range_flag');
    &$proc($bits, 1, 'alpha_flag');
    &$proc($bits, 1, 'explicit_cicp_flag');
    &$proc($bits, 1, 'hdr_flag');
    &$proc($bits, 1, 'icc_flag');
    &$proc($bits, 1, 'exif_flag');
    &$proc($bits, 1, 'xmp_flag');
    &$proc($bits, 2, 'chroma_subsampling');
    &$proc($bits, 3, 'orientation_minus1');
    &$proc($bits, 1, 'large_dimensions_flag') or return 0;
    &$proc($bits, $$vars{large_dimensions_flag} ? 15 : 7, 'width_minus1');
    &$proc($bits, $$vars{large_dimensions_flag} ? 15 : 7, 'height_minus1');
    &$proc($bits, 1) if $$vars{chroma_subsampling} == 1 || $$vars{chroma_subsampling} == 2;
    &$proc($bits, 1) if $$vars{chroma_subsampling} == 1;
    if ($$vars{float_flag}) {
        &$proc($bits, 2, 'bit_depth_log2_minus4');
    } else {
        &$proc($bits, 1, 'high_bit_depth_flag');
        &$proc($bits, 3, 'bit_depth_minus_9') if $$vars{high_bit_depth_flag};
    }
    &$proc($bits, 1, 'alpha_is_premultiplied') if $$vars{alpha_flag};
    if ($$vars{explicit_cicp_flag}) {
        &$proc($bits, 8, 'colour_primaries');
        &$proc($bits, 8, 'transfer_characteristics');
        &$proc($bits, 8, 'matrix_coefficients') if $$vars{chroma_subsampling};
    }
    if ($$vars{explicit_codec_types_flag}) {
        &$proc($bits, 32, 'infe_type');
        &$proc($bits, 32, 'codec_config_type');
    }
    if ($$vars{hdr_flag}) {
        &$proc($bits, 1, 'gainmap_flag');
        if ($$vars{gainmap_flag}) {
            &$proc($bits, $$vars{large_dimensions_flag} ? 15 : 7, 'gainmap_width_minus1');
            &$proc($bits, $$vars{large_dimensions_flag} ? 15 : 7, 'gainmap_height_minus1');
            &$proc($bits, 8, 'gainmap_matrix_coefficients');
            &$proc($bits, 1, 'gainmap_full_range_flag');
            &$proc($bits, 2, 'gainmap_chroma_subsampling');
            &$proc($bits, 1) if $$vars{gainmap_chroma_subsampling} == 1 || $$vars{gainmap_chroma_subsampling} == 2;
            &$proc($bits, 1) if $$vars{gainmap_chroma_subsampling} == 1;
            &$proc($bits, 1, 'gainmap_float_flag');
            if ($$vars{gainmap_float_flag}) {
                &$proc($bits, 2, 'gainmap_bit_depth_log2_minus4');
            } else {
                &$proc($bits, 1, 'gainmap_high_bit_depth_flag');
                &$proc($bits, 3, 'gainmap_bit_depth_minus9') if $$vars{gainmap_high_bit_depth_flag};
            }
            &$proc($bits, 1, 'tmap_icc_flag');
            &$proc($bits, 1, 'tmap_explicit_cicp_flag');
            if ($$vars{tmap_explicit_cicp_flag}) {
                &$proc($bits, 8, 'tmap_colour_primaries');
                &$proc($bits, 8, 'tmap_transfer_characteristics');
                &$proc($bits, 8, 'tmap_matrix_coefficients');
                &$proc($bits, 1, 'tmap_full_range_flag');
            }
        }
    }
    if ($$vars{icc_flag} or $$vars{exif_flag} or $$vars{xmp_flag} or $$vars{gainmap_flag}) {
        &$proc($bits, 1, 'large_metadata_flag');
    } else {
        $$vars{large_metadata_flag} = 0;
    }
    &$proc($bits, 1, 'large_codec_config_flag');
    &$proc($bits, 1, 'large_item_data_flag');
    my $metadataSize = $$vars{large_metadata_flag} ? 20 : 10;
    my $codecConfigSize = $$vars{large_codec_config_flag} ? 12 : 3;
    my $itemDataSize = $$vars{large_item_data_flag} ? 28 : 15;
    &$proc($bits, $metadataSize, 'icc_data_size_minus1') if $$vars{icc_flag};
    &$proc($bits, $metadataSize, 'tmap_icc_data_size_minus1') if $$vars{tmap_icc_flag};
    if ($$vars{gainmap_flag}) {
        my $gainItemData;
        &$proc($bits, $metadataSize, 'gainmap_metadata_size');
        &$proc($bits, $itemDataSize, 'gainmap_item_data_size');
        if ($$vars{gainmap_item_data_size}) {
            &$proc($bits, $codecConfigSize, 'gainmap_item_codec_config_size');
        }
    }
    &$proc($bits, $codecConfigSize, 'main_item_codec_config_size');
    &$proc($bits, $itemDataSize, 'main_item_data_size_minus1') or return 0;
    if ($$vars{alpha_flag}) {
        &$proc($bits, $itemDataSize, 'alpha_item_data_size');
        if ($$vars{alpha_item_data_size}) {
            &$proc($bits, $codecConfigSize, 'alpha_item_codec_config_size');
        }
    }
    if ($$vars{exif_flag} or $$vars{xmp_flag}) {
        &$proc($bits, 1, 'exif_xmp_compressed_flag');
    } else {
        $$vars{exif_xmp_compressed_flag} = 0;
    }
    &$proc($bits, $metadataSize, 'exif_data_size_minus1') if $$vars{exif_flag};
    &$proc($bits, $metadataSize, 'xmp_data_size_minus1') if $$vars{xmp_flag};
    my @sizes = ( # chunk sizes
        int(($$bits{Pos} + 7) / 8),                      # 0) header chunk
        $$vars{main_item_codec_config_size},             # 1) main item codec config chunk
        $$vars{alpha_item_codec_config_size} || 0,       # 2) alpha codec config chunk
        $$vars{gainmap_item_codec_config_size} || 0,     # 3) gainmap coded config chunk
        defined($$vars{icc_data_size_minus1}) ? $$vars{icc_data_size_minus1} + 1 : 0, # 4) icc profile chunk
        defined($$vars{tmap_icc_data_size_minus1}) ? $$vars{tmap_icc_data_size_minus1} + 1 : 0, # 5) tmap icc chunk
        $$vars{gainmap_metadata_size} || 0,              # 6) gainmap metadata chunk
        $$vars{alpha_item_data_size} || 0,               # 7) alpha chunk
        $$vars{gainmap_item_data_size} || 0,             # 8) gainmap chunk
        $$vars{main_item_data_size_minus1} + 1,          # 9) main item data chunk
        defined($$vars{exif_data_size_minus1}) ? $$vars{exif_data_size_minus1} + 1 : 0, # 10) exif chunk
        defined($$vars{xmp_data_size_minus1}) ? $$vars{xmp_data_size_minus1} + 1 : 0, # 11) xmp chunk
    );
    # calculate chunk offsets
    my ($i, @offsets);
    my $offset = 0;
    for ($i=0; $i<@sizes; ++$i) {
        $offsets[$i] = $offset;
        $offset += $sizes[$i];
    }
    # exit here if processing only the 'mini' bitstream header and return
    # information about the header variables and chunk Offsets and Sizes
    if ($$dirInfo{HeaderOnly}) {
        $$dirInfo{Vars} = $$bits{Vars};
        $$dirInfo{Offsets} = \@offsets;
        $$dirInfo{Sizes} = \@sizes;
        unless ($$dirInfo{BitsProc}) {
            return 0 if $offsets[-1] + $sizes[-1] != length $$dataPt;
        }
        return 1;
    }
#
# process the metadata chunks (icc, exif and xmp)
#
    my %parms = ( DataPt => $dataPt );
    if ($sizes[4]) {                                   # 4) icc profile chunk
        if ($offsets[4] + $sizes[4] <= length($$dataPt)) {
            $parms{Start} = $offsets[4];
            $parms{Size} = $sizes[4];
            $et->HandleTag($tagTbl, 'icc', undef, %parms);
        }
    }
    my $type;
    foreach $type ('exif', 'xmp') {
        $i = $type eq 'exif' ? 10 : 11;                 # 10/11) exif/xmp chunk
        next unless $sizes[$i];
        if ($offsets[$i] + $sizes[$i] <= length($$dataPt)) {
            $parms{Name} = uc $type;
            $parms{DataPt} = $dataPt;
            $parms{Start} = $offsets[$i];
            $parms{Size} = $sizes[$i];
            Inflate($et, \%parms) or next if $$vars{exif_xmp_compressed_flag};
            $$et{PROCESSED} = { }; # (bypass recursion protection)
            $et->HandleTag($tagTbl, $type, undef, %parms) if $parms{Size};
        }
    }
    $et->Warn('Unexpected mini box size') if $offset != length $$dataPt;
    return 1;
}

#------------------------------------------------------------------------------
# Write SlimHEIC 'mini' box
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub Write_mini($$$)
{
    my ($et, $dirInfo, $tagTbl) = @_;
    $et or return 1;      # allow dummy access to autoload this package
    my $editDirs = $$et{EDIT_DIRS};
    return undef unless $$editDirs{Mini};
    my $addDirs = $$et{ADD_DIRS};
    $$dirInfo{HeaderOnly} = 1;  # read only the bitstream header
    unless (Process_mini($et, $dirInfo, $tagTbl)) {
        $et->Warn('Format error in mif3 mini box');
        return undef;
    }
    my $dataPt = $$dirInfo{DataPt};
    my $vars = $$dirInfo{Vars};         # header variable values
    my $offsets = $$dirInfo{Offsets};   # metadata chunk offsets
    my $sizes = $$dirInfo{Sizes};       # metadata chunk sizes
    my ($i, $nvHash, $isCompressed, $chunk, %has);
    my $wasCompressed = $isCompressed = $$vars{exif_xmp_compressed_flag};
    # set compressed flag according to Compress option setting
    if (defined $$et{OPTIONS}{Compress}) {
        $isCompressed = $$vars{exif_xmp_compressed_flag} = $$et{OPTIONS}{Compress} ? 1 : 0;
    }
    # set Orientation if specified
    my $val = $et->GetNewValue($Image::ExifTool::Mini::Main{orientation_minus1}, \$nvHash);
    if (defined $val) {
        my $isOverwriting = $et->IsOverwriting($nvHash, $$vars{orientation_minus1});
        if ($isOverwriting and $val != $$vars{orientation_minus1}) {
            $$vars{orientation_minus1} = $val;
            ++$$et{CHANGED};
        }
    }
    my $maxSize = $$vars{large_metadata_flag} ? 0x100000 : 0x400;
    # rewrite ICC, EXIF and XMP chunks
    my @chunk = ({
        Index => 4,
        Name  => 'ICC_Profile',
        Table => 'ICC_Profile::Main',
        Flag  => 'icc',
    },{
        Index => 10,
        Name  => 'EXIF',
        Table => 'Exif::Main',
        Flag  => 'exif',
        Compressible => 1,
        WriteProc => \&Image::ExifTool::WriteTIFF,
    },{
        Index => 11,
        Name  => 'XMP',
        Table => 'XMP::Main',
        Flag  => 'xmp',
        Compressible => 1,
    });
    # (this is fairly straighforward, but dealing with changing the compression
    #  flag and/or compression/decompression failures complicates things somewhat)
    foreach $chunk (@chunk) {
        my $i = $$chunk{Index};
        my $name = $$chunk{Name};
        my $editDir = $$editDirs{$name};
        # edit this chunk if compressible and the compression changed
        $editDir = 1 if $$chunk{Compressible} and $isCompressed ne $wasCompressed;
        next unless $$addDirs{$name} or ($$sizes[$i] and $editDir);
        my ($old, $oldPt, $new, $newPt);
        $old = $$sizes[$i] ? substr($$dataPt, $$offsets[$i], $$sizes[$i]) : '';
        if ($$chunk{Compressible} and $wasCompressed and length $old) {
            my %block = ( Name => $name, DataPt => \$old );
            Inflate($et, \%block) or next;
            $oldPt = $block{DataPt};
        } else {
            $oldPt = \$old;
        }
        my $tbl = GetTagTable("Image::ExifTool::$$chunk{Table}");
        my %dirInfo = ( DataPt => $oldPt );
        my $oldChanged = $$et{CHANGED};
        $new = $et->WriteDirectory(\%dirInfo, $tbl, $$chunk{WriteProc}) if $$editDirs{$name};
        # re-use original data if nothing changed (eg. avoid unnecessary restructuring)
        $new = $$oldPt if $$et{CHANGED} eq $oldChanged;
        $$et{CHANGED} = $oldChanged; # (we'll handle this later)
        if (not defined $new or $new eq $$oldPt) {
            # the data for this chunk didn't change, so unless the
            # compression changed, just rewrite the original data
            next unless $$chunk{Compressible} and $isCompressed ne $wasCompressed;
            # fall through using old data if necessary to change compression
            $new = $old unless defined $new;
        }
        if ($$chunk{Compressible} and $isCompressed and length $new) {
            my %block = ( DataPt => \$new, Name => $name );
            if (Deflate($et, \%block)) {
                $newPt = $block{DataPt};
            } else {
                # write as uncompressed and reset compression flag
                $$vars{exif_xmp_compressed_flag} = $isCompressed = 0;
                $newPt = \$new; # write uncompressed data
            }
        } else {
            $newPt = \$new;
        }
        if (length($$newPt) > $maxSize) {
            if (length($$newPt) > 0x100000) {
                my $str = $isCompressed ? '' : ', try using the Compress option';
                $et->Warn("$name too large to write$str");
                next;
            }
            $et->VPrint(0, "$$et{INDENT}\[Setting large_metadata_flag due to $name]\n");
            $$vars{large_metadata_flag} = 1;
        }
        if (length $$newPt) {
            $$vars{"$$chunk{Flag}_flag"} = 1;
            $$vars{"$$chunk{Flag}_data_size_minus1"} = length($$newPt) - 1;
            $$sizes[$i] = $newPt;   # set size to new data ref
            $has{$isCompressed ? 'Compressed' : 'Uncompressed'} = 1 if $$chunk{Compressible};
        } else {
            $$vars{"$$chunk{Flag}_flag"} = 0;
            $$sizes[$i] = 0;
        }
        ++$$et{CHANGED};    # success!
    }
    return undef unless $$et{CHANGED};  # rewrite original data if nothing changed
    # update $has compression flags for unedited EXIF or XMP
    foreach $i (10,11) {
        next if ref $$sizes[$i] or not $$sizes[$i];
        # this chunk wasn't changed, so the compression state is same as original
        $has{$wasCompressed ? 'Compressed' : 'Uncompressed'} = 1;
    }
    # verify the compression status of EXIF and XMP (it is possible to be
    # inconsistent if we had an inflate/deflate error in one of the types)
    if ($has{Compressed} and not $isCompressed or $has{Uncompressed} and $isCompressed) {
        $et->Error('Compression error when writing Mini box');
    }
    # rebuild mini box header from $bits data
    my $outBuff = '';
    $$dirInfo{DataPt} = \$outBuff;
    $$dirInfo{BitsProc} = \&SetBits;
    return undef unless Process_mini($et, $dirInfo, $tagTbl);
    # add back all blocks (block 0 header is already there)
    for ($i=1; $i<@$sizes; ++$i) {
        # ($sizes holds the new data if it is scalar reference)
        ref $$sizes[$i] and $outBuff .= ${$$sizes[$i]}, next;
        $outBuff .= substr($$dataPt, $$offsets[$i], $$sizes[$i]);
    }
    return $outBuff;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Mini - Read SlimHEIF 'mini' metadata

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains routines required by Image::ExifTool to read/write
metadata in the 'mini' box of mif3 low-overhead SlimHEIF files.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://github.com/MediaArea/MediaInfoLib>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Mini Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

