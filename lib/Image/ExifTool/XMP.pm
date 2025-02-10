#------------------------------------------------------------------------------
# File:         XMP.pm
#
# Description:  Read XMP meta information
#
# Revisions:    11/25/2003 - P. Harvey Created
#               10/28/2004 - P. Harvey Major overhaul to conform with XMP spec
#               02/27/2005 - P. Harvey Also read UTF-16 and UTF-32 XMP
#               08/30/2005 - P. Harvey Split tag tables into separate namespaces
#               10/24/2005 - P. Harvey Added ability to parse .XMP files
#               08/25/2006 - P. Harvey Added ability to handle blank nodes
#               08/22/2007 - P. Harvey Added ability to handle alternate language tags
#               09/26/2008 - P. Harvey Added Iptc4xmpExt tags (version 1.0 rev 2)
#
# References:   1) http://www.adobe.com/products/xmp/pdfs/xmpspec.pdf
#               2) http://www.w3.org/TR/rdf-syntax-grammar/  (20040210)
#               3) http://www.portfoliofaq.com/pfaq/v7mappings.htm
#               4) http://www.iptc.org/IPTC4XMP/
#               5) http://creativecommons.org/technology/xmp
#                  --> changed to http://wiki.creativecommons.org/Companion_File_metadata_specification (2007/12/21)
#               6) http://www.optimasc.com/products/fileid/xmp-extensions.pdf
#               7) Lou Salkind private communication
#               8) http://partners.adobe.com/public/developer/en/xmp/sdk/XMPspecification.pdf
#               9) http://www.w3.org/TR/SVG11/
#               10) http://www.adobe.com/devnet/xmp/pdfs/XMPSpecificationPart2.pdf (Oct 2008)
#               11) http://www.extensis.com/en/support/kb_article.jsp?articleNumber=6102211
#               12) http://www.cipa.jp/std/documents/e/DC-010-2012_E.pdf
#               13) http://www.cipa.jp/std/documents/e/DC-010-2017_E.pdf (changed to
#                   http://www.cipa.jp/std/documents/e/DC-X010-2017.pdf)
#
# Notes:      - Property qualifiers are handled as if they were separate
#               properties (with no associated namespace).
#
#             - Currently, there is no special treatment of the following
#               properties which could potentially affect the extracted
#               information: xml:base, rdf:parseType (note that parseType
#               Literal isn't allowed by the XMP spec).
#
#             - The family 2 group names will be set to 'Unknown' for any XMP
#               tags not found in the XMP or Exif tag tables.
#------------------------------------------------------------------------------

package Image::ExifTool::XMP;

use strict;
use vars qw($VERSION $AUTOLOAD @ISA @EXPORT_OK %stdXlatNS %nsURI %latConv %longConv
            %dateTimeInfo %xmpTableDefaults %specialStruct %sDimensions %sArea %sColorant);
use Image::ExifTool qw(:Utils);
use Image::ExifTool::Exif;
use Image::ExifTool::GPS;
require Exporter;

$VERSION = '3.71';
@ISA = qw(Exporter);
@EXPORT_OK = qw(EscapeXML UnescapeXML);

sub ProcessXMP($$;$);
sub WriteXMP($$;$);
sub CheckXMP($$$;$);
sub ParseXMPElement($$$;$$$$);
sub DecodeBase64($);
sub EncodeBase64($;$);
sub SaveBlankInfo($$$;$);
sub ProcessBlankInfo($$$;$);
sub ValidateXMP($;$);
sub ValidateProperty($$;$);
sub UnescapeChar($$;$);
sub AddFlattenedTags($;$$);
sub FormatXMPDate($);
sub ConvertRational($);
sub ConvertRationalList($);
sub WriteGSpherical($$$);

# standard path locations for XMP in major file types
my %stdPath = (
    JPEG => 'JPEG-APP1-XMP',
    TIFF => 'TIFF-IFD0-XMP',
    PSD => 'PSD-XMP',
);

# lookup for translating to ExifTool namespaces (and family 1 group names)
%stdXlatNS = (
    # shorten ugly namespace prefixes
    'Iptc4xmpCore' => 'iptcCore',
    'Iptc4xmpExt' => 'iptcExt',
    'photomechanic'=> 'photomech',
    'MicrosoftPhoto' => 'microsoft',
    'prismusagerights' => 'pur',
    'GettyImagesGIFT' => 'getty',
    'hdr_metadata' => 'hdr',
);

# translate ExifTool XMP family 1 group names back to standard XMP namespace prefixes
my %xmpNS = (
    'iptcCore' => 'Iptc4xmpCore',
    'iptcExt' => 'Iptc4xmpExt',
    'photomech'=> 'photomechanic',
    'microsoft' => 'MicrosoftPhoto',
    'getty' => 'GettyImagesGIFT',
    # (prism changed their spec to now use 'pur')
    # 'pur' => 'prismusagerights',
);

# Lookup to translate standard XMP namespace prefixes into URI's.  This list
# need not be complete, but it must contain an entry for each namespace prefix
# (NAMESPACE) for writable tags in the XMP tables or in structures that doesn't
# define a URI.  Also, the namespace must be defined here for non-standard
# namespace prefixes to be recognized.
%nsURI = (
    aux       => 'http://ns.adobe.com/exif/1.0/aux/',
    album     => 'http://ns.adobe.com/album/1.0/',
    cc        => 'http://creativecommons.org/ns#', # changed 2007/12/21 - PH
    crd       => 'http://ns.adobe.com/camera-raw-defaults/1.0/',
    crs       => 'http://ns.adobe.com/camera-raw-settings/1.0/',
    crss      => 'http://ns.adobe.com/camera-raw-saved-settings/1.0/',
    dc        => 'http://purl.org/dc/elements/1.1/',
    exif      => 'http://ns.adobe.com/exif/1.0/',
    exifEX    => 'http://cipa.jp/exif/1.0/',
    iX        => 'http://ns.adobe.com/iX/1.0/',
    pdf       => 'http://ns.adobe.com/pdf/1.3/',
    pdfx      => 'http://ns.adobe.com/pdfx/1.3/',
    photoshop => 'http://ns.adobe.com/photoshop/1.0/',
    rdf       => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
    rdfs      => 'http://www.w3.org/2000/01/rdf-schema#',
    stDim     => 'http://ns.adobe.com/xap/1.0/sType/Dimensions#',
    stEvt     => 'http://ns.adobe.com/xap/1.0/sType/ResourceEvent#',
    stFnt     => 'http://ns.adobe.com/xap/1.0/sType/Font#',
    stJob     => 'http://ns.adobe.com/xap/1.0/sType/Job#',
    stRef     => 'http://ns.adobe.com/xap/1.0/sType/ResourceRef#',
    stVer     => 'http://ns.adobe.com/xap/1.0/sType/Version#',
    stMfs     => 'http://ns.adobe.com/xap/1.0/sType/ManifestItem#',
    stCamera  => 'http://ns.adobe.com/photoshop/1.0/camera-profile',
    crlcp     => 'http://ns.adobe.com/camera-raw-embedded-lens-profile/1.0/',
    tiff      => 'http://ns.adobe.com/tiff/1.0/',
   'x'        => 'adobe:ns:meta/',
    xmpG      => 'http://ns.adobe.com/xap/1.0/g/',
    xmpGImg   => 'http://ns.adobe.com/xap/1.0/g/img/',
    xmp       => 'http://ns.adobe.com/xap/1.0/',
    xmpBJ     => 'http://ns.adobe.com/xap/1.0/bj/',
    xmpDM     => 'http://ns.adobe.com/xmp/1.0/DynamicMedia/',
    xmpMM     => 'http://ns.adobe.com/xap/1.0/mm/',
    xmpRights => 'http://ns.adobe.com/xap/1.0/rights/',
    xmpNote   => 'http://ns.adobe.com/xmp/note/',
    xmpTPg    => 'http://ns.adobe.com/xap/1.0/t/pg/',
    xmpidq    => 'http://ns.adobe.com/xmp/Identifier/qual/1.0/',
    xmpPLUS   => 'http://ns.adobe.com/xap/1.0/PLUS/',
    panorama  => 'http://ns.adobe.com/photoshop/1.0/panorama-profile',
    dex       => 'http://ns.optimasc.com/dex/1.0/',
    mediapro  => 'http://ns.iview-multimedia.com/mediapro/1.0/',
    expressionmedia => 'http://ns.microsoft.com/expressionmedia/1.0/',
    Iptc4xmpCore => 'http://iptc.org/std/Iptc4xmpCore/1.0/xmlns/',
    Iptc4xmpExt => 'http://iptc.org/std/Iptc4xmpExt/2008-02-29/',
    MicrosoftPhoto => 'http://ns.microsoft.com/photo/1.0',
    MP1       => 'http://ns.microsoft.com/photo/1.1', #PH (MP1 is fabricated)
    MP        => 'http://ns.microsoft.com/photo/1.2/',
    MPRI      => 'http://ns.microsoft.com/photo/1.2/t/RegionInfo#',
    MPReg     => 'http://ns.microsoft.com/photo/1.2/t/Region#',
    lr        => 'http://ns.adobe.com/lightroom/1.0/',
    DICOM     => 'http://ns.adobe.com/DICOM/',
   'drone-dji'=> 'http://www.dji.com/drone-dji/1.0/',
    svg       => 'http://www.w3.org/2000/svg',
    et        => 'http://ns.exiftool.org/1.0/',
#
# namespaces defined in XMP2.pl:
#
    plus      => 'http://ns.useplus.org/ldf/xmp/1.0/',
    # (prism recommendations from http://www.prismstandard.org/specifications/3.0/Image_Guide_3.0.htm)
    prism     => 'http://prismstandard.org/namespaces/basic/2.0/',
    prl       => 'http://prismstandard.org/namespaces/prl/2.1/',
    pur       => 'http://prismstandard.org/namespaces/prismusagerights/2.1/',
    pmi       => 'http://prismstandard.org/namespaces/pmi/2.2/',
    prm       => 'http://prismstandard.org/namespaces/prm/3.0/',
    acdsee    => 'http://ns.acdsee.com/iptc/1.0/',
   'acdsee-rs'=> 'http://ns.acdsee.com/regions/',
    digiKam   => 'http://www.digikam.org/ns/1.0/',
    swf       => 'http://ns.adobe.com/swf/1.0/',
    cell      => 'http://developer.sonyericsson.com/cell/1.0/',
    aas       => 'http://ns.apple.com/adjustment-settings/1.0/',
   'mwg-rs'   => 'http://www.metadataworkinggroup.com/schemas/regions/',
   'mwg-kw'   => 'http://www.metadataworkinggroup.com/schemas/keywords/',
   'mwg-coll' => 'http://www.metadataworkinggroup.com/schemas/collections/',
    stArea    => 'http://ns.adobe.com/xmp/sType/Area#',
    extensis  => 'http://ns.extensis.com/extensis/1.0/',
    ics       => 'http://ns.idimager.com/ics/1.0/',
    fpv       => 'http://ns.fastpictureviewer.com/fpv/1.0/',
    creatorAtom=>'http://ns.adobe.com/creatorAtom/1.0/',
   'apple-fi' => 'http://ns.apple.com/faceinfo/1.0/',
    GAudio    => 'http://ns.google.com/photos/1.0/audio/',
    GImage    => 'http://ns.google.com/photos/1.0/image/',
    GPano     => 'http://ns.google.com/photos/1.0/panorama/',
    GSpherical=> 'http://ns.google.com/videos/1.0/spherical/',
    GDepth    => 'http://ns.google.com/photos/1.0/depthmap/',
    GFocus    => 'http://ns.google.com/photos/1.0/focus/',
    GCamera   => 'http://ns.google.com/photos/1.0/camera/',
    GCreations=> 'http://ns.google.com/photos/1.0/creations/',
    dwc       => 'http://rs.tdwg.org/dwc/index.htm',
    GettyImagesGIFT => 'http://xmp.gettyimages.com/gift/1.0/',
    LImage    => 'http://ns.leiainc.com/photos/1.0/image/',
    Profile   => 'http://ns.google.com/photos/dd/1.0/profile/',
    sdc       => 'http://ns.nikon.com/sdc/1.0/',
    ast       => 'http://ns.nikon.com/asteroid/1.0/',
    nine      => 'http://ns.nikon.com/nine/1.0/',
    hdr_metadata => 'http://ns.adobe.com/hdr-metadata/1.0/',
    hdrgm     => 'http://ns.adobe.com/hdr-gain-map/1.0/',
    xmpDSA    => 'http://leica-camera.com/digital-shift-assistant/1.0/',
    seal      => 'http://ns.seal/2024/1.0/',
    # Note: Google uses a prefix of 'Container', but this conflicts with the
    # Device Container namespace, also by Google.  So call this one GContainer
    GContainer=> 'http://ns.google.com/photos/1.0/container/',
    HDRGainMap=> 'http://ns.apple.com/HDRGainMap/1.0/',
    apdi      => 'http://ns.apple.com/pixeldatainfo/1.0/',
);

# build reverse namespace lookup
my %uri2ns = ( 'http://ns.exiftool.ca/1.0/' => 'et' ); # (allow exiftool.ca as well as exiftool.org)
{
    my $ns;
    foreach $ns (keys %nsURI) {
        $uri2ns{$nsURI{$ns}} = $ns;
    }
}

# conversions for GPS coordinates
%latConv = (
    ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
    ValueConvInv => 'Image::ExifTool::GPS::ToDMS($self, $val, 2, "N")',
    PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1, "lat")',
);
%longConv = (
    ValueConv    => 'Image::ExifTool::GPS::ToDegrees($val, 1)',
    ValueConvInv => 'Image::ExifTool::GPS::ToDMS($self, $val, 2, "E")',
    PrintConv    => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    PrintConvInv => 'Image::ExifTool::GPS::ToDegrees($val, 1, "lon")',
);
%dateTimeInfo = (
    # NOTE: Do NOT put "Groups" here because Groups hash must not be common!
    Writable => 'date',
    Shift => 'Time',
    Validate => 'ValidateXMPDate($val)',
    PrintConv => '$self->ConvertDateTime($val)',
    PrintConvInv => '$self->InverseDateTime($val,undef,1)',
);

# this conversion allows alternate language support for designated boolean tags
my %boolConv = (
    PrintConv => {
        OTHER => sub { # (inverse conversion is the same)
            my $val = shift;
            return 'False' if lc $val eq 'false';
            return 'True' if lc $val eq 'true';
            return $val;
        },
        True => 'True',
        False => 'False',
    },
);

# XMP namespaces which we don't want to contribute to generated EXIF tag names
# (Note: namespaces with non-standard prefixes aren't currently ignored)
my %ignoreNamespace = ( 'x'=>1, rdf=>1, xmlns=>1, xml=>1, svg=>1, office=>1 );

# ExifTool properties that don't generate tag names (et:tagid is historic)
my %ignoreEtProp = ( 'et:desc'=>1, 'et:prt'=>1, 'et:val'=>1 , 'et:id'=>1, 'et:tagid'=>1,
                     'et:toolkit'=>1, 'et:table'=>1, 'et:index'=>1 );

# XMP properties to ignore (set dynamically via dirInfo IgnoreProp)
my %ignoreProp;

# these are the attributes that we handle for properties that contain
# sub-properties.  Attributes for simple properties are easy, and we
# just copy them over.  These are harder since we don't store attributes
# for properties without simple values.  (maybe this will change...)
# (special attributes are indicated by a list reference of tag information)
my %recognizedAttrs = (
    'rdf:about' => [ 'Image::ExifTool::XMP::rdf', 'about', 'About' ],
    'x:xmptk'   => [ 'Image::ExifTool::XMP::x',   'xmptk', 'XMPToolkit' ],
    'x:xaptk'   => [ 'Image::ExifTool::XMP::x',   'xmptk', 'XMPToolkit' ],
    'rdf:parseType' => 1,
    'rdf:nodeID' => 1,
    'et:toolkit' => 1,
    'rdf:xmlns'  => 1, # this is presumably the default namespace, which we currently ignore
    'lastUpdate' => [ 'Image::ExifTool::XMP::XML', 'lastUpdate', 'LastUpdate' ], # found in XML from Sony ILCE-7S MP4
);

# special tags in structures below
# NOTE: this lookup is duplicated in TagLookup.pm!!
%specialStruct = (
    STRUCT_NAME => 1, # [optional] name of structure
    NAMESPACE   => 1, # [mandatory for XMP] namespace prefix used for fields of this structure
    NOTES       => 1, # [optional] notes for documentation about this structure
    TYPE        => 1, # [optional] rdf:type resource for struct (if used, the StructType flag
                      # will be set automatically for all derived flattened tags when writing)
    GROUPS      => 1, # [optional] specifies family group 2 name for the structure
    SORT_ORDER  => 1, # [optional] order for sorting fields in documentation
);
# XMP structures (each structure is similar to a tag table so we can
# recurse through them in SetPropertyPath() as if they were tag tables)
# The main differences between structure field information and tagInfo hashes are:
#   1) Field information hashes do not contain Name, Groups or Table entries, and
#   2) The TagID entry is optional, and is used only if the key in the structure hash
#      is different from the TagID (currently only true for alternate language fields)
#   3) Field information hashes support a additional "Namespace" property.
my %sResourceRef = (
    STRUCT_NAME => 'ResourceRef',
    NAMESPACE   => 'stRef',
    documentID      => { },
    instanceID      => { },
    manager         => { },
    managerVariant  => { },
    manageTo        => { },
    manageUI        => { },
    renditionClass  => { },
    renditionParams => { },
    versionID       => { },
    # added Oct 2008
    alternatePaths  => { List => 'Seq' },
    filePath        => { },
    fromPart        => { },
    lastModifyDate  => { %dateTimeInfo, Groups => { 2 => 'Time' } },
    maskMarkers     => { PrintConv => { All => 'All', None => 'None' } },
    partMapping     => { },
    toPart          => { },
    # added May 2010
    originalDocumentID => { }, # (undocumented property written by Adobe InDesign)
    # added Aug 2016 (INDD again)
    lastURL         => { },
    linkForm        => { },
    linkCategory    => { },
    placedXResolution    => { },
    placedYResolution    => { },
    placedResolutionUnit => { },
);
my %sResourceEvent = (
    STRUCT_NAME => 'ResourceEvent',
    NAMESPACE   => 'stEvt',
    action          => { },
    instanceID      => { },
    parameters      => { },
    softwareAgent   => { },
    when            => { %dateTimeInfo, Groups => { 2 => 'Time' } },
    # added Oct 2008
    changed         => { },
);
my %sJobRef = (
    STRUCT_NAME => 'JobRef',
    NAMESPACE   => 'stJob',
    id          => { },
    name        => { },
    url         => { },
);
my %sVersion = (
    STRUCT_NAME => 'Version',
    NAMESPACE   => 'stVer',
    comments    => { },
    event       => { Struct => \%sResourceEvent },
    modifier    => { },
    modifyDate  => { %dateTimeInfo, Groups => { 2 => 'Time' } },
    version     => { },
);
my %sThumbnail = (
    STRUCT_NAME => 'Thumbnail',
    NAMESPACE   => 'xmpGImg',
    height      => { Writable => 'integer' },
    width       => { Writable => 'integer' },
   'format'     => { },
    image       => {
        Avoid => 1,
        Groups => { 2 => 'Preview' },
        ValueConv => 'Image::ExifTool::XMP::DecodeBase64($val)',
        ValueConvInv => 'Image::ExifTool::XMP::EncodeBase64($val)',
    },
);
my %sPageInfo = (
    STRUCT_NAME => 'PageInfo',
    NAMESPACE   => 'xmpGImg',
    PageNumber  => { Writable => 'integer', Namespace => 'xmpTPg' }, # override default namespace
    height      => { Writable => 'integer' },
    width       => { Writable => 'integer' },
   'format'     => { },
    image       => {
        Groups => { 2 => 'Preview' },
        ValueConv => 'Image::ExifTool::XMP::DecodeBase64($val)',
        ValueConvInv => 'Image::ExifTool::XMP::EncodeBase64($val)',
    },
);
#my %sIdentifierScheme = (
#    NAMESPACE   => 'xmpidq',
#    Scheme      => { }, # qualifier for xmp:Identifier only
#);
%sDimensions = (
    STRUCT_NAME => 'Dimensions',
    NAMESPACE   => 'stDim',
    w           => { Writable => 'real' },
    h           => { Writable => 'real' },
    unit        => { },
);
%sArea = (
    STRUCT_NAME => 'Area',
    NAMESPACE   => 'stArea',
   'x'          => { Writable => 'real' },
   'y'          => { Writable => 'real' },
    w           => { Writable => 'real' },
    h           => { Writable => 'real' },
    d           => { Writable => 'real' },
    unit        => { },
);
%sColorant = (
    STRUCT_NAME => 'Colorant',
    NAMESPACE   => 'xmpG',
    swatchName  => { },
    mode        => { PrintConv => { CMYK=>'CMYK', RGB=>'RGB', LAB=>'Lab' } },
    # note: do not implement closed choice for "type" because Adobe can't
    # get the case right:  spec. says "PROCESS" but Indesign writes "Process"
    type        => { },
    cyan        => { Writable => 'real' },
    magenta     => { Writable => 'real' },
    yellow      => { Writable => 'real' },
    black       => { Writable => 'real' },
    red         => { Writable => 'integer' },
    green       => { Writable => 'integer' },
    blue        => { Writable => 'integer' },
    gray        => { Writable => 'integer' },
    L           => { Writable => 'real' },
    A           => { Writable => 'integer' },
    B           => { Writable => 'integer' },
    # 'tint' observed in INDD sample - PH
    tint        => { Writable => 'integer', Notes => 'not part of 2010 XMP specification' },
);
my %sSwatchGroup = (
    STRUCT_NAME => 'SwatchGroup',
    NAMESPACE   => 'xmpG',
    groupName   => { },
    groupType   => { Writable => 'integer' },
    Colorants => {
        FlatName => 'SwatchColorant',
        Struct => \%sColorant,
        List => 'Seq',
    },
);
my %sFont = (
    STRUCT_NAME => 'Font',
    NAMESPACE   => 'stFnt',
    fontName    => { },
    fontFamily  => { },
    fontFace    => { },
    fontType    => { },
    versionString => { },
    composite   => { Writable => 'boolean' },
    fontFileName=> { },
    childFontFiles => { List => 'Seq' },
);
my %sOECF = (
    STRUCT_NAME => 'OECF',
    NAMESPACE   => 'exif',
    Columns     => { Writable => 'integer' },
    Rows        => { Writable => 'integer' },
    Names       => { List => 'Seq' },
    Values      => { List => 'Seq', Writable => 'rational' },
);
my %sAreaModels = (
    STRUCT_NAME => 'AreaModels',
    NAMESPACE   => 'crs',
    ColorRangeMaskAreaSampleInfo => { FlatName => 'ColorSampleInfo' },
    AreaComponents => { FlatName => 'Components', List => 'Seq' },
);
my %sCorrRangeMask = (
    STRUCT_NAME => 'CorrRangeMask',
    NAMESPACE   => 'crs',
    NOTES => 'Called CorrectionRangeMask by the spec.',
    Version     => { },
    Type        => { },
    ColorAmount => { Writable => 'real' },
    LumMin      => { Writable => 'real' },
    LumMax      => { Writable => 'real' },
    LumFeather  => { Writable => 'real' },
    DepthMin    => { Writable => 'real' },
    DepthMax    => { Writable => 'real' },
    DepthFeather=> { Writable => 'real' },
    # new in LR 11.0
    Invert      => { Writable => 'boolean' },
    SampleType  => { Writable => 'integer' },
    AreaModels  => {
        List => 'Seq',
        Struct => \%sAreaModels,
    },
    LumRange    => { },
    LuminanceDepthSampleInfo => { },
);
# new LR2 crs structures (PH)
my %sCorrectionMask; # (must define this before assigning because it is self-referential)
%sCorrectionMask = (
    STRUCT_NAME => 'CorrectionMask',
    NAMESPACE   => 'crs',
    # disable List behaviour of flattened Gradient/PaintBasedCorrections
    # because these are nested in lists and the flattened tags can't
    # do justice to this complex structure
    What         => { List => 0 },
    MaskValue    => { Writable => 'real', List => 0, FlatName => 'Value' },
    Radius       => { Writable => 'real', List => 0 },
    Flow         => { Writable => 'real', List => 0 },
    CenterWeight => { Writable => 'real', List => 0 },
    Dabs         => { List => 'Seq' },
    ZeroX        => { Writable => 'real', List => 0 },
    ZeroY        => { Writable => 'real', List => 0 },
    FullX        => { Writable => 'real', List => 0 },
    FullY        => { Writable => 'real', List => 0 },
    # new elements used in CircularGradientBasedCorrections CorrectionMasks
    # and RetouchAreas Masks
    Top          => { Writable => 'real', List => 0 },
    Left         => { Writable => 'real', List => 0 },
    Bottom       => { Writable => 'real', List => 0 },
    Right        => { Writable => 'real', List => 0 },
    Angle        => { Writable => 'real', List => 0 },
    Midpoint     => { Writable => 'real', List => 0 },
    Roundness    => { Writable => 'real', List => 0 },
    Feather      => { Writable => 'real', List => 0 },
    Flipped      => { Writable => 'boolean', List => 0 },
    Version      => { Writable => 'integer', List => 0 },
    SizeX        => { Writable => 'real', List => 0 },
    SizeY        => { Writable => 'real', List => 0 },
    X            => { Writable => 'real', List => 0 },
    Y            => { Writable => 'real', List => 0 },
    Alpha        => { Writable => 'real', List => 0 },
    CenterValue  => { Writable => 'real', List => 0 },
    PerimeterValue=>{ Writable => 'real', List => 0 },
    # new in LR 11.0 MaskGroupBasedCorrections
    MaskActive   => { Writable => 'boolean', List => 0 },
    MaskName     => { List => 0 },
    MaskBlendMode=> { Writable => 'integer', List => 0 },
    MaskInverted => { Writable => 'boolean', List => 0 },
    MaskSyncID   => { List => 0 },
    MaskVersion  => { List => 0 },
    MaskSubType  => { List => 0 },
    ReferencePoint => { List => 0  },
    InputDigest  => { List => 0 },
    MaskDigest   => { List => 0 },
    WholeImageArea => { List => 0 },
    Origin       => { List => 0 },
    Masks        => { Struct => \%sCorrectionMask, NoSubStruct => 1 },
    CorrectionRangeMask => {
        Name => 'CorrRangeMask',
        Notes => 'called CorrectionRangeMask by the spec',
        FlatName => 'Range',
        Struct => \%sCorrRangeMask,
    },
);
my %sCorrection = (
    STRUCT_NAME => 'Correction',
    NAMESPACE   => 'crs',
    What => { List => 0 },
    CorrectionAmount => { FlatName => 'Amount',     Writable => 'real', List => 0 },
    CorrectionActive => { FlatName => 'Active',     Writable => 'boolean', List => 0 },
    LocalExposure    => { FlatName => 'Exposure',   Writable => 'real', List => 0 },
    LocalSaturation  => { FlatName => 'Saturation', Writable => 'real', List => 0 },
    LocalContrast    => { FlatName => 'Contrast',   Writable => 'real', List => 0 },
    LocalClarity     => { FlatName => 'Clarity',    Writable => 'real', List => 0 },
    LocalSharpness   => { FlatName => 'Sharpness',  Writable => 'real', List => 0 },
    LocalBrightness  => { FlatName => 'Brightness', Writable => 'real', List => 0 },
    LocalToningHue   => { FlatName => 'ToningHue',  Writable => 'real', List => 0 },
    LocalToningSaturation => { FlatName => 'ToningSaturation',  Writable => 'real', List => 0 },
    LocalExposure2012     => { FlatName => 'Exposure2012',      Writable => 'real', List => 0 },
    LocalContrast2012     => { FlatName => 'Contrast2012',      Writable => 'real', List => 0 },
    LocalHighlights2012   => { FlatName => 'Highlights2012',    Writable => 'real', List => 0 },
    LocalShadows2012      => { FlatName => 'Shadows2012',       Writable => 'real', List => 0 },
    LocalClarity2012      => { FlatName => 'Clarity2012',       Writable => 'real', List => 0 },
    LocalLuminanceNoise   => { FlatName => 'LuminanceNoise',    Writable => 'real', List => 0 },
    LocalMoire       => { FlatName => 'Moire',      Writable => 'real', List => 0 },
    LocalDefringe    => { FlatName => 'Defringe',   Writable => 'real', List => 0 },
    LocalTemperature => { FlatName => 'Temperature',Writable => 'real', List => 0 },
    LocalTint        => { FlatName => 'Tint',       Writable => 'real', List => 0 },
    LocalHue         => { FlatName => 'Hue',        Writable => 'real', List => 0 },
    LocalWhites2012  => { FlatName => 'Whites2012', Writable => 'real', List => 0 },
    LocalBlacks2012  => { FlatName => 'Blacks2012', Writable => 'real', List => 0 },
    LocalDehaze      => { FlatName => 'Dehaze', Writable => 'real', List => 0 },
    LocalTexture     => { FlatName => 'Texture', Writable => 'real', List => 0 },
    # new in LR 11.0
    CorrectionRangeMask => {
        Name => 'CorrRangeMask',
        Notes => 'called CorrectionRangeMask by the spec',
        FlatName => 'RangeMask',
        Struct => \%sCorrRangeMask,
    },
    CorrectionMasks  => {
        FlatName => 'Mask',
        Struct => \%sCorrectionMask,
        List => 'Seq',
    },
    CorrectionName => { },
    CorrectionSyncID => { },
);
my %sRetouchArea = (
    STRUCT_NAME => 'RetouchArea',
    NAMESPACE   => 'crs',
    SpotType        => { List => 0 },
    SourceState     => { List => 0 },
    Method          => { List => 0 },
    SourceX         => { Writable => 'real',    List => 0 },
    OffsetY         => { Writable => 'real',    List => 0 },
    Opacity         => { Writable => 'real',    List => 0 },
    Feather         => { Writable => 'real',    List => 0 },
    Seed            => { Writable => 'integer', List => 0 },
    Masks => {
        FlatName => 'Mask',
        Struct => \%sCorrectionMask,
        List => 'Seq',
    },
);
my %sMapInfo = (
    STRUCT_NAME => 'MapInfo',
    NAMESPACE   => 'crs',
    NOTES => q{
        Called RangeMaskMapInfo by the specification, the same as the containing
        structure.
    },
    RGBMin => { },
    RGBMax => { },
    LabMin => { },
    LabMax => { },
    LumEq  => { List => 'Seq' },
);
my %sRangeMask = (
    STRUCT_NAME => 'RangeMask',
    NAMESPACE   => 'crs',
    NOTES => q{
        This structure is actually called RangeMaskMapInfo, but it only contains one
        element which is a RangeMaskMapInfo structure (Yes, really!).  So these are
        renamed to RangeMask and MapInfo respectively to avoid confusion and
        redundancy in the tag names.
    },
    RangeMaskMapInfo => { FlatName => 'MapInfo', Struct => \%sMapInfo },
);

