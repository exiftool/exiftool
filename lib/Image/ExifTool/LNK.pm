#------------------------------------------------------------------------------
# File:         LNK.pm
#
# Description:  Read meta information from MS Shell Link files
#
# Revisions:    2009/09/19 - P. Harvey Created
#               2025/10/20 - PH Added .URL file support
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

$VERSION = '1.14';

sub ProcessItemID($$$);
sub ProcessLinkInfo($$$);

my %guidLookup = (
    # ref https://learn.microsoft.com/en-us/windows/win32/shell/knownfolderid
    '008CA0B1-55B4-4C56-B8A8-4DE4B299D3BE' => 'Account Pictures (per-user)',
    'DE61D971-5EBC-4F02-A3A9-6C82895E5C04' => 'Get Programs (virtual)',
    '724EF170-A42D-4FEF-9F26-B60E846FBA4F' => 'Administrative Tools (per-user)',
    'B2C5E279-7ADD-439F-B28C-C41FE1BBF672' => 'AppDataDesktop (per-user)',
    '7BE16610-1F7F-44AC-BFF0-83E15F2FFCA1' => 'AppDataDocuments (per-user)',
    '7CFBEFBC-DE1F-45AA-B843-A542AC536CC9' => 'AppDataFavorites (per-user)',
    '559D40A3-A036-40FA-AF61-84CB430A4D34' => 'AppDataProgramData (per-user)',
    'A3918781-E5F2-4890-B3D9-A7E54332328C' => 'Application Shortcuts (per-user)',
    '1E87508D-89C2-42F0-8A7E-645A0F50CA58' => 'Applications (virtual)',
    'A305CE99-F527-492B-8B1A-7E76FA98D6E4' => 'Installed Updates (virtual)',
    'AB5FB87B-7CE2-4F83-915D-550846C9537B' => 'Camera Roll (per-user)',
    '9E52AB10-F80D-49DF-ACB8-4330F5687855' => 'Temporary Burn Folder (per-user)',
    'DF7266AC-9274-4867-8D55-3BD661DE872D' => 'Programs and Features (virtual)',
    'D0384E7D-BAC3-4797-8F14-CBA229B392B5' => 'Administrative Tools (common)',
    'C1BAE2D0-10DF-4334-BEDD-7AA20B227A9D' => 'OEM Links (common)',
    '0139D44E-6AFE-49F2-8690-3DAFCAE6FFB8' => 'Programs (common)',
    'A4115719-D62E-491D-AA7C-E74B8BE3B067' => 'Start Menu (common)',
    '82A5EA35-D9CD-47C5-9629-E15D2F714E6E' => 'Startup (common)',
    'B94237E7-57AC-4347-9151-B08C6C32D1F7' => 'Templates (common)',
    '0AC0837C-BBF8-452A-850D-79D08E667CA7' => 'Computer (virtual)',
    '4BFEFB45-347D-4006-A5BE-AC0CB0567192' => 'Conflicts (virtual)',
    '6F0CD92B-2E97-45D1-88FF-B0D186B8DEDD' => 'Network Connections (virtual)',
    '56784854-C6CB-462B-8169-88E350ACB882' => 'Contacts (per-user)',
    '82A74AEB-AEB4-465C-A014-D097EE346D63' => 'Control Panel (virtual)',
    '2B0F765D-C0E9-4171-908E-08A611B84FF6' => 'Cookies (per-user)',
    'B4BFCC3A-DB2C-424C-B029-7FE99A87C641' => 'Desktop (per-user)',
    '5CE4A5E9-E4EB-479D-B89F-130C02886155' => 'DeviceMetadataStore (common)',
    'FDD39AD0-238F-46AF-ADB4-6C85480369C7' => 'Documents (per-user)',
    '7B0DB17D-9CD2-4A93-9733-46CC89022E7C' => 'Documents (per-user)',
    '374DE290-123F-4565-9164-39C4925E467B' => 'Downloads (per-user)',
    '1777F761-68AD-4D8A-87BD-30B759FA33DD' => 'Favorites (per-user)',
    'FD228CB7-AE11-4AE3-864C-16F3910AB8FE' => 'Fonts (fixed)',
    'CAC52C1A-B53D-4EDC-92D7-6B2E8AC19434' => 'Games (virtual)',
    '054FAE61-4DD8-4787-80B6-090220C4B700' => 'GameExplorer (per-user)',
    'D9DC8A3B-B784-432E-A781-5A1130A75963' => 'History (per-user)',
    '52528A6B-B9E3-4ADD-B60D-588C2DBA842D' => 'Homegroup (virtual)',
    '9B74B6A3-0DFD-4F11-9E78-5F7800F2E772' => 'User name (%USERNAME%) (virtual)',
    'BCB5256F-79F6-4CEE-B725-DC34E402FD46' => 'ImplicitAppShortcuts (per-user)',
    '352481E8-33BE-4251-BA85-6007CAEDCF9D' => 'Temporary Internet Files (per-user)',
    '4D9F7874-4E0C-4904-967B-40B0D20C3E4B' => 'The Internet (virtual)',
    '1B3EA5DC-B587-4786-B4EF-BD1DC332AEAE' => 'Libraries (per-user)',
    'BFB9D5E0-C6A9-404C-B2B2-AE6DB6AF4968' => 'Links (per-user)',
    'F1B32785-6FBA-4FCF-9D55-7B8E7F157091' => 'Local (per-user)',
    'A520A1A4-1780-4FF6-BD18-167343C5AF16' => 'LocalLow (per-user)',
    '2A00375E-224C-49DE-B8D1-440DF7EF3DDC' => 'None (fixed)',
    '4BD8D571-6D19-48D3-BE97-422220080E43' => 'Music (per-user)',
    '2112AB0A-C86A-4FFE-A368-0DE96E47012E' => 'Music (per-user)',
    'C5ABBF53-E17F-4121-8900-86626FC2C973' => 'Network Shortcuts (per-user)',
    'D20BEEC4-5CA8-4905-AE3B-BF251EA09B53' => 'Network (virtual)',
    '31C0DD25-9439-4F12-BF41-7FF4EDA38722' => '3D Objects (per-user)',
    '2C36C0AA-5812-4B87-BFD0-4CD0DFB19B39' => 'Original Images (per-user)',
    '69D2CF90-FC33-4FB7-9A0C-EBB0F0FCB43C' => 'Slide Shows (per-user)',
    'A990AE9F-A03B-4E80-94BC-9912D7504104' => 'Pictures (per-user)',
    '33E28130-4E1E-4676-835A-98395C3BC3BB' => 'Pictures (per-user)',
    'DE92C1C7-837F-4F69-A3BB-86E631204A23' => 'Playlists (per-user)',
    '76FC4E2D-D6AD-4519-A663-37BD56068185' => 'Printers (virtual)',
    '9274BD8D-CFD1-41C3-B35E-B13F55A758F4' => 'Printer Shortcuts (per-user)',
    '5E6C858F-0E22-4760-9AFE-EA3317B67173' => 'User Name (%USERNAME%) (fixed)',
    '62AB5D82-FDC1-4DC3-A9DD-070D1D495D97' => 'ProgramData (fixed)',
    '905E63B6-C1BF-494E-B29C-65B732D3D21A' => 'Program Files (fixed)',
    '6D809377-6AF0-444B-8957-A3773F02200E' => 'Program Files (fixed)',
    '7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E' => 'Program Files (fixed)',
    'F7F1ED05-9F6D-47A2-AAAE-29D317C6F066' => 'Common Files (fixed)',
    '6365D5A7-0F0D-45E5-87F6-0DA56B6A4F7D' => 'Common Files (fixed)',
    'DE974D24-D9C6-4D3E-BF91-F4455120B917' => 'Common Files (fixed)',
    'A77F5D77-2E2B-44C3-A6A2-ABA601054A51' => 'Programs (per-user)',
    'DFDF76A2-C82A-4D63-906A-5644AC457385' => 'Public (fixed)',
    'C4AA340D-F20F-4863-AFEF-F87EF2E6BA25' => 'Public Desktop (common)',
    'ED4824AF-DCE4-45A8-81E2-FC7965083634' => 'Public Documents (common)',
    '3D644C9B-1FB8-4F30-9B45-F670235F79C0' => 'Public Downloads (common)',
    'DEBF2536-E1A8-4C59-B6A2-414586476AEA' => 'GameExplorer (common)',
    '48DAF80B-E6CF-4F4E-B800-0E69D84EE384' => 'Libraries (common)',
    '3214FAB5-9757-4298-BB61-92A9DEAA44FF' => 'Public Music (common)',
    'B6EBFB86-6907-413C-9AF7-4FC2ABF07CC5' => 'Public Pictures (common)',
    'E555AB60-153B-4D17-9F04-A5FE99FC15EC' => 'Ringtones (common)',
    '0482AF6C-08F1-4C34-8C90-E17EC98B1E17' => 'Public Account Pictures (common)',
    '2400183A-6185-49FB-A2D8-4A392A602BA3' => 'Public Videos (common)',
    '52A4F021-7B75-48A9-9F6B-4B87A210BC8F' => 'Quick Launch (per-user)',
    'AE50C081-EBD2-438A-8655-8A092E34987A' => 'Recent Items (per-user)',
    '1A6FDBA2-F42D-4358-A798-B74D745926C5' => 'Recorded TV (common)',
    'B7534046-3ECB-4C18-BE4E-64CD4CB7D6AC' => 'Recycle Bin (virtual)',
    '8AD10C31-2ADB-4296-A8F7-E4701232C972' => 'Resources (fixed)',
    'C870044B-F49E-4126-A9C3-B52A1FF411E8' => 'Ringtones (per-user)',
    '3EB685DB-65F9-4CF6-A03A-E3EF65729F3D' => 'Roaming (per-user)',
    'AAA8D5A5-F1D6-4259-BAA8-78E7EF60835E' => 'RoamedTileImages (per-user)',
    '00BCFC5A-ED94-4E48-96A1-3F6217F21990' => 'RoamingTiles (per-user)',
    'B250C668-F57D-4EE1-A63C-290EE7D1AA1F' => 'Sample Music (common)',
    'C4900540-2379-4C75-844B-64E6FAF8716B' => 'Sample Pictures (common)',
    '15CA69B3-30EE-49C1-ACE1-6B5EC372AFB5' => 'Sample Playlists (common)',
    '859EAD94-2E85-48AD-A71A-0969CB56A6CD' => 'Sample Videos (common)',
    '4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4' => 'Saved Games (per-user)',
    '3B193882-D3AD-4EAB-965A-69829D1FB59F' => 'Saved Pictures (per-user)',
    'E25B5812-BE88-4BD9-94B0-29233477B6C3' => 'Saved Pictures Library (per-user)',
    '7D1D3A04-DEBB-4115-95CF-2F29DA2920DA' => 'Searches (per-user)',
    'B7BEDE81-DF94-4682-A7D8-57A52620B86F' => 'Screenshots (per-user)',
    'EE32E446-31CA-4ABA-814F-A5EBD2FD6D5E' => 'Offline Files (virtual)',
    '0D4C3DB6-03A3-462F-A0E6-08924C41B5D4' => 'History (per-user)',
    '190337D1-B8CA-4121-A639-6D472D16972A' => 'Search Results (virtual)',
    '98EC0E18-2098-4D44-8644-66979315A281' => 'Microsoft Office Outlook (virtual)',
    '7E636BFE-DFA9-4D5E-B456-D7B39851D8A9' => 'Templates (per-user)',
    '8983036C-27C0-404B-8F08-102D10DCFD74' => 'SendTo (per-user)',
    '7B396E54-9EC5-4300-BE0A-2482EBAE1A26' => 'Gadgets (common)',
    'A75D362E-50FC-4FB7-AC2C-A8BEAA314493' => 'Gadgets (per-user)',
    'A52BBA46-E9E1-435F-B3D9-28DAA648C0F6' => 'OneDrive (per-user)',
    '767E6811-49CB-4273-87C2-20F355E1085B' => 'Camera Roll (per-user)',
    '24D89E24-2F19-4534-9DDE-6A6671FBB8FE' => 'Documents (per-user)',
    '339719B5-8C47-4894-94C2-D8F77ADD44A6' => 'Pictures (per-user)',
    '625B53C3-AB48-4EC1-BA1F-A1EF4146FC19' => 'Start Menu (per-user)',
    'B97D20BB-F46A-4C97-BA10-5E3608430854' => 'Startup (per-user)',
    '43668BF8-C14E-49B2-97C9-747784D784B7' => 'Sync Center (virtual)',
    '289A9A43-BE44-4057-A41B-587A76D7E7F9' => 'Sync Results (virtual)',
    '0F214138-B1D3-4A90-BBA9-27CBC0C5389A' => 'Sync Setup (virtual)',
    '1AC14E77-02E7-4E5D-B744-2EB1AE5198B7' => 'System32 (fixed)',
    'D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27' => 'System32 (fixed)',
    'A63293E8-664E-48DB-A079-DF759E0509F7' => 'Templates (per-user)',
    '9E3995AB-1F9C-4F13-B827-48B24B6C7174' => 'User Pinned (per-user)',
    '0762D272-C50A-4BB0-A382-697DCD729B80' => 'Users (fixed)',
    '5CD7AEE2-2219-4A67-B85D-6C9CE15660CB' => 'Programs (per-user)',
    'BCBD3057-CA5C-4622-B42D-BC56DB0AE516' => 'Programs (per-user)',
    'F3CE0F7C-4901-4ACC-8648-D5D44B04EF8F' => 'Users Full Name (virtual)',
    'A302545D-DEFF-464B-ABE8-61C8648D939B' => 'Libraries (virtual)',
    '18989B1D-99B5-455B-841C-AB7C74E4DDFC' => 'MyVideos (per-user)',
    '491E922F-5643-4AF4-A7EB-4E7A138D8174' => 'Videos (per-user)',
    # ref Google AI
    '00021401-0000-0000-C000-000000000046' => 'Shell Link Class Identifier',
    '20D04FE0-3AEA-1069-A2D8-08002B30309D' => 'My Computer',
    '450D8FBA-AD25-11D0-A2A8-0800361B3003' => 'My Documents',
    'B4BFCC3A-DB2C-424C-B029-7FE99A87C641' => 'Desktop',
    'F3364BA0-65B9-11CE-A9BA-00AA004AE661' => 'Search Results Folder',
    '04731B67-D933-450A-90E6-4ACD2E9408FE' => 'CLSID_SearchFolder (Windows Search)',
    '53F5630D-B6BF-11D0-94F2-00A0C91EFB8B' => 'Device Class GUID for a volume',
    'F42EE2D3-909F-4907-8871-4C22FC0BF756' => 'Documents',
    '17789161-0268-45B3-8557-013009765873' => 'Local AppData',
    '9E395ED8-512D-4315-9960-9110B74616C8' => 'Recent Items',
    '21EC2020-3AEA-1069-A2DD-08002B30309D' => 'Control Panel Items',
    '7007ACC7-3202-11D1-AAD2-00805FC1270E' => 'Network Connections',
);

