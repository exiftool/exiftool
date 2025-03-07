#------------------------------------------------------------------------------
# File:         PCAP.pm
#
# Description:  Read CAP, PCAP and PCAPNG Packet Capture files
#
# Revisions:    2025-03-03 - P. Harvey Created
#
# References:   1) https://www.ietf.org/archive/id/draft-gharris-opsawg-pcap-01.html
#               2) https://www.ietf.org/archive/id/draft-ietf-opsawg-pcapng-02.html
#               3) https://formats.kaitai.io/microsoft_network_monitor_v2/
#------------------------------------------------------------------------------

package Image::ExifTool::PCAP;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

%Image::ExifTool::PCAP::Main = (
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Other' },
    VARS => { NO_LOOKUP => 1 }, # omit tags from lookup
    NOTES => 'Tags extracted from  CAP, PCAP and PCAPNG Packet Capture files.',
# (Note: All string values are UTF-8 but I'm going to be lazy and not bother decoding them)
    ByteOrder => {
        PrintConv => {
            II => 'Little-endian (Intel, II)',
            MM => 'Big-endian (Motorola, MM)',
        },
    },
    PCAPVersion => { },
    LinkType => {
        PrintConvColumns => 2,
        PrintConv => {
            # (see https://datatracker.ietf.org/doc/html/draft-richardson-opsawg-pcaplinktype-01 for a full list)
            0 => 'BSD Loopback',
            1 => 'IEEE 802.3 Ethernet',
            2 => 'Experimental 4Mb Ethernet',
            3 => 'AX.25',
            4 => 'PRONET',
            5 => 'MIT CHAOSNET',
            6 => 'IEEE 802.5',
            7 => 'ARCNET BSD',
            8 => 'SLIP',
            9 => 'PPP',
            10 => 'fddI',
          # 11-49 not to be used
            50 => 'PPP HDLC',
            51 => 'PPP Ethernet',
          # 52-98 not to be used
            99 => 'Symantec Firewall',
            100 => 'ATM RFC 1483',
            101 => 'Raw',
            102 => 'SLIP BSD/OS',
            103 => 'PPP BSD/OS',
            104 => 'Cisco PPP with HDLC',
            105 => 'IEEE 802.11',
            106 => 'ATM Classical IP',
            107 => 'Frame Relay',
            108 => 'OpenBSD Loopback',
            109 => 'OpenBSD IPSEC',
            110 => 'ATM LANE 802.3',
            111 => 'NetBSD HIPPI',
            112 => 'NetBSD HDLC',
            113 => 'Linux SLL',
            114 => 'Apple LocalTalk',
            115 => 'Acorn Econet',
            116 => 'OpenBSD ipfilter',
            117 => 'OpenBSD pflog',
            118 => 'Cisco IOS',
            119 => 'IEEE 802.11 Prism',
            120 => 'IEEE 802.11 Aironet',
            121 => 'Siemens HiPath HDLC',
            122 => 'IP-over-Fibre',
            123 => 'SunATM',
            124 => 'RapidIO',
            125 => 'PCI Express',
            126 => 'Xilinx Aurora',
            127 => 'IEEE 802.11 Radiotap',
            128 => 'Tazmen Sniffer',
            129 => 'ARCNET Linux',
            130 => 'Juniper MLPPP',
            131 => 'Juniper MLFR',
            132 => 'Juniper ES',
            133 => 'Juniper GGSN',
            134 => 'Juniper MFR',
            135 => 'Juniper ATM2',
            136 => 'Juniper Services',
            137 => 'Juniper ATM1',
            138 => 'Apple IP-over-IEEE 1394',
            139 => 'MTP2 with PHDR',
            140 => 'MTP2',
            141 => 'MTP3',
            142 => 'SCCP',
            143 => 'DOCSIS',
            144 => 'Linux IrDA',
            145 => 'IBM SP',
            146 => 'IBM SN',
          # 147-162 - reserved
            163 => 'IEEE 802.11 AVS',
            164 => 'Juniper Monitor',
            165 => 'BACnet MS/TP',
            166 => 'PPP PPPD',
            167 => 'Juniper PPPOE',
            168 => 'Juniper PPPOE ATM',
            169 => 'GPRS LLC',
            170 => 'GPF-T',
            171 => 'GPF-F',
            172 => 'Gcom T1/E1',
            173 => 'Gcom Serial',
            174 => 'Juniper PIC Peer',
            175 => 'ERF ETH',
            176 => 'ERF POS',
            177 => 'Linux LAPD',
            178 => 'Juniper Ether',
            179 => 'Juniper PPP',
            180 => 'Juniper Frame Relay',
            181 => 'Juniper CHDLC',
            182 => 'MFR',
            182 => 'Juniper VP',
            185 => 'A653 ICM',
            186 => 'USB FreeBSD',
            187 => 'Bluetooth HCI H4',
            188 => 'IEEE 802.16 MAC CPS',
            189 => 'USB Linux',
            190 => 'CAN 2.0B',
            191 => 'IEEE 802.15.4 Linux',
            192 => 'PPI',
            193 => 'IEEE 802.16 MAC CPS Radio',
            194 => 'Juniper ISM',
            195 => 'IEEE 802.15.4 with FCS',
            196 => 'SITA',
            197 => 'ERF',
            198 => 'RAIF1',
            199 => 'IPMB Kontron',
            200 => 'Juniper ST',
            201 => 'Bluetooth HCI H4 with PHDR',
            202 => 'AX.25 KISS',
            203 => 'LAPD',
            204 => 'PPP with DIR',
            205 => 'Cisco HDLC with DIR',
            206 => 'Frame Relay with DIR',
            207 => 'LAPB with DIR',
          # 208 reserved
            209 => 'IPMB Linux',
            210 => 'FlexRay',
            211 => 'MOST',
            212 => 'LIN',
            213 => 'X2E Serial',
            214 => 'X2E Xoraya',
            215 => 'IEEE 802.15.4 Nonask PHY',
            216 => 'Linux evdev',
            217 => 'GSMtap Um',
            218 => 'GSMtap Abis',
            219 => 'MPLS',
            220 => 'USB Linux MMapped',
            221 => 'DECT',
            222 => 'AOS',
            223 => 'Wireless HART',
            224 => 'FC-2',
            225 => 'FC-2 with Frame Delims',
            226 => 'IPNET',
            227 => 'CAN Socketcan',
            228 => 'IPv4',
            229 => 'IPv6',
            230 => 'IEEE 802.15.4 No FCS',
            231 => 'D-Bus',
            232 => 'Juniper VS',
            233 => 'Juniper SRX E2E',
            234 => 'Juniper Fibre Channel',
            235 => 'DVB-CI',
            236 => 'Mux 27.010',
            237 => 'STANAG 5066 D_PDU',
            238 => 'Juniper ATM Cemic',
            239 => 'NFLOG',
            240 => 'Netanalyzer',
            241 => 'Netanalyzer Transparent',
            242 => 'IP-over-InfiniBand',
            243 => 'MPEG-2 TS',
            244 => 'NG40',
            245 => 'NFC LLCP',
            246 => 'Pfsync',
            247 => 'InfiniBand',
            248 => 'SCTP',
            249 => 'USBPcap',
            250 => 'RTAC Serial',
            251 => 'Bluetooth LE LL',
            252 => 'Wireshark Upper PDU',
            253 => 'Netlink',
            254 => 'Bluetooth Linux Monitor',
            255 => 'Bluetooth BREDR BB',
            256 => 'Bluetooth LE LL with PHDR',
            257 => 'PROFIBUS Data Link',
            258 => 'Apple PKTAP',
            259 => 'EPON',
            260 => 'IPMI HPM.2',
            261 => 'Z-Wave R1/R2',
            262 => 'Z-Wave R3',
            263 => 'WattStopper DLM',
            264 => 'ISO 14443',
            265 => 'RDS',
            266 => 'USB Darwin',
            267 => 'Openflow',
            268 => 'SDLC',
            269 => 'TI LLN Sniffer',
            270 => 'LoRaTap',
            271 => 'Vsock',
            272 => 'Nordic BLE',
            273 => 'DOCSIS 31 XRA31',
            274 => 'Ethernet MPacket',
            275 => 'DisplayPort AUX',
            276 => 'Linux SLL2',
            277 => 'Sercos Monitor',
            278 => 'Openvizsla',
            279 => 'Elektrobit EBHSR',
            280 => 'VPP Dispatch',
            281 => 'DSA Tag BRCM',
            282 => 'DSA Tag BRCM Prepend',
            283 => 'IEEE 802.15.4 Tap',
            284 => 'DSA Tag DSA',
            285 => 'DSA Tag EDSA',
            286 => 'ELEE',
            287 => 'Z-Wave Serial',
            288 => 'USB 2.0',
            289 => 'ATSC ALP',
        },
    },
    TimeStamp => {
        Groups => { 2 => 'Time' },
        ValueConv => q{
            return $val if $$self{WindowsTS};
            return ConvertUnixTime($val, 1, $$self{TSResol} < 1e-7 ? 9 : 6);
        },
        PrintConv => '$self->ConvertDateTime($val)',
    },
#
# "options" tags common to all blocks
#
    1 => 'Comment',
    2988 => {
        Name => 'CustomOption1',
        ValueConv => q{
            return undef unless length($val) > 4;
            my $len = Get16u(\$val, 2);
            return undef unless $len > 4 and $len <= length($val) - 4;
            my $str = 'Type='.Get16u(\$val,0).' PEN='.Get32u(\$val,4). ' Val='.substr($val, 8, $len-4);
        },
    },
    2989 => {
        Name => 'CustomOption2',
        Binary => 1,
    },
    19372 => {
        Name => 'CustomOption3',
        ValueConv => q{
            return undef unless length($val) > 4;
            my $len = Get16u(\$val, 2);
            return undef unless $len > 4 and $len <= length($val) - 4;
            my $str = 'Type='.Get16u(\$val,0).' PEN='.Get32u(\$val,4). ' Val='.substr($val, 8, $len-4);
        },
    },
    19373 => {
        Name => 'CustomOption3',
        Binary => 1,
    },
#
# "options" tags in Section Header Block
#
    'SHB-2' => 'Hardware',
    'SHB-3' => 'OperatingSytem',
    'SHB-4' => 'UserApplication',
#
# "options" tags in Interface Description Block
#
    'IDB-2' => 'DeviceName',
    'IDB-3' => 'Description',
    'IDB-4' => {
        Name => 'IPv4Addr',
        Description => 'IPv4 Addr',
        # IP address and net mask
        ValueConv => '$_=join(".", unpack("C*", $val))); s/(:.*?:.*?:.*?):/$1 /; $_',
    },
    'IDB-5' => {
        Name => 'IPv6Addr',
        Description => 'IPv6 Addr',
        ValueConv => 'join(":", unpack("(H4)8", $val)) . "/" . unpack("x16C",$val)',
    },
    'IDB-6' => {
        Name => 'MACAddr',
        ValueConv => 'join("-", unpack("(H2)6", $val))',
    },
    'IDB-7' => {
        Name => 'EUIAddr',
        ValueConv => 'join(":", unpack("(H4)4", $val))',
    },
    'IDB-8' => {
        Name => 'Speed',
        Format => 'int64u',
    },
    'IDB-9' => {
        Name => 'TimeStampResolution',
        Format => 'int8u',
        RawConv => '$$self{TSResol} = ($val & 0x80 ? 2 ** -($val & 0x7f) : 10 ** -$val)',
    },
    'IDB-10' => 'TimeZone',
    'IDB-11' => {
        Name => 'Filter',
        ValueConv => 'Get8u(\$val,0) . ": " . substr($val, 1)',
    },
    'IDB-12' => 'OperatingSytem',
    'IDB-13' => { Name => 'FCSLen',  Format => 'int8u' },
    'IDB-14' => {
        Name => 'TimeStampOffset',
        Format => 'int64u',
        RawConv => '$$self{TSOff} = $val',
    },
    'IDB-15' => 'Hardware',
    'IDB-16' => { Name => 'TXSpeed', Format => 'int64u' },
    'IDB-17' => { Name => 'RXSpeed', Format => 'int64u' },
    'IDB-18' => 'TimezoneName',
);

