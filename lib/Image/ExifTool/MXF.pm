#------------------------------------------------------------------------------
# File:         MXF.pm
#
# Description:  Read MXF meta information
#
# Revisions:    2010/12/15 - P. Harvey Created
#
# References:   1) http://sourceforge.net/projects/mxflib/
#               2) http://www.aafassociation.org/downloads/whitepapers/MXFPhysicalview.pdf
#               3) http://archive.nlm.nih.gov/pubs/pearson/MJ2_Metadata2005.pdf
#               4) http://www.aafassociation.org/downloads/specifications/AMWA-AS-03-Delivery-Spec-1_0.pdf
#               5) http://paul-sampson.ca/private/s385m.pdf
#               6) http://avwiki.nl/documents/eg41.pdf
#               7) http://avwiki.nl/documents/eg42.pdf
#               8) http://rhea.tele.ucl.ac.be:8081/Plone/Members/egoray/thesaurus-dictionnaire-metadata/
#                   a) S335M Dictionary structure.pdf
#                   b) S330M  UMID.PDF
#               9) http://www.smpte-ra.org/mdd/RP210v12-publication-20100623.xls
#               10) http://www.amwa.tv/downloads/specifications/aafobjectspec-v1.1.pdf
#               11) http://www.mog-solutions.com/img_upload/PDF/XML%20Schema%20for%20MXF%20Metadata.pdf
#               12) http://www.freemxf.org/freemxf_board/viewtopic.php?p=545&sid=00a5c17e07d828c1e93ecdbaed3076f7
#
# Notes:     1) The alternate language support is dependent on the serialization
#               sequence.  Specifically the InstanceUID's must come before any
#               text in an alternate language set, and these sets must come
#               after the language definitions.
#
#            2) UTF-16 surrogate pairs are not handled properly.
#
#            3) This code is not tested for files larger than 2 GB,
#               but in theory this should be OK with 64-bit Perl.
#------------------------------------------------------------------------------

package Image::ExifTool::MXF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::GPS;

$VERSION = '1.08';

sub ProcessPrimer($$$);
sub ProcessLocalSet($$$);
sub ConvLatLon($);
sub ReadMXFValue($$$);
sub SetGroups($$;$$);
sub ConvertDurations($$);

# list of currently decoded MXF value types
my %knownType = (
    Alt => 1,       Lon => 1,                   UL => 1,
    AUID => 1,      PackageID => 1,             UMID => 1,
    BatchOfUL => 1, Position => 1,             'UTF-16' => 1,
    Boolean => 1,   ProductVersion => 1,        UUID => 1,
    GUID => 1,      StrongReference => 1,       VersionType => 1,
    Hex => 1,       StrongReferenceArray => 1,  WeakReference => 1,
    Label => 1,     StrongReferenceBatch => 1,
    Lat => 1,       Timestamp => 1,
    Length => 1,    UID => 1,
);

# common tag info parameters
my %header = (
    IsHeader => 1,
    SubDirectory => {
        TagTable => 'Image::ExifTool::MXF::Header',
        ProcessProc => \&Image::ExifTool::ProcessBinaryData,
    },
);
my %localSet = (
    SubDirectory => { TagTable => 'Image::ExifTool::MXF::Main' },
);
my %timestamp = (
    Type => 'Timestamp',
    Groups => { 2 => 'Time' },
    PrintConv => '$self->ConvertDateTime($val)',
);
my %geoLat = (
    Groups => { 2 => 'Location' },
    PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
);
my %geoLon = (
    Groups => { 2 => 'Location' },
    PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
);
my %geoLatLon = (
    Groups => { 2 => 'Location' },
    PrintConv => q{
        my ($lat, $lon) = split ' ', $val;
        $lat = Image::ExifTool::GPS::ToDMS($self, $lat, 1, 'N');
        $lon = Image::ExifTool::GPS::ToDMS($self, $lon, 1, 'E');
        return "$lat, $lon";
    },
);
my %duration = (
    IsDuration => 1,  # flag used to correct durations by the appropriate EditRate
    RawConv    => '$val > 1e18 ? undef : $val', # (all 0xff's)
    PrintConv  => 'ConvertDuration($val)',
);

# ComponentDataDefinition values
my %componentDataDef = (
    PrintConv => {
        '060e2b34.0401.0101.01030201.01000000' => 'SMPTE 12M Timecode Track',
        '060e2b34.0401.0101.01030201.02000000' => 'SMPTE 12M Timecode Track with active user bits',
        '060e2b34.0401.0101.01030201.03000000' => 'SMPTE 309M Timecode Track',
        '060e2b34.0401.0101.01030201.10000000' => 'Descriptive Metadata Track',
        '060e2b34.0401.0101.01030202.01000000' => 'Picture Essence Track',
        '060e2b34.0401.0101.01030202.02000000' => 'Sound Essence Track',
        '060e2b34.0401.0101.01030202.03000000' => 'Data Essence Track',
    },
);

