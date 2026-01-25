#------------------------------------------------------------------------------
# File:         ICC_Profile.pm
#
# Description:  Read ICC Profile meta information
#
# Revisions:    11/16/2004 - P. Harvey Created
#
# References:   1) http://www.color.org/icc_specs2.html (ICC.1:2003-09)
#               2) http://www.color.org/icc_specs2.html (ICC.1:2001-04)
#               3) http://developer.apple.com/documentation/GraphicsImaging/Reference/ColorSync_Manager/ColorSync_Manager.pdf
#               4) http://www.color.org/privatetag2007-01.pdf
#               5) http://www.color.org/icc_specs2.xalter (approved revisions, 2010-07-16)
#               6) Eef Vreeland private communication
#               7) https://color.org/specification/ICC.2-2019.pdf
#               8) https://www.color.org/specification/ICC.1-2022-05.pdf
#
# Notes:        The ICC profile information is different: the format of each
#               tag is embedded in the information instead of in the directory
#               structure. This makes things a bit more complex because I need
#               an extra level of logic to decode the variable-format tags.
#------------------------------------------------------------------------------

package Image::ExifTool::ICC_Profile;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.42';

sub ProcessICC($$);
sub ProcessICC_Profile($$$);
sub WriteICC_Profile($$;$);
sub ProcessMetadata($$$);
sub ValidateICC($);

