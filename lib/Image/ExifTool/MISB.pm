#------------------------------------------------------------------------------
# File:         MISB.pm
#
# Description:  Read Motion Industry Standards Board metadata
#
# Revisions:    2022/10/08 - P. Harvey Created
#
# References: 1) https://dokumen.tips/documents/nato-standardization-agreement-stanag-4609-ed-3.html
#             2) https://upload.wikimedia.org/wikipedia/commons/1/19/MISB_Standard_0601.pdf
#             3) https://dokumen.tips/documents/misb-st-010211-standard-security-metadata-universal-standard-describes-the-use.html
#------------------------------------------------------------------------------

package Image::ExifTool::MISB;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

sub ProcessKLV($$$);

my %timeInfo = (
    Groups => { 2 => 'Time' },
    Format => 'int64u',
    ValueConv => 'ConvertUnixTime($val/1e6, 0, 6) . "Z"',
    PrintConv => '$self->ConvertDateTime($val)',
);
my %latInfo = (
    Format => 'int32s',
    ValueConv => '$val * 90 / 0x7fffffff',
    PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
);
my %lonInfo = (
    Format => 'int32s',
    ValueConv => '$val * 180 / 0x7fffffff',
    PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
);
my %altInfo = (
    Format => 'int16u',
    ValueConv => '$val * 19900 / 0xffff - 900',
    PrintConv => 'sprintf("%.2f m", $val)',
);

# default format based on size of unknown KLV information
my %defaultFormat = (
    1 => 'int8u',
    2 => 'int16u',
    4 => 'int32u',
    8 => 'int64u',
);

%Image::ExifTool::MISB::Main = (
    GROUPS => { 0 => 'MISB', 1 => 'MISB', 2 => 'Other' },
    VARS => { LONG_TAGS => 2 },
    NOTES => q{
        These tags are extracted from STANAG-4609 MISB (Motion Industry Standards
        Board) KLV-format metadata in M2TS videos.
    },
    '060e2b34020b01010e01030101000000' => {
        Name => 'UASDataLink',
        SubDirectory => { TagTable => 'Image::ExifTool::MISB::UASDatalink' },
    },
    '060e2b3402030101434e415644494147' => { # "CNAVDIAG" written by ChurchillNavigation ION
        Name => 'ChurchillNav',
        SubDirectory => {
            TagTable => 'Image::ExifTool::MISB::ChurchillNav',
            ByteOrder => 'LittleEndian', # !!
        },
    },
    '060E2B34030101010E01030302000000' => { # (NC)
        Name => 'Security',
        SubDirectory => { TagTable => 'Image::ExifTool::MISB::Security' },
    },
    '<other>' => {
        Name => 'Unknown',
        SubDirectory => { TagTable => 'Image::ExifTool::MISB::Unknown' },
    },
);

