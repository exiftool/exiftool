#------------------------------------------------------------------------------
# File:         LNK.pm
#
# Description:  Read meta information from MS Shell Link files
#
# Revisions:    2009/09/19 - P. Harvey Created
#
# References:   1) http://msdn.microsoft.com/en-us/library/dd871305(PROT.10).aspx
#               2) http://www.i2s-lab.com/Papers/The_Windows_Shortcut_File_Format.pdf
#               3) https://harfanglab.io/insidethelab/sadfuture-xdspy-latest-evolution/#tid_specifications_ignored
#------------------------------------------------------------------------------

package Image::ExifTool::LNK;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::Microsoft;

$VERSION = '1.11';

sub ProcessItemID($$$);
sub ProcessLinkInfo($$$);

# Information extracted from LNK (Windows Shortcut) files
%Image::ExifTool::LNK::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Other' },
    VARS => { HEX_ID => 1 },    # print hex ID's in documentation
    NOTES => 'Information extracted from MS Shell Link (Windows shortcut) files.',
    # maybe the Flags aren't very useful to the user (since they are
    # mainly structural), but extract them anyway for completeness
    0x14 => {
        Name => 'Flags',
        Format => 'int32u',
        PrintConv => { BITMASK => {
            0 => 'IDList',
            1 => 'LinkInfo',
            2 => 'Description',
            3 => 'RelativePath',
            4 => 'WorkingDir',
            5 => 'CommandArgs',
            6 => 'IconFile',
            7 => 'Unicode',
            8 => 'NoLinkInfo',
            9 => 'ExpString',
            10 => 'SeparateProc',
            12 => 'DarwinID',
            13 => 'RunAsUser',
            14 => 'ExpIcon',
            15 => 'NoPidAlias',
            17 => 'RunWithShim',
            18 => 'NoLinkTrack',
            19 => 'TargetMetadata',
            20 => 'NoLinkPathTracking',
            21 => 'NoKnownFolderTracking',
            22 => 'NoKnownFolderAlias',
            23 => 'LinkToLink',
            24 => 'UnaliasOnSave',
            25 => 'PreferEnvPath',
            26 => 'KeepLocalIDList',
        }},
    },
    0x18 => {
        Name => 'FileAttributes',
        Format => 'int32u',
        PrintConv => { BITMASK => {
            0 => 'Read-only',
            1 => 'Hidden',
            2 => 'System',
            3 => 'Volume', #(not used)
            4 => 'Directory',
            5 => 'Archive',
            6 => 'Encrypted?', #(ref 2, not used in XP)
            7 => 'Normal',
            8 => 'Temporary',
            9 => 'Sparse',
            10 => 'Reparse point',
            11 => 'Compressed',
            12 => 'Offline',
            13 => 'Not indexed',
            14 => 'Encrypted',
        }},
    },
    0x1c => {
        Name => 'CreateDate',
        Format => 'int64u',
        Groups => { 2 => 'Time' },
        # convert time from 100-ns intervals since Jan 1, 1601
        RawConv => '$val ? $val : undef',
        ValueConv => '$val=$val/1e7-11644473600; ConvertUnixTime($val,1)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x24 => {
        Name => 'AccessDate',
        Format => 'int64u',
        Groups => { 2 => 'Time' },
        RawConv => '$val ? $val : undef',
        ValueConv => '$val=$val/1e7-11644473600; ConvertUnixTime($val,1)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x2c => {
        Name => 'ModifyDate',
        Format => 'int64u',
        Groups => { 2 => 'Time' },
        RawConv => '$val ? $val : undef',
        ValueConv => '$val=$val/1e7-11644473600; ConvertUnixTime($val,1)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    0x34 => {
        Name => 'TargetFileSize',
        Format => 'int32u',
    },
    0x38 => {
        Name => 'IconIndex',
        Format => 'int32u',
        PrintConv => '$val ? $val : "(none)"',
    },
    0x3c => {
        Name => 'RunWindow',
        Format => 'int32u',
        PrintConv => {
            0 => 'Hide',
            1 => 'Normal',
            2 => 'Show Minimized',
            3 => 'Show Maximized',
            4 => 'Show No Activate',
            5 => 'Show',
            6 => 'Minimized',
            7 => 'Show Minimized No Activate',
            8 => 'Show NA',
            9 => 'Restore',
            10 => 'Show Default',
        },
    },
    0x40 => {
        Name => 'HotKey',
        Format => 'int32u',
        PrintHex => 1,
        PrintConv => {
            OTHER => sub {
                my $val = shift;
                my $ch = $val & 0xff;
                if (chr $ch =~ /^[A-Z0-9]$/) {
                    $ch = chr $ch;
                } elsif ($ch >= 0x70 and $ch <= 0x87) {
                    $ch = 'F' . ($ch - 0x6f);
                } elsif ($ch == 0x90) {
                    $ch = 'Num Lock';
                } elsif ($ch == 0x91) {
                    $ch = 'Scroll Lock';
                } else {
                    $ch = sprintf('Unknown (0x%x)', $ch);
                }
                $ch = "Alt-$ch" if $val & 0x400;
                $ch = "Control-$ch" if $val & 0x200;
                $ch = "Shift-$ch" if $val & 0x100;
                return $ch;
            },
            0x00 => '(none)',
            # these entries really only for documentation
            0x90 => 'Num Lock',
            0x91 => 'Scroll Lock',
           "0x30'-'0x39" => "0-9",
           "0x41'-'0x5a" => "A-Z",
           "0x70'-'0x87" => "F1-F24",
           0x100 => 'Shift',
           0x200 => 'Control',
           0x400 => 'Alt',
        },
    },
    # note: tags 0x10xx are synthesized tag ID's
    0x10000 => {
        Name => 'ItemID',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::ItemID' },
    },
    0x20000 => {
        Name => 'LinkInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::LinkInfo' },
    },
    0x30004 => 'Description',
    0x30008 => 'RelativePath',
    0x30010 => 'WorkingDirectory',
    0x30020 => 'CommandLineArguments',
    0x30040 => 'IconFileName',
    # note: tags 0xa000000x are actually ID's (not indices)
    0xa0000000 => {
        Name => 'UnknownData',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::UnknownData' },
    },
    0xa0000001 => {
        Name => 'EnvVarData',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::UnknownData' },
    },
    0xa0000002 => {
        Name => 'ConsoleData',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::ConsoleData' },
    },
    0xa0000003 => {
        Name => 'TrackerData',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::TrackerData' },
    },
    0xa0000004 => {
        Name => 'ConsoleFEData',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::ConsoleFEData' },
    },
    0xa0000005 => {
        Name => 'SpecialFolderData',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::UnknownData' },
    },
    0xa0000006 => {
        Name => 'DarwinData',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::UnknownData' },
    },
    0xa0000007 => {
        Name => 'IconEnvData',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::UnknownData' },
    },
    0xa0000008 => {
        Name => 'ShimData',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::UnknownData' },
    },
    0xa0000009 => {
        Name => 'PropertyStoreData',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::UnknownData' },
    },
    0xa000000b => {
        Name => 'KnownFolderData',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::UnknownData' },
    },
    0xa000000c => {
        Name => 'VistaIDListData',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::UnknownData' },
    },
);