# illuminant type definitions
my %illuminantType = (
    1 => 'D50',
    2 => 'D65',
    3 => 'D93',
    4 => 'F2',
    5 => 'D55',
    6 => 'A',
    7 => 'Equi-Power (E)',
    8 => 'F8',
);
my %profileClass = (
    scnr => 'Input Device Profile',
    mntr => 'Display Device Profile',
    prtr => 'Output Device Profile',
   'link'=> 'DeviceLink Profile',
    spac => 'ColorSpace Conversion Profile',
    abst => 'Abstract Profile',
    nmcl => 'NamedColor Profile',
    nkpf => 'Nikon Input Device Profile (NON-STANDARD!)', # (written by Nikon utilities)
    # additions in v5 (ref 7)
    cenc => 'ColorEncodingSpace Profile',
   'mid '=> 'MultiplexIdentification Profile',
    mlnk => 'MultiplexLink Profile',
    mvis => 'MultiplexVisualization Profile',
);
my %manuSig = ( #6
    'NONE' => 'none',
    'none' => 'none', #PH
    ''     => '', #PH
    '4d2p' => 'Erdt Systems GmbH & Co KG',
    'AAMA' => 'Aamazing Technologies, Inc.',
    'ACER' => 'Acer Peripherals',
    'ACLT' => 'Acolyte Color Research',
    'ACTI' => 'Actix Systems, Inc.',
    'ADAR' => 'Adara Technology, Inc.',
    'ADBE' => 'Adobe Systems Inc.',
    'ADI ' => 'ADI Systems, Inc.',
    'AGFA' => 'Agfa Graphics N.V.',
    'ALMD' => 'Alps Electric USA, Inc.',
    'ALPS' => 'Alps Electric USA, Inc.',
    'ALWN' => 'Alwan Color Expertise',
    'AMTI' => 'Amiable Technologies, Inc.',
    'AOC ' => 'AOC International (U.S.A), Ltd.',
    'APAG' => 'Apago',
    'APPL' => 'Apple Computer Inc.',
    'appl' => 'Apple Computer Inc.',
    'AST ' => 'AST',
    'AT&T' => 'AT&T Computer Systems',
    'BAEL' => 'BARBIERI electronic',
    'berg' => 'bergdesign incorporated',
    'bICC' => 'basICColor GmbH',
    'BRCO' => 'Barco NV',
    'BRKP' => 'Breakpoint Pty Limited',
    'BROT' => 'Brother Industries, LTD',
    'BULL' => 'Bull',
    'BUS ' => 'Bus Computer Systems',
    'C-IT' => 'C-Itoh',
    'CAMR' => 'Intel Corporation',
    'CANO' => 'Canon, Inc. (Canon Development Americas, Inc.)',
    'CARR' => 'Carroll Touch',
    'CASI' => 'Casio Computer Co., Ltd.',
    'CBUS' => 'Colorbus PL',
    'CEL ' => 'Crossfield',
    'CELx' => 'Crossfield',
    'ceyd' => 'Integrated Color Solutions, Inc.',
    'CGS ' => 'CGS Publishing Technologies International GmbH',
    'CHM ' => 'Rochester Robotics',
    'CIGL' => 'Colour Imaging Group, London',
    'CITI' => 'Citizen',
    'CL00' => 'Candela, Ltd.',
    'CLIQ' => 'Color IQ',
    'clsp' => 'MacDermid ColorSpan, Inc.',
    'CMCO' => 'Chromaco, Inc.',
    'CMiX' => 'CHROMiX',
    'COLO' => 'Colorgraphic Communications Corporation',
    'COMP' => 'COMPAQ Computer Corporation',
    'COMp' => 'Compeq USA/Focus Technology',
    'CONR' => 'Conrac Display Products',
    'CORD' => 'Cordata Technologies, Inc.',
    'CPQ ' => 'Compaq Computer Corporation',
    'CPRO' => 'ColorPro',
    'CRN ' => 'Cornerstone',
    'CTX ' => 'CTX International, Inc.',
    'CVIS' => 'ColorVision',
    'CWC ' => 'Fujitsu Laboratories, Ltd.',
    'DARI' => 'Darius Technology, Ltd.',
    'DATA' => 'Dataproducts',
    'DCP ' => 'Dry Creek Photo',
    'DCRC' => 'Digital Contents Resource Center, Chung-Ang University',
    'DELL' => 'Dell Computer Corporation',
    'DIC ' => 'Dainippon Ink and Chemicals',
    'DICO' => 'Diconix',
    'DIGI' => 'Digital',
    'DL&C' => 'Digital Light & Color',
    'DPLG' => 'Doppelganger, LLC',
    'DS  ' => 'Dainippon Screen',
    'ds  ' => 'Dainippon Screen',
    'DSOL' => 'DOOSOL',
    'DUPN' => 'DuPont',
    'dupn' => 'DuPont',
    'Eizo' => 'EIZO NANAO CORPORATION',
    'EPSO' => 'Epson',
    'ESKO' => 'Esko-Graphics',
    'ETRI' => 'Electronics and Telecommunications Research Institute',
    'EVER' => 'Everex Systems, Inc.',
    'EXAC' => 'ExactCODE GmbH',
    'FALC' => 'Falco Data Products, Inc.',
    'FF  ' => 'Fuji Photo Film Co.,LTD',
    'FFEI' => 'FujiFilm Electronic Imaging, Ltd.',
    'ffei' => 'FujiFilm Electronic Imaging, Ltd.',
    'flux' => 'FluxData Corporation',
    'FNRD' => 'fnord software',
    'FORA' => 'Fora, Inc.',
    'FORE' => 'Forefront Technology Corporation',
    'FP  ' => 'Fujitsu',
    'FPA ' => 'WayTech Development, Inc.',
    'FUJI' => 'Fujitsu',
    'FX  ' => 'Fuji Xerox Co., Ltd.',
    'GCC ' => 'GCC Technologies, Inc.',
    'GGSL' => 'Global Graphics Software Limited',
    'GMB ' => 'Gretagmacbeth',
    'GMG ' => 'GMG GmbH & Co. KG',
    'GOLD' => 'GoldStar Technology, Inc.',
    'GOOG' => 'Google', #PH
    'GPRT' => 'Giantprint Pty Ltd',
    'GTMB' => 'Gretagmacbeth',
    'GVC ' => 'WayTech Development, Inc.',
    'GW2K' => 'Sony Corporation',
    'HCI ' => 'HCI',
    'HDM ' => 'Heidelberger Druckmaschinen AG',
    'HERM' => 'Hermes',
    'HITA' => 'Hitachi America, Ltd.',
    'HiTi' => 'HiTi Digital, Inc.',
    'HP  ' => 'Hewlett-Packard',
    'HTC ' => 'Hitachi, Ltd.',
    'IBM ' => 'IBM Corporation',
    'IDNT' => 'Scitex Corporation, Ltd.',
    'Idnt' => 'Scitex Corporation, Ltd.',
    'IEC ' => 'Hewlett-Packard',
    'IIYA' => 'Iiyama North America, Inc.',
    'IKEG' => 'Ikegami Electronics, Inc.',
    'IMAG' => 'Image Systems Corporation',
    'IMI ' => 'Ingram Micro, Inc.',
    'Inca' => 'Inca Digital Printers Ltd.',
    'INTC' => 'Intel Corporation',
    'INTL' => 'N/A (INTL)',
    'INTR' => 'Intra Electronics USA, Inc.',
    'IOCO' => 'Iocomm International Technology Corporation',
    'IPS ' => 'InfoPrint Solutions Company',
    'IRIS' => 'Scitex Corporation, Ltd.',
    'Iris' => 'Scitex Corporation, Ltd.',
    'iris' => 'Scitex Corporation, Ltd.',
    'ISL ' => 'Ichikawa Soft Laboratory',
    'ITNL' => 'N/A (ITNL)',
    'IVM ' => 'IVM',
    'IWAT' => 'Iwatsu Electric Co., Ltd.',
    'JPEG' => 'Joint Photographic Experts Group', #PH
    'JSFT' => 'Jetsoft Development',
    'JVC ' => 'JVC Information Products Co.',
    'KART' => 'Scitex Corporation, Ltd.',
    'Kart' => 'Scitex Corporation, Ltd.',
    'kart' => 'Scitex Corporation, Ltd.',
    'KFC ' => 'KFC Computek Components Corporation',
    'KLH ' => 'KLH Computers',
    'KMHD' => 'Konica Minolta Holdings, Inc.',
    'KNCA' => 'Konica Corporation',
    'KODA' => 'Kodak',
    'KYOC' => 'Kyocera',
    'LCAG' => 'Leica Camera AG',
    'LCCD' => 'Leeds Colour',
    'lcms' => 'Little CMS', #NealKrawetz
    'LDAK' => 'Left Dakota',
    'LEAD' => 'Leading Technology, Inc.',
    'Leaf' => 'Leaf', #PH
    'LEXM' => 'Lexmark International, Inc.',
    'LINK' => 'Link Computer, Inc.',
    'LINO' => 'Linotronic',
    'Lino' => 'Linotronic', #PH (NC)
    'lino' => 'Linotronic', #PH (NC)
    'LITE' => 'Lite-On, Inc.',
    'MAGC' => 'Mag Computronic (USA) Inc.',
    'MAGI' => 'MAG Innovision, Inc.',
    'MANN' => 'Mannesmann',
    'MICN' => 'Micron Technology, Inc.',
    'MICR' => 'Microtek',
    'MICV' => 'Microvitec, Inc.',
    'MINO' => 'Minolta',
    'MITS' => 'Mitsubishi Electronics America, Inc.',
    'MITs' => 'Mitsuba Corporation',
    'Mits' => 'Mitsubishi Electric Corporation Kyoto Works',
    'MNLT' => 'Minolta',
    'MODG' => 'Modgraph, Inc.',
    'MONI' => 'Monitronix, Inc.',
    'MONS' => 'Monaco Systems Inc.',
    'MORS' => 'Morse Technology, Inc.',
    'MOTI' => 'Motive Systems',
    'MSFT' => 'Microsoft Corporation',
    'MUTO' => 'MUTOH INDUSTRIES LTD.',
    'NANA' => 'NANAO USA Corporation',
    'NEC ' => 'NEC Corporation',
    'NEXP' => 'NexPress Solutions LLC',
    'NISS' => 'Nissei Sangyo America, Ltd.',
    'NKON' => 'Nikon Corporation',
    'ob4d' => 'Erdt Systems GmbH & Co KG',
    'obic' => 'Medigraph GmbH',
    'OCE ' => 'Oce Technologies B.V.',
    'OCEC' => 'OceColor',
    'OKI ' => 'Oki',
    'OKID' => 'Okidata',
    'OKIP' => 'Okidata',
    'OLIV' => 'Olivetti',
    'OLYM' => 'OLYMPUS OPTICAL CO., LTD',
    'ONYX' => 'Onyx Graphics',
    'OPTI' => 'Optiquest',
    'PACK' => 'Packard Bell',
    'PANA' => 'Matsushita Electric Industrial Co., Ltd.',
    'PANT' => 'Pantone, Inc.',
    'PBN ' => 'Packard Bell',
    'PFU ' => 'PFU Limited',
    'PHIL' => 'Philips Consumer Electronics Co.',
    'PNTX' => 'HOYA Corporation PENTAX Imaging Systems Division',
    'POne' => 'Phase One A/S',
    'PREM' => 'Premier Computer Innovations',
    'PRIN' => 'Princeton Graphic Systems',
    'PRIP' => 'Princeton Publishing Labs',
    'QLUX' => 'Hong Kong',
    'QMS ' => 'QMS, Inc.',
    'QPCD' => 'QPcard AB',
    'QUAD' => 'QuadLaser',
    'quby' => 'Qubyx Sarl',
    'QUME' => 'Qume Corporation',
    'RADI' => 'Radius, Inc.',
    'RDDx' => 'Integrated Color Solutions, Inc.',
    'RDG ' => 'Roland DG Corporation',
    'REDM' => 'REDMS Group, Inc.',
    'RELI' => 'Relisys',
    'RGMS' => 'Rolf Gierling Multitools',
    'RICO' => 'Ricoh Corporation',
    'RNLD' => 'Edmund Ronald',
    'ROYA' => 'Royal',
    'RPC ' => 'Ricoh Printing Systems,Ltd.',
    'RTL ' => 'Royal Information Electronics Co., Ltd.',
    'SAMP' => 'Sampo Corporation of America',
    'SAMS' => 'Samsung, Inc.',
    'SANT' => 'Jaime Santana Pomares',
    'SCIT' => 'Scitex Corporation, Ltd.',
    'Scit' => 'Scitex Corporation, Ltd.',
    'scit' => 'Scitex Corporation, Ltd.',
    'SCRN' => 'Dainippon Screen',
    'scrn' => 'Dainippon Screen',
    'SDP ' => 'Scitex Corporation, Ltd.',
    'Sdp ' => 'Scitex Corporation, Ltd.',
    'sdp ' => 'Scitex Corporation, Ltd.',
    'SEC ' => 'SAMSUNG ELECTRONICS CO.,LTD',
    'SEIK' => 'Seiko Instruments U.S.A., Inc.',
    'SEIk' => 'Seikosha',
    'SGUY' => 'ScanGuy.com',
    'SHAR' => 'Sharp Laboratories',
    'SICC' => 'International Color Consortium',
    'siwi' => 'SIWI GRAFIKA CORPORATION',
    'SONY' => 'SONY Corporation',
    'Sony' => 'Sony Corporation',
    'SPCL' => 'SpectraCal',
    'STAR' => 'Star',
    'STC ' => 'Sampo Technology Corporation',
    'TALO' => 'Talon Technology Corporation',
    'TAND' => 'Tandy',
    'TATU' => 'Tatung Co. of America, Inc.',
    'TAXA' => 'TAXAN America, Inc.',
    'TDS ' => 'Tokyo Denshi Sekei K.K.',
    'TECO' => 'TECO Information Systems, Inc.',
    'TEGR' => 'Tegra',
    'TEKT' => 'Tektronix, Inc.',
    'TI  ' => 'Texas Instruments',
    'TMKR' => 'TypeMaker Ltd.',
    'TOSB' => 'TOSHIBA corp.',
    'TOSH' => 'Toshiba, Inc.',
    'TOTK' => 'TOTOKU ELECTRIC Co., LTD',
    'TRIU' => 'Triumph',
    'TSBT' => 'TOSHIBA TEC CORPORATION',
    'TTX ' => 'TTX Computer Products, Inc.',
    'TVM ' => 'TVM Professional Monitor Corporation',
    'TW  ' => 'TW Casper Corporation',
    'ULSX' => 'Ulead Systems',
    'UNIS' => 'Unisys',
    'UTZF' => 'Utz Fehlau & Sohn',
    'VARI' => 'Varityper',
    'VIEW' => 'Viewsonic',
    'VISL' => 'Visual communication',
    'VIVO' => 'Vivo Mobile Communication Co., Ltd',
    'WANG' => 'Wang',
    'WLBR' => 'Wilbur Imaging',
    'WTG2' => 'Ware To Go',
    'WYSE' => 'WYSE Technology',
    'XERX' => 'Xerox Corporation',
    'XM  ' => 'Xiaomi',
    'XRIT' => 'X-Rite',
    'yxym' => 'YxyMaster GmbH',
    'Z123' => "Lavanya's test Company",
    'Zebr' => 'Zebra Technologies Inc',
    'ZRAN' => 'Zoran Corporation',
    # also seen: "    ",ACMS,KCMS,UCCM,etc2,SCTX
    # registry: https://www.color.org/signatureRegistry/index.xalter
);