# UAS datalink local set tags (ref 2, MISB ST 0601.11)
%Image::ExifTool::MISB::UASDatalink = (
    GROUPS => { 0 => 'MISB', 1 => 'MISB', 2 => 'Location' },
    PROCESS_PROC => \&ProcessKLV,
    NOTES => 'Tags extracted from the MISB ST 0601.11 UAS Datalink local set.',
    1  => { Name => 'Checksum',                 Format => 'int16u' },
    2  => { Name => 'GPSDateTime',              %timeInfo },
    3  => { Name => 'MissionID',                Format => 'string' },
    4  => { Name => 'TailNumber',               Format => 'string' },
    5  => { Name => 'GPSTrack',                 Format => 'int16u', ValueConv => '$val * 360 / 0xffff' },
    6  => { Name => 'PitchAngle',               Format => 'int16s', ValueConv => '$val * 20 / 0x7fff' },
    7  => { Name => 'RollAngle',                Format => 'int16s', ValueConv => '$val * 50 / 0x7fff' },
    8  => { Name => 'TrueAirspeed',             Format => 'int8u',  PrintConv => '"$val m/s"' },
    9  => { Name => 'IndicatedAirspeed',        Format => 'int8u',  PrintConv => '"$val m/s"' },
    10 => { Name => 'ProjectIDCode',            Format => 'string' },
    11 => { Name => 'SensorName',               Format => 'string' },
    12 => { Name => 'ImageCoordinateSystem',    Format => 'string' },
    13 => { Name => 'GPSLatitude',              %latInfo },
    14 => { Name => 'GPSLongitude',             %lonInfo },
    15 => { Name => 'GPSAltitude',              %altInfo },
    16 => { Name => 'HorizontalFieldOfView',    Format => 'int16u', ValueConv => '$val * 180 / 0xffff' },
    17 => { Name => 'VerticalFieldOfView',      Format => 'int16u', ValueConv => '$val * 180 / 0xffff' },
    18 => { Name => 'SensorRelativeAzimuthAngle',Format=> 'int32u', ValueConv => '$val * 360 / 0xffffffff' },
    19 => { Name => 'SensorRelativeElevationAngle',Format=>'int32s',ValueConv => '$val * 180 / 0x7fffffff' },
    20 => { Name => 'SensorRelativeRollAngle',  Format => 'int32u', ValueConv => '$val * 360 / 0xffffffff' },
    21 => { Name => 'SlantRange',               Format => 'int32u', ValueConv => '$val * 5000000 / 0xffffffff' },
    22 => { Name => 'TargetWidth',              Format => 'int16u', ValueConv => '$val * 10000 / 0xffff' },
    23 => { Name => 'FrameCenterLatitude',      %latInfo },
    24 => { Name => 'FrameCenterLongitude',     %lonInfo },
    25 => { Name => 'FrameCenterElevation',     %altInfo },
    26 => { Name => 'OffsetCornerLatitude1',    Format => 'int16s', ValueConv => '$val * .075 / 0x7fff' },
    27 => { Name => 'OffsetCornerLongitude1',   Format => 'int16s', ValueConv => '$val * .075 / 0x7fff' },
    28 => { Name => 'OffsetCornerLatitude2',    Format => 'int16s', ValueConv => '$val * .075 / 0x7fff' },
    29 => { Name => 'OffsetCornerLongitude2',   Format => 'int16s', ValueConv => '$val * .075 / 0x7fff' },
    30 => { Name => 'OffsetCornerLatitude3',    Format => 'int16s', ValueConv => '$val * .075 / 0x7fff' },
    31 => { Name => 'OffsetCornerLongitude3',   Format => 'int16s', ValueConv => '$val * .075 / 0x7fff' },
    32 => { Name => 'OffsetCornerLatitude4',    Format => 'int16s', ValueConv => '$val * .075 / 0x7fff' },
    33 => { Name => 'OffsetCornerLongitude4',   Format => 'int16s', ValueConv => '$val * .075 / 0x7fff' },
    34 => { Name => 'IcingDetected',            Format => 'int8u',  PrintConv => { 0 => 'n/a', 1 => 'No', 2 => 'Yes' } },
    35 => { Name => 'WindDirection',            Format => 'int16u', ValueConv => '$val * 360 / 0xffff' },
    36 => { Name => 'WindSpeed',                Format => 'int8u',  ValueConv => '$val * 100 / 0xff', Notes => 'm/s' },
    37 => { Name => 'StaticPressure',           Format => 'int16u', ValueConv => '$val * 5000 / 0xffff', Notes => 'mbar' },
    38 => { Name => 'DensityAltitude',          Format => 'int16u', ValueConv => '$val * 19900 / 0xffff - 900' },
    39 => { Name => 'AirTemperature',           Format => 'int8s' },
    40 => { Name => 'TargetLocationLatitude',   %latInfo },
    41 => { Name => 'TargetLocationLongitude',  %lonInfo },
    42 => { Name => 'TargetLocationElevation',  %altInfo },
    43 => { Name => 'TargetTrackGateWidth',     Format => 'int8u' },
    44 => { Name => 'TargetTrackGateHeight',    Format => 'int8u' },
    45 => { Name => 'TargetErrorEstimateCE90',  Format => 'int16u' },
    46 => { Name => 'TargetErrorEstimateLE90',  Format => 'int16u' },
    47 => { Name => 'GenericFlagData01',
        Format => 'int8u',
        PrintConv => { BITMASK => {
            0 => 'Laser range',
            1 => 'Auto-track',
            2 => 'IR polarity black',
            3 => 'Icing detected',
            4 => 'Slant range measured',
            5 => 'Image invalid',
        }},
    },
    48 => { Name => 'SecurityLocalMetadataSet', SubDirectory => { TagTable => 'Image::ExifTool::MISB::Security' } },
    49 => { Name => 'DifferentialPressure',     Format => 'int16u', ValueConv => '$val * 5000 / 0xffff' },
    50 => { Name => 'AngleOfAttack',            Format => 'int16s', ValueConv => '$val * 20 / 0x7fff' },
    51 => { Name => 'VerticalSpeed',            Format => 'int16s', ValueConv => '$val * 180 / 0x7fff', Notes => 'm/s' },
    52 => { Name => 'SideslipAngle',            Format => 'int16s', ValueConv => '$val * 20 / 0x7fff' },
    53 => { Name => 'AirfieldBarometricPressure',Format=> 'int16u', ValueConv => '$val * 5000 / 0xffff' },
    54 => { Name => 'AirfieldElevation',        %altInfo },
    55 => { Name => 'RelativeHumidity',         Format => 'int8u',  ValueConv => '$val * 100 / 0xff' },
    56 => { Name => 'GPSSpeed',                 Format => 'int8u',  Notes => 'm/s' },
    57 => { Name => 'GroundRange',              Format => 'int32u', ValueConv => '$val * 5000000 / 0xffffffff' },
    58 => { Name => 'FuelRemaining',            Format => 'int16u', ValueConv => '$val * 10000 / 0xffff', Notes => 'kg' },
    59 => { Name => 'CallSign',                 Format => 'string' },
    60 => { Name => 'WeaponLoad',               Format => 'int16u', PrintConv => 'sprintf("0x%.4x",$val)' },
    61 => { Name => 'WeaponFired',              Format => 'int8u',  PrintConv => 'sprintf("0x%.2x",$val)' },
    62 => { Name => 'LaserPRFCode',             Format => 'int16u' },
    63 => { Name => 'SensorFieldOfViewName',    Format => 'int8u',
        PrintConv => {
            0 => 'Ultranarrow',
            1 => 'Narrow',
            2 => 'Medium',
            3 => 'Wide',
            4 => 'Ultrawide',
            5 => 'Narrow Medium',
            6 => '2x Ultranarrow',
            7 => '4x Ultranarrow',
        },
    },
    64 => { Name => 'MagneticHeading',          Format => 'int16u', ValueConv => '$val * 360 / 0xffff' },
    65 => { Name => 'UAS_LSVersionNumber',      Format => 'int8u' },
    66 => { Name => 'TargetLocationCovarianceMatrix', Format => 'undef', ValueConv => '\$val' },
    67 => { Name => 'AlternateLatitude',        %latInfo },
    68 => { Name => 'AlternateLongitude',       %lonInfo },
    69 => { Name => 'AlternateAltitude',        %altInfo },
    70 => { Name => 'AlternateName',            Format => 'string' },
    71 => { Name => 'AlternateHeading',         Format => 'int16u', ValueConv => '$val * 360 / 0xffff' },
    72 => { Name => 'EventStartTime',           %timeInfo },
    73 => { Name => 'RVTLocalSet',              SubDirectory => { TagTable => 'Image::ExifTool::MISB::Unknown' } },
    74 => { Name => 'VMTIDataSet',              SubDirectory => { TagTable => 'Image::ExifTool::MISB::Unknown' } },
    75 => { Name => 'SensorEllipsoidHeight',    %altInfo },
    76 => { Name => 'AlternateEllipsoidHeight', %altInfo },
    77 => { Name => 'OperationalMode',          Format => 'int8u',
        PrintConv => {
            0 => 'Other',
            1 => 'Operational',
            2 => 'Training',
            3 => 'Exercise',
            4 => 'Maintenance',
        },
    },
    78 => { Name => 'FrameCenterHeightAboveEllipsoid', %altInfo },
    79 => { Name => 'SensorVelocityNorth',      Format => 'int16s', ValueConv => '$val * 327 / 0x7fff' },
    80 => { Name => 'SensorVelocityEast',       Format => 'int16s', ValueConv => '$val * 327 / 0x7fff' },
    81 => { Name => 'ImageHorizonPixelPack',    Format => 'undef',  ValueConv => '\$val' },
    82 => { Name => 'CornerLatitude1',          %latInfo },
    83 => { Name => 'CornerLongitude1',         %lonInfo },
    84 => { Name => 'CornerLatitude2',          %latInfo },
    85 => { Name => 'CornerLongitude2',         %lonInfo },
    86 => { Name => 'CornerLatitude3',          %latInfo },
    87 => { Name => 'CornerLongitude3',         %lonInfo },
    88 => { Name => 'CornerLatitude4',          %latInfo },
    89 => { Name => 'CornerLongitude4',         %lonInfo },
    90 => { Name => 'FullPitchAngle',           Format => 'int32s', ValueConv => '$val * 90 / 0x7fffffff' },
    91 => { Name => 'FullRollAngle',            Format => 'int32s', ValueConv => '$val * 90 / 0x7fffffff' },
    92 => { Name => 'FullAngleOfAttack',        Format => 'int32s', ValueConv => '$val * 90 / 0x7fffffff' },
    93 => { Name => 'FullSideslipAngle',        Format => 'int32s', ValueConv => '$val * 90 / 0x7fffffff' },
    94 => { Name => 'MIISCoreIdentifier',       Format => 'undef',  ValueConv => '\$val' },
    95 => { Name => 'SARMotionImageryData',     SubDirectory => { TagTable => 'Image::ExifTool::MISB::Unknown' } },
    96 => { Name => 'TargetWidthExtended',      Format => 'undef',  ValueConv => '\$val' }, # IMAPB format
    97 => { Name => 'RangeImageLocalSet',       SubDirectory => { TagTable => 'Image::ExifTool::MISB::Unknown' } },
    98 => { Name => 'GeoregistrationLocalSet',  SubDirectory => { TagTable => 'Image::ExifTool::MISB::Unknown' } },
    99 => { Name => 'CompositeImagingLocalSet', SubDirectory => { TagTable => 'Image::ExifTool::MISB::Unknown' } },
    100=> { Name => 'SegmentLocalSet',          SubDirectory => { TagTable => 'Image::ExifTool::MISB::Unknown' } },
    101=> { Name => 'AmendLocalSet',            SubDirectory => { TagTable => 'Image::ExifTool::MISB::Unknown' } },
    102=> { Name => 'SDCC-FLP',                 Format => 'undef',  ValueConv => '\$val' }, # IMAPB format
    103=> { Name => 'DensityAltitudeExtended',  Format => 'undef',  ValueConv => '\$val' }, # IMAPB format
    104=> { Name => 'SensorEllipsoidHeightExtended', Format => 'undef',  ValueConv => '\$val' }, # IMAPB format
    105=> { Name => 'AlternateEllipsoidHeightExtended', Format => 'undef',  ValueConv => '\$val' }, # IMAPB format
);