# Information extracted from LNK (Windows Shortcut) files
%Image::ExifTool::LNK::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Other' },
    VARS => { ID_FMT => 'hex' },    # print hex ID's in documentation
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
    # note: tags 0x100xx-0x300xx are synthesized tag ID's
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
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::EnvVarData' },
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

# ref: https://helgeklein.com/blog/dissecting-a-shortcut/
%Image::ExifTool::LNK::ItemID = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&ProcessItemID,
    # can't find any documentation on these items, but AI gives this:
    # 0x1f - root folder
    # 0x2e/0x2f - volume item
    # 0x31 - directory
    # 0x32 - file entry
    # 0x35/0x36 directory/file (Unicode)
    # 0x41-0x4c - network items
    # 0x61 - URI/URL
    # 0x71 - control panel
    0x1f => {
        Name => 'FolderInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::FolderInfo' },
    },
    0x2e => {
        Name => 'VolumeGUID',
        ValueConv => 'require Image::ExifTool::ASF; Image::ExifTool::ASF::GetGUID(substr($val,4))',
        SeparateTable => 'GUID',
        PrintConv => \%guidLookup,
    },
    0x2f => {
        Name => 'VolumeName',
        ValueConv => '$_ = substr($val, 3); s/\0+$//; $_',
    },
    0x31 => {
        Name => 'FileInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::FileInfo' },
    },
    0x32 => {
        Name => 'TargetInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::TargetInfo' },
    },
    0x35 => {
        Name => 'DirInfo',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::DirInfo' },
    },
    0x36 => {
        Name => 'FileInfo2',
        SubDirectory => { TagTable => 'Image::ExifTool::LNK::FileInfo2' },
    },
    0x71 => {
        Name => 'ControlPanelShellItem',
        ValueConv => 'require Image::ExifTool::ASF; Image::ExifTool::ASF::GetGUID(substr($val,14))',
        SeparateTable => 'GUID',
        PrintConv => \%guidLookup,
    },
    0xff => { #PH
        Name => 'VendorData',
        # extract Unicode and ASCII strings from vendor data (min length 3 chars, null terminated)
        # or return binary data if no strings
        ValueConv => q{
            my @strs = $val =~ /([\x21-\x7f]\0[\x20-\x7f]\0(?:[\x20-\x7f]\0)+\0|[\x21-\x7f][\x20-\x7f][\x20-\x7f]+)\0/g;
            tr/\0//d foreach @strs; # convert all to ASCII
            return @strs ? (@strs == 1 ? $strs[0] : \@strs) : \$val;
        },
    },
);