%Image::ExifTool::LNK::ItemID = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&ProcessItemID,
    # (can't find any documentation on these items)
    0x0032 => {
        Name => 'Item0032',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::Item0032' },
    },
);

%Image::ExifTool::LNK::Item0032 = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    0x0e => {
        Name => 'TargetFileDOSName',
        Format => 'var_string',
    },
    #not at a fixed offset -- offset is given by last 2 bytes of the item + 0x14
    #0x22 => {
    #    Name => 'TargetFileName',
    #    Format => 'var_ustring',
    #},
);

%Image::ExifTool::LNK::LinkInfo = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&ProcessLinkInfo,
    FORMAT => 'int32u',
    VARS => { NO_ID => 1 },
    VolumeID => { },
    DriveType => {
        PrintConv => {
            0 => 'Unknown',
            1 => 'Invalid Root Path',
            2 => 'Removable Media',
            3 => 'Fixed Disk',
            4 => 'Remote Drive',
            5 => 'CD-ROM',
            6 => 'Ram Disk',
        },
    },
    DriveSerialNumber => {
        PrintConv => 'join("-", unpack("A4 A4", sprintf("%08X", $val)))',
    },
    VolumeLabel => { },
    LocalBasePath => { },
    CommonNetworkRelLink => { },
    CommonPathSuffix => { },
    NetName => { },
    DeviceName => { },
    NetProviderType => {
        PrintHex => 1,
        PrintConv => {
            0x1a0000 => 'AVID',
            0x1b0000 => 'DOCUSPACE',
            0x1c0000 => 'MANGOSOFT',
            0x1d0000 => 'SERNET',
            0x1e0000 => 'RIVERFRONT1',
            0x1f0000 => 'RIVERFRONT2',
            0x200000 => 'DECORB',
            0x210000 => 'PROTSTOR',
            0x220000 => 'FJ_REDIR',
            0x230000 => 'DISTINCT',
            0x240000 => 'TWINS',
            0x250000 => 'RDR2SAMPLE',
            0x260000 => 'CSC',
            0x270000 => '3IN1',
            0x290000 => 'EXTENDNET',
            0x2a0000 => 'STAC',
            0x2b0000 => 'FOXBAT',
            0x2c0000 => 'YAHOO',
            0x2d0000 => 'EXIFS',
            0x2e0000 => 'DAV',
            0x2f0000 => 'KNOWARE',
            0x300000 => 'OBJECT_DIRE',
            0x310000 => 'MASFAX',
            0x320000 => 'HOB_NFS',
            0x330000 => 'SHIVA',
            0x340000 => 'IBMAL',
            0x350000 => 'LOCK',
            0x360000 => 'TERMSRV',
            0x370000 => 'SRT',
            0x380000 => 'QUINCY',
            0x390000 => 'OPENAFS',
            0x3a0000 => 'AVID1',
            0x3b0000 => 'DFS',
        },
    },
);

