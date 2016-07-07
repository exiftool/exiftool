#------------------------------------------------------------------------------
# File:         BuildTagLookup.pm
#
# Description:  Utility to build tag lookup tables in Image::ExifTool::TagLookup.pm
#
# Revisions:    12/31/2004 - P. Harvey Created
#               02/15/2005 - PH Added ability to generate TagNames documentation
#
# Notes:        Documentation for the tag tables may either be placed in the
#               %docs hash below or in a NOTES entry in the table itself, and
#               individual tags may have their own Notes entry.
#------------------------------------------------------------------------------

package Image::ExifTool::BuildTagLookup;

use strict;
require Exporter;

BEGIN {
    # prevent ExifTool from loading the user config file
    $Image::ExifTool::configFile = '';
    $Image::ExifTool::debug = 1; # enabled debug messages
}

use vars qw($VERSION @ISA);
use Image::ExifTool qw(:Utils :Vars);
use Image::ExifTool::Exif;
use Image::ExifTool::Shortcuts;
use Image::ExifTool::HTML qw(EscapeHTML);
use Image::ExifTool::IPTC;
use Image::ExifTool::XMP;
use Image::ExifTool::Canon;
use Image::ExifTool::Nikon;

$VERSION = '2.96';
@ISA = qw(Exporter);

sub NumbersFirst($$);
sub SortedTagTablekeys($);

# global variables to control sorting order of table entries
my $numbersFirst = 1;   # set to -1 to sort numbers last, or 2 to put negative numbers last
my $caseInsensitive;    # flag to ignore case when sorting tag names

# list of all tables in plug-in modules
my @pluginTables = ('Image::ExifTool::MWG::Composite');

# colors for html pages
my $noteFont = "<span class=n>";
my $noteFontSmall = "<span class='n s'>";

my $docType = q{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
        "http://www.w3.org/TR/html4/loose.dtd">
};

my $homePage = 'http://owl.phy.queensu.ca/~phil/exiftool';

# tweak the ordering of tables in the documentation
my %tweakOrder = (
  # this    => comes after this
  # -------    -----------------
    JPEG    => '-',     # JPEG comes first
    IPTC    => 'Exif',  # put IPTC after EXIF,
    GPS     => 'XMP',   # etc...
    Composite => 'Extra',
    GeoTiff => 'GPS',
    CanonVRD=> 'CanonCustom',
    FLIR    => 'Casio',
    FujiFilm => 'FLIR',
    Kodak   => 'JVC',
   'Kodak::IFD' => 'Kodak::Unknown',
   'Kodak::TextualInfo' => 'Kodak::IFD',
   'Kodak::Processing' => 'Kodak::TextualInfo',
    Leaf    => 'Kodak',
    Minolta => 'Leaf',
    Motorola => 'Minolta',
    Nikon   => 'Motorola',
    NikonCustom => 'Nikon',
    NikonCapture => 'NikonCustom',
    Nintendo => 'NikonCapture',
    Pentax  => 'Panasonic',
    SonyIDC => 'Sony',
    Unknown => 'SonyIDC',
    DNG     => 'Unknown',
    PrintIM => 'ICC_Profile',
    Vorbis  => 'Ogg',
    ID3     => 'PostScript',
    MinoltaRaw => 'KyoceraRaw',
    KyoceraRaw => 'CanonRaw',
    SigmaRaw => 'PanasonicRaw',
    Lytro   => 'SigmaRaw',
    PhotoMechanic => 'FotoStation',
    Microsoft     => 'PhotoMechanic',
   'Microsoft::MP'=> 'Microsoft::MP1',
    GIMP    => 'Microsoft',
   'Nikon::CameraSettingsD300' => 'Nikon::ShotInfoD300b',
   'Pentax::LensData' => 'Pentax::LensInfo2',
   'Sony::SRF2' => 'Sony::SRF',
    DarwinCore => 'AFCP',
   'MWG::Regions' => 'MWG::Composite',
   'MWG::Keywords' => 'MWG::Regions',
   'MWG::Collections' => 'MWG::Keywords',
);

# list of all recognized Format strings
# (not a complete list, but this is all we use so far)
# (also, formats like "var_X[Y]" are allowed for any valid X)
my %formatOK = (
    %Image::ExifTool::Exif::formatNumber,
    0 => 1,
    1 => 1,
    real    => 1,
    integer => 1,
    date    => 1,
    boolean => 1,
    rational  => 1,
   'lang-alt' => 1,
    fixed16u => 1,
    fixed16s => 1,
    fixed32u => 1,
    fixed32s => 1,
    extended => 1,
    resize   => 1,
    digits   => 1,
    int16uRev => 1,
    int32uRev => 1,
    rational32u => 1,
    rational32s => 1,
    pstring     => 1,
    var_string  => 1,
    var_int16u  => 1,
    var_pstr32  => 1,
    var_ustr32  => 1,
    var_ue7     => 1, # (BPG)
    # Matroska
    signed      => 1,
    unsigned    => 1,
    utf8        => 1,
);