# main XMP tag table (tag ID's are used for the family 1 group names)
%Image::ExifTool::XMP::Main = (
    GROUPS => { 2 => 'Unknown' },
    PROCESS_PROC => \&ProcessXMP,
    WRITE_PROC => \&WriteXMP,
    dc => {
        Name => 'dc', # (otherwise generated name would be 'Dc')
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::dc' },
    },
    xmp => {
        Name => 'xmp',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmp' },
    },
    xmpDM => {
        Name => 'xmpDM',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpDM' },
    },
    xmpRights => {
        Name => 'xmpRights',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpRights' },
    },
    xmpNote => {
        Name => 'xmpNote',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpNote' },
    },
    xmpMM => {
        Name => 'xmpMM',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpMM' },
    },
    xmpBJ => {
        Name => 'xmpBJ',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpBJ' },
    },
    xmpTPg => {
        Name => 'xmpTPg',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpTPg' },
    },
    pdf => {
        Name => 'pdf',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::pdf' },
    },
    pdfx => {
        Name => 'pdfx',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::pdfx' },
    },
    photoshop => {
        Name => 'photoshop',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::photoshop' },
    },
    crd => {
        Name => 'crd',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::crd' },
    },
    crs => {
        Name => 'crs',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::crs' },
    },
    # crss - it would be tedious to add the ability to write this
    aux => {
        Name => 'aux',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::aux' },
    },
    tiff => {
        Name => 'tiff',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::tiff' },
    },
    exif => {
        Name => 'exif',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::exif' },
    },
    exifEX => {
        Name => 'exifEX',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::exifEX' },
    },
    iptcCore => {
        Name => 'iptcCore',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::iptcCore' },
    },
    iptcExt => {
        Name => 'iptcExt',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::iptcExt' },
    },
    PixelLive => {
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::PixelLive' },
    },
    xmpPLUS => {
        Name => 'xmpPLUS',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::xmpPLUS' },
    },
    panorama => {
        Name => 'panorama',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::panorama' },
    },
    plus => {
        Name => 'plus',
        SubDirectory => { TagTable => 'Image::ExifTool::PLUS::XMP' },
    },
    cc => {
        Name => 'cc',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::cc' },
    },
    dex => {
        Name => 'dex',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::dex' },
    },
    photomech => {
        Name => 'photomech',
        SubDirectory => { TagTable => 'Image::ExifTool::PhotoMechanic::XMP' },
    },
    mediapro => {
        Name => 'mediapro',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::MediaPro' },
    },
    expressionmedia => {
        Name => 'expressionmedia',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::ExpressionMedia' },
    },
    microsoft => {
        Name => 'microsoft',
        SubDirectory => { TagTable => 'Image::ExifTool::Microsoft::XMP' },
    },
    MP => {
        Name => 'MP',
        SubDirectory => { TagTable => 'Image::ExifTool::Microsoft::MP' },
    },
    MP1 => {
        Name => 'MP1',
        SubDirectory => { TagTable => 'Image::ExifTool::Microsoft::MP1' },
    },
    lr => {
        Name => 'lr',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Lightroom' },
    },
    DICOM => {
        Name => 'DICOM',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::DICOM' },
    },
    album => {
        Name => 'album',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Album' },
    },
    et => {
        Name => 'et',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::ExifTool' },
    },
    prism => {
        Name => 'prism',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::prism' },
    },
    prl => {
        Name => 'prl',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::prl' },
    },
    pur => {
        Name => 'pur',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::pur' },
    },
    pmi => {
        Name => 'pmi',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::pmi' },
    },
    prm => {
        Name => 'prm',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::prm' },
    },
    rdf => {
        Name => 'rdf',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::rdf' },
    },
   'x' => {
        Name => 'x',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::x' },
    },
    acdsee => {
        Name => 'acdsee',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::acdsee' },
    },
   'acdsee-rs' => {
        Name => 'acdsee-rs',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::ACDSeeRegions' },
    },
    digiKam => {
        Name => 'digiKam',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::digiKam' },
    },
    swf => {
        Name => 'swf',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::swf' },
    },
    cell => {
        Name => 'cell',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::cell' },
    },
    aas => {
        Name => 'aas',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::aas' },
    },
   'mwg-rs' => {
        Name => 'mwg-rs',
        SubDirectory => { TagTable => 'Image::ExifTool::MWG::Regions' },
    },
   'mwg-kw' => {
        Name => 'mwg-kw',
        SubDirectory => { TagTable => 'Image::ExifTool::MWG::Keywords' },
    },
   'mwg-coll' => {
        Name => 'mwg-coll',
        SubDirectory => { TagTable => 'Image::ExifTool::MWG::Collections' },
    },
    extensis => {
        Name => 'extensis',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::extensis' },
    },
    ics => {
        Name => 'ics',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::ics' },
    },
    fpv => {
        Name => 'fpv',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::fpv' },
    },
    creatorAtom => {
        Name => 'creatorAtom',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::creatorAtom' },
    },
   'apple-fi' => {
        Name => 'apple-fi',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::apple_fi' },
    },
    GAudio => {
        Name => 'GAudio',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::GAudio' },
    },
    GImage => {
        Name => 'GImage',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::GImage' },
    },
    GPano => {
        Name => 'GPano',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::GPano' },
    },
    GSpherical => {
        Name => 'GSpherical',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::GSpherical' },
    },
    GDepth => {
        Name => 'GDepth',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::GDepth' },
    },
    GFocus => {
        Name => 'GFocus',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::GFocus' },
    },
    GCamera => {
        Name => 'GCamera',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::GCamera' },
    },
    GCreations => {
        Name => 'GCreations',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::GCreations' },
    },
    dwc => {
        Name => 'dwc',
        SubDirectory => { TagTable => 'Image::ExifTool::DarwinCore::Main' },
    },
    getty => {
        Name => 'getty',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::GettyImages' },
    },
   'drone-dji' => {
        Name => 'drone-dji',
        SubDirectory => { TagTable => 'Image::ExifTool::DJI::XMP' },
    },
    LImage => {
        Name => 'LImage',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::LImage' },
    },
    Device => {
        Name => 'Device',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::Device' },
    },
    sdc => {
        Name => 'sdc',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::sdc' },
    },
    ast => {
        Name => 'ast',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::ast' },
    },
    nine => {
        Name => 'nine',
        SubDirectory => { TagTable => 'Image::ExifTool::Nikon::nine' },
    },
    hdr => {
        Name => 'hdr',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::hdr' },
    },
    hdrgm => {
        Name => 'hdrgm',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::hdrgm' },
    },
    xmpDSA => {
        Name => 'xmpDSA',
        SubDirectory => { TagTable => 'Image::ExifTool::Panasonic::DSA' },
    },
    HDRGainMap => {
        Name => 'HDRGainMap',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::HDRGainMap' },
    },
    apdi => {
        Name => 'apdi',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::apdi' },
    },
    seal => {
        Name => 'seal',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::seal' },
    },
    GContainer => {
        Name => 'GContainer',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::GContainer' },
    },
);

# hack to allow XML containing Dublin Core metadata to be handled like XMP (eg. EPUB - see ZIP.pm)
%Image::ExifTool::XMP::XML = (
    GROUPS => { 0 => 'XML', 1 => 'XML', 2 => 'Unknown' },
    PROCESS_PROC => \&ProcessXMP,
    dc => {
        Name => 'dc',
        SubDirectory => { TagTable => 'Image::ExifTool::XMP::dc' },
    },
    lastUpdate => {
        Groups => { 2 => 'Time' },
        ValueConv => 'Image::ExifTool::XMP::ConvertXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
    },
);

#
# Tag tables for all XMP namespaces:
#
# Writable - only need to define this for writable tags if not plain text
#            (boolean, integer, rational, real, date or lang-alt)
# List - XMP list type (Bag, Seq or Alt, or set to 1 for elements in Struct lists --
#        this is necessary to obtain proper list behaviour when reading/writing)
#
# (Note that family 1 group names are generated from the property namespace, not
#  the group1 names below which exist so the groups will appear in the list.)
#
%xmpTableDefaults = (
    WRITE_PROC => \&WriteXMP,
    CHECK_PROC => \&CheckXMP,
    WRITABLE => 'string',
    LANG_INFO => \&GetLangInfo,
);

# rdf attributes extracted
%Image::ExifTool::XMP::rdf = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-rdf', 2 => 'Document' },
    NAMESPACE   => 'rdf',
    NOTES => q{
        Most RDF attributes are handled internally, but the "about" attribute is
        treated specially to allow it to be set to a specific value if required.
    },
    about => { Protected => 1 },
);

# x attributes extracted
%Image::ExifTool::XMP::x = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-x', 2 => 'Document' },
    NAMESPACE   => 'x',
    NOTES => qq{
        The "x" namespace is used for the "xmpmeta" wrapper, and may contain an
        "xmptk" attribute that is extracted as the XMPToolkit tag.  When writing,
        the XMPToolkit tag is generated automatically by ExifTool unless
        specifically set to another value.
    },
    xmptk => { Name => 'XMPToolkit', Protected => 1 },
);

# Dublin Core namespace properties (dc)
%Image::ExifTool::XMP::dc = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-dc', 2 => 'Other' },
    NAMESPACE   => 'dc',
    TABLE_DESC => 'XMP Dublin Core',
    NOTES => 'Dublin Core namespace tags.',
    contributor => { Groups => { 2 => 'Author' }, List => 'Bag' },
    coverage    => { },
    creator     => { Groups => { 2 => 'Author' }, List => 'Seq' },
    date        => { Groups => { 2 => 'Time' },   List => 'Seq', %dateTimeInfo },
    description => { Groups => { 2 => 'Image'  }, Writable => 'lang-alt' },
   'format'     => { Groups => { 2 => 'Image'  } },
    identifier  => { Groups => { 2 => 'Image'  } },
    language    => { List => 'Bag' },
    publisher   => { Groups => { 2 => 'Author' }, List => 'Bag' },
    relation    => { List => 'Bag' },
    rights      => { Groups => { 2 => 'Author' }, Writable => 'lang-alt' },
    source      => { Groups => { 2 => 'Author' }, Avoid => 1 },
    subject     => { Groups => { 2 => 'Image'  }, List => 'Bag' },
    title       => { Groups => { 2 => 'Image'  }, Writable => 'lang-alt' },
    type        => { Groups => { 2 => 'Image'  }, List => 'Bag' },
);

# XMP namespace properties (xmp, xap)
%Image::ExifTool::XMP::xmp = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-xmp', 2 => 'Image' },
    NAMESPACE   => 'xmp',
    NOTES => q{
        XMP namespace tags.  If the older "xap", "xapBJ", "xapMM" or "xapRights"
        namespace prefixes are found, they are translated to the newer "xmp",
        "xmpBJ", "xmpMM" and "xmpRights" prefixes for use in family 1 group names.
    },
    Advisory    => { List => 'Bag', Notes => 'deprecated' },
    BaseURL     => { },
    # (date/time tags not as reliable as EXIF)
    CreateDate  => { Groups => { 2 => 'Time' }, %dateTimeInfo, Priority => 0 },
    CreatorTool => { },
    Identifier  => { Avoid => 1, List => 'Bag' },
    Label       => { },
    MetadataDate=> { Groups => { 2 => 'Time' }, %dateTimeInfo },
    ModifyDate  => { Groups => { 2 => 'Time' }, %dateTimeInfo, Priority => 0 },
    Nickname    => { },
    Rating      => { Writable => 'real', Notes => 'a value from 0 to 5, or -1 for "rejected"' },
    RatingPercent=>{ Writable => 'real', Avoid => 1, Notes => 'non-standard' },
    Thumbnails  => {
        FlatName => 'Thumbnail',
        Struct => \%sThumbnail,
        List => 'Alt',
    },
    # the following written by Adobe InDesign, not part of XMP spec:
    PageInfo        => {
        FlatName => 'PageImage',
        Struct => \%sPageInfo,
        List => 'Seq',
    },
    PageInfoImage => { Name => 'PageImage', Flat => 1 },
    Title       => { Avoid => 1, Notes => 'non-standard', Writable => 'lang-alt' }, #11
    Author      => { Avoid => 1, Notes => 'non-standard', Groups => { 2 => 'Author' } }, #11
    Keywords    => { Avoid => 1, Notes => 'non-standard' }, #11
    Description => { Avoid => 1, Notes => 'non-standard', Writable => 'lang-alt' }, #11
    Format      => { Avoid => 1, Notes => 'non-standard' }, #11
);

# XMP Rights Management namespace properties (xmpRights, xapRights)
%Image::ExifTool::XMP::xmpRights = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-xmpRights', 2 => 'Author' },
    NAMESPACE   => 'xmpRights',
    NOTES => 'XMP Rights Management namespace tags.',
    Certificate     => { },
    Marked          => { Writable => 'boolean' },
    Owner           => { List => 'Bag' },
    UsageTerms      => { Writable => 'lang-alt' },
    WebStatement    => { },
);

# XMP Note namespace properties (xmpNote)
%Image::ExifTool::XMP::xmpNote = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-xmpNote' },
    NAMESPACE   => 'xmpNote',
    NOTES => 'XMP Note namespace tags.',
    HasExtendedXMP => {
        Notes => q{
            this tag is protected so it is not writable directly.  Instead, it is set
            automatically to the GUID of the extended XMP when writing extended XMP to a
            JPEG image
        },
        Protected => 2,
    },
);

# XMP xmpMM ManifestItem struct (ref PH, written by Adobe PDF library 8.0)
my %sManifestItem = (
    STRUCT_NAME => 'ManifestItem',
    NAMESPACE   => 'stMfs',
    linkForm            => { },
    placedXResolution   => { Namespace => 'xmpMM', Writable => 'real' },
    placedYResolution   => { Namespace => 'xmpMM', Writable => 'real' },
    placedResolutionUnit=> { Namespace => 'xmpMM' },
    reference           => { Struct => \%sResourceRef },
);

# the xmpMM Pantry
my %sPantryItem = (
    STRUCT_NAME => 'PantryItem',
    NAMESPACE   => undef, # stores any top-level XMP tags
    NOTES => q{
        This structure must have an InstanceID field, but may also contain any other
        XMP properties.
    },
    InstanceID => { Namespace => 'xmpMM', List => 0 },
);

# XMP Media Management namespace properties (xmpMM, xapMM)
%Image::ExifTool::XMP::xmpMM = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-xmpMM', 2 => 'Other' },
    NAMESPACE   => 'xmpMM',
    TABLE_DESC => 'XMP Media Management',
    NOTES => 'XMP Media Management namespace tags.',
    DerivedFrom     => { Struct => \%sResourceRef },
    DocumentID      => { },
    History         => { Struct => \%sResourceEvent, List => 'Seq' },
    # we treat these like list items since History is a list
    Ingredients     => { Struct => \%sResourceRef, List => 'Bag' },
    InstanceID      => { }, #PH (CS3)
    ManagedFrom     => { Struct => \%sResourceRef },
    Manager         => { Groups => { 2 => 'Author' } },
    ManageTo        => { Groups => { 2 => 'Author' } },
    ManageUI        => { },
    ManagerVariant  => { },
    Manifest        => { Struct => \%sManifestItem, List => 'Bag' },
    OriginalDocumentID=> { },
    Pantry          => { Struct => \%sPantryItem, List => 'Bag' },
    PreservedFileName => { },   # undocumented
    RenditionClass  => { },
    RenditionParams => { },
    VersionID       => { },
    Versions        => { Struct => \%sVersion, List => 'Seq' },
    LastURL         => { }, # (deprecated)
    RenditionOf     => { Struct => \%sResourceRef }, # (deprecated)
    SaveID          => { Writable => 'integer' }, # (deprecated)
    subject         => { List => 'Seq', Avoid => 1, Notes => 'undocumented' },
);

# XMP Basic Job Ticket namespace properties (xmpBJ, xapBJ)
%Image::ExifTool::XMP::xmpBJ = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-xmpBJ', 2 => 'Other' },
    NAMESPACE   => 'xmpBJ',
    TABLE_DESC => 'XMP Basic Job Ticket',
    NOTES => 'XMP Basic Job Ticket namespace tags.',
    # Note: JobRef is a List of structures.  To accomplish this, we set the XMP
    # List=>'Bag', but since SubDirectory is defined, this tag isn't writable
    # directly.  Then we need to set List=>1 for the members so the Writer logic
    # will allow us to add list items.
    JobRef => { Struct => \%sJobRef, List => 'Bag' },
);