%Image::ExifTool::LNK::UnknownData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Other' },
);

%Image::ExifTool::LNK::ConsoleData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Other' },
    0x08 => {
        Name => 'FillAttributes',
        Format => 'int16u',
        PrintConv => 'sprintf("0x%.2x", $val)',
    },
    0x0a => {
        Name => 'PopupFillAttributes',
        Format => 'int16u',
        PrintConv => 'sprintf("0x%.2x", $val)',
    },
    0x0c => {
        Name => 'ScreenBufferSize',
        Format => 'int16u[2]',
        PrintConv => '$val=~s/ / x /; $val',
    },
    0x10 => {
        Name => 'WindowSize',
        Format => 'int16u[2]',
        PrintConv => '$val=~s/ / x /; $val',
    },
    0x14 => {
        Name => 'WindowOrigin',
        Format => 'int16u[2]',
        PrintConv => '$val=~s/ / x /; $val',
    },
    0x20 => {
        Name => 'FontSize',
        Format => 'int16u[2]',
        PrintConv => '$val=~s/ / x /; $val',
    },
    0x24 => {
        Name => 'FontFamily',
        Format => 'int32u',
        PrintHex => 1,
        PrintConv => {
            0 => "Don't Care",
            0x10 => 'Roman',
            0x20 => 'Swiss',
            0x30 => 'Modern',
            0x40 => 'Script',
            0x50 => 'Decorative',
        },
    },
    0x28 => {
        Name => 'FontWeight',
        Format => 'int32u',
    },
    0x2c => {
        Name => 'FontName',
        Format => 'undef[64]',
        RawConv => q{
            $val = $self->Decode($val, 'UCS2');
            $val =~ s/\0.*//s;
            return length($val) ? $val : undef;
        },
    },
    0x6c => {
        Name => 'CursorSize',
        Format => 'int32u',
    },
    0x70 => {
        Name => 'FullScreen',
        Format => 'int32u',
        PrintConv => '$val ? "Yes" : "No"',
    },
    0x74 => { #PH (MISSING FROM MS DOCUMENTATION! -- screws up subsequent offsets)
        Name => 'QuickEdit',
        Format => 'int32u',
        PrintConv => '$val ? "Yes" : "No"',
    },
    0x78 => {
        Name => 'InsertMode',
        Format => 'int32u',
        PrintConv => '$val ? "Yes" : "No"',
    },
    0x7c => {
        Name => 'WindowOriginAuto',
        Format => 'int32u',
        PrintConv => '$val ? "Yes" : "No"',
    },
    0x80 => {
        Name => 'HistoryBufferSize',
        Format => 'int32u',
    },
    0x84 => {
        Name => 'NumHistoryBuffers',
        Format => 'int32u',
    },
    0x88 => {
        Name => 'RemoveHistoryDuplicates',
        Format => 'int32u',
        PrintConv => '$val ? "Yes" : "No"',
    },
);