# ICC_Profile tag table
%Image::ExifTool::ICC_Profile::Main = (
    GROUPS => { 2 => 'Image' },
    PROCESS_PROC => \&ProcessICC_Profile,
    WRITE_PROC => \&WriteICC_Profile,
    NOTES => q{
        ICC profile information is used in many different file types including JPEG,
        TIFF, PDF, PostScript, Photoshop, PNG, MIFF, PICT, QuickTime, XCF and some
        RAW formats.  While the tags listed below are not individually writable, the
        entire profile itself can be accessed via the extra 'ICC_Profile' tag, but
        this tag is neither extracted nor written unless specified explicitly.  See
        L<http://www.color.org/icc_specs2.xalter> for the official ICC
        specification.
    },
    A2B0 => 'AToB0',
    A2B1 => 'AToB1',
    A2B2 => 'AToB2',
    bXYZ => 'BlueMatrixColumn', # (called BlueColorant in ref 2)
    bTRC => {
        Name => 'BlueTRC',
        Description => 'Blue Tone Reproduction Curve',
    },
    B2A0 => 'BToA0',
    B2A1 => 'BToA1',
    B2A2 => 'BToA2',
    calt => {
        Name => 'CalibrationDateTime',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    targ => {
        Name => 'CharTarget',
        ValueConv => '$val=~s/\0.*//; length $val > 128 ? \$val : $val',
    },
    chad => 'ChromaticAdaptation',
    chrm => {
        Name => 'Chromaticity',
        Groups => { 1 => 'ICC_Profile#' }, #(just for the group list)
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Chromaticity',
            Validate => '$type eq "chrm"',
        },
    },
    clro => 'ColorantOrder',
    clrt => {
        Name => 'ColorantTable',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::ColorantTable',
            Validate => '$type eq "clrt"',
        },
    },
    clot => { # new in version 4.2
        Name => 'ColorantTableOut',
        Binary => 1,
    },
    cprt => {
        Name => 'ProfileCopyright',
        ValueConv => '$val=~s/\0.*//; $val', # may be null terminated
    },
    crdi => 'CRDInfo', #2
    dmnd => {
        Name => 'DeviceMfgDesc',
        Groups => { 2 => 'Camera' },
    },
    dmdd => {
        Name => 'DeviceModelDesc',
        Groups => { 2 => 'Camera' },
    },
    devs => {
        Name => 'DeviceSettings', #2
        Groups => { 2 => 'Camera' },
    },
    gamt => 'Gamut',
    kTRC => {
        Name => 'GrayTRC',
        Description => 'Gray Tone Reproduction Curve',
    },
    gXYZ => 'GreenMatrixColumn', # (called GreenColorant in ref 2)
    gTRC => {
        Name => 'GreenTRC',
        Description => 'Green Tone Reproduction Curve',
    },
    lumi => 'Luminance',
    meas => {
        Name => 'Measurement',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Measurement',
            Validate => '$type eq "meas"',
        },
    },
    bkpt => 'MediaBlackPoint',
    wtpt => 'MediaWhitePoint',
    ncol => 'NamedColor', #2
    ncl2 => 'NamedColor2',
    resp => 'OutputResponse',
    pre0 => 'Preview0',
    pre1 => 'Preview1',
    pre2 => 'Preview2',
    desc => 'ProfileDescription',
    pseq => 'ProfileSequenceDesc',
    psd0 => 'PostScript2CRD0', #2
    psd1 => 'PostScript2CRD1', #2
    psd2 => 'PostScript2CRD2', #2
    ps2s => 'PostScript2CSA', #2
    ps2i => 'PS2RenderingIntent', #2
    rXYZ => 'RedMatrixColumn', # (called RedColorant in ref 2)
    rTRC => {
        Name => 'RedTRC',
        Description => 'Red Tone Reproduction Curve',
    },
    scrd => 'ScreeningDesc',
    scrn => 'Screening',
   'bfd '=> {
        Name => 'UCRBG',
        Description => 'Under Color Removal and Black Gen.',
    },
    tech => {
        Name => 'Technology',
        PrintConv => {
            fscn => 'Film Scanner',
            dcam => 'Digital Camera',
            rscn => 'Reflective Scanner',
            ijet => 'Ink Jet Printer',
            twax => 'Thermal Wax Printer',
            epho => 'Electrophotographic Printer',
            esta => 'Electrostatic Printer',
            dsub => 'Dye Sublimation Printer',
            rpho => 'Photographic Paper Printer',
            fprn => 'Film Writer',
            vidm => 'Video Monitor',
            vidc => 'Video Camera',
            pjtv => 'Projection Television',
           'CRT '=> 'Cathode Ray Tube Display',
           'PMD '=> 'Passive Matrix Display',
           'AMD '=> 'Active Matrix Display',
            KPCD => 'Photo CD',
            imgs => 'Photo Image Setter',
            grav => 'Gravure',
            offs => 'Offset Lithography',
            silk => 'Silkscreen',
            flex => 'Flexography',
            mpfs => 'Motion Picture Film Scanner', #5
            mpfr => 'Motion Picture Film Recorder', #5
            dmpc => 'Digital Motion Picture Camera', #5
            dcpj => 'Digital Cinema Projector', #5
        },
    },
    vued => 'ViewingCondDesc',
    view => {
        Name => 'ViewingConditions',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::ViewingConditions',
            Validate => '$type eq "view"',
        },
    },
    ciis => 'ColorimetricIntentImageState', #5
    cicp => { #8 (Coding-independent Code Points)
        Name => 'ColorRepresentation',
        SubDirectory => { TagTable => 'Image::ExifTool::ICC_Profile::ColorRep' },
    },
    scoe => 'SceneColorimetryEstimates', #5
    sape => 'SceneAppearanceEstimates', #5
    fpce => 'FocalPlaneColorimetryEstimates', #5
    rhoc => 'ReflectionHardcopyOrigColorimetry', #5
    rpoc => 'ReflectionPrintOutputColorimetry', #5
    psid => { #5
        Name => 'ProfileSequenceIdentifier',
        Binary => 1,
    },
    B2D0 => { Name => 'BToD0', Binary => 1 }, #5
    B2D1 => { Name => 'BToD1', Binary => 1 }, #5
    B2D2 => { Name => 'BToD2', Binary => 1 }, #5
    B2D3 => { Name => 'BToD3', Binary => 1 }, #5
    D2B0 => { Name => 'DToB0', Binary => 1 }, #5
    D2B1 => { Name => 'DToB1', Binary => 1 }, #5
    D2B2 => { Name => 'DToB2', Binary => 1 }, #5
    D2B3 => { Name => 'DToB3', Binary => 1 }, #5
    rig0 => { #5
        Name => 'PerceptualRenderingIntentGamut',
        PrintConv => {
            prmg => 'Perceptual Reference Medium Gamut',
        },
    },
    rig2 => { #5
        Name => 'SaturationRenderingIntentGamut',
        PrintConv => {
            prmg => 'Perceptual Reference Medium Gamut',
        },
    },
    meta => { #5
        Name => 'Metadata',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Metadata',
            Validate => '$type eq "dict"',
        },
    },

    # ColorSync custom tags (ref 3)
    psvm => 'PS2CRDVMSize',
    vcgt => 'VideoCardGamma',
    mmod => 'MakeAndModel',
    dscm => 'ProfileDescriptionML',
    ndin => 'NativeDisplayInfo',

    # Microsoft custom tags (ref http://msdn2.microsoft.com/en-us/library/ms536870.aspx)
    MS00 => 'WCSProfiles',

    psd3 => { #6
        Name => 'PostScript2CRD3',
        Binary => 1, # (NC)
    },

    # new tags in v5 (ref 7)
    A2B3 => 'AToB3',
    A2M0 => 'AToM0',
    B2A3 => 'BToA3',
    bcp0 => 'BRDFColorimetricParam0',
    bcp1 => 'BRDFColorimetricParam1',
    bcp2 => 'BRDFColorimetricParam2',
    bcp3 => 'BRDFColorimetricParam3',
    bsp0 => 'BRDFSpectralParam0',
    bsp1 => 'BRDFSpectralParam1',
    bsp2 => 'BRDFSpectralParam2',
    bsp3 => 'BRDFSpectralParam3',
    bAB0 => 'BRDFAToB0',
    bAB1 => 'BRDFAToB1',
    bAB2 => 'BRDFAToB2',
    bAB3 => 'BRDFAToB3',
    bBA0 => 'BRDFBToA0',
    bBA1 => 'BRDFBToA1',
    bBA2 => 'BRDFBToA2',
    bBA3 => 'BRDFBToA3',
    bBD0 => 'BRDFBToD0',
    bBD1 => 'BRDFBToD1',
    bBD2 => 'BRDFBToD2',
    bBD3 => 'BRDFBToD3',
    bDB0 => 'BRDFDToB0',
    bDB1 => 'BRDFDToB1',
    bDB2 => 'BRDFDToB2',
    bDB3 => 'BRDFDToB3',
    bMB0 => 'BRDFMToB0',
    bMB1 => 'BRDFMToB1',
    bMB2 => 'BRDFMToB2',
    bMB3 => 'BRDFMToB3',
    bMS0 => 'BRDFMToS0',
    bMS1 => 'BRDFMToS1',
    bMS2 => 'BRDFMToS2',
    bMS3 => 'BRDFMToS3',
    dAB0 => 'DirectionalAToB0',
    dAB1 => 'DirectionalAToB1',
    dAB2 => 'DirectionalAToB2',
    dAB3 => 'DirectionalAToB3',
    dBA0 => 'DirectionalBToA0',
    dBA1 => 'DirectionalBToA1',
    dBA2 => 'DirectionalBToA2',
    dBA3 => 'DirectionalBToA3',
    dBD0 => 'DirectionalBToD0',
    dBD1 => 'DirectionalBToD1',
    dBD2 => 'DirectionalBToD2',
    dBD3 => 'DirectionalBToD3',
    dDB0 => 'DirectionalDToB0',
    dDB1 => 'DirectionalDToB1',
    dDB2 => 'DirectionalDToB2',
    dDB3 => 'DirectionalDToB3',
    gdb0 => 'GamutBoundaryDescription0',
    gdb1 => 'GamutBoundaryDescription1',
    gdb2 => 'GamutBoundaryDescription2',
    gdb3 => 'GamutBoundaryDescription3',
   'mdv '=> 'MultiplexDefaultValues',
    mcta => 'MultiplexTypeArray',
    minf => 'MeasurementInfo',
    miin => 'MeasurementInputInfo',
    M2A0 => 'MToA0',
    M2B0 => 'MToB0',
    M2B1 => 'MToB1',
    M2B2 => 'MToB2',
    M2B3 => 'MToB3',
    M2S0 => 'MToS0',
    M2S1 => 'MToS1',
    M2S2 => 'MToS2',
    M2S3 => 'MToS3',
    cept => 'ColorEncodingParams',
    csnm => 'ColorSpaceName',
    cloo => 'ColorantOrderOut',
    clio => 'ColorantInfoOut',
    c2sp => 'CustomToStandardPcc',
   'CxF '=> 'CXF',
    nmcl => 'NamedColor',
    psin => 'ProfileSequenceInfo',
    rfnm => 'ReferenceName',
    svcn => 'SpectralViewingConditions',
    swpt => 'SpectralWhitePoint',
    s2cp => 'StandardToCustomPcc',
    smap => 'SurfaceMap',
    # smwp ? (seen in some v5 samples [was a mistake in sample production])
    hdgm => { Name => 'HDGainMapInfo', Binary => 1 }, #PH

    # the following entry represents the ICC profile header, and doesn't
    # exist as a tag in the directory.  It is only in this table to provide
    # a link so ExifTool can locate the header tags
    Header => {
        Name => 'ProfileHeader',
        SubDirectory => {
            TagTable => 'Image::ExifTool::ICC_Profile::Header',
        },
    },
);