%Image::ExifTool::LNK::FolderInfo = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    # (is this useful?) 0x03 => 'FolderID',
    0x04 => {
        Name => 'FolderGUID',
        Format => 'undef[16]',
        ValueConv => 'require Image::ExifTool::ASF; Image::ExifTool::ASF::GetGUID($val)',
        SeparateTable => 'GUID',
        PrintConv => \%guidLookup,
    },
);

# ref https://helgeklein.com/blog/dissecting-a-shortcut/
%Image::ExifTool::LNK::FileInfo = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    # (always 0?) 3 => 'FileEntryFlags',
    # (always 0?) 4 => { Name => 'FileEntrySize', Format => 'int32u' },
    8 => {
        Name => 'FileEntryModifyDate',
        Groups => { 2 => 'Time' },
        Format => 'int32u',
        ValueConv => 'Image::ExifTool::LNK::DOSTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    12 => {
        Name => 'FileEntryAttributes',
        PrintConv => { BITMASK => {
            0 => 'Read-only',
            1 => 'Hidden',
            2 => 'System',
            3 => 'Volume Label',
            4 => 'Directory',
            5 => 'Archive',
        }},
    },
    14 => {
        Name => 'FileEntryDOSName',
        Format => 'string[$size-14]',
        # Hook based on minimum length of 2
        Hook => '$$dataPt =~ /^.{$pos}(.*?)\0/s and $varSize += length($1) & 0xfffe',
    },
    # 16 - int16u ExtensionSize
    # 18 - int16u ExtensionVersion
    # 20 - int16u unknown
    # 22 - int16u 0xbeef
    24 => {
        Name => 'FileEntryCreateDate',
        Groups => { 2 => 'Time' },
        Format => 'int32u',
        ValueConv => 'Image::ExifTool::LNK::DOSTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    28 => {
        Name => 'FileEntryAccessDate',
        Groups => { 2 => 'Time' },
        Format => 'int32u',
        ValueConv => 'Image::ExifTool::LNK::DOSTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    36 => {
        Name => 'FileEntryName',
        Format => 'unicode[int(($size-$varSize-36)/2)-1]',
    },
);