%Image::ExifTool::LNK::TrackerData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Other' },
    0x10 => {
        Name => 'MachineID',
        Format => 'var_string',
    },
);

%Image::ExifTool::LNK::ConsoleFEData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Other' },
    0x08 => {
        Name => 'CodePage',
        Format => 'int32u',
        SeparateTable => 'Microsoft CodePage',
        PrintConv => \%Image::ExifTool::Microsoft::codePage,
    },
);

#------------------------------------------------------------------------------
# Extract null-terminated ASCII or Unicode string from buffer
# Inputs: 0) buffer ref, 1) start position, 2) flag for unicode string
# Return: string or undef if start position is outside bounds
sub GetString($$;$)
{
    my ($dataPt, $pos, $unicode) = @_;
    return undef if $pos >= length($$dataPt);
    pos($$dataPt) = $pos;
    return $1 if ($unicode ? $$dataPt=~/\G((?:..)*?)\0\0/sg : $$dataPt=~/\G(.*?)\0/sg);
    return substr($$dataPt, $pos);
}

#------------------------------------------------------------------------------
# Process item ID data
# Inputs: 0) ExifTool object reference, 1) dirInfo reference, 2) tag table ref
# Returns: 1 on success
sub ProcessItemID($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataLen = length $$dataPt;
    my $pos = 0;
    my %opts = (
        DataPt  => $dataPt,
        DataPos => $$dirInfo{DataPos},
    );
    $et->VerboseDir('ItemID', undef, $dataLen);
    for (;;) {
        last if $pos + 4 >= $dataLen;
        my $size = Get16u($dataPt, $pos);
        last if $size < 2 or $pos + $size > $dataLen;
        my $tag = Get16u($dataPt, $pos+2); # (just a guess -- may not be a tag at all)
        AddTagToTable($tagTablePtr, $tag, {
            Name => sprintf('Item%.4x', $tag),
            SubDirectory => { TagTable => 'Image::ExifTool::LNK::UnknownData' },
        }) unless $$tagTablePtr{$tag};
        $et->HandleTag($tagTablePtr, $tag, undef, %opts, Start => $pos, Size => $size);
        $pos += $size;
    }
}