# XMP Paged-Text namespace properties (xmpTPg)
%Image::ExifTool::XMP::xmpTPg = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-xmpTPg', 2 => 'Image' },
    NAMESPACE   => 'xmpTPg',
    TABLE_DESC => 'XMP Paged-Text',
    NOTES => 'XMP Paged-Text namespace tags.',
    MaxPageSize         => { Struct => \%sDimensions },
    NPages              => { Writable => 'integer' },
    Fonts               => {
        FlatName => '',
        Struct => \%sFont,
        List => 'Bag',
    },
    FontsVersionString  => { Name => 'FontVersion',     Flat => 1 },
    FontsComposite      => { Name => 'FontComposite',   Flat => 1 },
    Colorants           => {
        FlatName => 'Colorant',
        Struct => \%sColorant,
        List => 'Seq',
    },
    PlateNames          => { List => 'Seq' },
    # the following found in an AI file:
    HasVisibleTransparency => { Writable => 'boolean' },
    HasVisibleOverprint    => { Writable => 'boolean' },
    SwatchGroups => {
        Struct => \%sSwatchGroup,
        List => 'Seq',
    },
    SwatchGroupsColorants => { Name => 'SwatchGroupsColorants', Flat => 1 },
    SwatchGroupsGroupName => { Name => 'SwatchGroupName',       Flat => 1 },
    SwatchGroupsGroupType => { Name => 'SwatchGroupType',       Flat => 1 },
);

# PDF namespace properties (pdf)
%Image::ExifTool::XMP::pdf = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-pdf', 2 => 'Image' },
    NAMESPACE   => 'pdf',
    TABLE_DESC => 'XMP PDF',
    NOTES => q{
        Adobe PDF namespace tags.  The official XMP specification defines only
        Keywords, PDFVersion, Producer and Trapped.  The other tags are included
        because they have been observed in PDF files, but some are avoided when
        writing due to name conflicts with other XMP namespaces.
    },
    Author      => { Groups => { 2 => 'Author' } }, #PH
    ModDate     => { Groups => { 2 => 'Time' }, %dateTimeInfo }, #PH
    CreationDate=> { Groups => { 2 => 'Time' }, %dateTimeInfo }, #PH
    Creator     => { Groups => { 2 => 'Author' }, Avoid => 1 },
    Copyright   => { Groups => { 2 => 'Author' }, Avoid => 1 }, #PH
    Marked      => { Avoid => 1, Writable => 'boolean' }, #PH
    Subject     => { Avoid => 1 },
    Title       => { Avoid => 1 },
    Trapped     => { #PH
        # remove leading '/' from '/True' or '/False'
        ValueConv => '$val=~s{^/}{}; $val',
        ValueConvInv => '"/$val"',
        PrintConv => { True => 'True', False => 'False', Unknown => 'Unknown' },
    },
    Keywords    => { Priority => -1 }, # (-1 to get below Priority 0 PDF:Keywords)
    PDFVersion  => { },
    Producer    => { Groups => { 2 => 'Author' } },
);

# PDF extension namespace properties (pdfx)
%Image::ExifTool::XMP::pdfx = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-pdfx', 2 => 'Document' },
    NAMESPACE   => 'pdfx',
    NOTES => q{
        PDF extension tags.  This namespace is used to store application-defined PDF
        information, so there are few pre-defined tags.  User-defined tags must be
        created to enable writing of other XMP-pdfx information.
    },
    SourceModified => {
        Name => 'SourceModified',
        Groups => { 2 => 'Time' },
        Shift => 'Time',
        ValueConv => 'require Image::ExifTool::PDF; $val = Image::ExifTool::PDF::ConvertPDFDate($val)',
        ValueConvInv => q{
            require Image::ExifTool::PDF;
            $val = Image::ExifTool::PDF::WritePDFValue($self,$val,"date");
            $val =~ tr/()//d;
            return $val;
        },
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
);

# Photoshop namespace properties (photoshop)
%Image::ExifTool::XMP::photoshop = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-photoshop', 2 => 'Image' },
    NAMESPACE   => 'photoshop',
    TABLE_DESC => 'XMP Photoshop',
    NOTES => 'Adobe Photoshop namespace tags.',
    AuthorsPosition => { Groups => { 2 => 'Author' } },
    CaptionWriter   => { Groups => { 2 => 'Author' } },
    Category        => { },
    City            => { Groups => { 2 => 'Location' } },
    ColorMode       => {
        Writable => 'integer', # (as of July 2010 spec, courtesy of yours truly)
        PrintConvColumns => 2,
        PrintConv => {
            0 => 'Bitmap',
            1 => 'Grayscale',
            2 => 'Indexed',
            3 => 'RGB',
            4 => 'CMYK',
            7 => 'Multichannel',
            8 => 'Duotone',
            9 => 'Lab',
        },
    },
    Country         => { Groups => { 2 => 'Location' } },
    Credit          => { Groups => { 2 => 'Author' } },
    DateCreated     => { Groups => { 2 => 'Time' }, %dateTimeInfo },
    DocumentAncestors => {
        List => 'Bag',
        # Contrary to their own XMP specification, Adobe writes this as a simple Bag
        # of strings instead of structures, so comment out the structure definition...
        # FlatName => 'Document',
        # Struct => {
        #     STRUCT_NAME => 'Ancestor',
        #     NAMESPACE   => 'photoshop',
        #     AncestorID  => { },
        # },
    },
    Headline        => { },
    History         => { }, #PH (CS3)
    ICCProfile      => { Name => 'ICCProfileName' }, #PH
    Instructions    => { },
    LegacyIPTCDigest=> { }, #PH
    SidecarForExtension => { }, #PH (CS3)
    Source          => { Groups => { 2 => 'Author' } },
    State           => { Groups => { 2 => 'Location' } },
    # the XMP spec doesn't show SupplementalCategories as a 'Bag', but
    # that's the way Photoshop writes it [fixed in the June 2005 XMP spec].
    # Also, it is incorrectly listed as "SupplementalCategory" in the
    # IPTC Standard Photo Metadata docs (2008rev2 and July 2009rev1) - PH
    SupplementalCategories  => { List => 'Bag' },
    TextLayers => {
        FlatName => 'Text',
        List => 'Seq',
        Struct => {
            STRUCT_NAME => 'Layer',
            NAMESPACE   => 'photoshop',
            LayerName   => { },
            LayerText => { },
        },
    },
    TransmissionReference => { Notes => 'Now used as a job identifier' },
    Urgency         => {
        Writable => 'integer',
        Notes => 'should be in the range 1-8 to conform with the XMP spec',
        PrintConv => { # (same values as IPTC:Urgency)
            0 => '0 (reserved)',              # (not standard XMP)
            1 => '1 (most urgent)',
            2 => 2,
            3 => 3,
            4 => 4,
            5 => '5 (normal urgency)',
            6 => 6,
            7 => 7,
            8 => '8 (least urgent)',
            9 => '9 (user-defined priority)', # (not standard XMP)
        },
    },
    EmbeddedXMPDigest => { },   #PH (LR5)
    CameraProfiles => { #PH (2022-10-11)
        List => 'Seq',
        Struct => {
            NAMESPACE   => 'stCamera',
            STRUCT_NAME => 'Camera',
            Author              => { },
            Make                => { },
            Model               => { },
            UniqueCameraModel   => { },
            CameraRawProfile    => { Writable => 'boolean' },
            AutoScale           => { Writable => 'boolean' },
            Lens                => { },
            CameraPrettyName    => { },
            LensPrettyName      => { },
            ProfileName         => { },
            SensorFormatFactor  => { Writable => 'real' },
            FocalLength         => { Writable => 'real' },
            FocusDistance       => { Writable => 'real' },
            ApertureValue       => { Writable => 'real' },
            PerspectiveModel    => {
                Namespace       => 'crlcp',
                Struct => {
                    NAMESPACE   => 'stCamera',
                    STRUCT_NAME => 'PerspectiveModel',
                    Version              => { },
                    ImageXCenter         => { Writable => 'real' },
                    ImageYCenter         => { Writable => 'real' },
                    ScaleFactor          => { Writable => 'real' },
                    RadialDistortParam1  => { Writable => 'real' },
                    RadialDistortParam2  => { Writable => 'real' },
                    RadialDistortParam3  => { Writable => 'real' },
                },
            },
        },
    },
);

# Photoshop Camera Raw namespace properties (crs) - (ref 8,PH)
%Image::ExifTool::XMP::crs = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-crs', 2 => 'Image' },
    NAMESPACE   => 'crs',
    TABLE_DESC => 'Photoshop Camera Raw namespace',
    NOTES => q{
        Photoshop Camera Raw namespace tags.  It is a shame that Adobe pollutes the
        metadata space with these incredibly bulky image editing parameters.
    },
    AlreadyApplied  => { Writable => 'boolean' }, #PH (written by LightRoom beta 4.1)
    AutoBrightness  => { Writable => 'boolean' },
    AutoContrast    => { Writable => 'boolean' },
    AutoExposure    => { Writable => 'boolean' },
    AutoShadows     => { Writable => 'boolean' },
    BlueHue         => { Writable => 'integer' },
    BlueSaturation  => { Writable => 'integer' },
    Brightness      => { Writable => 'integer' },
    CameraProfile   => { },
    ChromaticAberrationB=> { Writable => 'integer' },
    ChromaticAberrationR=> { Writable => 'integer' },
    ColorNoiseReduction => { Writable => 'integer' },
    Contrast        => { Writable => 'integer', Avoid => 1 },
    Converter       => { }, #PH guess (found in EXIF)
    CropTop         => { Writable => 'real' },
    CropLeft        => { Writable => 'real' },
    CropBottom      => { Writable => 'real' },
    CropRight       => { Writable => 'real' },
    CropAngle       => { Writable => 'real' },
    CropWidth       => { Writable => 'real' },
    CropHeight      => { Writable => 'real' },
    CropUnits => {
        Writable => 'integer',
        PrintConv => {
            0 => 'pixels',
            1 => 'inches',
            2 => 'cm',
        },
    },
    Exposure        => { Writable => 'real' },
    GreenHue        => { Writable => 'integer' },
    GreenSaturation => { Writable => 'integer' },
    HasCrop         => { Writable => 'boolean' },
    HasSettings     => { Writable => 'boolean' },
    LuminanceSmoothing  => { Writable => 'integer' },
    MoireFilter     => { PrintConv => { Off=>'Off', On=>'On' } },
    RawFileName     => { },
    RedHue          => { Writable => 'integer' },
    RedSaturation   => { Writable => 'integer' },
    Saturation      => { Writable => 'integer', Avoid => 1 },
    Shadows         => { Writable => 'integer' },
    ShadowTint      => { Writable => 'integer' },
    Sharpness       => { Writable => 'integer', Avoid => 1 },
    Smoothness      => { Writable => 'integer' },
    Temperature     => { Writable => 'integer', Name => 'ColorTemperature' },
    Tint            => { Writable => 'integer' },
    ToneCurve       => { List => 'Seq' },
    ToneCurveName => {
        PrintConv => {
            Linear           => 'Linear',
           'Medium Contrast' => 'Medium Contrast',
           'Strong Contrast' => 'Strong Contrast',
            Custom           => 'Custom',
        },
    },
    Version         => { },
    VignetteAmount  => { Writable => 'integer' },
    VignetteMidpoint=> { Writable => 'integer' },
    WhiteBalance    => {
        Avoid => 1,
        PrintConv => {
           'As Shot'    => 'As Shot',
            Auto        => 'Auto',
            Daylight    => 'Daylight',
            Cloudy      => 'Cloudy',
            Shade       => 'Shade',
            Tungsten    => 'Tungsten',
            Fluorescent => 'Fluorescent',
            Flash       => 'Flash',
            Custom      => 'Custom',
        },
    },
    # new tags observed in Adobe Lightroom output - PH
    CameraProfileDigest         => { },
    Clarity                     => { Writable => 'integer' },
    ConvertToGrayscale          => { Writable => 'boolean' },
    Defringe                    => { Writable => 'integer' },
    FillLight                   => { Writable => 'integer' },
    HighlightRecovery           => { Writable => 'integer' },
    HueAdjustmentAqua           => { Writable => 'integer' },
    HueAdjustmentBlue           => { Writable => 'integer' },
    HueAdjustmentGreen          => { Writable => 'integer' },
    HueAdjustmentMagenta        => { Writable => 'integer' },
    HueAdjustmentOrange         => { Writable => 'integer' },
    HueAdjustmentPurple         => { Writable => 'integer' },
    HueAdjustmentRed            => { Writable => 'integer' },
    HueAdjustmentYellow         => { Writable => 'integer' },
    IncrementalTemperature      => { Writable => 'integer' },
    IncrementalTint             => { Writable => 'integer' },
    LuminanceAdjustmentAqua     => { Writable => 'integer' },
    LuminanceAdjustmentBlue     => { Writable => 'integer' },
    LuminanceAdjustmentGreen    => { Writable => 'integer' },
    LuminanceAdjustmentMagenta  => { Writable => 'integer' },
    LuminanceAdjustmentOrange   => { Writable => 'integer' },
    LuminanceAdjustmentPurple   => { Writable => 'integer' },
    LuminanceAdjustmentRed      => { Writable => 'integer' },
    LuminanceAdjustmentYellow   => { Writable => 'integer' },
    ParametricDarks             => { Writable => 'integer' },
    ParametricHighlights        => { Writable => 'integer' },
    ParametricHighlightSplit    => { Writable => 'integer' },
    ParametricLights            => { Writable => 'integer' },
    ParametricMidtoneSplit      => { Writable => 'integer' },
    ParametricShadows           => { Writable => 'integer' },
    ParametricShadowSplit       => { Writable => 'integer' },
    SaturationAdjustmentAqua    => { Writable => 'integer' },
    SaturationAdjustmentBlue    => { Writable => 'integer' },
    SaturationAdjustmentGreen   => { Writable => 'integer' },
    SaturationAdjustmentMagenta => { Writable => 'integer' },
    SaturationAdjustmentOrange  => { Writable => 'integer' },
    SaturationAdjustmentPurple  => { Writable => 'integer' },
    SaturationAdjustmentRed     => { Writable => 'integer' },
    SaturationAdjustmentYellow  => { Writable => 'integer' },
    SharpenDetail               => { Writable => 'integer' },
    SharpenEdgeMasking          => { Writable => 'integer' },
    SharpenRadius               => { Writable => 'real' },
    SplitToningBalance          => { Writable => 'integer', Notes => 'also used for newer ColorGrade settings' },
    SplitToningHighlightHue     => { Writable => 'integer', Notes => 'also used for newer ColorGrade settings' },
    SplitToningHighlightSaturation => { Writable => 'integer', Notes => 'also used for newer ColorGrade settings' },
    SplitToningShadowHue        => { Writable => 'integer', Notes => 'also used for newer ColorGrade settings' },
    SplitToningShadowSaturation => { Writable => 'integer', Notes => 'also used for newer ColorGrade settings' },
    Vibrance                    => { Writable => 'integer' },
    # new tags written by LR 1.4 (not sure in what version they first appeared)
    GrayMixerRed                => { Writable => 'integer' },
    GrayMixerOrange             => { Writable => 'integer' },
    GrayMixerYellow             => { Writable => 'integer' },
    GrayMixerGreen              => { Writable => 'integer' },
    GrayMixerAqua               => { Writable => 'integer' },
    GrayMixerBlue               => { Writable => 'integer' },
    GrayMixerPurple             => { Writable => 'integer' },
    GrayMixerMagenta            => { Writable => 'integer' },
    RetouchInfo                 => { List => 'Seq' },
    RedEyeInfo                  => { List => 'Seq' },
    # new tags written by LR 2.0 (ref PH)
    CropUnit => { # was the XMP documentation wrong with "CropUnits"??
        Writable => 'integer',
        PrintConv => {
            0 => 'pixels',
            1 => 'inches',
            2 => 'cm',
            # have seen a value of 3 here! - PH
        },
    },
    PostCropVignetteAmount      => { Writable => 'integer' },
    PostCropVignetteMidpoint    => { Writable => 'integer' },
    PostCropVignetteFeather     => { Writable => 'integer' },
    PostCropVignetteRoundness   => { Writable => 'integer' },
    PostCropVignetteStyle       => {
        Writable => 'integer',
        PrintConv => { #forum14011
            1 => 'Highlight Priority',
            2 => 'Color Priority',
            3 => 'Paint Overlay',
        },
    },
    # disable List behaviour of flattened Gradient/PaintBasedCorrections
    # because these are nested in lists and the flattened tags can't
    # do justice to this complex structure
    GradientBasedCorrections => {
        FlatName => 'GradientBasedCorr',
        Struct => \%sCorrection,
        List => 'Seq',
    },
    GradientBasedCorrectionsCorrectionMasks => {
        Name => 'GradientBasedCorrMasks',
        FlatName => 'GradientBasedCorrMask',
        Flat => 1
    },
    GradientBasedCorrectionsCorrectionMasksDabs => {
        Name => 'GradientBasedCorrMaskDabs',
        Flat => 1, List => 0,
    },
    PaintBasedCorrections => {
        FlatName => 'PaintCorrection',
        Struct => \%sCorrection,
        List => 'Seq',
    },
    PaintBasedCorrectionsCorrectionMasks => {
        Name => 'PaintBasedCorrectionMasks',
        FlatName => 'PaintCorrectionMask',
        Flat => 1,
    },
    PaintBasedCorrectionsCorrectionMasksDabs => {
        Name => 'PaintCorrectionMaskDabs',
        Flat => 1, List => 0,
    },
    # new tags written by LR 3 (thanks Wolfgang Guelcker)
    ProcessVersion                      => { },
    LensProfileEnable                   => { Writable => 'integer' },
    LensProfileSetup                    => { },
    LensProfileName                     => { },
    LensProfileFilename                 => { },
    LensProfileDigest                   => { },
    LensProfileDistortionScale          => { Writable => 'integer' },
    LensProfileChromaticAberrationScale => { Writable => 'integer' },
    LensProfileVignettingScale          => { Writable => 'integer' },
    LensManualDistortionAmount          => { Writable => 'integer' },
    PerspectiveVertical                 => { Writable => 'integer' },
    PerspectiveHorizontal               => { Writable => 'integer' },
    PerspectiveRotate                   => { Writable => 'real'    },
    PerspectiveScale                    => { Writable => 'integer' },
    CropConstrainToWarp                 => { Writable => 'integer' },
    LuminanceNoiseReductionDetail       => { Writable => 'integer' },
    LuminanceNoiseReductionContrast     => { Writable => 'integer' },
    ColorNoiseReductionDetail           => { Writable => 'integer' },
    GrainAmount                         => { Writable => 'integer' },
    GrainSize                           => { Writable => 'integer' },
    GrainFrequency                      => { Writable => 'integer' },
    # new tags written by LR4
    AutoLateralCA                       => { Writable => 'integer' },
    Exposure2012                        => { Writable => 'real' },
    Contrast2012                        => { Writable => 'integer' },
    Highlights2012                      => { Writable => 'integer' },
    Highlight2012                       => { Writable => 'integer' }, # (written by Nikon software)
    Shadows2012                         => { Writable => 'integer' },
    Whites2012                          => { Writable => 'integer' },
    Blacks2012                          => { Writable => 'integer' },
    Clarity2012                         => { Writable => 'integer' },
    PostCropVignetteHighlightContrast   => { Writable => 'integer' },
    ToneCurveName2012                   => { },
    ToneCurveRed                        => { List => 'Seq' },
    ToneCurveGreen                      => { List => 'Seq' },
    ToneCurveBlue                       => { List => 'Seq' },
    ToneCurvePV2012                     => { List => 'Seq' },
    ToneCurvePV2012Red                  => { List => 'Seq' },
    ToneCurvePV2012Green                => { List => 'Seq' },
    ToneCurvePV2012Blue                 => { List => 'Seq' },
    DefringePurpleAmount                => { Writable => 'integer' },
    DefringePurpleHueLo                 => { Writable => 'integer' },
    DefringePurpleHueHi                 => { Writable => 'integer' },
    DefringeGreenAmount                 => { Writable => 'integer' },
    DefringeGreenHueLo                  => { Writable => 'integer' },
    DefringeGreenHueHi                  => { Writable => 'integer' },
    # new tags written by LR5
    AutoWhiteVersion                    => { Writable => 'integer' },
    CircularGradientBasedCorrections => {
        FlatName => 'CircGradBasedCorr',
        Struct => \%sCorrection,
        List => 'Seq',
    },
    CircularGradientBasedCorrectionsCorrectionMasks => {
        Name => 'CircGradBasedCorrMasks',
        FlatName => 'CircGradBasedCorrMask',
        Flat => 1
    },
    CircularGradientBasedCorrectionsCorrectionMasksDabs => {
        Name => 'CircGradBasedCorrMaskDabs',
        Flat => 1, List => 0,
    },
    ColorNoiseReductionSmoothness       => { Writable => 'integer' },
    PerspectiveAspect                   => { Writable => 'integer' },
    PerspectiveUpright                  => {
        Writable => 'integer',
        PrintConv => { #forum14012
            0 => 'Off',     # Disable Upright
            1 => 'Auto',    # Apply balanced perspective corrections
            2 => 'Full',    # Apply level, horizontal, and vertical perspective corrections
            3 => 'Level',   # Apply only level correction
            4 => 'Vertical',# Apply level and vertical perspective corrections
            5 => 'Guided',  # Draw two or more guides to customize perspective corrections
        },
    },
    RetouchAreas => {
        FlatName => 'RetouchArea',
        Struct => \%sRetouchArea,
        List => 'Seq',
    },
    RetouchAreasMasks => {
        Name => 'RetouchAreaMasks',
        FlatName => 'RetouchAreaMask',
        Flat => 1
    },
    RetouchAreasMasksDabs => {
        Name => 'RetouchAreaMaskDabs',
        Flat => 1, List => 0,
    },
    UprightVersion                      => { Writable => 'integer' },
    UprightCenterMode                   => { Writable => 'integer' },
    UprightCenterNormX                  => { Writable => 'real' },
    UprightCenterNormY                  => { Writable => 'real' },
    UprightFocalMode                    => { Writable => 'integer' },
    UprightFocalLength35mm              => { Writable => 'real' },
    UprightPreview                      => { Writable => 'boolean' },
    UprightTransformCount               => { Writable => 'integer' },
    UprightDependentDigest              => { },
    UprightGuidedDependentDigest        => { },
    UprightTransform_0                  => { },
    UprightTransform_1                  => { },
    UprightTransform_2                  => { },
    UprightTransform_3                  => { },
    UprightTransform_4                  => { },
    UprightTransform_5                  => { },
    UprightFourSegments_0               => { },
    UprightFourSegments_1               => { },
    UprightFourSegments_2               => { },
    UprightFourSegments_3               => { },
    # more stuff seen in lens profile file (unknown source)
    What => { }, # (with value "LensProfileDefaultSettings")
    LensProfileMatchKeyExifMake         => { },
    LensProfileMatchKeyExifModel        => { },
    LensProfileMatchKeyCameraModelName  => { },
    LensProfileMatchKeyLensInfo         => { },
    LensProfileMatchKeyLensID           => { },
    LensProfileMatchKeyLensName         => { },
    LensProfileMatchKeyIsRaw            => { Writable => 'boolean' },
    LensProfileMatchKeySensorFormatFactor=>{ Writable => 'real' },
    # more stuff (ref forum6993)
    DefaultAutoTone                     => { Writable => 'boolean' },
    DefaultAutoGray                     => { Writable => 'boolean' },
    DefaultsSpecificToSerial            => { Writable => 'boolean' },
    DefaultsSpecificToISO               => { Writable => 'boolean' },
    DNGIgnoreSidecars                   => { Writable => 'boolean' },
    NegativeCachePath                   => { },
    NegativeCacheMaximumSize            => { Writable => 'real' },
    NegativeCacheLargePreviewSize       => { Writable => 'integer' },
    JPEGHandling                        => { },
    TIFFHandling                        => { },
    Dehaze                              => { Writable => 'real' },
    ToneMapStrength                     => { Writable => 'real' },
    # yet more
    PerspectiveX                        => { Writable => 'real' },
    PerspectiveY                        => { Writable => 'real' },
    UprightFourSegmentsCount            => { Writable => 'integer' },
    AutoTone                            => { Writable => 'boolean' },
    Texture                             => { Writable => 'integer' },
    # more stuff (ref forum10721)
    OverrideLookVignette                => { Writable => 'boolean' },
    Look => {
        Struct => {
            STRUCT_NAME => 'Look',
            NAMESPACE   => 'crs',
            Name        => { },
            Amount      => { },
            Cluster     => { },
            UUID        => { },
            SupportsMonochrome => { },
            SupportsAmount     => { },
            SupportsOutputReferred => { },
            Copyright   => { },
            Group       => { Writable => 'lang-alt' },
            Parameters => {
                Struct => {
                    STRUCT_NAME => 'LookParms',
                    NAMESPACE   => 'crs',
                    Version         => { },
                    ProcessVersion  => { },
                    Clarity2012     => { },
                    ConvertToGrayscale => { },
                    CameraProfile   => { },
                    LookTable       => { },
                    ToneCurvePV2012 => { List => 'Seq' },
                    ToneCurvePV2012Red   => { List => 'Seq' },
                    ToneCurvePV2012Green => { List => 'Seq' },
                    ToneCurvePV2012Blue  => { List => 'Seq' },
                    Highlights2012  => { },
                    Shadows2012     => { },
                },
            },
        }
    },
    # more again (ref forum11258)
    GrainSeed => { },
    ClipboardOrientation => { Writable => 'integer' },
    ClipboardAspectRatio => { Writable => 'integer' },
    PresetType  => { },
    Cluster     => { },
    UUID        => { Avoid => 1 },
    SupportsAmount          => { Writable => 'boolean' },
    SupportsColor           => { Writable => 'boolean' },
    SupportsMonochrome      => { Writable => 'boolean' },
    SupportsHighDynamicRange=> { Writable => 'boolean' },
    SupportsNormalDynamicRange=> { Writable => 'boolean' },
    SupportsSceneReferred   => { Writable => 'boolean' },
    SupportsOutputReferred  => { Writable => 'boolean' },
    CameraModelRestriction  => { },
    Copyright   => { Avoid => 1 },
    ContactInfo => { },
    GrainSeed   => { Writable => 'integer' },
    Name        => { Writable => 'lang-alt', Avoid => 1 },
    ShortName   => { Writable => 'lang-alt' },
    SortName    => { Writable => 'lang-alt' },
    Group       => { Writable => 'lang-alt', Avoid => 1 },
    Description => { Writable => 'lang-alt', Avoid => 1 },
    # new for DNG converter 13.0
    LookName => { NotFlat => 1 }, # (grr... conflicts with "Name" element of "Look" struct!)
    # new for Lightroom CC 2021 (ref forum11745)
    ColorGradeMidtoneHue    => { Writable => 'integer' },
    ColorGradeMidtoneSat    => { Writable => 'integer' },
    ColorGradeShadowLum     => { Writable => 'integer' },
    ColorGradeMidtoneLum    => { Writable => 'integer' },
    ColorGradeHighlightLum  => { Writable => 'integer' },
    ColorGradeBlending      => { Writable => 'integer' },
    ColorGradeGlobalHue     => { Writable => 'integer' },
    ColorGradeGlobalSat     => { Writable => 'integer' },
    ColorGradeGlobalLum     => { Writable => 'integer' },
    # new for Adobe Camera Raw 13 (ref forum11745)
    LensProfileIsEmbedded   => { Writable => 'boolean'},
    AutoToneDigest          => { },
    AutoToneDigestNoSat     => { },
    ToggleStyleDigest       => { },
    ToggleStyleAmount       => { Writable => 'integer' },
    # new for LightRoom 11.0
    CompatibleVersion       => { },
    MaskGroupBasedCorrections => {
        FlatName => 'MaskGroupBasedCorr',
        Struct => \%sCorrection,
        List => 'Seq',
    },
    RangeMaskMapInfo => { Name => 'RangeMask', Struct => \%sRangeMask, FlatName => 'RangeMask' },
    # new for ACR 15.1 (not sure if these are integer or real, so just guess)
    HDREditMode    => { Writable => 'integer' },
    SDRBrightness  => { Writable => 'real' },
    SDRContrast    => { Writable => 'real' },
    SDRHighlights  => { Writable => 'real' },
    SDRShadows     => { Writable => 'real' },
    SDRWhites      => { Writable => 'real' },
    SDRBlend       => { Writable => 'real' },
    # new for ACR 16 (ref forum15305)
    LensBlur => {
        Struct => {
            STRUCT_NAME     => 'LensBlur',
            NAMESPACE       => 'crs',
            # (Note: all the following 'real' values could be limited to 'integer')
            Active          => { Writable => 'boolean' },
            BlurAmount      => { FlatName => 'Amount', Writable => 'real' },
            BokehAspect     => { Writable => 'real' },
            BokehRotation   => { Writable => 'real' },
            BokehShape      => { Writable => 'real' },
            BokehShapeDetail => { Writable => 'real' },
            CatEyeAmount    => { Writable => 'real' },
            CatEyeScale     => { Writable => 'real' },
            FocalRange      => { }, # (eg. "-48 32 64 144")
            FocalRangeSource => { Writable => 'real' },
            HighlightsBoost => { Writable => 'real' },
            HighlightsThreshold => { Writable => 'real' },
            SampledArea     => { }, # (eg. "0.500000 0.500000 0.500000 0.500000")
            SampledRange    => { }, # (eg. "0 0")
            SphericalAberration => { Writable => 'real' },
            SubjectRange    => { }, # (eg. "0 57");
            Version         => { },
         },
    },
    DepthMapInfo => {
        Struct => {
            STRUCT_NAME     => 'DepthMapInfo',
            NAMESPACE       => 'crs',
            BaseHighlightGuideInputDigest => { },
            BaseHighlightGuideTable     => { },
            BaseHighlightGuideVersion   => { },
            BaseLayeredDepthInputDigest => { },
            BaseLayeredDepthTable       => { },
            BaseLayeredDepthVersion     => { },
            BaseRawDepthInputDigest     => { },
            BaseRawDepthTable           => { },
            BaseRawDepthVersion         => { },
            DepthSource                 => { },
        },
    },
    DepthBasedCorrections => {
        List => 'Seq',
        FlatName => 'DepthBasedCorr',
        Struct => {
            STRUCT_NAME      => 'DepthBasedCorr',
            NAMESPACE        => 'crs',
            CorrectionActive => { Writable => 'boolean' },
            CorrectionAmount => { Writable => 'real' },
            CorrectionMasks  => { FlatName => 'Mask', List => 'Seq', Struct => \%sCorrectionMask },
            CorrectionSyncID => { },
            LocalCorrectedDepth => {  Writable => 'real' },
            LocalCurveRefineSaturation => { Writable => 'real' },
            What             => { },
        },
    },
);