# (same structure as above)
%Image::ExifTool::LNK::TargetInfo = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    # (always 0?) 3 => 'TargetFileFlags',
    # (duplicate tag name) 4 => { Name => 'TargetFileSize', Format => 'int32u' },
    8 => {
        Name => 'TargetFileModifyDate',
        Groups => { 2 => 'Time' },
        Format => 'int32u',
        ValueConv => 'Image::ExifTool::LNK::DOSTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    12 => {
        Name => 'TargetFileAttributes',
        PrintConv => { BITMASK => {
            0 => 'Read-only',
            1 => 'Hidden',
            2 => 'System',
            3 => 'Volume Label',
            4 => 'Directory',
            5 => 'Archive',
        }},
    },
    14 => {
        Name => 'TargetFileDOSName',
        Format => 'string[$size-14]',
        # Hook based on minimum length of 2
        Hook => '$$dataPt =~ /^.{$pos}(.*?)\0/s and $varSize += length($1) & 0xfffe',
    },
    # 16 - int16u ExtensionSize
    # 18 - int16u ExtensionVersion
    # 20 - int16u unknown
    # 22 - int16u 0xbeef
    24 => {
        Name => 'TargetFileCreateDate',
        Groups => { 2 => 'Time' },
        Format => 'int32u',
        ValueConv => 'Image::ExifTool::LNK::DOSTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    28 => {
        Name => 'TargetFileAccessDate',
        Groups => { 2 => 'Time' },
        Format => 'int32u',
        ValueConv => 'Image::ExifTool::LNK::DOSTime($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    36 => {
        Name => 'TargetFileName',
        Format => 'unicode[int(($size-$varSize-36)/2)-1]',
    },
);