#------------------------------------------------------------------------------
# Process link information data
# Inputs: 0) ExifTool object reference, 1) dirInfo reference, 2) tag table ref
# Returns: 1 on success
sub ProcessLinkInfo($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataLen = length $$dataPt;
    return 0 if $dataLen < 0x20;
    my $hdrLen = Get32u($dataPt, 4);
    my $lif = Get32u($dataPt, 8);   # link info flags
    my %opts = (
        DataPt  => $dataPt,
        DataPos => $$dirInfo{DataPos},
        Size    => 4, # (typical value size)
    );
    my ($off, $unicode, $pos, $val, $size);
    $et->VerboseDir('LinkInfo', undef, $dataLen);
    if ($lif & 0x01) {
        # read Volume ID
        $off = Get32u($dataPt, 0x0c);
        if ($off and $off + 0x20 <= $dataLen) {
            # my $len = Get32u($dataPt, $off);
            $et->HandleTag($tagTablePtr, 'DriveType', undef, %opts, Start=>$off+4);
            $et->HandleTag($tagTablePtr, 'DriveSerialNumber', undef, %opts, Start=>$off+8);
            $pos = Get32u($dataPt, $off + 0x0c);
            if ($pos == 0x14) {
                # use VolumeLabelOffsetUnicode instead
                $pos = Get32u($dataPt, $off + 0x10);
                $unicode = 1;
            }
            $pos += $off;
            $val = GetString($dataPt, $pos, $unicode);
            if (defined $val) {
                $size = length $val;
                $val = $et->Decode($val, 'UCS2') if $unicode;
                $et->HandleTag($tagTablePtr, 'VolumeLabel', $val, %opts, Start=>$pos, Size=>$size);
            }
        }
        # read local base path
        if ($hdrLen >= 0x24) {
            $pos = Get32u($dataPt, 0x1c);
            $unicode = 1;
        } else {
            $pos = Get32u($dataPt, 0x10);
            undef $unicode;
        }
        $val = GetString($dataPt, $pos, $unicode);
        if (defined $val) {
            $size = length $val;
            $val = $et->Decode($val, 'UCS2') if $unicode;
            $et->HandleTag($tagTablePtr, 'LocalBasePath', $val, %opts, Start=>$pos, Size=>$size);
        }
    }
    if ($lif & 0x02) {
        # read common network relative link
        $off = Get32u($dataPt, 0x14);
        if ($off and $off + 0x14 <= $dataLen) {
            my $siz = Get32u($dataPt, $off);
            return 0 if $off + $siz > $dataLen; 
            $pos = Get32u($dataPt, $off + 0x08);
            if ($pos > 0x14 and $siz >= 0x18) {
                $pos = Get32u($dataPt, $off + 0x14);
                $unicode = 1;
            } else {
                undef $unicode;
            }
            $val = GetString($dataPt, $off + $pos, $unicode);
            if (defined $val) {
                $size = length $val;
                $val = $et->Decode($val, 'UCS2') if $unicode;
                $et->HandleTag($tagTablePtr, 'NetName', $val, %opts, Start=>$pos, Size=>$size);
            }
            my $flg = Get32u($dataPt, $off + 0x04);
            if ($flg & 0x01) {
                $pos = Get32u($dataPt, $off + 0x0c);
                if ($pos > 0x14 and $siz >= 0x1c) {
                    $pos = Get32u($dataPt, $off + 0x18);
                    $unicode = 1;
                } else {
                    undef $unicode;
                }
                $val = GetString($dataPt, $off + $pos, $unicode);
                if (defined $val) {
                    $size = length $val;
                    $val = $et->Decode($val, 'UCS2') if $unicode;
                    $et->HandleTag($tagTablePtr, 'DeviceName', $val, %opts, Start=>$pos, Size=>$size);
                }
            }
            if ($flg & 0x02) {
                $val = Get32u($dataPt, $off + 0x10);
                $et->HandleTag($tagTablePtr, 'NetProviderType', $val, %opts, Start=>$off + 0x10);
            }
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from a MS Shell Link (Windows shortcut) file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid LNK file
sub ProcessLNK($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $buf2, $len, $i);

    # read LNK file header
    $raf->Read($buff, 0x4c) == 0x4c or return 0;
    $buff =~ /^.{4}\x01\x14\x02\0{5}\xc0\0{6}\x46/s or return 0;
    $len = unpack('V', $buff);
    $len >= 0x4c or return 0;
    if ($len > 0x4c) {
        $raf->Read($buf2, $len - 0x4c) == $len - 0x4c or return 0;
        $buff .= $buf2;
    }
    $et->SetFileType();
    SetByteOrder('II');

    my $tagTablePtr = GetTagTable('Image::ExifTool::LNK::Main');
    my %dirInfo = (
        DataPt => \$buff,
        DataPos => 0,
        DataLen => length $buff,
        DirLen => length $buff,
    );
    $et->ProcessDirectory(\%dirInfo, $tagTablePtr);

    my $flags = Get32u(\$buff, 0x14);

    # read link target ID list
    if ($flags & 0x01) {
        $raf->Read($buff, 2) or return 1;
        $len = unpack('v', $buff);
        $raf->Read($buff, $len) == $len or return 1;
        $et->HandleTag($tagTablePtr, 0x10000, undef,
            DataPt  => \$buff,
            DataPos => $raf->Tell() - $len,
            Size    => $len,
        );
    }

    # read link information
    if ($flags & 0x02) {
        $raf->Read($buff, 4) or return 1;
        $len = unpack('V', $buff);
        return 1 if $len < 4;
        $raf->Read($buf2, $len - 4) == $len - 4 or return 1;
        $buff .= $buf2;
        $et->HandleTag($tagTablePtr, 0x20000, undef,
            DataPt  => \$buff,
            DataPos => $raf->Tell() - $len,
            Size    => $len,
        );
    }

    # read string data
    my @strings = qw(Description RelativePath WorkingDirectory
                     CommandLineArguments IconFileName);
    for ($i=0; $i<@strings; ++$i) {
        my ($val, $limit);
        my $mask = 0x04 << $i;
        next unless $flags & $mask;
        $raf->Read($buff, 2) or return 1;
        my $pos = $raf->Tell();
        $len = unpack('v', $buff) or next;
        # Windows doesn't follow their own specification and limits the length
        # for most of these strings (ref 3)
        if ($i != 3 and $len >= 260) {
            $limit = 1;
            if ($len > 260) {
                $len = 260;
                $et->Warn('LNK string data overrun! Possible security issue');
            }
        }
        $len *= 2 if $flags & 0x80;  # characters are 2 bytes if Unicode flag is set
        $raf->Read($buff, $len) or return 1;
        # remove last character if string is at length limit (Windows treats this as a null)
        if ($limit) {
            $len -= $flags & 0x80 ? 2 : 1;
            $buff = substr($buff, 0, $len);
        }
        $val = $et->Decode($buff, 'UCS2') if $flags & 0x80;
        $et->HandleTag($tagTablePtr, 0x30000 | $mask, $val,
            DataPt  => \$buff,
            DataPos => $pos,
            Size    => $len,
        );
    }

    # read extra data
    while ($raf->Read($buff, 4) == 4) {
        $len = unpack('V', $buff);
        last if $len < 4;
        $len -= 4;
        $raf->Read($buf2, $len) == $len or last;
        next unless $len > 4;
        $buff .= $buf2;
        my $tag = Get32u(\$buff, 4);
        my $tagInfo = $$tagTablePtr{$tag};
        unless (ref $tagInfo eq 'HASH' and $$tagInfo{SubDirectory}) {
            $tagInfo = $$tagTablePtr{0xa0000000};
        }
        $et->HandleTag($tagTablePtr, $tag, undef,
            DataPt  => \$buff,
            DataPos => $raf->Tell() - $len - 4,
            TagInfo => $tagInfo,
        );
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::LNK - Read MS Shell Link (.LNK) meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract meta
information MS Shell Link (Windows shortcut) files.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://msdn.microsoft.com/en-us/library/dd871305(PROT.10).aspx>

=item L<http://www.i2s-lab.com/Papers/The_Windows_Shortcut_File_Format.pdf>

=item L<https://harfanglab.io/insidethelab/sadfuture-xdspy-latest-evolution/#tid_specifications_ignored>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/LNK Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