# Descriptions for the TagNames documentation
# (descriptions may also be defined in tag table NOTES)
# Note: POD headers in these descriptions start with '~' instead of '=' to keep
# from confusing POD parsers which apparently parse inside quoted strings.
my %docs = (
    PodHeader => q{
~head1 NAME

Image::ExifTool::TagNames - ExifTool tag name documentation

~head1 DESCRIPTION

This document contains a complete list of ExifTool tag names, organized into
tables based on information type.  Tag names are used to reference specific
meta information extracted from or written to a file.

~head1 TAG TABLES
},
    ExifTool => q{
The tables listed below give the names of all tags recognized by ExifTool.
},
    ExifTool2 => q{
B<Tag ID>, B<Index#> or B<Sequence> is given in the first column of each
table.  A B<Tag ID> is the computer-readable equivalent of a tag name, and
is the identifier that is actually stored in the file.  B<Index#> refers to
the location of a value when found at a fixed position within a data block
(B<#> is the multiplier for calculating a byte offset: B<1>, B<2> or B<4>).
B<Sequence> gives the order of values for a serial data stream.

A B<Tag Name> is the handle by which the information is accessed in
ExifTool.  In some instances, more than one name may correspond to a single
tag ID.  In these cases, the actual name used depends on the context in
which the information is found.  Case is not significant for tag names.  A
question mark (C<?>) after a tag name indicates that the information is
either not understood, not verified, or not very useful -- these tags are
not extracted by ExifTool unless the Unknown (-u) option is enabled.  Be
aware that some tag names are different than the descriptions printed out by
default when extracting information with exiftool.  To see the tag names
instead of the descriptions, use C<exiftool -s>.

The B<Writable> column indicates whether the tag is writable by ExifTool.
Anything but an C<N> in this column means the tag is writable.  A C<Y>
indicates writable information that is either unformatted or written using
the existing format.  Other expressions give details about the information
format, and vary depending on the general type of information.  The format
name may be followed by a number in square brackets to indicate the number
of values written, or the number of characters in a fixed-length string
(including a null terminator which is added if required).

A plus sign (C<+>) after an entry in the B<Writable> column indicates a
"list" tag which supports multiple values and allows individual values to be
added and deleted.  A slash (C</>) indicates an "avoided" tag that is not
created when writing if another same-named tag may be created instead.  To
write these tags, the group should be specified.  A tilde (C<~>) indicates a
tag this is writable only when the print conversion is disabled (by setting
PrintConv to 0, using the -n option, or suffixing the tag name with a C<#>
character).  An exclamation point (C<!>) indicates a tag that is considered
unsafe to write under normal circumstances.  These "unsafe" tags are not
written unless specified explicitly (ie. wildcards and "all" may not be
used), and care should be taken when editing them manually since they may
affect the way an image is rendered.  An asterisk (C<*>) indicates a
"protected" tag which is not writable directly, but is written automatically
by ExifTool (often when a corresponding Composite or Extra tag is written).
A colon (C<:>) indicates a mandatory tag which may be added automatically
when writing.

The HTML version of these tables also lists possible B<Values> for
discrete-valued tags, as well as B<Notes> for some tags.  The B<Values> are
listed as the computer-readable and human-readable values on the left and
right hand side of an equals sign (C<=>) respectively.  The human-readable
values are used by default when reading and writing, but the
computer-readable values may be accessed by disabling the value conversion
with the -n option on the command line, by setting the ValueConv option to 0
in the API, or or on a per-tag basis by adding a hash (C<#>) after the tag
name.

B<Note>: If you are familiar with common meta-information tag names, you may
find that some ExifTool tag names are different than expected.  The usual
reason for this is to make the tag names more consistent across different
types of meta information.  To determine a tag name, either consult this
documentation or run C<exiftool -s> on a file containing the information in
question.

I<(This documentation is the result of years of research, testing and
reverse engineering, and is the most complete metadata tag list available
anywhere on the internet.  It is provided not only for ExifTool users, but
more importantly as a public service to help augment the collective
knowledge, and is often used as a primary source of information in the
development of other metadata software.  Please help keep this documentation
as accurate and complete as possible, and feed any new discoveries back to
ExifTool.  A big thanks to everyone who has helped with this so far!)>
},
    EXIF => q{
EXIF stands for "Exchangeable Image File Format".  This type of information
is formatted according to the TIFF specification, and may be found in JPG,
TIFF, PNG, JP2, PGF, MIFF, HDP, PSP and XCF images, as well as many
TIFF-based RAW images, and even some AVI and MOV videos.

The EXIF meta information is organized into different Image File Directories
(IFD's) within an image.  The names of these IFD's correspond to the
ExifTool family 1 group names.  When writing EXIF information, the default
B<Group> listed below is used unless another group is specified.

The table below lists all EXIF tags.  Also listed are TIFF, DNG, HDP and
other tags which are not part of the EXIF specification, but may co-exist
with EXIF tags in some images.  Tags which are part of the EXIF 2.3
specification have an underlined B<Tag Name> in the HTML version of this
documentation.  See
L<http://www.cipa.jp/std/documents/e/DC-008-2012_E.pdf> for the official
EXIF 2.3 specification.
},
    GPS => q{
These GPS tags are part of the EXIF standard, and are stored in a separate
IFD within the EXIF information.

ExifTool is very flexible about the input format when writing lat/long
coordinates, and will accept from 1 to 3 floating point numbers (for decimal
degrees, degrees and minutes, or degrees, minutes and seconds) separated by
just about anything, and will format them properly according to the EXIF
specification.

Some GPS tags have values which are fixed-length strings. For these, the
indicated string lengths include a null terminator which is added
automatically by ExifTool.  Remember that the descriptive values are used
when writing (eg. 'Above Sea Level', not '0') unless the print conversion is
disabled (with '-n' on the command line or the PrintConv option in the API,
or by suffixing the tag name with a C<#> character).

When adding GPS information to an image, it is important to set all of the
following tags: GPSLatitude, GPSLatitudeRef, GPSLongitude, GPSLongitudeRef,
and GPSAltitude and GPSAltitudeRef if the altitude is known.  ExifTool will
write the required GPSVersionID tag automatically if new a GPS IFD is added
to an image.
},
    XMP => q{
XMP stands for "Extensible Metadata Platform", an XML/RDF-based metadata
format which is being pushed by Adobe.  Information in this format can be
embedded in many different image file types including JPG, JP2, TIFF, GIF,
EPS, PDF, PSD, IND, INX, PNG, DJVU, SVG, PGF, MIFF, XCF, CRW, DNG and a
variety of proprietary TIFF-based RAW images, as well as MOV, AVI, ASF, WMV,
FLV, SWF and MP4 videos, and WMA and audio formats supporting ID3v2
information.

The XMP B<Tag ID>'s aren't listed because in most cases they are identical
to the B<Tag Name> (aside from differences in case).  Tags with different
ID's are mentioned in the B<Notes> column of the HTML version of this
document.

All XMP information is stored as character strings.  The B<Writable> column
specifies the information format:  C<string> is an unformatted string,
C<integer> is a string of digits (possibly beginning with a '+' or '-'),
C<real> is a floating point number, C<rational> is entered as a floating
point number but stored as two C<integer> strings separated by a '/'
character, C<date> is a date/time string entered in the format "YYYY:mm:dd
HH:MM:SS[.ss][+/-HH:MM]", C<boolean> is either "True" or "False", C<struct>
indicates a structured tag, and C<lang-alt> is a tag that supports alternate
languages.

When reading, C<struct> tags are extracted only if the Struct (-struct)
option is used.  Otherwise the corresponding "flattened" tags, indicated by
an underline (C<_>) after the B<Writable> type, are extracted.  When
copying, by default both structured and flattened tags are available, but
the flattened tags are considered "unsafe" so they they aren't copied unless
specified explicitly.  The Struct option may be disabled by setting Struct
to 0 via the API or with --struct on the command line to copy only flattened
tags, or enabled by setting Struct to 1 via the API or with -struct on the
command line to copy only as structures.  When writing, the Struct option
has no effect, and both structured and flattened tags may be written.  See
L<http://owl.phy.queensu.ca/~phil/exiftool/struct.html> for more details.

Individual languages for C<lang-alt> tags are accessed by suffixing the tag
name with a '-', followed by an RFC 3066 language code (eg. "XMP:Title-fr",
or "Rights-en-US").  (See L<http://www.ietf.org/rfc/rfc3066.txt> for the RFC
3066 specification.)  A C<lang-alt> tag with no language code accesses the
"x-default" language, but causes other languages for this tag to be deleted
when writing.  The "x-default" language code may be specified when writing
to preserve other existing languages (eg. "XMP-dc:Description-x-default"). 
When reading, "x-default" is not specified.

The XMP tags are organized according to schema B<Namespace> in the following
tables.  Note that a few of the longer namespace prefixes given below have
been shortened for convenience (since the family 1 group names are derived
from these by adding a leading "XMP-").  In cases where a tag name exists in
more than one namespace, less common namespaces are avoided when writing.
However, any namespace may be written by specifying a family 1 group name
for the tag, eg) XMP-exif:Contrast or XMP-crs:Contrast.  When deciding on
which tags to add to an image, using standard schemas such as
L<dc|/XMP dc Tags>, L<xmp|/XMP xmp Tags>, L<iptcCore|/XMP iptcCore Tags>
and L<iptcExt|/XMP iptcExt Tags> is recommended if possible.

For structures, the heading of the first column is B<Field Name>.  Field
names are very similar to tag names, except they are used to identify fields
inside structures instead of stand-alone tags.  See
L<the Field Name section of the Structured Information documentation|http://owl.phy.queensu.ca/~phil/exiftool/struct.html#Fields> for more
details.

ExifTool will extract XMP information even if it is not listed in these
tables, but other tags are not writable unless added as user-defined tags in
the L<ExifTool config file|../config.html>.  For example, the C<pdfx> namespace doesn't have a
predefined set of tag names because it is used to store application-defined
PDF information, so although this information will be extracted, it is only
writable if the corresponding user-defined tags have been created.

The tables below list tags from the official XMP specification (with an
underlined B<Namespace> in the HTML version of this documentation), as well
as extensions from various other sources.  See
L<http://www.adobe.com/devnet/xmp/> for the official XMP specification.
},
    IPTC => q{
The tags listed below are part of the International Press Telecommunications
Council (IPTC) and the Newspaper Association of America (NAA) Information
Interchange Model (IIM).  This is an older meta information format, slowly
being phased out in favor of XMP -- the newer IPTCCore specification uses
XMP format.  IPTC information may be found in JPG, TIFF, PNG, MIFF, PS, PDF,
PSD, XCF and DNG images.

IPTC information is separated into different records, each of which has its
own set of tags.  See
L<http://www.iptc.org/std/IIM/4.1/specification/IIMV4.1.pdf> for the
official IPTC IIM specification.

This specification dictates a length for ASCII (C<string> or C<digits>) and
binary (C<undef>) values.  These lengths are given in square brackets after
the B<Writable> format name.  For tags where a range of lengths is allowed,
the minimum and maximum lengths are separated by a comma within the
brackets.  IPTC strings are not null terminated.  When writing, ExifTool
issues a minor warning and truncates the value if it is longer than allowed
by the IPTC specification.  Minor errors may be ignored with the
IgnoreMinorErrors (-m) option, allowing longer values to be written, but
beware that values like this may cause problems for some other IPTC readers.
ExifTool will happily read IPTC values of any length.

Separate IPTC date and time tags may be written with a combined date/time
value and ExifTool automagically takes the appropriate part of the date/time
string depending on whether a date or time tag is being written.  This is
very useful when copying date/time values to IPTC from other metadata
formats.

IPTC time values include a timezone offset.  If written with a value which
doesn't include a timezone then the current local timezone offset is used
(unless written with a combined date/time, in which case the local timezone
offset at the specified date/time is used, which may be different due to
changes in daylight savings time).

Note that it is not uncommon for IPTC to be found in non-standard locations
in JPEG and TIFF-based images.  When reading, the family 1 group name has a
number added for non-standard IPTC ("IPTC2", "IPTC3", etc), but when writing
only "IPTC" may be specified as the group.  To keep the IPTC consistent,
ExifTool updates tags in all existing IPTC locations, but will create a new
IPTC group only in the standard location.
},
    Photoshop => q{
Photoshop tags are found in PSD and PSB files, as well as inside embedded
Photoshop information in many other file types (JPEG, TIFF, PDF, PNG to name
a few).

Many Photoshop tags are marked as Unknown (indicated by a question mark
after the tag name) because the information they provide is not very useful
under normal circumstances.  These unknown tags are not extracted unless the
Unknown (-u) option is used.  See
L<http://www.adobe.com/devnet-apps/photoshop/fileformatashtml/> for the
official specification

Photoshop path tags (Tag ID's 0x7d0 to 0xbb5) are not defined by default,
but a config file included in the full ExifTool distribution
(config_files/photoshop_paths.config) contains the tag definitions to allow
access to this information.
},
    PrintIM => q{
The format of the PrintIM information is known, however no PrintIM tags have
been decoded.  Use the Unknown (-u) option to extract PrintIM information.
},
    GeoTiff => q{
ExifTool extracts the following tags from GeoTIFF images.  See
L<http://www.remotesensing.org/geotiff/spec/geotiffhome.html> for the
complete GeoTIFF specification.  Also included in the table below are
ChartTIFF tags (see L<http://www.charttiff.com/whitepapers.shtml>). GeoTIFF
tags are not writable individually, but they may be copied en mass via the
block tags GeoTiffDirectory, GeoTiffDoubleParams and GeoTiffAsciiParams.
},
    JFIF => q{
The following information is extracted from the JPEG JFIF header.  See
L<https://www.w3.org/Graphics/JPEG/jfif3.pdf> for the JFIF 1.02
specification.
},
    Kodak => q{
Many Kodak models don't store the maker notes in standard IFD format, and
these formats vary with different models.  Some information has been
decoded, but much of the Kodak information remains unknown.
},
    'Kodak SpecialEffects' => q{
The Kodak SpecialEffects and Borders tags are found in sub-IFD's within the
Kodak JPEG APP3 "Meta" segment.
},
    Minolta => q{
These tags are used by Minolta, Konica/Minolta as well as some Sony cameras.
Minolta doesn't make things easy for decoders because the meaning of some
tags and the location where some information is stored is different for
different camera models.  (Take MinoltaQuality for example, which may be
located in 5 different places.)
},
    Olympus => q{
Tags 0x0000 through 0x0103 are used by some older Olympus cameras, and are
the same as Konica/Minolta tags.  These tags are also used for some models
from other brands such as Acer, BenQ, Epson, Hitachi, HP, Maginon, Minolta,
Pentax, Ricoh, Samsung, Sanyo, SeaLife, Sony, Supra and Vivitar.
},
    Panasonic => q{
These tags are used in Panasonic/Leica cameras.
},
    Pentax => q{
These tags are used in Pentax/Asahi cameras.
},
    CanonRaw => q{
These tags apply to CRW-format Canon RAW files and information in the APP0
"CIFF" segment of JPEG images.  When writing CanonRaw/CIFF information, the
length of the information is preserved (and the new information is truncated
or padded as required) unless B<Writable> is C<resize>. Currently, only
JpgFromRaw and ThumbnailImage are allowed to change size.

CRW images also support the addition of a CanonVRD trailer, which in turn
supports XMP.  This trailer is created automatically if necessary when
ExifTool is used to write XMP to a CRW image.
},
    NikonCustom => q{
Unfortunately, the NikonCustom settings are stored in a binary data block
which changes from model to model.  This means that significant effort must
be spent in decoding these for each model, usually requiring hundreds of
test images from a dedicated Nikon owner.  For this reason, the NikonCustom
settings have not been decoded for all models.  The tables below list the
custom settings for the currently supported models.
},
    Unknown => q{
The following tags are decoded in unsupported maker notes.  Use the Unknown
(-u) option to display other unknown tags.
},
    PDF => q{
The tags listed in the PDF tables below are those which are used by ExifTool
to extract meta information, but they are only a small fraction of the total
number of available PDF tags.  See
L<http://www.adobe.com/devnet/pdf/pdf_reference.html> for the official PDF
specification.

ExifTool supports reading and writing PDF documents up to version 1.7
extension level 3, including support for RC4, AES-128 and AES-256
encryption.  A Password option is provided to allow processing of
password-protected PDF files.

ExifTool may be used to write native PDF and XMP metadata to PDF files. It
uses an incremental update technique that has the advantages of being both
fast and reversible.  The original PDF can be easily recovered by deleting
the C<PDF-update> pseudo-group (with C<-PDF-update:all=> on the command
line).  However, there are two main disadvantages to this technique:

1) A linearized PDF file is no longer linearized after the update, so it
must be subsequently re-linearized if this is required.

2) All metadata edits are reversible.  While this would normally be
considered an advantage, it is a potential security problem because old
information is never actually deleted from the file.
},
    DNG => q{
The main DNG tags are found in the EXIF table.  The tables below define only
information found within structures of these main DNG tag values.  See
L<http://www.adobe.com/products/dng/> for the official DNG specification.
},
    MPEG => q{
The MPEG format doesn't specify any file-level meta information.  In lieu of
this, information is extracted from the first audio and video frame headers
in the file.
},
    Real => q{
ExifTool recognizes three basic types of Real audio/video files: 1)
RealMedia (RM, RV and RMVB), 2) RealAudio (RA), and 3) Real Metafile (RAM
and RPM).
},
    Extra => q{
The extra tags represent extra information extracted or generated by
ExifTool that is not directly associated with another tag group.  The
B<Group> column lists the family 1 group name when reading.  Tags with a "-"
in this column are write-only.

Tags in the family 1 "System" group are referred to as "pseudo" tags because
they don't represent real metadata in the file.  Instead, this information
is stored in the directory structure of the filesystem.  The five writable
"pseudo" tags (FileName, Directory, FileModifyDate, FileCreateDate and
HardLink) may be written without modifying the file itself.  The TestName
tag is used for dry-run testing before writing FileName.
},
    Composite => q{
The values of the composite tags are B<Derived From> the values of other
tags.  These are convenience tags which are calculated after all other
information is extracted.  Only a few of these tags are writable directly,
the others are changed by writing the corresponding B<Derived From> tags.
User-defined Composite tags, also useful for custom-formatting of tag
values, may created via the L<ExifTool configuration file|../config.html>.
},
    Shortcuts => q{
Shortcut tags are convenience tags that represent one or more other tag
names.  They are used like regular tags to read and write the information
for a specified set of tags.

The shortcut tags below have been pre-defined, but user-defined shortcuts
may be added via the %Image::ExifTool::UserDefined::Shortcuts lookup in the
~/.ExifTool_config file.  See the Image::ExifTool::Shortcuts documentation
for more details.
},
    MWG => q{
The Metadata Working Group (MWG) recommends techniques to allow certain
overlapping EXIF, IPTC and XMP tags to be reconciled when reading, and
synchronized when writing.  The MWG Composite tags below are designed to aid
in the implementation of these recommendations.  As well, the MWG defines
new XMP tags which are listed in the subsequent tables below.  See
L<http://www.metadataworkinggroup.org/> for the official MWG specification.
},
    PodTrailer => q{
~head1 NOTES

This document generated automatically by
L<Image::ExifTool::BuildTagLookup|Image::ExifTool::BuildTagLookup>.

~head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

~head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

~cut
},
);

# notes for Shortcuts tags
my %shortcutNotes = (
    AllDates => q{
        contrary to the shortcut name, this represents only the common EXIF
        date/time tags.  To access all date/time tags, use Time:All instead
    },
    MakerNotes => q{
        useful when copying tags between files to either copy the maker notes as a
        block or prevent it from being copied
    },
    ColorSpaceTags => q{
        standard tags which carry color space information.  Useful for preserving
        color space when deleting all other metadata
    },
    CommonIFD0 => q{
        common metadata tags found in IFD0 of TIFF-format images.  Used to simpify
        deletion of all metadata from these images.  See
        L<FAQ number 7|../faq.html#Q7> for details
    },
    Unsafe => q{
        "unsafe" tags in JPEG images which are normally not copied.  Defined here
        as a shortcut to use when rebuilding JPEG EXIF from scratch. See
        L<FAQ number 20|../faq.html#Q20> for more information
    },
    LargeTags => q{
        large binary data tags which may be excluded to reduce memory usage if
        memory limitations are a problem
    },
);