%Image::ExifTool::LNK::DirInfo = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    14 => {
        Name => 'LinkedDirectoryName',
        Format => 'unicode[int(($size-14)/2)-1]',
    },
);

%Image::ExifTool::LNK::FileInfo2 = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    14 => {
        Name => 'LinkedFileName',
        Format => 'unicode[int(($size-14)/2)-1]',
    },
);

%Image::ExifTool::LNK::LinkInfo = (
    GROUPS => { 2 => 'Other' },
    PROCESS_PROC => \&ProcessLinkInfo,
    FORMAT => 'int32u',
    VARS => { ID_FMT => 'none' },
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
    CommonPathSuffixUnicode => { },
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

%Image::ExifTool::LNK::EnvVarData = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 2 => 'Other' },
    8 => {
        Name => 'EnvironmentTarget',
        Format => 'string[260]',
    },
    268 => {
        Name => 'EnvironmentTargetUnicode',
        Format => 'unicode[260]',
    },
);

%Image::ExifTool::LNK::INI = (
    GROUPS => { 2 => 'Document' },
    VARS => { ID_FMT => 'none' },
    NOTES => 'Tags found in INI-format Windows .URL files.',
    URL         => { },
    IconFile    => { },
    IconIndex   => { },
    WorkingDirectory => { },
    HotKey      => { },
    ShowCommand => { PrintConv => { 1 => 'Normal', 2 => 'Minimized', 3 => 'Maximized' } },
    Modified    => {
        Groups => { 2 => 'Time' },
        Format => 'int64u',
        Groups => { 2 => 'Time' },
        # convert time from 100-ns intervals since Jan 1, 1601 (NC)
        RawConv => q{
            my $dat = pack('H*', $val);
            return undef if length $dat < 8;
            my ($lo, $hi) = unpack('V2', $dat);
            return undef unless $lo or $hi;
            return $hi * 4294967296 + $lo;
        },
        ValueConv => '$val=$val/1e7-11644473600; ConvertUnixTime($val,1)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    Author      => { Groups => { 2 => 'Author' } },
    WhatsNew    => { },
    Comment     => { },
    Desc        => { },
    Roamed      => { Notes => '1 if synced across multiple devices' },
    IDList      => { },
);

#------------------------------------------------------------------------------
# Get DOS date/time
# Inputs: 0) date/time integer value (date in low word)
# Returns: EXIF-format date/time string
sub DOSTime($)
{
    my $val = shift;
    return sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d',
       (($val >> 9)  & 0x7f) + 1980, # year
        ($val >> 5)  & 0x0f, # month
        ($val >> 0)  & 0x1f, # day
        ($val >> 27) & 0x1f, # hour
        ($val >> 21) & 0x3f, # minute
        ($val >> 15) & 0x3e  # second (2 sec resolution)
    );
}

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
        last if $pos + 3 >= $dataLen;
        my $size = Get16u($dataPt, $pos);
        last if $size < 3 or $pos + $size > $dataLen;
        my $tag = Get8u($dataPt, $pos+2); # (just a guess -- may not be a tag at all)
        AddTagToTable($tagTablePtr, $tag, {
            Name => sprintf('Item_%.2x', $tag),
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
    return 0 if $dataLen < 0x24;
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
    $off = Get32u($dataPt, 0x18);
    if ($off and $off < $dataLen) {
        $val = GetString($dataPt, $off);
        $et->HandleTag($tagTablePtr, 'CommonPathSuffix', $val, %opts, Start=>$off, Size=>length($val)+1);
    }
    if ($hdrLen >= 0x24) {
        $off = Get32u($dataPt, 0x20);
        if ($off and $off < $dataLen) {
            $val = GetString($dataPt, $off, 1);
            $et->HandleTag($tagTablePtr, 'CommonPathSuffixUnicode', $val, %opts, Start=>$off, Size=>length($val)+1);
        }
    }
    return 1;
}

#------------------------------------------------------------------------------
# Extract information from a INI-format file
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid INI file
sub ProcessINI($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;
    local $/ = "\x0d\x0a";
    my $tagTablePtr = GetTagTable('Image::ExifTool::LNK::INI');
    while ($raf->ReadLine($buff)) {
        if ($buff =~ /^\[(.*?)\]/) {
            $et->VPrint(0, "$1 section:\n");
        } elsif ($buff =~ /^\s*(\w+)=(.*)\x0d\x0a$/) {
            $et->HandleTag($tagTablePtr, $1, $2, MakeTagInfo => 1);
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
    unless ($buff =~ /^.{4}\x01\x14\x02\0{5}\xc0\0{6}\x46/s) {
        # check for INI-format LNK file (eg. .URL file)
        return undef unless $buff =~ /^\[[InternetShortcut\][\x0d\x0a]/;
        $raf->Seek(0,0) or return 0;
        $et->SetFileType('URL', 'application/x-mswinurl');
        return ProcessINI($et, $dirInfo);
    };
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

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

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