# tags from MISB ST 0102.11 local set
%Image::ExifTool::MISB::Security = (
    GROUPS => { 0 => 'MISB', 1 => 'MISB', 2 => 'Document' },
    PROCESS_PROC => \&ProcessKLV,
    NOTES => 'Tags extracted from the MISB ST 0102.11 Security Metadata local set.',
    1  => { Name => 'SecurityClassification', PrintConv => {
        1 => 'Unclassified',
        2 => 'Restricted',
        3 => 'Confidential',
        4 => 'Secret',
        5 => 'Top Secret',
    }},
    2  => { Name => 'ClassifyingCountryCodeMethod', PrintConv => {
        0x01 => 'ISO-3166 Two Letter',
        0x02 => 'ISO-3166 Three Letter',
        0x03 => 'FIPS 10-4 Two Letter',
        0x04 => 'FIPS 10-4 Four Letter',
        0x05 => 'ISO-3166 Numeric',
        0x06 => '1059 Two Letter',
        0x07 => '1059 Three Letter',
        0x0a => 'FIPS 10-4 Mixed',
        0x0b => 'ISO 3166 Mixed',
        0x0c => 'STANAG 1059 Mixed',
        0x0d => 'GENC Two Letter',
        0x0e => 'GENC Three Letter',
        0x0f => 'GENC Numeric',
        0x10 => 'GENC Mixed',
    }},
    3  => { Name => 'ClassifyingCountry',   Format => 'string', PrintConv => '$val =~ s(^//)(); $val' },
    4  => 'SecuritySCI-SHIInformation',
    5  => { Name => 'Caveats',              Format => 'string' },
    6  => { Name => 'ReleasingInstructions',Format => 'string' },
    7  => { Name => 'ClassifiedBy',         Format => 'string' },
    8  => { Name => 'DerivedFrom',          Format => 'string' },
    9  => { Name => 'ClassificationReason', Format => 'string' },
    10 => {
        Name => 'DeclassificationDate',
        Format => 'string',
        Groups => { 2 => 'Time' },
        ValueConv => '$val =~ s/(\d{4})(\d{2})(\d{2})/$1:$2:$3/; $val',
    },
    11 => 'ClassificationAndMarkingSystem',
    12 => { Name => 'ObjectCountryCodingMethod', PrintConv => {
        0x01 => 'ISO-3166 Two Letter',
        0x02 => 'ISO-3166 Three Letter',
        0x03 => 'ISO-3166 Numeric',
        0x04 => 'FIPS 10-4 Two Letter',
        0x05 => 'FIPS 10-4 Four Letter',
        0x06 => '1059 Two Letter',
        0x07 => '1059 Three Letter',
        0x0d => 'GENC Two Letter',
        0x0e => 'GENC Three Letter',
        0x0f => 'GENC Numeric',
        0x40 => 'GENC AdminSub',
    }},
    13 => { Name => 'ObjectCountryCodes', Format => 'string', PrintConv => '$val =~ s(^//)(); $val' },
    14 => { Name => 'ClassificationComments', Format => 'string' },
    15 => 'UMID',
    16 => 'StreamID',
    17 => 'TransportStreamID',
    21 => 'ItemDesignatorID',
    22 => { Name => 'SecurityVersion', Format => 'int16u', PrintConv => '"0102.$val"' },
    23 => {
        Name => 'ClassifyingCountryCodingMethodDate',
        Groups => { 2 => 'Time' },
        Format => 'string',
        ValueConv => '$val=~tr/-/:/; $val',
    },
    24 => {
        Name => 'ObjectCountryCodingMethodDate',
        Groups => { 2 => 'Time' },
        Format => 'string',
        ValueConv => '$val=~tr/-/:/; $val',
    },
);