# EXIF table tag ID's which are part of the EXIF 2.3 specification
# (used only to add underlines in HTML version of EXIF Tag Table)
my %exifSpec = (
    0x100 => 1,  0x212 => 1,   0x9204 => 1,  0xa217 => 1,
    0x101 => 1,  0x213 => 1,   0x9205 => 1,  0xa300 => 1,
    0x102 => 1,  0x214 => 1,   0x9206 => 1,  0xa301 => 1,
    0x103 => 1,  0x8298 => 1,  0x9207 => 1,  0xa302 => 1,
    0x106 => 1,  0x829a => 1,  0x9208 => 1,  0xa401 => 1,
    0x10e => 1,  0x829d => 1,  0x9209 => 1,  0xa402 => 1,
    0x10f => 1,  0x8769 => 1,  0x920a => 1,  0xa403 => 1,
    0x110 => 1,  0x8822 => 1,  0x9214 => 1,  0xa404 => 1,
    0x111 => 1,  0x8824 => 1,  0x927c => 1,  0xa405 => 1,
    0x112 => 1,  0x8825 => 1,  0x9286 => 1,  0xa406 => 1,
    0x115 => 1,  0x8827 => 1,  0x9290 => 1,  0xa407 => 1,
    0x116 => 1,  0x8828 => 1,  0x9291 => 1,  0xa408 => 1,
    0x117 => 1,  0x8830 => 1,  0x9292 => 1,  0xa409 => 1,
    0x11a => 1,  0x8831 => 1,  0xa000 => 1,  0xa40a => 1,
    0x11b => 1,  0x8832 => 1,  0xa001 => 1,  0xa40b => 1,
    0x11c => 1,  0x8833 => 1,  0xa002 => 1,  0xa40c => 1,
    0x128 => 1,  0x8834 => 1,  0xa003 => 1,  0xa420 => 1,
    0x12d => 1,  0x8835 => 1,  0xa004 => 1,  0xa430 => 1,
    0x131 => 1,  0x9000 => 1,  0xa005 => 1,  0xa431 => 1,
    0x132 => 1,  0x9003 => 1,  0xa20b => 1,  0xa432 => 1,
    0x13b => 1,  0x9004 => 1,  0xa20c => 1,  0xa433 => 1,
    0x13e => 1,  0x9101 => 1,  0xa20e => 1,  0xa434 => 1,
    0x13f => 1,  0x9102 => 1,  0xa20f => 1,  0xa435 => 1,
    0x201 => 1,  0x9201 => 1,  0xa210 => 1,
    0x202 => 1,  0x9202 => 1,  0xa214 => 1,
    0x211 => 1,  0x9203 => 1,  0xa215 => 1,
);
# same thing for RIFF INFO tags found in the EXIF spec
my %riffSpec = (
    IARL => 1,  ICRD => 1,  IGNR => 1,  IPLT => 1,  ISRC => 1,
    IART => 1,  ICRP => 1,  IKEY => 1,  IPRD => 1,  ISRF => 1,
    ICMS => 1,  IDIM => 1,  ILGT => 1,  ISBJ => 1,  ITCH => 1,
    ICMT => 1,  IDPI => 1,  IMED => 1,  ISFT => 1,
    ICOP => 1,  IENG => 1,  INAM => 1,  ISHP => 1,
);
# same thing for XMP namespaces
my %xmpSpec = (
    aux       => 1,   'x'        => 1,
    crs       => 1,    xmp       => 1,
    dc        => 1,    xmpBJ     => 1,
    exif      => 1,    xmpDM     => 1,
    pdf       => 1,    xmpMM     => 1,
    pdfx      => 1,    xmpNote   => 1,
    photoshop => 1,    xmpRights => 1,
    tiff      => 1,    xmpTPg    => 1,
);