# ICC profile header definition
%Image::ExifTool::ICC_Profile::Header = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'ICC_Profile', 1 => 'ICC-header', 2 => 'Image' },
    4 => {
        Name => 'ProfileCMMType',
        Format => 'string[4]',
        SeparateTable => 'ManuSig',
        PrintConv => \%manuSig,
    },
    8 => {
        Name => 'ProfileVersion',
        Format => 'int16s',
        PrintConv => '($val >> 8).".".(($val & 0xf0)>>4).".".($val & 0x0f)',
    },
    12 => {
        Name => 'ProfileClass',
        Format => 'string[4]',
        PrintConv => \%profileClass,
    },
    16 => {
        Name => 'ColorSpaceData',
        Format => 'string[4]',
    },
    20 => {
        Name => 'ProfileConnectionSpace',
        Format => 'string[4]',
    },
    24 => {
        Name => 'ProfileDateTime',
        Groups => { 2 => 'Time' },
        Format => 'int16u[6]',
        ValueConv => 'sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2d",split(" ",$val));',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    36 => {
        Name => 'ProfileFileSignature',
        Format => 'string[4]',
    },
    40 => {
        Name => 'PrimaryPlatform',
        Format => 'string[4]',
        PrintConv => {
            'APPL' => 'Apple Computer Inc.',
            'MSFT' => 'Microsoft Corporation',
            'SGI ' => 'Silicon Graphics Inc.',
            'SUNW' => 'Sun Microsystems Inc.',
            'TGNT' => 'Taligent Inc.',
        },
    },
    44 => {
        Name => 'CMMFlags',
        Format => 'int32u',
        PrintConv => q[
            ($val & 0x01 ? "Embedded, " : "Not Embedded, ") .
            ($val & 0x02 ? "Not Independent" : "Independent")
        ],
    },
    48 => {
        Name => 'DeviceManufacturer',
        Format => 'string[4]',
        SeparateTable => 'ManuSig',
        PrintConv => \%manuSig,
    },
    52 => {
        Name => 'DeviceModel',
        Format => 'string[4]',
        # ROMM = Reference Output Medium Metric
    },
    56 => {
        Name => 'DeviceAttributes',
        Format => 'int32u[2]',
        PrintConv => q[
            my @v = split ' ', $val;
            ($v[1] & 0x01 ? "Transparency, " : "Reflective, ") .
            ($v[1] & 0x02 ? "Matte, " : "Glossy, ") .
            ($v[1] & 0x04 ? "Negative, " : "Positive, ") .
            ($v[1] & 0x08 ? "B&W" : "Color");
        ],
    },
    64 => {
        Name => 'RenderingIntent',
        Format => 'int32u',
        PrintConv => {
            0 => 'Perceptual',
            1 => 'Media-Relative Colorimetric',
            2 => 'Saturation',
            3 => 'ICC-Absolute Colorimetric',
        },
    },
    68 => {
        Name => 'ConnectionSpaceIlluminant',
        Format => 'fixed32s[3]',  # xyz
    },
    80 => {
        Name => 'ProfileCreator',
        Format => 'string[4]',
        SeparateTable => 'ManuSig',
        PrintConv => \%manuSig,
    },
    84 => {
        Name => 'ProfileID',
        Format => 'int8u[16]',
        PrintConv => 'Image::ExifTool::ICC_Profile::HexID($val)',
    },
);