#------------------------------------------------------------------------------
# Extract metadata from a PCAP file
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid PCAP file
sub ProcessPCAP($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $tagTablePtr, $type, $ts, $byteOrder, $verPos);

    # verify this is a valid PCAP file
    return 0 unless $raf->Read($buff, 24) == 24;

    if ($buff =~ /^\xa1\xb2(\xc3\xd4|\x3c\x4d)\0.\0.|(\xd4\xc3|\x4d\x3c)\xb2\xa1.\0.\0/s) {
        $type = 'PCAP';
        my $tmp = $1 || $2;
        $$et{TSResol} = ($tmp eq "\xc3\xd4" or $tmp eq "\xd4\xc3") ? 1e-6 : 1e-9;
        $byteOrder = $buff =~ /^\xa1/ ? 'MM' : 'II';
        $verPos = 4;
    } elsif ($buff =~ /^\x0a\x0d\x0d\x0a.{4}(\x1a\x2b\x3c\x4d|\x4d\x3c\x2b\x1a)/s) {
        $type = 'PCAPNG';
        $byteOrder = $1 eq "\x1a\x2b\x3c\x4d" ? 'MM' : 'II';
        $verPos = 12;
    } elsif ($buff =~ /^GMBU\0\x02/) {
        # handle Windows Network Monitor 2.0 CAP files
        # http://web.archive.org/web/20240430011527/https://learn.microsoft.com/en-us/windows/win32/netmon2/capturefile-header-values
        $Image::ExifTool::static_vars{OverrideFileDescription}{CAP} = 'Microsoft Network Monitor Capture';
        $et->SetFileType('CAP', 'application/octet-stream', 'cap');
        $type = 'CAP';
        $tagTablePtr = GetTagTable('Image::ExifTool::PCAP::Main');
        my @a = unpack('x6v*', $buff);
        $$et{WindowsTS} = 1;
        my $val = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d.%.3d',@a[1,2,4..8]);
        $et->HandleTag($tagTablePtr, LinkType => $a[0]);
        $et->HandleTag($tagTablePtr, TimeStamp => $val);
        if ($raf->Seek(40,0) and $raf->Read($buff,8)==8) {
            my ($off, $len) = unpack('V2', $buff);
            # extract comment
            if ($len < 1024 and $raf->Seek($off,0) and $raf->Read($buff,$len) == $len) {
                $et->HandleTag($tagTablePtr, 1 => $buff);   # (NC) null terminated? Unicode?
            }
        }
        return 1;
    } else {
        return 0;
    }
    $et->SetFileType($type);
    SetByteOrder($byteOrder);
    $tagTablePtr = GetTagTable('Image::ExifTool::PCAP::Main');
    my $ver = Get16u(\$buff, $verPos) . '.' . Get16u(\$buff, $verPos+2);
    $et->HandleTag($tagTablePtr, PCAPVersion => "$type $ver");
    $et->HandleTag($tagTablePtr, ByteOrder => $byteOrder);

    if ($type eq 'PCAP') {
        $et->HandleTag($tagTablePtr, LinkType => Get16u(\$buff, 22));
        $raf->Read($buff, 8) == 8 or $et->Warn('Truncated PCAP file'), return 1;
        $ts = Get32u(\$buff, 0) + Get32u(\$buff, 4) * $$et{TSResol};
        $et->HandleTag($tagTablePtr, TimeStamp => $ts);
        return 1;
    }
    # read through PCAPNG options for the SHB, IDB and get the timestamp from the first EPD
    my $dir = 'SHB';    # Section Header Block
    for (;;) {
        $raf->Read($buff, 4) == 4 or last;
        my $opt = Get16u(\$buff, 0);
        my $len = Get16u(\$buff, 2);
        if ($opt == 0) { # (end of options?)
            last unless $raf->Read($buff, 20) == 20;
            my $dirNum = Get32u(\$buff, 4);
            if ($dirNum == 1) {
                $et->HandleTag($tagTablePtr, LinkType => Get16u(\$buff, 12));
                $dir = 'IDB';   # Interface Description Block
                next;           # continue with IDB options
            } elsif ($dirNum == 6) { # EPD (Enhanced Packet Data)
                my $ts = 4294967296 * Get32u(\$buff, 16);
                $raf->Read(\$buff, 4) == 4 or last;
                if ($$et{TSResol}) {
                    $ts = ($ts + Get32u(\$buff, 0)) * $$et{TSResol} + ($$et{TSOff} || 0);
                    $et->HandleTag($tagTablePtr, TimeStamp => $ts);
                }
            }
            last;
        }
        my $n = ($len + 3) & 0xfffc;    # round to an even 4 bytes
        $raf->Read($buff, $n) == $n or $et->Warn("Error reading $dir options"), last;
        my $id = $$tagTablePtr{$opt} ? $opt : "$dir-$opt";
        $et->HandleTag($tagTablePtr, $id, undef,
            DataPt  => \$buff,
            DataPos => $raf->Tell() - $n,
            Size    => $len,
            MakeTagInfo => 1,
        );
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::PCAP - Read CAP, PCAP and PCAPNG Packet Capture files

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read
metadata from CAP, PCAP and PCAPNG Packet Capture files.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://www.ietf.org/archive/id/draft-gharris-opsawg-pcap-01.html>

=item L<https://www.ietf.org/archive/id/draft-ietf-opsawg-pcapng-02.html>

=item L<https://formats.kaitai.io/microsoft_network_monitor_v2/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PCAP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