#------------------------------------------------------------------------------
# New - create new BuildTagLookup object
# Inputs: 0) reference to BuildTagLookup object or BuildTagLookup class name
sub new
{
    local $_;
    my $that = shift;
    my $class = ref($that) || $that || 'Image::ExifTool::BuildTagLookup';
    my $self = bless {}, $class;
    my (%subdirs, %isShortcut, %allStructs);
    my %count = (
        'unique tag names' => 0,
        'total tags' => 0,
    );
#
# loop through all tables, accumulating TagLookup and TagName information
#
    my (%tagNameInfo, %id, %longID, %longName, %shortName, %tableNum,
        %tagLookup, %tagExists, %noLookup, %tableWritable, %sepTable, %case,
        %structs, %compositeModules, %isPlugin, %flattened, %structLookup);
    $self->{TAG_NAME_INFO} = \%tagNameInfo;
    $self->{ID_LOOKUP} = \%id;
    $self->{LONG_ID} = \%longID;
    $self->{LONG_NAME} = \%longName;
    $self->{SHORT_NAME} = \%shortName;
    $self->{TABLE_NUM} = \%tableNum;
    $self->{TAG_LOOKUP} = \%tagLookup;
    $self->{TAG_EXISTS} = \%tagExists;
    $self->{FLATTENED} = \%flattened;
    $self->{TABLE_WRITABLE} = \%tableWritable;
    $self->{SEPARATE_TABLE} = \%sepTable;
    $self->{STRUCTURES} = \%structs;
    $self->{STRUCT_LOOKUP} = \%structLookup;  # lookup for Struct hash ref based on Struct name
    $self->{COMPOSITE_MODULES} = \%compositeModules;
    $self->{COUNT} = \%count;

    Image::ExifTool::LoadAllTables();
    my @tableNames = sort keys %allTables;
    # add Shortcuts after other tables
    push @tableNames, 'Image::ExifTool::Shortcuts::Main';
    # add plug-in modules last
    foreach (@pluginTables) {
        push @tableNames, $_;
        $isPlugin{$_} = 1;
    }

    my $tableNum = 0;
    my $et = new Image::ExifTool;
    my ($tableName, $tag);
    # create lookup for short table names
    foreach $tableName (@tableNames) {
        my $short = $tableName;
        $short =~ s/^Image::ExifTool:://;
        $short =~ s/::Main$//;
        $short =~ s/::/ /;
        $short =~ s/^(.+)Tags$/\u$1/ unless $short eq 'Nikon AVITags';
        $short =~ s/^Exif\b/EXIF/;
        # change underlines to dashes in XMP-mwg group names
        # (we used underlines just because Perl variables can't contain dashes)
        $short =~ s/^XMP mwg_/XMP mwg-/;
        $shortName{$tableName} = $short;    # remember short name
        $tableNum{$tableName} = $tableNum++;
    }
    # validate DICOM UID values
    foreach (values %Image::ExifTool::DICOM::uid) {
        next unless /[\0-\x1f\x7f-\xff]/;
        warn "Warning: Special characters in DICOM UID value ($_)\n";
    }
    # make lookup table to check for shortcut tags
    foreach $tag (keys %Image::ExifTool::Shortcuts::Main) {
        my $entry = $Image::ExifTool::Shortcuts::Main{$tag};
        # ignore if shortcut tag name includes itself
        next if ref $entry eq 'ARRAY' and grep /^$tag$/, @$entry;
        $isShortcut{lc($tag)} = 1;
    }
    foreach $tableName (@tableNames) {
        # create short table name
        my $short = $shortName{$tableName};
        my $info = $tagNameInfo{$tableName} = [ ];
        my $isPlugin = $isPlugin{$tableName};
        my ($table, $shortcut, %isOffset, %datamember, %hasSubdir);
        if ($short eq 'Shortcuts') {
            # can't use GetTagTable() for Shortcuts (not a normal table)
            $table = \%Image::ExifTool::Shortcuts::Main;
            $shortcut = 1;
        } elsif ($isPlugin) {
            $table = GetTagTable($tableName);
            # don't add to allTables list because this messes our table order
            delete $allTables{$tableName};
            pop @tableOrder;
        } else {
            $table = GetTagTable($tableName);
        }
        my $tableNum = $tableNum{$tableName};
        my $writeProc = $$table{WRITE_PROC};
        my $vars = $$table{VARS} || { };
        $longID{$tableName} = 0;
        $longName{$tableName} = 0;
        # save all tag names
        my ($tagID, $binaryTable, $noID, $hexID, $isIPTC, $isXMP);
        $isIPTC = 1 if $writeProc and $writeProc eq \&Image::ExifTool::IPTC::WriteIPTC;
        # generate flattened tag names for structure fields if this is an XMP table
        if ($$table{GROUPS} and $$table{GROUPS}{0} eq 'XMP') {
            Image::ExifTool::XMP::AddFlattenedTags($table);
            $isXMP = 1;
        }
        $noID = 1 if $isXMP or $short =~ /^(Shortcuts|ASF.*)$/ or $$vars{NO_ID};
        $hexID = $$vars{HEX_ID};
        my $processBinaryData = ($$table{PROCESS_PROC} and (
            $$table{PROCESS_PROC} eq \&Image::ExifTool::ProcessBinaryData or
            $$table{PROCESS_PROC} eq \&Image::ExifTool::Nikon::ProcessNikonEncrypted));
        if ($$vars{ID_LABEL} or $processBinaryData) {
            my $s = $$table{FORMAT} ? Image::ExifTool::FormatSize($$table{FORMAT}) || 1 : 1;
            $binaryTable = 1;
            $id{$tableName} = $$vars{ID_LABEL} || "Index$s";
        } elsif ($isIPTC and $$table{PROCESS_PROC}) { #only the main IPTC table has a PROCESS_PROC
            $id{$tableName} = 'Record';
        } elsif (not $noID) {
            $id{$tableName} = 'Tag ID';
        }
        $caseInsensitive = $isXMP;
        $numbersFirst = 2;
        $numbersFirst = -1 if $$table{VARS} and $$table{VARS}{ALPHA_FIRST};
        my @keys = SortedTagTableKeys($table);
        $numbersFirst = 1;
        my $defFormat = $table->{FORMAT};
        # use default format for binary data tables
        $defFormat = 'int8u' if not $defFormat and $binaryTable;

TagID:  foreach $tagID (@keys) {
            my ($tagInfo, @tagNames, $subdir, @values);
            my (@infoArray, @require, @writeGroup, @writable);
            if ($shortcut) {
                # must build a dummy tagInfo list since Shortcuts is not a normal table
                $tagInfo = {
                    Name => $tagID,
                    Notes => $shortcutNotes{$tagID},
                    Writable => 1,
                    Require => { },
                };
                my $i;
                for ($i=0; $i<@{$$table{$tagID}}; ++$i) {
                    $tagInfo->{Require}->{$i} = $table->{$tagID}->[$i];
                }
                @infoArray = ( $tagInfo );
            } else {
                @infoArray = GetTagInfoList($table,$tagID);
            }
            foreach $tagInfo (@infoArray) {
                my $name = $$tagInfo{Name};
                unless ($$tagInfo{SubDirectory} or $$tagInfo{Struct}) {
                    my $lc = lc $name;
                    warn "Different case for $tableName $name $case{$lc}\n" if $case{$lc} and $case{$lc} ne $name;
                    $case{$lc} = $name;
                }
                my $format = $$tagInfo{Format};
                # validate Name (must not start with a digit or else XML output will not be valid)
                # (must not start with a dash or exiftool command line may get confused)
                if ($name !~ /^[_A-Za-z][-\w]+$/ and
                    # single-character subdirectory names are allowed
                    (not $$tagInfo{SubDirectory} or $name !~ /^[_A-Za-z]$/))
                {
                    warn "Warning: Invalid tag name $short '$name'\n";
                }
                # validate list type
                if ($$tagInfo{List} and $$tagInfo{List} !~ /^(1|Alt|Bag|Seq|array|string)$/) {
                    warn "Warning: Unknown List type ($$tagInfo{List}) for $name in $tableName\n";
                }
                # accumulate information for consistency check of BinaryData tables
                if ($processBinaryData and $$table{WRITABLE}) {
                    # can't currently write tag if Condition accesses $valPt
                    if ($$tagInfo{Condition} and not $$tagInfo{SubDirectory} and
                        $$tagInfo{Condition} =~ /\$valPt/ and
                        ($$tagInfo{Writable} or not defined $$tagInfo{Writable}))
                    {
                        warn "Warning: Tag not writable due to Condition - $short $name\n";
                    }
                    $isOffset{$tagID} = $name if $$tagInfo{IsOffset};
                    $hasSubdir{$tagID} = $name if $$tagInfo{SubDirectory};
                    # require DATAMEMBER for writable var-format tags, Hook and DataMember tags
                    if ($format and $format =~ /^var_/) {
                        $datamember{$tagID} = $name;
                        unless (defined $$tagInfo{Writable} and not $$tagInfo{Writable}) {
                            warn "Warning: Var-format tag is writable - $short $name\n"
                        }
                        # also need DATAMEMBER for tags used in length of var-sized value
                        while ($format =~ /\$val\{(.*?)\}/g) {
                            my $id = $1;
                            $id = hex($id) if $id =~ /^0x/; # convert from hex if necessary
                            $datamember{$id} = $$table{$id}{Name} if ref $$table{$id} eq 'HASH';
                            unless ($datamember{$id}) {
                                warn "Warning: Unknown ID ($id) used in Format - $short $name\n";
                            }
                        }
                    } elsif ($$tagInfo{Hook} or ($$tagInfo{RawConv} and
                             $$tagInfo{RawConv} =~ /\$self(->)?\{\w+\}\s*=(?!~)/))
                    {
                        $datamember{$tagID} = $name;
                    }
                    if ($format and $format =~ /\$val\{/ and
                        ($$tagInfo{Writable} or not defined $$tagInfo{Writable}))
                    {
                        warn "Warning: \$var{} used in Format of writable tag - $short $name\n"
                    }
                }
                if ($$tagInfo{Hidden}) {
                    if ($tagInfo == $infoArray[0]) {
                        next TagID; # hide all tags with this ID if first tag in list is hidden
                    } else {
                        next;       # only hide this tag
                    }
                }
                my $writable;
                if (defined $$tagInfo{Writable}) {
                    $writable = $$tagInfo{Writable};
                    # validate Writable
                    unless ($formatOK{$writable} or  ($writable =~ /(.*)\[/ and $formatOK{$1})) {
                        warn "Warning: Unknown Writable ($writable) - $short $name\n",
                    }
                } elsif (not $$tagInfo{SubDirectory}) {
                    $writable = $$table{WRITABLE};
                }
                # validate some characteristics of obvious date/time tags
                if ($$tagInfo{PrintConv} and $$tagInfo{PrintConv} eq '$self->ConvertDateTime($val)') {
                    my @g = $et->GetGroup($tagInfo);
                    warn "$short $name should be in 'Time' group!\n" unless $g[2] eq 'Time';
                    if ($writable and not $$tagInfo{Shift} and $g[0] ne 'Composite' and
                        $short ne 'PostScript')
                    {
                        warn "$short $name is not shiftable!\n";
                    }
                    if ($writable and (not $$tagInfo{PrintConvInv} or
                        $$tagInfo{PrintConvInv} !~ /InverseDateTime/))
                    {
                        warn "$short $name missing InverseDateTime PrintConvInv\n";
                    }
                } elsif ($name =~ /DateTime(?!Stamp)/ and (not $$tagInfo{Groups}{2} or
                    $$tagInfo{Groups}{2} ne 'Time') and $short ne 'DICOM') {
                    warn "$short $name should be in 'Time' group!\n";
                }
                # validate Description (can't contain special characters)
                if ($$tagInfo{Description} and
                    $$tagInfo{Description} ne EscapeHTML($$tagInfo{Description}))
                {
                    # this is a problem because the Escape option currently only
                    # escapes descriptions if the default Lang option isn't default
                    warn "$name description contains special characters!\n";
                }
                # generate structure lookup
                my $struct = $$tagInfo{Struct};
                my $strTable;
                if (ref $struct) {
                    $strTable = $struct;
                    $struct = $$strTable{STRUCT_NAME};
                    if ($struct) {
                        my $oldTable = $structLookup{$struct};
                        if ($oldTable and $oldTable ne $strTable) {
                            warn "Duplicate XMP structure with name $struct\n";
                        } else {
                            $structLookup{$struct} = $strTable;
                        }
                    } else {
                        warn "Missing STRUCT_NAME for structure in $$tagInfo{Name}\n";
                        undef $strTable;
                    }
                } elsif ($struct) {
                    $strTable = $structLookup{$struct};
                    unless ($strTable) {
                        $struct = "XMP $struct" unless $struct =~ / /;
                        warn "Missing $struct structure!\n";
                        undef $struct;
                    }
                }
                # validate SubIFD flag
                my $subdir = $$tagInfo{SubDirectory};
                my $isSub = ($subdir and $$subdir{Start} and $$subdir{Start} =~ /\$val\b/);
                if ($$tagInfo{SubIFD}) {
                    warn "Warning: Wrong SubDirectory Start for SubIFD tag - $short $name\n" unless $isSub;
                } else {
                    warn "Warning: SubIFD flag not set for $short $name\n" if $isSub;
                }
                if ($$tagInfo{Notes}) {
                    my $note = $$tagInfo{Notes};
                    # remove leading/trailing blank lines
                    $note =~ s/^\s+//; $note =~ s/\s+$//;
                    # remove leading/trailing spaces on each line
                    $note =~ s/(^[ \t]+|[ \t]+$)//mg;
                    push @values, "($note)";
                } elsif ($isXMP and lc $tagID ne lc $name) {
                    # add note about different XMP Tag ID
                    if ($$tagInfo{RootTagInfo}) {
                        push @values, "($tagID)";
                    } else {
                        push @values,"(called $tagID by the spec)";
                    }
                }
                my $writeGroup;
                if ($short eq 'Extra') {
                    my @g = $et->GetGroup($tagInfo);
                    $writeGroup = $$tagInfo{WriteOnly} ? '-' : $g[1];
                } else {
                    $writeGroup = $$tagInfo{WriteGroup};
                }
                unless ($writeGroup) {
                    $writeGroup = $$table{WRITE_GROUP} if $writable;
                    $writeGroup = '-' unless $writeGroup;
                }
                if (defined $format) {
                    # validate Format
                    unless ($formatOK{$format} or $short eq 'PICT' or
                        ($format =~ /^(var_)?(.*)\[/ and $formatOK{$2}))
                    {
                        warn "Warning: Unknown Format ($format) for $short $name\n";
                    }
                } else {
                    $format = $defFormat;
                }
                if ($subdir) {
                    my $subTable = $$subdir{TagTable} || $tableName;
                    push @values, $shortName{$subTable}
                } elsif ($struct) {
                    push @values, $struct;
                    $structs{$struct} = 1;
                }
                my $type;
                foreach $type ('Require','Desire') {
                    my $require = $$tagInfo{$type};
                    if (ref $require) {
                        foreach (sort { $a <=> $b } keys %$require) {
                            push @require, $$require{$_};
                        }
                    } elsif ($require) {
                        push @require, $require;
                    }
                }
                my $printConv = $$tagInfo{PrintConv};
                if ($$tagInfo{Mask}) {
                    my $val = $$tagInfo{Mask};
                    push @values, sprintf('[Mask 0x%.2x]',$val);
                    $$tagInfo{PrintHex} = 1 unless defined $$tagInfo{PrintHex};
                    # verify that all values are within the mask
                    if (ref $printConv eq 'HASH') {
                        # convert mask if necessary
                        if ($$tagInfo{ValueConv}) {
                            my $v = eval $$tagInfo{ValueConv};
                            $val = $v if defined $v;
                        }
                        foreach (keys %$printConv) {
                            next if $_ !~ /^\d+$/ or ($_ & $val) == $_;
                            my $hex = sprintf '0x%.2x', $_;
                            warn "$short $name PrintConv value $hex is not in Mask!\n";
                        }
                    }
                }
                if (ref($printConv) =~ /^(HASH|ARRAY)$/) {
                    my (@printConvList, @indexList, $index);
                    if (ref $printConv eq 'ARRAY') {
                        for ($index=0; $index<@$printConv; ++$index) {
                            next if ref $$printConv[$index] ne 'HASH';
                            next unless %{$$printConv[$index]};
                            push @printConvList, $$printConv[$index];
                            push @indexList, $index;
                            # collapse values with identical PrintConv's
                            if (@printConvList >= 2 and $printConvList[-1] eq $printConvList[-2]) {
                                if (ref $indexList[-2]) {
                                    push @{$indexList[-2]}, $indexList[-1];
                                } else {
                                    $indexList[-2] = [ $indexList[-2], $indexList[-1] ];
                                }
                                pop @printConvList;
                                pop @indexList;
                            }
                        }
                        $printConv = shift @printConvList;
                        $index = shift @indexList;
                    }
                    while (defined $printConv) {
                        if (defined $index) {
                            # (print indices of original values if reorganized)
                            my $s = '';
                            my $idx = $$tagInfo{Relist} ? $tagInfo->{Relist}->[$index] : $index;
                            if (ref $idx) {
                                $s = 's' if @$idx > 1;
                                # collapse consecutive number ranges
                                my ($i, @i, $rngStart);
                                for ($i=0; $i<@$idx; ++$i) {
                                    if ($i < @$idx - 1 and $$idx[$i+1] == $$idx[$i] + 1) {
                                        $rngStart = $i unless defined $rngStart;
                                        next;
                                    }
                                    push @i, defined($rngStart) ? "$rngStart-$i" : $i;
                                }
                                ($idx = join ', ', @i) =~ s/(.*),/$1 and/;
                            } elsif (not $$tagInfo{Relist}) {
                                while (@printConvList and $printConv eq $printConvList[0]) {
                                    shift @printConvList;
                                    $index = shift @indexList;
                                }
                                if ($idx != $index) {
                                    $idx = "$idx-$index";
                                    $s = 's';
                                }
                            }
                            push @values, "[Value$s $idx]";
                        }
                        if ($$tagInfo{SeparateTable}) {
                            $subdir = 1;
                            my $s = $$tagInfo{SeparateTable};
                            $s = $name if $s eq '1';
                            # add module name if not specified
                            $s =~ / / or ($short =~ /^(\w+)/ and $s = "$1 $s");
                            push @values, $s;
                            $sepTable{$s} = $printConv;
                            # add PrintHex flag to PrintConv so we can check it later
                            $$printConv{PrintHex} = 1 if $$tagInfo{PrintHex};
                            $$printConv{PrintString} = 1 if $$tagInfo{PrintString};
                        } else {
                            $caseInsensitive = 0;
                            my @pk = sort { NumbersFirst($a,$b) } keys %$printConv;
                            my $n = scalar @values;
                            my ($bits, $i);
                            foreach (@pk) {
                                next if $_ eq '';
                                $_ eq 'BITMASK' and $bits = $$printConv{$_}, next;
                                $_ eq 'OTHER' and next;
                                my $index;
                                if (($$tagInfo{PrintHex} or $$printConv{BITMASK}) and /^-?\d+$/) {
                                    if ($_ >= 0) {
                                        $index = sprintf('0x%x', $_);
                                    } elsif ($format and $format =~ /int(16|32)/) {
                                        # mask off unused bits of signed integer hex value
                                        my $mask = { 16 => 0xffff, 32 => 0xffffffff }->{$1};
                                        $index = sprintf('0x%x', $_ & $mask);
                                    } else {
                                        $index = $_;
                                    }
                                } elsif (/^[+-]?(?=\d|\.\d)\d*(\.\d*)?$/ and not $$tagInfo{PrintString}) {
                                    $index = $_;
                                } else {
                                    $index = $_;
                                    # translate unprintable values
                                    if ($index =~ s/([\x00-\x1f\x80-\xff])/sprintf("\\x%.2x",ord $1)/eg) {
                                        $index = qq{"$index"};
                                    } else {
                                        $index = qq{'$index'};
                                    }
                                }
                                push @values, "$index = " . $$printConv{$_};
                                # validate all PrintConv values
                                if ($$printConv{$_} =~ /[\0-\x1f\x7f-\xff]/) {
                                    warn "Warning: Special characters in $short $name PrintConv ($$printConv{$_})\n";
                                }
                            }
                            if ($bits) {
                                my @pk = sort { NumbersFirst($a,$b) } keys %$bits;
                                foreach (@pk) {
                                    push @values, "Bit $_ = " . $$bits{$_};
                                }
                            }
                            # organize values into columns if specified
                            my $cols = $$tagInfo{PrintConvColumns};
                            if (not $cols and scalar(@values) - $n >= 6) {
                                # do columns if more than 6 short entries
                                my $maxLen = 0;
                                for ($i=$n; $i<@values; ++$i) {
                                    next unless $maxLen < length $values[$i];
                                    $maxLen = length $values[$i];
                                }
                                my $num = scalar(@values) - $n;
                                $cols = int(50 / ($maxLen + 2)); # (50 chars max width)
                                # have 3 rows minimum
                                --$cols while $cols and $num / $cols < 3;
                            }
                            if ($cols) {
                                my @new = splice @values, $n;
                                my $v = '[!HTML]<table class=cols><tr>';
                                my $rows = int((scalar(@new) + $cols - 1) / $cols);
                                for ($n=0; ;) {
                                    $v .= "\n  <td>";
                                    for ($i=0; $i<$rows and $n+$i<@new; ++$i) {
                                        $v .= "\n  <br>" if $i;
                                        $v .= EscapeHTML($new[$n+$i]);
                                    }
                                    $v .= '</td>';
                                    last if ($n += $rows) >= @new;
                                    $v .= '<td>&nbsp;&nbsp;</td>'; # add spaces between columns
                                }
                                push @values, $v . "</tr></table>\n";
                            }
                        }
                        last unless @printConvList;
                        $printConv = shift @printConvList;
                        $index = shift @indexList;
                    }
                } elsif ($printConv and $printConv =~ /DecodeBits\(\$val,\s*(\{.*\})\s*\)/s) {
                    $$self{Model} = '';   # needed for Nikon ShootingMode
                    my $bits = eval $1;
                    delete $$self{Model};
                    if ($@) {
                        warn $@;
                    } else {
                        my @pk = sort { NumbersFirst($a,$b) } keys %$bits;
                        foreach (@pk) {
                            push @values, "Bit $_ = " . $$bits{$_};
                        }
                    }
                }
                if ($subdir and not $$tagInfo{SeparateTable}) {
                    # subdirectories are only writable if specified explicitly
                    my $tw = $$tagInfo{Writable};
                    $writable = 'Y' if $tw and $writable eq '1';
                    $writable = '-' . ($tw ? $writable : '');
                    $writable .= '!' if $tw and ($$tagInfo{Protected} || 0) & 0x01;
                    $writable .= '+' if $$tagInfo{List};
                } else {
                    # not writable if we can't do the inverse conversions
                    my $noPrintConvInv;
                    if ($writable) {
                        foreach ('PrintConv','ValueConv') {
                            next unless $$tagInfo{$_};
                            next if $$tagInfo{$_ . 'Inv'};
                            next if ref($$tagInfo{$_}) =~ /^(HASH|ARRAY)$/;
                            next if $$tagInfo{WriteAlso};
                            if ($_ eq 'ValueConv') {
                                undef $writable;
                            } else {
                                $noPrintConvInv = 1;
                            }
                        }
                    }
                    if (not $writable) {
                        $writable = 'N';
                    } else {
                        $writable eq '1' and $writable = $format ? $format : 'Y';
                        my $count = $$tagInfo{Count} || 1;
                        # adjust count to Writable size if different than Format
                        if ($writable and $format and $writable ne $format and
                            $Image::ExifTool::Exif::formatNumber{$writable} and
                            $Image::ExifTool::Exif::formatNumber{$format})
                        {
                            my $n1 = $Image::ExifTool::Exif::formatNumber{$format};
                            my $n2 = $Image::ExifTool::Exif::formatNumber{$writable};
                            $count *= $Image::ExifTool::Exif::formatSize[$n1] /
                                      $Image::ExifTool::Exif::formatSize[$n2];
                        }
                        if ($count != 1) {
                            $count = 'n' if $count < 0;
                            $writable .= "[$count]";
                        }
                        $writable .= '~' if $noPrintConvInv;
                        # add a '*' if this tag is protected or a '!' for unsafe tags
                        if ($$tagInfo{Protected}) {
                            $writable .= '*' if $$tagInfo{Protected} & 0x02;
                            $writable .= '!' if $$tagInfo{Protected} & 0x01;
                        }
                        $writable .= '/' if $$tagInfo{Avoid};
                    }
                    $writable = "=struct" if $struct;
                    $writable .= '_' if defined $$tagInfo{Flat};
                    $writable .= '+' if $$tagInfo{List};
                    $writable .= ':' if $$tagInfo{Mandatory};
                    # separate tables link like subdirectories (flagged with leading '-')
                    $writable = "-$writable" if $subdir;
                }
                # don't duplicate a tag name unless an entry is different
                my $lcName = lc($name);
                # check for conflicts with shortcut names
                if ($isShortcut{$lcName} and $short ne 'Shortcuts' and
                    ($$tagInfo{Writable} or not $$tagInfo{SubDirectory}))
                {
                    warn "WARNING: $short $name is a shortcut tag!\n";
                }
                $name .= '?' if $$tagInfo{Unknown};
                unless (@tagNames and $tagNames[-1] eq $name and
                    $writeGroup[-1] eq $writeGroup and $writable[-1] eq $writable)
                {
                    push @tagNames, $name;
                    push @writeGroup, $writeGroup;
                    push @writable, $writable;
                }
#
# add this tag to the tag lookup unless NO_LOOKUP is set or shortcut or plug-in tag
#
                next if $shortcut or $isPlugin;
                # count tags
                if ($$tagInfo{SubDirectory}) {
                    next if $$vars{NO_LOOKUP};
                    $subdirs{$lcName} or $subdirs{$lcName} = 0;
                    ++$subdirs{$lcName};
                } else {
                    ++$count{'total tags'};
                    unless ($tagExists{$lcName} and
                        (not $subdirs{$lcName} or $subdirs{$lcName} == $tagExists{$lcName}))
                    {
                        ++$count{'unique tag names'} unless $noLookup{$lcName};
                    }
                    # don't add to tag lookup if specified
                    $$vars{NO_LOOKUP} and $noLookup{$lcName} = 1, next;
                }
                $tagExists{$lcName} or $tagExists{$lcName} = 0;
                ++$tagExists{$lcName};
                # only add writable tags to lookup table (for speed)
                my $wflag = $$tagInfo{Writable};
                next unless $writeProc and ($wflag or ($$table{WRITABLE} and
                    not defined $wflag and not $$tagInfo{SubDirectory}));
                $tagLookup{$lcName} or $tagLookup{$lcName} = { };
                # add to lookup for flattened tags if necessary
                if ($$tagInfo{RootTagInfo}) {
                    $flattened{$lcName} or $flattened{$lcName} = { };
                    $flattened{$lcName}{$tableNum} = $$tagInfo{RootTagInfo}{TagID};
                }
                # remember number for this table
                my $tagIDs = $tagLookup{$lcName}->{$tableNum};
                # must allow for duplicate tags with the same name in a single table!
                if ($tagIDs) {
                    if (ref $tagIDs eq 'HASH') {
                        $$tagIDs{$tagID} = 1;
                        next;
                    } elsif ($tagID eq $tagIDs) {
                        next;
                    } else {
                        $tagIDs = { $tagIDs => 1, $tagID => 1 };
                    }
                } else {
                    $tagIDs = $tagID;
                }
                $tableWritable{$tableName} = 1;
                $tagLookup{$lcName}->{$tableNum} = $tagIDs;
                if ($short eq 'Composite' and $$tagInfo{Module}) {
                    $compositeModules{$lcName} = $$tagInfo{Module};
                }
            }
#
# save TagName information
#
            my $tagIDstr;
            if ($tagID =~ /^(-)?\d+(\.\d+)?$/) {
                if ($1) {
                    $tagIDstr = $tagID;
                } elsif (defined $hexID) {
                    $tagIDstr = $hexID ? sprintf('0x%.4x',$tagID) : $tagID;
                } elsif (not $2 and not $binaryTable and not $isIPTC and
                         not ($short =~ /^CanonCustom/ and $tagID < 256))
                {
                    $tagIDstr = sprintf('0x%.4x',$tagID);
                } elsif ($tagID < 0x10000) {
                    $tagIDstr = $tagID;
                } else {
                    $tagIDstr = sprintf('0x%.8x',$tagID);
                }
            } elsif ($short eq 'DICOM') {
                ($tagIDstr = $tagID) =~ s/_/,/;
            } elsif ($tagID =~ /^0x([0-9a-f]+)\.(\d+)$/) {  # DR4 tags like '0x20500.0'
                $tagIDstr = $tagID;
            } else {
                # convert non-printable characters to hex escape sequences
                if ($tagID =~ s/([\x00-\x1f\x7f-\xff])/'\x'.unpack('H*',$1)/eg) {
                    $tagID =~ s/\\x00/\\0/g;
                    next if $tagID eq 'jP\x1a\x1a'; # ignore abnormal JP2 signature tag
                    $tagIDstr = qq{"$tagID"};
                } else {
                    $tagIDstr = "'$tagID'";
                }
            }
            my $len = length $tagIDstr;
            $longID{$tableName} = $len if $longID{$tableName} < $len;
            foreach (@tagNames) {
                $len = length $_;
                $longName{$tableName} = $len if $longName{$tableName} < $len;
            }
            push @$info, [ $tagIDstr, \@tagNames, \@writable, \@values, \@require, \@writeGroup ];
        }
        # do consistency check of writable BinaryData tables
        if ($processBinaryData and $$table{WRITABLE}) {
            my %lookup = (
                IS_OFFSET => \%isOffset,
                IS_SUBDIR => \%hasSubdir,
                DATAMEMBER => \%datamember,
            );
            my ($var, $tagID);
            foreach $var (sort keys %lookup) {
                my $hash = $lookup{$var};
                if ($$table{$var}) {
                    foreach $tagID (@{$$table{$var}}) {
                        $$hash{$tagID} and delete($$hash{$tagID}), next;
                        warn "Warning: Extra $var for $short tag $tagID\n";
                    }
                }
                foreach $tagID (sort keys %$hash) {
                    warn "Warning: Missing $var for $short $$hash{$tagID}\n";
                }
            }
        }
    }
    # save information about structures
    my $strName;
    foreach $strName (keys %structs) {
        my $struct = $structLookup{$strName};
        my $fullName = ($strName =~ / / ? '' : 'XMP ') . "$strName Struct";
        my $info = $tagNameInfo{$fullName} = [ ];
        my $tag;
        foreach $tag (sort keys %$struct) {
            my $tagInfo = $$struct{$tag};
            next unless ref $tagInfo eq 'HASH';
            my $writable = $$tagInfo{Writable};
            my @vals;
            unless ($writable) {
                $writable = $$tagInfo{Struct};
                ref $writable and $writable = $$writable{STRUCT_NAME};
                if ($writable) {
                    push @vals, $writable;
                    $structs{$writable} = 1;
                    $writable = "=$writable";
                } else {
                    $writable = 'string';
                }
            }
            $writable .= '+' if $$tagInfo{List};
            push @$info, [
                $tag,
                [ $$tagInfo{Name} || ucfirst($tag) ],
                [ $writable ],
                \@vals,
                [], []
            ];
        }
    }
    return $self;
}

#------------------------------------------------------------------------------
# Rewrite this file to build the lookup tables
# Inputs: 0) BuildTagLookup object reference
#         1) output tag lookup module name (eg. 'lib/Image/ExifTool/TagLookup.pm')
# Returns: true on success
sub WriteTagLookup($$)
{
    local ($_, *INFILE, *OUTFILE);
    my ($self, $file) = @_;
    my $tagLookup = $self->{TAG_LOOKUP};
    my $tagExists = $self->{TAG_EXISTS};
    my $flattened = $self->{FLATTENED};
    my $tableWritable = $self->{TABLE_WRITABLE};
#
# open/create necessary files and transfer file headers
#
    my $tmpFile = "${file}_tmp";
    open(INFILE, $file) or warn("Can't open $file\n"), return 0;
    unless (open(OUTFILE, ">$tmpFile")) {
        warn "Can't create temporary file $tmpFile\n";
        close(INFILE);
        return 0;
    }
    my $success;
    while (<INFILE>) {
        print OUTFILE $_ or last;
        if (/^#\+{4} Begin/) {
            $success = 1;
            last;
        }
    }
    print OUTFILE "\n# list of tables containing writable tags\n";
    print OUTFILE "my \@tableList = (\n";

#
# write table list
#
    my @tableNames = sort keys %allTables;
    my $tableName;
    my %wrNum;      # translate from allTables index to writable tables index
    my $count = 0;
    my $num = 0;
    foreach $tableName (@tableNames) {
        if ($$tableWritable{$tableName}) {
            print OUTFILE "\t'$tableName',\n";
            $wrNum{$count} = $num++;
        }
        $count++;
    }
#
# write the tag lookup table
#
    my $tag;
    # verify that certain critical tag names aren't duplicated
    foreach $tag (qw{filename directory}) {
        next unless $$tagLookup{$tag};
        my $n = scalar keys %{$$tagLookup{$tag}};
        warn "Warning: $n writable '$tag' tags!\n" if $n > 1;
    }
    print OUTFILE ");\n\n# lookup for all writable tags\nmy \%tagLookup = (\n";
    foreach $tag (sort keys %$tagLookup) {
        print OUTFILE "\t'$tag' => { ";
        my @tableNums = sort { $a <=> $b } keys %{$$tagLookup{$tag}};
        my (@entries, $tableNum);
        foreach $tableNum (@tableNums) {
            my $tagID = $$tagLookup{$tag}{$tableNum};
            my $rootID = $$flattened{$tag}{$tableNum};
            my $entry;
            if (ref $tagID eq 'HASH' or $rootID) {
                $tagID = { $tagID => 1 } unless ref $tagID eq 'HASH';
                my @tagIDs = sort keys %$tagID;
                foreach (@tagIDs) {
                    if (/^\d+$/) {
                        $_ = sprintf('0x%x',$_);
                    } else {
                        my $quot = "'";
                        # escape non-printable characters in tag ID if necessary
                        $quot = '"' if s/[\x00-\x1f,\x7f-\xff]/sprintf('\\x%.2x',ord($&))/ge;
                        $_ = $quot . $_ . $quot;
                    }
                }
                # reference to root structure ID must come first in lookup
                # (so we can generate the flattened tags just before we need them)
                unshift @tagIDs, "\\'$rootID'" if $rootID;
                $entry = '[' . join(',', @tagIDs) . ']';
            } elsif ($tagID =~ /^\d+$/) {
                $entry = sprintf('0x%x',$tagID);
            } else {
                $entry = "'$tagID'";
            }
            my $wrNum = $wrNum{$tableNum};
            push @entries, "$wrNum => $entry";
        }
        print OUTFILE join(', ', @entries);
        print OUTFILE " },\n";
    }
#
# write tag exists lookup
#
    print OUTFILE ");\n\n# lookup for non-writable tags to check if the name exists\n";
    print OUTFILE "my \%tagExists = (\n";
    foreach $tag (sort keys %$tagExists) {
        next if $$tagLookup{$tag};
        print OUTFILE "\t'$tag' => 1,\n";
    }
#
# write module lookup for writable composite tags
#
    my $compositeModules = $self->{COMPOSITE_MODULES};
    print OUTFILE ");\n\n# module names for writable Composite tags\n";
    print OUTFILE "my \%compositeModules = (\n";
    foreach (sort keys %$compositeModules) {
        print OUTFILE "\t'$_' => '$$compositeModules{$_}',\n";
    }
    print OUTFILE ");\n\n";
#
# finish writing TagLookup.pm and clean up
#
    if ($success) {
        $success = 0;
        while (<INFILE>) {
            $success or /^#\+{4} End/ or next;
            print OUTFILE $_;
            $success = 1;
        }
    }
    close(INFILE);
    close(OUTFILE) or $success = 0;
#
# return success code
#
    if ($success) {
        local (*ORG, *TMP);
        # only rename the file if something changed
        open ORG, $file or return 0;
        open TMP, $tmpFile or return 0;
        my ($buff, $buf2, $changed);
        for (;;) {
            my $n1 = read ORG, $buff, 65536;
            my $n2 = read TMP, $buf2, 65536;
            $n1 eq $n2 or $changed = 1, last;
            last unless $n1;
            $buff eq $buf2 or $changed = 1, last;
        }
        close ORG;
        close TMP;
        if ($changed) {
            rename($tmpFile, $file) or warn("Error renaming $tmpFile\n"), $success = 0;
        } else {
            unlink($tmpFile);
        }
    } else {
        unlink($tmpFile);
        warn "Error rewriting file\n";
    }
    return $success;
}

#------------------------------------------------------------------------------
# Sort numbers first numerically, then strings alphabetically (case insensitive)
# - two global variables are used to change the sort algorithm:
#   $numbersFirst: -1 = put numbers after other strings
#                   1 = put numbers before other strings
#                   2 = put numbers first, but negative numbers last
#   $caseInsensitive: flag set for case-insensitive sorting
sub NumbersFirst($$)
{
    my ($a, $b) = @_;
    my $rtnVal;
    my ($bNum, $bDec);
    ($bNum, $bDec) = ($1, $3) if $b =~ /^(-?[0-9]+)(\.(\d*))?$/;
    if ($a =~ /^(-?[0-9]+)(\.(\d*))?$/) {
        if (defined $bNum) {
            $bNum += 1e9 if $numbersFirst == 2 and $bNum < 0;
            my $aInt = $1;
            $aInt += 1e9 if $numbersFirst == 2 and $aInt < 0;
            # compare integer part as a number
            $rtnVal = $aInt <=> $bNum;
            unless ($rtnVal) {
                my $aDec = $3 || 0;
                $bDec or $bDec = 0;
                # compare decimal part as an integer too
                # (so that "1.10" comes after "1.9")
                $rtnVal = $aDec <=> $bDec;
            }
        } else {
            $rtnVal = -$numbersFirst;
        }
    } elsif (defined $bNum) {
        $rtnVal = $numbersFirst;
    } else {
        my ($a2, $b2) = ($a, $b);
        # expand numbers to 3 digits (with restrictions to avoid messing up ascii-hex tags)
        $a2 =~ s/(\d+)/sprintf("%.3d",$1)/eg if $a2 =~ /^(APP|DMC-\w+ )?[.0-9 ]*$/ and length($a2)<16;
        $b2 =~ s/(\d+)/sprintf("%.3d",$1)/eg if $b2 =~ /^(APP|DMC-\w+ )?[.0-9 ]*$/ and length($b2)<16;
        $caseInsensitive and $rtnVal = (lc($a2) cmp lc($b2));
        $rtnVal or $rtnVal = ($a2 cmp $b2);
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Convert our pod-like documentation to pod
# (funny, I know, but the pod headings must be hidden to prevent confusing
#  the pod parser)
# Inputs: 0-N) documentation strings
sub Doc2Pod($;@)
{
    my $doc = shift;
    local $_;
    $doc .= shift while @_;
    $doc =~ s/\n~/\n=/g;
    $doc =~ s/L<[^>]+?\|(http[^>]+)>/L<$1>/g; # POD doesn't support text for http links
    $doc =~ s/L<([^>]+?)\|[^>]+\.html>/$1/g;  # remove relative HTML links
    return $doc;
}

#------------------------------------------------------------------------------
# Convert our pod-like documentation to html
# Inputs: 0) string
sub Doc2Html($)
{
    my $doc = EscapeHTML(shift);
    $doc =~ s/\n\n/<\/p>\n\n<p>/g;
    $doc =~ s/B&lt;(.*?)&gt;/<b>$1<\/b>/sg;
    $doc =~ s/C&lt;(.*?)&gt;/<code>$1<\/code>/sg;
    $doc =~ s/I&lt;(.*?)&gt;/<i>$1<\/i>/sg;
    # L<some text|http://owl.phy.queensu.ca/~phil/exiftool/struct.html#Fields> --> <a href="../struct.html#Fields">some text</a>
    $doc =~ s{L&lt;([^&]+?)\|\Q$homePage\E/(.*?)&gt;}{<a href="../$2">$1<\/a>}sg;
    # L<http://owl.phy.queensu.ca/~phil/exiftool/struct.html> --> <a href="http://owl.phy.queensu.ca/~phil/exiftool/struct.html">http://owl.phy.queensu.ca/~phil/exiftool/struct.html</a>
    $doc =~ s{L&lt;\Q$homePage\E/(.*?)&gt;}{<a href="../$1">$1<\/a>}sg;
    # L<XMP DICOM Tags|Image::ExifTool::TagNames/XMP DICOM Tags> --> <a href="XMP.html#DICOM">XMP DICOM Tags</a>
    # (specify "Image::ExifTool::TagNames" to link to another html file)
    $doc =~ s{L&lt;([^&]+?)\|Image::ExifTool::TagNames/(\w+) ([^/&|]+) Tags&gt;}{<a href="$2.html#$3">$1</a>}sg;
    # L<DICOM Tags|Image::ExifTool::TagNames/DICOM Tags> --> <a href="DICOM.html">DICOM Tags</a>
    $doc =~ s{L&lt;([^&]+?)\|Image::ExifTool::TagNames/(\w+) Tags&gt;}{<a href="$2.html">$1</a>}sg;
    # L<dc|/XMP dc Tags> --> <a href="#dc">dc</a>
    # (a relative POD link turns into a relative HTML link)
    $doc =~ s{L&lt;([^&]+?)\|/\w+ ([^/&|]+) Tags&gt;}{<a href="#$2">$1</a>}sg;
    # L<sample config file|../config.html> --> <a href="../config.html">sample config file</a>
    $doc =~ s/L&lt;([^&]+?)\|(.+?)&gt;/<a href="$2">$1<\/a>/sg;
    # L<http://some.web.site/> --> <a href="http://some.web.site">http://some.web.site</a>
    $doc =~ s/L&lt;(http.*?)&gt;/<a href="$1">$1<\/a>/sg;
    return $doc;
}

#------------------------------------------------------------------------------
# Tweak order of tables
# Inputs: 0) table list ref, 1) reference to tweak hash
sub TweakOrder($$)
{
    my ($sortedTables, $tweakOrder) = @_;
    my @tweak = sort keys %$tweakOrder;
    while (@tweak) {
        my $table = shift @tweak;
        my $first = $$tweakOrder{$table};
        if ($$tweakOrder{$first}) {
            push @tweak, $table;    # must defer this till later
            next;
        }
        delete $$tweakOrder{$table}; # because the table won't move again
        my @moving = grep /^Image::ExifTool::$table\b/, @$sortedTables;
        my @notMoving = grep !/^Image::ExifTool::$table\b/, @$sortedTables;
        my @after;
        while (@notMoving) {
            last if $notMoving[-1] =~ /^Image::ExifTool::$first\b/;
            unshift @after, pop @notMoving;
        }
        @$sortedTables = (@notMoving, @moving, @after);
    }
}

#------------------------------------------------------------------------------
# Get a list of sorted tag ID's from a table
# Inputs: 0) tag table ref
# Returns: list of sorted keys
sub SortedTagTableKeys($)
{
    my $table = shift;
    my $vars = $$table{VARS} || { };
    my @keys = TagTableKeys($table);
    if ($$vars{NO_ID}) {
        # sort by tag name if ID not shown
        my ($key, %name);
        foreach $key (@keys) {
            my ($tagInfo) = GetTagInfoList($table, $key);
            $name{$key} = $$tagInfo{Name};
        }
        return sort { $name{$a} cmp $name{$b} or $a cmp $b } @keys;
    } else {
        my $sortProc = $$vars{SORT_PROC} || \&NumbersFirst;
        return sort { &$sortProc($a,$b) } @keys;
    }
}

#------------------------------------------------------------------------------
# Get the order that we want to print the tables in the documentation
# Inputs: 0-N) Extra tables to add at end
# Returns: tables in the order we want
sub GetTableOrder(@)
{
    my %gotTable;
    my @tableNames = @tableOrder;
    my (@orderedTables, %mainTables, @outOfOrder);
    my $lastTable = '';

    while (@tableNames) {
        my $tableName = shift @tableNames;
        next if $gotTable{$tableName};
        if ($tableName =~ /^Image::ExifTool::(\w+)::Main/) {
            $mainTables{$1} = 1;
        } elsif ($lastTable and not $tableName =~ /^${lastTable}::/) {
            push @outOfOrder, $tableName;
        }
        ($lastTable) = ($tableName =~ /^(Image::ExifTool::\w+)/);
        push @orderedTables, $tableName;
        $gotTable{$tableName} = 1;
        my $table = GetTagTable($tableName);
        # recursively scan through tables in subdirectories
        my @moreTables;
        $caseInsensitive = ($$table{GROUPS} and $$table{GROUPS}{0} eq 'XMP');
        $numbersFirst = -1 if $$table{VARS} and $$table{VARS}{ALPHA_FIRST};
        my @keys = SortedTagTableKeys($table);
        $numbersFirst = 1;
        foreach (@keys) {
            my @infoArray = GetTagInfoList($table,$_);
            my $tagInfo;
            foreach $tagInfo (@infoArray) {
                my $subdir = $$tagInfo{SubDirectory} or next;
                $tableName = $$subdir{TagTable} or next;
                next if $gotTable{$tableName};  # next if table already loaded
                push @moreTables, $tableName;   # must scan this one too
            }
        }
        unshift @tableNames, @moreTables;
    }
    # clean up the order for tables which are out of order
    # (groups all Canon and Kodak tables together)
    my %fixOrder;
    foreach (@outOfOrder) {
        next unless /^Image::ExifTool::(\w+)/;
        # only re-order tables which have a corresponding main table
        next unless $mainTables{$1};
        $fixOrder{$1} = [];     # fix the order of these tables
    }
    my (@sortedTables, %fixPos, $pos);
    foreach (@orderedTables) {
        if (/^Image::ExifTool::(\w+)/ and $fixOrder{$1}) {
            my $fix = $fixOrder{$1};
            unless (@$fix) {
                $pos = @sortedTables;
                $fixPos{$pos} or $fixPos{$pos} = [];
                push @{$fixPos{$pos}}, $1;
            }
            push @{$fix}, $_;
        } else {
            push @sortedTables, $_;
        }
    }
    # insert back in better order
    foreach $pos (sort { $b <=> $a } keys %fixPos) { # (reverse sort)
        my $fix = $fixPos{$pos};
        foreach (@$fix) {
            splice(@sortedTables, $pos, 0, @{$fixOrder{$_}});
        }
    }
    # add the extra tables
    push @sortedTables, @_;
    # tweak the table order
    TweakOrder(\@sortedTables, \%tweakOrder);

    return @sortedTables;
}

#------------------------------------------------------------------------------
# Open HTMLFILE and print header and description
# Inputs: 0) Filename, 1) optional category
# Returns: True on success
my %createdFiles;
sub OpenHtmlFile($;$$)
{
    my ($htmldir, $category, $sepTable) = @_;
    my ($htmlFile, $head, $title, $url, $class);
    my $top = '';

    if ($category) {
        my @names = split ' ', $category;
        $class = shift @names;
        $htmlFile = "$htmldir/TagNames/$class.html";
        $head = $category;
        if ($head =~ /^\S+ .+ Struct$/) {
            pop @names;
        } else {
            $head .= ($sepTable ? ' Values' : ' Tags');
        }
        ($title = $head) =~ s/ .* / /;
        @names and $url = join '_', @names;
    } else {
        $htmlFile = "$htmldir/TagNames/index.html";
        $category = $class = 'ExifTool';
        $head = $title = 'ExifTool Tag Names';
    }
    if ($createdFiles{$htmlFile}) {
        open(HTMLFILE, ">>${htmlFile}_tmp") or return 0;
    } else {
        open(HTMLFILE, ">${htmlFile}_tmp") or return 0;
        print HTMLFILE "$docType<html>\n<head>\n<title>$title</title>\n";
        print HTMLFILE "<link rel=stylesheet type='text/css' href='style.css' title='Style'>\n";
        print HTMLFILE "</head>\n<body>\n";
        if ($category ne $class and $docs{$class}) {
            print HTMLFILE "<h2 class=top>$class Tags</h2>\n" or return 0;
            print HTMLFILE '<p>',Doc2Html($docs{$class}),"</p>\n" or return 0;
        } else {
            $top = " class=top";
        }
    }
    $head = "<a name='$url'>$head</a>" if $url;
    print HTMLFILE "<h2$top>$head</h2>\n" or return 0;
    print HTMLFILE '<p>',Doc2Html($docs{$category}),"</p>\n" if $docs{$category};
    $createdFiles{$htmlFile} = 1;
    return 1;
}

#------------------------------------------------------------------------------
# Close all html files and write trailers
# Returns: true on success
# Inputs: 0) BuildTagLookup object reference
sub CloseHtmlFiles($)
{
    my $self = shift;
    my $preserveDate = $$self{PRESERVE_DATE};
    my $success = 1;
    # get the date
    my ($sec,$min,$hr,$day,$mon,$yr) = localtime;
    my @month = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    $yr += 1900;
    my $date = "$month[$mon] $day, $yr";
    my $htmlFile;
    my $countNewFiles = 0;
    my $countSameFiles = 0;
    foreach $htmlFile (keys %createdFiles) {
        my $tmpFile = $htmlFile . '_tmp';
        my $fileDate = $date;
        if ($preserveDate) {
            my @lines = `grep '<i>Last revised' $htmlFile`;
            $fileDate = $1 if @lines and $lines[-1] =~ m{<i>Last revised (.*)</i>};
        }
        open(HTMLFILE, ">>$tmpFile") or $success = 0, next;
        # write the trailers
        print HTMLFILE "<hr>\n";
        print HTMLFILE "(This document generated automatically by Image::ExifTool::BuildTagLookup)\n";
        print HTMLFILE "<br><i>Last revised $fileDate</i>\n";
        print HTMLFILE "<p class=lf><a href=";
        if ($htmlFile =~ /index\.html$/) {
            print HTMLFILE "'../index.html'>&lt;-- Back to ExifTool home page</a></p>\n";
        } else {
            print HTMLFILE "'index.html'>&lt;-- ExifTool Tag Names</a></p>\n"
        }
        print HTMLFILE "</body>\n</html>\n" or $success = 0;
        close HTMLFILE or $success = 0;
        # check for differences and only use new file if it was changed
        # (so the date only gets updated if changes were really made)
        my $useNewFile;
        if ($success) {
            open (TEMPFILE, $tmpFile) or $success = 0, last;
            if (open (HTMLFILE, $htmlFile)) {
                while (<HTMLFILE>) {
                    my $newLine = <TEMPFILE>;
                    if (defined $newLine) {
                        next if /^<br><i>Last revised/;
                        next if $_ eq $newLine;
                    }
                    # files are different -- use the new file
                    $useNewFile = 1;
                    last;
                }
                $useNewFile = 1 if <TEMPFILE>;
                close HTMLFILE;
            } else {
                $useNewFile = 1;
            }
            close TEMPFILE;
            if ($useNewFile) {
                ++$countNewFiles;
                rename $tmpFile, $htmlFile or warn("Error renaming temporary file\n"), $success = 0;
            } else {
                ++$countSameFiles;
                unlink $tmpFile;   # erase new file and use existing file
            }
        }
        last unless $success;
    }
    # save number of files processed so we can check the results later
    $self->{COUNT}->{'HTML files changed'} = $countNewFiles;
    $self->{COUNT}->{'HTML files unchanged'} = $countSameFiles;
    return $success;
}

#------------------------------------------------------------------------------
# Write the TagName HTML and POD documentation
# Inputs: 0) BuildTagLookup object reference
#         1) output pod file (eg. 'lib/Image/ExifTool/TagNames.pod')
#         2) output html directory (eg. 'html')
# Returns: true on success
# Notes: My apologies for the patchwork code, but this is only used to generate the docs.
sub WriteTagNames($$)
{
    my ($self, $podFile, $htmldir) = @_;
    my ($tableName, $short, $url, @sepTables, @structs);
    my $tagNameInfo = $self->{TAG_NAME_INFO} or return 0;
    my $idLabel = $self->{ID_LOOKUP};
    my $shortName = $self->{SHORT_NAME};
    my $sepTable = $self->{SEPARATE_TABLE};
    my $structs = $self->{STRUCTURES};
    my $structLookup = $self->{STRUCT_LOOKUP};
    my $success = 1;
    my $columns = 6;    # number of columns in html index
    my $percent = int(100 / $columns);

    # open the file and write the header
    open(PODFILE, ">$podFile") or return 0;
    print PODFILE Doc2Pod($docs{PodHeader}, $docs{ExifTool}, $docs{ExifTool2});
    mkdir "$htmldir/TagNames";
    OpenHtmlFile($htmldir) or return 0;
    print HTMLFILE "<blockquote>\n";
    print HTMLFILE "<table width='100%' class=frame><tr><td>\n";
    print HTMLFILE "<table width='100%' class=inner cellspacing=1><tr class=h>\n";
    print HTMLFILE "<th colspan=$columns><span class=l>Tag Table Index</span></th></tr>\n";
    print HTMLFILE "<tr class=b><td width='$percent%'>\n";

    # get the full table list, adding shortcuts and plug-in tables to the end
    my @tableNames = GetTableOrder('Image::ExifTool::Shortcuts::Main', @pluginTables);

    # get list of headings and add any missing ones
    my $heading = 'xxx';
    my (@tableIndexNames, @headings);
    foreach $tableName (@tableNames) {
        $short = $$shortName{$tableName};
        my @names = split ' ', $short;
        my $class = shift @names;
        if (@names) {
            # add heading for tables without a Main
            unless ($heading eq $class) {
                $heading = $class;
                push @tableIndexNames, $heading;
                push @headings, $heading;
            }
        } else {
            $heading = $short;
            push @headings, $heading;
        }
        push @tableIndexNames, $tableName;
    }
    @tableNames = @tableIndexNames;
    # print html index of headings only
    my $count = 0;
    my $lines = int((scalar(@headings) + $columns - 1) / $columns);
    foreach $tableName (@headings) {
        if ($count) {
            if ($count % $lines) {
                print HTMLFILE "<br>\n";
            } else {
                print HTMLFILE "</td><td width='$percent%'>\n";
            }
        }
        $short = $$shortName{$tableName};
        $short = $tableName unless $short;
        $url = "$short.html";
        print HTMLFILE "<a href='$url'>$short</a>";
        ++$count;
    }
    print HTMLFILE "\n</td></tr></table></td></tr></table></blockquote>\n";
    print HTMLFILE '<p>',Doc2Html($docs{ExifTool2}),"</p>\n";

    # write all the tag tables
    while (@tableNames or @sepTables or @structs) {
        while (@sepTables) {
            $tableName = shift @sepTables;
            my $printConv = $$sepTable{$tableName};
            next unless ref $printConv eq 'HASH';
            $$sepTable{$tableName} = 1;
            my $notes = $$printConv{Notes};
            if ($notes) {
                # remove unnecessary whitespace
                $notes =~ s/^\s+//; $notes =~ s/\s+$//;
                $notes =~ s/(^[ \t]+|[ \t]+$)//mg;
            }
            my $head = $tableName;
            $head =~ s/^.* //s;
            close HTMLFILE;
            if (OpenHtmlFile($htmldir, $tableName, 1)) {
                print HTMLFILE '<p>', Doc2Html($notes), "</p>\n" if $notes;
                print HTMLFILE "<blockquote>\n";
                print HTMLFILE "<table class=frame><tr><td>\n";
                print HTMLFILE "<table class='inner sep' cellspacing=1>\n";
                my $align = ' class=r';
                my $wid = 0;
                my @keys;
                foreach (sort { NumbersFirst($a,$b) } keys %$printConv) {
                    next if /^(Notes|PrintHex|PrintString|OTHER)$/;
                    $align = '' if $align and /[^\d]/;
                    my $w = length($_) + length($$printConv{$_});
                    $wid = $w if $wid < $w;
                    push @keys, $_;
                }
                $wid = length($tableName)+7 if $wid < length($tableName)+7;
                # print in multiple columns if there is room
                my $cols = int(110 / ($wid + 4));
                $cols = 1 if $cols < 1 or $cols > @keys or @keys < 4;
                my $rows = int((scalar(@keys) + $cols - 1) / $cols);
                my ($r, $c);
                print HTMLFILE '<tr class=h>';
                for ($c=0; $c<$cols; ++$c) {
                    print HTMLFILE "<th>Value</th><th>$head</th>";
                }
                print HTMLFILE "</tr>\n";
                for ($r=0; $r<$rows; ++$r) {
                    print HTMLFILE '<tr>';
                    for ($c=0; $c<$cols; ++$c) {
                        my $key = $keys[$r + $c*$rows];
                        my ($index, $prt);
                        if (defined $key) {
                            $index = $key;
                            $prt = '= ' . EscapeHTML($$printConv{$key});
                            if ($$printConv{PrintHex}) {
                                $index =~ s/(\.\d+)$//; # remove decimal
                                $index = sprintf('0x%x',$index);
                                $index .= $1 if $1; # add back decimal
                            } elsif ($$printConv{PrintString} or
                                $index !~ /^[+-]?(?=\d|\.\d)\d*(\.\d*)?$/)
                            {
                                $index = "'" . EscapeHTML($index) . "'";
                            }
                        } else {
                            $index = $prt = '&nbsp;';
                        }
                        my ($ic, $pc);
                        if ($c & 0x01) {
                            $pc = ' class=b';
                            $ic = $align ? " class='r b'" : $pc;
                        } else {
                            $ic = $align;
                            $pc = '';
                        }
                        print HTMLFILE "<td$ic>$index</td><td$pc>$prt</td>\n";
                    }
                    print HTMLFILE '</tr>';
                }
                print HTMLFILE "</table></td></tr></table></blockquote>\n\n";
            }
        }
        last unless @tableNames or @structs;
        my $isStruct;
        if (@structs) {
            $tableName = shift @structs;
            next if $$structs{$tableName} == 2; # only list each structure once
            $$structs{$tableName} = 2;
            $isStruct = $$structLookup{$tableName};
            $isStruct or warn("Missing structure $tableName\n"), next;
            $tableName = "XMP $tableName" unless $tableName =~ / /;
            $short = $tableName = "$tableName Struct";
            my $maxLen = 0;
            $maxLen < length and $maxLen = length foreach keys %$isStruct;
            $$self{LONG_ID}{$tableName} = $maxLen;
        } else {
            $tableName = shift @tableNames;
            $short = $$shortName{$tableName};
            unless ($short) {
                # this is just an index heading
                print PODFILE "\n=head2 $tableName Tags\n";
                print PODFILE Doc2Pod($docs{$tableName}) if $docs{$tableName};
                next;
            }
        }
        my $isExif = ($tableName eq 'Image::ExifTool::Exif::Main');
        my $isRiff = ($tableName eq 'Image::ExifTool::RIFF::Info');
        my $isXmpMain = ($tableName eq 'Image::ExifTool::XMP::Main');
        my $info = $$tagNameInfo{$tableName};
        my $id = $$idLabel{$tableName};
        my ($hid, $showGrp);
        # widths of the different columns in the POD documentation
        my ($wID,$wTag,$wReq,$wGrp) = (8,36,24,10);
        my ($composite, $derived, $notes, $longTags, $wasLong, $prefix);
        if ($short eq 'Shortcuts') {
            $derived = '<th>Refers To</th>';
            $composite = 2;
        } elsif ($isStruct) {
            $derived = '';
            $notes = $$isStruct{NOTES};
        } else {
            my $table = GetTagTable($tableName);
            $notes = $$table{NOTES};
            $longTags = $$table{VARS}{LONG_TAGS} if $$table{VARS};
            if ($$table{GROUPS}{0} eq 'Composite') {
                $composite = 1;
                $derived = '<th>Derived From</th>';
            } else {
                $composite = 0;
                $derived = '';
            }
        }
        my $podIdLen = $self->{LONG_ID}->{$tableName};
        if ($notes) {
            # remove unnecessary whitespace
            $notes =~ s/^\s+//; $notes =~ s/\s+$//;
            $notes =~ s/(^[ \t]+|[ \t]+$)//mg;
            if ($notes =~ /leading '(.*?_)' which/) {
                $prefix = $1;
                $podIdLen -= length $prefix;
            }
        }
        if ($podIdLen <= $wID) {
            $podIdLen = $wID;
        } elsif ($short eq 'DICOM') {
            $podIdLen = 10;
        } else {
            # align tag names in secondary columns if possible
            my $col = ($podIdLen <= 10) ? 12 : 20;
            $podIdLen = $col if $podIdLen < $col;
        }
        if ($id) {
            ($hid = "<th>$id</th>") =~ s/ /&nbsp;/g;
            $wTag -= $podIdLen - $wID;
            $wID = $podIdLen;
            my $longTag = $self->{LONG_NAME}->{$tableName};
            if ($wTag < $longTag) {
                if ($wID - $longTag + $wTag >= 6) { # don't let ID column get too narrow
                    $wID -= $longTag - $wTag;
                    $wTag = $longTag;
                }
                $wasLong = 1 if $wID <= $self->{LONG_ID}->{$tableName};
            }
        } elsif ($composite) {
            $wTag += $wID - $wReq;
            $hid = '';
        } else {
            $wTag += 9;
            $hid = '';
        }
        if ($short eq 'EXIF' or $short eq 'Extra') {
            $derived = '<th>Group</th>';
            $showGrp = 1;
            $wGrp += 8 if $short eq 'Extra';    # tweak Group column width for "Extra" tags
            $wTag -= $wGrp + 1;
        }
        my $head = ($short =~ / /) ? 'head3' : 'head2';
        my $str = $isStruct ? '' : ' Tags';
        print PODFILE "\n=$head $short$str\n";
        print PODFILE Doc2Pod($docs{$short}) if $docs{$short};
        print PODFILE "\n", Doc2Pod($notes), "\n" if $notes;
        my $line = "\n";
        if ($id) {
            # shift over 'Index' heading by one character for a bit more balance
            $id = " $id" if $id eq 'Index';
            $line .= sprintf "  %-${wID}s", $id;
        } else {
            $line .= ' ';
        }
        my $tagNameHeading = ($short eq 'XMP') ? 'Namespace' : ($isStruct?'Field':'Tag').' Name';
        $line .= sprintf " %-${wTag}s", $tagNameHeading;
        $line .= sprintf " %-${wReq}s", $composite == 2 ? 'Refers To' : 'Derived From' if $composite;
        $line .= sprintf " %-${wGrp}s", 'Group' if $showGrp;
        $line .= ' Writable';
        print PODFILE $line;
        $line =~ s/^(\s*\w.{6}\w) /$1\t/;   # change space to tab after long ID label (eg. "Sequence")
        $line =~ s/\S/-/g;
        $line =~ s/- -/---/g;
        $line =~ tr/\t/ /;                  # change tab back to space
        print PODFILE $line,"\n";
        close HTMLFILE;
        OpenHtmlFile($htmldir, $short) or $success = 0;
        print HTMLFILE '<p>',Doc2Html($notes), "</p>\n" if $notes;
        print HTMLFILE "<blockquote>\n";
        print HTMLFILE "<table class=frame><tr><td>\n";
        print HTMLFILE "<table class=inner cellspacing=1>\n";
        print HTMLFILE "<tr class=h>$hid<th>$tagNameHeading</th>\n";
        print HTMLFILE "<th>Writable</th>$derived<th>Values / ${noteFont}Notes</span></th></tr>\n";
        my $rowClass = 1;
        my $infoCount = 0;
        my $infoList;
        foreach $infoList (@$info) {
            ++$infoCount;
            my ($tagIDstr, $tagNames, $writable, $values, $require, $writeGroup) = @$infoList;
            my ($align, $idStr, $w, $tip);
            my $wTag2 = $wTag;
            if (not $id) {
                $idStr = '  ';
            } elsif ($tagIDstr =~ /^-?\d+(\.\d+)?$/) {
                $w = $wID - 3;
                $idStr = sprintf "  %${w}g    ", $tagIDstr;
                $align = " class=r";
            } else {
                $tagIDstr =~ s/^'$prefix/'/ if $prefix;
                $w = $wID;
                my $over = length($tagIDstr) - $w;
                if ($over > 0) {
                    # shift over tag name if there is room
                    if ($over <= $wTag - length($$tagNames[0])) {
                        $wTag2 -= $over;
                        $w += $over;
                    } else {
                        # put tag name on next line if ID is too long
                        $idStr = "  $tagIDstr\n   " . (' ' x $w);
                        if ($longTags) {
                            --$longTags;
                        } else {
                            warn "Notice: Split $$tagNames[0] line\n";
                        }
                    }
                }
                $idStr = sprintf "  %-${w}s ", $tagIDstr unless defined $idStr;
                $align = '';
            }
            my @reqs;
            my @tags = @$tagNames;
            my @wGrp = @$writeGroup;
            my @vals = @$writable;
            my $wrStr = shift @vals;
            my $subdir;
            my @masks = grep /^\[Mask 0x[\da-f]+\]/, @$values;
            my $tag = shift @tags;
            # if this is a subdirectory or structure, print subdir name (from values) instead of writable
            if ($wrStr =~ /^[-=]/) {
                $subdir = 1;
                if (@masks) {
                    # combine any mask into the format string
                    $wrStr .= " & $1" if $masks[0] =~ /(0x[\da-f]+)/;
                    shift @masks;
                    @vals = grep !/^\[Mask 0x[\da-f]+\]/, @$values;
                } else {
                    @vals = @$values;
                }
                # remove Notes if subdir has Notes as well
                shift @vals if $vals[0] =~ /^\(/ and @vals >= @$writable;
                foreach (@vals) { /^\(/ and $_ = '-' }
                my $i;  # fill in any missing entries from non-directory tags
                for ($i=0; $i<@$writable; ++$i) {
                    $vals[$i] = $$writable[$i] unless defined $vals[$i];
                    if (@masks) {
                        $vals[$i] .= " & $1" if $masks[0] =~ /(0x[\da-f]+)/;
                        shift @masks;
                    }
                }
                if ($$sepTable{$vals[0]}) {
                    $wrStr =~ s/^[-=]//;
                    $wrStr = 'N' unless $wrStr;
                } elsif ($$structs{$vals[0]}) {
                    my $flags = $wrStr =~ /([+_]+)$/ ? $1 : '';
                    $wrStr = "$vals[0] Struct$flags";
                } else {
                    $wrStr = $vals[0];
                }
                shift @vals;
            } elsif ($wrStr and $wrStr ne 'N' and @masks) {
                # fill in missing entries if masks are different
                my $mask = shift @masks;
                while (@masks > @vals) {
                    last if $masks[@vals] eq $mask;
                    push @vals, $wrStr;
                    push @tags, $tag if @tags < @vals;
                }
                # add Mask to Writable column in POD doc
                $wrStr .= " & $1" if $mask =~ /(0x[\da-f]+)/;
            }
            printf PODFILE "%s%-${wTag2}s", $idStr, $tag;
            my $tGrp = $wGrp;
            if ($id and length($tag) > $wTag2) {
                my $madeRoom;
                if ($showGrp) {
                    my $wGrp0 = length($wGrp[0] || '-');
                    if (not $composite and $wGrp > $wGrp0) {
                        $tGrp = $wGrp - (length($tag) - $wTag2);
                        if ($tGrp < length $wGrp0) {
                            $tGrp = length $wGrp0;
                        } else {
                            $madeRoom = 1;
                        }
                    }
                }
                warn "Warning: Pushed $tag\n" unless $madeRoom;
            }
            printf PODFILE " %-${tGrp}s", shift(@wGrp) || '-' if $showGrp;
            if ($composite) {
                @reqs = @$require;
                $w = $wReq; # Keep writable column in line
                length($tag) > $wTag2 and $w -= length($tag) - $wTag2;
                printf PODFILE " %-${w}s", shift(@reqs) || '';
            }
            print PODFILE " $wrStr\n";
            my $numTags = scalar @$tagNames;
            my $n = 0;
            while (@tags or @reqs or @vals) {
                my $more = (@tags or @reqs);
                $line = '  ';
                $line .= ' 'x($wID+1) if $id;
                $line .= sprintf("%-${wTag2}s", shift(@tags) || '');
                $line .= sprintf(" %-${wReq}s", shift(@reqs) || '') if $composite;
                $line .= sprintf(" %-${wGrp}s", shift(@wGrp) || '-') if $showGrp;
                ++$n;
                if (@vals) {
                    my $val = shift @vals;
                    # use writable if this is a note
                    my $wrStr = $$writable[$n];
                    if ($subdir and ($val =~ /^\(/ or $val =~ /=/ or ($wrStr and $wrStr !~ /^[-=]/))) {
                        $val = $wrStr;
                        if (defined $val) {
                            $val =~ s/^[-=]//;
                        } else {
                            # done with tag if nothing else to print
                            last unless $more;
                        }
                    }
                    if (defined $val) {
                        $line .= " $val";
                        if (@masks) {
                            $line .= " & $1" if $masks[0] =~ /(0x[\da-f]+)/;
                            shift @masks;
                        }
                    }
                }
                $line =~ s/\s+$//;  # trim trailing white space
                print PODFILE "$line\n";
            }
            my @htmlTags;
            foreach (@$tagNames) {
                push @htmlTags, EscapeHTML($_);
            }
            if (($isExif and $exifSpec{hex $tagIDstr}) or
                ($isRiff and $tagIDstr=~/(\w+)/ and $riffSpec{$1}) or
                ($isXmpMain and $tagIDstr=~/([-\w]+)/ and $xmpSpec{$1}))
            {
                # underline "unknown" makernote tags only
                my $n = $tagIDstr eq '0x927c' ? -1 : 0;
                $htmlTags[$n] = "<u>$htmlTags[$n]</u>";
            }
            $rowClass = $rowClass ? '' : " class=b";
            my $isSubdir;
            if ($$writable[0] =~ /^[-=]/) {
                $isSubdir = 1;
                s/^[-=](.+)/$1/ foreach @$writable;
            }
            # add tooltip for hex conversion of Tag ID
            if ($tagIDstr =~ /^(0x[0-9a-f]+)(\.\d+)?$/i) {
                $tip = sprintf(" title='$tagIDstr = %u%s'", hex($1), $2||'');
            } elsif ($tagIDstr =~ /^(\d+)(\.\d*)?$/) {
                $tip = sprintf(" title='%u = 0x%x'", $1, $1);
            } else {
                $tip = '';
                # use copyright symbol in QuickTime UserData tags
                $tagIDstr =~ s/^"\\xa9/"&copy;/;
            }
            # add tooltip for special writable attributes
            my $wtip = '';
            my %wattr = (
                '_' => 'Flattened',
                '+' => 'List',
                '/' => 'Avoided',
                '~' => 'Writable only with -n',
                '!' => 'Unsafe',
                '*' => 'Protected',
                ':' => 'Mandatory',
            );
            my ($wstr, %hasAttr, @hasAttr);
            foreach $wstr (@$writable) {
                next unless $wstr =~ m{([+/~!*:_]+)$};
                my @a = split //, $1;
                foreach (@a) {
                    next if $hasAttr{$_};
                    push @hasAttr, $_;
                    $hasAttr{$_} = 1;
                }
            }
            if (@hasAttr) {
                $wtip = " title='";
                my $n = 0;
                foreach (@hasAttr) {
                    $wtip .= "\n" if $n;
                    $wtip .= " $_ = $wattr{$_}";
                    ++$n;
                }
                $wtip .= "'";
            }
            # print this row in the tag table
            print HTMLFILE "<tr$rowClass>\n";
            print HTMLFILE "<td$align$tip>$tagIDstr</td>\n" if $id;
            print HTMLFILE "<td>", join("\n  <br>",@htmlTags), "</td>\n";
            print HTMLFILE "<td class=c$wtip>",join('<br>',@$writable),"</td>\n";
            print HTMLFILE '<td class=n>',join("\n  <br>",@$require),"</td>\n" if $composite;
            print HTMLFILE "<td class=c>",join('<br>',@$writeGroup),"</td>\n" if $showGrp;
            print HTMLFILE "<td>";
            if (@$values) {
                if ($isSubdir) {
                    my ($smallNote, @values);
                    foreach (@$values) {
                        if (/^\(/) {
                            # set the note font
                            $smallNote = 1 if $numTags < 2;
                            push @values, ($smallNote ? $noteFontSmall : $noteFont) . "$_</span>";
                            next;
                        }
                        # make text in square brackets small
                        if (/^\[/) {
                            if (s/^\[!HTML\]//) {
                                push @values, $_;
                            } else {
                                push @values, "<span class=s>$_</span>";
                            }
                            next;
                        }
                        /=/ and push(@values, $_), next;
                        my @names = split;
                        my $suffix = ' Tags';
                        if ($$sepTable{$_}) {
                            push @sepTables, $_;
                            $suffix = ' Values';
                        }
                        # handle structures specially
                        if ($$structs{$_}) {
                            # assume XMP module for this struct unless otherwise specified
                            unshift @names, 'XMP' unless / /;
                            push @structs, $_;  # list this later
                            # hack to put Area Struct in with XMP tags,
                            # even though it is only used by the MWG module
                            push @structs, 'Area' if $_ eq 'Dimensions';
                            $suffix = ' Struct';
                        }
                        $url = (shift @names) . '.html';
                        @names and $url .= '#' . join '_', @names;
                        push @values, "--&gt; <a href='$url'>$_$suffix</a>";
                    }
                    # put small note last
                    $smallNote and push @values, shift @values;
                    print HTMLFILE join("\n  <br>",@values);
                } else {
                    my ($close, $br) = ('', '');
                    foreach (@$values) {
                        if (s/^\[!HTML\]//) {
                            print HTMLFILE $close if $close;
                            print HTMLFILE $_;
                            $close = $br = '';
                        } else {
                            if (/^\(/) {
                                # notes can use POD syntax
                                $_ = $noteFont . Doc2Html($_) . "</span>";
                            } else {
                                $_ = EscapeHTML($_);
                            }
                            $close or $_ = "<span class=s>$_", $close = '</span>';
                            print HTMLFILE $br, $_;
                            $br = "\n  <br>";
                        }
                    }
                    print HTMLFILE $close if $close;
                }
            } else {
                print HTMLFILE '&nbsp;';
            }
            print HTMLFILE "</td></tr>\n";
        }
        warn "$longTags unaccounted-for long tags in $tableName\n" if $longTags;
        if ($wasLong and not defined $longTags) {
            warn "Notice: Long tags in $tableName table\n";
        }
        unless ($infoCount) {
            print PODFILE "  [no tags known]\n";
            my $cols = 3;
            ++$cols if $hid;
            ++$cols if $derived;
            print HTMLFILE "<tr><td colspan=$cols class=c><i>[no tags known]</i></td></tr>\n";
        }
        print HTMLFILE "</table></td></tr></table></blockquote>\n\n";
    }
    close(HTMLFILE) or $success = 0;
    CloseHtmlFiles($self) or $success = 0;
    print PODFILE Doc2Pod($docs{PodTrailer}) or $success = 0;
    close(PODFILE) or $success = 0;
    return $success;
}

1;  # end


__END__

=head1 NAME

Image::ExifTool::BuildTagLookup - Build ExifTool tag lookup tables

=head1 DESCRIPTION

This module is used to generate the tag lookup tables in
Image::ExifTool::TagLookup.pm and tag name documentation in
Image::ExifTool::TagNames.pod, as well as HTML tag name documentation.  It
is used before each new ExifTool release to update the lookup tables and
documentation, but it is not used otherwise.  It also performs some
validation and consistency checks on the tag tables.

=head1 SYNOPSIS

  use Image::ExifTool::BuildTagLookup;

  $builder = new Image::ExifTool::BuildTagLookup;

  $ok = $builder->WriteTagLookup('lib/Image/ExifTool/TagLookup.pm');

  $ok = $builder->WriteTagNames('lib/Image/ExifTool/TagNames.pod','html');

=head1 MEMBER VARIABLES

=over 4

=item PRESERVE_DATE

Flag to preserve "Last revised" date in HTML files.  Set before calling
WriteTagNames().

=item COUNT

Reference to hash containing counting statistics.  Keys are the
descriptions, and values are the numerical counts.  Valid after
BuildTagLookup object is created, but additional statistics are added by
WriteTagNames().

=back

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>,
L<Image::ExifTool::TagLookup(3pm)|Image::ExifTool::TagLookup>,
L<Image::ExifTool::TagNames(3pm)|Image::ExifTool::TagNames>

=cut