# Coding-independent code points (cicp) definition
# (NOTE: conversions are the same as Image::ExifTool::QuickTime::ColorRep tags)
%Image::ExifTool::ICC_Profile::ColorRep = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'ICC_Profile', 1 => 'ICC-cicp', 2 => 'Image' },
    8 => {
        Name => 'ColorPrimaries',
        PrintConv => {
            1 => 'BT.709',
            2 => 'Unspecified',
            4 => 'BT.470 System M (historical)',
            5 => 'BT.470 System B, G (historical)',
            6 => 'BT.601',
            7 => 'SMPTE 240',
            8 => 'Generic film (color filters using illuminant C)',
            9 => 'BT.2020, BT.2100',
            10 => 'SMPTE 428 (CIE 1931 XYZ)', #forum14766
            11 => 'SMPTE RP 431-2',
            12 => 'SMPTE EG 432-1',
            22 => 'EBU Tech. 3213-E',
        },
    },
    9 => {
        Name => 'TransferCharacteristics',
        PrintConv => {
            0 => 'For future use (0)',
            1 => 'BT.709',
            2 => 'Unspecified',
            3 => 'For future use (3)',
            4 => 'BT.470 System M (historical)',    # Gamma 2.2? (ref forum14960)
            5 => 'BT.470 System B, G (historical)', # Gamma 2.8? (ref forum14960)
            6 => 'BT.601',
            7 => 'SMPTE 240 M',
            8 => 'Linear',
            9 => 'Logarithmic (100 : 1 range)',
            10 => 'Logarithmic (100 * Sqrt(10) : 1 range)',
            11 => 'IEC 61966-2-4',
            12 => 'BT.1361',
            13 => 'sRGB or sYCC',
            14 => 'BT.2020 10-bit systems',
            15 => 'BT.2020 12-bit systems',
            16 => 'SMPTE ST 2084, ITU BT.2100 PQ',
            17 => 'SMPTE ST 428',
            18 => 'BT.2100 HLG, ARIB STD-B67',
        },
    },
    10 => {
        Name => 'MatrixCoefficients',
        PrintConv => {
            0 => 'Identity matrix',
            1 => 'BT.709',
            2 => 'Unspecified',
            3 => 'For future use (3)',
            4 => 'US FCC 73.628',
            5 => 'BT.470 System B, G (historical)',
            6 => 'BT.601',
            7 => 'SMPTE 240 M',
            8 => 'YCgCo',
            9 => 'BT.2020 non-constant luminance, BT.2100 YCbCr',
            10 => 'BT.2020 constant luminance',
            11 => 'SMPTE ST 2085 YDzDx',
            12 => 'Chromaticity-derived non-constant luminance',
            13 => 'Chromaticity-derived constant luminance',
            14 => 'BT.2100 ICtCp',
        },
    },
    11 => {
        Name => 'VideoFullRangeFlag',
        PrintConv => { 0 => 'Limited', 1 => 'Full' },
    },
);

# viewingConditionsType (view) definition
%Image::ExifTool::ICC_Profile::ViewingConditions = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'ICC_Profile', 1 => 'ICC-view', 2 => 'Image' },
    8 => {
        Name => 'ViewingCondIlluminant',
        Format => 'fixed32s[3]',   # xyz
    },
    20 => {
        Name => 'ViewingCondSurround',
        Format => 'fixed32s[3]',   # xyz
    },
    32 => {
        Name => 'ViewingCondIlluminantType',
        Format => 'int32u',
        PrintConv => \%illuminantType,
    },
);