# MXF tags (ref 1)
# Note: The Binary flag is automatically set for all Unknown tags with unknown Type
%Image::ExifTool::MXF::Main = (
    GROUPS => { 2 => 'Video' },
    VARS => { NO_LOOKUP => 1, NO_ID => 1 }, # tag ID's are too bulky
    NOTES => q{
        Tags extracted from Material Exchange Format files.  Tag ID's are not listed
        because they are bulky 16-byte binary values.
    },
  # '060a2b34.0101.0101.01010100.00000000' => { Name => 'UMIDVideo', Type => 'Node' },
  # '060a2b34.0101.0101.01010110.00000000' => { Name => 'UMIDVideo', Unknown => 1 },
  # '060a2b34.0101.0101.01010111.00000000' => { Name => 'UMIDVideo', Unknown => 1 },
  # '060a2b34.0101.0101.01010112.00000000' => { Name => 'UMIDVideo', Unknown => 1 },
  # '060a2b34.0101.0101.01010120.00000000' => { Name => 'UMIDVideo', Unknown => 1 },
  # '060a2b34.0101.0101.01010121.00000000' => { Name => 'UMIDVideo', Unknown => 1 },
  # '060a2b34.0101.0101.01010122.00000000' => { Name => 'UMIDVideo', Unknown => 1 },
  # '060a2b34.0101.0101.01010200.00000000' => { Name => 'UMIDAudio', Type => 'Node' },
  # '060a2b34.0101.0101.01010210.00000000' => { Name => 'UMIDAudio', Unknown => 1 },
  # '060a2b34.0101.0101.01010211.00000000' => { Name => 'UMIDAudio', Unknown => 1 },
  # '060a2b34.0101.0101.01010212.00000000' => { Name => 'UMIDAudio', Unknown => 1 },
  # '060a2b34.0101.0101.01010220.00000000' => { Name => 'UMIDAudio', Unknown => 1 },
  # '060a2b34.0101.0101.01010221.00000000' => { Name => 'UMIDAudio', Unknown => 1 },
  # '060a2b34.0101.0101.01010222.00000000' => { Name => 'UMIDAudio', Unknown => 1 },
  # '060a2b34.0101.0101.01010300.00000000' => { Name => 'UMIDData', Type => 'Node' },
  # '060a2b34.0101.0101.01010310.00000000' => { Name => 'UMIDData', Unknown => 1 },
  # '060a2b34.0101.0101.01010311.00000000' => { Name => 'UMIDData', Unknown => 1 },
  # '060a2b34.0101.0101.01010312.00000000' => { Name => 'UMIDData', Unknown => 1 },
  # '060a2b34.0101.0101.01010320.00000000' => { Name => 'UMIDData', Unknown => 1 },
  # '060a2b34.0101.0101.01010321.00000000' => { Name => 'UMIDData', Unknown => 1 },
  # '060a2b34.0101.0101.01010322.00000000' => { Name => 'UMIDData', Unknown => 1 },
  # '060a2b34.0101.0101.01010400.00000000' => { Name => 'UMIDSystem', Type => 'Node' },
  # '060a2b34.0101.0101.01010410.00000000' => { Name => 'UMIDSystem', Unknown => 1 },
  # '060a2b34.0101.0101.01010411.00000000' => { Name => 'UMIDSystem', Unknown => 1 },
  # '060a2b34.0101.0101.01010412.00000000' => { Name => 'UMIDSystem', Unknown => 1 },
  # '060a2b34.0101.0101.01010420.00000000' => { Name => 'UMIDSystem', Unknown => 1 },
  # '060a2b34.0101.0101.01010421.00000000' => { Name => 'UMIDSystem', Unknown => 1 },
  # '060a2b34.0101.0101.01010422.00000000' => { Name => 'UMIDSystem', Unknown => 1 },

  # '060e2b34.0101.0101.00000000.00000000' => { Name => 'Elements', Type => 'Node' },
  # '060e2b34.0101.0101.01000000.00000000' => { Name => 'Identifiers', Type => 'Node' },
  # '060e2b34.0101.0101.01010000.00000000' => { Name => 'GloballyUniqueIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0101.01011000.00000000' => { Name => 'InternationalBroadcastingOrganizationIdentifiers', Type => 'Node' },
    '060e2b34.0101.0101.01011001.00000000' => { Name => 'OrganizationID', Format => 'string' },
  # '060e2b34.0101.0101.01011003.00000000' => { Name => 'ProgramIdentifiers', Type => 'Node' },
    '060e2b34.0101.0101.01011003.01000000' => { Name => 'UPID', Unknown => 1 },
    '060e2b34.0101.0101.01011003.02000000' => { Name => 'UPN', Unknown => 1 },
  # '060e2b34.0101.0101.01011004.00000000' => { Name => 'PhysicalMediaIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0101.01011004.01000000' => { Name => 'TapeIdentifiers', Type => 'Node' },
    '060e2b34.0101.0101.01011004.01010000' => { Name => 'IBTN', Unknown => 1 },
  # '060e2b34.0101.0101.01011100.00000000' => { Name => 'InternationalStandardIdentifiers', Type => 'Node' },
    '060e2b34.0101.0101.01011101.00000000' => { Name => 'ISAN', Unknown => 1 },
    '060e2b34.0101.0101.01011102.00000000' => { Name => 'ISBN', Unknown => 1 },
    '060e2b34.0101.0101.01011103.00000000' => { Name => 'ISSN', Unknown => 1 },
    '060e2b34.0101.0101.01011104.00000000' => { Name => 'ISWC', Unknown => 1 },
    '060e2b34.0101.0101.01011105.00000000' => { Name => 'ISMN', Unknown => 1 },
    '060e2b34.0101.0101.01011106.00000000' => { Name => 'ISCI', Unknown => 1 },
    '060e2b34.0101.0101.01011107.00000000' => { Name => 'ISRC', Unknown => 1 },
    '060e2b34.0101.0101.01011108.00000000' => { Name => 'ISRN', Unknown => 1 },
    '060e2b34.0101.0101.01011109.00000000' => { Name => 'ISBD', Unknown => 1 },
    '060e2b34.0101.0101.0101110a.00000000' => { Name => 'ISTC', Unknown => 1 },
  # '060e2b34.0101.0101.01011300.00000000' => { Name => 'InternationalStandardCompoundIdentifiers', Type => 'Node' },
    '060e2b34.0101.0101.01011301.00000000' => { Name => 'SICI', Unknown => 1 },
    '060e2b34.0101.0101.01011302.00000000' => { Name => 'BICI', Unknown => 1 },
    '060e2b34.0101.0101.01011303.00000000' => { Name => 'AICI', Unknown => 1 },
    '060e2b34.0101.0101.01011304.00000000' => { Name => 'PII', Unknown => 1 },
  # '060e2b34.0101.0101.01011500.00000000' => { Name => 'ObjectIdentifiers', Type => 'Node' },
    '060e2b34.0101.0101.01011501.00000000' => { Name => 'DOI', Unknown => 1 },
    '060e2b34.0101.0101.01011502.00000000' => { Name => 'InstanceUID', Type => 'GUID', Unknown => 1 },
    '060e2b34.0101.0101.01011510.00000000' => { Name => 'PackageID', Type => 'PackageID', Unknown => 1 },
  # '060e2b34.0101.0101.01012000.00000000' => { Name => 'DeviceIdentifiers', Type => 'Node' },
    '060e2b34.0101.0101.01012001.00000000' => { Name => 'DeviceDesignation', Format => 'string' },
    '060e2b34.0101.0101.01012003.00000000' => { Name => 'DeviceModel', Format => 'string' },
    '060e2b34.0101.0101.01012004.00000000' => { Name => 'DeviceSerialNumber', Format => 'string' },
  # '060e2b34.0101.0101.01020000.00000000' => { Name => 'GloballyUniqueLocators', Type => 'Node' },
  # '060e2b34.0101.0101.01020100.00000000' => { Name => 'UniformResourceLocators', Type => 'Node' },
    '060e2b34.0101.0101.01020101.00000000' => { Name => 'URL', Format => 'string' },
    '060e2b34.0101.0101.01020101.01000000' => { Name => 'URL', Type => 'UTF-16' },
    '060e2b34.0101.0101.01020102.00000000' => { Name => 'PURL', Format => 'string' },
    '060e2b34.0101.0101.01020103.00000000' => { Name => 'URN', Format => 'string' },
  # '060e2b34.0101.0101.01030000.00000000' => { Name => 'LocallyUniqueIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0101.01030100.00000000' => { Name => 'AdministrativeIdentifiers', Type => 'Node' },
    '060e2b34.0101.0101.01030101.00000000' => { Name => 'TransmissionID', Format => 'string' },
    '060e2b34.0101.0101.01030102.00000000' => { Name => 'ArchiveID', Format => 'string' },
    '060e2b34.0101.0101.01030103.00000000' => { Name => 'ItemID', Format => 'string' },
    '060e2b34.0101.0101.01030104.00000000' => { Name => 'AccountingReferenceNumber', Format => 'string' },
    '060e2b34.0101.0101.01030105.00000000' => { Name => 'TrafficID', Format => 'string' },
  # '060e2b34.0101.0101.01030200.00000000' => { Name => 'LocalPhysicalMediaIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0101.01030201.00000000' => { Name => 'LocalFilmID', Type => 'Node' },
    '060e2b34.0101.0101.01030201.01000000' => { Name => 'ReelOrRollNumber', Format => 'string' },
  # '060e2b34.0101.0101.01030202.00000000' => { Name => 'LocalTapeIdentifiers', Type => 'Node' },
    '060e2b34.0101.0101.01030202.01000000' => { Name => 'LocalTapeNumber', Format => 'string' },
  # '060e2b34.0101.0101.01030300.00000000' => { Name => 'LocalObjectIdentifiers', Type => 'Node' },
    '060e2b34.0101.0101.01030301.00000000' => { Name => 'LUID', Format => 'int32u' },
    '060e2b34.0101.0101.01030302.01000000' => { Name => 'PackageName', Type => 'UTF-16' },
  # '060e2b34.0101.0101.01040000.00000000' => { Name => 'LocallyUniqueLocators', Type => 'Node' },
  # '060e2b34.0101.0101.01040100.00000000' => { Name => 'MediaLocators', Type => 'Node' },
    '060e2b34.0101.0101.01040101.00000000' => { Name => 'LocalFilePath', Format => 'string' },
  # '060e2b34.0101.0101.01040700.00000000' => { Name => 'FilmLocators', Type => 'Node' },
    '060e2b34.0101.0101.01040701.00000000' => { Name => 'EdgeCode', Format => 'string' },
    '060e2b34.0101.0101.01040702.00000000' => { Name => 'FrameCode', Format => 'string' },
    '060e2b34.0101.0101.01040703.00000000' => { Name => 'KeyCode', Type => 'KeyCode', Unknown => 1 },
    '060e2b34.0101.0101.01040704.00000000' => { Name => 'InkNumber', Format => 'string' },
  # '060e2b34.0101.0101.01041000.00000000' => { Name => 'ProxyLocators', Type => 'Node' },
    '060e2b34.0101.0101.01041001.00000000' => { Name => 'KeyText', Format => 'string' },
    '060e2b34.0101.0101.01041002.00000000' => { Name => 'KeyFrame', Format => 'string' },
    '060e2b34.0101.0101.01041003.00000000' => { Name => 'KeySound', Format => 'string' },
    '060e2b34.0101.0101.01041004.00000000' => { Name => 'KeyDataOrProgram', Format => 'string' },
  # '060e2b34.0101.0101.01050000.00000000' => { Name => 'Titles', Type => 'Node' },
    '060e2b34.0101.0101.01050100.00000000' => { Name => 'TitleKind', Format => 'string' },
    '060e2b34.0101.0101.01050200.00000000' => { Name => 'MainTitle', Format => 'string' },
    '060e2b34.0101.0101.01050300.00000000' => { Name => 'SecondaryTitle', Format => 'string' },
    '060e2b34.0101.0101.01050400.00000000' => { Name => 'SeriesNumber', Format => 'string' },
    '060e2b34.0101.0101.01050500.00000000' => { Name => 'EpisodeNumber', Format => 'string' },
    '060e2b34.0101.0101.01050600.00000000' => { Name => 'SceneNumber', Format => 'string' },
    '060e2b34.0101.0101.01050700.00000000' => { Name => 'TakeNumber', Format => 'int16u' },
  # '060e2b34.0101.0101.01100000.00000000' => { Name => 'IntellectualPropertyRightsIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0101.01100100.00000000' => { Name => 'SUISACISACIPI', Type => 'Node' },
    '060e2b34.0101.0101.01100101.00000000' => { Name => 'CISACLegalEntityID', Unknown => 1 },
  # '060e2b34.0101.0101.01100200.00000000' => { Name => 'AGICOAIdentifers', Type => 'Node' },
    '060e2b34.0101.0101.01100201.00000000' => { Name => 'AGICOAID', Unknown => 1 },
  # '060e2b34.0101.0101.02000000.00000000' => { Name => 'ADMINISTRATION', Type => 'Node' },
  # '060e2b34.0101.0101.02010000.00000000' => { Name => 'Supplier', Type => 'Node' },
    '060e2b34.0101.0101.02010100.00000000' => { Name => 'SourceOrganization', Format => 'string' },
    '060e2b34.0101.0101.02010200.00000000' => { Name => 'SupplyContractNumber', Format => 'string' },
    '060e2b34.0101.0101.02010300.00000000' => { Name => 'OriginalProducerName', Format => 'string' },
  # '060e2b34.0101.0101.02020000.00000000' => { Name => 'Product', Type => 'Node' },
    '060e2b34.0101.0101.02020100.00000000' => { Name => 'TotalEpisodeCount', Format => 'int16u' },
  # '060e2b34.0101.0101.02050000.00000000' => { Name => 'Rights', Type => 'Node' },
  # '060e2b34.0101.0101.02050100.00000000' => { Name => 'Copyright', Type => 'Node' },
    '060e2b34.0101.0101.02050101.00000000' => { Name => 'CopyrightStatus', Format => 'string' },
    '060e2b34.0101.0101.02050102.00000000' => { Name => 'CopyrightOwnerName', Format => 'string' },
  # '060e2b34.0101.0101.02050200.00000000' => { Name => 'IntellectualRights', Type => 'Node' },
    '060e2b34.0101.0101.02050201.00000000' => { Name => 'IntellectualPropertyDescription', Format => 'string' },
    '060e2b34.0101.0101.02050202.00000000' => { Name => 'IntellectualPropertyRights', Format => 'string' },
  # '060e2b34.0101.0101.02050300.00000000' => { Name => 'LegalPersonalities', Type => 'Node' },
    '060e2b34.0101.0101.02050301.00000000' => { Name => 'Rightsholder', Format => 'string' },
    '060e2b34.0101.0101.02050302.00000000' => { Name => 'RightsManagementAuthority', Format => 'string' },
    '060e2b34.0101.0101.02050303.00000000' => { Name => 'InterestedPartyName', Format => 'string' },
  # '060e2b34.0101.0101.02050400.00000000' => { Name => 'IntellectualPropertyRightsOptions', Type => 'Node' },
    '060e2b34.0101.0101.02050401.00000000' => { Name => 'MaximumUseCount', Format => 'int16u' },
    '060e2b34.0101.0101.02050402.00000000' => { Name => 'LicenseOptionsDescription', Format => 'string' },
  # '060e2b34.0101.0101.02060000.00000000' => { Name => 'FinancialInformation', Type => 'Node' },
  # '060e2b34.0101.0101.02060100.00000000' => { Name => 'Currencies', Type => 'Node' },
    '060e2b34.0101.0101.02060101.00000000' => { Name => 'CurrencyCode', Format => 'string' },
  # '060e2b34.0101.0101.02060200.00000000' => { Name => 'PaymentsAndCosts', Type => 'Node' },
    '060e2b34.0101.0101.02060201.00000000' => { Name => 'RoyaltyPaymentInformation', Format => 'string' },
  # '060e2b34.0101.0101.02060300.00000000' => { Name => 'Income', Type => 'Node' },
    '060e2b34.0101.0101.02060301.00000000' => { Name => 'RoyaltyIncomeInformation', Format => 'string' },
  # '060e2b34.0101.0101.02070000.00000000' => { Name => 'AccessControl', Type => 'Node' },
    '060e2b34.0101.0101.02070100.00000000' => { Name => 'RestrictionsonUse', Format => 'string' },
    '060e2b34.0101.0101.02070200.00000000' => { Name => 'ExCCIData', Type => 'DataBlock', Unknown => 1 },
  # '060e2b34.0101.0101.02080000.00000000' => { Name => 'Security', Type => 'Node' },
  # '060e2b34.0101.0101.02080100.00000000' => { Name => 'SystemAccess', Type => 'Node' },
    '060e2b34.0101.0101.02080101.00000000' => { Name => 'UserName', Format => 'string' },
    '060e2b34.0101.0101.02080101.01000000' => { Name => 'UserName', Type => 'UTF-16' },
    '060e2b34.0101.0101.02080102.00000000' => { Name => 'Password', Format => 'string' },
    '060e2b34.0101.0101.02080102.01000000' => { Name => 'Password', Type => 'UTF-16' },
  # '060e2b34.0101.0101.02090000.00000000' => { Name => 'Encryption', Type => 'Node' },
  # '060e2b34.0101.0101.02090100.00000000' => { Name => 'FilmEncryption', Type => 'Node' },
  # '060e2b34.0101.0101.02090101.00000000' => { Name => 'ScramblingKeys', Type => 'Node' },
    '060e2b34.0101.0101.02090101.01000000' => { Name => 'ScramblingKeyKind', Format => 'string' },
    '060e2b34.0101.0101.02090101.02000000' => { Name => 'ScramblingKeyValue', Format => 'int8u' },
  # '060e2b34.0101.0101.02100000.00000000' => { Name => 'PublicationOutlet', Type => 'Node' },
  # '060e2b34.0101.0101.02100100.00000000' => { Name => 'Broadcast', Type => 'Node' },
  # '060e2b34.0101.0101.02100101.00000000' => { Name => 'Broadcaster', Type => 'Node' },
    '060e2b34.0101.0101.02100101.01000000' => { Name => 'BroadcastOrganizationName', Format => 'string' },
    '060e2b34.0101.0101.02100101.02000000' => { Name => 'BroadcastChannel', Format => 'string' },
    '060e2b34.0101.0101.02100101.03000000' => { Name => 'BroadcastMediumKind', Format => 'string' },
    '060e2b34.0101.0101.02100101.05000000' => { Name => 'BroadcastRegion', Format => 'string' },
  # '060e2b34.0101.0101.02200000.00000000' => { Name => 'BroadcastAndRepeatInformation', Type => 'Node' },
  # '060e2b34.0101.0101.02200100.00000000' => { Name => 'BroadcastFlags', Type => 'Node' },
    '060e2b34.0101.0101.02200101.00000000' => { Name => 'FirstBroadcastFlag', Type => 'Boolean' },
  # '060e2b34.0101.0101.02200200.00000000' => { Name => 'RepeatNumbers', Type => 'Node' },
    '060e2b34.0101.0101.02200201.00000000' => { Name => 'CurrentRepeatNumber', Format => 'int16u' },
    '060e2b34.0101.0101.02200202.00000000' => { Name => 'PreviousRepeatNumber', Format => 'int16u' },
  # '060e2b34.0101.0101.02200300.00000000' => { Name => 'Ratings', Type => 'Node' },
    '060e2b34.0101.0101.02200301.00000000' => { Name => 'AudienceRating', Format => 'int32u' },
    '060e2b34.0101.0101.02200302.00000000' => { Name => 'AudienceReach', Format => 'int32u' },
  # '060e2b34.0101.0101.02300000.00000000' => { Name => 'ParticipatingParties', Type => 'Node' },
  # '060e2b34.0101.0101.02300100.00000000' => { Name => 'IndividualsAndGroups', Type => 'Node' },
    '060e2b34.0101.0101.02300101.00000000' => { Name => 'NatureOfPersonality', Format => 'string' },
  # '060e2b34.0101.0101.02300102.00000000' => { Name => 'Production', Type => 'Node' },
    '060e2b34.0101.0101.02300102.01000000' => { Name => 'ContributionStatus', Format => 'string' },
  # '060e2b34.0101.0101.02300103.00000000' => { Name => 'SupportAndAdministrationDetails', Type => 'Node' },
    '060e2b34.0101.0101.02300103.01000000' => { Name => 'SupportOrAdministrationStatus', Format => 'string' },
  # '060e2b34.0101.0101.02300200.00000000' => { Name => 'OrganizationsAndPublicBodies', Type => 'Node' },
    '060e2b34.0101.0101.02300201.00000000' => { Name => 'OrganizationKind', Format => 'string' },
  # '060e2b34.0101.0101.02300202.00000000' => { Name => 'ProductionOrganizationOrPublicBody', Type => 'Node' },
    '060e2b34.0101.0101.02300202.01000000' => { Name => 'ProductionOrganizationRole', Format => 'string' },
  # '060e2b34.0101.0101.02300203.00000000' => { Name => 'SupportAndAdministrationOrganizationOrPublicBody', Type => 'Node' },
    '060e2b34.0101.0101.02300203.01000000' => { Name => 'SupportOrganizationRole', Format => 'string' },
  # '060e2b34.0101.0101.02300500.00000000' => { Name => 'JobFunctionInformation', Type => 'Node' },
    '060e2b34.0101.0101.02300501.00000000' => { Name => 'JobFunctionName', Format => 'string' },
    '060e2b34.0101.0101.02300502.00000000' => { Name => 'RoleName', Format => 'string' },
  # '060e2b34.0101.0101.02300600.00000000' => { Name => 'ContactInformation', Type => 'Node' },
    '060e2b34.0101.0101.02300601.00000000' => { Name => 'ContactKind', Format => 'string' },
    '060e2b34.0101.0101.02300602.00000000' => { Name => 'ContactDepartmentName', Format => 'string' },
  # '060e2b34.0101.0101.02300603.00000000' => { Name => 'PersonOrOrganizationDetails', Type => 'Node' },
  # '060e2b34.0101.0101.02300603.01000000' => { Name => 'PersonNames', Type => 'Node' },
    '060e2b34.0101.0101.02300603.01010000' => { Name => 'FamilyName', Format => 'string' },
    '060e2b34.0101.0101.02300603.01020000' => { Name => 'FirstGivenName', Format => 'string' },
    '060e2b34.0101.0101.02300603.01030000' => { Name => 'SecondGivenName', Format => 'string' },
    '060e2b34.0101.0101.02300603.01040000' => { Name => 'ThirdGivenName', Format => 'string' },
  # '060e2b34.0101.0101.02300603.02000000' => { Name => 'GroupNames', Type => 'Node' },
    '060e2b34.0101.0101.02300603.02010000' => { Name => 'MainName', Format => 'string' },
    '060e2b34.0101.0101.02300603.02020000' => { Name => 'SupplementaryName', Format => 'string' },
  # '060e2b34.0101.0101.02300603.03000000' => { Name => 'OrganizationNames', Type => 'Node' },
    '060e2b34.0101.0101.02300603.03010000' => { Name => 'OrganizationMainName', Format => 'string' },
    '060e2b34.0101.0101.02300603.03020000' => { Name => 'SupplementaryOrganizationName', Format => 'string' },
  # '060e2b34.0101.0101.03000000.00000000' => { Name => 'Interpretive', Type => 'Node' },
  # '060e2b34.0101.0101.03010000.00000000' => { Name => 'Fundamental', Type => 'Node' },
  # '060e2b34.0101.0101.03010100.00000000' => { Name => 'CountriesAndLanguages', Type => 'Node' },
  # '060e2b34.0101.0101.03010101.00000000' => { Name => 'CountryAndRegionCodes', Type => 'Node' },
    '060e2b34.0101.0101.03010101.01000000' => { Name => 'ISO3166CountryCode', Format => 'string' },
  # '060e2b34.0101.0101.03010102.00000000' => { Name => 'LanguageCodes', Type => 'Node' },
    '060e2b34.0101.0101.03010102.01000000' => { Name => 'ISO639-1LanguageCode', Format => 'string' },
  # '060e2b34.0101.0101.03010201.00000000' => { Name => 'SystemInterpretations', Type => 'Node' },
    '060e2b34.0101.0101.03010201.01000000' => { Name => 'OperatingSystemInterpretations', Format => 'int8u' },
    '060e2b34.0101.0101.03010201.02000000' => {
        Name => 'ByteOrder', #PH (was int16s, but I have seen "II")
        Format => 'string',
        PrintConv => {
            II => 'Little-endian (Intel, II)',
            MM => 'Big-endian (Motorola, MM)',
        },
    },
    '060e2b34.0101.0101.03010201.03000000' => { Name => 'EssenceIsIdentified', Type => 'Boolean' },
  # '060e2b34.0101.0101.03010300.00000000' => { Name => 'FundamentalDimensions', Type => 'Node' },
  # '060e2b34.0101.0101.03010301.00000000' => { Name => 'Length', Type => 'Node' },
    '060e2b34.0101.0101.03010301.01000000' => { Name => 'LengthSystemName', Format => 'string' },
    '060e2b34.0101.0101.03010301.02000000' => { Name => 'LengthUnitKind', Format => 'string' },
  # '060e2b34.0101.0101.03010302.00000000' => { Name => 'Angles', Type => 'Node' },
    '060e2b34.0101.0101.03010302.01000000' => { Name => 'AngularUnitKind', Format => 'string' },
  # '060e2b34.0101.0101.03010303.00000000' => { Name => 'Time', Type => 'Node' },
    '060e2b34.0101.0101.03010303.01000000' => { Name => 'TimeSystemOffset', Format => 'string' },
    '060e2b34.0101.0101.03010303.02000000' => { Name => 'TimeUnitKind', Format => 'string' },
  # '060e2b34.0101.0101.03010304.00000000' => { Name => 'Mass', Type => 'Node' },
  # '060e2b34.0101.0101.03010305.00000000' => { Name => 'Energy', Type => 'Node' },
  # '060e2b34.0101.0101.03020000.00000000' => { Name => 'HumanAssignedDescriptors', Type => 'Node' },
  # '060e2b34.0101.0101.03020100.00000000' => { Name => 'Categorization', Type => 'Node' },
  # '060e2b34.0101.0101.03020101.00000000' => { Name => 'ContentClassification', Type => 'Node' },
    '060e2b34.0101.0101.03020101.01000000' => { Name => 'ContentCodingSystem', Format => 'string' },
    '060e2b34.0101.0101.03020101.02000000' => { Name => 'ProgramKind', Format => 'string' },
    '060e2b34.0101.0101.03020101.03000000' => { Name => 'Genre', Format => 'string' },
    '060e2b34.0101.0101.03020101.04000000' => { Name => 'TargetAudience', Format => 'string' },
  # '060e2b34.0101.0101.03020102.00000000' => { Name => 'CatalogingAndIndexing', Type => 'Node' },
    '060e2b34.0101.0101.03020102.01000000' => { Name => 'CatalogDataStatus', Format => 'string' },
    '060e2b34.0101.0101.03020102.02000000' => { Name => 'ThesaurusName', Format => 'string' },
    '060e2b34.0101.0101.03020102.03000000' => { Name => 'Theme', Format => 'string' },
    '060e2b34.0101.0101.03020102.04000000' => { Name => 'ContentClassification', Format => 'string' },
    '060e2b34.0101.0101.03020102.05000000' => { Name => 'Keywords', Format => 'string' },
    '060e2b34.0101.0101.03020102.06000000' => { Name => 'KeyFrames', Format => 'string' },
    '060e2b34.0101.0101.03020102.07000000' => { Name => 'KeySounds', Format => 'string' },
    '060e2b34.0101.0101.03020102.08000000' => { Name => 'KeyData', Format => 'string' },
  # '060e2b34.0101.0101.03020106.00000000' => { Name => 'TextualDescription', Type => 'Node' },
    '060e2b34.0101.0101.03020106.01000000' => { Name => 'Abstract', Format => 'string' },
    '060e2b34.0101.0101.03020106.02000000' => { Name => 'Purpose', Format => 'string' },
    '060e2b34.0101.0101.03020106.03000000' => { Name => 'Description', Format => 'string' },
    '060e2b34.0101.0101.03020106.04000000' => { Name => 'ColorDescriptor', Format => 'string' },
    '060e2b34.0101.0101.03020106.05000000' => { Name => 'FormatDescriptor', Format => 'string' },
  # '060e2b34.0101.0101.03020107.00000000' => { Name => 'Stratum', Type => 'Node' },
    '060e2b34.0101.0101.03020107.01000000' => { Name => 'StratumKind', Format => 'string' },
  # '060e2b34.0101.0101.03020200.00000000' => { Name => 'Assessments', Type => 'Node' },
  # '060e2b34.0101.0101.03020201.00000000' => { Name => 'Awards', Type => 'Node' },
    '060e2b34.0101.0101.03020201.01000000' => { Name => 'IndividualAwardName', Format => 'string' },
    '060e2b34.0101.0101.03020201.02000000' => { Name => 'ProgramAwardName', Format => 'string' },
  # '060e2b34.0101.0101.03020202.00000000' => { Name => 'QualitativeValues', Type => 'Node' },
    '060e2b34.0101.0101.03020202.01000000' => { Name => 'AssetValue', Format => 'string' },
    '060e2b34.0101.0101.03020202.02000000' => { Name => 'ContentValue', Format => 'string' },
    '060e2b34.0101.0101.03020202.03000000' => { Name => 'CulturalValue', Format => 'string' },
    '060e2b34.0101.0101.03020202.04000000' => { Name => 'AestheticValue', Format => 'string' },
    '060e2b34.0101.0101.03020202.05000000' => { Name => 'HistoricalValue', Format => 'string' },
    '060e2b34.0101.0101.03020202.06000000' => { Name => 'TechnicalValue', Format => 'string' },
    '060e2b34.0101.0101.03020202.07000000' => { Name => 'OtherValues', Format => 'string' },
  # '060e2b34.0101.0101.03020300.00000000' => { Name => 'TechnicalCommentsAndDescriptions', Type => 'Node' },
  # '060e2b34.0101.0101.03020301.00000000' => { Name => 'ObjectCommentsAndDescriptions', Type => 'Node' },
  # '060e2b34.0101.0101.03030000.00000000' => { Name => 'Machine-AssignedOrComputedDescriptions', Type => 'Node' },
  # '060e2b34.0101.0101.03030100.00000000' => { Name => 'AutomatedCategorization', Type => 'Node' },
  # '060e2b34.0101.0101.03030101.00000000' => { Name => 'AutomatedContentClassification', Type => 'Node' },
  # '060e2b34.0101.0101.03030102.00000000' => { Name => 'AutomatedCatalogingAndIndexing', Type => 'Node' },
    '060e2b34.0101.0101.03030102.01000000' => { Name => 'CatalogDataStatus', Format => 'string' },
    '060e2b34.0101.0101.03030102.02000000' => { Name => 'CatalogingSystemName', Format => 'string' },
    '060e2b34.0101.0101.03030102.06000000' => { Name => 'ComputedKeywords', Format => 'string' },
    '060e2b34.0101.0101.03030102.07000000' => { Name => 'ComputedKeyFrames', Format => 'string' },
    '060e2b34.0101.0101.03030102.08000000' => { Name => 'ComputedKeySounds', Format => 'string' },
    '060e2b34.0101.0101.03030102.09000000' => { Name => 'ComputedKeyData', Format => 'string' },
  # '060e2b34.0101.0101.03030106.00000000' => { Name => 'ComputedTextualDescription', Type => 'Node' },
  # '060e2b34.0101.0101.03030107.00000000' => { Name => 'AutomatedStratum', Type => 'Node' },
    '060e2b34.0101.0101.03030107.01000000' => { Name => 'ComputedStratumKind', Format => 'string' },
  # '060e2b34.0101.0101.03030300.00000000' => { Name => 'ComputedTechnicalCommentsAndDescriptions', Type => 'Node' },
  # '060e2b34.0101.0101.03030301.00000000' => { Name => 'ComputedObjectCommentsAndDescriptions', Type => 'Node' },
  # '060e2b34.0101.0101.04000000.00000000' => { Name => 'PARAMETRIC', Type => 'Node' },
  # '060e2b34.0101.0101.04010000.00000000' => { Name => 'VideoAndImageEssenceCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04010100.00000000' => { Name => 'FundamentalImageCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04010101.00000000' => { Name => 'AspectRatios', Type => 'Node' },
    '060e2b34.0101.0101.04010101.01000000' => { Name => 'PresentationAspectRatio', Format => 'rational64s' },
    '060e2b34.0101.0101.04010101.02000000' => { Name => 'CaptureAspectRatio', Format => 'string' },
  # '060e2b34.0101.0101.04010200.00000000' => { Name => 'ImageSourceCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04010201.00000000' => { Name => 'Opto-ElectronicFormulation', Type => 'Node' },
  # '060e2b34.0101.0101.04010201.01000000' => { Name => 'TransferCharacteristics', Type => 'Node' },
    '060e2b34.0101.0101.04010201.01010000' => { Name => 'CaptureGammaEquation', Format => 'string' },
    '060e2b34.0101.0101.04010201.01010100' => { Name => 'CaptureGammaEquation', Format => 'rational64s' },
    '060e2b34.0101.0101.04010201.01020000' => { Name => 'LumaEquation', Format => 'string' },
    '060e2b34.0101.0101.04010201.01030000' => { Name => 'ColorimetryCode', Format => 'string' },
    '060e2b34.0101.0101.04010201.01040000' => { Name => 'SignalFormCode', Format => 'string' },
  # '060e2b34.0101.0101.04010300.00000000' => { Name => 'VideoAndImageScanningParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04010301.00000000' => { Name => 'TemporalParameters', Type => 'Node' },
    '060e2b34.0101.0101.04010301.01000000' => { Name => 'ColorFieldCode', Format => 'int8u' },
    '060e2b34.0101.0101.04010301.02000000' => { Name => 'FieldRate', Format => 'int16u' },
    '060e2b34.0101.0101.04010301.03000000' => { Name => 'FrameRate', Format => 'int16u' },
    '060e2b34.0101.0101.04010301.04000000' => { Name => 'FrameLayout', Format => 'int8u' },
    '060e2b34.0101.0101.04010301.05000000' => { Name => 'SamplingStructureCode', Format => 'string' },
  # '060e2b34.0101.0101.04010302.00000000' => { Name => 'VerticalParameters', Type => 'Node' },
    '060e2b34.0101.0101.04010302.01000000' => { Name => 'TotalLinesperFrame', Format => 'int16u' },
    '060e2b34.0101.0101.04010302.02000000' => { Name => 'ActiveLinesperFrame', Format => 'int16u' },
    '060e2b34.0101.0101.04010302.03000000' => { Name => 'LeadingLines', Format => 'int32s' },
    '060e2b34.0101.0101.04010302.04000000' => { Name => 'TrailingLines', Format => 'int32s' },
  # '060e2b34.0101.0101.04010303.00000000' => { Name => 'HorizontalParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04010400.00000000' => { Name => 'AnalogVideoCodingCharacteristics', Type => 'Node' },
    '060e2b34.0101.0101.04010401.00000000' => { Name => 'AnalogVideoSystemName', Format => 'string' },
  # '060e2b34.0101.0101.04010500.00000000' => { Name => 'DigitalVideoAndImageCodingParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04010501.00000000' => { Name => 'DigitalVideoAndImageSamplingParameters', Type => 'Node' },
    '060e2b34.0101.0101.04010501.01000000' => { Name => 'LuminanceSampleRate', Format => 'int8u' },
    '060e2b34.0101.0101.04010501.02000000' => { Name => 'ActiveSamplesperLine', Format => 'int16u' },
    '060e2b34.0101.0101.04010501.03000000' => { Name => 'TotalSamplesperLine', Format => 'int16u' },
    '060e2b34.0101.0101.04010501.04000000' => { Name => 'SamplingHierarchyCode', Format => 'string' },
    '060e2b34.0101.0101.04010501.05000000' => { Name => 'HorizontalSubsampling', Format => 'int32u' },
    '060e2b34.0101.0101.04010501.06000000' => { Name => 'ColorSiting', Format => 'int8u' },
    '060e2b34.0101.0101.04010501.07000000' => { Name => 'SampledHeight', Format => 'int32u' },
    '060e2b34.0101.0101.04010501.08000000' => { Name => 'SampledWidth', Format => 'int32u' },
    '060e2b34.0101.0101.04010501.09000000' => { Name => 'SampledXOffset', Format => 'int32s' },
    '060e2b34.0101.0101.04010501.0a000000' => { Name => 'SampledYOffset', Format => 'int32s' },
    '060e2b34.0101.0101.04010501.0b000000' => { Name => 'DisplayHeight', Format => 'int32u' },
    '060e2b34.0101.0101.04010501.0c000000' => { Name => 'DisplayWidth', Format => 'int32u' },
    '060e2b34.0101.0101.04010501.0d000000' => { Name => 'DisplayXOffset', Format => 'int32s' },
    '060e2b34.0101.0101.04010501.0e000000' => { Name => 'DisplayYOffset', Format => 'int32s' },
    '060e2b34.0101.0101.04010501.0f000000' => { Name => 'FilteringCode', Format => 'string' },
  # '060e2b34.0101.0101.04010502.00000000' => { Name => 'DigitalVideoAndImageStorageParameters', Type => 'Node' },
    '060e2b34.0101.0101.04010502.01000000' => { Name => 'ImageHeight', Format => 'int32u' }, # (renamed from StoredHeight)
    '060e2b34.0101.0101.04010502.02000000' => { Name => 'ImageWidth', Format => 'int32u' }, # (renamed from StoredWidth)
  # '060e2b34.0101.0101.04010503.00000000' => { Name => 'DigitalQuantizationAndLevelParameters', Type => 'Node' },
    '060e2b34.0101.0101.04010503.01000000' => { Name => 'BitsPerPixel', Format => 'int8u' },
    '060e2b34.0101.0101.04010503.02000000' => { Name => 'RoundingMethodCode', Format => 'string' },
    '060e2b34.0101.0101.04010503.03000000' => { Name => 'BlackReferenceLevel', Format => 'int32u' },
    '060e2b34.0101.0101.04010503.04000000' => { Name => 'WhiteReferenceLevel', Format => 'int32u' },
  # '060e2b34.0101.0101.04010600.00000000' => { Name => 'DigitalVideoAndImageCompressionParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04010602.00000000' => { Name => 'MPEGCodingParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04010602.01000000' => { Name => 'MPEG-2CodingParameters', Type => 'Node' },
    '060e2b34.0101.0101.04010602.01010000' => { Name => 'FieldFrameTypeCode', Format => 'string' },
  # '060e2b34.0101.0101.04010800.00000000' => { Name => 'Film-to-VideoCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04010801.00000000' => { Name => 'FilmPulldownCharacteristics', Type => 'Node' },
    '060e2b34.0101.0101.04010801.01000000' => { Name => 'PulldownSequence', Type => 'PulldownKind', Unknown => 1 },
    '060e2b34.0101.0101.04010801.02000000' => { Name => 'PulldownFieldDominance', Type => 'Boolean' },
    '060e2b34.0101.0101.04010801.03000000' => { Name => 'VideoAndFilmFrameRelationship', Format => 'int8u' },
  # '060e2b34.0101.0101.04010802.00000000' => { Name => 'FilmFrameRates', Type => 'Node' },
    '060e2b34.0101.0101.04010802.01000000' => { Name => 'CaptureFilmFrameRate', Format => 'string' },
    '060e2b34.0101.0101.04010802.02000000' => { Name => 'TransferFilmFrameRate', Format => 'string' },
  # '060e2b34.0101.0101.04011000.00000000' => { Name => 'ImageTestParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04011001.00000000' => { Name => 'VideoTestParameters', Type => 'Node' },
    '060e2b34.0101.0101.04011001.01000000' => { Name => 'VideoTestParameter', Format => 'string' },
    '060e2b34.0101.0101.04011001.02000000' => { Name => 'VideoTestResult', Format => 'float' },
    '060e2b34.0101.0101.04011001.03000000' => { Name => 'VideoTestResult', Format => 'int32u' },
  # '060e2b34.0101.0101.04011002.00000000' => { Name => 'FilmTestParameters', Type => 'Node' },
    '060e2b34.0101.0101.04011002.01000000' => { Name => 'FilmTestParameter', Format => 'string' },
    '060e2b34.0101.0101.04011002.02000000' => { Name => 'FilmTestResult', Format => 'float' },
    '060e2b34.0101.0101.04011002.03000000' => { Name => 'FilmTestResult', Type => 'SIMSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.04020000.00000000' => { Name => 'AudioEssenceCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04020100.00000000' => { Name => 'FundamentalAudioCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04020101.00000000' => { Name => 'AudioFormulation', Type => 'Node' },
    '060e2b34.0101.0101.04020101.01000000' => { Name => 'ElectrospatialFormulation', Format => 'int8u', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0101.04020101.02000000' => { Name => 'FilteringApplied', Format => 'string', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0101.04020101.03000000' => { Name => 'AudioReferenceLevel', Format => 'int8s', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.04020101.10000000' => { Name => 'AudioMix', Type => 'Node' },
    '060e2b34.0101.0101.04020101.10010000' => { Name => 'AudioMonoChannelCount', Format => 'int8u', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0101.04020101.10020000' => { Name => 'AudioStereoChannelCount', Format => 'int8u', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.04020200.00000000' => { Name => 'AnalogAudioCodingParameters', Type => 'Node' },
    '060e2b34.0101.0101.04020201.00000000' => { Name => 'AnalogSystem', Format => 'string', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.04020300.00000000' => { Name => 'DigitalAudioCodingParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04020301.00000000' => { Name => 'DigitalSamplingParameters', Type => 'Node' },
    '060e2b34.0101.0101.04020301.01000000' => { Name => 'AudioSampleRate', Format => 'int8u', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.04020302.00000000' => { Name => 'DigitalAudioStorageParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04020303.00000000' => { Name => 'DigitalAudioQuantizationAndLevelParameters', Type => 'Node' },
    '060e2b34.0101.0101.04020303.01000000' => { Name => 'BitsPerSample', Format => 'int8u', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0101.04020303.02000000' => { Name => 'RoundingLaw', Format => 'string', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0101.04020303.03000000' => { Name => 'Dither', Format => 'string', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.04020400.00000000' => { Name => 'DigitalAudioCompressionParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04020403.00000000' => { Name => 'MPEGAudioCodingParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04020403.01000000' => { Name => 'MPEG-1AudioCodingParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04020800.00000000' => { Name => 'FilmSoundSource', Type => 'Node' },
    '060e2b34.0101.0101.04020801.00000000' => { Name => 'OpticalTrack', Format => 'string' },
    '060e2b34.0101.0101.04020802.00000000' => { Name => 'MagneticTrack', Format => 'string' },
  # '060e2b34.0101.0101.04021000.00000000' => { Name => 'AudioTestParameters', Type => 'Node' },
    '060e2b34.0101.0101.04021001.00000000' => { Name => 'Signal-to-NoiseRatio', Format => 'float', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0101.04021002.00000000' => { Name => 'Weighting', Format => 'string', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.04030000.00000000' => { Name => 'DataEssenceCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04030100.00000000' => { Name => 'FundamentalDataEssenceParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04030200.00000000' => { Name => 'AnalogDataEssenceCodingParameters', Type => 'Node' },
    '060e2b34.0101.0101.04030201.00000000' => { Name => 'AnalogDataCodingKind', Format => 'string' },
  # '060e2b34.0101.0101.04030300.00000000' => { Name => 'DigitalDataEssenceCodingParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04031000.00000000' => { Name => 'DataEssenceTestParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04040000.00000000' => { Name => 'MetadataCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04040100.00000000' => { Name => 'FundamentalMetadataCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04040101.00000000' => { Name => 'TimecodeCharacteristics', Type => 'Node' },
    '060e2b34.0101.0101.04040101.01000000' => { Name => 'TimecodeKind', Format => 'string' },
    '060e2b34.0101.0101.04040101.02000000' => { Name => 'TimecodeTimebase', Format => 'int8u' },
    '060e2b34.0101.0101.04040101.03000000' => { Name => 'TimecodeUserBitsFlag', Type => 'Boolean' },
    '060e2b34.0101.0101.04040101.04000000' => { Name => 'IncludeSync', Type => 'Boolean' },
    '060e2b34.0101.0101.04040101.05000000' => { Name => 'DropFrame', Type => 'Boolean' },
  # '060e2b34.0101.0101.04040200.00000000' => { Name => 'AnalogMetadataCodingCharacteristics', Type => 'Node' },
    '060e2b34.0101.0101.04040201.00000000' => { Name => 'TimecodeSourceKind', Format => 'int8u' },
    '060e2b34.0101.0101.04040202.00000000' => { Name => 'AnalogMetadataCarrier', Format => 'string' },
  # '060e2b34.0101.0101.04040300.00000000' => { Name => 'DigitalMetadataCodingCharacteristics', Type => 'Node' },
    '060e2b34.0101.0101.04040301.00000000' => { Name => 'DigitalMetadataCarrier', Format => 'string' },
  # '060e2b34.0101.0101.04041000.00000000' => { Name => 'MetadataTestParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04050000.00000000' => { Name => 'MonitoringAndControlCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04050100.00000000' => { Name => 'FundamentalMonitoringAndControlCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04050200.00000000' => { Name => 'AnalogMonitoringAndControlCodingCharacteristics', Type => 'Node' },
    '060e2b34.0101.0101.04050201.00000000' => { Name => 'AnalogMonitoringAndControlCodingKind', Format => 'string' },
  # '060e2b34.0101.0101.04050300.00000000' => { Name => 'DigitalMonitoringAndControlCodingParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04050301.00000000' => { Name => 'DigitalMonitoringAndControlSamplingParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04051000.00000000' => { Name => 'MonitoringAndControlTestParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04060000.00000000' => { Name => 'GeneralCodingCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04060100.00000000' => { Name => 'GeneralEssenceCodingCharacteristics', Type => 'Node' },
    '060e2b34.0101.0101.04060101.00000000' => { Name => 'SampleRate', Format => 'rational64s' },
    '060e2b34.0101.0101.04060102.00000000' => { Name => 'EssenceLength', Type => 'Length', %duration },
  # '060e2b34.0101.0101.04080000.00000000' => { Name => 'ObjectCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04100000.00000000' => { Name => 'MediumCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04100100.00000000' => { Name => 'StorageMediumParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04100101.00000000' => { Name => 'TapeMediumParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04100102.00000000' => { Name => 'DiscMediumParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04100103.00000000' => { Name => 'FilmMediumParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04100103.01000000' => { Name => 'GenericFilmMediumParameters', Type => 'Node' },
    '060e2b34.0101.0101.04100103.01010000' => { Name => 'FilmColorProcess', Format => 'string' },
    '060e2b34.0101.0101.04100103.01020000' => { Name => 'EdgeCodeFormat', Type => 'EdgeType', Unknown => 1 },
    '060e2b34.0101.0101.04100103.01040000' => { Name => 'FilmFormatName', Format => 'string' },
    '060e2b34.0101.0101.04100103.01050000' => { Name => 'FilmStockKind', Format => 'string' },
    '060e2b34.0101.0101.04100103.01060000' => { Name => 'FilmStockManufacturerName', Format => 'string' },
  # '060e2b34.0101.0101.04100103.02000000' => { Name => 'SpecificFilmMediumParameters', Type => 'Node' },
    '060e2b34.0101.0101.04100103.02010000' => { Name => 'PhysicalMediaLength', Type => 'UIMSBF', Unknown => 1, Groups => { 2 => 'Time' } },
    '060e2b34.0101.0101.04100103.02020000' => { Name => 'FilmCaptureAperture', Format => 'string' },
  # '060e2b34.0101.0101.04200000.00000000' => { Name => 'DeviceCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04200100.00000000' => { Name => 'CameraCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04200101.00000000' => { Name => 'ImageCharacteristics', Type => 'Node' },
    '060e2b34.0101.0101.04200101.01000000' => { Name => 'ImageCategory', Format => 'string' },
  # '060e2b34.0101.0101.04200102.01000000' => { Name => 'ImageDevices', Type => 'Node' },
    '060e2b34.0101.0101.04200102.01010000' => { Name => 'ImageSourceDeviceKind', Format => 'string' },
  # '060e2b34.0101.0101.04200200.00000000' => { Name => 'OpticalCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.04200201.00000000' => { Name => 'OpticalTestParameters', Type => 'Node' },
  # '060e2b34.0101.0101.04200201.01000000' => { Name => 'OpticalDeviceParameters', Type => 'Node' },
    '060e2b34.0101.0101.04200201.01010000' => { Name => 'OpticalTestParameterName', Format => 'string' },
    '060e2b34.0101.0101.04200201.01020000' => { Name => 'OpticalTestResult', Format => 'float' },
    '060e2b34.0101.0101.04200201.01030000' => { Name => 'OpticalTestResult', Format => 'int32s' },
  # '060e2b34.0101.0101.04200300.00000000' => { Name => 'MicrophoneCharacteristics', Type => 'Node' },
    '060e2b34.0101.0101.04200301.00000000' => { Name => 'SensorType', Format => 'string' },
    '060e2b34.0101.0101.04200302.00000000' => { Name => 'PolarCharacteristic', Format => 'string' },
  # '060e2b34.0101.0101.05000000.00000000' => { Name => 'PROCESS', Type => 'Node' },
  # '060e2b34.0101.0101.05010000.00000000' => { Name => 'GeneralProcessIndicators', Type => 'Node' },
  # '060e2b34.0101.0101.05010100.00000000' => { Name => 'ProcessFundamentals', Type => 'Node' },
    '060e2b34.0101.0101.05010101.00000000' => { Name => 'IntegrationIndication', Format => 'string' },
    '060e2b34.0101.0101.05010102.00000000' => { Name => 'EventIndication', Format => 'string' },
    '060e2b34.0101.0101.05010103.00000000' => { Name => 'QualityFlag', Type => 'Boolean' },
    '060e2b34.0101.0101.05010105.00000000' => { Name => 'PhysicalInstanceKind', Format => 'string' },
  # '060e2b34.0101.0101.05010200.00000000' => { Name => 'ContentCapture', Type => 'Node' },
    '060e2b34.0101.0101.05010201.00000000' => { Name => 'DigitalOrAnalogOrigination', Format => 'string' },
  # '060e2b34.0101.0101.05010202.00000000' => { Name => 'VideoOrImageCaptureProcess', Type => 'Node' },
  # '060e2b34.0101.0101.05010203.00000000' => { Name => 'FilmCaptureProcess', Type => 'Node' },
  # '060e2b34.0101.0101.05010204.00000000' => { Name => 'AudioCaptureProcess', Type => 'Node' },
    '060e2b34.0101.0101.05010204.01000000' => { Name => 'MicrophonePlacementTechniques', Format => 'string', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.05010205.00000000' => { Name => 'DataCaptureProcess', Type => 'Node' },
  # '060e2b34.0101.0101.05010300.00000000' => { Name => 'Manipulation', Type => 'Node' },
    '060e2b34.0101.0101.05010301.00000000' => { Name => 'SimpleFlaggingCount', Format => 'int16u' },
    '060e2b34.0101.0101.05010302.00000000' => { Name => 'CopyCount', Format => 'int8u' },
    '060e2b34.0101.0101.05010303.00000000' => { Name => 'CloneCount', Format => 'int8u' },
    '060e2b34.0101.0101.05010304.00000000' => { Name => 'Work-in-ProgressFlag', Type => 'Boolean' },
  # '060e2b34.0101.0101.05020000.00000000' => { Name => 'CompressionProcessing', Type => 'Node' },
  # '060e2b34.0101.0101.05020100.00000000' => { Name => 'VideoOrImageCompression', Type => 'Node' },
    '060e2b34.0101.0101.05020101.00000000' => { Name => 'VideoOrImageCompressionAlgorithm', Format => 'string' },
  # '060e2b34.0101.0101.05020102.00000000' => { Name => 'MPEGProcessing', Type => 'Node' },
  # '060e2b34.0101.0101.05020102.01000000' => { Name => 'MPEG-2Processing', Type => 'Node' },
    '060e2b34.0101.0101.05020102.01010000' => { Name => 'SplicingMetadata', Unknown => 1 },
  # '060e2b34.0101.0101.05020200.00000000' => { Name => 'AudioCompression', Type => 'Node' },
    '060e2b34.0101.0101.05020201.00000000' => { Name => 'AudioCompressionAlgorithm', Format => 'string', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.05020300.00000000' => { Name => 'DataEssenceCompression', Type => 'Node' },
  # '060e2b34.0101.0101.05020400.00000000' => { Name => 'MetadataCompression', Type => 'Node' },
  # '060e2b34.0101.0101.05030000.00000000' => { Name => 'NoiseReductionProcessing', Type => 'Node' },
  # '060e2b34.0101.0101.05030100.00000000' => { Name => 'VideoNoiseReduction', Type => 'Node' },
    '060e2b34.0101.0101.05030101.00000000' => { Name => 'VideoNoiseReductionAlgorithm', Format => 'string' },
  # '060e2b34.0101.0101.05030200.00000000' => { Name => 'AudioNoiseReduction', Type => 'Node' },
    '060e2b34.0101.0101.05030201.00000000' => { Name => 'AudioNoiseReductionAlgorithm', Format => 'string', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.05200000.00000000' => { Name => 'EnhancementOrModification', Type => 'Node' },
  # '060e2b34.0101.0101.05200100.00000000' => { Name => 'ImageEssenceProcessing', Type => 'Node' },
    '060e2b34.0101.0101.05200101.00000000' => { Name => 'EnhancementOrModificationDescription', Format => 'string' },
  # '060e2b34.0101.0101.05200200.00000000' => { Name => 'VideoProcessOrSettings', Type => 'Node' },
    '060e2b34.0101.0101.05200201.00000000' => { Name => 'VideoDeviceKind', Format => 'string' },
    '060e2b34.0101.0101.05200202.00000000' => { Name => 'VideoDeviceParameterName', Format => 'string' },
    '060e2b34.0101.0101.05200203.00000000' => { Name => 'VideoDeviceParameterSetting', Format => 'string' },
  # '060e2b34.0101.0101.05200300.00000000' => { Name => 'AudioEssenceProcessing', Type => 'Node' },
    '060e2b34.0101.0101.05200301.00000000' => { Name => 'AudioEnhancementOrModificationDescription', Format => 'string', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0101.05200302.00000000' => { Name => 'AudioFirstMix-DownProcess', Format => 'string', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.05200400.00000000' => { Name => 'AudioProcessorSettings', Type => 'Node' },
    '060e2b34.0101.0101.05200401.00000000' => { Name => 'AudioDeviceKind', Format => 'string', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0101.05200402.00000000' => { Name => 'AudioDeviceParameter', Format => 'string', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0101.05200403.00000000' => { Name => 'AudioDeviceParameterSetting', Format => 'string', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.05200500.00000000' => { Name => 'DataEssenceProcessing', Type => 'Node' },
    '060e2b34.0101.0101.05200501.00000000' => { Name => 'DataEnhancementOrModificationDescription', Format => 'string' },
  # '060e2b34.0101.0101.05200600.00000000' => { Name => 'DataProcessorSettings', Type => 'Node' },
    '060e2b34.0101.0101.05200601.00000000' => { Name => 'DataDeviceKind', Format => 'string' },
    '060e2b34.0101.0101.05200602.00000000' => { Name => 'DataDeviceParameterName', Format => 'string' },
    '060e2b34.0101.0101.05200603.00000000' => { Name => 'DataDeviceParameterSetting', Format => 'string' },
  # '060e2b34.0101.0101.05200700.00000000' => { Name => 'MetadataProcessing', Type => 'Node' },
  # '060e2b34.0101.0101.05200800.00000000' => { Name => 'MetadataProcessorSettings', Type => 'Node' },
  # '060e2b34.0101.0101.05300000.00000000' => { Name => 'EditingInformation', Type => 'Node' },
  # '060e2b34.0101.0101.05300100.00000000' => { Name => 'EditingVersionInformation', Type => 'Node' },
  # '060e2b34.0101.0101.05300200.00000000' => { Name => 'EditingDecisionInformation', Type => 'Node' },
    '060e2b34.0101.0101.05300201.00000000' => { Name => 'DefaultFadeType', Type => 'FadeType', Unknown => 1 },
  # '060e2b34.0101.0101.05300300.00000000' => { Name => 'EditingMatteInformation', Type => 'Node' },
  # '060e2b34.0101.0101.05300400.00000000' => { Name => 'EditingEventInformation', Type => 'Node' },
    '060e2b34.0101.0101.05300401.00000000' => { Name => 'ActiveState', Type => 'Boolean' },
  # '060e2b34.0101.0101.05300500.00000000' => { Name => 'EditingEffectInformation', Type => 'Node' },
    '060e2b34.0101.0101.05300501.00000000' => { Name => 'Fade-InType', Type => 'FadeType', Unknown => 1 },
    '060e2b34.0101.0101.05300502.00000000' => { Name => 'Fade-OutType', Type => 'FadeType', Unknown => 1 },
    '060e2b34.0101.0101.05300503.00000000' => { Name => 'SpeedChangeEffectFlag', Type => 'Boolean' },
    '060e2b34.0101.0101.05300504.00000000' => { Name => 'InputSegmentCount', Format => 'int32s' },
    '060e2b34.0101.0101.05300505.00000000' => { Name => 'Bypass', Format => 'int32u' },
  # '060e2b34.0101.0101.05300600.00000000' => { Name => 'EditingWebInformation', Type => 'Node' },
  # '060e2b34.0101.0101.05300700.00000000' => { Name => 'EditingUserNotes', Type => 'Node' },
  # '060e2b34.0101.0101.05400000.00000000' => { Name => 'ProcessingHistory', Type => 'Node' },
  # '060e2b34.0101.0101.05400100.00000000' => { Name => 'VideoCompressionHistory', Type => 'Node' },
    '060e2b34.0101.0101.05400101.00000000' => { Name => 'VideoCompressionAlgorithm', Format => 'string' },
    '060e2b34.0101.0101.05400102.00000000' => { Name => 'MPEGVideoRecodingDataset', Unknown => 1 },
  # '060e2b34.0101.0101.05400200.00000000' => { Name => 'AudioCompressionHistory', Type => 'Node' },
    '060e2b34.0101.0101.05400201.00000000' => { Name => 'UpstreamAudioCompressionAlgorithm', Format => 'string', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0101.05400202.00000000' => { Name => 'MPEGAudioRecodingDataset', Unknown => 1, Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.05400300.00000000' => { Name => 'DataCompressionHistory', Type => 'Node' },
  # '060e2b34.0101.0101.05400400.00000000' => { Name => 'MetadataCompressionHistory', Type => 'Node' },
  # '060e2b34.0101.0101.06000000.00000000' => { Name => 'RELATIONAL', Type => 'Node' },
  # '060e2b34.0101.0101.06010000.00000000' => { Name => 'GenericRelationships', Type => 'Node' },
  # '060e2b34.0101.0101.06010100.00000000' => { Name => 'EssenceAndMetadataRelationships', Type => 'Node' },
  # '060e2b34.0101.0101.06010101.00000000' => { Name => 'EssenceToEssenceRelationships', Type => 'Node' },
  # '060e2b34.0101.0101.06010102.00000000' => { Name => 'MetadataToEssenceRelationships', Type => 'Node' },
  # '060e2b34.0101.0101.06010103.00000000' => { Name => 'MetadataToMetadataRelationships', Type => 'Node' },
  # '060e2b34.0101.0101.06010104.00000000' => { Name => 'ObjectToObjectRelationships', Type => 'Node' },
  # '060e2b34.0101.0101.06010105.00000000' => { Name => 'MetadataToObjectRelationships', Type => 'Node' },
  # '060e2b34.0101.0101.06020000.00000000' => { Name => 'RelatedProductionMaterial', Type => 'Node' },
    '060e2b34.0101.0101.06020100.00000000' => { Name => 'ProgramSupportMaterialReference', Format => 'string' },
    '060e2b34.0101.0101.06020200.00000000' => { Name => 'AdvertisingMaterialReference', Format => 'string' },
    '060e2b34.0101.0101.06020300.00000000' => { Name => 'ProgramCommercialMaterialReference', Format => 'string' },
  # '060e2b34.0101.0101.06080000.00000000' => { Name => 'StreamAndStorageRelationships', Type => 'Node' },
  # '060e2b34.0101.0101.06080100.00000000' => { Name => 'StreamRelationships', Type => 'Node' },
  # '060e2b34.0101.0101.06080200.00000000' => { Name => 'StorageRelationships', Type => 'Node' },
    '060e2b34.0101.0101.06080201.00000000' => { Name => 'ContiguousDataFlag', Type => 'Boolean' },
  # '060e2b34.0101.0101.06100000.00000000' => { Name => 'NumericalSequence', Type => 'Node' },
    '060e2b34.0101.0101.06100100.00000000' => { Name => 'PositionInSequence', Format => 'int32u' },
    '060e2b34.0101.0101.06100200.00000000' => { Name => 'RelativePositionInSequenceOffset', Format => 'int32s' },
    '060e2b34.0101.0101.06100300.00000000' => { Name => 'RelativePositionInSequenceName', Format => 'string' },
  # '060e2b34.0101.0101.07000000.00000000' => { Name => 'SPATIO-TEMPORAL', Type => 'Node' },
  # '060e2b34.0101.0101.07010000.00000000' => { Name => 'PositionAndSpaceVectors', Type => 'Node' },
  # '060e2b34.0101.0101.07010100.00000000' => { Name => 'PositionalSystemInformation', Type => 'Node' },
    '060e2b34.0101.0101.07010101.00000000' => { Name => 'ImageCoordinateSystem', Format => 'string' },
    '060e2b34.0101.0101.07010102.00000000' => { Name => 'MapDatumUsed', Format => 'string' },
  # '060e2b34.0101.0101.07010200.00000000' => { Name => 'PositionalInformation', Type => 'Node' },
  # '060e2b34.0101.0101.07010201.00000000' => { Name => 'AbsolutePosition', Type => 'Node' },
  # '060e2b34.0101.0101.07010201.01000000' => { Name => 'LocalDatumAbsolutePosition', Type => 'Node' },
    '060e2b34.0101.0101.07010201.01010000' => { Name => 'LocalDatumAbsolutePositionAccuracy', Format => 'float' },
  # '060e2b34.0101.0101.07010201.02000000' => { Name => 'DeviceAbsolutePosition', Type => 'Node' },
    '060e2b34.0101.0101.07010201.02010000' => { Name => 'DeviceAbsolutePositionalAccuracy', Format => 'float' },
    '060e2b34.0101.0101.07010201.02020000' => { Name => 'DeviceAltitude', Format => 'float', Groups => { 2 => 'Location' }, PrintConv => '$val m' },
    '060e2b34.0101.0101.07010201.02020100' => { Name => 'DeviceAltitude', Type => 'Alt', Groups => { 2 => 'Location' }, PrintConv => '$val m' },
    '060e2b34.0101.0101.07010201.02040000' => { Name => 'DeviceLatitude', Format => 'float', %geoLat },
    '060e2b34.0101.0101.07010201.02040100' => { Name => 'DeviceLatitude', Type => 'Lat', %geoLat },
    '060e2b34.0101.0101.07010201.02060000' => { Name => 'DeviceLongitude', Format => 'float', %geoLon },
    '060e2b34.0101.0101.07010201.02060100' => { Name => 'DeviceLongitude', Type => 'Lon', %geoLon },
    '060e2b34.0101.0101.07010201.02100000' => { Name => 'DeviceXDimension', Format => 'float' },
    '060e2b34.0101.0101.07010201.02110000' => { Name => 'DeviceYDimension', Format => 'float' },
  # '060e2b34.0101.0101.07010201.03000000' => { Name => 'SubjectAbsolutePosition', Type => 'Node' },
    '060e2b34.0101.0101.07010201.03010000' => { Name => 'FramePositionalAccuracy', Format => 'float' },
    '060e2b34.0101.0101.07010201.03020000' => { Name => 'FrameCenterLatitude', Format => 'double', %geoLat },
    '060e2b34.0101.0101.07010201.03030000' => { Name => 'FrameCenterLatitude', Format => 'string', %geoLat, ValueConv => \&ConvLatLon },
    '060e2b34.0101.0101.07010201.03040000' => { Name => 'FrameCenterLongitude', Format => 'double', %geoLon },
    '060e2b34.0101.0101.07010201.03050000' => { Name => 'FrameCenterLongitude', Format => 'string', %geoLon, ValueConv => \&ConvLatLon },
    '060e2b34.0101.0101.07010201.03060000' => { Name => 'FrameCenterLatitudeLongitude', Format => 'string', %geoLatLon, ValueConv => \&ConvLatLon },
  # '060e2b34.0101.0101.07010202.00000000' => { Name => 'RelativePosition', Type => 'Node' },
  # '060e2b34.0101.0101.07010202.01000000' => { Name => 'LocalDatumRelativePosition', Type => 'Node' },
    '060e2b34.0101.0101.07010202.01010000' => { Name => 'LocalDatumRelativePositionAccuracy', Format => 'float' },
  # '060e2b34.0101.0101.07010202.02000000' => { Name => 'DeviceRelativePosition', Type => 'Node' },
    '060e2b34.0101.0101.07010202.02010000' => { Name => 'DeviceRelativePositionalAccuracy', Format => 'float' },
    '060e2b34.0101.0101.07010202.02020000' => { Name => 'DeviceRelativePositionX', Format => 'float' },
    '060e2b34.0101.0101.07010202.02030000' => { Name => 'DeviceRelativePositionY', Format => 'float' },
    '060e2b34.0101.0101.07010202.02040000' => { Name => 'DeviceRelativePositionZ', Format => 'float' },
  # '060e2b34.0101.0101.07010202.03000000' => { Name => 'SubjectRelativePosition', Type => 'Node' },
    '060e2b34.0101.0101.07010202.03010000' => { Name => 'SubjectRelativePositionalAccuracy', Format => 'float' },
  # '060e2b34.0101.0101.07010203.00000000' => { Name => 'ImagePositionalInformation', Type => 'Node' },
    '060e2b34.0101.0101.07010203.01000000' => { Name => 'PositionWithinViewportImageXCoordinate', Format => 'int16s' },
    '060e2b34.0101.0101.07010203.02000000' => { Name => 'PositionWithinViewportImageYCoordinate', Format => 'int16s' },
    '060e2b34.0101.0101.07010203.03000000' => { Name => 'SourceImageCenterXCoordinate', Format => 'int16s' },
    '060e2b34.0101.0101.07010203.04000000' => { Name => 'SourceImageCenterYCoordinate', Format => 'int16s' },
    '060e2b34.0101.0101.07010203.05000000' => { Name => 'ViewportImageCenterCCoordinate', Format => 'int16s' },
    '060e2b34.0101.0101.07010203.06000000' => { Name => 'ViewportImageCenterYCoordinate', Format => 'int16s' },
  # '060e2b34.0101.0101.07010300.00000000' => { Name => 'RateAndDirectionOfPositionalChange', Type => 'Node' },
  # '060e2b34.0101.0101.07010301.00000000' => { Name => 'AbsoluteRateAndDirectionOfPositionalChange', Type => 'Node' },
  # '060e2b34.0101.0101.07010301.01000000' => { Name => 'DeviceRateAndDirectionOfPositionalChange', Type => 'Node' },
    '060e2b34.0101.0101.07010301.01010000' => { Name => 'DeviceAbsoluteSpeed', Format => 'float' },
    '060e2b34.0101.0101.07010301.01020000' => { Name => 'DeviceAbsoluteHeading', Format => 'float' },
  # '060e2b34.0101.0101.07010301.02000000' => { Name => 'SubjectRateAndDirectionOfPositionalChange', Type => 'Node' },
    '060e2b34.0101.0101.07010301.02010000' => { Name => 'SubjectAbsoluteSpeed', Format => 'float' },
    '060e2b34.0101.0101.07010301.02020000' => { Name => 'SubjectAbsoluteHeading', Format => 'float' },
  # '060e2b34.0101.0101.07010302.00000000' => { Name => 'RelativeRateAndDirectionOfPositionalChange', Type => 'Node' },
  # '060e2b34.0101.0101.07010302.01000000' => { Name => 'DeviceRelativeRateAndDirectionOfPositionalChange', Type => 'Node' },
    '060e2b34.0101.0101.07010302.01010000' => { Name => 'DeviceRelativeSpeed', Format => 'float' },
    '060e2b34.0101.0101.07010302.01020000' => { Name => 'DeviceRelativeHeading', Format => 'float' },
  # '060e2b34.0101.0101.07010302.02000000' => { Name => 'SubjectRelativeRateAndDirectionOfPositionalChange', Type => 'Node' },
    '060e2b34.0101.0101.07010302.02010000' => { Name => 'SubjectRelativeSpeed', Format => 'float' },
    '060e2b34.0101.0101.07010302.02020000' => { Name => 'SubjectRelativeHeading', Format => 'float' },
  # '060e2b34.0101.0101.07010800.00000000' => { Name => 'DistanceMeasurements', Type => 'Node' },
  # '060e2b34.0101.0101.07010801.00000000' => { Name => 'DeviceToSubjectDistance', Type => 'Node' },
    '060e2b34.0101.0101.07010801.01000000' => { Name => 'SlantRange', Format => 'float' },
  # '060e2b34.0101.0101.07010900.00000000' => { Name => 'Dimensions', Type => 'Node' },
  # '060e2b34.0101.0101.07010901.00000000' => { Name => 'DeviceDimensions', Type => 'Node' },
  # '060e2b34.0101.0101.07010902.00000000' => { Name => 'SubjectDimensions', Type => 'Node' },
    '060e2b34.0101.0101.07010902.01000000' => { Name => 'TargetWidth', Format => 'float' },
  # '060e2b34.0101.0101.07010903.00000000' => { Name => 'LocationDimensions', Type => 'Node' },
  # '060e2b34.0101.0101.07010904.00000000' => { Name => 'MediaDimensions', Type => 'Node' },
  # '060e2b34.0101.0101.07010904.01000000' => { Name => 'ImageDimensions', Type => 'Node' },
  # '060e2b34.0101.0101.07010904.01010000' => { Name => 'Pan-and-ScanImageDimensions', Type => 'Node' },
    '060e2b34.0101.0101.07010904.01010100' => { Name => 'ViewportHeight', Format => 'int16u' },
    '060e2b34.0101.0101.07010904.01010200' => { Name => 'ViewportWidth', Format => 'int16u' },
  # '060e2b34.0101.0101.07011000.00000000' => { Name => 'AngularSpecifications', Type => 'Node' },
  # '060e2b34.0101.0101.07011001.00000000' => { Name => 'DeviceAngles', Type => 'Node' },
    '060e2b34.0101.0101.07011001.01000000' => { Name => 'SensorRollAngle', Format => 'float' },
    '060e2b34.0101.0101.07011001.02000000' => { Name => 'AngleToNorth', Format => 'float' },
    '060e2b34.0101.0101.07011001.03000000' => { Name => 'ObliquityAngle', Format => 'float' },
  # '060e2b34.0101.0101.07011002.00000000' => { Name => 'SubjectAngles', Type => 'Node' },
  # '060e2b34.0101.0101.07012000.00000000' => { Name => 'AbstractLocations', Type => 'Node' },
  # '060e2b34.0101.0101.07012001.00000000' => { Name => 'PlaceNames', Type => 'Node' },
  # '060e2b34.0101.0101.07012001.01000000' => { Name => 'AbstractNames', Type => 'Node' },
    '060e2b34.0101.0101.07012001.01010000' => { Name => 'PlaceKeyword', Format => 'string' },
  # '060e2b34.0101.0101.07012001.02000000' => { Name => 'CountryCodes', Type => 'Node' },
    '060e2b34.0101.0101.07012001.02010000' => { Name => 'ObjectCountryCode', Format => 'string' },
    '060e2b34.0101.0101.07012001.02020000' => { Name => 'ShootingCountryCode', Format => 'string' },
    '060e2b34.0101.0101.07012001.02030000' => { Name => 'SettingCountryCode', Format => 'string' },
    '060e2b34.0101.0101.07012001.02040000' => { Name => 'CopyrightLicenseCountryCode', Format => 'string' },
    '060e2b34.0101.0101.07012001.02050000' => { Name => 'IntellectualPropertyLicenseCountryCode', Format => 'string' },
  # '060e2b34.0101.0101.07012001.03000000' => { Name => 'Regions', Type => 'Node' },
    '060e2b34.0101.0101.07012001.03010000' => { Name => 'ObjectRegionCode', Format => 'string' },
    '060e2b34.0101.0101.07012001.03020000' => { Name => 'ShootingRegionCode', Format => 'string' },
    '060e2b34.0101.0101.07012001.03030000' => { Name => 'SettingRegionCode', Format => 'string' },
    '060e2b34.0101.0101.07012001.03040000' => { Name => 'CopyrightLicenseRegionCode', Format => 'string' },
    '060e2b34.0101.0101.07012001.03050000' => { Name => 'IntellectualPropertyLicenseRegionCode', Format => 'string' },
  # '060e2b34.0101.0101.07012001.04000000' => { Name => 'Addresses', Type => 'Node' },
  # '060e2b34.0101.0101.07012001.04010000' => { Name => 'PostalAddresses', Type => 'Node' },
    '060e2b34.0101.0101.07012001.04010100' => { Name => 'RoomNumber', Format => 'string' },
    '060e2b34.0101.0101.07012001.04010200' => { Name => 'StreetNumber', Format => 'string' },
    '060e2b34.0101.0101.07012001.04010300' => { Name => 'StreetName', Format => 'string' },
    '060e2b34.0101.0101.07012001.04010400' => { Name => 'PostalTown', Format => 'string' },
    '060e2b34.0101.0101.07012001.04010500' => { Name => 'CityName', Format => 'string' },
    '060e2b34.0101.0101.07012001.04010600' => { Name => 'StateOrProvinceOrCountyName', Format => 'string' },
    '060e2b34.0101.0101.07012001.04010700' => { Name => 'PostalCode', Format => 'string' },
    '060e2b34.0101.0101.07012001.04010800' => { Name => 'CountryName', Format => 'string' },
  # '060e2b34.0101.0101.07012001.04020000' => { Name => 'SettingAddresses', Type => 'Node' },
    '060e2b34.0101.0101.07012001.04020100' => { Name => 'SettingRoomNumber', Format => 'string' },
    '060e2b34.0101.0101.07012001.04020200' => { Name => 'SettingStreetNumberOrBuildingName', Format => 'string' },
    '060e2b34.0101.0101.07012001.04020300' => { Name => 'SettingStreetName', Format => 'string' },
    '060e2b34.0101.0101.07012001.04020400' => { Name => 'SettingTownName', Format => 'string' },
    '060e2b34.0101.0101.07012001.04020500' => { Name => 'SettingCityName', Format => 'string' },
    '060e2b34.0101.0101.07012001.04020600' => { Name => 'SettingStateOrProvinceOrCountyName', Format => 'string' },
    '060e2b34.0101.0101.07012001.04020700' => { Name => 'SettingPostalCode', Format => 'string' },
    '060e2b34.0101.0101.07012001.04020800' => { Name => 'SettingCountryName', Format => 'string' },
  # '060e2b34.0101.0101.07012001.10030000' => { Name => 'ElectronicAddressInformation', Type => 'Node' },
    '060e2b34.0101.0101.07012001.10030100' => { Name => 'TelephoneNumber', Format => 'string' },
    '060e2b34.0101.0101.07012001.10030200' => { Name => 'FaxNumber', Format => 'string' },
    '060e2b34.0101.0101.07012001.10030300' => { Name => 'E-mailAddress', Format => 'string' },
  # '060e2b34.0101.0101.07012002.00000000' => { Name => 'PlaceDescriptions', Type => 'Node' },
    '060e2b34.0101.0101.07012002.01000000' => { Name => 'SettingDescription', Format => 'string' },
  # '060e2b34.0101.0101.07020000.00000000' => { Name => 'Temporal', Type => 'Node' },
  # '060e2b34.0101.0101.07020100.00000000' => { Name => 'DatesAndTimes', Type => 'Node' },
  # '060e2b34.0101.0101.07020101.00000000' => { Name => 'GeneralDatesAndTimes', Type => 'Node' },
  # '060e2b34.0101.0101.07020101.01000000' => { Name => 'UserDateTime', Type => 'Node' },
    '060e2b34.0101.0101.07020101.01010000' => { Name => 'UTCUserDateTime', Format => 'string', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0101.07020101.01020000' => { Name => 'LocalUserDateTime', Format => 'string', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0101.07020101.01030000' => { Name => 'SMPTE309MUserDateTime', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
    '060e2b34.0101.0101.07020101.01040000' => { Name => 'SMPTE12MUserDateTime', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020102.00000000' => { Name => 'AbsoluteDatesAndTimes', Type => 'Node' },
  # '060e2b34.0101.0101.07020102.01000000' => { Name => 'MaterialStartTrueDateTime', Type => 'Node' },
    '060e2b34.0101.0101.07020102.01010000' => { Name => 'UTCStartDateTime', Format => 'string', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0101.07020102.01020000' => { Name => 'LocalStartDateTime', Format => 'string', Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020102.02000000' => { Name => 'MaterialStartTimeAddress', Type => 'Node' },
    '060e2b34.0101.0101.07020102.02010000' => { Name => 'TimecodeStartDateTime', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020102.03000000' => { Name => 'MaterialEndTrueDateTime', Type => 'Node' },
    '060e2b34.0101.0101.07020102.03010000' => { Name => 'UTCEndDateTime', Format => 'string', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0101.07020102.03020000' => { Name => 'LocalEndDateTime', Format => 'string', Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020102.04000000' => { Name => 'MaterialEndTimeAddress', Type => 'Node' },
    '060e2b34.0101.0101.07020102.04010000' => { Name => 'TimecodeEndDateTime', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020102.05000000' => { Name => 'MaterialOccurrenceTrueDateTime', Type => 'Node' },
    '060e2b34.0101.0101.07020102.05010000' => { Name => 'UTCLastModifyDate', Format => 'string', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0101.07020102.05020000' => { Name => 'LocalLastModifyDate', Format => 'string', Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020102.06000000' => { Name => 'MaterialOccurrenceTimeAddress', Type => 'Node' },
    '060e2b34.0101.0101.07020102.06010000' => { Name => 'TimecodeLastModifyDate', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020102.07000000' => { Name => 'EventStartTrueDateTime', Type => 'Node' },
    '060e2b34.0101.0101.07020102.07010000' => { Name => 'UTCEventStartDateTime', Format => 'string', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0101.07020102.07020000' => { Name => 'LocalEventStartDateTime', Format => 'string', Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020102.08000000' => { Name => 'EventStartTimeAddress', Type => 'Node' },
    '060e2b34.0101.0101.07020102.08010000' => { Name => 'TimecodeEventStartDateTime', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020102.09000000' => { Name => 'EventEndTrueDateTime', Type => 'Node' },
    '060e2b34.0101.0101.07020102.09010000' => { Name => 'UTCEventEndDateTime', Format => 'string', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0101.07020102.09020000' => { Name => 'LocalEventEndDateTime', Format => 'string', Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020102.0a000000' => { Name => 'EventEndTimeAddress', Type => 'Node' },
    '060e2b34.0101.0101.07020102.0a010000' => { Name => 'TimecodeEventEndDateTime', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020103.00000000' => { Name => 'RelativeTimes', Type => 'Node' },
  # '060e2b34.0101.0101.07020103.01000000' => { Name => 'MaterialStartRelativeTimes', Type => 'Node' },
    '060e2b34.0101.0101.07020103.01010000' => { Name => 'StartTimeRelativeToReference', Format => 'string' },
    '060e2b34.0101.0101.07020103.01020000' => { Name => 'StartTimecodeRelativeToReference', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020103.02000000' => { Name => 'MaterialEndRelativeTimes', Type => 'Node' },
    '060e2b34.0101.0101.07020103.02010000' => { Name => 'MaterialEndTimeOffset', Format => 'string' },
    '060e2b34.0101.0101.07020103.02020000' => { Name => 'MaterialEndTimecodeOffset', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020103.03000000' => { Name => 'EventStartRelativeTimes', Type => 'Node' },
    '060e2b34.0101.0101.07020103.03010000' => { Name => 'EventStartTimeOffset', Format => 'string' },
    '060e2b34.0101.0101.07020103.03020000' => { Name => 'EventStartTimecodeOffset', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020103.04000000' => { Name => 'EventEndRelativeTimes', Type => 'Node' },
    '060e2b34.0101.0101.07020103.04010000' => { Name => 'EventEndTimeOffset', Format => 'string' },
    '060e2b34.0101.0101.07020103.04020000' => { Name => 'EventEndTimecodeOffset', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020103.10000000' => { Name => 'Offsets', Type => 'Node' },
  # '060e2b34.0101.0101.07020103.10010000' => { Name => 'MaterialOffsets', Type => 'Node' },
    '060e2b34.0101.0101.07020103.10010100' => { Name => 'FrameCountOffset', Format => 'int32u' },
  # '060e2b34.0101.0101.07020108.00000000' => { Name => 'SettingDateAndTime', Type => 'Node' },
    '060e2b34.0101.0101.07020108.01000000' => { Name => 'TimePeriodName', Format => 'string' },
  # '060e2b34.0101.0101.07020110.00000000' => { Name => 'ProcessDateTime', Type => 'Node' },
  # '060e2b34.0101.0101.07020110.01000000' => { Name => 'CreateDate', Type => 'Node' },
    '060e2b34.0101.0101.07020110.01010000' => { Name => 'LocalCreationDateTime', Format => 'string', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0101.07020110.01020000' => { Name => 'TimecodeCreationDateTime', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020110.02000000' => { Name => 'ModifyDate', Type => 'Node' },
    '060e2b34.0101.0101.07020110.02010000' => { Name => 'LocalModifyDate', Format => 'string', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0101.07020110.02020000' => { Name => 'TimecodeModifyDate', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020200.00000000' => { Name => 'Durations', Type => 'Node' },
  # '060e2b34.0101.0101.07020201.00000000' => { Name => 'AbsoluteDurations', Type => 'Node' },
  # '060e2b34.0101.0101.07020201.01000000' => { Name => 'EditTimelineDurations', Type => 'Node' },
    '060e2b34.0101.0101.07020201.01010000' => { Name => 'FrameCount', Format => 'int32u' },
  # '060e2b34.0101.0101.07020201.01040000' => { Name => 'VideoDurations', Type => 'Node' },
  # '060e2b34.0101.0101.07020201.01050000' => { Name => 'AudioDurations', Type => 'Node' },
  # '060e2b34.0101.0101.07020201.02000000' => { Name => 'MaterialAbsoluteDurations', Type => 'Node' },
    '060e2b34.0101.0101.07020201.02010000' => { Name => 'MaterialAbsoluteDuration', Format => 'string' },
    '060e2b34.0101.0101.07020201.02020000' => { Name => 'MaterialAbsoluteDuration', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
    '060e2b34.0101.0101.07020201.02030000' => { Name => 'TextlessBlackDuration', Format => 'int32u' },
  # '060e2b34.0101.0101.07020201.03000000' => { Name => 'EventAbsoluteDurations', Type => 'Node' },
    '060e2b34.0101.0101.07020201.03010000' => { Name => 'EventAbsoluteDurationFrameCount', Format => 'int32u' },
    '060e2b34.0101.0101.07020201.03020000' => { Name => 'EventAbsoluteDuration', Format => 'string' },
    '060e2b34.0101.0101.07020201.03030000' => { Name => 'EventAbsoluteDuration', Type => 'UILSBF', Unknown => 1, Groups => { 2 => 'Time' } },
  # '060e2b34.0101.0101.07020202.00000000' => { Name => 'RelativeScalingDurations', Type => 'Node' },
  # '060e2b34.0101.0101.07020300.00000000' => { Name => 'Delay', Type => 'Node' },
  # '060e2b34.0101.0101.07020301.00000000' => { Name => 'EncodingAndDecoding', Type => 'Node' },
  # '060e2b34.0101.0101.07020301.01000000' => { Name => 'CodecDelay', Type => 'Node' },
  # '060e2b34.0101.0101.07020301.02000000' => { Name => 'EncodingDelay', Type => 'Node' },
  # '060e2b34.0101.0101.07020301.03000000' => { Name => 'DecodingDelay', Type => 'Node' },
    '060e2b34.0101.0101.07020301.03010000' => { Name => 'BufferDelay', Unknown => 1 },
  # '060e2b34.0101.0101.07020500.00000000' => { Name => 'Latency', Type => 'Node' },
  # '060e2b34.0101.0101.07020600.00000000' => { Name => 'ShutterCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.07020601.00000000' => { Name => 'ShutterCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0101.07020601.01000000' => { Name => 'ShutterSpeed', Type => 'Node' },
  # '060e2b34.0101.0101.07020601.02000000' => { Name => 'ShutterGating', Type => 'Node' },
  # '060e2b34.0101.0101.0d000000.00000000' => { Name => 'UserOrganizationRegisteredForPublicUse', Type => 'Node' },
  # '060e2b34.0101.0101.0d010000.00000000' => { Name => 'AAFAssociation', Type => 'Node' },
  # '060e2b34.0101.0101.0d010100.00000000' => { Name => 'AAFAttributes', Type => 'Node' },
  # '060e2b34.0101.0101.0d010101.00000000' => { Name => 'AAFInformationAttributes', Type => 'Node' },
  # '060e2b34.0101.0101.0d010101.01000000' => { Name => 'AAFInformationAttributesVersion1', Type => 'Node' },
  # '060e2b34.0101.0101.0d010101.01010000' => { Name => 'EnumeratedAttributes', Type => 'Node' },

    # tags from ref 4 (untested)
    '060e2b34.0101.0101.0d010401.03010100' => { Name => 'ProgramIdentifier', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d010401.03010200' => { Name => 'ProgramIdentifierString', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d010401.03010300' => { Name => 'ShimName', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d010401.03010400' => { Name => 'SignalStandard', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d010401.03010500' => { Name => 'IntendedAFD', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d010401.03010600' => { Name => 'SlateTitle', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d010401.03010700' => { Name => 'NOLACode', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d010401.03010800' => { Name => 'Rating', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d010401.03010900' => { Name => 'NielsenStreamIdentifier', Type => 'UTF-16' },

  # '060e2b34.0101.0101.0d0b0100.00000000' => { Name => 'ProductionFramework', Type => 'Node' },
    '060e2b34.0101.0101.0d0b0101.00000000' => { Name => 'IsRecording', Type => 'Boolean' },
    '060e2b34.0101.0101.0d0b0102.00000000' => { Name => 'IsLiveProduction', Type => 'Boolean' },
    '060e2b34.0101.0101.0d0b0103.00000000' => { Name => 'IsLiveTransmission', Type => 'Boolean' },
    '060e2b34.0101.0101.0d0b0104.00000000' => { Name => 'IsDubbed', Type => 'Boolean' },
    '060e2b34.0101.0101.0d0b0105.00000000' => { Name => 'IsVoiceover', Type => 'Boolean' },
    '060e2b34.0101.0101.0d0b0106.00000000' => { Name => 'HasAudioWatermark', Type => 'Boolean', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0101.0d0b0107.00000000' => { Name => 'AudioWatermarkKind', Type => 'UTF-16', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0101.0d0b0108.00000000' => { Name => 'HasVideoWatermark', Type => 'Boolean' },
    '060e2b34.0101.0101.0d0b0109.00000000' => { Name => 'VideoWatermarkKind', Type => 'UTF-16' },
  # '060e2b34.0101.0101.0d0b0200.00000000' => { Name => 'Subtitling', Type => 'Node' },
    '060e2b34.0101.0101.0d0b0201.00000000' => { Name => 'SubtitlesPresent', Type => 'Boolean' },
  # '060e2b34.0101.0101.0d0b0300.00000000' => { Name => 'CaptionTitles', Type => 'Node' },
    '060e2b34.0101.0101.0d0b0301.00000000' => { Name => 'CaptionTitles', Type => 'Boolean' },
    '060e2b34.0101.0101.0d0b0302.00000000' => { Name => 'CaptionsViaTeletext', Type => 'Boolean' },
    '060e2b34.0101.0101.0d0b0303.00000000' => { Name => 'TextlessMaterial', Type => 'Boolean' },
  # '060e2b34.0101.0101.0d0b0400.00000000' => { Name => 'AudioParameters', Type => 'Node' },
    '060e2b34.0101.0101.0d0b0401.00000000' => { Name => 'AudioReferenceLevel', Format => 'string', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0101.0d0b0500.00000000' => { Name => 'StorageMedia', Type => 'Node' },
    '060e2b34.0101.0101.0d0b0501.00000000' => { Name => 'StorageDeviceKind', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0502.00000000' => { Name => 'StorageMediaKind', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0503.00000000' => { Name => 'StorageMediaID', Type => 'UTF-16' },
  # '060e2b34.0101.0101.0d0b0600.00000000' => { Name => 'BroadcastScheduleInformation', Type => 'Node' },
    '060e2b34.0101.0101.0d0b0601.00000000' => { Name => 'BroadcastDate', %timestamp },
    '060e2b34.0101.0101.0d0b0602.00000000' => { Name => 'BroadcastTime', %timestamp },
    '060e2b34.0101.0101.0d0b0603.00000000' => { Name => 'IsRepeat', Type => 'Boolean' },
    '060e2b34.0101.0101.0d0b0604.00000000' => { Name => 'FirstTransmissionInfo', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0605.00000000' => { Name => 'TeletextSubtitlesAvailable', Type => 'Boolean' },
    '060e2b34.0101.0101.0d0b0606.00000000' => { Name => 'SeasonEpisodeNumber', Format => 'string' },
    '060e2b34.0101.0101.0d0b0607.00000000' => { Name => 'SeasonEpisodeTitle', Format => 'string' },
    '060e2b34.0101.0101.0d0b0608.00000000' => { Name => 'EPGProgramSynopsis', Type => 'UTF-16' },
  # '060e2b34.0101.0101.0d0b0700.00000000' => { Name => 'Classification', Type => 'Node' },
    '060e2b34.0101.0101.0d0b0701.00000000' => { Name => 'ContentClassification', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0702.00000000' => { Name => 'DVBParentalRating', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0703.00000000' => { Name => 'ContentMaturityRating', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0704.00000000' => { Name => 'ContentMaturityDescription', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0705.00000000' => { Name => 'ContentMaturityGraphic', Type => 'UTF-16' },
  # '060e2b34.0101.0101.0d0b0800.00000000' => { Name => 'Contract', Type => 'Node' },
    '060e2b34.0101.0101.0d0b0801.00000000' => { Name => 'ContractEntity', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0802.00000000' => { Name => 'ContractTypeLink', Type => 'UTF-16' },
  # '060e2b34.0101.0101.0d0b0900.00000000' => { Name => 'Rights', Type => 'Node' },
    '060e2b34.0101.0101.0d0b0901.00000000' => { Name => 'ConsumerRightsToCopy', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0902.00000000' => { Name => 'BroadcasterRightsToCopy', Type => 'UTF-16' },
  # '060e2b34.0101.0101.0d0b0a00.00000000' => { Name => 'ProductionKeyPeople', Type => 'Node' },
    '060e2b34.0101.0101.0d0b0a01.00000000' => { Name => 'DirectorName', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0a02.00000000' => { Name => 'ProducerName', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0a03.00000000' => { Name => 'FemaleLeadActressName', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0a04.00000000' => { Name => 'MaleLeadActorName', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0a05.00000000' => { Name => 'PresenterName', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0a06.00000000' => { Name => 'MainSponsorName', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0a07.00000000' => { Name => 'VoiceTalentName', Type => 'UTF-16' },
  # '060e2b34.0101.0101.0d0b0b00.00000000' => { Name => 'Address', Type => 'Node' },
    '060e2b34.0101.0101.0d0b0b01.00000000' => { Name => 'PostboxNumber', Type => 'UTF-16' },
    '060e2b34.0101.0101.0d0b0b02.00000000' => { Name => 'PostCodeForPostbox', Type => 'UTF-16' },
  # '060e2b34.0101.0101.0e000000.00000000' => { Name => 'PrivateUse', Type => 'Node' },
  # '060e2b34.0101.0101.0e010000.00000000' => { Name => 'MISBSystems', Type => 'Node' },
  # '060e2b34.0101.0101.0e010100.00000000' => { Name => 'MISBSystemsStreams', Type => 'Node' },
  # '060e2b34.0101.0101.0e010200.00000000' => { Name => 'MISBSystemsAttributes', Type => 'Node' },
  # '060e2b34.0101.0101.0e010300.00000000' => { Name => 'MISBSystemsComposites', Type => 'Node' },
  # '060e2b34.0101.0101.0e010400.00000000' => { Name => 'MISBSystemsIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0101.0e020000.00000000' => { Name => 'ASPA', Type => 'Node' },
  # '060e2b34.0101.0101.0e020100.00000000' => { Name => 'ASPAStreams', Type => 'Node' },
  # '060e2b34.0101.0101.0e020200.00000000' => { Name => 'ASPAAttributes', Type => 'Node' },
  # '060e2b34.0101.0101.0e020201.00000000' => { Name => 'ASPARelationalAttributes', Type => 'Node' },
  # '060e2b34.0101.0101.0e020202.00000000' => { Name => 'ASPAInformationAttributes', Type => 'Node' },
  # '060e2b34.0101.0101.0e020300.00000000' => { Name => 'ASPAComposites', Type => 'Node' },
  # '060e2b34.0101.0101.0e020400.00000000' => { Name => 'ASPAIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0101.0e030000.00000000' => { Name => 'MISBClassified', Type => 'Node' },
  # '060e2b34.0101.0101.0e030100.00000000' => { Name => 'MISBClassifiedStreams', Type => 'Node' },
  # '060e2b34.0101.0101.0e030200.00000000' => { Name => 'MISBClassifiedAttributes', Type => 'Node' },
  # '060e2b34.0101.0101.0e030300.00000000' => { Name => 'MISBClassifiedComposites', Type => 'Node' },
  # '060e2b34.0101.0101.0e030400.00000000' => { Name => 'MISBClassifiedIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0101.0f000000.00000000' => { Name => 'EXPERIMENTALMETADATA', Type => 'Node' },
  # '060e2b34.0101.0101.43000000.00000000' => { Name => 'Legacy315M', Type => 'Node' },
    '060e2b34.0101.0102.01011003.03000000' => { Name => 'ProgramNumber', Format => 'string' },
    '060e2b34.0101.0102.01011503.00000000' => { Name => 'DefinitionObjectID', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.01012005.00000000' => { Name => 'IEEEDeviceID', Format => 'int8u' },
    '060e2b34.0101.0102.01030106.00000000' => { Name => 'ProjectNumber', Format => 'string' },
    '060e2b34.0101.0102.01030201.02000000' => { Name => 'EdgeCodeHeader', Type => 'DataValue', Unknown => 1 },
  # '060e2b34.0101.0102.01030400.00000000' => { Name => 'NetworkAndStreamIdentifiers', Type => 'Node' },
    '060e2b34.0101.0102.01030401.00000000' => { Name => 'ChannelHandle', Format => 'int16s' },
    '060e2b34.0101.0102.01040102.00000000' => { Name => 'PhysicalMediaLocation', Format => 'string' },
    '060e2b34.0101.0102.01040102.01000000' => { Name => 'MediaLocation', Type => 'UTF-16' },
    '060e2b34.0101.0102.01040103.00000000' => { Name => 'TrackNumber', Format => 'int32u' },
  # '060e2b34.0101.0102.01040900.00000000' => { Name => 'SynchronizationLocators', Type => 'Node' },
    '060e2b34.0101.0102.01040901.00000000' => { Name => 'EdgeCodeStart', Type => 'Position', %duration },
    '060e2b34.0101.0102.01050800.00000000' => { Name => 'VersionTitle', Format => 'string' },
  # '060e2b34.0101.0102.01070000.00000000' => { Name => 'LocalIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0102.01070100.00000000' => { Name => 'PackageIdentifiers', Type => 'Node' },
    '060e2b34.0101.0102.01070101.00000000' => { Name => 'TrackID', Format => 'int32u' },
    '060e2b34.0101.0102.01070102.00000000' => { Name => 'TrackName', Format => 'string' },
    '060e2b34.0101.0102.01070102.01000000' => { Name => 'TrackName', Type => 'UTF-16' },
    '060e2b34.0101.0102.01070102.03000000' => { Name => 'DefinitionObjectName', Format => 'string' },
    '060e2b34.0101.0102.01070102.03010000' => { Name => 'DefinitionObjectName', Type => 'UTF-16' },
    '060e2b34.0101.0102.01070103.00000000' => { Name => 'ContentPackageMetadataLink', Format => 'int8u' },
    '060e2b34.0101.0102.01070104.00000000' => { Name => 'DefinedName', Format => 'string' },
    '060e2b34.0101.0102.01070104.01000000' => { Name => 'DefinedName', Type => 'UTF-16' },
  # '060e2b34.0101.0102.010a0000.00000000' => { Name => 'OrganizationIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0102.010a0100.00000000' => { Name => 'ManufacturerIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0102.010a0101.00000000' => { Name => 'ManufacturerIdentifiers', Type => 'Node' },
    '060e2b34.0101.0102.010a0101.01000000' => { Name => 'DeviceManufacturerName', Format => 'string' },
    '060e2b34.0101.0102.010a0101.01010000' => { Name => 'DeviceManufacturerName', Type => 'UTF-16' },
    '060e2b34.0101.0102.010a0101.03000000' => { Name => 'ManufacturerID', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.010a0102.00000000' => { Name => 'IEEEManufacturerID', Type => 'Hex' },
    '060e2b34.0101.0102.010a0103.00000000' => { Name => 'AAFManufacturerID', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.02010400.00000000' => { Name => 'SupplyingDepartmentName', Format => 'string' },
    '060e2b34.0101.0102.02200303.00000000' => { Name => 'AudienceShare', Format => 'float' },
    '060e2b34.0101.0102.02200304.00000000' => { Name => 'AudienceAppreciation', Format => 'float' },
    '060e2b34.0101.0102.02300603.01050000' => { Name => 'Salutation', Format => 'string' },
    '060e2b34.0101.0102.02300603.01060000' => { Name => 'HonorsAndQualifications', Format => 'string' },
  # '060e2b34.0101.0102.03010200.00000000' => { Name => 'DataInterpretationsAndDefinitions', Type => 'Node' },
    '060e2b34.0101.0102.03010201.04000000' => { Name => 'ObjectModelVersion', Format => 'int32u' },
    '060e2b34.0101.0102.03010201.05000000' => { Name => 'SDKVersion', Type => 'VersionType' },
  # '060e2b34.0101.0102.03010202.00000000' => { Name => 'PropertyDefinitions', Type => 'Node' },
    '060e2b34.0101.0102.03010202.01000000' => { Name => 'IsOptional', Type => 'Boolean' },
    '060e2b34.0101.0102.03010202.02000000' => { Name => 'IsSearchable', Type => 'Boolean' },
  # '060e2b34.0101.0102.03010202.03000000' => { Name => 'PropertyDefaults', Type => 'Node' },
    '060e2b34.0101.0102.03010202.03010000' => { Name => 'UseDefaultValue', Type => 'Boolean' },
    '060e2b34.0101.0102.03010202.03020000' => { Name => 'DefaultDataValue', Type => 'Indirect', Unknown => 1 },
  # '060e2b34.0101.0102.03010203.00000000' => { Name => 'TypeDefinition', Type => 'Node' },
    '060e2b34.0101.0102.03010203.01000000' => { Name => 'Size', Format => 'int8u' },
    '060e2b34.0101.0102.03010203.02000000' => { Name => 'IsSigned', Type => 'Boolean' },
    '060e2b34.0101.0102.03010203.03000000' => { Name => 'ElementCount', Format => 'int32u' },
    '060e2b34.0101.0102.03010203.04000000' => { Name => 'ElementNameList', Type => 'UTF-16' },
    '060e2b34.0101.0102.03010203.05000000' => { Name => 'TypeDefinitionElementValueList', Format => 'int64s' },
    '060e2b34.0101.0102.03010203.06000000' => { Name => 'MemberNameList', Type => 'UTF-16' },
    '060e2b34.0101.0102.03010203.07000000' => { Name => 'ExtendibleElementNameList', Type => 'UTF-16' },
    '060e2b34.0101.0102.03010203.08000000' => { Name => 'TypeDefinitionExtendibleElementValues', Type => 'AUIDArray', Unknown => 1 },
    '060e2b34.0101.0102.03010203.0b000000' => { Name => 'TargetSet', Type => 'AUIDArray', Unknown => 1 },
  # '060e2b34.0101.0102.03010210.00000000' => { Name => 'KLVInterpretations', Type => 'Node' },
    '060e2b34.0101.0102.03010210.01000000' => { Name => 'FillerData', Format => 'undef', Unknown => 1 },
    '060e2b34.0101.0102.03010210.02000000' => { Name => 'KLVDataValue', Type => 'Opaque', Unknown => 1 },
    '060e2b34.0101.0102.03010210.03000000' => { Name => 'PackageKLVData', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.03010210.04000000' => { Name => 'ComponentKLVData', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.03020102.09000000' => { Name => 'AssignedCategoryName', Format => 'string' },
    '060e2b34.0101.0102.03020102.09010000' => { Name => 'AssignedCategoryName', Type => 'UTF-16' },
    '060e2b34.0101.0102.03020102.0a000000' => { Name => 'AssignedCategoryValue', Format => 'string' },
    '060e2b34.0101.0102.03020102.0a010000' => { Name => 'AssignedCategoryValue', Type => 'UTF-16' },
    '060e2b34.0101.0102.03020102.0b000000' => { Name => 'ShotList', Format => 'string' },
    '060e2b34.0101.0102.03020102.0c000000' => { Name => 'PackageUserComments', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.03020102.0d000000' => { Name => 'Cue-InWords', Format => 'string' },
    '060e2b34.0101.0102.03020102.0e000000' => { Name => 'Cue-OutWords', Format => 'string' },
    '060e2b34.0101.0102.03020301.01000000' => { Name => 'ObjectKind', Format => 'string' },
    '060e2b34.0101.0102.03020301.01010000' => { Name => 'ObjectKind', Type => 'UTF-16' },
    '060e2b34.0101.0102.03020301.02000000' => { Name => 'ObjectDescription', Format => 'string' },
    '060e2b34.0101.0102.03020301.02010000' => { Name => 'ObjectDescription', Type => 'UTF-16' },
  # '060e2b34.0101.0102.03020400.00000000' => { Name => 'DescriptiveNames', Type => 'Node' },
  # '060e2b34.0101.0102.03020401.01000000' => { Name => 'GenericObjectNames', Type => 'Node' },
    '060e2b34.0101.0102.03020401.01010000' => { Name => 'ObjectName', Format => 'string' },
    '060e2b34.0101.0102.03020401.02010000' => { Name => 'MetadataItemName', Type => 'UTF-16' },
  # '060e2b34.0101.0102.03020500.00000000' => { Name => 'EditorialCommentsAndDescriptions', Type => 'Node' },
    '060e2b34.0101.0102.03020501.00000000' => { Name => 'ShotCommentKind', Format => 'string' },
    '060e2b34.0101.0102.03020502.00000000' => { Name => 'ShotComment', Format => 'string' },
    '060e2b34.0101.0102.03030301.01000000' => { Name => 'ComputedObjectKind', Format => 'string' },
    '060e2b34.0101.0102.03030301.01010000' => { Name => 'ComputedObjectKind', Type => 'UTF-16' },
    '060e2b34.0101.0102.03030301.02000000' => { Name => 'VersionNumberString', Format => 'string' },
    '060e2b34.0101.0102.03030301.02010000' => { Name => 'VersionNumberString', Type => 'UTF-16' },
    '060e2b34.0101.0102.03030301.03000000' => { Name => 'VersionNumber', Type => 'VersionType' },
  # '060e2b34.0101.0102.03030302.00000000' => { Name => 'DerivedSummaryInformation', Type => 'Node' },
    '060e2b34.0101.0102.03030302.01000000' => { Name => 'WAVESummary', Type => 'DataValue', Unknown => 1 },
    '060e2b34.0101.0102.03030302.02000000' => { Name => 'AIFCSummary', Type => 'DataValue', Unknown => 1 },
    '060e2b34.0101.0102.03030302.03000000' => { Name => 'TIFFSummary', Type => 'DataValue', Unknown => 1 },
    '060e2b34.0101.0102.04010101.03000000' => { Name => 'ViewportAspectRatio', Format => 'rational64s' },
    '060e2b34.0101.0102.04010201.01010200' => { Name => 'CaptureGammaEquation', Type => 'UL', Unknown => 1 },
    '060e2b34.0101.0102.04010201.01030100' => { Name => 'ColorimetryCode', Type => 'ColorimetryCode', Unknown => 1 },
    '060e2b34.0101.0102.04010201.01100000' => { Name => 'PresentationGammaEquation', Format => 'string' },
    '060e2b34.0101.0102.04010201.01100100' => { Name => 'PresentationGammaEquation', Type => 'PresentationGamma', Unknown => 1 },
    '060e2b34.0101.0102.04010301.06000000' => { Name => 'FieldDominance', Format => 'int8u' },
    '060e2b34.0101.0102.04010302.05000000' => { Name => 'VideoLineMap', Format => 'int32s' },
    '060e2b34.0101.0102.04010401.01000000' => { Name => 'AnalogVideoSystemName', Type => 'VideoSignalType', Unknown => 1 },
    '060e2b34.0101.0102.04010501.10000000' => { Name => 'VerticalSub-sampling', Format => 'int32u' },
    '060e2b34.0101.0102.04010503.01010000' => { Name => 'BitsPerPixel', Format => 'int32u' },
    '060e2b34.0101.0102.04010503.05000000' => { Name => 'ColorRangeLevels', Format => 'int32u' },
    '060e2b34.0101.0102.04010503.06000000' => { Name => 'PixelLayout', Type => 'RGBALayout', Unknown => 1 },
    '060e2b34.0101.0102.04010503.07000000' => { Name => 'AlphaSampleDepth', Format => 'int32u' },
    '060e2b34.0101.0102.04010503.08000000' => { Name => 'Palette', Type => 'DataValue', Unknown => 1 },
    '060e2b34.0101.0102.04010503.09000000' => { Name => 'PaletteLayout', Type => 'RGBALayout', Unknown => 1 },
    '060e2b34.0101.0102.04010503.0a000000' => { Name => 'ComponentDepth', Format => 'int32u' },
    '060e2b34.0101.0102.04010601.00000000' => { Name => 'VideoCodingSchemeID', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.04010802.03000000' => { Name => 'RoundedCaptureFilmFrameRate', Format => 'int32u' },
    '060e2b34.0101.0102.04020301.02000000' => { Name => 'AudioAverageBitrate', Format => 'float', PrintConv => 'ConvertBitrate($val)', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0102.04020301.03000000' => { Name => 'AudioFixedBitrateFlag', Type => 'Boolean', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0102.04020401.00000000' => { Name => 'CodingLawKind', Format => 'string' },
    '060e2b34.0101.0102.04020402.00000000' => { Name => 'AudioCodingSchemeID', Type => 'AUID', Unknown => 1, Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0102.04020403.01010000' => { Name => 'LayerNumber', Format => 'int8u' },
    '060e2b34.0101.0102.04040101.02010000' => { Name => 'TimecodeTimebase', Format => 'rational64s' },
    '060e2b34.0101.0102.04040101.02060000' => { Name => 'RoundedTimecodeTimebase', Format => 'int16u' },
  # '060e2b34.0101.0102.04070000.00000000' => { Name => 'GeneralEssenceAndDataParameters', Type => 'Node' },
    '060e2b34.0101.0102.04070100.00000000' => { Name => 'ComponentDataDefinition', Type => 'WeakReference', %componentDataDef },
    '060e2b34.0101.0102.04070200.00000000' => { Name => 'StreamData', Type => 'DataStream', Unknown => 1 },
    '060e2b34.0101.0102.04070300.00000000' => { Name => 'TimecodeStreamData', Type => 'DataStream', Unknown => 1 },
    '060e2b34.0101.0102.04090101.00000000' => { Name => 'RecordedFormat', Type => 'UTF-16' },
    '060e2b34.0101.0102.04100101.01000000' => { Name => 'TapeShellKind', Format => 'string' },
    '060e2b34.0101.0102.04100101.01010000' => { Name => 'TapeShellKind', Type => 'UTF-16' },
    '060e2b34.0101.0102.04100101.02000000' => { Name => 'TapeFormulation', Format => 'string' },
    '060e2b34.0101.0102.04100101.02010000' => { Name => 'TapeFormulation', Type => 'UTF-16' },
    '060e2b34.0101.0102.04100101.03000000' => { Name => 'TapeCapacity', Format => 'int32u' },
    '060e2b34.0101.0102.04100101.04000000' => { Name => 'TapeManufacturer', Format => 'string' },
    '060e2b34.0101.0102.04100101.04010000' => { Name => 'TapeManufacturer', Type => 'UTF-16' },
    '060e2b34.0101.0102.04100101.05000000' => { Name => 'TapeStock', Format => 'string' },
    '060e2b34.0101.0102.04100101.05010000' => { Name => 'TapeStock', Type => 'UTF-16' },
    '060e2b34.0101.0102.04100101.06000000' => { Name => 'TapeBatchNumber', Format => 'string' },
    '060e2b34.0101.0102.04100101.06010000' => { Name => 'TapeBatchNumber', Type => 'UTF-16' },
    '060e2b34.0101.0102.04100103.01030000' => { Name => 'PerforationsPerFrame', Format => 'int8u' },
    '060e2b34.0101.0102.04100103.01030100' => { Name => 'PerforationsPerFrame', Format => 'rational64s' },
    '060e2b34.0101.0102.04100103.01040100' => { Name => 'FilmFormatName', Type => 'UTF-16' },
    '060e2b34.0101.0102.04100103.01040200' => { Name => 'FilmFormatName', Type => 'FilmFormat', Unknown => 1 },
    '060e2b34.0101.0102.04100103.01050100' => { Name => 'FilmStockKind', Type => 'UTF-16' },
    '060e2b34.0101.0102.04100103.01060100' => { Name => 'FilmStockManufacturerName', Type => 'UTF-16' },
    '060e2b34.0101.0102.04100103.01070000' => { Name => 'FilmBatchNumber', Format => 'string' },
    '060e2b34.0101.0102.04100103.01070100' => { Name => 'FilmBatchNumber', Type => 'UTF-16' },
    '060e2b34.0101.0102.04100103.01080000' => { Name => 'FilmGauge', Type => 'FilmType', Unknown => 1 },
    '060e2b34.0101.0102.04100103.01090000' => { Name => 'EdgeCodeFilmGauge', Type => 'FilmType', Unknown => 1 },
    '060e2b34.0101.0102.04100103.02030000' => { Name => 'ExposedAspectRatio', Format => 'rational64s' },
  # '060e2b34.0101.0102.04180000.00000000' => { Name => 'MemoryStorageCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0102.04180100.00000000' => { Name => 'MemoryStorageAlignmentCharacteristics', Type => 'Node' },
    '060e2b34.0101.0102.04180101.00000000' => { Name => 'ImageAlignmentOffset', Format => 'int32u' },
    '060e2b34.0101.0102.04180102.00000000' => { Name => 'ImageStartOffset', Format => 'int32u' },
    '060e2b34.0101.0102.04180103.00000000' => { Name => 'ImageEndOffset', Format => 'int32u' },
    '060e2b34.0101.0102.04180104.00000000' => { Name => 'PaddingBits', Format => 'int16s' },
    '060e2b34.0101.0102.04200201.01040000' => { Name => 'FocalLength', Format => 'float', PrintConv => 'sprintf("%.1f mm",$val)' },
    '060e2b34.0101.0102.04200201.01050000' => { Name => 'SensorSize', Format => 'string' },
    '060e2b34.0101.0102.04200201.01060000' => { Name => 'FNumber', Format => 'float' },
    '060e2b34.0101.0102.04200201.01070000' => { Name => 'SensorTypeCode', Format => 'string' },
    '060e2b34.0101.0102.04200201.01080000' => { Name => 'FieldOfViewHorizontal', Format => 'float' },
    '060e2b34.0101.0102.04200201.01090000' => { Name => 'AnamorphicLensCharacteristic', Format => 'string' },
  # '060e2b34.0101.0102.05020103.00000000' => { Name => 'JPEGProcessing', Type => 'Node' },
  # '060e2b34.0101.0102.05020103.01000000' => { Name => 'TIFFJPEGProcessing', Type => 'Node' },
    '060e2b34.0101.0102.05020103.01010000' => { Name => 'UniformDataFlag', Type => 'Boolean' },
    '060e2b34.0101.0102.05020103.01020000' => { Name => 'JPEGTableID', Type => 'JPEGTableIDType', Unknown => 1 },
  # '060e2b34.0101.0102.05020103.02000000' => { Name => 'JFIF_JPEGProcessing', Type => 'Node' },
    '060e2b34.0101.0102.05200102.00000000' => { Name => 'AlphaTransparency', Format => 'int8u',
        PrintConv => { 0 => 'Not Inverted', 1 => 'Inverted' },
    },
  # '060e2b34.0101.0102.05200701.00000000' => { Name => 'ModificationInformation', Type => 'Node' },
    '060e2b34.0101.0102.05200701.01000000' => { Name => 'GenerationID', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.05200701.02000000' => { Name => 'ApplicationSupplierName', Format => 'string' },
    '060e2b34.0101.0102.05200701.02010000' => { Name => 'ApplicationSupplierName', Type => 'UTF-16' },
    '060e2b34.0101.0102.05200701.03000000' => { Name => 'ApplicationName', Format => 'string' },
    '060e2b34.0101.0102.05200701.03010000' => { Name => 'ApplicationName', Type => 'UTF-16' },
    '060e2b34.0101.0102.05200701.04000000' => { Name => 'ApplicationVersionNumber', Type => 'ProductVersion' },
    '060e2b34.0101.0102.05200701.05000000' => { Name => 'ApplicationVersionString', Format => 'string' },
    '060e2b34.0101.0102.05200701.05010000' => { Name => 'ApplicationVersionString', Type => 'UTF-16' },
    '060e2b34.0101.0102.05200701.06000000' => { Name => 'ApplicationPlatform', Format => 'string' },
    '060e2b34.0101.0102.05200701.06010000' => { Name => 'ApplicationPlatform', Type => 'UTF-16' },
    '060e2b34.0101.0102.05200701.07000000' => { Name => 'ApplicationProductID', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.05200701.08000000' => { Name => 'LinkedGenerationID', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.05200701.09000000' => { Name => 'ContainerVersion', Type => 'ProductVersion' },
    '060e2b34.0101.0102.05200701.0a000000' => { Name => 'ToolkitVersion', Type => 'ProductVersion' },
  # '060e2b34.0101.0102.05200900.00000000' => { Name => 'CodeProcessorSettings', Type => 'Node' },
    '060e2b34.0101.0102.05200901.00000000' => { Name => 'Plug-InCategoryID', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.05200902.00000000' => { Name => 'Plug-InPlatformID', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.05200903.00000000' => { Name => 'MinimumSupportedPlatformVersion', Type => 'VersionType' },
    '060e2b34.0101.0102.05200904.00000000' => { Name => 'MaximumSupportedPlatformVersion', Type => 'VersionType' },
    '060e2b34.0101.0102.05200905.00000000' => { Name => 'Plug-InEngineID', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.05200906.00000000' => { Name => 'MinimumSupportedEngineVersion', Type => 'VersionType' },
    '060e2b34.0101.0102.05200907.00000000' => { Name => 'MaximumSupportedEngineVersion', Type => 'VersionType' },
    '060e2b34.0101.0102.05200908.00000000' => { Name => 'Plug-InAPIID', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.05200909.00000000' => { Name => 'MinimumAPIVersion', Type => 'VersionType' },
    '060e2b34.0101.0102.0520090a.00000000' => { Name => 'MaximumAPIVersion', Type => 'VersionType' },
    '060e2b34.0101.0102.0520090b.00000000' => { Name => 'Software-OnlySupportFlag', Type => 'Boolean' },
    '060e2b34.0101.0102.0520090c.00000000' => { Name => 'HardwareAcceleratorFlag', Type => 'Boolean' },
    '060e2b34.0101.0102.0520090d.00000000' => { Name => 'Plug-InLocatorSet', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.0520090e.00000000' => { Name => 'AuthenticationFlag', Type => 'Boolean' },
    '060e2b34.0101.0102.0520090f.00000000' => { Name => 'AssociatedMetadataDefinition', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.05300402.00000000' => { Name => 'EventTrackEditRate', Format => 'rational64s' },
    '060e2b34.0101.0102.05300403.00000000' => { Name => 'DefaultFadeEditRate', Format => 'rational64s' },
    '060e2b34.0101.0102.05300404.00000000' => { Name => 'EditingEventComment', Format => 'string' },
    '060e2b34.0101.0102.05300404.01000000' => { Name => 'EditingEventComment', Type => 'UTF-16' },
    '060e2b34.0101.0102.05300405.00000000' => { Name => 'EditRate', Format => 'rational64s' },
    '060e2b34.0101.0102.05300506.00000000' => { Name => 'OperationDefinitionID', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.05300507.00000000' => { Name => 'Value', Type => 'Indirect', Unknown => 1 },
    '060e2b34.0101.0102.05300508.00000000' => { Name => 'EditHint', Type => 'EditHintType', Unknown => 1 },
    '060e2b34.0101.0102.05300509.00000000' => { Name => 'OperationDataDefinition', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.0530050a.00000000' => { Name => 'OperationCategory', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.0530050b.00000000' => { Name => 'DisplayUnits', Format => 'string' },
    '060e2b34.0101.0102.0530050b.01000000' => { Name => 'DisplayUnits', Type => 'UTF-16' },
    '060e2b34.0101.0102.0530050c.00000000' => { Name => 'BypassOverride', Format => 'int32u' },
    '060e2b34.0101.0102.0530050d.00000000' => { Name => 'TimepointValue', Type => 'Indirect', Unknown => 1 },
    '060e2b34.0101.0102.05300601.00000000' => { Name => 'BeginAnchor', Format => 'string' },
    '060e2b34.0101.0102.05300601.01000000' => { Name => 'BeginAnchor', Type => 'UTF-16' },
    '060e2b34.0101.0102.05300602.00000000' => { Name => 'EndAnchor', Format => 'string' },
    '060e2b34.0101.0102.05300602.01000000' => { Name => 'EndAnchor', Type => 'UTF-16' },
  # '060e2b34.0101.0102.05401000.00000000' => { Name => 'TransferHistory', Type => 'Node' },
  # '060e2b34.0101.0102.05401001.00000000' => { Name => 'ImageTransferHistory', Type => 'Node' },
    '060e2b34.0101.0102.05401001.01000000' => { Name => 'FilmToVideoTransferDirection', Type => 'PulldownDirection', Unknown => 1 },
    '060e2b34.0101.0102.05401001.02000000' => { Name => 'FilmToVideoTransferKind', Type => 'PulldownKind', Unknown => 1 },
    '060e2b34.0101.0102.05401001.03000000' => { Name => 'FilmToVideoTransferPhase', Type => 'PhaseFrameType', Unknown => 1 },
    '060e2b34.0101.0102.06010101.01000000' => { Name => 'TeletextSubtitlesFlag', Type => 'Boolean' },
    '060e2b34.0101.0102.06010101.02000000' => { Name => 'SubtitleDatafileFlag', Type => 'Boolean' },
    '060e2b34.0101.0102.06010101.03000000' => { Name => 'ClosedCaptionSubtitlesFlag', Type => 'Boolean' },
    '060e2b34.0101.0102.06010102.01000000' => { Name => 'SampleIndex', Type => 'DataStream', Unknown => 1 },
    '060e2b34.0101.0102.06010103.01000000' => { Name => 'SourcePackageID', Type => 'PackageID', Unknown => 1 },
    '060e2b34.0101.0102.06010103.02000000' => { Name => 'SourceTrackID', Format => 'int32u' },
    '060e2b34.0101.0102.06010103.03000000' => { Name => 'RelativeScope', Format => 'int32u' },
    '060e2b34.0101.0102.06010103.04000000' => { Name => 'RelativeTrack', Format => 'int32u' },
  # '060e2b34.0101.0102.06010104.01000000' => { Name => 'WeakReferences', Type => 'Node' },
    '060e2b34.0101.0102.06010104.01010000' => { Name => 'ObjectClass', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.01020000' => { Name => 'EssenceContainerFormat', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.01030000' => { Name => 'CodecDefinition', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.01040000' => { Name => 'ParameterDefinition', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.01050000' => { Name => 'Interpolation', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.01060000' => { Name => 'ParameterDataType', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.01070000' => { Name => 'CodecEssenceDescriptor', Type => 'WeakReference', Unknown => 1 },
  # '060e2b34.0101.0102.06010104.02000000' => { Name => 'StrongReferences', Type => 'Node' },
    '060e2b34.0101.0102.06010104.02010000' => { Name => 'ContentStorage', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.02020000' => { Name => 'Dictionary', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.02030000' => { Name => 'EssenceDescription', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.02040000' => { Name => 'Sequence', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.02050000' => { Name => 'TransitionEffect', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.02060000' => { Name => 'EffectRendering', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.02070000' => { Name => 'InputSegment', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.02080000' => { Name => 'StillFrame', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.02090000' => { Name => 'Selected', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.020a0000' => { Name => 'Annotation', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0102.06010104.020b0000' => { Name => 'ManufacturerInformationObject', Type => 'StrongReference', Unknown => 1 },
  # '060e2b34.0101.0102.06010104.03000000' => { Name => 'WeakReferencesBatches', Type => 'Node' },
    '060e2b34.0101.0102.06010104.03010000' => { Name => 'CodecEssenceKinds', Type => 'WeakReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0102.06010104.03020000' => { Name => 'OperationParameters', Type => 'WeakReferenceBatch', Unknown => 1 },
  # '060e2b34.0101.0102.06010104.04000000' => { Name => 'WeakReferencesArrays', Type => 'Node' },
    '060e2b34.0101.0102.06010104.04010000' => { Name => 'DegradedEffects', Type => 'WeakReferenceArray', Unknown => 1 },
  # '060e2b34.0101.0102.06010104.05000000' => { Name => 'StrongReferencesBatches', Type => 'Node' },
    '060e2b34.0101.0102.06010104.05010000' => { Name => 'Packages', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0102.06010104.05020000' => { Name => 'EssenceData', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0102.06010104.05030000' => { Name => 'OperationDefinitions', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0102.06010104.05040000' => { Name => 'ParameterDefinitions', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0102.06010104.05050000' => { Name => 'DataDefinitions', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0102.06010104.05060000' => { Name => 'Plug-InDefinitions', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0102.06010104.05070000' => { Name => 'CodecDefinitions', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0102.06010104.05080000' => { Name => 'ContainerDefinitions', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0102.06010104.05090000' => { Name => 'InterpolationDefinitions', Type => 'StrongReferenceBatch', Unknown => 1 },
  # '060e2b34.0101.0102.06010104.06000000' => { Name => 'StrongReferencesArrays', Type => 'Node' },
    '060e2b34.0101.0102.06010104.06010000' => { Name => 'AvailableRepresentations', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.06010104.06020000' => { Name => 'InputSegments', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.06010104.06030000' => { Name => 'EssenceLocators', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.06010104.06040000' => { Name => 'IdentificationList', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.06010104.06050000' => { Name => 'Tracks', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.06010104.06060000' => { Name => 'ControlPointList', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.06010104.06070000' => { Name => 'PackageTracks', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.06010104.06080000' => { Name => 'Alternates', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.06010104.06090000' => { Name => 'ComponentsInSequence', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.06010104.060a0000' => { Name => 'Parameters', Type => 'StrongReferenceBatch', Unknown => 1 },
  # '060e2b34.0101.0102.06010106.00000000' => { Name => 'EssenceToObjectRelationships', Type => 'Node' },
    '060e2b34.0101.0102.06010106.01000000' => { Name => 'LinkedPackageID', Type => 'PackageID', Unknown => 1 },
  # '060e2b34.0101.0102.06010107.00000000' => { Name => 'ObjectDictionaryToMetadataRelationships', Type => 'Node' },
    '060e2b34.0101.0102.06010107.01000000' => { Name => 'ParentClass', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010107.02000000' => { Name => 'Properties', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0102.06010107.03000000' => { Name => 'IsConcrete', Type => 'Boolean' },
    '060e2b34.0101.0102.06010107.04000000' => { Name => 'PropertyType', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010107.05000000' => { Name => 'LocalID', Format => 'int16u' },
    '060e2b34.0101.0102.06010107.06000000' => { Name => 'IsUniqueIdentifier', Type => 'Boolean' },
    '060e2b34.0101.0102.06010107.07000000' => { Name => 'ClassDefinitions', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0102.06010107.08000000' => { Name => 'TypeDefinitions', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0102.06010107.09000000' => { Name => 'TargetClassOfStrongReference', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010107.0a000000' => { Name => 'TargetClassOfWeakReference', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010107.0b000000' => { Name => 'EnumerationUnderlyingIntegerType', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010107.0c000000' => { Name => 'FixedArrayElementType', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010107.0d000000' => { Name => 'VariableArrayElementType', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010107.0e000000' => { Name => 'SetElementType', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010107.0f000000' => { Name => 'StringElementType', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010107.10000000' => { Name => 'StreamElementType', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010107.11000000' => { Name => 'MemberTypes', Type => 'WeakReferenceArray', Unknown => 1 },
    '060e2b34.0101.0102.06010107.12000000' => { Name => 'RenamedType', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0102.06010107.13000000' => { Name => 'DictionaryIdentifier', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0102.06010107.14000000' => { Name => 'DictionaryDescription', Format => 'string' },
    '060e2b34.0101.0102.06010107.14010000' => { Name => 'DictionaryDescription', Type => 'UTF-16' },
  # '060e2b34.0101.0102.06080101.00000000' => { Name => 'ContinuityCounts', Type => 'Node' },
    '060e2b34.0101.0102.06080101.01000000' => { Name => 'BlockContinuityCount', Format => 'int16u' },
  # '060e2b34.0101.0102.06080102.00000000' => { Name => 'StreamPositionalRelationships', Type => 'Node' },
    '060e2b34.0101.0102.06080102.01000000' => { Name => 'StreamPositionIndicator', Format => 'int8u' },
  # '060e2b34.0101.0102.06080202.00000000' => { Name => 'StorageOffsets', Type => 'Node' },
    '060e2b34.0101.0102.07020103.01030000' => { Name => 'Origin', Format => 'int64s', %duration },
    '060e2b34.0101.0102.07020103.01040000' => { Name => 'StartTimeRelativeToReference', Format => 'int64s', %duration },
    '060e2b34.0101.0102.07020103.01050000' => { Name => 'StartTimecode', Format => 'int64s', %duration },
    '060e2b34.0101.0102.07020103.01060000' => { Name => 'CutPoint', Format => 'int64s', %duration },
    '060e2b34.0101.0102.07020103.03030000' => { Name => 'EventStart', Type => 'Position', %duration },
  # '060e2b34.0101.0102.07020103.10020000' => { Name => 'EditOffsets', Type => 'Node' },
    '060e2b34.0101.0102.07020103.10020100' => { Name => 'ControlPointTime', Format => 'rational64s' },
    '060e2b34.0101.0102.07020110.01030000' => { Name => 'CreateDate', %timestamp },
    '060e2b34.0101.0102.07020110.02030000' => { Name => 'ModifyDate', %timestamp },
    '060e2b34.0101.0102.07020110.02040000' => { Name => 'ContainerLastModifyDate', %timestamp },
    '060e2b34.0101.0102.07020110.02050000' => { Name => 'PackageLastModifyDate', %timestamp },
    '060e2b34.0101.0102.07020201.01030000' => { Name => 'Duration', Type => 'Length', %duration },
    '060e2b34.0101.0102.07020201.01050100' => { Name => 'DefaultFadeDuration', Type => 'Length', %duration },
    '060e2b34.0101.0102.07020201.01050200' => { Name => 'Fade-InDuration', Type => 'Length', %duration },
    '060e2b34.0101.0102.07020201.01050300' => { Name => 'Fade-OutDuration', Type => 'Length', %duration },
    '060e2b34.0101.0102.0d010101.01010100' => { Name => 'TapeFormat', Type => 'TapeFormatType', Unknown => 1 },
    '060e2b34.0101.0103.01011001.01000000' => { Name => 'OrganizationID', Type => 'UTF-16' },
    '060e2b34.0101.0103.01011504.00000000' => { Name => 'GlobalNumber', Format => 'string' },
    '060e2b34.0101.0103.01012007.00000000' => { Name => 'DeviceIDKind', Format => 'string' },
    '060e2b34.0101.0103.01012008.00000000' => { Name => 'DeviceKind', Format => 'string' },
    '060e2b34.0101.0103.01012008.02000000' => { Name => 'DeviceKindCode', Format => 'string' },
  # '060e2b34.0101.0103.01012100.00000000' => { Name => 'PlatformIdentifiers', Type => 'Node' },
    '060e2b34.0101.0103.01012101.00000000' => { Name => 'PlatformDesignation', Format => 'string' },
    '060e2b34.0101.0103.01012102.00000000' => { Name => 'PlatformModel', Format => 'string' },
    '060e2b34.0101.0103.01012103.00000000' => { Name => 'PlatformSerialNumber', Format => 'string' },
    '060e2b34.0101.0103.01030107.00000000' => { Name => 'LocalTargetID', Format => 'string' },
  # '060e2b34.0101.0103.01030203.00000000' => { Name => 'DiskIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0103.01030203.01000000' => { Name => 'MagneticDisks', Type => 'Node' },
    '060e2b34.0101.0103.01030203.01010000' => { Name => 'MagneticDiskNumber', Format => 'string' },
  # '060e2b34.0101.0103.01030203.02000000' => { Name => 'OpticalDiscs', Type => 'Node' },
    '060e2b34.0101.0103.01030203.02010000' => { Name => 'OpticalDiscNumber', Format => 'string' },
    '060e2b34.0101.0103.01030402.00000000' => { Name => 'StreamID', Format => 'int8u' },
    '060e2b34.0101.0103.01030403.00000000' => { Name => 'TransportStreamID', Format => 'int16u' },
  # '060e2b34.0101.0103.01030500.00000000' => { Name => 'OrganizationalProgramIdentifiers', Type => 'Node' },
    '060e2b34.0101.0103.01030501.00000000' => { Name => 'OrganizationalProgramNumber', Format => 'string' },
    '060e2b34.0101.0103.01030501.01000000' => { Name => 'OrganizationalProgramNumber', Type => 'UTF-16' },
  # '060e2b34.0101.0103.01030600.00000000' => { Name => 'MetadataIdentifiers', Type => 'Node' },
    '060e2b34.0101.0103.01030601.00000000' => { Name => 'ItemDesignatorID', Type => 'SMPTE336M', Unknown => 1 },
    '060e2b34.0101.0103.01040101.01000000' => { Name => 'LocalFilePath', Type => 'UTF-16' },
    '060e2b34.0101.0103.01050101.00000000' => { Name => 'TitleKind', Type => 'UTF-16' },
    '060e2b34.0101.0103.01050201.00000000' => { Name => 'MainTitle', Type => 'UTF-16' },
    '060e2b34.0101.0103.01050301.00000000' => { Name => 'SecondaryTitle', Type => 'UTF-16' },
    '060e2b34.0101.0103.01050401.00000000' => { Name => 'SeriesNumber', Type => 'UTF-16' },
    '060e2b34.0101.0103.01050501.00000000' => { Name => 'EpisodeNumber', Type => 'UTF-16' },
    '060e2b34.0101.0103.01050601.00000000' => { Name => 'SceneNumber', Type => 'UTF-16' },
    '060e2b34.0101.0103.01050801.00000000' => { Name => 'VersionTitle', Type => 'UTF-16' },
    '060e2b34.0101.0103.01050900.00000000' => { Name => 'MissionID', Format => 'string' },
    '060e2b34.0101.0103.01050901.00000000' => { Name => 'MissionID', Type => 'UTF-16' },
  # '060e2b34.0101.0103.01100300.00000000' => { Name => 'MusicIndustryIdentifiers', Type => 'Node' },
    '060e2b34.0101.0103.01100301.00000000' => { Name => 'RecordingLabelName', Format => 'string' },
    '060e2b34.0101.0103.01100301.01000000' => { Name => 'RecordingLabelName', Type => 'UTF-16' },
    '060e2b34.0101.0103.01100302.00000000' => { Name => 'CollectionName', Format => 'string' },
    '060e2b34.0101.0103.01100302.01000000' => { Name => 'CollectionName', Type => 'UTF-16' },
    '060e2b34.0101.0103.01100303.00000000' => { Name => 'OriginCode', Format => 'string' },
    '060e2b34.0101.0103.01100304.00000000' => { Name => 'MainCatalogNumber', Format => 'string' },
    '060e2b34.0101.0103.01100305.00000000' => { Name => 'CatalogPrefixNumber', Format => 'string' },
    '060e2b34.0101.0103.01100306.00000000' => { Name => 'SideNumber', Format => 'string' },
    '060e2b34.0101.0103.01100307.00000000' => { Name => 'RecordedTrackNumber', Format => 'string' },
    '060e2b34.0101.0103.02020200.00000000' => { Name => 'SeriesinaSeriesGroupCount', Format => 'int16u' },
    '060e2b34.0101.0103.02020300.00000000' => { Name => 'ProgrammingGroupKind', Format => 'string' },
  # '060e2b34.0101.0103.02030000.00000000' => { Name => 'Purchaser', Type => 'Node' },
    '060e2b34.0101.0103.02030100.00000000' => { Name => 'PurchasingOrganizationName', Format => 'string' },
    '060e2b34.0101.0103.02030200.00000000' => { Name => 'SalesContractNumber', Format => 'string' },
    '060e2b34.0101.0103.02030400.00000000' => { Name => 'PurchasingDepartment', Format => 'string' },
  # '060e2b34.0101.0103.02040000.00000000' => { Name => 'ContractDescriptions', Type => 'Node' },
    '060e2b34.0101.0103.02040100.00000000' => { Name => 'ContractType', Format => 'string' },
    '060e2b34.0101.0103.02040101.00000000' => { Name => 'ContractTypeCode', Format => 'string' },
    '060e2b34.0101.0103.02040200.00000000' => { Name => 'ContractClauseDescription', Format => 'string' },
    '060e2b34.0101.0103.02040300.00000000' => { Name => 'ContractLineCode', Format => 'string' },
    '060e2b34.0101.0103.02040301.00000000' => { Name => 'ContractLineName', Format => 'string' },
    '060e2b34.0101.0103.02040400.00000000' => { Name => 'ContractTermsOfBusiness', Format => 'string' },
    '060e2b34.0101.0103.02040500.00000000' => { Name => 'ContractInstallmentPercentage', Format => 'float' },
    '060e2b34.0101.0103.02040600.00000000' => { Name => 'Jurisdiction', Format => 'string' },
    '060e2b34.0101.0103.02050101.01000000' => { Name => 'CopyrightStatus', Type => 'UTF-16' },
    '060e2b34.0101.0103.02050102.01000000' => { Name => 'CopyrightOwnerName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02050201.01000000' => { Name => 'IntellectualPropertyDescription', Type => 'UTF-16' },
    '060e2b34.0101.0103.02050202.01000000' => { Name => 'IntellectualPropertyRights', Type => 'UTF-16' },
    '060e2b34.0101.0103.02050301.01000000' => { Name => 'Rightsholder', Type => 'UTF-16' },
    '060e2b34.0101.0103.02050302.01000000' => { Name => 'RightsManagementAuthority', Type => 'UTF-16' },
    '060e2b34.0101.0103.02050403.00000000' => { Name => 'RightsConditionDescription', Format => 'string' },
    '060e2b34.0101.0103.02050403.01000000' => { Name => 'RightsConditionDescription', Type => 'UTF-16' },
    '060e2b34.0101.0103.02060101.01000000' => { Name => 'CurrencyName', Format => 'string' },
    '060e2b34.0101.0103.02060202.00000000' => { Name => 'TotalPayment', Format => 'string' },
    '060e2b34.0101.0103.02060203.00000000' => { Name => 'PayeeAccountName', Format => 'string' },
    '060e2b34.0101.0103.02060204.00000000' => { Name => 'PayeeAccountNumber', Format => 'string' },
    '060e2b34.0101.0103.02060205.00000000' => { Name => 'PayeeAccountSortCode', Format => 'string' },
    '060e2b34.0101.0103.02060302.00000000' => { Name => 'TotalIncome', Format => 'string' },
    '060e2b34.0101.0103.02060303.00000000' => { Name => 'PayerAccountName', Format => 'string' },
    '060e2b34.0101.0103.02060304.00000000' => { Name => 'PayerAccountNumber', Format => 'string' },
    '060e2b34.0101.0103.02060305.00000000' => { Name => 'PayerAccountSortCode', Format => 'string' },
  # '060e2b34.0101.0103.02080200.00000000' => { Name => 'Classification', Type => 'Node' },
    '060e2b34.0101.0103.02080201.00000000' => { Name => 'SecurityClassification', Format => 'string' },
    '060e2b34.0101.0103.02080202.00000000' => { Name => 'SecurityClassificationCaveats', Format => 'string' },
    '060e2b34.0101.0103.02080203.00000000' => { Name => 'ClassifiedBy', Format => 'string' },
    '060e2b34.0101.0103.02080204.00000000' => { Name => 'ClassificationReason', Format => 'string' },
    '060e2b34.0101.0103.02080205.00000000' => { Name => 'DeclassificationDate', Format => 'string', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0103.02080206.00000000' => { Name => 'DerivedFrom', Format => 'string' },
    '060e2b34.0101.0103.02080207.00000000' => { Name => 'ClassificationComment', Format => 'string' },
    '060e2b34.0101.0103.02080208.00000000' => { Name => 'ClassificationAndMarkingSystem', Format => 'string' },
    '060e2b34.0101.0103.02100101.01010000' => { Name => 'BroadcastOrganizationName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02100101.02010000' => { Name => 'BroadcastServiceName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02100101.03020000' => { Name => 'BroadcastMediumCode', Format => 'string' },
    '060e2b34.0101.0103.02100101.04010000' => { Name => 'BroadcastRegion', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300101.01000000' => { Name => 'NatureOfPersonality', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300102.01010000' => { Name => 'ContributionStatus', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300103.01010000' => { Name => 'SupportOrAdministrationStatus', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300201.01000000' => { Name => 'OrganizationKind', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300202.01010000' => { Name => 'ProductionOrganizationRole', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300203.01010000' => { Name => 'SupportOrganizationRole', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300501.01000000' => { Name => 'JobFunctionName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300501.02000000' => { Name => 'JobFunctionCode', Format => 'string' },
    '060e2b34.0101.0103.02300502.01000000' => { Name => 'RoleName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300503.00000000' => { Name => 'JobTitle', Format => 'string' },
    '060e2b34.0101.0103.02300503.01000000' => { Name => 'JobTitle', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300601.01000000' => { Name => 'ContactKind', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300602.01000000' => { Name => 'ContactDepartmentName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300603.01010100' => { Name => 'FamilyName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300603.01020100' => { Name => 'FirstGivenName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300603.01030100' => { Name => 'SecondGivenName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300603.01040100' => { Name => 'ThirdGivenName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300603.01070000' => { Name => 'PersonDescription', Format => 'string' },
    '060e2b34.0101.0103.02300603.01070100' => { Name => 'PersonDescription', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300603.02010100' => { Name => 'MainName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300603.02020100' => { Name => 'SupplementaryName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300603.03010100' => { Name => 'OrganizationMainName', Type => 'UTF-16' },
    '060e2b34.0101.0103.02300603.03020100' => { Name => 'SupplementaryOrganizationName', Type => 'UTF-16' },
    '060e2b34.0101.0103.03010101.02000000' => { Name => 'RegionCode', Format => 'string' },
  # '060e2b34.0101.0103.03010101.10000000' => { Name => 'CountryAndRegionNames', Type => 'Node' },
    '060e2b34.0101.0103.03010101.10010000' => { Name => 'CountryName', Format => 'string' },
    '060e2b34.0101.0103.03010101.10010100' => { Name => 'CountryName', Type => 'UTF-16' },
    '060e2b34.0101.0103.03010101.10020000' => { Name => 'RegionName', Format => 'string' },
    '060e2b34.0101.0103.03010101.10020100' => { Name => 'RegionName', Type => 'UTF-16' },
  # '060e2b34.0101.0103.03010102.10000000' => { Name => 'LanguageNames', Type => 'Node' },
    '060e2b34.0101.0103.03010102.10010000' => { Name => 'LanguageName', Format => 'string' },
    '060e2b34.0101.0103.03010102.10010100' => { Name => 'LanguageName', Type => 'UTF-16' },
    '060e2b34.0101.0103.03010210.05000000' => { Name => 'TerminatingFillerData', Format => 'int8u' },
    '060e2b34.0101.0103.03010303.03000000' => { Name => 'TimingBiasCorrection', Format => 'float' },
    '060e2b34.0101.0103.03010303.04000000' => { Name => 'TimingBiasCorrectionDescription', Format => 'string' },
    '060e2b34.0101.0103.03020101.03010000' => { Name => 'Genre', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020101.04010000' => { Name => 'TargetAudience', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020101.10000000' => { Name => 'ProgramMaterialClassificationCode', Format => 'string' },
    '060e2b34.0101.0103.03020102.03010000' => { Name => 'Theme', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020102.04010000' => { Name => 'SubjectName', Format => 'string' },
    '060e2b34.0101.0103.03020102.04020000' => { Name => 'SubjectName', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020102.05010000' => { Name => 'Keywords', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020102.0f000000' => { Name => 'KeyFrameSampleCount', Format => 'int32u' },
    '060e2b34.0101.0103.03020106.01010000' => { Name => 'Abstract', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020106.02010000' => { Name => 'Purpose', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020106.03010000' => { Name => 'Description', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020106.04010000' => { Name => 'ColorDescriptor', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020106.05010000' => { Name => 'FormatDescriptor', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020106.06000000' => { Name => 'IntentDescriptor', Format => 'string' },
    '060e2b34.0101.0103.03020106.06010000' => { Name => 'IntentDescriptor', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020106.07000000' => { Name => 'TextualDescriptionKind', Format => 'string' },
    '060e2b34.0101.0103.03020106.07010000' => { Name => 'TextualDescriptionKind', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020201.03000000' => { Name => 'FestivalName', Format => 'string' },
    '060e2b34.0101.0103.03020301.02020000' => { Name => 'ObjectDescriptionCode', Format => 'string' },
  # '060e2b34.0101.0103.03020302.00000000' => { Name => 'GeneralComments', Type => 'Node' },
    '060e2b34.0101.0103.03020302.01000000' => { Name => 'DescriptionKind', Format => 'string' },
    '060e2b34.0101.0103.03020302.01010000' => { Name => 'DescriptionKind', Type => 'UTF-16' },
    '060e2b34.0101.0103.03020302.02000000' => { Name => 'DescriptiveComment', Format => 'string' },
    '060e2b34.0101.0103.03020302.02010000' => { Name => 'DescriptiveComment', Type => 'UTF-16' },
  # '060e2b34.0101.0103.03020401.00000000' => { Name => 'ObjectNames', Type => 'Node' },
  # '060e2b34.0101.0103.03020600.00000000' => { Name => 'Human-AssignedContextDescriptions', Type => 'Node' },
    '060e2b34.0101.0103.03020601.00000000' => { Name => 'ContextDescription', Format => 'string' },
    '060e2b34.0101.0103.03030102.06010000' => { Name => 'ComputedKeywords', Type => 'UTF-16' },
    '060e2b34.0101.0103.03030301.04000000' => { Name => 'ObjectIdentificationConfidence', Format => 'int16u' },
    '060e2b34.0101.0103.03030301.05000000' => { Name => 'ObjectHorizontalAverageDimension', Format => 'int32u' },
    '060e2b34.0101.0103.03030301.06000000' => { Name => 'ObjectVerticalAverageDimension', Format => 'int32u' },
    '060e2b34.0101.0103.03030301.07000000' => { Name => 'ObjectAreaDimension', Format => 'int32u' },
    '060e2b34.0101.0103.04010101.04000000' => { Name => 'HorizontalActionSafePercentage', Format => 'float' },
    '060e2b34.0101.0103.04010101.05000000' => { Name => 'VerticalActionSafePercentage', Format => 'float' },
    '060e2b34.0101.0103.04010101.06000000' => { Name => 'HorizontalGraphicsSafePercentage', Format => 'float' },
    '060e2b34.0101.0103.04010101.07000000' => { Name => 'VerticalGraphicsSafePercentage', Format => 'float' },
    '060e2b34.0101.0103.04010101.08000000' => { Name => 'PerceivedDisplayFormatName', Format => 'string' },
    '060e2b34.0101.0103.04010101.08010000' => { Name => 'PerceivedDisplayFormatCode', Format => 'string' },
    '060e2b34.0101.0103.04010201.01050000' => { Name => 'VideoColorKind', Format => 'string' },
    '060e2b34.0101.0103.04010301.07000000' => { Name => 'PictureDisplayRate', Format => 'int16u' },
    '060e2b34.0101.0103.04010501.11000000' => { Name => 'VideoAverageBitrate', Format => 'float', PrintConv => 'ConvertBitrate($val)' },
    '060e2b34.0101.0103.04010501.12000000' => { Name => 'VideoFixedBitrate', Type => 'Boolean' },
  # '060e2b34.0101.0103.04010b00.00000000' => { Name => 'VideoFileFormats', Type => 'Node' },
    '060e2b34.0101.0103.04010b01.00000000' => { Name => 'DigitalVideoFileFormat', Format => 'string' },
    '060e2b34.0101.0103.04020401.01000000' => { Name => 'CodingLawName', Format => 'string' },
    '060e2b34.0101.0103.04020402.01000000' => { Name => 'AudioCodingSchemeCode', Format => 'string', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0103.04020402.02000000' => { Name => 'AudioCodingSchemeName', Format => 'string', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0103.04030301.00000000' => { Name => 'DigitalEncodingBitrate', Format => 'int32u', PrintConv => 'ConvertBitrate($val)' },
    '060e2b34.0101.0103.04030302.00000000' => { Name => 'DataEssenceCodingID', Type => 'AUID', Unknown => 1 },
  # '060e2b34.0101.0103.040f0000.00000000' => { Name => 'StorageCharacteristics', Type => 'Node' },
    '060e2b34.0101.0103.040f0100.00000000' => { Name => 'StorageKind', Format => 'string' },
    '060e2b34.0101.0103.040f0101.00000000' => { Name => 'StorageKind', Type => 'UTF-16' },
    '060e2b34.0101.0103.040f0102.00000000' => { Name => 'StorageKindCode', Format => 'string' },
  # '060e2b34.0101.0103.04100101.10000000' => { Name => 'TapeMediumFundamentalParameters', Type => 'Node' },
    '060e2b34.0101.0103.04100101.10010000' => { Name => 'TapePartitionCapacity', Format => 'int64u' },
  # '060e2b34.0101.0103.04100102.01000000' => { Name => 'DiscMediumFundamentalParameters', Type => 'Node' },
    '060e2b34.0101.0103.04100102.02000000' => { Name => 'DiscPartitionCapacity', Format => 'int64u' },
    '060e2b34.0101.0103.04200201.01040100' => { Name => 'FocalLength', Format => 'int32u', ValueConv => '$val/10' },
    '060e2b34.0101.0103.04200201.01080100' => { Name => 'FieldOfViewHorizontal', Format => 'int16u', ValueConv => '$val/10' },
    '060e2b34.0101.0103.04200201.010a0000' => { Name => 'FieldOfViewVertical', Format => 'int16u', ValueConv => '$val/10' },
  # '060e2b34.0101.0103.04300000.00000000' => { Name => 'SystemCharacteristics', Type => 'Node' },
    '060e2b34.0101.0103.04300100.00000000' => { Name => 'SystemNameOrNumber', Format => 'string' },
    '060e2b34.0101.0103.05010104.00000000' => { Name => 'LogoFlag', Type => 'Boolean' },
    '060e2b34.0101.0103.05010106.00000000' => { Name => 'GraphicKind', Format => 'string' },
    '060e2b34.0101.0103.05010107.00000000' => { Name => 'GraphicUsageKind', Format => 'string' },
    '060e2b34.0101.0103.05010401.00000000' => { Name => 'SignatureTuneFlag', Type => 'Boolean' },
    '060e2b34.0101.0103.05010402.00000000' => { Name => 'BackgroundMusicFlag', Type => 'Boolean' },
  # '060e2b34.0101.0103.06030000.00000000' => { Name => 'RelatedProductionContent', Type => 'Node' },
  # '060e2b34.0101.0103.06030500.00000000' => { Name => 'RelatedTextualContent', Type => 'Node' },
    '060e2b34.0101.0103.06030501.00000000' => { Name => 'ProductionScriptReference', Format => 'string' },
    '060e2b34.0101.0103.06030501.01000000' => { Name => 'ProductionScriptReference', Type => 'UTF-16' },
    '060e2b34.0101.0103.06030502.00000000' => { Name => 'TranscriptReference', Format => 'string' },
    '060e2b34.0101.0103.06030502.01000000' => { Name => 'TranscriptReference', Type => 'UTF-16' },
    '060e2b34.0101.0103.07010103.00000000' => { Name => 'HorizontalDatum', Format => 'string' },
    '060e2b34.0101.0103.07010104.00000000' => { Name => 'VerticalDatum', Format => 'string' },
    '060e2b34.0101.0103.07010201.02040200' => { Name => 'DeviceLatitude', Format => 'double', %geoLat },
    '060e2b34.0101.0103.07010201.02060200' => { Name => 'DeviceLongitude', Format => 'double', %geoLon },
    '060e2b34.0101.0103.07010201.03020200' => { Name => 'FrameCenterLatitude', Format => 'double', %geoLat },
    '060e2b34.0101.0103.07010201.03040200' => { Name => 'FrameCenterLongitude', Format => 'double', %geoLon },
    '060e2b34.0101.0103.07010201.03070000' => { Name => 'CornerLatitudePoint1', Format => 'string', %geoLat, ValueConv => \&ConvLatLon },
    '060e2b34.0101.0103.07010201.03070100' => { Name => 'CornerLatitudePoint1', Format => 'double', %geoLat },
    '060e2b34.0101.0103.07010201.03080000' => { Name => 'CornerLatitudePoint2', Format => 'string', %geoLat },
    '060e2b34.0101.0103.07010201.03080100' => { Name => 'CornerLatitudePoint2', Format => 'double', %geoLat },
    '060e2b34.0101.0103.07010201.03090000' => { Name => 'CornerLatitudePoint3', Format => 'string', %geoLat },
    '060e2b34.0101.0103.07010201.03090100' => { Name => 'CornerLatitudePoint3', Format => 'double', %geoLat },
    '060e2b34.0101.0103.07010201.030a0000' => { Name => 'CornerLatitudePoint4', Format => 'string' },
    '060e2b34.0101.0103.07010201.030a0100' => { Name => 'CornerLatitudePoint4', Format => 'double', %geoLat },
    '060e2b34.0101.0103.07010201.030b0000' => { Name => 'CornerLongitudePoint1', Format => 'string' },
    '060e2b34.0101.0103.07010201.030b0100' => { Name => 'CornerLongitudePoint1', Format => 'double', %geoLon },
    '060e2b34.0101.0103.07010201.030c0000' => { Name => 'CornerLongitudePoint2', Format => 'string' },
    '060e2b34.0101.0103.07010201.030c0100' => { Name => 'CornerLongitudePoint2', Format => 'double', %geoLon },
    '060e2b34.0101.0103.07010201.030d0000' => { Name => 'CornerLongitudePoint3', Format => 'string' },
    '060e2b34.0101.0103.07010201.030d0100' => { Name => 'CornerLongitudePoint3', Format => 'double', %geoLon },
    '060e2b34.0101.0103.07010201.030e0000' => { Name => 'CornerLongitudePoint4', Format => 'string' },
    '060e2b34.0101.0103.07010201.030e0100' => { Name => 'CornerLongitudePoint4', Format => 'double', %geoLon },
    '060e2b34.0101.0103.07010801.02000000' => { Name => 'SubjectDistance', Format => 'float' },
    '060e2b34.0101.0103.07012001.01010100' => { Name => 'PlaceKeyword', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.02010100' => { Name => 'ObjectCountryCode', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.02060000' => { Name => 'ObjectCountryCodeMethod', Format => 'string' },
    '060e2b34.0101.0103.07012001.02070000' => { Name => 'CountryCodeMethod', Format => 'string' },
    '060e2b34.0101.0103.07012001.02080000' => { Name => 'Non-USClassifyingCountryCode', Format => 'string' },
    '060e2b34.0101.0103.07012001.02090000' => { Name => 'ReleasableCountryCode', Format => 'string' },
    '060e2b34.0101.0103.07012001.03010100' => { Name => 'ObjectRegionName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.03020100' => { Name => 'ShootingRegionName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.03030100' => { Name => 'SettingRegionName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.03040100' => { Name => 'CopyrightLicenseRegionName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.03050100' => { Name => 'IntellectualPropertyLicenseRegionName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04010101' => { Name => 'RoomNumber', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04010201' => { Name => 'StreetNumber', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04010301' => { Name => 'StreetName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04010401' => { Name => 'PostalTown', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04010501' => { Name => 'CityName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04010601' => { Name => 'StateOrProvinceOrCountyName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04010701' => { Name => 'PostalCode', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04010801' => { Name => 'CountryName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04020101' => { Name => 'SettingRoomNumber', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04020201' => { Name => 'SettingStreetNumberOrBuildingName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04020301' => { Name => 'SettingStreetName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04020401' => { Name => 'SettingTownName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04020501' => { Name => 'SettingCityName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04020601' => { Name => 'SettingStateOrProvinceOrCountyName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04020701' => { Name => 'SettingPostalCode', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.04020801' => { Name => 'SettingCountryName', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.10030101' => { Name => 'TelephoneNumber', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.10030201' => { Name => 'FaxNumber', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012001.10030301' => { Name => 'E-mailAddress', Type => 'UTF-16' },
    '060e2b34.0101.0103.07012002.01010000' => { Name => 'SettingDescription', Type => 'UTF-16' },
    '060e2b34.0101.0103.07020101.01050000' => { Name => 'POSIXMicroseconds', Format => 'int64u' },
  # '060e2b34.0101.0103.07020103.10030000' => { Name => 'EventOffsets', Type => 'Node' },
    '060e2b34.0101.0103.07020103.10030100' => { Name => 'EventElapsedTimeToStart', Format => 'string' },
    '060e2b34.0101.0103.07020103.10030200' => { Name => 'EventElapsedTimeToEnd', Format => 'string' },
    '060e2b34.0101.0104.01011002.00000000' => { Name => 'OrganizationIDKind', Format => 'string' },
    '060e2b34.0101.0104.01011002.01000000' => { Name => 'OrganizationIDKind', Type => 'UTF-16' },
  # '060e2b34.0101.0104.01020200.00000000' => { Name => 'RegistryLocators', Type => 'Node' },
    '060e2b34.0101.0104.01020201.00000000' => { Name => 'SMPTEUL', Type => 'UL', Unknown => 1 },
  # '060e2b34.0101.0104.01020210.00000000' => { Name => 'RegistryLocatorGroups', Type => 'Node' },
  # '060e2b34.0101.0104.01020210.01000000' => { Name => 'RegistryLocatorOrderedGroup', Type => 'Node' },
    '060e2b34.0101.0104.01020210.01010000' => { Name => 'EssenceContainerArray', Type => 'Array of UL', Unknown => 1 },
    '060e2b34.0101.0104.01030404.00000000' => { Name => 'EssenceStreamID', Format => 'int32u' },
    '060e2b34.0101.0104.01030405.00000000' => { Name => 'IndexStreamID', Format => 'int32u' },
    '060e2b34.0101.0104.01050a00.00000000' => { Name => 'WorkingTitle', Format => 'string' },
    '060e2b34.0101.0104.01050a01.00000000' => { Name => 'WorkingTitle', Type => 'UTF-16' },
    '060e2b34.0101.0104.01050b00.00000000' => { Name => 'OriginalTitle', Format => 'string' },
    '060e2b34.0101.0104.01050b01.00000000' => { Name => 'OriginalTitle', Type => 'UTF-16' },
    '060e2b34.0101.0104.01050c00.00000000' => { Name => 'ClipNumber', Format => 'string' },
    '060e2b34.0101.0104.01050c01.00000000' => { Name => 'ClipNumber', Type => 'UTF-16' },
    '060e2b34.0101.0104.01070105.00000000' => { Name => 'DescriptiveMetadataTrackIDs', Format => 'int32u' },
  # '060e2b34.0101.0104.01080000.00000000' => { Name => 'GenericIdentifiers', Type => 'Node' },
    '060e2b34.0101.0104.01080100.00000000' => { Name => 'IdentifierKind', Format => 'string' },
    '060e2b34.0101.0104.01080200.00000000' => { Name => 'IdentifierValue', Format => 'int8u' },
  # '060e2b34.0101.0104.010a0200.00000000' => { Name => 'GeneralOrganizationIdentifiers', Type => 'Node' },
    '060e2b34.0101.0104.010a0201.00000000' => { Name => 'OrganizationCode', Format => 'string' },
    '060e2b34.0101.0104.010a0201.01000000' => { Name => 'OrganizationCode', Type => 'UTF-16' },
    '060e2b34.0101.0104.02010500.00000000' => { Name => 'SupplierIdentificationKind', Format => 'string' },
    '060e2b34.0101.0104.02010600.00000000' => { Name => 'SupplierIdentificationValue', Format => 'string' },
    '060e2b34.0101.0104.02010700.00000000' => { Name => 'SupplierAccountNumber', Format => 'string' },
    '060e2b34.0101.0104.02010800.00000000' => { Name => 'SupplierAccountName', Format => 'string' },
    '060e2b34.0101.0104.02010801.00000000' => { Name => 'SupplierAccountName', Type => 'UTF-16' },
    '060e2b34.0101.0104.02020400.00000000' => { Name => 'EpisodeStartNumber', Format => 'int16u' },
    '060e2b34.0101.0104.02020500.00000000' => { Name => 'EpisodeEndNumber', Format => 'int16u' },
    '060e2b34.0101.0104.02030500.00000000' => { Name => 'PurchaserIdentificationKind', Format => 'string' },
    '060e2b34.0101.0104.02030600.00000000' => { Name => 'PurchaserIdentificationValue', Format => 'string' },
    '060e2b34.0101.0104.02030700.00000000' => { Name => 'PurchaserAccountNumber', Format => 'string' },
    '060e2b34.0101.0104.02030800.00000000' => { Name => 'PurchaserAccountName', Format => 'string' },
    '060e2b34.0101.0104.02030801.00000000' => { Name => 'PurchaserAccountName', Type => 'UTF-16' },
    '060e2b34.0101.0104.02040102.00000000' => { Name => 'ContractType', Type => 'UTF-16' },
    '060e2b34.0101.0104.02040201.00000000' => { Name => 'ContractClauseDescription', Type => 'UTF-16' },
    '060e2b34.0101.0104.02040302.00000000' => { Name => 'ContractLineName', Type => 'UTF-16' },
    '060e2b34.0101.0104.02040401.00000000' => { Name => 'ContractTermsOfBusiness', Type => 'UTF-16' },
    '060e2b34.0101.0104.02040601.00000000' => { Name => 'Jurisdiction', Type => 'UTF-16' },
    '060e2b34.0101.0104.02060102.00000000' => { Name => 'TotalCurrencyAmount', Format => 'double' },
    '060e2b34.0101.0104.02060103.00000000' => { Name => 'InstallmentNumber', Format => 'int16u' },
  # '060e2b34.0101.0104.020a0000.00000000' => { Name => 'IdentifiersAndLocatorsAdministrationAuthorities', Type => 'Node' },
    '060e2b34.0101.0104.020a0100.00000000' => { Name => 'IdentifierIssuingAuthority', Format => 'string' },
  # '060e2b34.0101.0104.02100200.00000000' => { Name => 'Publication', Type => 'Node' },
  # '060e2b34.0101.0104.02100201.00000000' => { Name => 'GeneralPublication', Type => 'Node' },
    '060e2b34.0101.0104.02100201.01000000' => { Name => 'PublishingOrganizationName', Format => 'string' },
    '060e2b34.0101.0104.02100201.01010000' => { Name => 'PublishingOrganizationName', Type => 'UTF-16' },
    '060e2b34.0101.0104.02100201.02000000' => { Name => 'PublishingServiceName', Format => 'string' },
    '060e2b34.0101.0104.02100201.02010000' => { Name => 'PublishingServiceName', Type => 'UTF-16' },
    '060e2b34.0101.0104.02100201.03000000' => { Name => 'PublishingMediumName', Format => 'string' },
    '060e2b34.0101.0104.02100201.03010000' => { Name => 'PublishingMediumName', Type => 'UTF-16' },
    '060e2b34.0101.0104.02100201.04000000' => { Name => 'PublishingRegionName', Format => 'string' },
    '060e2b34.0101.0104.02100201.04010000' => { Name => 'PublishingRegionName', Type => 'UTF-16' },
    '060e2b34.0101.0104.02300603.01050100' => { Name => 'Salutation', Type => 'UTF-16' },
    '060e2b34.0101.0104.02300603.01060100' => { Name => 'HonorsAndQualifications', Type => 'UTF-16' },
    '060e2b34.0101.0104.02300603.01080000' => { Name => 'OtherGivenNames', Format => 'string' },
    '060e2b34.0101.0104.02300603.01080100' => { Name => 'OtherGivenNames', Type => 'UTF-16' },
    '060e2b34.0101.0104.02300603.01090000' => { Name => 'AlternateName', Format => 'string' },
    '060e2b34.0101.0104.02300603.01090100' => { Name => 'AlternateName', Type => 'UTF-16' },
  # '060e2b34.0101.0104.03010102.02000000' => { Name => 'TextLanguageCodes', Type => 'Node' },
    '060e2b34.0101.0104.03010102.02010000' => { Name => 'ISO639TextLanguageCode', Format => 'string', LanguageCode => 1 },
    '060e2b34.0101.0104.03010102.02020000' => { Name => 'ISO639CaptionsLanguageCode', Format => 'string' },
  # '060e2b34.0101.0104.03010102.03000000' => { Name => 'SpokenLanguageCodes', Type => 'Node' },
    '060e2b34.0101.0104.03010102.03010000' => { Name => 'PrimarySpokenLanguageCode', Format => 'string' },
    '060e2b34.0101.0104.03010102.03020000' => { Name => 'SecondarySpokenLanguageCode', Format => 'string' },
    '060e2b34.0101.0104.03010102.03030000' => { Name => 'PrimaryOriginalLanguageCode', Format => 'string' },
    '060e2b34.0101.0104.03010102.03040000' => { Name => 'SecondaryOriginalLanguageCode', Format => 'string' },
    '060e2b34.0101.0104.03010201.06000000' => { Name => 'MajorVersion', Format => 'int16u' },
    '060e2b34.0101.0104.03010201.07000000' => { Name => 'MinorVersion', Format => 'int16u' },
    '060e2b34.0101.0104.03010201.08000000' => { Name => 'SectorSize', Format => 'int32u' },
    '060e2b34.0101.0104.03010203.09000000' => { Name => 'ElementLength', Format => 'int32u' },
    '060e2b34.0101.0104.03020102.02010000' => { Name => 'ThesaurusName', Type => 'UTF-16' },
    '060e2b34.0101.0104.03020102.0d010000' => { Name => 'Cue-InWords', Type => 'UTF-16' },
    '060e2b34.0101.0104.03020102.0e010000' => { Name => 'Cue-OutWords', Type => 'UTF-16' },
    '060e2b34.0101.0104.03020102.10000000' => { Name => 'KeypointKind', Format => 'string' },
    '060e2b34.0101.0104.03020102.10010000' => { Name => 'KeypointKind', Type => 'UTF-16' },
    '060e2b34.0101.0104.03020102.11000000' => { Name => 'KeypointValue', Format => 'string' },
    '060e2b34.0101.0104.03020102.11010000' => { Name => 'KeypointValue', Type => 'UTF-16' },
    '060e2b34.0101.0104.03020201.03010000' => { Name => 'FestivalName', Type => 'UTF-16' },
    '060e2b34.0101.0104.03020201.04000000' => { Name => 'AwardName', Format => 'string' },
    '060e2b34.0101.0104.03020201.04010000' => { Name => 'AwardName', Type => 'UTF-16' },
    '060e2b34.0101.0104.03020201.05000000' => { Name => 'AwardCategory', Format => 'string' },
    '060e2b34.0101.0104.03020201.05010000' => { Name => 'AwardCategory', Type => 'UTF-16' },
    '060e2b34.0101.0104.03020503.00000000' => { Name => 'SlateInformation', Type => 'UTF-16' },
    '060e2b34.0101.0104.04020301.04000000' => { Name => 'LockedIndicator', Type => 'Boolean' },
    '060e2b34.0101.0104.04020303.04000000' => { Name => 'BitsPerAudioSample', Format => 'int32u', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0104.04030101.00000000' => { Name => 'CaptionKind', Format => 'string' },
    '060e2b34.0101.0104.04030101.01000000' => { Name => 'CaptionKind', Type => 'UTF-16' },
  # '060e2b34.0101.0104.04040400.00000000' => { Name => 'IndexingMetadataCodingCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0104.04040401.00000000' => { Name => 'IntraEditUnitIndexing', Type => 'Node' },
    '060e2b34.0101.0104.04040401.01000000' => { Name => 'SliceCount', Format => 'int8u' },
    '060e2b34.0101.0104.04040401.02000000' => { Name => 'SliceNumber', Format => 'int8u' },
    '060e2b34.0101.0104.04040401.03000000' => { Name => 'ElementDelta', Format => 'int32u' },
    '060e2b34.0101.0104.04040401.04000000' => { Name => 'PositionTableIndexing', Format => 'int8s' },
    '060e2b34.0101.0104.04040401.05000000' => { Name => 'SliceOffsetList', Type => 'UInt32Array', Unknown => 1 },
    '060e2b34.0101.0104.04040401.08000000' => { Name => 'PosTableArray', Unknown => 1 },
  # '060e2b34.0101.0104.04040402.00000000' => { Name => 'InterEditUnitIndexing', Type => 'Node' },
    '060e2b34.0101.0104.04040402.01000000' => { Name => 'StreamOffset', Format => 'int64u' },
    '060e2b34.0101.0104.04040402.02000000' => { Name => 'EditUnitFlags', Format => 'int8u' },
    '060e2b34.0101.0104.04040402.03000000' => { Name => 'TemporalOffset', Format => 'int8s' },
    '060e2b34.0101.0104.04040402.04000000' => { Name => 'AnchorOffset', Format => 'int8s' },
  # '060e2b34.0101.0104.04060200.00000000' => { Name => 'GeneralEssenceContainerCharacteristics', Type => 'Node' },
    '060e2b34.0101.0104.04060201.00000000' => { Name => 'EditUnitLength', Format => 'int32u' },
  # '060e2b34.0101.0104.04060800.00000000' => { Name => 'GeneralMetadataCodingCharacteristics', Type => 'Node' },
  # '060e2b34.0101.0104.04060900.00000000' => { Name => 'GeneralMetadataContainerCharacteristics', Type => 'Node' },
    '060e2b34.0101.0104.04060901.00000000' => { Name => 'HeaderByteCount', Format => 'int64u' },
    '060e2b34.0101.0104.04060902.00000000' => { Name => 'IndexByteCount', Format => 'int64u' },
  # '060e2b34.0101.0104.04061000.00000000' => { Name => 'GeneralDataCodingCharacteristics', Type => 'Node' },
    '060e2b34.0101.0104.04061001.00000000' => { Name => 'PackLength', Format => 'int32u' },
  # '060e2b34.0101.0104.04200102.00000000' => { Name => 'ImagerCharacteristics', Type => 'Node' },
    '060e2b34.0101.0104.05010101.01000000' => { Name => 'IntegrationIndication', Type => 'UTF-16' },
    '060e2b34.0101.0104.05010102.01000000' => { Name => 'EventIndication', Type => 'UTF-16' },
    '060e2b34.0101.0104.05010107.01000000' => { Name => 'GraphicUsageKind', Type => 'UTF-16' },
    '060e2b34.0101.0104.06010104.01080000' => { Name => 'PrimaryPackage', Type => 'WeakReference', Unknown => 1 },
  # '060e2b34.0101.0104.06010104.02400000' => { Name => 'StrongReferencingToDescriptiveMetadataSets', Type => 'Node' },
    '060e2b34.0101.0104.06010104.03030000' => { Name => 'DescriptiveMetadataSets', Type => 'WeakReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0104.06010104.04020000' => { Name => 'DescriptiveMetadataSetReferences', Type => 'WeakReferenceArray', Unknown => 1 },
  # '060e2b34.0101.0104.06010104.05400000' => { Name => 'StrongReferencesToDescriptiveMetadataBatches', Type => 'Node' },
    '060e2b34.0101.0104.06010104.060b0000' => { Name => 'FileDescriptors', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0104.06080102.01010000' => { Name => 'StreamPositionIndicator', Format => 'int16u' },
    '060e2b34.0101.0104.06080102.01020000' => { Name => 'StreamPositionIndicator', Format => 'int32u' },
    '060e2b34.0101.0104.06080102.01030000' => { Name => 'StreamPositionIndicator', Format => 'int64u' },
    '060e2b34.0101.0104.06080202.01000000' => { Name => 'OffsetToMetadata', Format => 'int32s' },
    '060e2b34.0101.0104.06080202.01010000' => { Name => 'OffsetToMetadata', Format => 'int64s' },
    '060e2b34.0101.0104.06080202.02000000' => { Name => 'OffsetToIndexTable', Format => 'int32s' },
    '060e2b34.0101.0104.06080202.02010000' => { Name => 'OffsetToIndexTable', Format => 'int64s' },
  # '060e2b34.0101.0104.06090000.00000000' => { Name => 'DataRelationships', Type => 'Node' },
  # '060e2b34.0101.0104.06090200.00000000' => { Name => 'LocalDataRelationships', Type => 'Node' },
  # '060e2b34.0101.0104.06090201.00000000' => { Name => 'DataOffsets', Type => 'Node' },
    '060e2b34.0101.0104.06090201.01000000' => { Name => 'ByteOffset', Format => 'int64u' },
    '060e2b34.0101.0104.06090201.02000000' => { Name => 'ReversePlay', Format => 'int64u' },
  # '060e2b34.0101.0104.06101000.00000000' => { Name => 'RelativeNumericalSequences', Type => 'Node' },
    '060e2b34.0101.0104.06101001.00000000' => { Name => 'FirstNumberInSequence', Format => 'int32u' },
    '060e2b34.0101.0104.06101001.01000000' => { Name => 'FirstNumberInSequence', Format => 'int64u' },
    '060e2b34.0101.0104.06101002.00000000' => { Name => 'PreviousNumberInSequence', Format => 'int32u' },
    '060e2b34.0101.0104.06101002.01000000' => { Name => 'PreviousNumberInSequence', Format => 'int64u' },
    '060e2b34.0101.0104.06101003.00000000' => { Name => 'CurrentNumberInSequence', Format => 'int32u' },
    '060e2b34.0101.0104.06101003.01000000' => { Name => 'CurrentNumberInSequence', Format => 'int64u' },
    '060e2b34.0101.0104.06101004.00000000' => { Name => 'NextNumberInSequence', Format => 'int32u' },
    '060e2b34.0101.0104.06101004.01000000' => { Name => 'NextNumberInSequence', Format => 'int64u' },
    '060e2b34.0101.0104.06101005.00000000' => { Name => 'LastNumberInSequence', Format => 'int32u' },
    '060e2b34.0101.0104.06101005.01000000' => { Name => 'LastNumberInSequence', Format => 'int64u' },
  # '060e2b34.0101.0104.07012001.10000000' => { Name => 'ElectronicAddressVarieties', Type => 'Node' },
    '060e2b34.0101.0104.07012001.10030400' => { Name => 'CentralTelephoneNumber', Format => 'string' },
    '060e2b34.0101.0104.07012001.10030500' => { Name => 'MobileTelephoneNumber', Format => 'string' },
    '060e2b34.0101.0104.07012001.10030600' => { Name => 'URL', Format => 'string' },
    '060e2b34.0101.0104.07012002.02000000' => { Name => 'LocationDescription', Format => 'string' },
    '060e2b34.0101.0104.07012002.02010000' => { Name => 'LocationDescription', Type => 'UTF-16' },
    '060e2b34.0101.0104.07012002.03000000' => { Name => 'LocationKind', Format => 'string' },
    '060e2b34.0101.0104.07012002.03010000' => { Name => 'LocationKind', Type => 'UTF-16' },
    '060e2b34.0101.0104.07020102.07010100' => { Name => 'UTCEventStartDateTime', %timestamp },
    '060e2b34.0101.0104.07020102.07020100' => { Name => 'LocalEventStartDateTime', %timestamp },
    '060e2b34.0101.0104.07020102.09010100' => { Name => 'UTCEventEndDateTime', %timestamp },
    '060e2b34.0101.0104.07020102.09020100' => { Name => 'LocalEventEndDateTime', %timestamp },
    '060e2b34.0101.0104.07020103.01070000' => { Name => 'KeyTimePoint', Format => 'int64u' },
    '060e2b34.0101.0104.07020108.01010000' => { Name => 'TimePeriodName', Type => 'UTF-16' },
    '060e2b34.0101.0104.07020108.02000000' => { Name => 'SettingDateTime', %timestamp },
  # '060e2b34.0101.0104.07020120.00000000' => { Name => 'AdministrativeDateTime', Type => 'Node' },
    '060e2b34.0101.0104.07020120.01000000' => { Name => 'ContractDateTime', %timestamp },
    '060e2b34.0101.0104.07020120.02000000' => { Name => 'RightsStartDateTime', %timestamp },
    '060e2b34.0101.0104.07020120.03000000' => { Name => 'RightsStopDateTime', %timestamp },
    '060e2b34.0101.0104.07020120.04000000' => { Name => 'PaymentDueDateTime', %timestamp },
  # '060e2b34.0101.0105.01010500.00000000' => { Name => 'UMIDPicture', Type => 'Node' },
  # '060e2b34.0101.0105.01010600.00000000' => { Name => 'UMIDMultiPicture', Type => 'Node' },
  # '060e2b34.0101.0105.01010800.00000000' => { Name => 'UMIDSound', Type => 'Node' },
  # '060e2b34.0101.0105.01010900.00000000' => { Name => 'UMIDMultiSound', Type => 'Node' },
  # '060e2b34.0101.0105.01010b00.00000000' => { Name => 'UMIDSingleData', Type => 'Node' },
  # '060e2b34.0101.0105.01010c00.00000000' => { Name => 'UMIDMultiData', Type => 'Node' },
  # '060e2b34.0101.0105.01010d00.00000000' => { Name => 'UMIDMixed', Type => 'Node' },
  # '060e2b34.0101.0105.01010f00.00000000' => { Name => 'UMIDGeneral', Type => 'Node' },
    '060e2b34.0101.0105.01011508.00000000' => { Name => 'ClipID', Type => 'UMID' },
    '060e2b34.0101.0105.01012008.01000000' => { Name => 'DeviceKind', Type => 'UTF-16' },
    '060e2b34.0101.0105.0101200c.00000000' => { Name => 'DeviceAssetNumber', Format => 'string' },
    '060e2b34.0101.0105.01020202.00000000' => { Name => 'IdentificationUL', Type => 'UL', Unknown => 1 },
    '060e2b34.0101.0105.01020203.00000000' => { Name => 'OperationalPatternUL', Type => 'UL', Unknown => 1 },
  # '060e2b34.0101.0105.01020210.02000000' => { Name => 'RegistryLocatorUnorderedGroups', Type => 'Node' },
    '060e2b34.0101.0105.01020210.02010000' => { Name => 'EssenceContainers', Type => 'BatchOfUL', Unknown => 1 },
    '060e2b34.0101.0105.01020210.02020000' => { Name => 'DescriptiveMetadataSchemes', Type => 'BatchOfUL', Unknown => 1 },
    '060e2b34.0101.0105.01030108.00000000' => { Name => 'ProjectName', Format => 'string' },
    '060e2b34.0101.0105.01030108.01000000' => { Name => 'ProjectName', Type => 'UTF-16' },
    '060e2b34.0101.0105.01030602.00000000' => { Name => 'LocalTagValue', Format => 'int16u' },
    '060e2b34.0101.0105.01030603.00000000' => { Name => 'LocalTagUniqueID', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0105.01050d00.00000000' => { Name => 'BrandMainTitle', Format => 'string' },
    '060e2b34.0101.0105.01050d01.00000000' => { Name => 'BrandMainTitle', Type => 'UTF-16' },
    '060e2b34.0101.0105.01050e00.00000000' => { Name => 'BrandOriginalTitle', Format => 'string' },
    '060e2b34.0101.0105.01050e01.00000000' => { Name => 'BrandOriginalTitle', Type => 'UTF-16' },
    '060e2b34.0101.0105.01050f00.00000000' => { Name => 'FrameworkTitle', Format => 'string' },
    '060e2b34.0101.0105.01050f01.00000000' => { Name => 'FrameworkTitle', Type => 'UTF-16' },
    '060e2b34.0101.0105.01070106.00000000' => { Name => 'SourceTrackIDs', Format => 'int32u' },
    '060e2b34.0101.0105.01070107.00000000' => { Name => 'ShotTrackIDs', Format => 'int32u' },
    '060e2b34.0101.0105.02020301.00000000' => { Name => 'ProgrammingGroupKind', Type => 'UTF-16' },
    '060e2b34.0101.0105.02020600.00000000' => { Name => 'ProgrammingGroupTitle', Format => 'string' },
    '060e2b34.0101.0105.02020601.00000000' => { Name => 'ProgrammingGroupTitle', Type => 'UTF-16' },
    '060e2b34.0101.0105.020a0101.00000000' => { Name => 'IdentifierIssuingAuthority', Type => 'UTF-16' },
    '060e2b34.0101.0105.02300603.010a0000' => { Name => 'LinkingName', Format => 'string' },
    '060e2b34.0101.0105.02300603.010a0100' => { Name => 'LinkingName', Type => 'UTF-16' },
    '060e2b34.0101.0105.02300603.010b0000' => { Name => 'NameSuffix', Format => 'string' },
    '060e2b34.0101.0105.02300603.010b0100' => { Name => 'NameSuffix', Type => 'UTF-16' },
    '060e2b34.0101.0105.02300603.010c0000' => { Name => 'FormerFamilyName', Format => 'string' },
    '060e2b34.0101.0105.02300603.010c0100' => { Name => 'FormerFamilyName', Type => 'UTF-16' },
    '060e2b34.0101.0105.02300603.010d0000' => { Name => 'Nationality', Format => 'string' },
    '060e2b34.0101.0105.02300603.010d0100' => { Name => 'Nationality', Type => 'UTF-16' },
    '060e2b34.0101.0105.02300603.010e0000' => { Name => 'Citizenship', Format => 'string' },
    '060e2b34.0101.0105.02300603.010e0100' => { Name => 'Citizenship', Type => 'UTF-16' },
    '060e2b34.0101.0105.03010102.02030000' => { Name => 'FrameworkTextLanguageCode', Format => 'string', LanguageCode => 1 },
    '060e2b34.0101.0105.03010201.09000000' => { Name => 'KAGSize', Format => 'int32u' },
    '060e2b34.0101.0105.03010201.0a000000' => { Name => 'ReversedByteOrder', Type => 'Boolean' },
  # '060e2b34.0101.0105.0301020a.00000000' => { Name => 'NameValueConstructInterpretations', Type => 'Node' },
    '060e2b34.0101.0105.0301020a.01000000' => { Name => 'ItemName', Format => 'string' },
    '060e2b34.0101.0105.0301020a.01010000' => { Name => 'ItemName', Type => 'UTF-16' },
    '060e2b34.0101.0105.0301020a.02000000' => { Name => 'ItemValue', Format => 'string' },
    '060e2b34.0101.0105.0301020a.02010000' => { Name => 'ItemValue', Type => 'UTF-16' },
  # '060e2b34.0101.0105.03010220.00000000' => { Name => 'XMLConstructsAndInterpretations', Type => 'Node' },
    '060e2b34.0101.0105.03010220.01000000' => { Name => 'XMLDocumentText', Type => 'Indirect', Unknown => 1 },
    '060e2b34.0101.0105.03010220.01010000' => { Name => 'XMLDocumentText', Format => 'string' },
    '060e2b34.0101.0105.03010220.01020000' => { Name => 'XMLDocumentText', Type => 'UTF-16' },
    '060e2b34.0101.0105.03010220.01030000' => { Name => 'XMLDocumentText', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0105.03020102.15000000' => { Name => 'FrameworkThesaurusName', Format => 'string' },
    '060e2b34.0101.0105.03020102.15010000' => { Name => 'FrameworkThesaurusName', Type => 'UTF-16' },
    '060e2b34.0101.0105.03020106.08000000' => { Name => 'GroupSynopsis', Format => 'string' },
    '060e2b34.0101.0105.03020106.08010000' => { Name => 'GroupSynopsis', Type => 'UTF-16' },
    '060e2b34.0101.0105.03020106.09000000' => { Name => 'AnnotationSynopsis', Format => 'string' },
    '060e2b34.0101.0105.03020106.09010000' => { Name => 'AnnotationSynopsis', Type => 'UTF-16' },
    '060e2b34.0101.0105.03020106.0a000000' => { Name => 'AnnotationDescription', Format => 'string' },
    '060e2b34.0101.0105.03020106.0a010000' => { Name => 'AnnotationDescription', Type => 'UTF-16' },
    '060e2b34.0101.0105.03020106.0b000000' => { Name => 'ScriptingKind', Format => 'string' },
    '060e2b34.0101.0105.03020106.0b010000' => { Name => 'ScriptingKind', Type => 'UTF-16' },
    '060e2b34.0101.0105.03020106.0c000000' => { Name => 'ScriptingText', Format => 'string' },
    '060e2b34.0101.0105.03020106.0c010000' => { Name => 'ScriptingText', Type => 'UTF-16' },
    '060e2b34.0101.0105.03020106.0d000000' => { Name => 'ShotDescription', Format => 'string' },
    '060e2b34.0101.0105.03020106.0d010000' => { Name => 'ShotDescription', Type => 'UTF-16' },
    '060e2b34.0101.0105.03020106.0e000000' => { Name => 'AnnotationKind', Format => 'string' },
    '060e2b34.0101.0105.03020106.0e010000' => { Name => 'AnnotationKind', Type => 'UTF-16' },
    '060e2b34.0101.0105.03020106.0f000000' => { Name => 'RelatedMaterialDescription', Format => 'string' },
    '060e2b34.0101.0105.03020106.0f010000' => { Name => 'RelatedMaterialDescription', Type => 'UTF-16' },
    '060e2b34.0101.0105.03020504.00000000' => { Name => 'ClipKind', Type => 'UTF-16' },
  # '060e2b34.0101.0105.03030310.00000000' => { Name => 'DeviceCommentsAndDescriptions', Type => 'Node' },
    '060e2b34.0101.0105.03030310.01000000' => { Name => 'DeviceUsageDescription', Format => 'string' },
    '060e2b34.0101.0105.03030310.01010000' => { Name => 'DeviceUsageDescription', Type => 'UTF-16' },
    '060e2b34.0101.0105.04010302.07000000' => { Name => 'DisplayF2Offset', Format => 'int32s' },
    '060e2b34.0101.0105.04010302.08000000' => { Name => 'StoredF2Offset', Format => 'int32s' },
    '060e2b34.0101.0105.04010302.09000000' => { Name => 'ActiveFormatDescriptor', Format => 'int8u' },
    '060e2b34.0101.0105.04010302.0a000000' => { Name => 'LineNumber', Format => 'int32u' },
  # '060e2b34.0101.0105.04010404.00000000' => { Name => 'VideoScanningCharacteristics', Type => 'Node' },
    '060e2b34.0101.0105.04010404.01000000' => { Name => 'ScanningDirection', Format => 'int8u' },
    '060e2b34.0101.0105.04010503.0b000000' => { Name => 'ComponentMaximumRef', Format => 'int32u' },
    '060e2b34.0101.0105.04010503.0c000000' => { Name => 'ComponentMinimumRef', Format => 'int32u' },
    '060e2b34.0101.0105.04010503.0d000000' => { Name => 'AlphaMaximumRef', Format => 'int32u' },
    '060e2b34.0101.0105.04010503.0e000000' => { Name => 'AlphaMinimumRef', Format => 'int32u' },
  # '060e2b34.0101.0105.04010504.00000000' => { Name => 'DigitalVideoAndImageSignalTypeIdentifiers', Type => 'Node' },
    '060e2b34.0101.0105.04010504.01000000' => { Name => 'VideoPayloadIdentifier', Format => 'int8u' },
    '060e2b34.0101.0105.04010504.02000000' => { Name => 'VideoPayloadIdentifier2002', Format => 'int8u' },
    '060e2b34.0101.0105.04010602.01020000' => { Name => 'SingleSequenceFlag', Type => 'Boolean' },
    '060e2b34.0101.0105.04010602.01030000' => { Name => 'ConstantBPictureFlag', Type => 'Boolean' },
    '060e2b34.0101.0105.04010602.01040000' => { Name => 'CodedContentScanningKind', Type => 'int8u',
        PrintConv => { 0 => 'Unknown', 1 => 'Progressive', 2 => 'Interlaced', 3 => 'Mixed' },
    },
    '060e2b34.0101.0105.04010602.01050000' => { Name => 'LowDelayIndicator', Type => 'Boolean' },
    '060e2b34.0101.0105.04010602.01060000' => { Name => 'ClosedGOPIndicator', Type => 'Boolean' },
    '060e2b34.0101.0105.04010602.01070000' => { Name => 'IdenticalGOPIndicator', Type => 'Boolean' },
    '060e2b34.0101.0105.04010602.01080000' => { Name => 'MaximumGOPSize', Format => 'int16u' },
    '060e2b34.0101.0105.04010602.01090000' => { Name => 'MaximumBPictureCount', Format => 'int16u' },
    '060e2b34.0101.0105.04010602.010a0000' => { Name => 'ProfileAndLevel', Format => 'int8u' },
    '060e2b34.0101.0105.04010602.010b0000' => { Name => 'Bitrate', Format => 'int32u', PrintConv => 'ConvertBitrate($val)' },
    '060e2b34.0101.0105.04020101.04000000' => { Name => 'ChannelCount', Format => 'int32u', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0105.04020301.01010000' => { Name => 'AudioSampleRate', Format => 'rational64s', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0105.04020301.05000000' => { Name => 'PeakEnvelope', Format => 'int8u', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0105.04020301.0e000000' => { Name => 'PeakEnvelopeData', Type => 'Stream', Unknown => 1, Groups => { 2 => 'Audio' } },
    '060e2b34.0101.0105.04020302.01000000' => { Name => 'BlockAlign', Format => 'int16u' },
    '060e2b34.0101.0105.04020302.02000000' => { Name => 'SequenceOffset', Format => 'int8u' },
    '060e2b34.0101.0105.04020302.03000000' => { Name => 'BlockStartOffset', Format => 'int16u' },
    '060e2b34.0101.0105.04020302.05000000' => { Name => 'FileSecurityReport', Format => 'int32u' },
    '060e2b34.0101.0105.04020302.06000000' => { Name => 'FileSecurityWave', Format => 'int32u' },
    '060e2b34.0101.0105.04020303.05000000' => { Name => 'AverageBytesPerSecond', Format => 'int32u', Groups => { 2 => 'Audio' } },
  # '060e2b34.0101.0105.04020500.00000000' => { Name => 'DigitalAudioProcessingParameters', Type => 'Node' },
  # '060e2b34.0101.0105.04020501.00000000' => { Name => 'AES-3ProcessingParameters', Type => 'Node' },
    '060e2b34.0101.0105.04020501.01000000' => { Name => 'AuxiliaryBitsMode', Format => 'int8u' },
    '060e2b34.0101.0105.04020501.02000000' => { Name => 'ChannelStatusMode', Format => 'undef',
        RawConv => 'length($val) > 8 ? join(" ",unpack("x8C*",$val)) : undef',
        # convert just the first value for now
        PrintConv => [{
            0 => 'No Channel Status Data',
            1 => 'AES3 Minimum',
            2 => 'AES3 Standard',
            3 => 'Fixed 24 Bytes in FixedChannelStatusData',
            4 => 'Stream of Data in MXF Header Metadata',
            5 => 'Stream of Data Multiplexed within MXF Body',
        }],
    },
    '060e2b34.0101.0105.04020501.03000000' => { Name => 'FixedChannelStatusData', Type => 'Array of bytes', Unknown => 1 },
    '060e2b34.0101.0105.04020501.04000000' => { Name => 'UserDataMode', Type => 'EnumeratedArray', Unknown => 1 },
    '060e2b34.0101.0105.04020501.05000000' => { Name => 'FixedUserData', Type => 'Array of bytes', Unknown => 1 },
    '060e2b34.0101.0105.04020501.06000000' => { Name => 'Emphasis', Format => 'int8u' },
  # '060e2b34.0101.0105.04020502.00000000' => { Name => 'BWFProcessingParameters', Type => 'Node' },
    '060e2b34.0101.0105.04020502.01000000' => { Name => 'BextCodingHistory', Format => 'string' },
    '060e2b34.0101.0105.04020502.01010000' => { Name => 'BextCodingHistory', Type => 'UTF-16' },
    '060e2b34.0101.0105.04020502.02000000' => { Name => 'QltyBasicData', Format => 'string' },
    '060e2b34.0101.0105.04020502.02010000' => { Name => 'QltyBasicData', Type => 'UTF-16' },
    '060e2b34.0101.0105.04020502.03000000' => { Name => 'QltyStartOfModulation', Format => 'string' },
    '060e2b34.0101.0105.04020502.03010000' => { Name => 'QltyStartOfModulation', Type => 'UTF-16' },
    '060e2b34.0101.0105.04020502.04000000' => { Name => 'QltyQualityEvent', Format => 'string' },
    '060e2b34.0101.0105.04020502.04010000' => { Name => 'QltyQualityEvent', Type => 'UTF-16' },
    '060e2b34.0101.0105.04020502.05000000' => { Name => 'QltyEndOfModulation', Format => 'string' },
    '060e2b34.0101.0105.04020502.05010000' => { Name => 'QltyEndOfModulation', Type => 'UTF-16' },
    '060e2b34.0101.0105.04020502.06000000' => { Name => 'QltyQualityParameter', Format => 'string' },
    '060e2b34.0101.0105.04020502.06010000' => { Name => 'QltyQualityParameter', Type => 'UTF-16' },
    '060e2b34.0101.0105.04020502.07000000' => { Name => 'QltyOperatorComment', Format => 'string' },
    '060e2b34.0101.0105.04020502.07010000' => { Name => 'QltyOperatorComment', Type => 'UTF-16' },
    '060e2b34.0101.0105.04020502.08000000' => { Name => 'QltyCueSheet', Format => 'string' },
    '060e2b34.0101.0105.04020502.08010000' => { Name => 'QltyCueSheet', Type => 'UTF-16' },
  # '060e2b34.0101.0105.04020700.00000000' => { Name => 'GeneralProcessingParameters', Type => 'Node' },
    '060e2b34.0101.0105.04020701.00000000' => { Name => 'DialNorm', Format => 'int8s' },
    '060e2b34.0101.0105.04030302.00000000' => { Name => 'DataEssenceCoding', Type => 'Label' },
  # '060e2b34.0101.0105.04040102.00000000' => { Name => 'GeneralDateTimeCodingCharacteristics', Type => 'Node' },
    '060e2b34.0101.0105.04040102.01000000' => { Name => 'DateTimeRate', Format => 'rational64s', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0105.04040102.02000000' => { Name => 'DateTimeDropFrameFlag', Type => 'Boolean', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0105.04040102.03000000' => { Name => 'DateTimeEmbeddedFlag', Type => 'Boolean', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0105.04040102.04000000' => { Name => 'DateTimeKind', Type => 'UL', Unknown => 1, Groups => { 2 => 'Time' } },
    '060e2b34.0101.0105.04040401.06000000' => { Name => 'DeltaEntryArray', Type => 'ArrayOfDeltaEntry', Unknown => 1 },
    '060e2b34.0101.0105.04040401.07000000' => { Name => 'PositionTableCount', Format => 'int8u' },
    '060e2b34.0101.0105.04040401.08000000' => { Name => 'PositionTable', Type => 'ArrayOfRational', Unknown => 1 },
    '060e2b34.0101.0105.04040402.05000000' => { Name => 'IndexEntryArray', Type => 'ArrayOfIndexEntry', Unknown => 1 },
    '060e2b34.0101.0105.04050113.00000000' => { Name => 'SignalStandard', Format => 'int8u' },
    '060e2b34.0101.0105.04070101.00000000' => { Name => 'DataDefinition', Type => 'UL', Unknown => 1 },
  # '060e2b34.0101.0105.04090000.00000000' => { Name => 'FormatCharacteristics', Type => 'Node' },
    '060e2b34.0101.0105.04090100.00000000' => { Name => 'RecordedFormat', Format => 'string' },
    '060e2b34.0101.0105.05010302.01000000' => { Name => 'GenerationCopyNumber', Format => 'int16u' },
    '060e2b34.0101.0105.05010303.01000000' => { Name => 'GenerationCloneNumber', Format => 'int16u' },
  # '060e2b34.0101.0105.05010400.00000000' => { Name => 'MusicFlags', Type => 'Node' },
    '060e2b34.0101.0105.05010403.00000000' => { Name => 'ThemeMusicFlag', Type => 'Boolean' },
    '060e2b34.0101.0105.05010404.00000000' => { Name => 'InsertMusicFlag', Type => 'Boolean' },
    '060e2b34.0101.0105.05300406.00000000' => { Name => 'IndexEditRate', Format => 'rational64s' },
    '060e2b34.0101.0105.06010103.05000000' => { Name => 'LinkedTrackID', Format => 'int32u' },
    '060e2b34.0101.0105.06010104.01020100' => { Name => 'EssenceContainerFormat', Type => 'UL', Unknown => 1 },
    '060e2b34.0101.0105.06010104.01030100' => { Name => 'CodecDefinition', Type => 'UL', Unknown => 1 },
    '060e2b34.0101.0105.06010104.020c0000' => { Name => 'DescriptiveMetadataFramework', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0105.06010104.02400500' => { Name => 'GroupSet', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0105.06010104.02401c00' => { Name => 'BankDetailsSet', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0105.06010104.02401d00' => { Name => 'ImageFormatSet', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0105.06010104.02402000' => { Name => 'ProcessingSet', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0105.06010104.02402100' => { Name => 'ProjectSet', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0105.06010104.02402200' => { Name => 'ContactsListSet', Type => 'StrongReference', Unknown => 1 },
  # '060e2b34.0101.0105.06010104.02402300' => { Name => 'CueWordsSets', Type => 'Node' },
    '060e2b34.0101.0105.06010104.02402301' => { Name => 'AnnotationCueWordsSet', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0105.06010104.02402302' => { Name => 'ShotCueWordsSet', Type => 'StrongReference', Unknown => 1 },
  # '060e2b34.0101.0105.06010104.03400000' => { Name => 'WeakReferencingToDescriptiveMetadataSets', Type => 'Node' },
  # '060e2b34.0101.0105.06010104.03401300' => { Name => 'ParticipantRoleSets', Type => 'Node' },
    '060e2b34.0101.0105.06010104.03401301' => { Name => 'AwardParticipantSets', Type => 'GlobalReferenceBatch (Participant)', Unknown => 1 },
    '060e2b34.0101.0105.06010104.03401302' => { Name => 'ContractParticipantSets', Type => 'GlobalReferenceBatch (Participant)', Unknown => 1 },
    '060e2b34.0101.0105.06010104.03401400' => { Name => 'PersonSets', Type => 'GlobalReferenceBatch (Participant)', Unknown => 1 },
  # '060e2b34.0101.0105.06010104.03401500' => { Name => 'OrganizationSets', Type => 'Node' },
    '060e2b34.0101.0105.06010104.03401501' => { Name => 'ParticipantOrganizationSets', Type => 'GlobalReferenceBatch (Organisation)', Unknown => 1 },
    '060e2b34.0101.0105.06010104.03401502' => { Name => 'PersonOrganizationSets', Type => 'GlobalReferenceBatch (Organisation)', Unknown => 1 },
    '060e2b34.0101.0105.06010104.03401600' => { Name => 'LocationSets', Type => 'GlobalReferenceBatch (Location)', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05400400' => { Name => 'TitlesSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05400500' => { Name => 'GroupSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05400600' => { Name => 'IdentificationSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05400700' => { Name => 'EpisodicItemSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05400800' => { Name => 'BrandingSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05400900' => { Name => 'EventSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05400a00' => { Name => 'PublicationSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05400b00' => { Name => 'AwardSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05400c00' => { Name => 'CaptionDescriptionSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05400d00' => { Name => 'AnnotationSets', Type => 'StrongReferenceBatch', Unknown => 1 },
  # '060e2b34.0101.0105.06010104.05400e00' => { Name => 'SettingPeriodSets', Type => 'Node' },
    '060e2b34.0101.0105.06010104.05400e01' => { Name => 'ProductionSettingPeriodSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05400e02' => { Name => 'SceneSettingPeriodSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05400f00' => { Name => 'ScriptingSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401000' => { Name => 'ClassificationSets', Type => 'StrongReferenceBatch', Unknown => 1 },
  # '060e2b34.0101.0105.06010104.05401100' => { Name => 'ShotSets', Type => 'Node' },
    '060e2b34.0101.0105.06010104.05401101' => { Name => 'SceneShotSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401102' => { Name => 'ClipShotSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401200' => { Name => 'KeyPointSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401300' => { Name => 'ShotParticipantRoleSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401400' => { Name => 'ShotPersonSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401500' => { Name => 'OrganizationSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401600' => { Name => 'ShotLocationSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401700' => { Name => 'AddressSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401800' => { Name => 'CommunicationSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401900' => { Name => 'ContractSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401a00' => { Name => 'RightsSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401b00' => { Name => 'PaymentsSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401e00' => { Name => 'DeviceParametersSets', Type => 'StrongReferenceBatch', Unknown => 1 },
  # '060e2b34.0101.0105.06010104.05401f00' => { Name => 'NameValueSets', Type => 'Node' },
    '060e2b34.0101.0105.06010104.05401f01' => { Name => 'ClassificationNameValueSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401f02' => { Name => 'ContactNameValueSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.05401f03' => { Name => 'DeviceParameterNameValueSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0105.06010104.060c0000' => { Name => 'MetadataServerLocators', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0105.06010104.060d0000' => { Name => 'RelatedMaterialLocators', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0105.06010107.15000000' => { Name => 'LocalTagEntries', Type => 'LocalTagEntryBatch', Unknown => 1 },
    '060e2b34.0101.0105.06100400.00000000' => { Name => 'TotalNumberInSequence', Format => 'int32u' },
    '060e2b34.0101.0105.07012001.04011100' => { Name => 'RoomOrSuiteName', Format => 'string' },
    '060e2b34.0101.0105.07012001.04011101' => { Name => 'RoomOrSuiteName', Type => 'UTF-16' },
    '060e2b34.0101.0105.07012001.04011200' => { Name => 'BuildingName', Format => 'string' },
    '060e2b34.0101.0105.07012001.04011201' => { Name => 'BuildingName', Type => 'UTF-16' },
    '060e2b34.0101.0105.07012001.10030601' => { Name => 'URL', Type => 'UTF-16' },
  # '060e2b34.0101.0105.07020102.07100000' => { Name => 'DefinedEventStartTrueDateTime', Type => 'Node' },
    '060e2b34.0101.0105.07020102.07100100' => { Name => 'LocalFestivalDateTime', Format => 'string', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0105.07020103.01090000' => { Name => 'ShotStartPosition', Type => 'Position', %duration },
    '060e2b34.0101.0105.07020103.010a0000' => { Name => 'IndexingStartPosition', Type => 'Position', %duration },
    '060e2b34.0101.0105.07020103.010b0000' => { Name => 'EventOrigin', Type => 'Position', %duration },
    '060e2b34.0101.0105.07020108.03000000' => { Name => 'SettingPeriodDescription', Format => 'string' },
    '060e2b34.0101.0105.07020108.03010000' => { Name => 'SettingPeriodDescription', Type => 'UTF-16' },
    '060e2b34.0101.0105.07020201.01020000' => { Name => 'IndexDuration', Type => 'Length', %duration },
    '060e2b34.0101.0105.07020201.02040000' => { Name => 'ShotDuration', Type => 'Length', %duration },
  # '060e2b34.0101.0105.0d020000.00000000' => { Name => 'EBU_UER', Type => 'Node' },
  # '060e2b34.0101.0105.0d030000.00000000' => { Name => 'Pro-MPEGForum', Type => 'Node' },
  # '060e2b34.0101.0106.0e040000.00000000' => { Name => 'Avid', Type => 'Node' },
  # '060e2b34.0101.0106.0e050000.00000000' => { Name => 'CNN', Type => 'Node' },
  # '060e2b34.0101.0106.0e050100.00000000' => { Name => 'CNNMediaIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0106.0e050101.00000000' => { Name => 'CNNLegacyMediaIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0106.0e050200.00000000' => { Name => 'CNNAttributes', Type => 'Node' },
  # '060e2b34.0101.0106.0e050201.00000000' => { Name => 'CNNRelationalAttributes', Type => 'Node' },
  # '060e2b34.0101.0106.0e050202.00000000' => { Name => 'CNNInformationAttributes', Type => 'Node' },
  # '060e2b34.0101.0106.0e050300.00000000' => { Name => 'CNNMetadataSets', Type => 'Node' },
  # '060e2b34.0101.0106.0e060000.00000000' => { Name => 'Sony', Type => 'Node' },
    '060e2b34.0101.0107.01011509.00000000' => { Name => 'ExtendedClipID', Type => 'UMID' },
    '060e2b34.0101.0107.0101150a.00000000' => { Name => 'ClipIDArray', Type => 'UMID Array', Unknown => 1 },
    '060e2b34.0101.0107.0101150b.00000000' => { Name => 'ExtendedClipIDArray', Type => 'UMID Array', Unknown => 1 },
    '060e2b34.0101.0107.01040104.00000000' => { Name => 'TrackNumberBatch', Format => 'int32u' },
    '060e2b34.0101.0107.03010102.02110000' => { Name => 'ExtendedTextLanguageCode', Format => 'string', LanguageCode => 1 },
    '060e2b34.0101.0107.03010102.02120000' => { Name => 'ExtendedCaptionsLanguageCode', Format => 'string' },
    '060e2b34.0101.0107.03010102.02130000' => { Name => 'FrameworkExtendedTextLanguageCode', Format => 'string', LanguageCode => 1 },
    '060e2b34.0101.0107.03010102.03110000' => { Name => 'PrimaryExtendedSpokenLanguageCode', Format => 'string' },
    '060e2b34.0101.0107.03010102.03120000' => { Name => 'SecondaryExtendedSpokenLanguageCode', Format => 'string' },
    '060e2b34.0101.0107.03010102.03130000' => { Name => 'OriginalExtendedSpokenPrimaryLanguageCode', Format => 'string' },
    '060e2b34.0101.0107.03010102.03140000' => { Name => 'SecondaryOriginalExtendedSpokenLanguageCode', Format => 'string' },
    '060e2b34.0101.0107.03010210.06000000' => { Name => 'KLVMetadataSequence', Type => 'Sequence of KLV packets', Unknown => 1 },
    '060e2b34.0101.0107.03010210.07000000' => { Name => 'PackageAttributes', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0107.03010210.08000000' => { Name => 'ComponentAttributes', Type => 'StrongReferenceArray', Unknown => 1 },
  # '060e2b34.0101.0107.03010220.02000000' => { Name => 'XMLBiMConstructsInMultipleStreams', Type => 'Node' },
  # '060e2b34.0101.0107.03010220.02010000' => { Name => 'MPEG7BiMDecoderInitFrames', Type => 'Node' },
    '060e2b34.0101.0107.03010220.02010100' => { Name => 'MPEG7BiMDecoderInitFrame1', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02010200' => { Name => 'MPEG7BiMDecoderInitFrame2', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02010300' => { Name => 'MPEG7BiMDecoderInitFrame3', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02010400' => { Name => 'MPEG7BiMDecoderInitFrame4', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02010500' => { Name => 'MPEG7BiMDecoderInitFrame5', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02010600' => { Name => 'MPEG7BiMDecoderInitFrame6', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02010700' => { Name => 'MPEG7BiMDecoderInitFrame7', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02010800' => { Name => 'MPEG7BiMDecoderInitFrame8', Type => 'ByteStream', Unknown => 1 },
  # '060e2b34.0101.0107.03010220.02020000' => { Name => 'MPEG7BiMAccessUnitFrames', Type => 'Node' },
    '060e2b34.0101.0107.03010220.02020100' => { Name => 'MPEG7BiMAccessUnitFrame1', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02020200' => { Name => 'MPEG7BiMAccessUnitFrame2', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02020300' => { Name => 'MPEG7BiMAccessUnitFrame3', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02020400' => { Name => 'MPEG7BiMAccessUnitFrame4', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02020500' => { Name => 'MPEG7BiMAccessUnitFrame5', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02020600' => { Name => 'MPEG7BiMAccessUnitFrame6', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02020700' => { Name => 'MPEG7BiMAccessUnitFrame7', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03010220.02020800' => { Name => 'MPEG7BiMAccessUnitFrame8', Type => 'ByteStream', Unknown => 1 },
    '060e2b34.0101.0107.03020102.16000000' => { Name => 'ComponentUserComments', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0107.03020501.01000000' => { Name => 'ShotCommentKind', Type => 'UTF-16' },
    '060e2b34.0101.0107.03020502.01000000' => { Name => 'ShotComment', Type => 'UTF-16' },
  # '060e2b34.0101.0107.04010202.00000000' => { Name => 'SensorParameters', Type => 'Node' },
    '060e2b34.0101.0107.04010202.01000000' => { Name => 'SensorMode', Format => 'string' },
    '060e2b34.0101.0107.04020101.05000000' => { Name => 'ChannelAssignment', Type => 'UL', Unknown => 1 },
    '060e2b34.0101.0107.04040402.06000000' => { Name => 'ContentPackageIndexArray', Type => 'ArrayOfIndexEntry', Unknown => 1 },
  # '060e2b34.0101.0107.04040403.00000000' => { Name => 'VideoIndexParameters', Type => 'Node' },
    '060e2b34.0101.0107.04040403.01000000' => { Name => 'VideoIndexArray', Type => 'Array of bytes', Unknown => 1 },
    '060e2b34.0101.0107.04060202.00000000' => { Name => 'ApproximateImageContainerSize', Format => 'int32u' },
    '060e2b34.0101.0107.04060801.00000000' => { Name => 'MetadataEncodingSchemeCode', Format => 'string' },
    '060e2b34.0101.0107.04090200.00000000' => { Name => 'MIMEMediaType', Format => 'string' },
    '060e2b34.0101.0107.04090201.00000000' => { Name => 'MIMEMediaType', Type => 'UTF-16' },
    '060e2b34.0101.0107.04200201.010a0100' => { Name => 'FieldOfViewVerticalFP', Format => 'float' },
    '060e2b34.0101.0107.05010108.00000000' => { Name => 'PackageUsageKind', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.0107.06010103.06000000' => { Name => 'ChannelID', Format => 'int32u' },
    '060e2b34.0101.0107.06010103.07000000' => { Name => 'ChannelIDs', Format => 'int32u' },
    '060e2b34.0101.0107.06010104.01090000' => { Name => 'KLVDataType', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.0107.06010104.03040000' => { Name => 'KLVDataParentProperties', Type => 'WeakReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0107.06010104.03050000' => { Name => 'TaggedValueParentProperties', Type => 'WeakReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0107.06010104.03401303' => { Name => 'AnnotationParticipantSets', Type => 'GlobalReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0107.06010104.050a0000' => { Name => 'KLVDataDefinitions', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0107.06010104.050b0000' => { Name => 'TaggedValueDefinitions', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0107.06010104.05401f04' => { Name => 'AddressNameValueSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0107.07010201.02300000' => { Name => 'NMEADocumentText', Format => 'string' },
    '060e2b34.0101.0107.07011001.04000000' => { Name => 'PlatformRollAngle', Format => 'float' },
    '060e2b34.0101.0107.07011001.05000000' => { Name => 'PlatformPitchAngle', Format => 'float' },
    '060e2b34.0101.0107.07011001.06000000' => { Name => 'PlatformHeadingAngle', Format => 'float' },
    '060e2b34.0101.0107.07012001.04011300' => { Name => 'AddressLine', Format => 'string' },
    '060e2b34.0101.0107.07012001.04011301' => { Name => 'AddressLine', Type => 'UTF-16' },
    '060e2b34.0101.0107.07012001.04011400' => { Name => 'PlaceName', Format => 'string' },
    '060e2b34.0101.0107.07012001.04011401' => { Name => 'PlaceName', Type => 'UTF-16' },
    '060e2b34.0101.0107.07012001.04011500' => { Name => 'GeographicalCoordinates', Type => '12-byte Spatial Coordinate', Unknown => 1 },
    '060e2b34.0101.0107.07012001.04011600' => { Name => 'AstronomicalBodyName', Format => 'string' },
    '060e2b34.0101.0107.07012001.04011601' => { Name => 'AstronomicalBodyName', Type => 'UTF-16' },
    '060e2b34.0101.0107.07020102.08020000' => { Name => 'TimecodeArray', Type => 'Array of timecodes', Unknown => 1 },
    '060e2b34.0101.0107.07020103.010c0000' => { Name => 'MarkIn', Type => 'Position', %duration },
    '060e2b34.0101.0107.07020103.010d0000' => { Name => 'UserPosition', Type => 'Position', %duration },
    '060e2b34.0101.0107.07020103.02030000' => { Name => 'MarkOut', Type => 'Position', %duration },
    '060e2b34.0101.0107.07020110.01040000' => { Name => 'ClipCreationDateTime', %timestamp },
    '060e2b34.0101.0107.07020201.02050000' => { Name => 'VideoClipDuration', Format => 'int32u' },
  # '060e2b34.0101.0107.0d040000.00000000' => { Name => 'BBC', Type => 'Node' },
  # '060e2b34.0101.0107.0d050000.00000000' => { Name => 'IRT', Type => 'Node' },
  # '060e2b34.0101.0107.0e070000.00000000' => { Name => 'IdeasUnlimitedTV', Type => 'Node' },
  # '060e2b34.0101.0107.0e080000.00000000' => { Name => 'IPV', Type => 'Node' },
  # '060e2b34.0101.0107.0e090000.00000000' => { Name => 'Dolby', Type => 'Node' },
  # '060e2b34.0101.0108.01011540.00000000' => { Name => 'GloballyUniqueObjectIdentifiers', Type => 'Node' },
  # '060e2b34.0101.0108.01011540.01000000' => { Name => 'GloballyUniqueHumanIdentifiers', Type => 'Node' },
    '060e2b34.0101.0108.01011540.01010000' => { Name => 'ParticipantID', Type => 'UID', Unknown => 1 },
    '060e2b34.0101.0108.01011540.01020000' => { Name => 'ContactID', Type => 'UID', Unknown => 1 },
    '060e2b34.0101.0108.01020104.00000000' => { Name => 'DefaultNamespaceURI', Format => 'string' },
    '060e2b34.0101.0108.01020104.01000000' => { Name => 'DefaultNamespaceURI', Type => 'UTF-16' },
    '060e2b34.0101.0108.01020105.00000000' => { Name => 'NamespaceURI', Format => 'string' },
    '060e2b34.0101.0108.01020105.01000000' => { Name => 'NamespaceURI', Type => 'UTF-16' },
    '060e2b34.0101.0108.01020106.00000000' => { Name => 'NamespaceURIs', Format => 'string' },
    '060e2b34.0101.0108.01020106.01000000' => { Name => 'NamespaceURIs', Type => 'UTF-16' },
    '060e2b34.0101.0108.01030604.00000000' => { Name => 'HTMLDOCTYPE', Format => 'string' },
    '060e2b34.0101.0108.01030604.01000000' => { Name => 'HTMLDOCTYPE', Type => 'UTF-16' },
    '060e2b34.0101.0108.01030605.00000000' => { Name => 'NamespacePrefix', Format => 'string' },
    '060e2b34.0101.0108.01030605.01000000' => { Name => 'NamespacePrefix', Type => 'UTF-16' },
    '060e2b34.0101.0108.01030606.00000000' => { Name => 'NamespacePrefixes', Format => 'string' },
    '060e2b34.0101.0108.01030606.01000000' => { Name => 'NamespacePrefixes', Type => 'UTF-16' },
    '060e2b34.0101.0108.02050404.00000000' => { Name => 'RightsComment', Format => 'string' },
    '060e2b34.0101.0108.02050404.01000000' => { Name => 'RightsComment', Type => 'UTF-16' },
    '060e2b34.0101.0108.03020201.06000000' => { Name => 'NominationCategory', Format => 'string' },
    '060e2b34.0101.0108.03020201.06010000' => { Name => 'NominationCategory', Type => 'UTF-16' },
    '060e2b34.0101.0108.04020301.06000000' => { Name => 'PeakEnvelopeVersion', Format => 'int32u' },
    '060e2b34.0101.0108.04020301.07000000' => { Name => 'PeakEnvelopeFormat', Format => 'int32u' },
    '060e2b34.0101.0108.04020301.08000000' => { Name => 'PointsPerPeakValue', Format => 'int32u' },
    '060e2b34.0101.0108.04020301.09000000' => { Name => 'PeakEnvelopeBlockSize', Format => 'int32u' },
    '060e2b34.0101.0108.04020301.0a000000' => { Name => 'PeakChannelCount', Format => 'int32u' },
    '060e2b34.0101.0108.04020301.0b000000' => { Name => 'PeakFrameCount', Format => 'int32u' },
    '060e2b34.0101.0108.04020301.0c000000' => { Name => 'PeakOfPeaksPosition', Type => 'Position', %duration },
    '060e2b34.0101.0108.04020301.0d000000' => { Name => 'PeakEnvelopeTimestamp', Format => 'int32u' },
    '060e2b34.0101.0108.04020301.0e000000' => { Name => 'PeakEnvelopeData', Type => 'Stream', Unknown => 1 },
    '060e2b34.0101.0108.04060802.00000000' => { Name => 'RIFFChunkID', Format => 'int32u' },
    '060e2b34.0101.0108.04060903.00000000' => { Name => 'RIFFChunkLength', Format => 'int32u' },
    '060e2b34.0101.0108.04070400.00000000' => { Name => 'RIFFChunkData', Type => 'DataStream', Unknown => 1 },
    '060e2b34.0101.0108.04090300.00000000' => { Name => 'MIMECharSet', Format => 'string' },
    '060e2b34.0101.0108.04090301.00000000' => { Name => 'MIMECharSet', Type => 'UTF-16' },
    '060e2b34.0101.0108.04090400.00000000' => { Name => 'MIMEEncoding', Format => 'string' },
    '060e2b34.0101.0108.04090401.00000000' => { Name => 'MIMEEncoding', Type => 'UTF-16' },
    '060e2b34.0101.0108.06010103.08000000' => { Name => 'MonoSourceTrackIDs', Format => 'int32u' },
    '060e2b34.0101.0108.06010104.010a0000' => { Name => 'CompositionRendering', Type => 'PackageID', Unknown => 1 },
    '060e2b34.0101.0108.06010104.03401304' => { Name => 'CaptionsDescriptionParticipantSets', Type => 'GlobalReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0108.06010104.05400d01' => { Name => 'EventAnnotationSets', Type => 'StrongReferenceBatch', Unknown => 1 },
    '060e2b34.0101.0108.06010104.060e0000' => { Name => 'ScriptingLocators', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0108.06010104.060f0000' => { Name => 'UnknownBWFChunks', Type => 'StrongReferenceArray', Unknown => 1 },
  # '060e2b34.0101.0108.0e0a0000.00000000' => { Name => 'SnellAndWilcox', Type => 'Node' },
    '060e2b34.0101.0109.01011511.00000000' => { Name => 'CryptographicContextID', Type => 'UUID', Unknown => 1 },
    '060e2b34.0101.0109.01012101.01000000' => { Name => 'PlatformDesignation', Type => 'UTF-16' },
    '060e2b34.0101.0109.01030107.01000000' => { Name => 'LocalTargetID', Type => 'UTF-16' },
    '060e2b34.0101.0109.01030109.00000000' => { Name => 'NITFLayerTargetID', Format => 'string' },
    '060e2b34.0101.0109.01030109.01000000' => { Name => 'NITFLayerTargetID', Type => 'UTF-16' },
    '060e2b34.0101.0109.01030302.00000000' => { Name => 'PackageName', Format => 'string' },
    '060e2b34.0101.0109.01030406.00000000' => { Name => 'RP217DataStreamPID', Format => 'int16u' },
    '060e2b34.0101.0109.01030407.00000000' => { Name => 'RP217VideoStreamPID', Format => 'int16u' },
    '060e2b34.0101.0109.02010101.00000000' => { Name => 'SourceOrganization', Type => 'UTF-16' },
    '060e2b34.0101.0109.02010301.00000000' => { Name => 'OriginalProducerName', Type => 'UTF-16' },
    '060e2b34.0101.0109.02080201.01000000' => { Name => 'SecurityClassification', Type => 'UTF-16' },
    '060e2b34.0101.0109.02080202.01000000' => { Name => 'SecurityClassificationCaveats', Type => 'UTF-16' },
    '060e2b34.0101.0109.02080207.01000000' => { Name => 'ClassificationComment', Type => 'UTF-16' },
  # '060e2b34.0101.0109.02090200.00000000' => { Name => 'DataEncryption', Type => 'Node' },
  # '060e2b34.0101.0109.02090201.00000000' => { Name => 'DataEncryptionAlgorithms', Type => 'Node' },
  # '060e2b34.0101.0109.02090202.00000000' => { Name => 'DataHashingAlgorithms', Type => 'Node' },
  # '060e2b34.0101.0109.02090300.00000000' => { Name => 'DigitalCinemaEncryption', Type => 'Node' },
  # '060e2b34.0101.0109.02090301.00000000' => { Name => 'DigitalCinemaEncryptionAlgorithms', Type => 'Node' },
    '060e2b34.0101.0109.02090301.01000000' => { Name => 'CipherAlgorithm', Type => 'UL', Unknown => 1 },
    '060e2b34.0101.0109.02090301.02000000' => { Name => 'CryptographicKeyID', Type => 'UUID', Unknown => 1 },
    '060e2b34.0101.0109.02090301.03000000' => { Name => 'EncryptedSourceValue', Type => 'DataValue', Unknown => 1 },
  # '060e2b34.0101.0109.02090302.00000000' => { Name => 'DigitalCinemaHashingAlgorithms', Type => 'Node' },
    '060e2b34.0101.0109.02090302.01000000' => { Name => 'MICAlgorithm', Type => 'UL', Unknown => 1 },
    '060e2b34.0101.0109.02090302.02000000' => { Name => 'MIC', Type => 'DataValue', Unknown => 1 },
    '060e2b34.0101.0109.03010102.01010000' => { Name => 'ISO639-1LanguageCode', Type => 'UTF-16' },
    '060e2b34.0101.0109.03020106.10000000' => { Name => 'JFIFMarkerDescription', Format => 'string' },
    '060e2b34.0101.0109.03020106.10010000' => { Name => 'JFIFMarkerDescription', Type => 'UTF-16' },
    '060e2b34.0101.0109.03020106.11000000' => { Name => 'HTMLMetaDescription', Format => 'string' },
    '060e2b34.0101.0109.03020106.11010000' => { Name => 'HTMLMetaDescription', Type => 'UTF-16' },
    '060e2b34.0101.0109.03020401.02000000' => { Name => 'MetadataItemName', Format => 'string' },
    '060e2b34.0101.0109.04010201.01060000' => { Name => 'ColorPrimaries', Format => 'string' },
    '060e2b34.0101.0109.04010201.01060100' => { Name => 'ColorPrimaries', Type => 'ColorPrimariesType', Unknown => 1 },
    '060e2b34.0101.0109.04060203.00000000' => { Name => 'ProductFormat', Format => 'string' },
    '060e2b34.0101.0109.04060203.01000000' => { Name => 'ProductFormat', Type => 'UTF-16' },
    '060e2b34.0101.0109.04061002.00000000' => { Name => 'SourceLength', Format => 'int64u' },
    '060e2b34.0101.0109.04200102.01010100' => { Name => 'ImageSourceDeviceKind', Type => 'UTF-16' },
    '060e2b34.0101.0109.06010102.02000000' => { Name => 'SourceContainerFormat', Type => 'UL', Unknown => 1 },
    '060e2b34.0101.0109.06010102.03000000' => { Name => 'SourceKey', Type => 'UL', Unknown => 1 },
    '060e2b34.0101.0109.06010103.09000000' => { Name => 'DynamicSourcePackageID', Type => 'PackageID', Unknown => 1 },
    '060e2b34.0101.0109.06010103.0a000000' => { Name => 'DynamicSourceTrackIDs', Format => 'int32u' },
    '060e2b34.0101.0109.06010103.0b000000' => { Name => 'SourceIndex', Type => 'Indirect', Unknown => 1 },
    '060e2b34.0101.0109.06010103.0c000000' => { Name => 'SourceSpecies', Type => 'Indirect', Unknown => 1 },
    '060e2b34.0101.0109.06010103.0d000000' => { Name => 'SourceValue', Type => 'Indirect', Unknown => 1 },
    '060e2b34.0101.0109.06010104.020d0000' => { Name => 'CryptographicContextObject', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.0109.06010104.06100000' => { Name => 'Sub-descriptors', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.0109.06010106.02000000' => { Name => 'EncryptedTrackFileID', Type => 'UUID', Unknown => 1 },
    '060e2b34.0101.0109.06010106.03000000' => { Name => 'CryptographicContextLink', Type => 'UUID', Unknown => 1 },
    '060e2b34.0101.0109.06090201.03000000' => { Name => 'PlaintextOffset', Format => 'int64u' },
    '060e2b34.0101.0109.06100500.00000000' => { Name => 'TripletSequenceNumber', Format => 'int64u' },
    '060e2b34.0101.0109.07010201.030f0000' => { Name => 'BoundingRectangle', Type => 'Geographic Rectangle', Unknown => 1 },
    '060e2b34.0101.0109.07010201.03100000' => { Name => 'GeographicLocation', Type => 'Geographic Polygon', Unknown => 1 },
    '060e2b34.0101.0109.07010201.03110000' => { Name => 'GeographicPolygonCoordinates', Type => 'Array of GeographicCoordinate', Unknown => 1 },
    '060e2b34.0101.0109.07010201.03120000' => { Name => 'GeographicAreaNorthwest', Type => 'GeographicCoordinate', Unknown => 1 },
    '060e2b34.0101.0109.07010201.03130000' => { Name => 'GeographicAreaSoutheast', Type => 'GeographicCoordinate', Unknown => 1 },
    '060e2b34.0101.0109.07010201.03140000' => { Name => 'GeographicAreaSourceDatum', Format => 'string' },
    '060e2b34.0101.0109.07010201.03150000' => { Name => 'GeographicPolygonSourceDatum', Format => 'string' },
    '060e2b34.0101.0109.07012001.02070100' => { Name => 'CountryCodeMethod', Type => 'UTF-16' },
    '060e2b34.0101.0109.07012001.02080100' => { Name => 'ClassifyingCountryCode', Type => 'UTF-16' },
    '060e2b34.0101.0109.07012001.02090100' => { Name => 'ReleasableCountryCode', Type => 'UTF-16' },
    '060e2b34.0101.0109.07020102.01010100' => { Name => 'UTCStartDateTime', Type => 'UTF-16', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0109.07020102.01030000' => { Name => 'UTCInstantDateTime', Format => 'string', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0109.07020102.01030100' => { Name => 'UTCInstantDateTime', Type => 'UTF-16', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0109.07020102.05010100' => { Name => 'UTCLastModifyDate', Type => 'UTF-16', Groups => { 2 => 'Time' } },
    '060e2b34.0101.0109.07020501.00000000' => { Name => 'ToleranceMode', Type => 'ToleranceModeType', Unknown => 1 },
    '060e2b34.0101.0109.07020502.00000000' => { Name => 'ToleranceWindow', Type => 'Indirect', Unknown => 1 },
    '060e2b34.0101.0109.07020503.00000000' => { Name => 'ToleranceInterpolationMethod', Type => 'WeakReferenceInterpolationDefinition', Unknown => 1 },
  # '060e2b34.0101.0109.0d060000.00000000' => { Name => 'ARIB', Type => 'Node' },
  # '060e2b34.0101.0109.0d070000.00000000' => { Name => 'AMIA', Type => 'Node' },
  # '060e2b34.0101.0109.0e0b0000.00000000' => { Name => 'OmneonVideoNetworks', Type => 'Node' },
  # '060e2b34.0101.0109.0e0c0000.00000000' => { Name => 'AscentMediaGroup', Type => 'Node' },
  # '060e2b34.0101.0109.0e0c0100.00000000' => { Name => 'Published', Type => 'Node' },
  # '060e2b34.0101.0109.0e0d0000.00000000' => { Name => 'Quantel', Type => 'Node' },
  # '060e2b34.0101.0109.0e0e0000.00000000' => { Name => 'Panasonic', Type => 'Node' },
    '060e2b34.0101.010a.04010502.03000000' => { Name => 'VBILineCount', Format => 'int16u' },
    '060e2b34.0101.010a.04010502.04000000' => { Name => 'StoredVBILineNumber', Format => 'int16u' },
    '060e2b34.0101.010a.04010502.05000000' => { Name => 'VBIWrappingType', Format => 'int8u' },
    '060e2b34.0101.010a.04010502.06000000' => { Name => 'VBIPayloadSampleCount', Format => 'int16u' },
    '060e2b34.0101.010a.04010502.07000000' => { Name => 'VBIPayloadByteArray', Format => 'int8u' },
    '060e2b34.0101.010a.04010502.08000000' => { Name => 'ANCPacketCount', Format => 'int16u' },
    '060e2b34.0101.010a.04010502.09000000' => { Name => 'StoredANCLineNumber', Format => 'int16u' },
    '060e2b34.0101.010a.04010502.0a000000' => { Name => 'ANCWrappingType', Format => 'int8u' },
    '060e2b34.0101.010a.04010502.0b000000' => { Name => 'ANCPayloadSampleCount', Format => 'int16u' },
    '060e2b34.0101.010a.04010502.0c000000' => { Name => 'ANCPayloadByteArray', Format => 'int8u' },
    '060e2b34.0101.010a.04010503.0f000000' => { Name => 'VBIPayloadSampleCoding', Format => 'int8u' },
    '060e2b34.0101.010a.04010503.10000000' => { Name => 'ANCPayloadSampleCoding', Format => 'int8u' },
  # '060e2b34.0101.010a.04010603.00000000' => { Name => 'JPEG2000CodingParameters', Type => 'Node' },
    '060e2b34.0101.010a.04010603.01000000' => { Name => 'Rsiz', Format => 'int16u' },
    '060e2b34.0101.010a.04010603.02000000' => { Name => 'Xsiz', Format => 'int32u' },
    '060e2b34.0101.010a.04010603.03000000' => { Name => 'Ysiz', Format => 'int32u' },
    '060e2b34.0101.010a.04010603.04000000' => { Name => 'XOsiz', Format => 'int32u' },
    '060e2b34.0101.010a.04010603.05000000' => { Name => 'YOsiz', Format => 'int32u' },
    '060e2b34.0101.010a.04010603.06000000' => { Name => 'XTsiz', Format => 'int32u' },
    '060e2b34.0101.010a.04010603.07000000' => { Name => 'YTsiz', Format => 'int32u' },
    '060e2b34.0101.010a.04010603.08000000' => { Name => 'XTOsiz', Format => 'int32u' },
    '060e2b34.0101.010a.04010603.09000000' => { Name => 'YTOsiz', Format => 'int32u' },
    '060e2b34.0101.010a.04010603.0a000000' => { Name => 'Csiz', Format => 'int16u' },
    '060e2b34.0101.010a.04010603.0b000000' => { Name => 'PictureComponentSizing', Type => 'J2K ComponentSizingArray', Unknown => 1 },
    '060e2b34.0101.010a.04010603.0c000000' => { Name => 'CodingStyleDefault', Type => 'J2K CodingStyleDefault', Unknown => 1 },
    '060e2b34.0101.010a.04010603.0d000000' => { Name => 'QuantizationDefault', Type => 'J2K QuantizationDefault', Unknown => 1 },
    '060e2b34.0101.010a.04020403.01020000' => { Name => 'MPEGAudioBitrate', Format => 'int32u', PrintConv => 'ConvertBitrate($val)', Groups => { 2 => 'Audio' } },
    '060e2b34.0101.010a.04060204.00000000' => { Name => 'CBEStartOffset', Format => 'int64u' },
    '060e2b34.0101.010a.04060205.00000000' => { Name => 'VBEEndOffset', Format => 'int64u' },
    '060e2b34.0101.010a.06010104.02100000' => { Name => 'SubDescriptor', Unknown => 1 },
    '060e2b34.0101.010a.06010104.06100000' => { Name => 'SubDescriptors', Unknown => 1 },
    '060e2b34.0101.010a.06010107.16000000' => { Name => 'RootMetaDictionary', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.010a.06010107.17000000' => { Name => 'RootPreface', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.010a.06010107.18000000' => { Name => 'RootObjectDirectory', Type => 'Array of bytes', Unknown => 1 },
    '060e2b34.0101.010a.06010107.19000000' => { Name => 'RootFormatVersion', Format => 'int32u' },
    '060e2b34.0101.010a.07010201.03160000' => { Name => 'FrameCenterElevation', Format => 'float' },
    '060e2b34.0101.010a.07020103.010e0000' => { Name => 'PackageMarkInPosition', Type => 'Position', %duration },
    '060e2b34.0101.010a.07020103.02040000' => { Name => 'PackageMarkOutPosition', Type => 'Position', %duration },
  # '060e2b34.0101.010a.0d080000.00000000' => { Name => 'PBS', Type => 'Node' },
  # '060e2b34.0101.010a.0e0f0000.00000000' => { Name => 'GrassValley', Type => 'Node' },
  # '060e2b34.0101.010a.0e100000.00000000' => { Name => 'DoremiLabs', Type => 'Node' },
  # '060e2b34.0101.010a.0e110000.00000000' => { Name => 'EVSBroadcastEquipment', Type => 'Node' },
  # '060e2b34.0101.010a.0e120000.00000000' => { Name => 'TurnerBroadcastingSystem', Type => 'Node' },
    '060e2b34.0101.010c.0101110b.00000000' => { Name => 'Ad-ID', Unknown => 1 },
    '060e2b34.0101.010c.01011512.00000000' => { Name => 'ResourceID', Type => 'UUID', Unknown => 1 },
    '060e2b34.0101.010c.01011513.00000000' => { Name => 'AncillaryResourceID', Type => 'UUID', Unknown => 1 },
    '060e2b34.0101.010c.01020210.02030000' => { Name => 'ApplicationSchemeBatch', Type => 'BatchOfUL', Unknown => 1 },
  # '060e2b34.0101.010c.02100202.00000000' => { Name => 'RegisterPublicationInformation', Type => 'Node' },
    '060e2b34.0101.010c.02100202.01000000' => { Name => 'RegisterKind', Type => 'RegisterType', Unknown => 1 },
    '060e2b34.0101.010c.02100202.02000000' => { Name => 'RegisterVersion', Type => 'Hex' },
    '060e2b34.0101.010c.02100202.03000000' => { Name => 'RegisterEditorName', Type => 'UTF-16' },
    '060e2b34.0101.010c.02100202.04000000' => { Name => 'RegisterStatusKind', Type => 'RegisterStatusType', Unknown => 1 },
  # '060e2b34.0101.010c.02100203.00000000' => { Name => 'RegisterItem', Type => 'Node' },
    '060e2b34.0101.010c.02100203.01000000' => { Name => 'RegisterItemName', Type => 'UTF-16' },
    '060e2b34.0101.010c.02100203.02000000' => { Name => 'RegisterItemDefinition', Type => 'UTF-16' },
    '060e2b34.0101.010c.02100203.03000000' => { Name => 'RegisterItemSymbol', Type => 'SymbolType', Unknown => 1 },
    '060e2b34.0101.010c.02100203.04000000' => { Name => 'RegisterItemDefiningDocumentName', Type => 'UTF-16' },
    '060e2b34.0101.010c.02100203.05000000' => { Name => 'RegisterItemUL', Type => 'UniversalLabelType', Unknown => 1 },
    '060e2b34.0101.010c.02100203.06000000' => { Name => 'RegisterItemNotes', Type => 'UTF-16' },
    '060e2b34.0101.010c.02100203.07000000' => { Name => 'RegisterItemIntroductionVersion', Format => 'int8u' },
    '060e2b34.0101.010c.02100203.08000000' => { Name => 'RegisterItemHierarchyLevel', Format => 'int16u' },
  # '060e2b34.0101.010c.02100203.09000000' => { Name => 'RegisterWildcardFlag', Type => 'Node' },
    '060e2b34.0101.010c.02100203.0a000000' => { Name => 'RegisterEntryStatus', Type => 'EntryStatusType', Unknown => 1 },
  # '060e2b34.0101.010c.02100204.00000000' => { Name => 'RegisterAdministration', Type => 'Node' },
    '060e2b34.0101.010c.02100204.01000000' => { Name => 'RegisterAction', Type => 'UTF-16' },
    '060e2b34.0101.010c.02100204.02000000' => { Name => 'RegisterApproverName', Type => 'UTF-16' },
    '060e2b34.0101.010c.02100204.03000000' => { Name => 'RegisterCreationTime', %timestamp },
    '060e2b34.0101.010c.02100204.04000000' => { Name => 'RegistrantName', Type => 'UTF-16' },
    '060e2b34.0101.010c.02100204.05000000' => { Name => 'RegisterItemOriginatorName', Type => 'UTF-16' },
    '060e2b34.0101.010c.02100204.06000000' => { Name => 'RegisterUserName', Type => 'UTF-16' },
    '060e2b34.0101.010c.02100204.07000000' => { Name => 'RegisterUserTime', %timestamp },
    '060e2b34.0101.010c.02100204.08000000' => { Name => 'RegisterAdministrationNotes', Type => 'UTF-16' },
    '060e2b34.0101.010c.04010101.09000000' => { Name => 'AFDAndBarData', Unknown => 1 },
    '060e2b34.0101.010c.04010101.0a000000' => { Name => 'PanScanInformation', Unknown => 1 },
  # '060e2b34.0101.010c.04010604.00000000' => { Name => 'VC-1PictureEssenceDescriptors', Type => 'Node' },
    '060e2b34.0101.010c.04010604.01000000' => { Name => 'VC-1InitializationMetadata', Type => 'DataStream', Unknown => 1 },
    '060e2b34.0101.010c.04010604.02000000' => { Name => 'VC-1SingleSequence', Type => 'Boolean' },
    '060e2b34.0101.010c.04010604.03000000' => { Name => 'VC-1CodedContentType', Format => 'int8u' },
    '060e2b34.0101.010c.04010604.04000000' => { Name => 'VC-1IdenticalGOP', Type => 'Boolean' },
    '060e2b34.0101.010c.04010604.05000000' => { Name => 'VC-1MaximumGOP', Format => 'int16u' },
    '060e2b34.0101.010c.04010604.06000000' => { Name => 'VC-1BPictureCount', Format => 'int16u' },
    '060e2b34.0101.010c.04010604.07000000' => { Name => 'VC-1AverageBitrate', Format => 'int32u', PrintConv => 'ConvertBitrate($val)' },
    '060e2b34.0101.010c.04010604.08000000' => { Name => 'VC-1MaximumBitrate', Format => 'int32u', PrintConv => 'ConvertBitrate($val)' },
    '060e2b34.0101.010c.04010604.09000000' => { Name => 'VC-1Profile', Format => 'int8u' },
    '060e2b34.0101.010c.04010604.0a000000' => { Name => 'VC-1Level', Format => 'int8u' },
    '060e2b34.0101.010c.04020501.07000000' => { Name => 'LinkedTimecodeTrackID', Type => 'UInt32Array', Unknown => 1 },
    '060e2b34.0101.010c.04020501.08000000' => { Name => 'SMPTE337MDataStreamNumber', Format => 'int8u' },
    '060e2b34.0101.010c.04060803.00000000' => { Name => 'ApplicationScheme', Type => 'UL', Unknown => 1 },
    '060e2b34.0101.010c.04060804.00000000' => { Name => 'DescriptiveMetadataScheme', Type => 'UL', Unknown => 1 },
    '060e2b34.0101.010c.04090500.00000000' => { Name => 'UCSEncoding', Type => 'UTF-16' },
    '060e2b34.0101.010c.05200701.0b000000' => { Name => 'LinkedApplicationPlug-InInstanceID', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.010c.05200701.0c000000' => { Name => 'LinkedDescriptiveFrameworkPlug-InID', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.010c.05200701.0d000000' => { Name => 'ApplicationPlug-InInstanceID', Type => 'UUID', Unknown => 1 },
    '060e2b34.0101.010c.05200701.0e000000' => { Name => 'DescriptiveMetadataPlug-InID', Type => 'UUID', Unknown => 1 },
    '060e2b34.0101.010c.05200701.0f000000' => { Name => 'ApplicationEnvironmentID', Type => 'UTF-16' },
    '060e2b34.0101.010c.05200701.10000000' => { Name => 'DescriptiveMetadataApplicationEnvironmentID', Type => 'UTF-16' },
    '060e2b34.0101.010c.05200701.11000000' => { Name => 'LinkedDescriptiveObjectPlug-InID', Type => 'WeakReference', Unknown => 1 },
    '060e2b34.0101.010c.06010103.0e000000' => { Name => 'TimebaseReferenceTrackID', Format => 'int32u' },
    '060e2b34.0101.010c.06010104.010b0000' => { Name => 'ObjectClassDefinition', Type => 'AUID', Unknown => 1 },
    '060e2b34.0101.010c.06010104.020e0000' => { Name => 'ApplicationPlug-InBatch', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.010c.06010104.020f0000' => { Name => 'PackageMarker', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.010c.06010104.02100000' => { Name => 'PackageTimelineMarkerRef', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.010c.06010104.02110000' => { Name => 'RegisterAdministrationObject', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.010c.06010104.02120000' => { Name => 'RegisterEntryAdministrationObject', Type => 'StrongReference', Unknown => 1 },
    '060e2b34.0101.010c.06010104.03060000' => { Name => 'GenericPayloads', Type => 'WeakReferenceBatch', Unknown => 1 },
    '060e2b34.0101.010c.06010104.06110000' => { Name => 'RegisterEntryArray', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.010c.06010104.06120000' => { Name => 'RegisterAdministrationArray', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.010c.06010104.06130000' => { Name => 'ApplicationInformationArray', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.010c.06010104.06140000' => { Name => 'RegisterChildEntryArray', Type => 'StrongReferenceArray', Unknown => 1 },
    '060e2b34.0101.010c.07020101.01060000' => { Name => 'RegisterReleaseDateTime', %timestamp },
    '060e2b34.0101.010c.07020101.01070000' => { Name => 'RegisterItemStatusChangeDateTime', %timestamp },
  # '060e2b34.0101.010c.0d090000.00000000' => { Name => 'ASC', Type => 'Node' },
  # '060e2b34.0101.010c.0d0a0000.00000000' => { Name => 'AES', Type => 'Node' },
  # '060e2b34.0101.010c.0d0b0000.00000000' => { Name => 'DutchGuild', Type => 'Node' },
  # '060e2b34.0101.010c.0e130000.00000000' => { Name => 'NLTechnologyLLC', Type => 'Node' },
  # '060e2b34.0101.010c.0e140000.00000000' => { Name => 'HarrisCorporation', Type => 'Node' },

  # data types (not used as tag ID's, right?)
  # '060e2b34.0104.0101.01010100.00000000' => { Name => 'UInt8' },
  # '060e2b34.0104.0101.01010200.00000000' => { Name => 'UInt16' },
  # '060e2b34.0104.0101.01010300.00000000' => { Name => 'UInt32' },
  # '060e2b34.0104.0101.01010400.00000000' => { Name => 'UInt64' },
  # '060e2b34.0104.0101.01010500.00000000' => { Name => 'Int8' },
  # '060e2b34.0104.0101.01010600.00000000' => { Name => 'Int16' },
  # '060e2b34.0104.0101.01010700.00000000' => { Name => 'Int32' },
  # '060e2b34.0104.0101.01010800.00000000' => { Name => 'Int64' },
  # '060e2b34.0104.0101.01012001.00000000' => { Name => 'Position' },
  # '060e2b34.0104.0101.01012002.00000000' => { Name => 'LengthType' },
  # '060e2b34.0104.0101.01030100.00000000' => { Name => 'AUID' },
  # '060e2b34.0104.0101.01030200.00000000' => { Name => 'PackageID' },
  # '060e2b34.0104.0101.01040100.00000000' => { Name => 'Boolean' },
  # '060e2b34.0104.0101.01100100.00000000' => { Name => 'UTF16' },
  # '060e2b34.0104.0101.01100200.00000000' => { Name => 'UTF16String' },
  # '060e2b34.0104.0101.01100300.00000000' => { Name => 'ISO7' },
  # '060e2b34.0104.0101.01100400.00000000' => { Name => 'ISO7String' },
  # '060e2b34.0104.0101.01200500.00000000' => { Name => 'UTF7String' },
  # '060e2b34.0104.0101.01300100.00000000' => { Name => 'UMID' },
  # '060e2b34.0104.0101.0201010e.00000000' => { Name => 'RGBACode' },
  # '060e2b34.0104.0101.02010125.00000000' => { Name => 'ChannelStatusModeType' },
  # '060e2b34.0104.0101.03010100.00000000' => { Name => 'Rational' },
  # '060e2b34.0104.0101.03010101.00000000' => { Name => 'Numerator' },
  # '060e2b34.0104.0101.03010102.00000000' => { Name => 'Denominator' },
  # '060e2b34.0104.0101.03010200.00000000' => { Name => 'ProductVersionType' },
  # '060e2b34.0104.0101.03010201.00000000' => { Name => 'Major' },
  # '060e2b34.0104.0101.03010202.00000000' => { Name => 'Minor' },
  # '060e2b34.0104.0101.03010203.00000000' => { Name => 'Patch' },
  # '060e2b34.0104.0101.03010204.00000000' => { Name => 'Build' },
  # '060e2b34.0104.0101.03010205.00000000' => { Name => 'Release' },
  # '060e2b34.0104.0101.03010300.00000000' => { Name => 'VersionType' },
  # '060e2b34.0104.0101.03010400.00000000' => { Name => 'RGBALayoutItem' },
  # '060e2b34.0104.0101.03010501.00000000' => { Name => 'Year' },
  # '060e2b34.0104.0101.03010502.00000000' => { Name => 'Month' },
  # '060e2b34.0104.0101.03010503.00000000' => { Name => 'Day' },
  # '060e2b34.0104.0101.03010601.00000000' => { Name => 'Hours' },
  # '060e2b34.0104.0101.03010602.00000000' => { Name => 'Minutes' },
  # '060e2b34.0104.0101.03010603.00000000' => { Name => 'Seconds' },
  # '060e2b34.0104.0101.03010604.00000000' => { Name => 'msBy4' },
  # '060e2b34.0104.0101.03010700.00000000' => { Name => 'Timestamp' },
  # '060e2b34.0104.0101.04010100.00000000' => { Name => 'UInt8Array' },
  # '060e2b34.0104.0101.04010300.00000000' => { Name => 'Int32Array' },
  # '060e2b34.0104.0101.04010400.00000000' => { Name => 'Int64Array' },
  # '060e2b34.0104.0101.04010600.00000000' => { Name => 'AUIDArray' },
  # '060e2b34.0104.0101.04020100.00000000' => { Name => 'RGBALayout' },
  # '060e2b34.0104.0101.04020200.00000000' => { Name => 'RationalArray' },
  # '060e2b34.0104.0101.04030200.00000000' => { Name => 'UInt32Batch' },
  # '060e2b34.0104.0101.04100100.00000000' => { Name => 'DataValue' },
  # '060e2b34.0104.0101.04100200.00000000' => { Name => 'Stream' },
  # '060e2b34.0104.0101.04100300.00000000' => { Name => 'Indirect' },
  # '060e2b34.0104.0101.04100400.00000000' => { Name => 'Opaque' },
  # '060e2b34.0104.0101.05010000.00000000' => { Name => 'WeakRef' },
  # '060e2b34.0104.0101.05020000.00000000' => { Name => 'StrongRef' },
  # '060e2b34.0104.0101.05021400.00000000' => { Name => 'StrongReferenceTrack' },
  # '060e2b34.0104.0101.05060500.00000000' => { Name => 'StrongReferenceVectorTrack' },
  # '060e2b34.0204.0107.0d010301.027e0100' => { Name => 'EncryptedTriplet' },

    '060e2b34.0205.0101.0d010201.01020100' => { Name => 'OpenHeader', %header },
    '060e2b34.0205.0101.0d010201.01020200' => { Name => 'ClosedHeader', %header },
    '060e2b34.0205.0101.0d010201.01020300' => { Name => 'OpenCompleteHeader', %header },
    '060e2b34.0205.0101.0d010201.01020400' => { Name => 'ClosedCompleteHeader', %header },
    '060e2b34.0205.0101.0d010201.01030100' => { Name => 'OpenBodyPartition', Unknown => 1 },
    '060e2b34.0205.0101.0d010201.01030200' => { Name => 'ClosedBodyPartition', Unknown => 1 },
    '060e2b34.0205.0101.0d010201.01030300' => { Name => 'OpenCompleteBodyPartition', Unknown => 1 },
    '060e2b34.0205.0101.0d010201.01030400' => { Name => 'ClosedCompleteBodyPartition', Unknown => 1 },
    '060e2b34.0205.0101.0d010201.01040200' => { Name => 'Footer', Unknown => 1 },
    '060e2b34.0205.0101.0d010201.01040400' => { Name => 'CompleteFooter', Unknown => 1 },

    '060e2b34.0205.0101.0d010201.01050100' => { Name => 'Primer', SubDirectory => { TagTable => 'Image::ExifTool::MXF::Main', ProcessProc => \&ProcessPrimer } },

    '060e2b34.0205.0101.0d010201.01110000' => { Name => 'RandomIndexMetadataV10', Type => 'FixedPack', Unknown => 1 },
    '060e2b34.0205.0101.0d010201.01110100' => { Name => 'RandomIndexMetadata', Type => 'FixedPack', Unknown => 1 },
    '060e2b34.0206.0101.0d010200.00000000' => { Name => 'PartitionMetadata', Type => 'FixedPack', Unknown => 1 },

    '060e2b34.0253.0101.0d010101.01010200' => { Name => 'StructuralComponent', %localSet },
    '060e2b34.0253.0101.0d010101.01010f00' => { Name => 'SequenceSet', %localSet },
    # Note: SourceClip is actually a local set, but it isn't decoded because it has a Duration
    # tag which gets confused with the other Duration tags (also, my technique of determining
    # the corresponding EditRate doesn't seem to work for this Duration)
    '060e2b34.0253.0101.0d010101.01011100' => { Name => 'SourceClip', Unknown => 1 },
    '060e2b34.0253.0101.0d010101.01011400' => { Name => 'TimecodeComponent', %localSet },
    '060e2b34.0253.0101.0d010101.01011800' => { Name => 'ContentStorageSet', %localSet },
    '060e2b34.0253.0101.0d010101.01012300' => { Name => 'EssenceContainerDataSet', %localSet },
    '060e2b34.0253.0101.0d010101.01012500' => { Name => 'FileDescriptor', %localSet },
    '060e2b34.0253.0101.0d010101.01012700' => { Name => 'GenericPictureEssenceDescriptor', %localSet },
    '060e2b34.0253.0101.0d010101.01012800' => { Name => 'CDCIEssenceDescriptor', %localSet },
    '060e2b34.0253.0101.0d010101.01012900' => { Name => 'RGBAEssenceDescriptor', %localSet },
    '060e2b34.0253.0101.0d010101.01012f00' => { Name => 'Preface', %localSet },
    '060e2b34.0253.0101.0d010101.01013000' => { Name => 'Identification', %localSet },
    '060e2b34.0253.0101.0d010101.01013200' => { Name => 'NetworkLocator', %localSet },
    '060e2b34.0253.0101.0d010101.01013300' => { Name => 'TextLocator', %localSet },
    '060e2b34.0253.0101.0d010101.01013400' => { Name => 'GenericPackage', %localSet },
    '060e2b34.0253.0101.0d010101.01013600' => { Name => 'MaterialPackage', %localSet },
    '060e2b34.0253.0101.0d010101.01013700' => { Name => 'SourcePackage', %localSet },
    '060e2b34.0253.0101.0d010101.01013800' => { Name => 'GenericTrack', %localSet },
    '060e2b34.0253.0101.0d010101.01013900' => { Name => 'EventTrack', %localSet },
    '060e2b34.0253.0101.0d010101.01013a00' => { Name => 'StaticTrack', %localSet },
    '060e2b34.0253.0101.0d010101.01013b00' => { Name => 'Track', %localSet },
    '060e2b34.0253.0101.0d010101.01014100' => { Name => 'DMSegment', %localSet },
    '060e2b34.0253.0101.0d010101.01014200' => { Name => 'GenericSoundEssenceDescriptor', %localSet },
    '060e2b34.0253.0101.0d010101.01014300' => { Name => 'GenericDataEssenceDescriptor', %localSet },
    '060e2b34.0253.0101.0d010101.01014400' => { Name => 'MultipleDescriptor', %localSet },
    '060e2b34.0253.0101.0d010101.01014500' => { Name => 'DMSourceClip', %localSet },
    '060e2b34.0253.0101.0d010101.01014700' => { Name => 'AES3PCMDescriptor', %localSet },
    '060e2b34.0253.0101.0d010101.01014800' => { Name => 'WaveAudioDescriptor', %localSet },
    '060e2b34.0253.0101.0d010101.01015100' => { Name => 'MPEG2VideoDescriptor', %localSet },
    '060e2b34.0253.0101.0d010101.01015a00' => { Name => 'JPEG2000PictureSubDescriptor', %localSet },
    '060e2b34.0253.0101.0d010101.01015b00' => { Name => 'VBIDataDescriptor', %localSet },
    # ignore the index table sets because they contain no useful metadata
    '060e2b34.0253.0101.0d010201.01100000' => { Name => 'V10IndexTableSegment', Unknown => 1 },
    '060e2b34.0253.0101.0d010201.01100100' => { Name => 'IndexTableSegment', Unknown => 1 },
    '060e2b34.0253.0101.0d010400.00000000' => { Name => 'DMSet', %localSet },
    '060e2b34.0253.0101.0d010401.00000000' => { Name => 'DMFramework', %localSet },

    # DMS1 local sets (ref 12)
    '060e2b34.0253.0101.0d010401.01010100' => { Name => 'ProductionFramework', %localSet },
    '060e2b34.0253.0101.0d010401.01010200' => { Name => 'ClipFramework', %localSet },
    '060e2b34.0253.0101.0d010401.01010300' => { Name => 'SceneFramework', %localSet },
    '060e2b34.0253.0101.0d010401.01100100' => { Name => 'Titles', %localSet },
    '060e2b34.0253.0101.0d010401.01110100' => { Name => 'Identification', %localSet },
    '060e2b34.0253.0101.0d010401.01120100' => { Name => 'GroupRelationship', %localSet },
    '060e2b34.0253.0101.0d010401.01130100' => { Name => 'Branding', %localSet },
    '060e2b34.0253.0101.0d010401.01140100' => { Name => 'Event', %localSet },
    '060e2b34.0253.0101.0d010401.01140200' => { Name => 'Publication', %localSet },
    '060e2b34.0253.0101.0d010401.01150100' => { Name => 'Award', %localSet },
    '060e2b34.0253.0101.0d010401.01160100' => { Name => 'CaptionDescription', %localSet },
    '060e2b34.0253.0101.0d010401.01170100' => { Name => 'Annotation', %localSet },
    '060e2b34.0253.0101.0d010401.01170200' => { Name => 'SettingPeriod', %localSet },
    '060e2b34.0253.0101.0d010401.01170300' => { Name => 'Scripting', %localSet },
    '060e2b34.0253.0101.0d010401.01170400' => { Name => 'Classification', %localSet },
    '060e2b34.0253.0101.0d010401.01170500' => { Name => 'Shot', %localSet },
    '060e2b34.0253.0101.0d010401.01170600' => { Name => 'KeyPoint', %localSet },
    '060e2b34.0253.0101.0d010401.01170800' => { Name => 'CueWords', %localSet },
    '060e2b34.0253.0101.0d010401.01180100' => { Name => 'Participant', %localSet },
    '060e2b34.0253.0101.0d010401.01190100' => { Name => 'ContactsList', %localSet },
    '060e2b34.0253.0101.0d010401.011a0200' => { Name => 'Person', %localSet },
    '060e2b34.0253.0101.0d010401.011a0300' => { Name => 'Organisation', %localSet },
    '060e2b34.0253.0101.0d010401.011a0400' => { Name => 'Location', %localSet },
    '060e2b34.0253.0101.0d010401.011b0100' => { Name => 'Address', %localSet },
    '060e2b34.0253.0101.0d010401.011b0200' => { Name => 'Communications', %localSet },
    '060e2b34.0253.0101.0d010401.011c0100' => { Name => 'Contract', %localSet },
    '060e2b34.0253.0101.0d010401.011c0200' => { Name => 'Rights', %localSet },
    '060e2b34.0253.0101.0d010401.011d0100' => { Name => 'PictureFormat', %localSet },
    '060e2b34.0253.0101.0d010401.011e0100' => { Name => 'DeviceParameters', %localSet },
    '060e2b34.0253.0101.0d010401.011f0100' => { Name => 'NameValue', %localSet },
    '060e2b34.0253.0101.0d010401.01200100' => { Name => 'Processing', %localSet },
    '060e2b34.0253.0101.0d010401.01200200' => { Name => 'Projects', %localSet },

    '060e2b34.0253.0101.0d010401.02010000' => { Name => 'CryptographicFramework', %localSet },
    '060e2b34.0253.0101.0d010401.02020000' => { Name => 'CryptographicContext', %localSet },

    '060e2b34.0253.0101.7f000000.00000000' => { Name => 'DefaultObject', Unknown => 1 },
    '060e2b34.0401.0107.02090201.01000000' => { Name => 'CipherAlgorithmAES128CBC', Type => 'Label', Unknown => 1 },
    '060e2b34.0401.0107.02090202.01000000' => { Name => 'HMACAlgorithmSHA1128', Type => 'Label', Unknown => 1 },
    '060e2b34.0401.0107.0d010301.020b0100' => { Name => 'EncryptedContainerLabel', Type => 'Label', Unknown => 1 },
    '060e2b34.0401.0107.0d010401.02010100' => { Name => 'CryptographicFrameworkLabel', Type => 'Label', Unknown => 1 },
);

# header information
%Image::ExifTool::MXF::Header = (
    GROUPS => { 2 => 'Video' },
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    0 => {
        Name => 'MXFVersion',
        Format => 'int16u[2]',
        ValueConv => '$val =~ tr/ /./; $val',
    },
    # 4 - int32u: KAGSize
    # 8 - int64u: bytes from first header
    # 16 - int64u: bytes from previous partition
    24 => { # bytes to footer from start of header
        Name => 'FooterPosition',
        Format => 'int64u',
        RawConv => '$$self{MXFInfo}{FooterPos} = $val; undef',
    },
    32 => { # number of bytes in header, beginning at the start of the Primer
        Name => 'HeaderSize',
        Format => 'int64u',
        # use this opportinity to also save our header type
        RawConv => q{
            $$self{MXFInfo}{HeaderType} = $$self{DIR_NAME};
            $$self{MXFInfo}{HeaderSize} = $val;
            return undef; # I don't think anyone would care about this
        },
    },
    # ...plus more stuff we don't care about
);

#------------------------------------------------------------------------------
# Convert 16 bytes to UL format
# Inputs: 0) 16-byte value
# Returns: UL string
sub UL($)
{
    return join('.', unpack('H8H4H4H8H8', shift));;
}

#------------------------------------------------------------------------------
# Convert latitude and/or longitude in [d]ddmmss(N|S|E|W) format
# Inputs: 0) string value to convert
# Returns: numerical lat and/or long
sub ConvLatLon($)
{
    my $val = shift;
    my (@convVal, $ne);
    foreach $ne ('NS','EW') {
        next unless $val =~ /(\d{2,3})(\d{2})(\d{2})([$ne])/;
        push @convVal, $1 + ($2 + $3 / 60) / 60 * (($4 eq 'N' or $4 eq 'E') ? 1 : -1);
    }
    return join ' ', @convVal;
}

#------------------------------------------------------------------------------
# Read MXF-specific Format types
# Inputs: 0) ExifTool ref, 1) value, 2) MXF value type
# Returns: formatted value
# Note: All types recognized here should be defined in the %knownType lookup
sub ReadMXFValue($$$)
{
    my ($et, $val, $type) = @_;
    my $len = length($val);
    local $_;

    if ($type eq 'UTF-16') {
        $val = $et->Decode($val, 'UCS2'); # (until we handle UTF-16 properly)
    } elsif ($type eq 'ProductVersion') {
        my @a = unpack('n*', $val);
        push @a, 0 while @a < 5;
        $a[4] = { 0 => 'unknown', 1 => 'released', 2 => 'debug', 3 => 'patched',
                  4 => 'beta', 5 => 'private build' }->{$a[4]} || "unknown $a[4]";
        $val = join('.', @a[0..3]) . ' ' . $a[4];
    } elsif ($type eq 'VersionType') {
        $val = join('.',unpack('C*',$val));
    } elsif ($type eq 'Timestamp') {
        my @a = unpack('nC*',$val);
        my @max = (3000,12,31,24,59,59,249);
        foreach (@a) {
            last unless @max and $_ <= $max[0];
            shift @max;
        }
        if (@max) {
            $val = 'Invalid (0x' . unpack('H*',$val) . ')';
        } else {
            $a[6] *= 4;
            $val = sprintf('%.4d:%.2d:%.2d %.2d:%.2d:%.2d.%.3d', @a);
        }
    } elsif ($type eq 'Position' or $type eq 'Length') {
        $val = Get64u(\$val, 0);
    } elsif ($type eq 'Boolean') {
        $val = $val eq "\0" ? 'False' : 'True';
    } elsif ($type =~ /^(Alt|Lat|Lon)$/ and $len == 4) {
        # split into nibbles after swapping byte order (see reference 8b)
        $val = unpack('H*', pack('N', unpack('V', $val)));
        if ($type eq 'Alt') {
            # drop satellite information and only support altitudes up to +/-99999 m
            $val = "$val (from earth centre)" unless $val =~ s/^[abc]..// or $val =~ s/^[def]../-/;
        } else {
            $val =~ s/(...)/$1./;   # insert decimal point after 3rd character
            if ($type eq 'Lat') {
                $val =~ s/^f/-/;    # south with first digit = 0
            } else {
                $val =~ s/^e/-/;    # east with first digit = 0
                $val =~ s/^f/-1/;   # east with first digit = 1
            }
        }
    } elsif ($type =~ /(Array|Batch)/ and $len > 16) {
        my ($count, $size) = unpack('NN', $val);
        # validate data length
        $len == 8 + $count * $size or $et->WarnOnce("Bad array or batch size");
        my ($i, @a);
        for ($i=0; $i<$count; ++$i) {
            my $pos = 8 + $i * $size;
            last if $pos + $size > $len;
            push @a, substr($val, $pos, $size);
        }
        if ($type =~ /^StrongReference/) {
            $_ = join('-', unpack('H8H4H4H4H12', $_)) foreach @a;
        } elsif ($type eq 'BatchOfUL' or $type =~ /^WeakReference/) {
            $_ = ReadMXFValue($et, $_, 'UL') foreach @a;
        }
        $val = \@a;
    } elsif ($len == 32) {
        # 32-byte types include UMID, PackageID
        $val = join('.', unpack('H8H4H4H8', $val)) . ' ' .
               join(' ', unpack('x12H2H6', $val)) . ' ' .
               join('-', unpack('x16H8H4H4H4H12', $val));
    } elsif ($len == 16) {
        # convert remaining 16-byte known types as GUID or UL
        # - this covers all UID's, UL, Label, WeakReference, StrongReference
        if ($type eq 'UL' or $type eq 'WeakReference') {
            # reverse high/low word if a reversed GUID is stored in a UL type
            # (see ref 8b, section 5.5.8)
            # - a GUID will have high bit of byte 8 set (reversed, this is in byte 0)
            return UL($val) unless unpack('C', $val) & 0x80;
            $val = substr($val, 8) . substr($val, 0, 8);
        }
        $val = join('-', unpack('H8H4H4H4H12', $val)); # compact GUID format
    } else {
        # Note: a 64-byte extended UMID contains date/time, GPS coordinates, etc,
        # which would could be decoded here (ref 8b, section 5)...
        $val = unpack('H*', $val);
    }
    return $val;
}

#------------------------------------------------------------------------------
# Process MXF Primer (to build lookup for translating local tag ID's)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessPrimer($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $end = $$dirInfo{DirLen};
    return 0 unless $end > 8;
    my $count = Get32u($dataPt, 0);
    my $size = Get32u($dataPt, 4);
    return 0 unless $size >= 18;
    $et->VerboseDir('MXF Primer', $count);
    my $verbose = $et->Options('Verbose');
    my $primer = $$et{MXFInfo}{Primer};
    my $pos = 8;
    my $i;
    for ($i=0; $i<$count; ++$i) {
        last if $pos + $size > $end;
        my $local = Get16u($dataPt, $pos);
        my $global = UL(substr($$dataPt, $pos + 2, 16));
        $pos += $size;
        # save this entry in the primer lookup table
        $$primer{$local} = $global;
        # print lookup details in verbose mode
        next unless $verbose;
        my $indx = $i . ')';
        $indx .= ' ' if length($indx) < 3;
        $et->VPrint(0, sprintf("  | $indx 0x%.4x => '${global}'\n", $local));
    }
    return 1;
}

#------------------------------------------------------------------------------
# Read tags from an MXF local set
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessLocalSet($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    local $_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $end = $$dirInfo{DirLen};
    my $mxfInfo = $$et{MXFInfo};
    my $primer = $$mxfInfo{Primer};
    my (@strongRef, @groups, $instance, $editRate, $trackID, $langCode, $textLang);

    $et->VerboseDir('MXF LocalSet', undef, $end);

    # loop through all tags in this local set
    my $pos = 0;
    while ($pos + 4 < $end) {
        my $loc = Get16u($dataPt, $pos);        # get key (local tag ID)
        my $len = Get16u($dataPt, $pos + 2);    # get length
        $pos += 4;
        last if $pos + $len > $end;
        my $tag = $$primer{$loc};
        my ($extra, $val, $type, $langInfo);
        if ($tag and $$tagTablePtr{$tag}) {
            $extra = sprintf(', Local 0x%.4x', $loc);
        } else {
            $tag = $loc;
          # $et->WarnOnce('Missing local key for at least one tag');
            $extra = ', NOT IN PRIMER!';
        }
        my $tagInfo = $$tagTablePtr{$tag};
        # handle our MXF-specific format types
        if ($tagInfo) {
            $type = $$tagInfo{Type};
            if ($type and $knownType{$type}) {
                $val = ReadMXFValue($et, substr($$dataPt, $pos, $len), $type);
                push @strongRef, (ref $val ? @$val : $val) if $type =~ /^StrongReference/;
                # remember instance UID of this local set
                if ($$tagInfo{Name} eq 'InstanceUID') {
                    $instance = $val;
                    # set language code for text
                    # (only works if InstanceUID comes before text)
                    $textLang = $$mxfInfo{$instance}{LangCode} if $$mxfInfo{$instance};
                } elsif ($type eq 'UTF-16' and $textLang) {
                    $langInfo = Image::ExifTool::GetLangInfo($tagInfo, $textLang);
                }
            }
        }
        # get tagInfo ref the standard way to handle Unknown tags
        $tagInfo = $langInfo || $et->GetTagInfo($tagTablePtr, $tag);
        # set Binary flag to extract all unknown-format tags as Binary data
        if ($tagInfo and $$tagInfo{Unknown} and not defined $$tagInfo{Binary}) {
            $$tagInfo{Binary} = not ($$tagInfo{Format} or ($type and $knownType{$type}));
        }
        my $key = $et->HandleTag($tagTablePtr, $tag, $val,
            Extra       => $extra,
            TagInfo     => $tagInfo,
            DataPt      => $dataPt,
            DataPos     => $dataPos,
            Start       => $pos,
            Size        => $len,
            ProcessProc => \&ProcessLocalSet,
        );
        $pos += $len;
        next unless $key;
        # save information to allow later fixup of durations and group1 names
        # (necessary because we don't have all the information we need
        #  to do this on the fly when the file is parsed linearly)
        push @groups, $$et{TAG_EXTRA}{$key};
        next unless $tagInfo;
        my $name = $$tagInfo{Name};
        if ($$tagInfo{IsDuration}) {
            $$mxfInfo{FixDuration}{$key} = 1;
        } elsif ($$tagInfo{LanguageCode}) {
            $langCode = $$et{VALUE}{$key};
        } elsif ($name eq 'EditRate') {
            $editRate = $$et{VALUE}{$key};
        } elsif ($name =~ /TrackID$/) {
            $trackID = $$et{VALUE}{$key};
            unless ($$mxfInfo{Group1}{$trackID}) {
                # save lookup to convert TrackID to our group 1 name
                $$mxfInfo{Group1}{$trackID} = 'Track' . ++$$mxfInfo{NumTracks};
            }
        }
    }

    # save object information now that we know the instance UID
    if ($instance) {
        my $objInfo = $$mxfInfo{$instance};
        if ($objInfo) {
            push @{$$objInfo{StrongRef}}, @strongRef;
            push @{$$objInfo{Groups}}, @groups;
        } else {
            $objInfo = $$mxfInfo{$instance} = {
                StrongRef => \@strongRef,
                Groups => \@groups,
            };
        }
        # save instance UID's in groups hash (used to remove duplicates later)
        $$_{UID} = $instance foreach @groups;
        $$objInfo{Name} = $$et{DIR_NAME};
        $$objInfo{TrackID} = $trackID if defined $trackID;
        $$objInfo{EditRate} = $editRate if $editRate;
        if ($langCode) {
            $$objInfo{LangCode} = $langCode;
        } else {
            $langCode = $$objInfo{LangCode};
        }
        if ($langCode) {
            # pre-set language code in all children
            my $ul;
            foreach $ul (@{$$objInfo{StrongRef}}) {
                my $obj = $$mxfInfo{$ul};
                $obj or $obj = $$mxfInfo{$ul} = { StrongRef => [], Groups => [], Name => 'XXX' };
                $$obj{LangCode} = $langCode;
            }
        }
        # save instance UID's of Preface's
        push @{$$mxfInfo{Preface}}, $instance if $$et{DIR_NAME} eq 'Preface';
    }
    return 1;
}

#------------------------------------------------------------------------------
# Walk MXF tree to set group names
# Inputs: 0) MXF information hash ref, 1) object instance UID,
#         2) path information hash ref (only for group 5 names), 3) track ID number
# Notes: also generates lookup table for EditRate based on group 1 name
#        and the instance UID of the SequenceSet with the preferred Duration value
sub SetGroups($$;$$)
{
    my ($mxfInfo, $instance, $pathInfo, $trackID) = @_;
    my $objInfo = $$mxfInfo{$instance};
    return unless $objInfo and not $$objInfo{DidGroups};
    $$objInfo{DidGroups} = 1;   # avoid reprocessing this object
    $trackID = $$objInfo{TrackID} if defined $$objInfo{TrackID};
    my ($ul, $g1, $g5, $groups, $path, $nameCount, $setSource);
    # generate group 1 name for different tracks
    if (defined $trackID) {
        $$objInfo{TrackID} = $trackID;
        $g1 = $$mxfInfo{Group1}{$trackID};
        # build a lookup to determine edit rates based on group 1 name
        my $editRate = $$objInfo{EditRate};
        $$mxfInfo{EditRate}{$g1} = $editRate if defined $editRate;
        # save the TimeCodeComponent instance UID (for determining Duration later)
        if ($$objInfo{Name} eq 'TimecodeComponent') {
            my $inWhat = $$mxfInfo{InSource} ? 'Source' : 'Other';
            $$mxfInfo{BestDuration}{$inWhat} = $instance;
        }
    }
    # set flag if we are in the SourcePackage (contains our preferred TimecodeComponent)
    my $name = $$objInfo{Name};
    $setSource = $$mxfInfo{InSource} = 1 if $name eq 'SourcePackage';

    # generate group 5 path names if requested
    if ($pathInfo) {
        $nameCount = $$pathInfo{NameCount} || { };
        $path = $$pathInfo{Path};
        $$nameCount{$name} = ($$nameCount{$name} || 0) + 1;
        push @$path, $name . $$nameCount{$name};
        $g5 = join '-', @$path;
        $$pathInfo{NameCount} = { };    # use new name count for child objects
    }
    foreach $groups (@{$$objInfo{Groups}}) {
        $$groups{G1} = $g1 if $g1;
        $$groups{G5} = $g5 if $g5;
    }
    # walk through remaining objects in tree
    foreach $ul (@{$$objInfo{StrongRef}}) {
        SetGroups($mxfInfo, $ul, $pathInfo, $trackID);
    }
    if ($pathInfo) {
        pop @$path;
        $$pathInfo{NameCount} = $nameCount;
    }
    delete $$mxfInfo{InSource} if $setSource;
}

#------------------------------------------------------------------------------
# Convert all duration values to seconds
# Inputs: 0) ExifTool object ref, 1) MXF information hash ref
sub ConvertDurations($$)
{
    my ($et, $mxfInfo) = @_;
    my $valueHash = $$et{VALUE};
    my $infoHash = $$et{TAG_INFO};
    my $tagExtra = $$et{TAG_EXTRA};
    my $editHash = $$mxfInfo{EditRate};
    my ($tag, $key, $i);
    foreach $tag (keys %{$$mxfInfo{FixDuration}}) {
        # loop through all instances of this tag name
        for ($i=0, $key=$tag; ; ++$i, $key="$tag ($i)") {
            my $tagInfo = $$infoHash{$key} or last;
            next unless $$tagInfo{IsDuration};  # test IsDuration flag to be sure
            my $g1 = $$tagExtra{$key}{G1} or next;
            my $editRate = $$editHash{$g1};
            $$valueHash{$key} /= $editRate if $editRate;
        }
    }
}

#------------------------------------------------------------------------------
# Read information in a MXF file
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid MXF file
sub ProcessMXF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $verbose = $et->Options('Verbose');
    my $unknown = $et->Options('Unknown');
    my ($buff, $preface, $n, $headerEnd, $footerPos);

    # read enough to allow skipping over run-in if it exists
    $raf->Read($buff, 65547) or return 0;
    $buff =~ /\x06\x0e\x2b\x34\x02\x05\x01\x01\x0d\x01\x02/g or return 0;
    my $start = pos($buff) - 11;

    $et->SetFileType();
    SetByteOrder('MM');
    $raf->Seek($start, 0) or $et->Warn('Seek error'), return 1;
    my $tagTablePtr = GetTagTable('Image::ExifTool::MXF::Main');

    # determine header length and type

    # initialize MXF information lookups
    my %mxfInfo = (
        Primer => { },      # convert local keys to global UL
        Group1 => { },      # group 1 names base on TrackID
        NumTracks => 0,     # counts number of tracks in file
        FixDuration => { }, # names of all Duration tags that need fixing
        Preface => [ ],     # instance UID's for all Preface objects
    );
    $$et{MXFInfo} = \%mxfInfo;

    # set group 1 name for all tags (so we can overwrite with track number later)
    $$et{SET_GROUP1} = 'MXF';

    for (;;) {
        my $pos = $raf->Tell();
        # did we just finish parsing the header partition?
        if ($headerEnd and $pos >= $headerEnd) {
            # all done if it was a closed and complete header
            last if $mxfInfo{HeaderType} eq 'ClosedCompleteHeader' and not $verbose;
            undef $headerEnd;   # (only test this once)
            # skip directly to footer if possible
            if ($footerPos and $footerPos > $pos and (not $verbose or not $unknown)) {
                $et->VPrint(0, "[Skipping to footer. Use Unknown option to parse body partitions]\n");
                $raf->Seek($footerPos, 0) or last;
                $pos = $footerPos;
            }
        }
        # read the next KLV Key and first byte of Value
        $raf->Read($buff, 17) == 17 or last;
        my $tag = substr($buff, 0, 16);     # get KLV Key (global tag ID)
        my $len = Get8u(\$buff, 16);        # get KLV Length
        my $n;
        if ($len >= 0x80) {
            $n = $len & 0x7f;
            $raf->Read($buff, $n) == $n or last;
            $len = 0;
            foreach $b (unpack 'C*', $buff) {
                $len = $len * 256 + $b;
            }
        } else {
            $n = 0;
        }
        # convert tag ID to ASCII UL notation
        my $ul = UL($tag);
        my $tagInfo = $$tagTablePtr{$ul};
        if (not $tagInfo and $ul =~ /^060e2b34\.0253\.0101\.(0d|0f)/ and
            ($1 eq '0d' or $verbose or $unknown))
        {
            # generate some unknown set tags automatically
            my $name = $1 eq '0d' ? 'UserOrganizationPublicUse' : 'Experimental';
            $tagInfo = { Name => $name, %localSet };
            AddTagToTable($tagTablePtr, $ul, $tagInfo);
        }
        my ($val, $dataPt);
        if ($tagInfo and not $$tagInfo{Unknown} and $len < 10000000) {
            # save information about header/footer positions for skipping over body partitions
            if ($$tagInfo{Name} eq 'Primer' and $mxfInfo{HeaderSize}) {
                # footer position relative to header start and only valid if non-zero
                $footerPos = $start + $mxfInfo{FooterPos} if $mxfInfo{FooterPos};
                # header length is relative to start of Primer
                $headerEnd = $pos + $mxfInfo{HeaderSize};
            } elsif ($$tagInfo{IsHeader}) {
                # save position of header start to allow calculation of footer position
                $start = $pos;
            }
            $raf->Read($buff, $len) == $len or last; # get KLV Value
            $dataPt = \$buff;
            my $type = $$tagInfo{Type};
            $val = ReadMXFValue($et, $buff, $type) if $type and $knownType{$type};
        } elsif (($tagInfo and (not $$tagInfo{Unknown} or $unknown)) or $verbose) {
            if ($tagInfo) {
                # set Binary flag to extract all unknown-format tags as Binary data
                if ($$tagInfo{Unknown} and not defined $$tagInfo{Binary}) {
                    my $type = $$tagInfo{Type};
                    $$tagInfo{Binary} = not ($$tagInfo{Format} or ($type and $knownType{$type}));
                }
            } else {
                my $id = unpack 'H*', $tag;
                $tagInfo = {
                    Name        => "MXF_$id",
                    Description => "MXF $id",
                };
                # note: don't add unknown tags to table because we don't
                # want them to be extracted with the Unknown option
            }
            # read the first 64kB max
            my $n = $len < 65536 ? $len : 65536;
            $raf->Read($val, $n) == $n or last;
            $dataPt = \$val;
            my $more = $len - $n;
            $raf->Seek($more, 1) or last if $more;
        } else {
            $raf->Seek($len, 1) or last;    # skip this value
            next;
        }
        $et->HandleTag($tagTablePtr, $ul, $val,
            TagInfo     => $tagInfo,
            DataPt      => $dataPt,
            DataPos     => $pos + 17 + $n,
            Size        => $len,
            ProcessProc => \&ProcessLocalSet,
        );
    }
    # walk entire MXF object tree to fix family 1 group names
    my ($pathInfo, $tag, %did, %bestDur);
    $pathInfo = { Path => [ 'MXF' ] } if $et->Options('SavePath');
    foreach $preface (@{$mxfInfo{Preface}}) {
        SetGroups(\%mxfInfo, $preface, $pathInfo);
    }
    # convert Duration values to seconds based on the appropriate EditRate
    ConvertDurations($et, \%mxfInfo);

    # remove tags to keep only the one from the most recent instance of the object
    my $tagExtra = $$et{TAG_EXTRA};
    my $fileOrder = $$et{FILE_ORDER};
    # also determine our best Duration value
    if ($mxfInfo{BestDuration}) {
        my $instance = $mxfInfo{BestDuration}{Source} || $mxfInfo{BestDuration}{Other};
        $instance and $bestDur{"Duration $instance"} = 1;
    }
    # process tags in reverse order to preserve the last found of each identical tag
    foreach $tag (sort { $$fileOrder{$b} <=> $$fileOrder{$a} } keys %$tagExtra) {
        my $instance = $$tagExtra{$tag}{UID} or next;
        delete $$tagExtra{$tag}{UID};   # (no longer needed)
        $tag =~ /^(\S+)/;               # get tag name without index number
        my $utag = "$1 $instance";      # instance-specific tag name
        if ($did{$utag}) {
            Image::ExifTool::DeleteTag($et, $tag); # delete the duplicate
        } else {
            $did{$utag} = 1;
            if ($bestDur{$utag}) {
                # save best duration value
                my $val = $$et{VALUE}{$tag};
                $et->HandleTag($tagTablePtr, '060e2b34.0101.0102.07020201.01030000', $val);
            }
        }
    }

    # clean up and return
    delete $$et{SET_GROUP1};
    delete $$et{MXFInfo};
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MXF - Read MXF meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read meta
information from MXF (Material Exchange Format) files.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://sourceforge.net/projects/mxflib/>

=item L<http://www.aafassociation.org/downloads/whitepapers/MXFPhysicalview.pdf>

=item L<http://archive.nlm.nih.gov/pubs/pearson/MJ2_Metadata2005.pdf>

=item L<http://www.aafassociation.org/downloads/specifications/AMWA-AS-03-Delivery-Spec-1_0.pdf>

=item L<http://paul-sampson.ca/private/s385m.pdf>

=item L<http://avwiki.nl/documents/eg41.pdf>

=item L<http://avwiki.nl/documents/eg42.pdf>

=item L<http://www.amwa.tv/downloads/specifications/aafobjectspec-v1.1.pdf>

=item L<http://www.smpte-ra.org/mdd/RP210v12-publication-20100623.xls>

=item L<http://rhea.tele.ucl.ac.be:8081/Plone/Members/egoray/thesaurus-dictionnaire-metadata/>

=item L<http://www.mog-solutions.com/img_upload/PDF/XML%20Schema%20for%20MXF%20Metadata.pdf>

=item L<http://www.freemxf.org/freemxf_board/viewtopic.php?p=545&sid=00a5c17e07d828c1e93ecdbaed3076f7>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MXF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