# I have seen these, but don't know what they are for - PH
# (they look interesting, but remain static through my sample video)
%Image::ExifTool::MISB::ChurchillNav = (
    GROUPS => { 0 => 'MISB', 1 => 'MISB', 2 => 'Other' },
    PROCESS_PROC => \&ProcessKLV,
    TAG_PREFIX => 'ChurchillNav',
    NOTES => q{
        Proprietary tags used by Churchill Navigation units.  These tags are all
        currently unknown, but extracted with the Unknown option.
    },
    # Note: tag ID's are decimal (because the MISB specification uses decimal ID's)
    1  => { Name => 'ChurchillNav_0x0001', Format => 'double', Unknown => 1, Hidden => 1 },
    2  => { Name => 'ChurchillNav_0x0002', Format => 'double', Unknown => 1, Hidden => 1 },
    3  => { Name => 'ChurchillNav_0x0003', Format => 'double', Unknown => 1, Hidden => 1 },
    4  => { Name => 'ChurchillNav_0x0004', Format => 'double', Unknown => 1, Hidden => 1 },
    5  => { Name => 'ChurchillNav_0x0005', Format => 'double', Unknown => 1, Hidden => 1 },
    6  => { Name => 'ChurchillNav_0x0006', Format => 'double', Unknown => 1, Hidden => 1 },
    9  => { Name => 'ChurchillNav_0x0009', Format => 'double', Unknown => 1, Hidden => 1 },
    10 => { Name => 'ChurchillNav_0x000a', Format => 'double', Unknown => 1, Hidden => 1 },
    11 => { Name => 'ChurchillNav_0x000b', Format => 'string', Unknown => 1, Hidden => 1 },
    12 => { Name => 'ChurchillNav_0x000c', Format => 'double', Unknown => 1, Hidden => 1 },
    13 => { Name => 'ChurchillNav_0x000d', Format => 'double', Unknown => 1, Hidden => 1 },
    14 => { Name => 'ChurchillNav_0x000e', Format => 'double', Unknown => 1, Hidden => 1 },
    16 => { Name => 'ChurchillNav_0x0010', Format => 'double', Unknown => 1, Hidden => 1 },
    17 => { Name => 'ChurchillNav_0x0011', Format => 'double', Unknown => 1, Hidden => 1 },
    18 => { Name => 'ChurchillNav_0x0012', Format => 'double', Unknown => 1, Hidden => 1 },
    20 => { Name => 'ChurchillNav_0x0014', Format => 'double', Unknown => 1, Hidden => 1 },
);