# measurementType (meas) definition
%Image::ExifTool::ICC_Profile::Measurement = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'ICC_Profile', 1 => 'ICC-meas', 2 => 'Image' },
    8 => {
        Name => 'MeasurementObserver',
        Format => 'int32u',
        PrintConv => {
            1 => 'CIE 1931',
            2 => 'CIE 1964',
        },
    },
    12 => {
        Name => 'MeasurementBacking',
        Format => 'fixed32s[3]',   # xyz
    },
    24 => {
        Name => 'MeasurementGeometry',
        Format => 'int32u',
        PrintConv => {
            0 => 'Unknown',
            1 => '0/45 or 45/0',
            2 => '0/d or d/0',
        },
    },
    28 => {
        Name => 'MeasurementFlare',
        Format => 'fixed32u',
        PrintConv => '$val*100 . "%"',  # change into a percent
    },
    32 => {
        Name => 'MeasurementIlluminant',
        Format => 'int32u',
        PrintConv => \%illuminantType,
    },
);

# chromaticity (chrm) definition
%Image::ExifTool::ICC_Profile::Chromaticity = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'ICC_Profile', 1 => 'ICC-chrm', 2 => 'Image' },
    8 => {
        Name => 'ChromaticityChannels',
        Format => 'int16u',
    },
    10 => {
        Name => 'ChromaticityColorant',
        Format => 'int16u',
        PrintConv => {
            0 => 'Unknown',
            1 => 'ITU-R BT.709',
            2 => 'SMPTE RP145-1994',
            3 => 'EBU Tech.3213-E',
            4 => 'P22',
        },
    },
    # include definitions for 4 channels -- if there are
    # fewer then the ProcessBinaryData logic won't print them.
    # If there are more, oh well.
    12 => {
        Name => 'ChromaticityChannel1',
        Format => 'fixed32u[2]',
    },
    20 => {
        Name => 'ChromaticityChannel2',
        Format => 'fixed32u[2]',
    },
    28 => {
        Name => 'ChromaticityChannel3',
        Format => 'fixed32u[2]',
    },
    36 => {
        Name => 'ChromaticityChannel4',
        Format => 'fixed32u[2]',
    },
);

# colorantTable (clrt) definition
%Image::ExifTool::ICC_Profile::ColorantTable = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'ICC_Profile', 1 => 'ICC-clrt', 2 => 'Image' },
    8 => {
        Name => 'ColorantCount',
        Format => 'int32u',
    },
    # include definitions for 3 colorants -- if there are
    # fewer then the ProcessBinaryData logic won't print them.
    # If there are more, oh well.
    12 => {
        Name => 'Colorant1Name',
        Format => 'string[32]',
    },
    44 => {
        Name => 'Colorant1Coordinates',
        Format => 'int16u[3]',
    },
    50 => {
        Name => 'Colorant2Name',
        Format => 'string[32]',
    },
    82 => {
        Name => 'Colorant2Coordinates',
        Format => 'int16u[3]',
    },
    88 => {
        Name => 'Colorant3Name',
        Format => 'string[32]',
    },
    120 => {
        Name => 'Colorant3Coordinates',
        Format => 'int16u[3]',
    },
);

# metadata (meta) tags
%Image::ExifTool::ICC_Profile::Metadata = (
    PROCESS_PROC => \&ProcessMetadata,
    GROUPS => { 0 => 'ICC_Profile', 1 => 'ICC-meta', 2 => 'Image' },
    VARS => { ID_FMT => 'none' },
    NOTES => q{
        Only these few tags have been pre-defined, but ExifTool will extract any
        Metadata tags that exist.
    },
    ManufacturerName => { },
    MediaColor       => { },
    MediaWeight      => { },
    CreatorApp       => { },
);

#------------------------------------------------------------------------------
# Print ICC Profile ID in hex
# Inputs: 1) string of numbers
# Returns: string of hex digits
sub HexID($)
{
    my $val = shift;
    my @vals = split(' ', $val);
    # return a simple zero if no MD5 done
    return 0 unless grep(!/^0/, @vals);
    $val = '';
    foreach (@vals) { $val .= sprintf("%.2x",$_); }
    return $val;
}

#------------------------------------------------------------------------------
# Get formatted value from ICC tag (which has the type embedded)
# Inputs: 0) data reference, 1) offset to tag data, 2) tag data size
# Returns: Formatted value or undefined if format not supported
# Notes: The following types are handled by BinaryTables:
#  chromaticityType, colorantTableType, measurementType, viewingConditionsType
# The following types are currently not handled (most are large tables):
#  curveType, lut16Type, lut8Type, lutAtoBType, lutBtoAType, namedColor2Type,
#  parametricCurveType, profileSeqDescType, responseCurveSet16Type
# The multiLocalizedUnicodeType must be handled by the calling routine.
sub FormatICCTag($$$)
{
    my ($dataPt, $offset, $size) = @_;

    my $type;
    if ($size >= 8) {
        # get data type from start of tag data
        $type = substr($$dataPt, $offset, 4);
    } else {
        $type = 'err';
    }
    # colorantOrderType
    if ($type eq 'clro' and $size >= 12) {
        my $num = Get32u($dataPt, $offset+8);
        if ($size >= $num + 12) {
            my $pos = $offset + 12;
            return join(' ',unpack("x$pos c$num", $$dataPt));
        }
    }
    # dataType
    if ($type eq 'data' and $size >= 12) {
        my $form = Get32u($dataPt, $offset+8);
        # format 0 is UTF-8 data
        $form == 0 and return substr($$dataPt, $offset+12, $size-12);
        # binary data and other data types treat as binary (ie. don't format)
    }
    # dateTimeType
    if ($type eq 'dtim' and $size >= 20) {
        return sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2d",
               Get16u($dataPt, $offset+8),  Get16u($dataPt, $offset+10),
               Get16u($dataPt, $offset+12), Get16u($dataPt, $offset+14),
               Get16u($dataPt, $offset+16), Get16u($dataPt, $offset+18));
    }
    # s15Fixed16ArrayType
    if ($type eq 'sf32') {
        return ReadValue($dataPt,$offset+8,'fixed32s',($size-8)/4,$size-8);
    }
    # signatureType
    if ($type eq 'sig ' and $size >= 12) {
        return substr($$dataPt, $offset+8, 4);
    }
    # textType
    $type eq 'text' and return substr($$dataPt, $offset+8, $size-8);
    # textDescriptionType (ref 2, replaced by multiLocalizedUnicodeType)
    if ($type eq 'desc' and $size >= 12) {
        my $len = Get32u($dataPt, $offset+8);
        if ($size >= $len + 12) {
            my $str = substr($$dataPt, $offset+12, $len);
            $str =~ s/\0.*//s;   # truncate at null terminator
            return $str;
        }
    }
    # u16Fixed16ArrayType
    if ($type eq 'uf32') {
        return ReadValue($dataPt,$offset+8,'fixed32u',($size-8)/4,$size-8);
    }
    # uInt32ArrayType
    if ($type eq 'ui32') {
        return ReadValue($dataPt,$offset+8,'int32u',($size-8)/4,$size-8);
    }
    # uInt64ArrayType
    if ($type eq 'ui64') {
        return ReadValue($dataPt,$offset+8,'int64u',($size-8)/8,$size-8);
    }
    # uInt8ArrayType
    if ($type eq 'ui08') {
        return ReadValue($dataPt,$offset+8,'int8u',$size-8,$size-8);
    }
    # XYZType
    if ($type eq 'XYZ ') {
        my $str = '';
        my $pos;
        for ($pos=8; $pos+12<=$size; $pos+=12) {
            $str and $str .= ', ';
            $str .= ReadValue($dataPt,$offset+$pos,'fixed32s',3,$size-$pos);
        }
        return $str;
    }
    return undef;   # data type is not supported
}