# Tiff namespace properties (tiff)
%Image::ExifTool::XMP::tiff = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-tiff', 2 => 'Image' },
    NAMESPACE   => 'tiff',
    PRIORITY => 0, # not as reliable as actual TIFF tags
    TABLE_DESC => 'XMP TIFF',
    NOTES => q{
        EXIF namespace for TIFF tags.  See
        L<https://web.archive.org/web/20180921145139if_/http://www.cipa.jp:80/std/documents/e/DC-010-2017_E.pdf>
        for the specification.
    },
    ImageWidth    => { Writable => 'integer' },
    ImageLength   => { Writable => 'integer', Name => 'ImageHeight' },
    BitsPerSample => { Writable => 'integer', List => 'Seq', AutoSplit => 1 },
    Compression => {
        Writable => 'integer',
        SeparateTable => 'EXIF Compression',
        PrintConv => \%Image::ExifTool::Exif::compression,
    },
    PhotometricInterpretation => {
        Writable => 'integer',
        PrintConv => \%Image::ExifTool::Exif::photometricInterpretation,
    },
    Orientation => {
        Writable => 'integer',
        PrintConv => \%Image::ExifTool::Exif::orientation,
    },
    SamplesPerPixel => { Writable => 'integer' },
    PlanarConfiguration => {
        Writable => 'integer',
        PrintConv => {
            1 => 'Chunky',
            2 => 'Planar',
        },
    },
    YCbCrSubSampling => {
        Writable => 'integer',
        List => 'Seq',
        # join the raw values before conversion to allow PrintConv to operate on
        # the combined string as it does for the corresponding EXIF tag
        RawJoin => 1,
        Notes => q{
            while technically this is a list-type tag, for compatibility with its EXIF
            counterpart it is written and read as a simple string
        },
        PrintConv => \%Image::ExifTool::JPEG::yCbCrSubSampling,
    },
    YCbCrPositioning => {
        Writable => 'integer',
        PrintConv => {
            1 => 'Centered',
            2 => 'Co-sited',
        },
    },
    XResolution => { Writable => 'rational' },
    YResolution => { Writable => 'rational' },
    ResolutionUnit => {
        Writable => 'integer',
        Notes => 'the value 1 is not standard EXIF',
        PrintConv => {
            1 => 'None',
            2 => 'inches',
            3 => 'cm',
        },
    },
    TransferFunction      => { Writable => 'integer',  List => 'Seq', AutoSplit => 1 },
    WhitePoint            => { Writable => 'rational', List => 'Seq', AutoSplit => 1 },
    PrimaryChromaticities => { Writable => 'rational', List => 'Seq', AutoSplit => 1 },
    YCbCrCoefficients     => { Writable => 'rational', List => 'Seq', AutoSplit => 1 },
    ReferenceBlackWhite   => { Writable => 'rational', List => 'Seq', AutoSplit => 1 },
    DateTime => { # (EXIF tag named ModifyDate, but this exists in XMP-xmp)
        Description => 'Date/Time Modified',
        Groups => { 2 => 'Time' },
        %dateTimeInfo,
    },
    ImageDescription => { Writable => 'lang-alt' },
    Make => {
        Groups => { 2 => 'Camera' },
        RawConv => '$$self{Make} ? $val : $$self{Make} = $val',
    },
    Model => {
        Groups => { 2 => 'Camera' },
        Description => 'Camera Model Name',
        RawConv => '$$self{Model} ? $val : $$self{Model} = $val',
    },
    Software  => { },
    Artist    => { Groups => { 2 => 'Author' } },
    Copyright => { Groups => { 2 => 'Author' }, Writable => 'lang-alt' },
    NativeDigest => { Avoid => 1 }, #PH
);

# Exif namespace properties (exif)
%Image::ExifTool::XMP::exif = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-exif', 2 => 'Image' },
    NAMESPACE   => 'exif',
    PRIORITY => 0, # not as reliable as actual EXIF tags
    NOTES => q{
        EXIF namespace for EXIF tags.  See
        L<https://web.archive.org/web/20180921145139if_/http://www.cipa.jp:80/std/documents/e/DC-010-2017_E.pdf>
        for the specification.
    },
    ExifVersion     => { },
    FlashpixVersion => { },
    ColorSpace => {
        Writable => 'integer',
        # (some applications incorrectly write -1 as a long integer)
        ValueConv => '$val == 0xffffffff ? 0xffff : $val',
        ValueConvInv => '$val',
        PrintConv => {
            1 => 'sRGB',
            2 => 'Adobe RGB',
            0xffff => 'Uncalibrated',
        },
    },
    ComponentsConfiguration => {
        Writable => 'integer',
        List => 'Seq',
        AutoSplit => 1,
        PrintConvColumns => 2,
        PrintConv => {
            0 => '-',
            1 => 'Y',
            2 => 'Cb',
            3 => 'Cr',
            4 => 'R',
            5 => 'G',
            6 => 'B',
        },
    },
    CompressedBitsPerPixel => { Writable => 'rational' },
    PixelXDimension  => { Name => 'ExifImageWidth',  Writable => 'integer' },
    PixelYDimension  => { Name => 'ExifImageHeight', Writable => 'integer' },
    MakerNote        => { },
    UserComment      => { Writable => 'lang-alt' },
    RelatedSoundFile => { },
    DateTimeOriginal => {
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        %dateTimeInfo,
    },
    DateTimeDigitized => { # (EXIF tag named CreateDate, but this exists in XMP-xmp)
        Description => 'Date/Time Digitized',
        Groups => { 2 => 'Time' },
        %dateTimeInfo,
    },
    ExposureTime => {
        Writable => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        PrintConvInv => '$val',
    },
    FNumber => {
        Writable => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintFNumber($val)',
        PrintConvInv => '$val',
    },
    ExposureProgram => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Not Defined',
            1 => 'Manual',
            2 => 'Program AE',
            3 => 'Aperture-priority AE',
            4 => 'Shutter speed priority AE',
            5 => 'Creative (Slow speed)',
            6 => 'Action (High speed)',
            7 => 'Portrait',
            8 => 'Landscape',
        },
    },
    SpectralSensitivity => { Groups => { 2 => 'Camera' } },
    ISOSpeedRatings => {
        Name => 'ISO',
        Writable => 'integer',
        List => 'Seq',
        AutoSplit => 1,
        Notes => 'deprecated',
    },
    OECF => {
        Name => 'Opto-ElectricConvFactor',
        FlatName => 'OECF',
        Groups => { 2 => 'Camera' },
        Struct => \%sOECF,
    },
    ShutterSpeedValue => {
        Writable => 'rational',
        ValueConv => 'abs($val)<100 ? 1/(2**$val) : 0',
        PrintConv => 'Image::ExifTool::Exif::PrintExposureTime($val)',
        ValueConvInv => '$val>0 ? -log($val)/log(2) : 0',
        PrintConvInv => 'Image::ExifTool::Exif::ConvertFraction($val)',
    },
    ApertureValue => {
        Writable => 'rational',
        ValueConv => 'sqrt(2) ** $val',
        PrintConv => 'sprintf("%.1f",$val)',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConvInv => '$val',
    },
    BrightnessValue   => { Writable => 'rational' },
    ExposureBiasValue => {
        Name => 'ExposureCompensation',
        Writable => 'rational',
        PrintConv => 'Image::ExifTool::Exif::PrintFraction($val)',
        PrintConvInv => '$val',
    },
    MaxApertureValue => {
        Groups => { 2 => 'Camera' },
        Writable => 'rational',
        ValueConv => 'sqrt(2) ** $val',
        PrintConv => 'sprintf("%.1f",$val)',
        ValueConvInv => '$val>0 ? 2*log($val)/log(2) : 0',
        PrintConvInv => '$val',
    },
    SubjectDistance => {
        Groups => { 2 => 'Camera' },
        Writable => 'rational',
        PrintConv => '$val =~ /^(inf|undef)$/ ? $val : "$val m"',
        PrintConvInv => '$val=~s/\s*m$//;$val',
    },
    MeteringMode => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            1 => 'Average',
            2 => 'Center-weighted average',
            3 => 'Spot',
            4 => 'Multi-spot',
            5 => 'Multi-segment',
            6 => 'Partial',
            255 => 'Other',
        },
    },
    LightSource => {
        Groups => { 2 => 'Camera' },
        SeparateTable => 'EXIF LightSource',
        PrintConv =>  \%Image::ExifTool::Exif::lightSource,
    },
    Flash => {
        Groups => { 2 => 'Camera' },
        Struct => {
            STRUCT_NAME => 'Flash',
            NAMESPACE   => 'exif',
            Fired       => { Writable => 'boolean', %boolConv },
            Return => {
                Writable => 'integer',
                PrintConv => {
                    0 => 'No return detection',
                    2 => 'Return not detected',
                    3 => 'Return detected',
                },
            },
            Mode => {
                Writable => 'integer',
                PrintConv => {
                    0 => 'Unknown',
                    1 => 'On',
                    2 => 'Off',
                    3 => 'Auto',
                },
            },
            Function    => { Writable => 'boolean', %boolConv },
            RedEyeMode  => { Writable => 'boolean', %boolConv },
        },
    },
    FocalLength=> {
        Groups => { 2 => 'Camera' },
        Writable => 'rational',
        PrintConv => 'sprintf("%.1f mm",$val)',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    SubjectArea => { Writable => 'integer', List => 'Seq', AutoSplit => 1 },
    FlashEnergy => { Groups => { 2 => 'Camera' }, Writable => 'rational' },
    SpatialFrequencyResponse => {
        Groups => { 2 => 'Camera' },
        Struct => \%sOECF,
    },
    FocalPlaneXResolution => { Groups => { 2 => 'Camera' }, Writable => 'rational' },
    FocalPlaneYResolution => { Groups => { 2 => 'Camera' }, Writable => 'rational' },
    FocalPlaneResolutionUnit => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        Notes => 'values 1, 4 and 5 are not standard EXIF',
        PrintConv => {
            1 => 'None', # (not standard EXIF)
            2 => 'inches',
            3 => 'cm',
            4 => 'mm',   # (not standard EXIF)
            5 => 'um',   # (not standard EXIF)
        },
    },
    SubjectLocation => { Writable => 'integer', List => 'Seq', AutoSplit => 1 },
    ExposureIndex   => { Writable => 'rational' },
    SensingMethod => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        Notes => 'values 1 and 6 are not standard EXIF',
        PrintConv => {
            1 => 'Monochrome area', # (not standard EXIF)
            2 => 'One-chip color area',
            3 => 'Two-chip color area',
            4 => 'Three-chip color area',
            5 => 'Color sequential area',
            6 => 'Monochrome linear', # (not standard EXIF)
            7 => 'Trilinear',
            8 => 'Color sequential linear',
        },
    },
    FileSource => {
        Writable => 'integer',
        PrintConv => {
            1 => 'Film Scanner',
            2 => 'Reflection Print Scanner',
            3 => 'Digital Camera',
        }
    },
    SceneType  => { Writable => 'integer', PrintConv => { 1 => 'Directly photographed' } },
    CFAPattern => {
        Struct => {
            STRUCT_NAME => 'CFAPattern',
            NAMESPACE   => 'exif',
            Columns     => { Writable => 'integer' },
            Rows        => { Writable => 'integer' },
            Values      => { Writable => 'integer', List => 'Seq' },
        },
    },
    CustomRendered => {
        Writable => 'integer',
        PrintConv => {
            0 => 'Normal',
            1 => 'Custom',
        },
    },
    ExposureMode => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
            2 => 'Auto bracket',
        },
    },
    WhiteBalance => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Auto',
            1 => 'Manual',
        },
    },
    DigitalZoomRatio => { Writable => 'rational' },
    FocalLengthIn35mmFilm => {
        Name => 'FocalLengthIn35mmFormat',
        Writable => 'integer',
        Groups => { 2 => 'Camera' },
        PrintConv => '"$val mm"',
        PrintConvInv => '$val=~s/\s*mm$//;$val',
    },
    SceneCaptureType => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Standard',
            1 => 'Landscape',
            2 => 'Portrait',
            3 => 'Night',
        },
    },
    GainControl => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'None',
            1 => 'Low gain up',
            2 => 'High gain up',
            3 => 'Low gain down',
            4 => 'High gain down',
        },
    },
    Contrast => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
        },
        PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
    },
    Saturation => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Normal',
            1 => 'Low',
            2 => 'High',
        },
        PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
    },
    Sharpness => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Normal',
            1 => 'Soft',
            2 => 'Hard',
        },
        PrintConvInv => 'Image::ExifTool::Exif::ConvertParameter($val)',
    },
    DeviceSettingDescription => {
        Groups => { 2 => 'Camera' },
        Struct => {
            STRUCT_NAME => 'DeviceSettings',
            NAMESPACE   => 'exif',
            Columns     => { Writable => 'integer' },
            Rows        => { Writable => 'integer' },
            Settings    => { List => 'Seq' },
        },
    },
    SubjectDistanceRange => {
        Groups => { 2 => 'Camera' },
        Writable => 'integer',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Macro',
            2 => 'Close',
            3 => 'Distant',
        },
    },
    ImageUniqueID   => { Avoid => 1, Notes => 'moved to exifEX namespace in 2024 spec' },
    GPSVersionID    => { Groups => { 2 => 'Location' } },
    GPSLatitude     => { Groups => { 2 => 'Location' }, %latConv },
    GPSLongitude    => { Groups => { 2 => 'Location' }, %longConv },
    GPSAltitudeRef  => {
        Groups => { 2 => 'Location' },
        Writable => 'integer',
        PrintConv => {
            OTHER => sub {
                my ($val, $inv) = @_;
                return undef unless $inv and $val =~ /^([-+0-9])/;
                return($1 eq '-' ? 1 : 0);
            },
            0 => 'Above Sea Level',
            1 => 'Below Sea Level',
        },
    },
    GPSAltitude => {
        Groups => { 2 => 'Location' },
        Writable => 'rational',
        # extricate unsigned decimal number from string
        ValueConvInv => '$val=~/((?=\d|\.\d)\d*(?:\.\d*)?)/ ? $1 : undef',
        PrintConv => '$val =~ /^(inf|undef)$/ ? $val : "$val m"',
        PrintConvInv => '$val=~s/\s*m$//;$val',
    },
    GPSTimeStamp => {
        Name => 'GPSDateTime',
        Description => 'GPS Date/Time',
        Groups => { 2 => 'Time' },
        Notes => q{
            a date/time tag called GPSTimeStamp by the XMP specification.  This tag is
            renamed here to prevent direct copy from EXIF:GPSTimeStamp which is a
            time-only tag.  Instead, the value of this tag should be taken from
            Composite:GPSDateTime when copying from EXIF
        },
        %dateTimeInfo,
    },
    GPSSatellites   => { Groups => { 2 => 'Location' } },
    GPSStatus => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            A => 'Measurement Active',
            V => 'Measurement Void',
        },
    },
    GPSMeasureMode => {
        Groups => { 2 => 'Location' },
        Writable => 'integer',
        PrintConv => {
            2 => '2-Dimensional Measurement',
            3 => '3-Dimensional Measurement',
        },
    },
    GPSDOP => { Groups => { 2 => 'Location' }, Writable => 'rational' },
    GPSSpeedRef => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            K => 'km/h',
            M => 'mph',
            N => 'knots',
        },
    },
    GPSSpeed => { Groups => { 2 => 'Location' }, Writable => 'rational' },
    GPSTrackRef => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    GPSTrack => { Groups => { 2 => 'Location' }, Writable => 'rational' },
    GPSImgDirectionRef => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    GPSImgDirection => { Groups => { 2 => 'Location' }, Writable => 'rational' },
    GPSMapDatum     => { Groups => { 2 => 'Location' } },
    GPSDestLatitude => { Groups => { 2 => 'Location' }, %latConv },
    GPSDestLongitude=> { Groups => { 2 => 'Location' }, %longConv },
    GPSDestBearingRef => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            M => 'Magnetic North',
            T => 'True North',
        },
    },
    GPSDestBearing => { Groups => { 2 => 'Location' }, Writable => 'rational' },
    GPSDestDistanceRef => {
        Groups => { 2 => 'Location' },
        PrintConv => {
            K => 'Kilometers',
            M => 'Miles',
            N => 'Nautical Miles',
        },
    },
    GPSDestDistance => {
        Groups => { 2 => 'Location' },
        Writable => 'rational',
    },
    GPSProcessingMethod => { Groups => { 2 => 'Location' } },
    GPSAreaInformation  => { Groups => { 2 => 'Location' } },
    GPSDifferential => {
        Groups => { 2 => 'Location' },
        Writable => 'integer',
        PrintConv => {
            0 => 'No Correction',
            1 => 'Differential Corrected',
        },
    },
    GPSHPositioningError => { #12
        Description => 'GPS Horizontal Positioning Error',
        Groups => { 2 => 'Location' },
        Writable => 'rational',
        PrintConv => '"$val m"',
        PrintConvInv => '$val=~s/\s*m$//; $val',
    },
    NativeDigest => { }, #PH
    # the following written incorrectly by ACR 15.1
    # SubSecTime (should not be written according to Exif4XMP 2.32 specification)
    # SubSecTimeOriginal (should not be written according to Exif4XMP 2.32 specification)
    # SubSecTimeDigitized (should not be written according to Exif4XMP 2.32 specification)
    # SerialNumber (should be BodySerialNumber)
    # Lens (should be XMP-aux)
    # LensInfo (should be XMP-aux)
);