%Image::ExifTool::MISB::Unknown = (
    GROUPS => { 0 => 'MISB', 1 => 'MISB', 2 => 'Other' },
    PROCESS_PROC => \&ProcessKLV,
    NOTES => 'Other tags are extracted with the Unknown option.',
);

#------------------------------------------------------------------------------
# Process KLV (Key-Length-Value) metadata
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 if anything was extracted
sub ProcessKLV($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart};
    my $dirEnd = $dirStart + $$dirInfo{DirLen};
    my $rtnVal = 0;
    my $pos;

    $et->VerboseDir($$dirInfo{DirName}, undef, $$dirInfo{DirLen});

    # loop through KLV packets
    for ($pos=$dirStart; $pos<$dirEnd-1; ) {
        my $tag = Get8u($dataPt, $pos++);
        my $len = Get8u($dataPt, $pos++);
        if ($len & 0x80) {
            my $n = $len & 0x7f;
            last if $pos + $n > $dirEnd;
            $len = 0;
            $len = $len * 256 + Get8u($dataPt, $pos++) foreach 1..$n;
        }
        last if $pos + $len > $dirEnd;
        # best guess at decoding the value
        my $val;
        my $tagInfo = $$tagTablePtr{$tag} || { };
        my $format = $$tagInfo{Format} || $defaultFormat{$len};
        if ($format) {
            $val = ReadValue($dataPt, $pos, $format, undef, $len);
        } else {
            # treat as string or binary data
            $val = substr($$dataPt, $pos, $len);
            if ($val !~ /^[\t\n\r\x20-\x7e]*$/) {
                my $dat = $val;
                $val = \$val;
            }
        }
        $et->HandleTag($tagTablePtr, $tag, $val,
            DataPt => $dataPt,
            Start  => $pos,
            Size   => $len,
        );
        $rtnVal = 1;
        $pos += $len;
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Parse MISB metadata
# Inputs: 0) ExifTool ref, 1) data ref, 2) tag table ref
# Returns: 1 if something was extracted, 0 otherwise
sub ParseMISB($$$)
{
    my ($et, $dataPt, $tagTablePtr) = @_;
    my $end = length $$dataPt;
    my $rtnVal = 0;
    my $unknown = $$et{OPTIONS}{Unknown};
    my $verbose = $$et{OPTIONS}{Verbose};
    my $pos;

    # increment document number in case we find any tags
    $$et{DOC_NUM} = ++$$et{DOC_COUNT};
    $$et{INDENT} .= '| ';

    # skip the 5-byte header (ref 1 pg. 68)
    #   0 - int8u: metadata service ID (0x00)
    #   1 - int8u: sequence number (increments each packet)
    #   2 - int8u: 0x0f (bits: cell fragmentation 00, decoder config 0, random access 0, reserved 1111)
    #   3-4 - int16u: data length (ie. packet length - 5)
    for ($pos = 5; $pos + 16 < $end; ) {
        my $key = unpack('H*', substr($$dataPt, $pos, 16));
        $pos += 16;
        my $len = Get8u($dataPt, $pos);
        ++$pos;
        if ($len & 0x80) { # is this a BER long form integer? (Basic Encoding Rules)
            my $n = $len & 0x7f;
            $len = 0;
            return $rtnVal if $pos + $n > $end;
            $len = $len * 256 + Get8u($dataPt, $pos++) foreach 1..$n;
        }
        my $tagInfo = $$tagTablePtr{$key};
        unless ($tagInfo) {
            if  ($verbose or $unknown) {
                # (assume this is a data set, but it maybe be a simple tag)
                $tagInfo = { Name => "MISB_$key", SubDirectory => { TagTable => 'Image::ExifTool::MISB::Unknown' } };
                $et->VPrint(0,"  [adding $$tagInfo{Name}]\n");
                AddTagToTable($tagTablePtr, $key, $tagInfo);
            } else {
                # skip this record
                $pos += $len;
                next;
            }
        }
        if ($pos + $len > $end) {
            $len = $end - $pos;
            $et->VPrint(0, "$$et{INDENT}(truncated record, only $len bytes available)\n");
        }
        my $dir = $$tagInfo{SubDirectory};
        SetByteOrder($$dir{ByteOrder}) if $$dir{ByteOrder};
        my %dirInfo = (
            DataPt   => $dataPt,
            DirStart => $pos,
            DirLen   => $len,
            DirName  => $$tagInfo{Name},
        );
        ProcessKLV($et, \%dirInfo, GetTagTable($$dir{TagTable})) and $rtnVal = 1;
        SetByteOrder('MM');
        $pos += $len;
    }
    $$et{INDENT} = substr($$et{INDENT},0,-2);
    delete $$et{DOC_NUM};
    --$$et{DOC_COUNT} unless $rtnVal;
    return $rtnVal;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MISB - Read Motion Industry Standards Board metadata

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains code to extract STANAG-4609 Motion Industry Standards
Board (MISB) KLV-format metadata from M2TS videos.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://dokumen.tips/documents/nato-standardization-agreement-stanag-4609-ed-3.html>

=item L<https://upload.wikimedia.org/wikipedia/commons/1/19/MISB_Standard_0601.pdf>

=item L<https://dokumen.tips/documents/misb-st-010211-standard-security-metadata-universal-standard-describes-the-use.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MISB Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