#------------------------------------------------------------------------------
# Process ICC metadata record (ref 5)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success
sub ProcessMetadata($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart};
    my $dirLen = $$dirInfo{DirLen};
    my $dirEnd = $dirStart + $dirLen;

    if ($dirLen < 16 or substr($$dataPt, $dirStart, 4) ne 'dict') {
        $et->Warn('Invalid ICC meta dictionary');
        return 0;
    }
    my $num = Get32u($dataPt, $dirStart + 8);
    $et->VerboseDir('Metadata', $num);
    my $size = Get32u($dataPt, $dirStart + 12);
    $size < 16 and $et->Warn('Invalid ICC meta record size'), return 0;
    # NOTE: In the example the minimum offset is 20,
    # but this doesn't jive with the table (both in ref 5)
    my $minPtr = 16 + $size * $num;
    my $index;
    for ($index=0; $index<$num; ++$index) {
        my $entry = $dirStart + 16 + $size * $index;
        if ($entry + $size > $dirEnd) {
            $et->Warn('Truncated ICC meta dictionary');
            last;
        }
        my $namePtr = Get32u($dataPt, $entry);
        my $nameLen = Get32u($dataPt, $entry + 4);
        my $valuePtr = Get32u($dataPt, $entry + 8);
        my $valueLen = Get32u($dataPt, $entry + 12);
        next unless $namePtr and $valuePtr;   # ignore if offsets are zero
        if ($namePtr < $minPtr or $namePtr + $nameLen > $dirLen or
            $valuePtr < $minPtr or $valuePtr + $valueLen > $dirLen)
        {
            $et->Warn('Corrupted ICC meta dictionary');
            last;
        }
        my $tag = substr($$dataPt, $dirStart + $namePtr, $nameLen);
        my $val = substr($$dataPt, $dirStart + $valuePtr, $valueLen);
        $tag = $et->Decode($tag, 'UTF16', 'MM', 'UTF8');
        $val = $et->Decode($val, 'UTF16', 'MM');
        # generate tagInfo if it doesn't exist
        unless ($$tagTablePtr{$tag}) {
            my $name = ucfirst $tag;
            $name =~ s/\s+(.)/\u$1/g;
            $name =~ tr/-_a-zA-Z0-9//dc;
            next unless length $name;
            $et->VPrint(0, $$et{INDENT}, "[adding $tag]\n");
            AddTagToTable($tagTablePtr, $tag, { Name => $name });
        }
        $et->HandleTag($tagTablePtr, $tag, $val);
    }
    return 1;
}

#------------------------------------------------------------------------------
# Write ICC profile file
# Inputs: 0) ExifTool object reference, 1) Reference to directory information
# Returns: 1 on success, 0 if this wasn't a valid ICC file,
#          or -1 if a write error occurred
sub WriteICC($$)
{
    my ($et, $dirInfo) = @_;
    # first make sure this is a valid ICC file (or no file at all)
    my $raf = $$dirInfo{RAF};
    my $buff;
    return 0 if $raf->Read($buff, 24) and ValidateICC(\$buff);
    # now write the new ICC
    $buff = WriteICC_Profile($et, $dirInfo);
    if (defined $buff and length $buff) {
        Write($$dirInfo{OutFile}, $buff) or return -1;
    } else {
        $et->Error('No ICC information to write');
    }
    return 1;
}

#------------------------------------------------------------------------------
# Write ICC data as a block
# Inputs: 0) ExifTool object reference, 1) source dirInfo reference,
#         2) tag table reference
# Returns: ICC data block (may be empty if no ICC data)
# Notes: Increments ExifTool CHANGED flag if changed
sub WriteICC_Profile($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access
    my $dirName = $$dirInfo{DirName} || 'ICC_Profile';
    # (don't write AsShotICCProfile or CurrentICCProfile here)
    return undef unless $dirName eq 'ICC_Profile';
    my $nvHash = $et->GetNewValueHash($Image::ExifTool::Extra{$dirName});
    my $val = $et->GetNewValue($nvHash);
    $val = '' unless defined $val;
    return undef unless $et->IsOverwriting($nvHash, $val);
    ++$$et{CHANGED};
    return $val;
}

#------------------------------------------------------------------------------
# Validate ICC data
# Inputs: 0) ICC data reference
# Returns: error string or undef on success
sub ValidateICC($)
{
    my $valPtr = shift;
    my $err;
    length($$valPtr) < 24 and return 'Invalid ICC profile';
    $profileClass{substr($$valPtr, 12, 4)} or $err = 'profile class';
    my $col = substr($$valPtr, 16, 4); # ColorSpaceData
    my $con = substr($$valPtr, 20, 4); # ConnectionSpace
    my $match = '(XYZ |Lab |Luv |YCbr|Yxy |RGB |GRAY|HSV |HLS |CMYK|CMY |[2-9A-F]CLR|nc..|\0{4})';
    $col =~ /$match/ or $err = 'color space';
    $con =~ /$match/ or $err = 'connection space';
    return $err ? "Invalid ICC profile (bad $err)" : undef;
}