# Exif extended properties (exifEX, ref 12)
%Image::ExifTool::XMP::exifEX = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-exifEX', 2 => 'Image' },
    NAMESPACE   => 'exifEX',
    PRIORITY => 0, # not as reliable as actual EXIF tags
    NOTES => q{
        EXIF tags added by the EXIF 2.32 for XMP specification (see
        L<https://cipa.jp/std/documents/download_e.html?DC-010-2020_E>).
    },
    Gamma                       => { Writable => 'rational' },
    PhotographicSensitivity     => { Writable => 'integer' },
    SensitivityType => {
        Writable => 'integer',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Standard Output Sensitivity',
            2 => 'Recommended Exposure Index',
            3 => 'ISO Speed',
            4 => 'Standard Output Sensitivity and Recommended Exposure Index',
            5 => 'Standard Output Sensitivity and ISO Speed',
            6 => 'Recommended Exposure Index and ISO Speed',
            7 => 'Standard Output Sensitivity, Recommended Exposure Index and ISO Speed',
        },
    },
    StandardOutputSensitivity   => { Writable => 'integer' },
    RecommendedExposureIndex    => { Writable => 'integer' },
    ISOSpeed                    => { Writable => 'integer' },
    ISOSpeedLatitudeyyy => {
        Description => 'ISO Speed Latitude yyy',
        Writable => 'integer',
    },
    ISOSpeedLatitudezzz => {
        Description => 'ISO Speed Latitude zzz',
        Writable => 'integer',
    },
    CameraOwnerName     => { Name => 'OwnerName' },
    BodySerialNumber    => { Name => 'SerialNumber', Groups => { 2 => 'Camera' } },
    LensSpecification => {
        Name => 'LensInfo',
        Writable => 'rational',
        Groups => { 2 => 'Camera' },
        List => 'Seq',
        RawJoin => 1, # join list into a string before ValueConv
        ValueConv => \&ConvertRationalList,
        ValueConvInv => sub {
            my $val = shift;
            my @vals = split ' ', $val;
            return $val unless @vals == 4;
            foreach (@vals) {
                $_ eq 'inf' and $_ = '1/0', next;
                $_ eq 'undef' and $_ = '0/0', next;
                Image::ExifTool::IsFloat($_) or return $val;
                my @a = Image::ExifTool::Rationalize($_);
                $_ = join '/', @a;
            }
            return \@vals; # return list reference (List-type tag)
        },
        PrintConv => \&Image::ExifTool::Exif::PrintLensInfo,
        PrintConvInv => \&Image::ExifTool::Exif::ConvertLensInfo,
        Notes => q{
            unfortunately the EXIF 2.3 for XMP specification defined this new tag
            instead of using the existing XMP-aux:LensInfo
        },
    },
    LensMake            => { Groups => { 2 => 'Camera' } },
    LensModel           => { Groups => { 2 => 'Camera' } },
    LensSerialNumber    => { Groups => { 2 => 'Camera' } },
    InteroperabilityIndex => {
        Name => 'InteropIndex',
        Description => 'Interoperability Index',
        PrintConv => {
            R98 => 'R98 - DCF basic file (sRGB)',
            R03 => 'R03 - DCF option file (Adobe RGB)',
            THM => 'THM - DCF thumbnail file',
        },
    },
    # new in Exif 2.31
    Temperature         => { Writable => 'rational', Name => 'AmbientTemperature' },
    Humidity            => { Writable => 'rational' },
    Pressure            => { Writable => 'rational' },
    WaterDepth          => { Writable => 'rational' },
    Acceleration        => { Writable => 'rational' },
    CameraElevationAngle=> { Writable => 'rational' },
    # new in Exif 2.32 (according to the spec, these should use a different namespace
    # URI, but the same namespace prefix... Exactly how is that supposed to work?!!
    # -- I'll just stick with the same URI)
    CompositeImage => { Writable => 'integer',
        PrintConv => {
            0 => 'Unknown',
            1 => 'Not a Composite Image',
            2 => 'General Composite Image',
            3 => 'Composite Image Captured While Shooting',
        },
    },
    CompositeImageCount => { List => 'Seq', Writable => 'integer' },
    CompositeImageExposureTimes => {
        FlatName => 'CompImage',
        Struct => {
            STRUCT_NAME => 'CompImageExp',
            NAMESPACE => 'exifEX',
            TotalExposurePeriod     => { Writable => 'rational' },
            SumOfExposureTimesOfAll => { Writable => 'rational', FlatName => 'SumExposureAll' },
            SumOfExposureTimesOfUsed=> { Writable => 'rational', FlatName => 'SumExposureUsed' },
            MaxExposureTimesOfAll   => { Writable => 'rational', FlatName => 'MaxExposureAll' },
            MaxExposureTimesOfUsed  => { Writable => 'rational', FlatName => 'MaxExposureUsed' },
            MinExposureTimesOfAll   => { Writable => 'rational', FlatName => 'MinExposureAll'  },
            MinExposureTimesOfUsed  => { Writable => 'rational', FlatName => 'MinExposureUsed' },
            NumberOfSequences       => { Writable => 'integer',  FlatName => 'NumSequences' },
            NumberOfImagesInSequences=>{ Writable => 'integer',  FlatName => 'ImagesPerSequence' },
            Values =>   { List => 'Seq', Writable => 'rational' },
        },
    },
    # new in Exif 3.0
    ImageUniqueID   => { },
    ImageTitle      => { },
    ImageEditor     => { },
    Photographer    => { Groups => { 2 => 'Author' } },
    CameraFirmware  => { Groups => { 2 => 'Camera' } },
    RAWDevelopingSoftware   => { },
    ImageEditingSoftware    => { },
    MetadataEditingSoftware => { },
);

# Auxiliary namespace properties (aux) - not fully documented (ref PH)
%Image::ExifTool::XMP::aux = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-aux', 2 => 'Camera' },
    NAMESPACE   => 'aux',
    NOTES => q{
        Adobe-defined auxiliary EXIF tags.  This namespace existed in the XMP
        specification until it was dropped in 2012, presumably due to the
        introduction of the EXIF 2.3 for XMP specification and the exifEX namespace
        at this time.  For this reason, tags below with equivalents in the
        L<exifEX namespace|/XMP exifEX Tags> are avoided when writing.
    },
    Firmware        => { }, #7
    FlashCompensation => { Writable => 'rational' }, #7
    ImageNumber     => { }, #7
    LensInfo        => { #7
        Notes => '4 rational values giving focal and aperture ranges',
        Avoid => 1,
        # convert to floating point values (or 'inf' or 'undef')
        ValueConv => \&ConvertRationalList,
        ValueConvInv => sub {
            my $val = shift;
            my @vals = split ' ', $val;
            return $val unless @vals == 4;
            foreach (@vals) {
                $_ eq 'inf' and $_ = '1/0', next;
                $_ eq 'undef' and $_ = '0/0', next;
                Image::ExifTool::IsFloat($_) or return $val;
                my @a = Image::ExifTool::Rationalize($_);
                $_ = join '/', @a;
            }
            return join ' ', @vals; # return string (string tag)
        },
        # convert to the form "12-20mm f/3.8-4.5" or "50mm f/1.4"
        PrintConv => \&Image::ExifTool::Exif::PrintLensInfo,
        PrintConvInv => \&Image::ExifTool::Exif::ConvertLensInfo,
    },
    Lens            => { },
    OwnerName       => { Avoid => 1 }, #7
    SerialNumber    => { Avoid => 1 },
    LensSerialNumber=> { Avoid => 1 },
    LensID          => {
        Priority => 0,
        # prevent this from getting set from a LensID that has been converted
        ValueConvInv => q{
            warn "Expected one or more integer values" if $val =~ /[^-\d ]/;
            return $val;
        },
    },
    ApproximateFocusDistance => {
        Writable => 'rational',
        PrintConv => {
            4294967295 => 'infinity',
            OTHER => sub {
                my ($val, $inv) = @_;
                return $val eq 'infinity' ? 4294967295 : $val if $inv;
                return $val eq 4294967295 ? 'infinity' : $val;
            },
        },
    }, #PH (LR3)
    # the following new in LR6 (ref forum6497)
    IsMergedPanorama         => { Writable => 'boolean' },
    IsMergedHDR              => { Writable => 'boolean' },
    DistortionCorrectionAlreadyApplied  => { Writable => 'boolean' },
    VignetteCorrectionAlreadyApplied    => { Writable => 'boolean' },
    LateralChromaticAberrationCorrectionAlreadyApplied => { Writable => 'boolean' },
    LensDistortInfo => { }, # (LR 7.5.1, 4 signed rational values)
    NeutralDensityFactor => { }, # (LR 11.0 - rational value, but denominator seems significant)
    # the following are ref forum13747
    EnhanceDetailsAlreadyApplied    => { Writable => 'boolean' },
    EnhanceDetailsVersion           => { }, # integer?
    EnhanceSuperResolutionAlreadyApplied => { Writable => 'boolean' },
    EnhanceSuperResolutionVersion   => { }, # integer?
    EnhanceSuperResolutionScale     => { Writable => 'rational' },
    EnhanceDenoiseAlreadyApplied    => { Writable => 'boolean' }, #forum14760
    EnhanceDenoiseVersion           => { }, #forum14760 integer?
    EnhanceDenoiseLumaAmount        => { }, #forum14760 integer?
    # FujiRatingAlreadyApplied - boolean written by LR classic 13.2 (forum15815)
);

# IPTC Core namespace properties (Iptc4xmpCore) (ref 4)
%Image::ExifTool::XMP::iptcCore = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-iptcCore', 2 => 'Author' },
    NAMESPACE   => 'Iptc4xmpCore',
    TABLE_DESC => 'XMP IPTC Core',
    NOTES => q{
        IPTC Core namespace tags.  The actual IPTC Core namespace prefix is
        "Iptc4xmpCore", which is the prefix recorded in the file, but ExifTool
        shortens this for the family 1 group name. (see
        L<http://www.iptc.org/IPTC4XMP/>)
    },
    CountryCode         => { Groups => { 2 => 'Location' } },
    CreatorContactInfo => {
        Struct => {
            STRUCT_NAME => 'ContactInfo',
            NAMESPACE   => 'Iptc4xmpCore',
            CiAdrCity   => { },
            CiAdrCtry   => { },
            CiAdrExtadr => { },
            CiAdrPcode  => { },
            CiAdrRegion => { },
            CiEmailWork => { },
            CiTelWork   => { },
            CiUrlWork   => { },
        },
    },
    CreatorContactInfoCiAdrCity   => { Flat => 1, Name => 'CreatorCity' },
    CreatorContactInfoCiAdrCtry   => { Flat => 1, Name => 'CreatorCountry' },
    CreatorContactInfoCiAdrExtadr => { Flat => 1, Name => 'CreatorAddress' },
    CreatorContactInfoCiAdrPcode  => { Flat => 1, Name => 'CreatorPostalCode' },
    CreatorContactInfoCiAdrRegion => { Flat => 1, Name => 'CreatorRegion' },
    CreatorContactInfoCiEmailWork => { Flat => 1, Name => 'CreatorWorkEmail' },
    CreatorContactInfoCiTelWork   => { Flat => 1, Name => 'CreatorWorkTelephone' },
    CreatorContactInfoCiUrlWork   => { Flat => 1, Name => 'CreatorWorkURL' },
    IntellectualGenre   => { Groups => { 2 => 'Other' } },
    Location            => { Groups => { 2 => 'Location' } },
    Scene               => { Groups => { 2 => 'Other' }, List => 'Bag' },
    SubjectCode         => { Groups => { 2 => 'Other' }, List => 'Bag' },
    # Copyright - have seen this in a sample (Jan 2021), but I think it is non-standard
    # new IPTC Core 1.3 properties
    AltTextAccessibility  => { Groups => { 2 => 'Other' }, Writable => 'lang-alt' },
    ExtDescrAccessibility => { Groups => { 2 => 'Other' }, Writable => 'lang-alt' },
);

# Adobe Lightroom namespace properties (lr) (ref PH)
%Image::ExifTool::XMP::Lightroom = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-lr', 2 => 'Image' },
    NAMESPACE   => 'lr',
    TABLE_DESC => 'XMP Adobe Lightroom',
    NOTES => 'Adobe Lightroom "lr" namespace tags.',
    privateRTKInfo => { },
    hierarchicalSubject => { List => 'Bag' },
    weightedFlatSubject => { List => 'Bag' },
);

# Adobe Album namespace properties (album) (ref PH)
%Image::ExifTool::XMP::Album = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-album', 2 => 'Image' },
    NAMESPACE   => 'album',
    TABLE_DESC => 'XMP Adobe Album',
    NOTES => 'Adobe Album namespace tags.',
    Notes => { },
);

# ExifTool namespace properties (et)
%Image::ExifTool::XMP::ExifTool = (
    %xmpTableDefaults,
    GROUPS => { 1 => 'XMP-et', 2 => 'Image' },
    NAMESPACE   => 'et',
    OriginalImageHash     => { Notes => 'used to store ExifTool ImageDataHash digest' },
    OriginalImageHashType => { Notes => "ImageHashType API setting, default 'MD5'" },
    OriginalImageMD5      => { Notes => 'deprecated' },
);

# table to add tags in other namespaces
%Image::ExifTool::XMP::other = (
    GROUPS => { 2 => 'Unknown' },
    LANG_INFO => \&GetLangInfo,
);