#------------------------------------------------------------------------------
# Process ICC profile file
# Inputs: 0) ExifTool object reference, 1) Reference to directory information
# Returns: 1 if this was an ICC file
sub ProcessICC($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $buff;
    $raf->Read($buff, 24) == 24 or return 0;
    # check to see if this is a valid ICC profile file
    return 0 if ValidateICC(\$buff);
    $et->SetFileType();
    # read the profile
    my $size = unpack('N', $buff);
    if ($size < 128 or $size & 0x80000000) {
        $et->Error("Bad ICC Profile length ($size)");
        return 1;
    }
    $raf->Seek(0, 0);
    unless ($raf->Read($buff, $size) == $size) {
        $et->Error('Truncated ICC profile');
        return 1;
    }
    my %dirInfo = (
        DataPt => \$buff,
        DataLen => $size,
        DirStart => 0,
        DirLen => $size,
    );
    my $tagTablePtr = GetTagTable('Image::ExifTool::ICC_Profile::Main');
    return ProcessICC_Profile($et, \%dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Process ICC_Profile APP13 record
# Inputs: 0) ExifTool object reference, 1) Reference to directory information
#         2) Tag table reference (undefined to read ICC file)
# Returns: 1 on success
sub ProcessICC_Profile($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen};
    my $verbose = $et->Options('Verbose');

    return 0 if $dirLen < 4;

    # extract binary ICC_Profile data block if binary mode or requested
    if ((($$et{TAGS_FROM_FILE} and not $$et{EXCL_TAG_LOOKUP}{icc_profile}) or
        $$et{REQ_TAG_LOOKUP}{icc_profile}) and
        # (don't extract from AsShotICCProfile or CurrentICCProfile)
        (not $$dirInfo{Name} or $$dirInfo{Name} eq 'ICC_Profile'))
    {
        $et->FoundTag('ICC_Profile', substr($$dataPt, $dirStart, $dirLen));
    }

    SetByteOrder('MM');     # ICC_Profile is always big-endian

    # check length of table
    my $len = Get32u($dataPt, $dirStart);
    if ($len != $dirLen or $len < 128) {
        $et->Warn("Bad length ICC_Profile (length $len)");
        return 0 if $len < 128 or $dirLen < $len;
    }
    my $pos = $dirStart + 128;  # position at start of table
    my $numEntries = Get32u($dataPt, $pos);
    if ($numEntries < 1 or $numEntries >= 0x100
        or $numEntries * 12 + 132 > $dirLen)
    {
        $et->Warn("Bad ICC_Profile table ($numEntries entries)");
        return 0;
    }

    if ($verbose) {
        $et->VerboseDir('ICC_Profile', $numEntries, $dirLen);
        my $fakeInfo = { Name=>'ProfileHeader', SubDirectory => { } };
        $et->VerboseInfo(undef, $fakeInfo);
    }
    # increment ICC dir count
    my $dirCount = $$et{DIR_COUNT}{ICC} = ($$et{DIR_COUNT}{ICC} || 0) + 1;
    $$et{SET_GROUP1} = '+' . $dirCount if $dirCount > 1;
    # process the header block
    my %subdirInfo = (
        Name     => 'ProfileHeader',
        DataPt   => $dataPt,
        DataLen  => $$dirInfo{DataLen},
        DirStart => $dirStart,
        DirLen   => 128,
        Parent   => $$dirInfo{DirName},
        DirName  => 'Header',
    );
    my $newTagTable = GetTagTable('Image::ExifTool::ICC_Profile::Header');
    $et->ProcessDirectory(\%subdirInfo, $newTagTable);

    $pos += 4;    # skip item count
    my $index;
    for ($index=0; $index<$numEntries; ++$index) {
        my $tagID  = substr($$dataPt, $pos, 4);
        my $offset = Get32u($dataPt, $pos + 4);
        my $size   = Get32u($dataPt, $pos + 8);
        $pos += 12;
        my $tagInfo = $et->GetTagInfo($tagTablePtr, $tagID);
        # unknown tags aren't generated automatically by GetTagInfo()
        # if the tagID's aren't numeric, so we must do this manually:
        if (not $tagInfo and ($$et{OPTIONS}{Unknown} or $verbose)) {
            $tagInfo = { Unknown => 1 };
            AddTagToTable($tagTablePtr, $tagID, $tagInfo);
        }
        next unless defined $tagInfo;

        if ($offset + $size > $dirLen) {
            $et->Warn("Bad ICC_Profile table (truncated)");
            last;
        }
        my $valuePtr = $dirStart + $offset;

        my $subdir = $$tagInfo{SubDirectory};
        # format the value unless this is a subdirectory
        my ($value, $fmt);
        if ($size > 4) {
            $fmt = substr($$dataPt, $valuePtr, 4);
            # handle multiLocalizedUnicodeType
            if ($fmt eq 'mluc' and not $subdir) {
                next if $size < 28;
                my $count = Get32u($dataPt, $valuePtr + 8);
                my $recLen = Get32u($dataPt, $valuePtr + 12);
                next if $recLen < 12;
                my $i;
                for ($i=0; $i<$count; ++$i) {
                    my $recPos = $valuePtr + 16 + $i * $recLen;
                    last if $recPos + $recLen > $valuePtr + $size;
                    my $lang = substr($$dataPt, $recPos, 4);
                    my $langInfo;
                    # validate language code and change to standard case (just in case)
                    if ($lang =~ s/^([a-z]{2})([A-Z]{2})$/\L$1-\U$2/i and $lang ne 'en-US') {
                        $langInfo = Image::ExifTool::GetLangInfo($tagInfo, $lang);
                    }
                    my $strLen = Get32u($dataPt, $recPos + 4);
                    my $strPos = Get32u($dataPt, $recPos + 8);
                    last if $strPos + $strLen > $size;
                    my $str = substr($$dataPt, $valuePtr + $strPos, $strLen);
                    $str = $et->Decode($str, 'UTF16');
                    $et->HandleTag($tagTablePtr, $tagID, $str,
                        TagInfo => $langInfo || $tagInfo,
                        Table  => $tagTablePtr,
                        Index  => $index,
                        Value  => $str,
                        DataPt => $dataPt,
                        Size   => $strLen,
                        Start  => $valuePtr + $strPos,
                        Format => "type '${fmt}'",
                    );
                }
                $et->Warn("Corrupted $$tagInfo{Name} data") if $i < $count;
                next;
            }
        } else {
            $fmt = 'err ';
        }
        $value = FormatICCTag($dataPt, $valuePtr, $size) unless $subdir;
        $verbose and $et->VerboseInfo($tagID, $tagInfo,
            Table  => $tagTablePtr,
            Index  => $index,
            Value  => $value,
            DataPt => $dataPt,
            Size   => $size,
            Start  => $valuePtr,
            Format => "type '${fmt}'",
        );
        if ($subdir) {
            my $name = $$tagInfo{Name};
            undef $newTagTable;
            if ($$subdir{TagTable}) {
                $newTagTable = GetTagTable($$subdir{TagTable});
                unless ($newTagTable) {
                    warn "Unknown tag table $$subdir{TagTable}\n";
                    next;
                }
            } else {
                warn "Must specify TagTable for SubDirectory $name\n";
                next;
            }
            %subdirInfo = (
                Name     => $name,
                DataPt   => $dataPt,
                DataPos  => $$dirInfo{DataPos},
                DataLen  => $$dirInfo{DataLen},
                DirStart => $valuePtr,
                DirLen   => $size,
                DirName  => $name,
                Parent   => $$dirInfo{DirName},
            );
            my $type = $fmt;
            #### eval Validate ($type)
            if (defined $$subdir{Validate} and not eval $$subdir{Validate}) {
                $et->Warn("Invalid ICC $name data");
            } else {
                $et->ProcessDirectory(\%subdirInfo, $newTagTable, $$subdir{ProcessProc});
            }
        } elsif (defined $value) {
            $et->FoundTag($tagInfo, $value);
        } else {
            $value = substr($$dataPt, $valuePtr, $size);
            # treat unsupported formats as binary data
            $$tagInfo{ValueConv} = '\$val' unless defined $$tagInfo{ValueConv};
            $et->FoundTag($tagInfo, $value);
        }
    }
    delete $$et{SET_GROUP1};
    return 1;
}


1; # end


__END__

=head1 NAME

Image::ExifTool::ICC_Profile - Read ICC Profile meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains the definitions to read information from ICC profiles.
ICC (International Color Consortium) profiles are used to translate color
data created on one device into another device's native color space.

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.color.org/icc_specs2.html>

=item L<http://developer.apple.com/documentation/GraphicsImaging/Reference/ColorSync_Manager/ColorSync_Manager.pdf>

=item L<https://color.org/specification/ICC.2-2019.pdf>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/ICC_Profile Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