# Composite XMP tags
%Image::ExifTool::XMP::Composite = (
    # get latitude/longitude reference from XMP lat/long tags
    # (used to set EXIF GPS position from XMP tags)
    GPSLatitudeRef => {
        Require => 'XMP-exif:GPSLatitude',
        Groups => { 2 => 'Location' },
        # Note: Do not Inihibit based on EXIF:GPSLatitudeRef (see forum10192)
        ValueConv => q{
            IsFloat($val[0]) and return $val[0] < 0 ? "S" : "N";
            $val[0] =~ /^.*([NS])/;
            return $1;
        },
        PrintConv => { N => 'North', S => 'South' },
    },
    GPSLongitudeRef => {
        Require => 'XMP-exif:GPSLongitude',
        Groups => { 2 => 'Location' },
        ValueConv => q{
            IsFloat($val[0]) and return $val[0] < 0 ? "W" : "E";
            $val[0] =~ /^.*([EW])/;
            return $1;
        },
        PrintConv => { E => 'East', W => 'West' },
    },
    GPSDestLatitudeRef => {
        Require => 'XMP-exif:GPSDestLatitude',
        Groups => { 2 => 'Location' },
        ValueConv => q{
            IsFloat($val[0]) and return $val[0] < 0 ? "S" : "N";
            $val[0] =~ /^.*([NS])/;
            return $1;
        },
        PrintConv => { N => 'North', S => 'South' },
    },
    GPSDestLongitudeRef => {
        Require => 'XMP-exif:GPSDestLongitude',
        Groups => { 2 => 'Location' },
        ValueConv => q{
            IsFloat($val[0]) and return $val[0] < 0 ? "W" : "E";
            $val[0] =~ /^.*([EW])/;
            return $1;
        },
        PrintConv => { E => 'East', W => 'West' },
    },
    LensID => {
        Notes => 'attempt to convert numerical XMP-aux:LensID stored by Adobe applications',
        Require => {
            0 => 'XMP-aux:LensID',
            1 => 'Make',
        },
        Desire => {
            2 => 'LensInfo',
            3 => 'FocalLength',
            4 => 'LensModel',
            5 => 'MaxApertureValue',
        },
        Inhibit => {
            6 => 'Composite:LensID',    # don't override existing Composite:LensID
        },
        Groups => { 2 => 'Camera' },
        ValueConv => '$val',
        PrintConv => 'Image::ExifTool::XMP::PrintLensID($self, @val)',
    },
    Flash => {
        Notes => 'facilitates copying camera flash information between XMP and EXIF',
        Desire => {
            0 => 'XMP:FlashFired',
            1 => 'XMP:FlashReturn',
            2 => 'XMP:FlashMode',
            3 => 'XMP:FlashFunction',
            4 => 'XMP:FlashRedEyeMode',
            5 => 'XMP:Flash', # handle structured flash information too
        },
        Groups => { 2 => 'Camera' },
        Writable => 1,
        PrintHex => 1,
        SeparateTable => 'EXIF Flash',
        ValueConv => q{
            if (ref $val[5] eq 'HASH') {
                # copy structure fields into value array
                my $i = 0;
                $val[$i++] = $val[5]{$_} foreach qw(Fired Return Mode Function RedEyeMode);
            }
            return((($val[0] and lc($val[0]) eq 'true') ? 0x01 : 0) |
                   (($val[1] || 0) << 1) |
                   (($val[2] || 0) << 3) |
                   (($val[3] and lc($val[3]) eq 'true') ? 0x20 : 0) |
                   (($val[4] and lc($val[4]) eq 'true') ? 0x40 : 0));
        },
        PrintConv => \%Image::ExifTool::Exif::flash,
        WriteAlso => {
            'XMP:FlashFired'      => '$val & 0x01 ? "True" : "False"',
            'XMP:FlashReturn'     => '($val & 0x06) >> 1',
            'XMP:FlashMode'       => '($val & 0x18) >> 3',
            'XMP:FlashFunction'   => '$val & 0x20 ? "True" : "False"',
            'XMP:FlashRedEyeMode' => '$val & 0x40 ? "True" : "False"',
        },
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::XMP');

#------------------------------------------------------------------------------
# AutoLoad our writer routines when necessary
#
sub AUTOLOAD
{
    return Image::ExifTool::DoAutoLoad($AUTOLOAD, @_);
}

#------------------------------------------------------------------------------
# Escape necessary XML characters in UTF-8 string
# Inputs: 0) string to be escaped
# Returns: escaped string
my %charName = ('"'=>'quot', '&'=>'amp', "'"=>'#39', '<'=>'lt', '>'=>'gt');
sub EscapeXML($)
{
    my $str = shift;
    $str =~ s/([&><'"])/&$charName{$1};/sg; # escape necessary XML characters
    return $str;
}

#------------------------------------------------------------------------------
# Unescape XML character references (entities and numerical)
# Inputs: 0) string to be unescaped
#         1) optional hash reference to convert entity names to numbers
#         2) optional character encoding
# Returns: unescaped string
my %charNum = ('quot'=>34, 'amp'=>38, 'apos'=>39, 'lt'=>60, 'gt'=>62);
sub UnescapeXML($;$$)
{
    my ($str, $conv, $enc) = @_;
    $conv = \%charNum unless $conv;
    $str =~ s/&(#?\w+);/UnescapeChar($1,$conv,$enc)/sge;
    return $str;
}

#------------------------------------------------------------------------------
# Escape string for XML, ensuring valid XML and UTF-8
# Inputs: 0) string
# Returns: escaped string
sub FullEscapeXML($)
{
    my $str = shift;
    $str =~ s/([&><'"])/&$charName{$1};/sg; # escape necessary XML characters
    $str =~ s/\\/&#92;/sg;                  # escape backslashes too
    # then use C-escape sequences for invalid characters
    if ($str =~ /[\0-\x1f]/ or Image::ExifTool::IsUTF8(\$str) < 0) {
        $str =~ s/([\0-\x1f\x7f-\xff])/sprintf("\\x%.2x",ord $1)/sge;
    }
    return $str;
}

#------------------------------------------------------------------------------
# Unescape XML/C escaped string
# Inputs: 0) string
# Returns: unescaped string
sub FullUnescapeXML($)
{
    my $str = shift;
    # unescape C escape sequences first
    $str =~ s/\\x([\da-f]{2})/chr(hex($1))/sge;
    my $conv = \%charNum;
    $str =~ s/&(#?\w+);/UnescapeChar($1,$conv)/sge;
    return $str;
}

#------------------------------------------------------------------------------
# Convert XML character reference to UTF-8
# Inputs: 0) XML character reference stripped of the '&' and ';' (eg. 'quot', '#34', '#x22')
#         1) hash reference for looking up character numbers by name
#         2) optional character encoding (default 'UTF8')
# Returns: UTF-8 equivalent (or original character on conversion error)
sub UnescapeChar($$;$)
{
    my ($ch, $conv, $enc) = @_;
    my $val = $$conv{$ch};
    unless (defined $val) {
        if ($ch =~ /^#x([0-9a-fA-F]+)$/) {
            $val = hex($1);
        } elsif ($ch =~ /^#(\d+)$/) {
            $val = $1;
        } else {
            return "&$ch;"; # should issue a warning here? [no]
        }
    }
    return chr($val) if $val < 0x80;   # simple ASCII
    $val = $] >= 5.006001 ? pack('C0U', $val) : Image::ExifTool::PackUTF8($val);
    $val = Image::ExifTool::Decode(undef, $val, 'UTF8', undef, $enc) if $enc and $enc ne 'UTF8';
    return $val;
}

#------------------------------------------------------------------------------
# Fix malformed UTF8 (by replacing bad bytes with specified character)
# Inputs: 0) string reference, 1) string to replace each bad byte,
#         may be '' to delete bad bytes, or undef to use '?'
# Returns: true if string was fixed, and updates string
sub FixUTF8($;$)
{
    my ($strPt, $bad) = @_;
    my $fixed;
    pos($$strPt) = 0; # start at beginning of string
    for (;;) {
        last unless $$strPt =~ /([\x80-\xff])/g;
        my $ch = ord($1);
        my $pos = pos($$strPt);
        # (see comments in Image::ExifTool::IsUTF8())
        if ($ch >= 0xc2 and $ch < 0xf8) {
            my $n = $ch < 0xe0 ? 1 : ($ch < 0xf0 ? 2 : 3);
            if ($$strPt =~ /\G([\x80-\xbf]{$n})/g) {
                next if $n == 1;
                if ($n == 2) {
                    next unless ($ch == 0xe0 and (ord($1) & 0xe0) == 0x80) or
                                ($ch == 0xed and (ord($1) & 0xe0) == 0xa0) or
                                ($ch == 0xef and ord($1) == 0xbf and
                                    (ord(substr $1, 1) & 0xfe) == 0xbe);
                } else {
                    next unless ($ch == 0xf0 and (ord($1) & 0xf0) == 0x80) or
                                ($ch == 0xf4 and ord($1) > 0x8f) or $ch > 0xf4;
                }
            }
        }
        # replace bad character
        $bad = '?' unless defined $bad;
        substr($$strPt, $pos-1, 1) = $bad;
        pos($$strPt) = $pos-1 + length $bad;
        $fixed = 1;
    }
    return $fixed;
}

#------------------------------------------------------------------------------
# Utility routine to decode a base64 string
# Inputs: 0) base64 string
# Returns: reference to decoded data
sub DecodeBase64($)
{
    local($^W) = 0; # unpack('u',...) gives bogus warning in 5.00[123]
    my $str = shift;

    # truncate at first unrecognized character (base 64 data
    # may only contain A-Z, a-z, 0-9, +, /, =, or white space)
    $str =~ s/[^A-Za-z0-9+\/= \t\n\r\f].*//s;
    # translate to uucoded and remove padding and white space
    $str =~ tr/A-Za-z0-9+\/= \t\n\r\f/ -_/d;

    # convert the data to binary in chunks
    my $chunkSize = 60;
    my $uuLen = pack('c', 32 + $chunkSize * 3 / 4); # calculate length byte
    my $dat = '';
    my ($i, $substr);
    # loop through the whole chunks
    my $len = length($str) - $chunkSize;
    for ($i=0; $i<=$len; $i+=$chunkSize) {
        $substr = substr($str, $i, $chunkSize);     # get a chunk of the data
        $dat .= unpack('u', $uuLen . $substr);      # decode it
    }
    $len += $chunkSize;
    # handle last partial chunk if necessary
    if ($i < $len) {
        $uuLen = pack('c', 32 + ($len-$i) * 3 / 4); # recalculate length
        $substr = substr($str, $i, $len-$i);        # get the last partial chunk
        $dat .= unpack('u', $uuLen . $substr);      # decode it
    }
    return \$dat;
}

#------------------------------------------------------------------------------
# Generate a tag ID for this XMP tag
# Inputs: 0) tag property name list ref, 1) array ref for receiving structure property list
#         2) array for receiving namespace list
# Returns: tagID and outtermost interesting namespace (or '' if no namespace)
sub GetXMPTagID($;$$)
{
    my ($props, $structProps, $nsList) = @_;
    my ($tag, $prop, $namespace);
    foreach $prop (@$props) {
        # split name into namespace and property name
        # (Note: namespace can be '' for property qualifiers)
        my ($ns, $nm) = ($prop =~ /(.*?):(.*)/) ? ($1, $2) : ('', $prop);
        if ($ignoreNamespace{$ns} or $ignoreProp{$prop} or $ignoreEtProp{$prop}) {
            # special case: don't ignore rdf numbered items
            # (not technically allowed in XMP, but used in RDF/XML)
            unless ($prop =~ /^rdf:(_\d+)$/) {
                # save list index if necessary for structures
                if ($structProps and @$structProps and $prop =~ /^rdf:li (\d+)$/) {
                    push @{$$structProps[-1]}, $1;
                }
                next;
            }
            $tag .= $1 if defined $tag;
        } else {
            $nm =~ s/ .*//; # remove nodeID if it exists
            # all uppercase is ugly, so convert it
            if ($nm !~ /[a-z]/) {
                my $xlat = $stdXlatNS{$ns} || $ns;
                my $info = $Image::ExifTool::XMP::Main{$xlat};
                my $table;
                if (ref $info eq 'HASH' and $$info{SubDirectory}) {
                    $table = GetTagTable($$info{SubDirectory}{TagTable});
                }
                unless ($table and $$table{$nm}) {
                    $nm = lc($nm);
                    $nm =~ s/_([a-z])/\u$1/g;
                }
            }
            if (defined $tag) {
                $tag .= ucfirst($nm);       # add to tag name
            } else {
                $tag = $nm;
            }
            # save structure information if necessary
            if ($structProps) {
                push @$structProps, [ $nm ];
                push @$nsList, $ns if $nsList;
            }
        }
        # save namespace of first property to contribute to tag name
        $namespace = $ns unless $namespace;
    }
    if (wantarray) {
        return ($tag, $namespace || '');
    } else {
        return $tag;
    }
}

#------------------------------------------------------------------------------
# Register namespace for specified user-defined table
# Inputs: 0) tag/structure table ref
# Returns: namespace prefix
sub RegisterNamespace($)
{
    my $table = shift;
    return $$table{NAMESPACE} unless ref $$table{NAMESPACE};
    my $nsRef = $$table{NAMESPACE};
    # recognize as either a list or hash
    my $ns;
    if (ref $nsRef eq 'ARRAY') {
        $ns = $$nsRef[0];
        $nsURI{$ns} = $$nsRef[1];
        $uri2ns{$$nsRef[1]} = $ns;
    } else { # must be a hash
        my @ns = sort keys %$nsRef; # allow multiple namespace definitions
        while (@ns) {
            $ns = pop @ns;
            if ($nsURI{$ns} and $nsURI{$ns} ne $$nsRef{$ns}) {
                warn "User-defined namespace prefix '${ns}' conflicts with existing namespace\n";
            }
            $nsURI{$ns} = $$nsRef{$ns};
            $uri2ns{$$nsRef{$ns}} = $ns;
        }
    }
    return $$table{NAMESPACE} = $ns;
}

#------------------------------------------------------------------------------
# Generate flattened tags and add to table
# Inputs: 0) tag table ref, 1) tag ID for Struct tag (if not defined, whole table is done),
#         2) flag to not expand sub-structures
# Returns: number of tags added (not counting those just initialized)
# Notes: Must have verified that $$tagTablePtr{$tagID}{Struct} exists before calling this routine
# - makes sure that the tagInfo Struct is a HASH reference
sub AddFlattenedTags($;$$)
{
    local $_;
    my ($tagTablePtr, $tagID, $noSubStruct) = @_;
    my $count = 0;
    my @tagIDs;

    if (defined $tagID) {
        push @tagIDs, $tagID;
    } else {
        foreach $tagID (TagTableKeys($tagTablePtr)) {
            my $tagInfo = $$tagTablePtr{$tagID};
            next unless ref $tagInfo eq 'HASH' and $$tagInfo{Struct};
            push @tagIDs, $tagID;
        }
    }

    # loop through specified tags
    foreach $tagID (@tagIDs) {

        my $tagInfo = $$tagTablePtr{$tagID};

        $$tagInfo{Flattened} and next;  # only generate flattened tags once
        $$tagInfo{Flattened} = 1;

        my $strTable = $$tagInfo{Struct};
        unless (ref $strTable) { # (allow a structure name for backward compatibility only)
            my $strName = $strTable;
            $strTable = $Image::ExifTool::UserDefined::xmpStruct{$strTable} or next;
            $$strTable{STRUCT_NAME} or $$strTable{STRUCT_NAME} = "XMP $strName";
            $$tagInfo{Struct} = $strTable;  # replace old-style name with HASH ref
            delete $$tagInfo{SubDirectory}; # deprecated use of SubDirectory in Struct tags
        }

        # get prefix for flattened tag names
        my $flat = (defined $$tagInfo{FlatName} ? $$tagInfo{FlatName} : $$tagInfo{Name});

        # get family 2 group name for this structure tag
        my ($tagG2, $field);
        $tagG2 = $$tagInfo{Groups}{2} if $$tagInfo{Groups};
        $tagG2 or $tagG2 = $$tagTablePtr{GROUPS}{2};

        foreach $field (keys %$strTable) {
            next if $specialStruct{$field};
            my $fieldInfo = $$strTable{$field};
            next if $$fieldInfo{LangCode};  # don't flatten lang-alt tags
            next if $$fieldInfo{Struct} and $noSubStruct;   # don't expand sub-structures if specified
            # build a tag ID for the corresponding flattened tag
            my $fieldName = ucfirst($field);
            my $flatField = $$fieldInfo{FlatName} || $fieldName;
            my $flatID = $tagID . $fieldName;
            my $flatInfo = $$tagTablePtr{$flatID};
            if ($flatInfo) {
                ref $flatInfo eq 'HASH' or warn("$flatInfo is not a HASH!\n"), next; # (to be safe)
                # pre-defined flattened tags should have Flat flag set
                if (not defined $$flatInfo{Flat}) {
                    next if $$flatInfo{NotFlat};
                    warn "Missing Flat flag for $$flatInfo{Name}\n" if $Image::ExifTool::debug;
                }
                $$flatInfo{Flat} = 0;
                # copy all missing entries from field information
                foreach (keys %$fieldInfo) {
                    # must not copy PropertyPath (but can't delete it afterwards
                    # because the flat tag may already have this set)
                    next if $_ eq 'PropertyPath' or defined $$flatInfo{$_};
                    # copy the property (making a copy of the Groups hash)
                    $$flatInfo{$_} = $_ eq 'Groups' ? { %{$$fieldInfo{$_}} } : $$fieldInfo{$_};
                }
                # (NOTE: Can NOT delete Groups because we need them if GotGroups was done)
                # re-generate List flag unless it is set to 0
                delete $$flatInfo{List} if $$flatInfo{List};
            } else {
                # generate new flattened tag information based on structure field
                my $flatName = $flat . $flatField;
                $flatInfo = { %$fieldInfo, Name => $flatName, Flat => 0 };
                $$flatInfo{FlatName} = $flatName if $$fieldInfo{FlatName};
                # make a copy of the Groups hash if necessary
                $$flatInfo{Groups} = { %{$$fieldInfo{Groups}} } if $$fieldInfo{Groups};
                # add new flattened tag to table
                AddTagToTable($tagTablePtr, $flatID, $flatInfo);
                ++$count;
            }
            # propagate List flag (unless set to 0 in pre-defined flattened tag)
            unless (defined $$flatInfo{List}) {
                $$flatInfo{List} = $$fieldInfo{List} || 1 if $$fieldInfo{List} or $$tagInfo{List};
            }
            # set group 2 name from the first existing family 2 group in the:
            # 1) structure field Groups, 2) structure table GROUPS, 3) structure tag Groups
            if ($$fieldInfo{Groups} and $$fieldInfo{Groups}{2}) {
                $$flatInfo{Groups}{2} = $$fieldInfo{Groups}{2};
            } elsif ($$strTable{GROUPS} and $$strTable{GROUPS}{2}) {
                $$flatInfo{Groups}{2} = $$strTable{GROUPS}{2};
            } else {
                $$flatInfo{Groups}{2} = $tagG2;
            }
            # save reference to top-level and parent structures
            $$flatInfo{RootTagInfo} = $$tagInfo{RootTagInfo} || $tagInfo;
            $$flatInfo{ParentTagInfo} = $tagInfo;
            # recursively generate flattened tags for sub-structures
            next unless $$flatInfo{Struct};
            length($flatID) > 250 and warn("Possible deep recursion for tag $flatID\n"), last;
            # reset flattened tag just in case we flattened hierarchy in the wrong order
            # because we must start from the outtermost structure to get the List flags right
            # (this should only happen when building tag tables)
            delete $$flatInfo{Flattened};
            $count += AddFlattenedTags($tagTablePtr, $flatID, $$flatInfo{NoSubStruct});
        }
    }
    return $count;
}

#------------------------------------------------------------------------------
# Get localized version of tagInfo hash
# Inputs: 0) tagInfo hash ref, 1) language code (eg. "x-default")
# Returns: new tagInfo hash ref, or undef if invalid
sub GetLangInfo($$)
{
    my ($tagInfo, $langCode) = @_;
    # only allow alternate language tags in lang-alt lists
    return undef unless $$tagInfo{Writable} and $$tagInfo{Writable} eq 'lang-alt';
    $langCode =~ tr/_/-/;   # RFC 3066 specifies '-' as a separator
    my $langInfo = Image::ExifTool::GetLangInfo($tagInfo, $langCode);
    return $langInfo;
}

#------------------------------------------------------------------------------
# Get standard case for language code
# Inputs: 0) Language code
# Returns: Language code in standard case
sub StandardLangCase($)
{
    my $lang = shift;
    # make 2nd subtag uppercase only if it is 2 letters
    return lc($1) . uc($2) . lc($3) if $lang =~ /^([a-z]{2,3}|[xi])(-[a-z]{2})\b(.*)/i;
    return lc($lang);
}

#------------------------------------------------------------------------------
# Scan for XMP in a file
# Inputs: 0) ExifTool object ref, 1) RAF reference
# Returns: 1 if xmp was found, 0 otherwise
# Notes: Currently only recognizes UTF8-encoded XMP
sub ScanForXMP($$)
{
    my ($et, $raf) = @_;
    my ($buff, $xmp);
    my $lastBuff = '';

    $et->VPrint(0,"Scanning for XMP\n");
    for (;;) {
        defined $buff or $raf->Read($buff, 65536) or return 0;
        unless (defined $xmp) {
            $lastBuff .= $buff;
            unless ($lastBuff =~ /(<\?xpacket begin=)/g) {
                # must keep last 15 bytes to match 16-byte "xpacket begin" string
                $lastBuff = length($buff) <= 15 ? $buff : substr($buff, -15);
                undef $buff;
                next;
            }
            $xmp = $1;
            $buff = substr($lastBuff, pos($lastBuff));
        }
        my $pos = length($xmp) - 18;    # (18 = length("<?xpacket end...") - 1)
        $xmp .= $buff;                  # add new data to our XMP
        pos($xmp) = $pos if $pos > 0;   # set start for "xpacket end" scan
        if ($xmp =~ /<\?xpacket end=['"][wr]['"]\?>/g) {
            $buff = substr($xmp, pos($xmp));    # save data after end of XMP
            $xmp = substr($xmp, 0, pos($xmp));  # isolate XMP
            # check XMP for validity (not valid if it contains null bytes)
            $pos = rindex($xmp, "\0") + 1 or last;
            $lastBuff = substr($xmp, $pos);     # re-parse beginning after last null byte
            undef $xmp;
        } else {
            undef $buff;
        }
    }
    unless ($$et{FileType}) {
        $$et{FILE_TYPE} = $$et{FILE_EXT};
        $et->SetFileType('<unknown file containing XMP>', undef, '');
    }
    my %dirInfo = (
        DataPt  => \$xmp,
        DirLen  => length $xmp,
        DataLen => length $xmp,
    );
    ProcessXMP($et, \%dirInfo);
    return 1;
}

#------------------------------------------------------------------------------
# Print conversion for XMP-aux:LensID
# Inputs: 0) ExifTool ref, 1) LensID, 2) Make, 3) LensInfo, 4) FocalLength,
#         5) LensModel, 6) MaxApertureValue
# (yes, this is ugly -- blame Adobe)
sub PrintLensID(@)
{
    local $_;
    my ($et, $id, $make, $info, $focalLength, $lensModel, $maxAv) = @_;
    my ($mk, $printConv);
    my %alt = ( Pentax => 'Ricoh' );    # Pentax changed its name to Ricoh
    # missing: Olympus (no XMP:LensID written by Adobe)
    foreach $mk (qw(Canon Nikon Pentax Sony Sigma Samsung Leica)) {
        next unless $make =~ /$mk/i or ($alt{$mk} and $make =~ /$alt{$mk}/i);
        # get name of module containing the lens lookup (default "Make.pm")
        my $mod = { Sigma => 'SigmaRaw', Leica => 'Panasonic' }->{$mk} || $mk;
        require "Image/ExifTool/$mod.pm";
        # get the name of the lens name lookup (default "makeLensTypes")
        # (canonLensTypes, pentaxLensTypes, nikonLensIDs, etc)
        my $convName = "Image::ExifTool::${mod}::" .
            ({ Nikon => 'nikonLensIDs' }->{$mk} || lc($mk) . 'LensTypes');
        no strict 'refs';
        %$convName or last;
        my $printConv = \%$convName;
        use strict 'refs';
        # sf = short focal
        # lf = long focal
        # sa = max aperture at short focal
        # la = max aperture at long focal
        my ($sf, $lf, $sa, $la);
        if ($info) {
            my @a = split ' ', $info;
            $_ eq 'undef' and $_ = undef foreach @a;
            ($sf, $lf, $sa, $la) = @a;
            # for Sony and ambiguous LensID, $info data may be incorrect:
            # use only if it agrees with $focalLength and $maxAv (ref JR)
            if ($mk eq 'Sony' and
                (($focalLength and (($sf and $focalLength < $sf - 0.5) or
                                    ($lf and $focalLength > $lf + 0.5))) or
                 ($maxAv and (($sa and $maxAv < $sa - 0.15) or
                              ($la and $maxAv > $la + 0.15)))))
            {
                undef $sf;
                undef $lf;
                undef $sa;
                undef $la;
            } elsif ($maxAv) {
                # (using the short-focal-length max aperture in place of MaxAperture
                # is a bad approximation, so don't do this if MaxApertureValue exists)
                undef $sa;
            }
        }
        if ($mk eq 'Pentax' and $id =~ /^\d+$/) {
            # for Pentax, CS4 stores an int16u, but we use 2 x int8u
            $id = join(' ', unpack('C*', pack('n', $id)));
        }
        # Nikon is a special case because Adobe doesn't store the full LensID
        # (Apple Photos does, but we have to convert back to hex)
        if ($mk eq 'Nikon') {
            $id = sprintf('%X', $id);
            $id = "0$id" if length($id) & 0x01;     # pad with leading 0 if necessary
            $id =~ s/(..)/$1 /g and $id =~ s/ $//;  # put spaces between bytes
            my (%newConv, %used);
            my $i = 0;
            foreach (grep /^$id/, keys %$printConv) {
                my $lens = $$printConv{$_};
                next if $used{$lens}; # avoid duplicates
                $used{$lens} = 1;
                $newConv{$i ? "$id.$i" : $id} = $lens;
                ++$i;
            }
            $printConv = \%newConv;
        }
        my $str = $$printConv{$id} || "Unknown ($id)";
        return Image::ExifTool::Exif::PrintLensID($et, $str, $printConv,
                    undef, $id, $focalLength, $sa, $maxAv, $sf, $lf, $lensModel);
    }
    return "Unknown ($id)";
}

#------------------------------------------------------------------------------
# Convert XMP date/time to EXIF format
# Inputs: 0) XMP date/time string, 1) set if we aren't sure this is a date
# Returns: EXIF date/time
sub ConvertXMPDate($;$)
{
    my ($val, $unsure) = @_;
    if ($val =~ /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}:\d{2})(:\d{2})?\s*(\S*)$/) {
        my $s = $5 || '';           # seconds may be missing
        $val = "$1:$2:$3 $4$s$6";   # convert back to EXIF time format
    } elsif (not $unsure and $val =~ /^(\d{4})(-\d{2}){0,2}/) {
        $val =~ tr/-/:/;
    }
    return $val;
}

#------------------------------------------------------------------------------
# Convert rational string value
# Inputs: 0) string (converted to number, 'inf' or 'undef' on return if rational)
# Returns: true if value was converted
sub ConvertRational($)
{
    my $val = $_[0];
    $val =~ m{^(-?\d+)/(-?\d+)$} or return undef;
    if ($2 != 0) {
        $_[0] = $1 / $2; # calculate quotient
    } elsif ($1) {
        $_[0] = 'inf';
    } else {
        $_[0] = 'undef';
    }
    return 1;
}

#------------------------------------------------------------------------------
# Convert a string of floating point values to rationals
# Inputs: 0) string of floating point numbers separated by spaces
# Returns: string of rational numbers separated by spaces
sub ConvertRationalList($)
{
    my $val = shift;
    my @vals = split ' ', $val;
    return $val unless @vals == 4;
    foreach (@vals) {
        ConvertRational($_) or return $val;
    }
    return join ' ', @vals;
}

#------------------------------------------------------------------------------
# We found an XMP property name/value
# Inputs: 0) ExifTool object ref, 1) Pointer to tag table
#         2) reference to array of XMP property names (last is current property)
#         3) property value, 4) attribute hash ref (for 'xml:lang' or 'rdf:datatype')
# Returns: 1 if valid tag was found
sub FoundXMP($$$$;$)
{
    local $_;
    my ($et, $tagTablePtr, $props, $val, $attrs) = @_;
    my ($lang, @structProps, $rawVal, $rational);
    my ($tag, $ns) = GetXMPTagID($props, $$et{OPTIONS}{Struct} ? \@structProps : undef);
    return 0 unless $tag;   # ignore things that aren't valid tags

    # translate namespace if necessary
    $ns = $stdXlatNS{$ns} if $stdXlatNS{$ns};
    my $info = $$tagTablePtr{$ns};
    my ($table, $added, $xns, $tagID);
    if ($info) {
        $table = $$info{SubDirectory}{TagTable} or warn "Missing TagTable for $tag!\n";
    } elsif ($$props[0] eq 'svg:svg') {
        if (not $ns) {
            # disambiguate MetadataID by adding back the 'metadata' we ignored
            $tag = 'metadataId' if $tag eq 'id' and $$props[1] eq 'svg:metadata';
            # use SVG namespace in SVG files if nothing better to use
            $table = 'Image::ExifTool::XMP::SVG';
        } elsif (not grep /^rdf:/, @$props) {
            # only other SVG information if not inside RDF (call it XMP if in RDF)
            $table = 'Image::ExifTool::XMP::otherSVG';
        }
    }

    my $xmlGroups;
    my $grp0 = $$tagTablePtr{GROUPS}{0};
    if (not $ns and $grp0 ne 'XMP') {
        $tagID = $tag;
    } elsif ($grp0 eq 'XML' and not $table) {
        # this is an XML table (no namespace lookup)
        $tagID = "$ns:$tag";
    } else {
        $xmlGroups = 1 if $grp0 eq 'XML';
        # look up this tag in the appropriate table
        $table or $table = 'Image::ExifTool::XMP::other';
        $tagTablePtr = GetTagTable($table);
        if ($$tagTablePtr{NAMESPACE}) {
            $tagID = $tag;
        } else {
            $xns = $xmpNS{$ns};
            unless (defined $xns) {
                $xns = $ns;
                # validate namespace prefix
                unless ($ns =~ /^[A-Z_a-z\x80-\xff][-.0-9A-Z_a-z\x80-\xff]*$/ or $ns eq '') {
                    $et->Warn("Invalid XMP namespace prefix '${ns}'");
                    # clean up prefix for use as an ExifTool group name
                    $ns =~ tr/-.0-9A-Z_a-z\x80-\xff//dc;
                    $ns =~ /^[A-Z_a-z\x80-\xff]/ or $ns = "ns_$ns";
                    $stdXlatNS{$xns} = $ns;
                    $xmpNS{$ns} = $xns;
                }
            }
            # add XMP namespace prefix to avoid collisions in variable-namespace tables
            $tagID = "$xns:$tag";
            # add namespace to top-level structure property
            $structProps[0][0] = "$xns:" . $structProps[0][0] if @structProps;
        }
    }
    my $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID);

    $lang = $$attrs{'xml:lang'} if $attrs;

    # must add a new tag table entry if this tag isn't pre-defined
    # (or initialize from structure field if this is a pre-defined flattened tag)
NoLoop:
    while (not $tagInfo or $$tagInfo{Flat}) {
        my (@tagList, @nsList);
        GetXMPTagID($props, \@tagList, \@nsList);
        my ($ta, $t, $ti, $addedFlat, $i, $j);
        # build tag ID strings for each level in the property path
        foreach $ta (@tagList) {
            # insert tag ID in index 1 of tagList list
            $t = $$ta[1] = $t ? $t . ucfirst($$ta[0]) : $$ta[0];
            # generate flattened tags for top-level structure if necessary
            next if defined $addedFlat;
            $ti = $$tagTablePtr{$t} or next;
            next unless ref $ti eq 'HASH' and $$ti{Struct};
            $addedFlat = AddFlattenedTags($tagTablePtr, $t);
            # all done if we generated the tag we are looking for
            $tagInfo = $$tagTablePtr{$tagID} and last NoLoop if $addedFlat;
        }
        my $name = ucfirst($tag);

        # search for the innermost containing structure
        # (in case tag is an unknown field in a known structure)
        # (only necessary if we found a structure above)
        if (defined $addedFlat) {
            my $t2 = '';
            for ($i=$#tagList-1; $i>=0; --$i) {
                $t = $tagList[$i][1];
                $t2 = $tagList[$i+1][0] . ucfirst($t2); # build relative tag id
                $ti = $$tagTablePtr{$t} or next;
                next unless ref $ti eq 'HASH';
                my $strTable = $$ti{Struct} or next;
                my $flat = (defined $$ti{FlatName} ? $$ti{FlatName} : $$ti{Name});
                $name = $flat . ucfirst($t2);
                # don't continue if structure is known but field is not
                last if $$strTable{NAMESPACE} or not exists $$strTable{NAMESPACE};
                # this is a variable-namespace structure, so we must:
                # 1) get tagInfo from corresponding top-level XMP tag if it exists
                # 2) add new entry in this tag table, but with namespace prefix on tag ID
                my $n = $nsList[$i+1];  # namespace of structure field
                # translate to standard ExifTool namespace
                $n = $stdXlatNS{$n} if $stdXlatNS{$n};
                my $xn = $xmpNS{$n} || $n;  # standard XMP namespace
                # no need to continue with variable-namespace logic if
                # we are in our own namespace (right?)
                last if $xn eq ($$tagTablePtr{NAMESPACE} || '');
                $tagID = "$xn:$tag";    # add namespace to avoid collisions
                # change structure properties to add the standard XMP namespace
                # prefix for this field (needed for variable-namespace fields)
                if (@structProps) {
                    $structProps[$i+1][0] = "$xn:" . $structProps[$i+1][0];
                }
                # copy tagInfo entries from the existing top-level XMP tag
                my $tg = $Image::ExifTool::XMP::Main{$n};
                last unless ref $tg eq 'HASH' and $$tg{SubDirectory};
                my $tbl = GetTagTable($$tg{SubDirectory}{TagTable}) or last;
                my $sti = $et->GetTagInfo($tbl, $t2);
                if (not $sti or $$sti{Flat}) {
                    # again, we must initialize flattened tags if necessary
                    # (but don't bother to recursively apply full logic to
                    #  allow nested variable-namespace strucures until someone
                    #  actually wants to do such a silly thing)
                    my $t3 = '';
                    for ($j=$i+1; $j<@tagList; ++$j) {
                        $t3 = $tagList[$j][0] . ucfirst($t3);
                        my $ti3 = $$tbl{$t3} or next;
                        next unless ref $ti3 eq 'HASH' and $$ti3{Struct};
                        last unless AddFlattenedTags($tbl, $t3);
                        $sti = $$tbl{$t2};
                        last;
                    }
                    last unless $sti;
                }
                # generate new tagInfo hash based on existing top-level tag
                $tagInfo = { %$sti, Name => $flat . $$sti{Name} };
                # be careful not to copy elements we shouldn't...
                delete $$tagInfo{Description}; # Description will be different
                # can't copy group hash because group 1 will be different and
                # we need to check this when writing tag to a specific group
                delete $$tagInfo{Groups};
                $$tagInfo{Groups}{2} = $$sti{Groups}{2} if $$sti{Groups};
                last;
            }
        }
        # generate a default tagInfo hash if necessary
        unless ($tagInfo) {
            # shorten tag name if necessary
            if ($$et{ShortenXmpTags}) {
                my $shorten = $$et{ShortenXmpTags};
                $name = &$shorten($name);
            }
            $tagInfo = { Name => $name, IsDefault => 1, Priority => 0 };
        }
        # add tag Namespace entry for tags in variable-namespace tables
        $$tagInfo{Namespace} = $xns if $xns;
        if ($$et{curURI}{$ns} and $$et{curURI}{$ns} =~ m{^http://ns.exiftool.(?:ca|org)/(.*?)/(.*?)/}) {
            my %grps = ( 0 => $1, 1 => $2 );
            # apply a little magic to recover original group names
            # from this exiftool-written RDF/XML file
            if ($grps{1} eq 'System') {
                $grps{1} = 'XML-System';
                $grps{0} = 'XML';
            } elsif ($grps{1} =~ /^\d/) {
                # URI's with only family 0 are internal tags from the source file,
                # so change the group name to avoid confusion with tags from this file
                $grps{1} = "XML-$grps{0}";
                $grps{0} = 'XML';
            }
            $$tagInfo{Groups} = \%grps;
            # flag to avoid setting group 1 later
            $$tagInfo{StaticGroup1} = 1;
        }
        # construct tag information for this unknown tag
        # -> make this a List or lang-alt tag if necessary
        if (@$props > 2 and $$props[-1] =~ /^rdf:li \d+$/ and
            $$props[-2] =~ /^rdf:(Bag|Seq|Alt)$/)
        {
            if ($lang and $1 eq 'Alt') {
                $$tagInfo{Writable} = 'lang-alt';
            } else {
                $$tagInfo{List} = $1;
            }
        # tried this, but maybe not a good idea for complex structures:
        #} elsif (grep / /, @$props) {
        #    $$tagInfo{List} = 1;
        }
        # save property list for verbose "adding" message unless this tag already exists
        $added = \@tagList unless $$tagTablePtr{$tagID};
        # if this is an empty structure, we must add a Struct field
        if (not length $val and $$attrs{'rdf:parseType'} and $$attrs{'rdf:parseType'} eq 'Resource') {
            $$tagInfo{Struct} = { STRUCT_NAME => 'XMP Unknown' };
        }
        AddTagToTable($tagTablePtr, $tagID, $tagInfo);
        last;
    }
    # decode value if necessary (et:encoding was used before exiftool 7.71)
    if ($attrs) {
        my $enc = $$attrs{'rdf:datatype'} || $$attrs{'et:encoding'};
        if ($enc and $enc =~ /base64/) {
            $val = DecodeBase64($val); # (now a value ref)
            $val = $$val unless length $$val > 100 or $$val =~ /[\0-\x08\x0b\0x0c\x0e-\x1f]/;
        }
    }
    if (defined $lang and lc($lang) ne 'x-default') {
        $lang = StandardLangCase($lang);
        my $langInfo = GetLangInfo($tagInfo, $lang);
        $tagInfo = $langInfo if $langInfo;
    }
    # un-escape XML character entities (handling CDATA)
    pos($val) = 0;
    if ($val =~ /<!\[CDATA\[(.*?)\]\]>/sg) {
        my $p = pos $val;
        # unescape everything up to the start of the CDATA section
        # (the length of "<[[CDATA[]]>" is 12 characters)
        my $v = UnescapeXML(substr($val, 0, $p - length($1) - 12)) . $1;
        while ($val =~ /<!\[CDATA\[(.*?)\]\]>/sg) {
            my $p1 = pos $val;
            $v .= UnescapeXML(substr($val, $p, $p1 - length($1) - 12)) . $1;
            $p = $p1;
        }
        $val = $v . UnescapeXML(substr($val, $p));
    } else {
        $val = UnescapeXML($val);
    }
    # decode from UTF8
    $val = $et->Decode($val, 'UTF8');
    # convert rational and date values to a more sensible format
    my $fmt = $$tagInfo{Writable};
    my $new = $$tagInfo{IsDefault} && $$et{OPTIONS}{XMPAutoConv};
    if ($fmt or $new) {
        $rawVal = $val; # save raw value for verbose output
        if (($new or $fmt eq 'rational') and ConvertRational($val)) {
            $rational = $rawVal;
        } else {
            $val = ConvertXMPDate($val, $new) if $new or $fmt eq 'date';
        }
        if ($$et{XmpValidate} and $fmt and $fmt eq 'boolean' and $val!~/^True|False$/) {
            if ($val =~ /^true|false$/) {
                $et->Warn("Boolean value for XMP-$ns:$$tagInfo{Name} should be capitalized",1);
            } else {
                $et->Warn(qq(Boolean value for XMP-$ns:$$tagInfo{Name} should be "True" or "False"),1);
            }
        }
        # protect against large binary data in unknown tags
        $$tagInfo{Binary} = 1 if $new and length($val) > 65536;
    }
    # store the value for this tag
    my $key = $et->FoundTag($tagInfo, $val) or return 0;
    # save original components of rational numbers (used when copying)
    $$et{TAG_EXTRA}{$key}{Rational} = $rational if defined $rational;
    # save structure/list information if necessary
    if (@structProps and (@structProps > 1 or defined $structProps[0][1]) and
        not $$et{NO_STRUCT})
    {
        $$et{TAG_EXTRA}{$key}{Struct} = \@structProps;
        $$et{IsStruct} = 1;
    }
    if ($xmlGroups) {
        $et->SetGroup($key, 'XML', 0);
        $et->SetGroup($key, "XML-$ns", 1);
    } elsif ($ns and not $$tagInfo{StaticGroup1}) {
        # set group1 dynamically according to the namespace
        $et->SetGroup($key, "$$tagTablePtr{GROUPS}{0}-$ns");
    }
    if ($$et{OPTIONS}{Verbose}) {
        if ($added) {
            my $props;
            if (@$added > 1) {
                $$tagInfo{Flat} = 0;    # this is a flattened tag
                my @props = map { $$_[0] } @$added;
                $props = ' (' . join('/',@props) . ')';
            } else {
                $props = '';
            }
            my $g1 = $et->GetGroup($key, 1);
            $et->VPrint(0, $$et{INDENT}, "[adding $g1:$tag]$props\n");
        }
        my $tagID = join('/',@$props);
        $et->VerboseInfo($tagID, $tagInfo, Value => $rawVal || $val);
    }
    # allow read-only subdirectories (eg. embedded base64 XMP/IPTC in NKSC files)
    if ($$tagInfo{SubDirectory} and not $$et{IsWriting}) {
        my $subdir = $$tagInfo{SubDirectory};
        my $dataPt = ref $$et{VALUE}{$key} ? $$et{VALUE}{$key} : \$$et{VALUE}{$key};
        # decode if necessary (eg. Nikon XMP-ast:XMLPackets)
        $dataPt = DecodeBase64($$dataPt) if $$tagInfo{Encoding} and $$tagInfo{Encoding} eq 'Base64';
        # process subdirectory information
        my %dirInfo = (
            DirName  => $$subdir{DirName} || $$tagInfo{Name},
            DataPt   => $dataPt,
            DirLen   => length $$dataPt,
            IgnoreProp => $$subdir{IgnoreProp}, # (allow XML to ignore specified properties)
            IsExtended => 1, # (hack to avoid Duplicate warning for embedded XMP)
            NoStruct => 1,   # (don't try to build structures since this isn't true XMP)
            NoBlockSave => 1,# (don't save as a block because we already did this)
        );
        my $oldOrder = GetByteOrder();
        SetByteOrder($$subdir{ByteOrder}) if $$subdir{ByteOrder};
        my $oldNS = $$et{definedNS};
        delete $$et{definedNS};
        my $subTablePtr = GetTagTable($$subdir{TagTable}) || $tagTablePtr;
        $et->ProcessDirectory(\%dirInfo, $subTablePtr, $$subdir{ProcessProc});
        SetByteOrder($oldOrder);
        $$et{definedNS} = $oldNS;
    }
    return 1;
}

#------------------------------------------------------------------------------
# Recursively parse nested XMP data element
# Inputs: 0) ExifTool ref, 1) tag table ref, 2) XMP data ref
#         3) offset to start of XMP element, 4) offset to end of XMP element
#         5) reference to array of enclosing XMP property names (undef if none)
#         6) reference to blank node information hash
# Returns: Number of contained XMP elements
sub ParseXMPElement($$$;$$$$)
{
    local $_;
    my ($et, $tagTablePtr, $dataPt, $start, $end, $propList, $blankInfo) = @_;
    my ($count, $nItems) = (0, 0);
    my $isWriting = $$et{XMP_CAPTURE};
    my $isSVG = $$et{XMP_IS_SVG};
    my $saveNS;     # save xlatNS lookup if changed for the scope of this element
    my (%definedNS, %usedNS);  # namespaces defined and used in this scope

    # get our parse procs
    my ($attrProc, $foundProc);
    if ($$et{XMPParseOpts}) {
        $attrProc = $$et{XMPParseOpts}{AttrProc};
        $foundProc = $$et{XMPParseOpts}{FoundProc} || \&FoundXMP;
    } else {
        $foundProc = \&FoundXMP;
    }
    $start or $start = 0;
    $end or $end = length $$dataPt;
    $propList or $propList = [ ];

    my $processBlankInfo;
    # create empty blank node information hash if necessary
    $blankInfo or $blankInfo = $processBlankInfo = { Prop => { } };
    # keep track of current nodeID at this nesting level
    my $oldNodeID = $$blankInfo{NodeID};
    pos($$dataPt) = $start;

    # lookup for translating namespace prefixes
    my $xlatNS = $$et{xlatNS};

    Element: for (;;) {
        # all done if there isn't enough data for another element
        # (the smallest possible element is 4 bytes, eg. "<a/>")
        last if pos($$dataPt) > $end - 4;
        # reset nodeID before processing each element
        my $nodeID = $$blankInfo{NodeID} = $oldNodeID;
        # get next element
        last if $$dataPt !~ m{<([?/]?)([-\w:.\x80-\xff]+|!--)([^>]*)>}sg or pos($$dataPt) > $end;
        # (the only reason we match '<[?/]' is to keep from scanning past the
        #  "<?xpacket end..." terminator or other closing token, so
        next if $1;
        my ($prop, $attrs) = ($2, $3);
        # skip comments
        if ($prop eq '!--') {
            next if $attrs =~ /--$/ or $$dataPt =~ /-->/sg;
            last;
        }
        my $valStart = pos($$dataPt);
        my $valEnd;
        # only look for closing token if this is not an empty element
        # (empty elements end with '/', eg. <a:b/>)
        if ($attrs !~ s/\/$//) {
            my $nesting = 1;
            for (;;) {
# this match fails with perl 5.6.2 (perl bug!), but it works without
# the '(.*?)', so we must do it differently...
#                $$dataPt =~ m/(.*?)<\/$prop>/sg or last Element;
#                my $val2 = $1;
                # find next matching closing token, or the next opening token
                # of a nested same-named element
                if ($$dataPt !~ m{<(/?)$prop([-\w:.\x80-\xff]*)(.*?(/?))>}sg or
                    pos($$dataPt) > $end)
                {
                    $et->Warn("XMP format error (no closing tag for $prop)");
                    last Element;
                }
                next if $2; # ignore opening properties with different names
                if ($1) {
                    next if --$nesting;
                    $valEnd = pos($$dataPt) - length($prop) - length($3) - 3;
                    last;   # this element is complete
                }
                # this is a nested opening token (or empty element)
                ++$nesting unless $4;
            }
        } else {
            $valEnd = $valStart;
        }
        $start = pos($$dataPt);         # start from here the next time around

        # ignore specified XMP namespaces/properties
        if ($$et{EXCL_XMP_LOOKUP} and not $isWriting and $prop =~ /^(.+):(.*)/) {
            my ($ns, $nm) = (lc($stdXlatNS{$1} || $1), lc($2));
            if ($$et{EXCL_XMP_LOOKUP}{"xmp-$ns:all"} or $$et{EXCL_XMP_LOOKUP}{"xmp-$ns:$nm"} or
                $$et{EXCL_XMP_LOOKUP}{"xmp-all:$nm"})
            {
                ++$count;   # (pretend we found something so we don't store as a tag value)
                next;
            }
        }

        # extract property attributes
        my ($parseResource, %attrs, @attrs);
# this hangs Perl (v5.18.4) for a specific capture string [patched in ExifTool 12.98]
#        while ($attrs =~ m/(\S+?)\s*=\s*(['"])(.*?)\2/sg) {
        while ($attrs =~ /(\S+?)\s*=\s*(['"])/g) {
            my ($attr, $quote) = ($1, $2);
            my $p0 = pos($attrs);
            last unless $attrs =~ /$quote/g;
            my $val = substr($attrs, $p0, pos($attrs)-$p0-1);
            # handle namespace prefixes (defined by xmlns:PREFIX, or used with PREFIX:tag)
            if ($attr =~ /(.*?):/) {
                if ($1 eq 'xmlns') {
                    my $ns = substr($attr, 6);
                    my $stdNS = $uri2ns{$val};
                    # keep track of namespace prefixes defined in this scope (for Validate)
                    $$et{definedNS}{$ns} = $definedNS{$ns} = 1 unless $$et{definedNS}{$ns};
                    unless ($stdNS) {
                        my $try = $val;
                        # patch for Nikon NX2 URI bug for Microsoft PhotoInfo namespace
                        $try =~ s{/$}{} or $try .= '/';
                        $stdNS = $uri2ns{$try};
                        if ($stdNS) {
                            $val = $try;
                            $et->Warn("Fixed incorrect URI for xmlns:$ns", 1);
                        } elsif ($val =~ m(^http://ns.nikon.com/BASIC_PARAM)) {
                            $et->OverrideFileType('NXD','application/x-nikon-nxd');
                        } else {
                            # look for same namespace with different version number
                            $try = quotemeta $val; # (note: escapes slashes too)
                            $try =~ s{\\/\d+\\\.\d+(\\/|$)}{\\/\\d+\\\.\\d+$1};
                            my ($good) = grep /^$try$/, keys %uri2ns;
                            if ($good) {
                                $stdNS = $uri2ns{$good};
                                $et->VPrint(0, $$et{INDENT}, "[different $stdNS version: $val]\n");
                            }
                        }
                    }
                    # tame wild namespace prefixes (patches Microsoft stupidity)
                    my $newNS;
                    if ($stdNS) {
                        # use standard namespace prefix if pre-defined
                        if ($stdNS ne $ns) {
                            $newNS = $stdNS;
                        } elsif ($$xlatNS{$ns}) {
                            # this prefix is re-defined to the standard prefix in this scope
                            $newNS = '';
                        }
                    } elsif ($$et{curNS}{$val}) {
                        # use a consistent prefix over the entire XMP for a given namespace URI
                        $newNS = $$et{curNS}{$val} if $$et{curNS}{$val} ne $ns;
                    } else {
                        my $curURI = $$et{curURI};
                        my $curNS = $$et{curNS};
                        my $usedNS = $ns;
                        # use unique prefixes for all namespaces across the entire XMP
                        if ($$curURI{$ns} or $nsURI{$ns}) {
                            # generate a temporary namespace prefix to resolve any conflict
                            my $i = 0;
                            ++$i while $$curURI{"tmp$i"};
                            $newNS = $usedNS = "tmp$i";
                        }
                        # keep track of the namespace prefixes and URI's used in this XMP
                        $$curNS{$val} = $usedNS;
                        $$curURI{$usedNS} = $val;
                    }
                    if (defined $newNS) {
                        # save translation used in containing scope if necessary
                        # create new namespace translation for the scope of this element
                        $saveNS or $saveNS = $xlatNS, $xlatNS = $$et{xlatNS} = { %$xlatNS };
                        if (length $newNS) {
                            # use the new namespace prefix
                            $$xlatNS{$ns} = $newNS;
                            $attr = 'xmlns:' . $newNS;
                            # must go through previous attributes and change prefixes if necessary
                            foreach (@attrs) {
                                next unless /(.*?):/ and $1 eq $ns and $1 ne $newNS;
                                my $newAttr = $newNS . substr($_, length($ns));
                                $attrs{$newAttr} = $attrs{$_};
                                delete $attrs{$_};
                                $_ = $newAttr;
                            }
                        } else {
                            delete $$xlatNS{$ns};
                        }
                    }
                } else {
                    $attr = $$xlatNS{$1} . substr($attr, length($1)) if $$xlatNS{$1};
                    $usedNS{$1} = 1;
                }
            }
            push @attrs, $attr;    # preserve order
            $attrs{$attr} = $val;
        }
        if ($prop =~ /(.*?):/) {
            $usedNS{$1} = 1;
            # tame wild namespace prefixes (patch for Microsoft stupidity)
            $prop = $$xlatNS{$1} . substr($prop, length($1)) if $$xlatNS{$1};
        }

        if ($prop eq 'rdf:li') {
            # impose a reasonable maximum on the number of items in a list
            if ($nItems == 1000) {
                my ($tg,$ns) = GetXMPTagID($propList);
                if ($isWriting) {
                    $et->Warn("Excessive number of items for $ns:$tg. Processing may be slow", 1);
                } elsif (not $$et{OPTIONS}{IgnoreMinorErrors}) {
                    $et->Warn("Extracted only 1000 $ns:$tg items. Ignore minor errors to extract all", 2);
                    last;
                }
            }
            # add index to list items so we can keep them in order
            # (this also enables us to keep structure elements grouped properly
            # for lists of structures, like JobRef)
            # Note: the list index is prefixed by the number of digits so sorting
            # alphabetically gives the correct order while still allowing a flexible
            # number of digits -- this scheme allows up to 9 digits in the index,
            # with index numbers ranging from 0 to 999999999.  The sequence is:
            # 10,11,12-19,210,211-299,3100,3101-3999,41000...9999999999.
            $prop .= ' ' . length($nItems) . $nItems;
            # reset LIST_TAGS at the start of the outtermost list
            # (avoids accumulating incorrectly-written elements in a correctly-written list)
            if (not $nItems and not grep /^rdf:li /, @$propList) {
                $$et{LIST_TAGS} = { };
            }
            ++$nItems;
        } elsif ($prop eq 'rdf:Description') {
            # remove unnecessary rdf:Description elements since parseType='Resource'
            # is more efficient (also necessary to make property path consistent)
            if (grep /^rdf:Description$/, @$propList) {
                $parseResource = 1;
                # set parseType so we know this is a structure
                $attrs{'rdf:parseType'} = 'Resource';
            }
        } elsif ($prop eq 'xmp:xmpmeta') {
            # patch MicrosoftPhoto unconformity
            $prop = 'x:xmpmeta';
            $et->Warn('Wrong namespace for xmpmeta') if $$et{XmpValidate};
        }

        # hook for special parsing of attributes
        my $val;
        if ($attrProc) {
            $val = substr($$dataPt, $valStart, $valEnd - $valStart);
            if (&$attrProc(\@attrs, \%attrs, \$prop, \$val)) {
                # the value was changed, so reset $valStart/$valEnd to use $val instead
                $valStart = $valEnd;
            }
        }

        # add nodeID to property path (with leading ' #') if it exists
        if (defined $attrs{'rdf:nodeID'}) {
            $nodeID = $$blankInfo{NodeID} = $attrs{'rdf:nodeID'};
            delete $attrs{'rdf:nodeID'};
            $prop .= ' #' . $nodeID;
            undef $parseResource;   # can't ignore if this is a node
        }

        # push this property name onto our hierarchy list
        push @$propList, $prop unless $parseResource;

        if ($isSVG) {
            # ignore everything but top level SVG tags and metadata unless Unknown set
            unless ($$et{OPTIONS}{Unknown} > 1 or $$et{OPTIONS}{Verbose}) {
                if (@$propList > 1 and $$propList[1] !~ /\b(metadata|desc|title)$/) {
                    pop @$propList;
                    next;
                }
            }
            if ($prop eq 'svg' or $prop eq 'metadata') {
                # add svg namespace prefix if missing to ignore these entries in the tag name
                $$propList[-1] = "svg:$prop";
            }
        } elsif ($$et{XmpIgnoreProps}) { # ignore specified properties for tag name
            foreach (@{$$et{XmpIgnoreProps}}) {
                last unless @$propList;
                pop @$propList if $_ eq $$propList[0];
            }
        }

        # handle properties inside element attributes (RDF shorthand format):
        # (attributes take the form a:b='c' or a:b="c")
        my ($shortName, $shorthand, $ignored);
        foreach $shortName (@attrs) {
            next unless defined $attrs{$shortName};
            my $propName = $shortName;
            my ($ns, $name);
            if ($propName =~ /(.*?):(.*)/) {
                $ns = $1;   # specified namespace
                $name = $2;
            } elsif ($prop =~ /(\S*?):/) {
                $ns = $1;   # assume same namespace as parent
                $name = $propName;
                $propName = "$ns:$name";    # generate full property name
            } else {
                # a property qualifier is the only property name that may not
                # have a namespace, and a qualifier shouldn't have attributes,
                # but what the heck, let's allow this anyway
                $ns = '';
                $name = $propName;
            }
            if ($propName eq 'rdf:about') {
                if (not $$et{XmpAbout}) {
                    $$et{XmpAbout} = $attrs{$shortName};
                } elsif ($$et{XmpAbout} ne $attrs{$shortName}) {
                    if ($isWriting) {
                        my $str = "Different 'rdf:about' attributes not handled";
                        unless ($$et{WAS_WARNED}{$str}) {
                            $et->Error($str, 1);
                            $$et{WAS_WARNED}{$str} = 1;
                        }
                    } elsif ($$et{XmpValidate}) {
                        $et->Warn("Different 'rdf:about' attributes");
                    }
                }
            }
            if ($isWriting) {
                # keep track of our namespaces when writing
                if ($ns eq 'xmlns') {
                    my $stdNS = $uri2ns{$attrs{$shortName}};
                    unless ($stdNS and ($stdNS eq 'x' or $stdNS eq 'iX')) {
                        my $nsUsed = $$et{XMP_NS};
                        $$nsUsed{$name} = $attrs{$shortName} unless defined $$nsUsed{$name};
                    }
                    delete $attrs{$shortName};  # (handled by namespace logic)
                    next;
                } elsif ($recognizedAttrs{$propName}) {
                    next;
                }
            }
            my $shortVal = $attrs{$shortName};
            # Note: $prop is the containing property in this loop (not the shorthand property)
            # so $ignoreProp ignores all attributes of the ignored property
            if ($ignoreNamespace{$ns} or $ignoreProp{$prop} or $ignoreEtProp{$propName}) {
                $ignored = $propName;
                # handle special attributes (extract as tags only once if not empty)
                if (ref $recognizedAttrs{$propName} and $shortVal) {
                    my ($tbl, $id, $name) = @{$recognizedAttrs{$propName}};
                    my $tval = UnescapeXML($shortVal);
                    unless (defined $$et{VALUE}{$name} and $$et{VALUE}{$name} eq $tval) {
                        $et->HandleTag(GetTagTable($tbl), $id, $tval);
                    }
                }
                next;
            }
            delete $attrs{$shortName};  # don't re-use this attribute
            push @$propList, $propName;
            # save this shorthand XMP property
            if (defined $nodeID) {
                SaveBlankInfo($blankInfo, $propList, $shortVal);
            } elsif ($isWriting) {
                CaptureXMP($et, $propList, $shortVal);
            } else {
                ValidateProperty($et, $propList) if $$et{XmpValidate};
                &$foundProc($et, $tagTablePtr, $propList, $shortVal);
            }
            pop @$propList;
            $shorthand = 1;
        }
        if ($isWriting) {
            if (ParseXMPElement($et, $tagTablePtr, $dataPt, $valStart, $valEnd,
                                $propList, $blankInfo))
            {
                # (no value since we found more properties within this one)
                # set an error on any ignored attributes here, because they will be lost
                $$et{XMP_ERROR} = "Can't handle XMP attribute '${ignored}'" if $ignored;
            } elsif (not $shorthand or $valEnd != $valStart) {
                $val = substr($$dataPt, $valStart, $valEnd - $valStart);
                # remove comments and whitespace from rdf:Description only
                if ($prop eq 'rdf:Description') {
                    $val =~ s/<!--.*?-->//g; $val =~ s/^\s+//; $val =~ s/\s+$//;
                }
                if (defined $nodeID) {
                    SaveBlankInfo($blankInfo, $propList, $val, \%attrs);
                } else {
                    CaptureXMP($et, $propList, $val, \%attrs);
                }
            }
        } else {
            # look for additional elements contained within this one
            if ($valStart == $valEnd or
                !ParseXMPElement($et, $tagTablePtr, $dataPt, $valStart, $valEnd,
                                 $propList, $blankInfo))
            {
                my $wasEmpty;
                unless (defined $val) {
                    $val = substr($$dataPt, $valStart, $valEnd - $valStart);
                    # remove comments and whitespace from rdf:Description only
                    if ($prop eq 'rdf:Description' and $val) {
                        $val =~ s/<!--.*?-->//g; $val =~ s/^\s+//; $val =~ s/\s+$//;
                    }
                    # if element value is empty, take value from RDF 'value' or 'resource' attribute
                    # (preferentially) or 'about' attribute (if no 'value' or 'resource')
                    if ($val eq '' and ($attrs =~ /\brdf:(?:value|resource)=(['"])(.*?)\1/ or
                                        $attrs =~ /\brdf:about=(['"])(.*?)\1/))
                    {
                        $val = $2;
                        $wasEmpty = 1;
                    }
                }
                # there are no contained elements, so this must be a simple property value
                # (unless we already extracted shorthand values from this element)
                if (length $val or not $shorthand) {
                    my $lastProp = $$propList[-1];
                    $lastProp = '' unless defined $lastProp;
                    if (defined $nodeID) {
                        SaveBlankInfo($blankInfo, $propList, $val);
                    } elsif ($lastProp eq 'rdf:type' and $wasEmpty) {
                        # do not extract empty structure types (for now)
                    } elsif ($lastProp =~ /^et:(desc|prt|val)$/ and ($count or $1 eq 'desc')) {
                        # ignore et:desc, and et:val if preceded by et:prt
                        --$count;
                    } else {
                        ValidateProperty($et, $propList, \%attrs) if $$et{XmpValidate};
                        &$foundProc($et, $tagTablePtr, $propList, $val, \%attrs);
                    }
                }
            }
        }
        pop @$propList unless $parseResource;
        ++$count;

        # validate namespace prefixes used at this level if necessary
        if ($$et{XmpValidate}) {
            foreach (sort keys %usedNS) {
                next if $$et{definedNS}{$_} or $_ eq 'xml';
                if (defined $$et{definedNS}{$_}) {
                    $et->Warn("XMP namespace $_ is used out of scope");
                } else {
                    $et->Warn("Undefined XMP namespace: $_");
                }
                $$et{definedNS}{$_} = -1;  # (don't warn again for this namespace)
            }
            # reset namespaces that went out of scope
            $$et{definedNS}{$_} = 0 foreach keys %definedNS;
            undef %usedNS;
            undef %definedNS;
        }

        last if $start >= $end;
        pos($$dataPt) = $start;
        $$dataPt =~ /\G\s+/gc;  # skip white space after closing token
    }
#
# process resources referenced by blank nodeID's
#
    if ($processBlankInfo and %{$$blankInfo{Prop}}) {
        ProcessBlankInfo($et, $tagTablePtr, $blankInfo, $isWriting);
        %$blankInfo = ();   # free some memory
    }
    # restore namespace lookup from the containing scope
    $$et{xlatNS} = $saveNS if $saveNS;

    return $count;  # return the number of elements found at this level
}

#------------------------------------------------------------------------------
# Process XMP data
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
# Notes: The following flavours of XMP files are currently recognized:
# - standard XMP with xpacket, x:xmpmeta and rdf:RDF elements
# - XMP that is missing the xpacket and/or x:xmpmeta elements
# - mutant Microsoft XMP with xmp:xmpmeta element
# - XML files beginning with "<xml"
# - SVG files that begin with "<svg" or "<!DOCTYPE svg"
# - XMP and XML files beginning with a UTF-8 byte order mark
# - UTF-8, UTF-16 and UTF-32 encoded XMP
# - erroneously double-UTF8 encoded XMP
# - otherwise valid files with leading XML comment
sub ProcessXMP($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my ($dirStart, $dirLen, $dataLen, $double);
    my ($buff, $fmt, $hasXMP, $isXML, $isRDF, $isSVG);
    my $rtnVal = 0;
    my $bom = 0;
    my $path = $et->MetadataPath();

    # namespaces and prefixes currently in effect while parsing the file,
    # and lookup to translate brain-dead-Microsoft-Photo-software prefixes
    $$et{curURI} = { };
    $$et{curNS}  = { };
    $$et{xlatNS} = { };
    $$et{definedNS} = { };
    delete $$et{XmpAbout};
    delete $$et{XmpValidate};   # don't validate by default
    delete $$et{XmpValidateLangAlt};

    # ignore non-standard XMP while in strict MWG compatibility mode
    if (($Image::ExifTool::MWG::strict or $$et{OPTIONS}{Validate}) and
        not ($$et{XMP_CAPTURE} or $$et{DOC_NUM}) and
        (($$dirInfo{DirName} || '') eq 'XMP' or $$et{FILE_TYPE} eq 'XMP'))
    {
        $$et{XmpValidate} = { } if $$et{OPTIONS}{Validate};
        my $nonStd = ($stdPath{$$et{FILE_TYPE}} and $path ne $stdPath{$$et{FILE_TYPE}});
        if ($nonStd and $Image::ExifTool::MWG::strict) {
            $et->Warn("Ignored non-standard XMP at $path");
            return 1;
        }
        if ($nonStd) {
            $et->Warn("Non-standard XMP at $path", 1);
        } elsif (not $$dirInfo{IsExtended}) {
            $et->Warn("Duplicate XMP at $path") if $$et{DIR_COUNT}{XMP};
            $$et{DIR_COUNT}{XMP} = ($$et{DIR_COUNT}{XMP} || 0) + 1; # count standard XMP
        }
    }
    if ($dataPt) {
        $dirStart = $$dirInfo{DirStart} || 0;
        $dirLen = $$dirInfo{DirLen} || (length($$dataPt) - $dirStart);
        $dataLen = $$dirInfo{DataLen} || length($$dataPt);
        # check leading BOM (may indicate double-encoded UTF)
        pos($$dataPt) = $dirStart;
        if ($$dataPt =~ /\G((\0\0)?\xfe\xff|\xff\xfe(\0\0)?|\xef\xbb\xbf)\0*<\0*\?\0*x\0*p\0*a\0*c\0*k\0*e\0*t/g) {
            $double = $1 
        } else {
            # handle UTF-16/32 XML
            pos($$dataPt) = $dirStart;
            if ($$dataPt =~ /\G((\0\0)?\xfe\xff|\xff\xfe(\0\0)?|\xef\xbb\xbf)\0*<\0*\?\0*x\0*m\0*l\0* /g) {
                my $tmp = $1;
                $fmt = $tmp =~ /\xfe\xff/ ? 'n' : 'v';
                $fmt = uc($fmt) if $tmp =~ /\0\0/;
                $isXML = 1;
            }
        }
    } else {
        my ($type, $mime, $buf2, $buf3);
        # read information from XMP file
        my $raf = $$dirInfo{RAF} or return 0;
        $raf->Read($buff, 256) or return 0;
        ($buf2 = $buff) =~ tr/\0//d;    # cheap conversion to UTF-8
        # remove leading comments if they exist (eg. ImageIngester)
        while ($buf2 =~ /^\s*<!--/) {
            # remove the comment if it is complete
            if ($buf2 =~ s/^\s*<!--.*?-->\s+//s) {
                # continue with parsing if we have more than 128 bytes remaining
                next if length $buf2 > 128;
            } else {
                # don't read more than 10k when looking for the end of comment
                return 0 if length($buf2) > 10000;
            }
            $raf->Read($buf3, 256) or last; # read more data if available
            $buff .= $buf3;
            $buf3 =~ tr/\0//d;
            $buf2 .= $buf3;
        }
        # check to see if this is XMP format
        # (CS2 writes .XMP files without the "xpacket begin")
        if ($buf2 =~ /^\s*(<\?xpacket begin=|<x(mp)?:x[ma]pmeta)/) {
            $hasXMP = 1;
        } else {
            # also recognize XML files and .XMP files with BOM and without x:xmpmeta
            if ($buf2 =~ /^(\xfe\xff)(<\?xml|<rdf:RDF|<x(mp)?:x[ma]pmeta)/g) {
                $fmt = 'n';     # UTF-16 or 32 MM with BOM
            } elsif ($buf2 =~ /^(\xff\xfe)(<\?xml|<rdf:RDF|<x(mp)?:x[ma]pmeta)/g) {
                $fmt = 'v';     # UTF-16 or 32 II with BOM
            } elsif ($buf2 =~ /^(\xef\xbb\xbf)?(<\?xml|<rdf:RDF|<x(mp)?:x[ma]pmeta|<svg\b)/g) {
                $fmt = 0;       # UTF-8 with BOM or unknown encoding without BOM
            } elsif ($buf2 =~ /^(\xfe\xff|\xff\xfe|\xef\xbb\xbf)(<\?xpacket begin=)/g) {
                $double = $1;   # double-encoded UTF
            } else {
                return 0;       # not recognized XMP or XML
            }
            $bom = 1 if $1;
            if ($2 eq '<?xml') {
                if (defined $fmt and not $fmt and $buf2 =~ /^[^\n\r]*[\n\r]+<\?aid /s) {
                    undef $$et{XmpValidate};    # don't validate INX
                    if ($$et{XMP_CAPTURE}) {
                        $et->Error("ExifTool does not yet support writing of INX files");
                        return 0;
                    }
                    $type = 'INX';
                } elsif ($buf2 =~ /<x(mp)?:x[ma]pmeta/) {
                    $hasXMP = 1;
                } else {
                    undef $$et{XmpValidate};    # don't validate XML
                    # identify SVG images and PLIST files by DOCTYPE if available
                    if ($buf2 =~ /<!DOCTYPE\s+(\w+)/) {
                        if ($1 eq 'svg') {
                            $isSVG = 1;
                        } elsif ($1 eq 'plist') {
                            $type = 'PLIST';
                        } elsif ($1 eq 'REDXIF') {
                            $type = 'RMD';
                            $mime = 'application/xml';
                        } elsif ($1 ne 'fcpxml') { # Final Cut Pro XML
                            return 0;
                        }
                    } elsif ($buf2 =~ /<svg[\s>]/) {
                        $isSVG = 1;
                    } elsif ($buf2 =~ /<rdf:RDF/) {
                        $isRDF = 1;
                    } elsif ($buf2 =~ /<plist[\s>]/) {
                        $type = 'PLIST';
                    }
                }
                $isXML = 1;
            } elsif ($2 eq '<rdf:RDF') {
                $isRDF = 1;     # recognize XMP without x:xmpmeta element
            } elsif ($2 eq '<svg') {
                $isSVG = $isXML = 1;
            }
            if ($isSVG and $$et{XMP_CAPTURE}) {
                $et->Error("ExifTool does not yet support writing of SVG images");
                return 0;
            }
            if ($buff =~ /^\0\0/) {
                $fmt = 'N';     # UTF-32 MM with or without BOM
            } elsif ($buff =~ /^..\0\0/s) {
                $fmt = 'V';     # UTF-32 II with or without BOM
            } elsif (not $fmt) {
                if ($buff =~ /^\0/) {
                    $fmt = 'n'; # UTF-16 MM without BOM
                } elsif ($buff =~ /^.\0/s) {
                    $fmt = 'v'; # UTF-16 II without BOM
                }
            }
        }
        my $size;
        if ($type) {
            if ($type eq 'PLIST') {
                my $ext = $$et{FILE_EXT};
                $type = $ext if $ext and $ext eq 'MODD';
                $tagTablePtr = GetTagTable('Image::ExifTool::PLIST::Main');
                $$dirInfo{XMPParseOpts}{FoundProc} = \&Image::ExifTool::PLIST::FoundTag;
            }
        } else {
            if ($isSVG) {
                $type = 'SVG';
            } elsif ($isXML and not $hasXMP and not $isRDF) {
                $type = 'XML';
                my $ext = $$et{FILE_EXT};
                $type = $ext if $ext and $ext eq 'COS'; # recognize COS by extension
            }
        }
        $et->SetFileType($type, $mime);

        my $fast = $et->Options('FastScan');
        return 1 if $fast and $fast == 3;

        if ($type and $type eq 'INX') {
            # brute force search for first XMP packet in INX file
            # start: '<![CDATA[<?xpacket begin' (24 bytes)
            # end:   '<?xpacket end="r"?>]]>'   (22 bytes)
            $raf->Seek(0, 0) or return 0;
            $raf->Read($buff, 65536) or return 1;
            for (;;) {
                last if $buff =~ /<!\[CDATA\[<\?xpacket begin/g;
                $raf->Read($buf2, 65536) or return 1;
                $buff = substr($buff, -24) . $buf2;
            }
            $buff = substr($buff, pos($buff) - 15); # (discard '<![CDATA[' and before)
            for (;;) {
                last if $buff =~ /<\?xpacket end="[rw]"\?>\]\]>/g;
                my $n = length $buff;
                $raf->Read($buf2, 65536) or $et->Warn('Missing xpacket end'), return 1;
                $buff .= $buf2;
                pos($buff) = $n - 22;   # don't miss end pattern if it was split
            }
            $size = pos($buff) - 3;     # (discard ']]>' and after)
            $buff = substr($buff, 0, $size);
        } else {
            # read the entire file
            $raf->Seek(0, 2) or return 0;
            $size = $raf->Tell() or return 0;
            $raf->Seek(0, 0) or return 0;
            $raf->Read($buff, $size) == $size or return 0;
        }
        $dataPt = \$buff;
        $dirStart = 0;
        $dirLen = $dataLen = $size;
    }

    # decode the first layer of double-encoded UTF text (if necessary)
    if ($double) {
        my ($buf2, $fmt);
        $buff = substr($$dataPt, $dirStart + length $double); # remove leading BOM
        Image::ExifTool::SetWarning(undef); # clear old warning
        local $SIG{'__WARN__'} = \&Image::ExifTool::SetWarning;
        # assume that character data has been re-encoded in UTF, so re-pack
        # as characters and look for warnings indicating a false assumption
        if ($double eq "\xef\xbb\xbf") {
            require Image::ExifTool::Charset;
            my $uni = Image::ExifTool::Charset::Decompose(undef,$buff,'UTF8');
            $buf2 = pack('C*', @$uni);
        } else {
            if (length($double) == 2) {
                $fmt = ($double eq "\xfe\xff") ? 'n' : 'v';
            } else {
                $fmt = ($double eq "\0\0\xfe\xff") ? 'N' : 'V';
            }
            $buf2 = pack('C*', unpack("$fmt*",$buff));
        }
        if (Image::ExifTool::GetWarning()) {
            $et->Warn('Superfluous BOM at start of XMP');
            $dataPt = \$buff;   # use XMP with the BOM removed
        } else {
            $et->Warn('XMP is double UTF-encoded');
            $dataPt = \$buf2;   # use the decoded XMP
        }
        $dirStart = 0;
        $dirLen = $dataLen = length $$dataPt;
    }

    # extract XMP/XML as a block if specified
    my $blockName = $$dirInfo{BlockInfo} ? $$dirInfo{BlockInfo}{Name} : 'XMP';
    my $blockExtract = $et->Options('BlockExtract');
    if (($$et{REQ_TAG_LOOKUP}{lc $blockName} or ($$et{TAGS_FROM_FILE} and
        not $$et{EXCL_TAG_LOOKUP}{lc $blockName}) or $blockExtract) and
        (($$et{FileType} eq 'XMP' and $blockName eq 'XMP') or
        ($$dirInfo{DirName} and $$dirInfo{DirName} eq $blockName)))
    {
        $et->FoundTag($$dirInfo{BlockInfo} || 'XMP', substr($$dataPt, $dirStart, $dirLen));
        return 1 if $blockExtract and $blockExtract > 1;
    }

    $tagTablePtr or $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
    if ($et->Options('Verbose') and not $$et{XMP_CAPTURE}) {
        my $dirType = $isSVG ? 'SVG' : $$tagTablePtr{GROUPS}{1};
        $et->VerboseDir($dirType, 0, $dirLen);
    }
#
# convert UTF-16 or UTF-32 encoded XMP to UTF-8 if necessary
#
    my $begin = '<?xpacket begin=';
    my $dirEnd = $dirStart + $dirLen;
    pos($$dataPt) = $dirStart;
    delete $$et{XMP_IS_XML};
    delete $$et{XMP_IS_SVG};
    if ($isXML or $isRDF) {
        $$et{XMP_IS_XML} = $isXML;
        $$et{XMP_IS_SVG} = $isSVG;
        $$et{XMP_NO_XPACKET} = 1 + $bom;
    } elsif ($$dataPt =~ /\G\Q$begin\E/gc) {
        delete $$et{XMP_NO_XPACKET};
    } elsif ($$dataPt =~ /<x(mp)?:x[ma]pmeta/gc and
             pos($$dataPt) > $dirStart and pos($$dataPt) < $dirEnd)
    {
        $$et{XMP_NO_XPACKET} = 1 + $bom;
    } else {
        delete $$et{XMP_NO_XPACKET};
        # check for UTF-16 encoding (insert one \0 between characters)
        $begin = join "\0", split //, $begin;
        # must reset pos because it was killed by previous unsuccessful //g match
        pos($$dataPt) = $dirStart;
        if ($$dataPt =~ /\G(\0)?\Q$begin\E\0./sg) {
            # validate byte ordering by checking for U+FEFF character
            if ($1) {
                # should be big-endian since we had a leading \0
                $fmt = 'n' if $$dataPt =~ /\G\xfe\xff/g;
            } else {
                $fmt = 'v' if $$dataPt =~ /\G\0\xff\xfe/g;
            }
        } else {
            # check for UTF-32 encoding (with three \0's between characters)
            $begin =~ s/\0/\0\0\0/g;
            pos($$dataPt) = $dirStart;
            if ($$dataPt !~ /\G(\0\0\0)?\Q$begin\E\0\0\0./sg) {
                $fmt = 0;   # set format to zero as indication we didn't find encoded XMP
            } elsif ($1) {
                # should be big-endian
                $fmt = 'N' if $$dataPt =~ /\G\0\0\xfe\xff/g;
            } else {
                $fmt = 'V' if $$dataPt =~ /\G\0\0\0\xff\xfe\0\0/g;
            }
        }
        defined $fmt or $et->Warn('XMP character encoding error');
    }
    # warn if standard XMP is missing xpacket wrapper
    if ($$et{XMP_NO_XPACKET} and $$et{OPTIONS}{Validate} and
        $stdPath{$$et{FILE_TYPE}} and $path eq $stdPath{$$et{FILE_TYPE}} and
        not $$dirInfo{IsExtended} and not $$et{DOC_NUM})
    {
        $et->Warn('XMP is missing xpacket wrapper', 1);
    }
    if ($fmt) {
        # trim if necessary to avoid converting non-UTF data
        if ($dirStart or $dirEnd != length($$dataPt)) {
            $buff = substr($$dataPt, $dirStart, $dirLen);
            $dataPt = \$buff;
        }
        # convert into UTF-8
        if ($] >= 5.006001) {
            $buff = pack('C0U*', unpack("$fmt*",$$dataPt));
        } else {
            $buff = Image::ExifTool::PackUTF8(unpack("$fmt*",$$dataPt));
        }
        $dataPt = \$buff;
        $dirStart = 0;
        $dirLen = length $$dataPt;
        $dirEnd = $dirStart + $dirLen;
    }
    # avoid scanning for XMP later in case ScanForXMP is set
    $$et{FoundXMP} = 1 if $tagTablePtr eq \%Image::ExifTool::XMP::Main;

    # set XMP parsing options
    $$et{XMPParseOpts} = $$dirInfo{XMPParseOpts};

    # ignore any specified properties (XML hack)
    if ($$dirInfo{IgnoreProp}) {
        %ignoreProp = %{$$dirInfo{IgnoreProp}};
    } else {
        undef %ignoreProp;
    }

    # need to preserve list indices to be able to handle multi-dimensional lists
    my $keepFlat;
    if ($$et{OPTIONS}{Struct}) {
        if ($$et{OPTIONS}{Struct} eq '2') {
            $keepFlat = 1;      # preserve flattened tags
            # setting NO_LIST to 0 combines list items in a TAG_EXTRA "NoList" element
            # to allow them to be re-listed later if necessary.  A "NoListDel" element
            # is also created for tags that wouldn't have existed.
            $$et{NO_LIST} = 0;
        } else {
            $$et{NO_LIST} = 1;
        }
    }

    # don't generate structures if this isn't real XMP
    $$et{NO_STRUCT} = 1 if $$dirInfo{BlockInfo} or $$dirInfo{NoStruct};

    # parse the XMP
    if (ParseXMPElement($et, $tagTablePtr, $dataPt, $dirStart, $dirEnd)) {
        $rtnVal = 1;
    } elsif ($$dirInfo{DirName} and $$dirInfo{DirName} eq 'XMP') {
        # if DirName was 'XMP' we expect well-formed XMP, so set Warning since it wasn't
        # (but allow empty XMP as written by some PhaseOne cameras)
        my $xmp = substr($$dataPt, $dirStart, $dirLen);
        if ($xmp =~ /^ *\0*$/) {
            $et->Warn('Invalid XMP');
        } else {
            $et->Warn('Empty XMP',1);
            $rtnVal = 1;
        }
    }
    delete $$et{NO_STRUCT};

    # return DataPt if successful in case we want it for writing
    $$dirInfo{DataPt} = $dataPt if $rtnVal and $$dirInfo{RAF};

    # restore structures if necessary
    if ($$et{IsStruct}) {
        unless ($$dirInfo{NoStruct}) {
            require 'Image/ExifTool/XMPStruct.pl';
            RestoreStruct($et, $keepFlat);
        }
        delete $$et{IsStruct};
    }
    # reset NO_LIST flag (must do this _after_ RestoreStruct() above)
    delete $$et{NO_LIST};
    delete $$et{XMPParseOpts};
    delete $$et{curURI};
    delete $$et{curNS};
    delete $$et{xlatNS};
    delete $$et{definedNS};

    return $rtnVal;
}


1;  #end

__END__

=head1 NAME

Image::ExifTool::XMP - Read XMP meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

XMP stands for Extensible Metadata Platform.  It is a format based on XML
that Adobe developed for embedding metadata information in image files.
This module contains the definitions required by Image::ExifTool to read XMP
information.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.adobe.com/devnet/xmp/>

=item L<http://www.w3.org/TR/rdf-syntax-grammar/>

=item L<http://www.iptc.org/IPTC4XMP/>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/XMP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
