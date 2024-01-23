#------------------------------------------------------------------------------
# File:         WriteXMP.pl
#
# Description:  Write XMP meta information
#
# Revisions:    12/19/2004 - P. Harvey Created
#------------------------------------------------------------------------------
package Image::ExifTool::XMP;

use strict;
use vars qw(%specialStruct %dateTimeInfo %stdXlatNS);

use Image::ExifTool qw(:DataAccess :Utils);

sub CheckXMP($$$;$);
sub CaptureXMP($$$;$);
sub SetPropertyPath($$;$$$$);

my $debug = 0;
my $numPadLines = 24;       # number of blank padding lines

# when writing extended XMP, resources bigger than this get placed in their own
# rdf:Description so they can be moved to the extended segments if necessary
my $newDescThresh = 10240;  # 10 kB

# individual resources and namespaces to place last in separate rdf:Description's
# so they can be moved to extended XMP segments if required (see Oct. 2008 XMP spec)
my %extendedRes = (
    'photoshop:History' => 1,
    'xap:Thumbnails' => 1,
    'xmp:Thumbnails' => 1,
    'crs' => 1,
    'crss' => 1,
);

my $rdfDesc = 'rdf:Description';
#
# packet/xmp/rdf headers and trailers
#
my $pktOpen = "<?xpacket begin='\xef\xbb\xbf' id='W5M0MpCehiHzreSzNTczkc9d'?>\n";
my $xmlOpen = "<?xml version='1.0' encoding='UTF-8'?>\n";
my $xmpOpenPrefix = "<x:xmpmeta xmlns:x='$nsURI{x}'";
my $rdfOpen = "<rdf:RDF xmlns:rdf='$nsURI{rdf}'>\n";
my $rdfClose = "</rdf:RDF>\n";
my $xmpClose = "</x:xmpmeta>\n";
my $pktCloseW =  "<?xpacket end='w'?>"; # writable by default
my $pktCloseR =  "<?xpacket end='r'?>";
my ($sp, $nl);

#------------------------------------------------------------------------------
# Get XMP opening tag (and set x:xmptk appropriately)
# Inputs: 0) ExifTool object ref
# Returns: x:xmpmeta opening tag
sub XMPOpen($)
{
    my $et = shift;
    my $nv = $$et{NEW_VALUE}{$Image::ExifTool::XMP::x{xmptk}};
    my $tk;
    if (defined $nv) {
        $tk = $et->GetNewValue($nv);
        $et->VerboseValue(($tk ? '+' : '-') . ' XMP-x:XMPToolkit', $tk);
        ++$$et{CHANGED};
    } else {
        $tk = "Image::ExifTool $Image::ExifTool::VERSION";
    }
    my $str = $tk ? (" x:xmptk='" . EscapeXML($tk) . "'") : '';
    return "$xmpOpenPrefix$str>\n";
}

#------------------------------------------------------------------------------
# Validate XMP packet and set read or read/write mode
# Inputs: 0) XMP data reference, 1) 'r' = read only, 'w' or undef = read/write
# Returns: true if XMP is good (and adds packet header/trailer if necessary)
sub ValidateXMP($;$)
{
    my ($xmpPt, $mode) = @_;
    $$xmpPt =~ s/^\s*<!--.*?-->\s*//s; # remove leading comment if it exists
    unless ($$xmpPt =~ /^\0*<\0*\?\0*x\0*p\0*a\0*c\0*k\0*e\0*t/) {
        return '' unless $$xmpPt =~ /^<x(mp)?:x[ma]pmeta/;
        # add required xpacket header/trailer
        $$xmpPt = $pktOpen . $$xmpPt . $pktCloseW;
    }
    $mode = 'w' unless $mode;
    my $end = substr($$xmpPt, -32, 32);
    # check for proper xpacket trailer and set r/w mode if necessary
    return '' unless $end =~ s/(e\0*n\0*d\0*=\0*['"]\0*)([rw])(\0*['"]\0*\?\0*>)/$1$mode$3/;
    substr($$xmpPt, -32, 32) = $end if $2 ne $mode;
    return 1;
}

#------------------------------------------------------------------------------
# Validate XMP property
# Inputs: 0) ExifTool ref, 1) validate hash ref, 2) attribute hash ref
# - issues warnings if problems detected
sub ValidateProperty($$;$)
{
    my ($et, $propList, $attr) = @_;

    if ($$et{XmpValidate} and @$propList > 2) {
        if ($$propList[0] =~ /^x:x[ma]pmeta$/ and
            $$propList[1] eq 'rdf:RDF' and
            $$propList[2] =~ /rdf:Description( |$)/)
        {
            if (@$propList > 3) {
                if ($$propList[-1] =~ /^rdf:(Bag|Seq|Alt)$/) {
                    $et->Warn("Ignored empty $$propList[-1] list for $$propList[-2]", 1);
                } else {
                    if ($$propList[-2] eq 'rdf:Alt' and $attr) {
                        my $lang = $$attr{'xml:lang'};
                        if ($lang and @$propList >= 5) {
                            my $langPath = join('/', @$propList[3..($#$propList-2)]);
                            my $valLang = $$et{XmpValidateLangAlt} || ($$et{XmpValidateLangAlt} = { });
                            $$valLang{$langPath} or $$valLang{$langPath} = { };
                            if ($$valLang{$langPath}{$lang}) {
                                $et->WarnOnce("Duplicate language ($lang) in lang-alt list: $langPath");
                            } else {
                                $$valLang{$langPath}{$lang} = 1;
                            }
                        }
                    }
                    my $xmpValidate = $$et{XmpValidate};
                    my $path = join('/', @$propList[3..$#$propList]);
                    if (defined $$xmpValidate{$path}) {
                        $et->Warn("Duplicate XMP property: $path");
                    } else {
                        $$xmpValidate{$path} = 1;
                    }
                }
            }
        } elsif ($$propList[0] ne 'rdf:RDF' or
                 $$propList[1] !~ /rdf:Description( |$)/)
        {
            $et->Warn('Improperly enclosed XMP property: ' . join('/',@$propList));
        }
    }
}

#------------------------------------------------------------------------------
# Check XMP date values for validity and format accordingly
# Inputs: 1) EXIF-format date string (XMP-format also accepted)
# Returns: XMP date/time string (or undef on error)
sub FormatXMPDate($)
{
    my $val = shift;
    my ($y, $m, $d, $t, $tz);
    if ($val =~ /(\d{4}):(\d{2}):(\d{2}) (\d{2}:\d{2}(?::\d{2}(?:\.\d*)?)?)(.*)/ or
        $val =~ /(\d{4})-(\d{2})-(\d{2})T(\d{2}:\d{2}(?::\d{2}(?:\.\d*)?)?)(.*)/)
    {
        ($y, $m, $d, $t, $tz) = ($1, $2, $3, $4, $5);
        $val = "$y-$m-${d}T$t";
    } elsif ($val =~ /^\s*\d{4}(:\d{2}){0,2}\s*$/) {
        # this is just a date (YYYY, YYYY-mm or YYYY-mm-dd)
        $val =~ tr/:/-/;
    } elsif ($val =~ /^\s*(\d{2}:\d{2}(?::\d{2}(?:\.\d*)?)?)(.*)\s*$/) {
        # this is just a time
        ($t, $tz) = ($1, $2);
        $val = $t;
    } else {
        return undef;
    }
    if ($tz) {
        $tz =~ /^(Z|[+-]\d{2}:\d{2})$/ or return undef;
        $val .= $tz;
    }
    return $val;
}

#------------------------------------------------------------------------------
# Check XMP values for validity and format accordingly
# Inputs: 0) ExifTool object ref, 1) tagInfo hash ref, 2) raw value ref, 3) conversion type
# Returns: error string or undef (and may change value) on success
# Note: copies structured information to avoid conflicts with calling code
sub CheckXMP($$$;$)
{
    my ($et, $tagInfo, $valPtr, $convType) = @_;

    if ($$tagInfo{Struct}) {
        require 'Image/ExifTool/XMPStruct.pl';
        my ($item, $err, $w, $warn);
        unless (ref $$valPtr) {
            ($$valPtr, $warn) = InflateStruct($et, $valPtr);
            # expect a structure HASH ref or ARRAY of structures
            unless (ref $$valPtr) {
                $$valPtr eq '' and $$valPtr = { }, return undef; # allow empty structures
                return 'Improperly formed structure';
            }
        }
        if (ref $$valPtr eq 'ARRAY') {
            return 'Not a list tag' unless $$tagInfo{List};
            my @copy = ( @{$$valPtr} ); # copy the list for ExifTool to use
            $$valPtr = \@copy;          # return the copy
            foreach $item (@copy) {
                unless (ref $item eq 'HASH') {
                    ($item, $w) = InflateStruct($et, \$item); # deserialize structure
                    $w and $warn = $w;
                    next if ref $item eq 'HASH';
                    $err = 'Improperly formed structure';
                    last;
                }
                ($item, $err) = CheckStruct($et, $item, $$tagInfo{Struct});
                last if $err;
            }
        } else {
            ($$valPtr, $err) = CheckStruct($et, $$valPtr, $$tagInfo{Struct});
        }
        $warn and $$et{CHECK_WARN} = $warn;
        return $err;
    }
    my $format = $$tagInfo{Writable};
    # (if no format specified, value is a simple string)
    if (not $format or $format eq 'string' or $format eq 'lang-alt') {
        # convert value to UTF8 if necessary
        if ($$et{OPTIONS}{Charset} ne 'UTF8') {
            if ($$valPtr =~ /[\x80-\xff]/) {
                # convert from Charset to UTF-8
                $$valPtr = $et->Encode($$valPtr,'UTF8');
            }
        } else {
            # translate invalid XML characters to "."
            $$valPtr =~ tr/\0-\x08\x0b\x0c\x0e-\x1f/./;
            # fix any malformed UTF-8 characters
            if (FixUTF8($valPtr) and not $$et{WarnBadUTF8}) {
                $et->Warn('Malformed UTF-8 character(s)');
                $$et{WarnBadUTF8} = 1;
            }
        }
        return undef;   # success
    }
    if ($format eq 'rational' or $format eq 'real') {
        # make sure the value is a valid floating point number
        unless (Image::ExifTool::IsFloat($$valPtr) or
            # allow 'inf' and 'undef' rational values
            ($format eq 'rational' and ($$valPtr eq 'inf' or
             $$valPtr eq 'undef' or Image::ExifTool::IsRational($$valPtr))))
        {
            return 'Not a floating point number';
        }
        if ($format eq 'rational') {
            $$valPtr = join('/', Image::ExifTool::Rationalize($$valPtr));
        }
    } elsif ($format eq 'integer') {
        # make sure the value is integer
        if (Image::ExifTool::IsInt($$valPtr)) {
            # no conversion required (converting to 'int' would remove leading '+')
        } elsif (Image::ExifTool::IsHex($$valPtr)) {
            $$valPtr = hex($$valPtr);
        } else {
            return 'Not an integer';
        }
    } elsif ($format eq 'date') {
        my $newDate = FormatXMPDate($$valPtr);
        return "Invalid date/time (use YYYY:mm:dd HH:MM:SS[.ss][+/-HH:MM|Z])" unless $newDate;
        $$valPtr = $newDate;
    } elsif ($format eq 'boolean') {
        # (allow lower-case 'true' and 'false' if not setting PrintConv value)
        if (not $$valPtr or $$valPtr =~ /false/i or $$valPtr =~ /^no$/i) {
            if (not $$valPtr or $$valPtr ne 'false' or not $convType or $convType eq 'PrintConv') {
                $$valPtr = 'False';
            }
        } elsif ($$valPtr ne 'true' or not $convType or $convType eq 'PrintConv') {
            $$valPtr = 'True';
        }
    } elsif ($format eq '1') {
        # this is the entire XMP data block
        return 'Invalid XMP data' unless ValidateXMP($valPtr);
    } else {
        return "Unknown XMP format: $format";
    }
    return undef;   # success!
}

#------------------------------------------------------------------------------
# Get PropertyPath for specified tagInfo
# Inputs: 0) tagInfo reference
# Returns: PropertyPath string
sub GetPropertyPath($)
{
    my $tagInfo = shift;
    SetPropertyPath($$tagInfo{Table}, $$tagInfo{TagID}) unless $$tagInfo{PropertyPath};
    return $$tagInfo{PropertyPath};
}

#------------------------------------------------------------------------------
# Set PropertyPath for specified tag (also for associated flattened tags and structure elements)
# Inputs: 0) tagTable reference, 1) tagID, 2) tagID of parent structure,
#         3) structure definition ref (or undef), 4) property list up to this point (or undef),
#         5) flag set if any containing structure has a TYPE
# Notes: also generates flattened tags if they don't already exist
sub SetPropertyPath($$;$$$$)
{
    my ($tagTablePtr, $tagID, $parentID, $structPtr, $propList, $isType) = @_;
    my $table = $structPtr || $tagTablePtr;
    my $tagInfo = $$table{$tagID};
    my $flatInfo;

    return if ref($tagInfo) ne 'HASH'; # (shouldn't happen)

    if ($structPtr) {
        my $flatID = $parentID . ucfirst($tagID);
        $flatInfo = $$tagTablePtr{$flatID};
        if ($flatInfo) {
            return if $$flatInfo{PropertyPath};
        } elsif (@$propList > 50) {
            return; # avoid deep recursion
        } else {
            # flattened tag doesn't exist, so create it now
            # (could happen if we were just writing a structure)
            $flatInfo = { Name => ucfirst($flatID), Flat => 1 };
            AddTagToTable($tagTablePtr, $flatID, $flatInfo);
        }
        $isType = 1 if $$structPtr{TYPE};
    } else {
        # don't override existing main table entry if already set by a Struct
        return if $$tagInfo{PropertyPath};
        # use property path from original tagInfo if this is an alternate-language tag
        my $srcInfo = $$tagInfo{SrcTagInfo};
        $$tagInfo{PropertyPath} = GetPropertyPath($srcInfo) if $srcInfo;
        return if $$tagInfo{PropertyPath};
        # set property path for all flattened tags in structure if necessary
        if ($$tagInfo{RootTagInfo}) {
            SetPropertyPath($tagTablePtr, $$tagInfo{RootTagInfo}{TagID});
            return if $$tagInfo{PropertyPath};
            warn "Internal Error: Didn't set path from root for $tagID\n";
            warn "(Is the Struct NAMESPACE defined?)\n";
        }
    }
    my $ns = $$tagInfo{Namespace} || $$table{NAMESPACE};
    $ns or warn("No namespace for $tagID\n"), return;
    my (@propList, $listType);
    $propList and @propList = @$propList;
    push @propList, "$ns:$tagID";
    # lang-alt lists are handled specially, signified by Writable='lang-alt'
    if ($$tagInfo{Writable} and $$tagInfo{Writable} eq 'lang-alt') {
        $listType = 'Alt';
        # remove language code from property path if it exists
        $propList[-1] =~ s/-$$tagInfo{LangCode}$// if $$tagInfo{LangCode};
        # handle lists of lang-alt lists (eg. XMP-plus:Custom tags)
        if ($$tagInfo{List} and $$tagInfo{List} ne '1') {
            push @propList, "rdf:$$tagInfo{List}", 'rdf:li 10';
        }
    } else {
        $listType = $$tagInfo{List};
    }
    # add required properties if this is a list
    push @propList, "rdf:$listType", 'rdf:li 10' if $listType and $listType ne '1';
    # set PropertyPath for all flattened tags of this structure if necessary
    my $strTable = $$tagInfo{Struct};
    if ($strTable and not ($parentID and
        # must test NoSubStruct flag to avoid infinite recursion
        (($$tagTablePtr{$parentID} and $$tagTablePtr{$parentID}{NoSubStruct}) or
        length $parentID > 500))) # avoid deep recursion
    {
        # make sure the structure namespace has been registered
        # (user-defined namespaces may not have been)
        RegisterNamespace($strTable) if ref $$strTable{NAMESPACE};
        my $tag;
        foreach $tag (keys %$strTable) {
            # ignore special fields and any lang-alt fields we may have added
            next if $specialStruct{$tag} or $$strTable{$tag}{LangCode};
            my $fullID = $parentID ? $parentID . ucfirst($tagID) : $tagID;
            SetPropertyPath($tagTablePtr, $tag, $fullID, $strTable, \@propList, $isType);
        }
    }
    # if this was a structure field and not a normal tag,
    # we set PropertyPath in the corresponding flattened tag
    if ($structPtr) {
        $tagInfo = $flatInfo;
        # set StructType flag if any containing structure has a TYPE
        $$tagInfo{StructType} = 1 if $isType;
    }
    # set property path for tagInfo in main table
    $$tagInfo{PropertyPath} = join '/', @propList;
}

#------------------------------------------------------------------------------
# Save XMP property name/value for rewriting
# Inputs: 0) ExifTool object reference
#         1) reference to array of XMP property path (last is current property)
#         2) property value, 3) optional reference to hash of property attributes
sub CaptureXMP($$$;$)
{
    my ($et, $propList, $val, $attrs) = @_;
    return unless defined $val and @$propList > 2;
    if ($$propList[0] =~ /^x:x[ma]pmeta$/ and
        $$propList[1] eq 'rdf:RDF' and
        $$propList[2] =~ /$rdfDesc( |$)/)
    {
        # no properties to save yet if this is just the description
        return unless @$propList > 3;
        # ignore empty list properties
        if ($$propList[-1] =~ /^rdf:(Bag|Seq|Alt)$/) {
            $et->Warn("Ignored empty $$propList[-1] list for $$propList[-2]", 1);
            return;
        }
        # save information about this property
        my $capture = $$et{XMP_CAPTURE};
        my $path = join('/', @$propList[3..$#$propList]);
        if (defined $$capture{$path}) {
            $$et{XMP_ERROR} = "Duplicate XMP property: $path";
        } else {
            $$capture{$path} = [$val, $attrs || { }];
        }
    } elsif ($$propList[0] eq 'rdf:RDF' and
             $$propList[1] =~ /$rdfDesc( |$)/)
    {
        # set flag so we don't write x:xmpmeta element
        $$et{XMP_NO_XMPMETA} = 1;
        # add missing x:xmpmeta element and try again
        unshift @$propList, 'x:xmpmeta';
        CaptureXMP($et, $propList, $val, $attrs);
    } else {
        $$et{XMP_ERROR} = 'Improperly enclosed XMP property: ' . join('/',@$propList);
    }
}

#------------------------------------------------------------------------------
# Save information about resource containing blank node with nodeID
# Inputs: 0) reference to blank node information hash
#         1) reference to property list
#         2) property value
#         3) [optional] reference to attribute hash
# Notes: This routine and ProcessBlankInfo() are also used for reading information, but
#        are uncommon so are put in this file to reduce compile time for the common case
sub SaveBlankInfo($$$;$)
{
    my ($blankInfo, $propListPt, $val, $attrs) = @_;

    my $propPath = join '/', @$propListPt;
    my @ids = ($propPath =~ m{ #([^ /]*)}g);
    my $id;
    # split the property path at each nodeID
    foreach $id (@ids) {
        my ($pre, $prop, $post) = ($propPath =~ m{^(.*?)/([^/]*) #$id((/.*)?)$});
        defined $pre or warn("internal error parsing nodeID's"), next;
        # the element with the nodeID should be in the path prefix for subject
        # nodes and the path suffix for object nodes
        unless ($prop eq $rdfDesc) {
            if ($post) {
                $post = "/$prop$post";
            } else {
                $pre = "$pre/$prop";
            }
        }
        $$blankInfo{Prop}{$id}{Pre}{$pre} = 1;
        if ((defined $post and length $post) or (defined $val and length $val)) {
            # save the property value and attributes for each unique path suffix
            $$blankInfo{Prop}{$id}{Post}{$post} = [ $val, $attrs, $propPath ];
        }
    }
}

#------------------------------------------------------------------------------
# Process blank-node information
# Inputs: 0) ExifTool object ref, 1) tag table ref,
#         2) blank node information hash ref, 3) flag set for writing
sub ProcessBlankInfo($$$;$)
{
    my ($et, $tagTablePtr, $blankInfo, $isWriting) = @_;
    $et->VPrint(1, "  [Elements with nodeID set:]\n") unless $isWriting;
    my ($id, $pre, $post);
    # handle each nodeID separately
    foreach $id (sort keys %{$$blankInfo{Prop}}) {
        my $path = $$blankInfo{Prop}{$id};
        # flag all resource names so we can warn later if some are unused
        my %unused;
        foreach $post (keys %{$$path{Post}}) {
            $unused{$post} = 1;
        }
        # combine property paths for all possible paths through this node
        foreach $pre (sort keys %{$$path{Pre}}) {
            # there will be no description for the object of a blank node
            next unless $pre =~ m{/$rdfDesc/};
            foreach $post (sort keys %{$$path{Post}}) {
                my @propList = split m{/}, "$pre$post";
                my ($val, $attrs) = @{$$path{Post}{$post}};
                if ($isWriting) {
                    CaptureXMP($et, \@propList, $val, $attrs);
                } else {
                    FoundXMP($et, $tagTablePtr, \@propList, $val);
                }
                delete $unused{$post};
            }
        }
        # save information from unused properties (if RDF is malformed like f-spot output)
        if (%unused) {
            $et->Options('Verbose') and $et->Warn('An XMP resource is about nothing');
            foreach $post (sort keys %unused) {
                my ($val, $attrs, $propPath) = @{$$path{Post}{$post}};
                my @propList = split m{/}, $propPath;
                if ($isWriting) {
                    CaptureXMP($et, \@propList, $val, $attrs);
                } else {
                    FoundXMP($et, $tagTablePtr, \@propList, $val);
                }
            }
        }
    }
}

#------------------------------------------------------------------------------
# Convert path to namespace used in file (this is a pain, but the XMP
# spec only suggests 'preferred' namespace prefixes...)
# Inputs: 0) ExifTool object reference, 1) property path
# Returns: conforming property path
sub ConformPathToNamespace($$)
{
    my ($et, $path) = @_;
    my @propList = split('/',$path);
    my $nsUsed = $$et{XMP_NS};
    my $prop;
    foreach $prop (@propList) {
        my ($ns, $tag) = $prop =~ /(.+?):(.*)/;
        next if not defined $ns or $$nsUsed{$ns};
        my $uri = $nsURI{$ns};
        unless ($uri) {
            warn "No URI for namespace prefix $ns!\n";
            next;
        }
        my $ns2;
        foreach $ns2 (keys %$nsUsed) {
            next unless $$nsUsed{$ns2} eq $uri;
            # use the existing namespace prefix instead of ours
            $prop = "$ns2:$tag";
            last;
        }
    }
    return join('/',@propList);
}

#------------------------------------------------------------------------------
# Add necessary rdf:type element when writing structure
# Inputs: 0) ExifTool ref, 1) tag table ref, 2) capture hash ref, 3) path string
#         4) optional base path (already conformed to namespace) for elements in
#            variable-namespace structures
sub AddStructType($$$$;$)
{
    my ($et, $tagTablePtr, $capture, $path, $basePath) = @_;
    my @props = split '/', $path;
    my %doneID;
    for (;;) {
        pop @props;
        last unless @props;
        my $tagID = GetXMPTagID(\@props);
        next if $doneID{$tagID};
        $doneID{$tagID} = 1;
        my $tagInfo = $$tagTablePtr{$tagID};
        last unless ref $tagInfo eq 'HASH';
        if ($$tagInfo{Struct}) {
            my $type = $$tagInfo{Struct}{TYPE};
            if ($type) {
                my $pat = $$tagInfo{PropertyPath};
                $pat or warn("Missing PropertyPath in AddStructType\n"), last;
                $pat = ConformPathToNamespace($et, $pat);
                $pat =~  s/ \d+/ \\d\+/g;
                $path =~ /^($pat)/ or warn("Wrong path in AddStructType\n"), last;
                my $p = $1 . '/rdf:type';
                $p = "$basePath/$p" if $basePath;
                $$capture{$p} = [ '', { 'rdf:resource' => $type } ] unless $$capture{$p};
            }
        }
        last unless $$tagInfo{StructType};
    }
}

#------------------------------------------------------------------------------
# Process SphericalVideoXML (see XMP-GSpherical tags documentation)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: SphericalVideoXML data
sub ProcessGSpherical($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    # extract SphericalVideoXML as a block if requested
    if ($$et{REQ_TAG_LOOKUP}{sphericalvideoxml}) {
        $et->FoundTag(SphericalVideoXML => substr(${$$dirInfo{DataPt}}, 16));
    }
    return Image::ExifTool::XMP::ProcessXMP($et, $dirInfo, $tagTablePtr);
}

#------------------------------------------------------------------------------
# Hack to use XMP writer for SphericalVideoXML (see XMP-GSpherical tags documentation)
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Returns: SphericalVideoXML data
sub WriteGSpherical($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $$dirInfo{Compact} = 1,
    my $dataPt = $$dirInfo{DataPt};
    if ($dataPt and $$dataPt) {
        # make it look like XMP for writing
        my $buff = $$dataPt;
        $buff =~ s/<rdf:SphericalVideo/<?xpacket begin='.*?' id='W5M0MpCehiHzreSzNTczkc9d'?>\n<x:xmpmeta xmlns:x='adobe:ns:meta\/'><rdf:RDF/;
        $buff =~ s/\s*xmlns:GSpherical/>\n<rdf:Description xmlns:GSpherical/s;
        $buff =~ s/<\/rdf:SphericalVideo>/<\/rdf:Description>/;
        $buff .= "</rdf:RDF></x:xmpmeta><?xpacket end='w'?>";
        $$dirInfo{DataPt} = \$buff;
        $$dirInfo{DirLen} = length($buff) - ($$dirInfo{DirStart} || 0);
    }
    my $xmp = Image::ExifTool::XMP::WriteXMP($et, $dirInfo, $tagTablePtr);
    if ($xmp) {
        # change back to rdf:SphericalVideo structure
        $xmp =~ s/^<\?xpacket begin.*?<rdf:RDF/<rdf:SphericalVideo\n/s;
        $xmp =~ s/>\s*<rdf:Description rdf:about=''\s*/\n /;
        $xmp =~ s/\s*<\/rdf:Description>\s*(<\/rdf:RDF>)/\n<\/rdf:SphericalVideo>$1/s;
        $xmp =~ s/\s*<\/rdf:RDF>\s*<\/x:xmpmeta>.*//s;
    }
    return $xmp;
}

#------------------------------------------------------------------------------
# Utility routine to encode data in base64
# Inputs: 0) binary data string, 1) flag to avoid inserting newlines
# Returns:   base64-encoded string
sub EncodeBase64($;$)
{
    # encode the data in 45-byte chunks
    my $chunkSize = 45;
    my $len = length $_[0];
    my $str = '';
    my $i;
    for ($i=0; $i<$len; $i+=$chunkSize) {
        my $n = $len - $i;
        $n = $chunkSize if $n > $chunkSize;
        # add uuencoded data to output (minus size byte, but including trailing newline)
        $str .= substr(pack('u', substr($_[0], $i, $n)), 1);
    }
    # convert to base64 (remember that "\0" may be encoded as ' ' or '`')
    $str =~ tr/` -_/AA-Za-z0-9+\//;
    # convert pad characters at the end (remember to account for trailing newline)
    my $pad = 3 - ($len % 3);
    substr($str, -$pad-1, $pad) = ('=' x $pad) if $pad < 3;
    $str =~ tr/\n//d if $_[1];  # remove newlines if specified
    return $str;
}

#------------------------------------------------------------------------------
# sort tagInfo hash references by tag name
sub ByTagName
{
    return $$a{Name} cmp $$b{Name};
}

#------------------------------------------------------------------------------
# sort alphabetically, but with rdf:type first in the structure
sub TypeFirst
{
    if ($a =~ /rdf:type$/) {
        return substr($a, 0, -8) cmp $b unless $b =~ /rdf:type$/;
    } elsif ($b =~ /rdf:type$/) {
        return $a cmp substr($b, 0, -8);
    }
    return $a cmp $b;
}

#------------------------------------------------------------------------------
# Limit size of XMP
# Inputs: 0) ExifTool object ref, 1) XMP data ref (written up to start of $rdfClose),
#         2) max XMP len, 3) rdf:about string, 4) list ref for description start offsets
#         5) start offset of first description recommended for extended XMP
# Returns: 0) extended XMP ref, 1) GUID and updates $$dataPt (or undef if no extended XMP)
sub LimitXMPSize($$$$$$)
{
    my ($et, $dataPt, $maxLen, $about, $startPt, $extStart) = @_;

    # return straight away if it isn't too big
    return undef if length($$dataPt) < $maxLen;

    push @$startPt, length($$dataPt);  # add end offset to list
    my $newData = substr($$dataPt, 0, $$startPt[0]);
    my $guid = '0' x 32;
    # write the required xmpNote:HasExtendedXMP property
    $newData .= "$nl$sp<$rdfDesc rdf:about='${about}'\n$sp${sp}xmlns:xmpNote='$nsURI{xmpNote}'";
    if ($$et{OPTIONS}{Compact}{Shorthand}) {
        $newData .= "\n$sp${sp}xmpNote:HasExtendedXMP='${guid}'/>\n";
    } else {
        $newData .= ">$nl$sp$sp<xmpNote:HasExtendedXMP>$guid</xmpNote:HasExtendedXMP>$nl$sp</$rdfDesc>\n";
    }

    my ($i, %descSize, $start);
    # calculate all description block sizes
    for ($i=1; $i<@$startPt; ++$i) {
        $descSize{$$startPt[$i-1]} = $$startPt[$i] - $$startPt[$i-1];
    }
    pop @$startPt;    # remove end offset
    # write the descriptions from smallest to largest, as many in main XMP as possible
    my @descStart = sort { $descSize{$a} <=> $descSize{$b} } @$startPt;
    my $extData = XMPOpen($et) . $rdfOpen;
    for ($i=0; $i<2; ++$i) {
      foreach $start (@descStart) {
        # write main XMP first (in order of size), then extended XMP afterwards (in order)
        next if $i xor $start >= $extStart;
        my $pt = (length($newData) + $descSize{$start} > $maxLen) ? \$extData : \$newData;
        $$pt .= substr($$dataPt, $start, $descSize{$start});
      }
    }
    $extData .= $rdfClose . $xmpClose;  # close rdf:RDF and x:xmpmeta
    # calculate GUID from MD5 of extended XMP data
    if (eval { require Digest::MD5 }) {
        $guid = uc unpack('H*', Digest::MD5::md5($extData));
        $newData =~ s/0{32}/$guid/;     # update GUID in main XMP segment
    }
    $et->VerboseValue('+ XMP-xmpNote:HasExtendedXMP', $guid);
    $$dataPt = $newData;        # return main XMP block
    return (\$extData, $guid);  # return extended XMP and its GUID
}

#------------------------------------------------------------------------------
# Close out bottom-level property
# Inputs: 0) current property path list ref, 1) longhand properties at each resource
#         level, 2) shorthand properties at each resource level, 3) resource flag for
#         each property path level (set only if Shorthand is enabled)
sub CloseProperty($$$$)
{
    my ($curPropList, $long, $short, $resFlag) = @_;

    my $prop = pop @$curPropList;
    $prop =~ s/ .*//;       # remove list index if it exists
    my $pad = $sp x (scalar(@$curPropList) + 1);
    if ($$resFlag[@$curPropList]) {
        # close this XMP structure with possible shorthand properties
        if (length $$short[-1]) {
            if (length $$long[-1]) {
                # require a new Description if both longhand and shorthand properties
                $$long[-2] .= ">$nl$pad<$rdfDesc";
                $$short[-1] .= ">$nl";
                $$long[-1] .= "$pad</$rdfDesc>$nl";
            } else {
                # simply close empty property if all shorthand
                $$short[-1] .= "/>$nl";
            }
        } else {
            # use "parseType" instead of opening a new Description
            $$long[-2] .= ' rdf:parseType="Resource"';
            $$short[-1] = length $$long[-1] ? ">$nl" : "/>$nl";
        }
        $$long[-1] .= "$pad</$prop>$nl" if length $$long[-1];
        $$long[-2] .= $$short[-1] . $$long[-1];
        pop @$short;
        pop @$long;
    } elsif (defined $$resFlag[@$curPropList]) {
        # close this top level Description with possible shorthand values
        if (length $$long[-1]) {
            $$long[-2] .= $$short[-1] . ">$nl" . $$long[-1] . "$pad</$prop>$nl";
        } else {
            $$long[-2] .= $$short[-1] . "/>$nl"; # empty element (ie. all shorthand)
        }
        $$short[-1] = $$long[-1] = '';
    } else {
        # close this property (no chance of shorthand)
        $$long[-1] .= "$pad</$prop>$nl";
        unless (@$curPropList) {
            # add properties now that this top-level Description is complete
            $$long[-2] .= ">$nl" . $$long[-1];
            $$long[-1] = '';
        }
    }
    $#$resFlag = $#$curPropList;    # remove expired resource flags
}

#------------------------------------------------------------------------------
# Write XMP information
# Inputs: 0) ExifTool ref, 1) source dirInfo ref (with optional WriteGroup),
#         2) [optional] tag table ref
# Returns: with tag table: new XMP data (may be empty if no XMP data) or undef on error
#          without tag table: 1 on success, 0 if not valid XMP file, -1 on write error
# Notes: May set dirInfo InPlace flag to rewrite with specified DirLen (=2 to allow larger)
#        May set dirInfo ReadOnly flag to write as read-only XMP ('r' mode and no padding)
#        May set dirInfo Compact flag to force compact (drops 2kB of padding)
#        May set dirInfo MaxDataLen to limit output data length -- this causes ExtendedXMP
#          and ExtendedGUID to be returned in dirInfo if extended XMP was required
sub WriteXMP($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access to autoload this package
    my $dataPt = $$dirInfo{DataPt};
    my (%capture, %nsUsed, $xmpErr, $about);
    my $changed = 0;
    my $xmpFile = (not $tagTablePtr);   # this is an XMP data file if no $tagTablePtr
    # prefer XMP over other metadata formats in some types of files
    my $preferred = $xmpFile || ($$et{PreferredGroup} and $$et{PreferredGroup} eq 'XMP');
    my $verbose = $$et{OPTIONS}{Verbose};
    my %compact = ( %{$$et{OPTIONS}{Compact}} ); # (make a copy so we can change settings)
    my $dirLen = $$dirInfo{DirLen};
    $dirLen = length($$dataPt) if not defined $dirLen and $dataPt;
#
# extract existing XMP information into %capture hash
#
    # define hash in ExifTool object to capture XMP information (also causes
    # CaptureXMP() instead of FoundXMP() to be called from ParseXMPElement())
    #
    # The %capture hash is keyed on the complete property path beginning after
    # rdf:RDF/rdf:Description/.  The values are array references with the
    # following entries: 0) value, 1) attribute hash reference.
    $$et{XMP_CAPTURE} = \%capture;
    $$et{XMP_NS} = \%nsUsed;
    delete $$et{XMP_NO_XMPMETA};
    delete $$et{XMP_NO_XPACKET};
    delete $$et{XMP_IS_XML};
    delete $$et{XMP_IS_SVG};

    # set current padding characters
    ($sp, $nl) = ($compact{NoIndent} ? '' : ' ', $compact{NoNewline} ? '' : "\n");

    # get value for new rdf:about
    my $tagInfo = $Image::ExifTool::XMP::rdf{about};
    if (defined $$et{NEW_VALUE}{$tagInfo}) {
        $about = $et->GetNewValue($$et{NEW_VALUE}{$tagInfo}) || '';
    }

    if ($xmpFile or $dirLen) {
        delete $$et{XMP_ERROR};
        # extract all existing XMP information (to the XMP_CAPTURE hash)
        my $success = ProcessXMP($et, $dirInfo, $tagTablePtr);
        # don't continue if there is nothing to parse or if we had a parsing error
        unless ($success and not $$et{XMP_ERROR}) {
            my $err = $$et{XMP_ERROR} || 'Error parsing XMP';
            # may ignore this error only if we were successful
            if ($xmpFile) {
                my $raf = $$dirInfo{RAF};
                # allow empty XMP data so we can create something from nothing
                if ($success or not $raf->Seek(0,2) or $raf->Tell()) {
                    # no error message if not an XMP file
                    return 0 unless $$et{XMP_ERROR};
                    if ($et->Error($err, $success)) {
                        delete $$et{XMP_CAPTURE};
                        return 0;
                    }
                }
            } else {
                $success = 2 if $success and $success eq '1';
                if ($et->Warn($err, $success)) {
                    delete $$et{XMP_CAPTURE};
                    return undef;
                }
            }
        }
        if (defined $about) {
            if ($verbose > 1) {
                my $wasAbout = $$et{XmpAbout};
                $et->VerboseValue('- XMP-rdf:About', UnescapeXML($wasAbout)) if defined $wasAbout;
                $et->VerboseValue('+ XMP-rdf:About', $about);
            }
            $about = EscapeXML($about); # must escape for XML
            ++$changed;
        } else {
            $about = $$et{XmpAbout} || '';
        }
        delete $$et{XMP_ERROR};

        # call InitWriteDirs to initialize FORCE_WRITE flags if necessary
        $et->InitWriteDirs({}, 'XMP') if $xmpFile and $et->GetNewValue('ForceWrite');
        # set changed if we are ForceWrite tag was set to "XMP"
        ++$changed if $$et{FORCE_WRITE}{XMP};

    } elsif (defined $about) {
        $et->VerboseValue('+ XMP-rdf:About', $about);
        $about = EscapeXML($about); # must escape for XML
        # (don't increment $changed here because we need another tag to be written)
    } else {
        $about = '';
    }
#
# handle writing XMP as a block to XMP file
#
    if ($xmpFile) {
        $tagInfo = $Image::ExifTool::Extra{XMP};
        if ($tagInfo and $$et{NEW_VALUE}{$tagInfo}) {
            my $rtnVal = 1;
            my $newVal = $et->GetNewValue($$et{NEW_VALUE}{$tagInfo});
            if (defined $newVal and length $newVal) {
                $et->VPrint(0, "  Writing XMP as a block\n");
                ++$$et{CHANGED};
                Write($$dirInfo{OutFile}, $newVal) or $rtnVal = -1;
            }
            delete $$et{XMP_CAPTURE};
            return $rtnVal;
        }
    }
#
# delete groups in family 1 if requested
#
    if (%{$$et{DEL_GROUP}} and (grep /^XMP-.+$/, keys %{$$et{DEL_GROUP}} or
        # (logic is a bit more complex for group names in exiftool XML files)
        grep m{^http://ns.exiftool.(?:ca|org)/}, values %nsUsed))
    {
        my $del = $$et{DEL_GROUP};
        my $path;
        foreach $path (keys %capture) {
            my @propList = split('/',$path); # get property list
            my ($tag, $ns) = GetXMPTagID(\@propList);
            # translate namespace if necessary
            $ns = $stdXlatNS{$ns} if $stdXlatNS{$ns};
            my ($grp, @g);
            # no "XMP-" added to most groups in exiftool RDF/XML output file
            if ($nsUsed{$ns} and (@g = ($nsUsed{$ns} =~ m{^http://ns.exiftool.(?:ca|org)/(.*?)/(.*?)/}))) {
                if ($g[1] =~ /^\d/) {
                    $grp = "XML-$g[0]";
                    #(all XML-* groups stored as uppercase DEL_GROUP key)
                    my $ucg = uc $grp;
                    next unless $$del{$ucg} or ($$del{'XML-*'} and not $$del{"-$ucg"});
                } else {
                    $grp = $g[1];
                    next unless $$del{$grp} or ($$del{$g[0]} and not $$del{"-$grp"});
                }
            } else {
                $grp = "XMP-$ns";
                my $ucg = uc $grp;
                next unless $$del{$ucg} or ($$del{'XMP-*'} and not $$del{"-$ucg"});
            }
            $et->VerboseValue("- $grp:$tag", $capture{$path}->[0]);
            delete $capture{$path};
            ++$changed;
        }
    }
    # delete HasExtendedXMP tag (we create it as needed)
    my $hasExtTag = 'xmpNote:HasExtendedXMP';
    if ($capture{$hasExtTag}) {
        $et->VerboseValue("- XMP-$hasExtTag", $capture{$hasExtTag}->[0]);
        delete $capture{$hasExtTag};
    }
    # set $xmpOpen now to to handle xmptk tag first
    my $xmpOpen = $$et{XMP_NO_XMPMETA} ? '' : XMPOpen($et);
#
# add, delete or change information as specified
#
    # get hash of all information we want to change
    # (sorted by tag name so alternate languages come last, but with structures
    # first so flattened tags may be used to override individual structure elements)
    my (@tagInfoList, $delLangPath, %delLangPaths, %delAllLang, $firstNewPath);
    my $writeGroup = $$dirInfo{WriteGroup};
    foreach $tagInfo (sort ByTagName $et->GetNewTagInfoList()) {
        next unless $et->GetGroup($tagInfo, 0) eq 'XMP';
        next if $$tagInfo{Name} eq 'XMP'; # (ignore full XMP block if we didn't write it already)
        next if $writeGroup and $writeGroup ne $$et{NEW_VALUE}{$tagInfo}{WriteGroup};
        if ($$tagInfo{Struct}) {
            unshift @tagInfoList, $tagInfo;
        } else {
            push @tagInfoList, $tagInfo;
        }
    }
    foreach $tagInfo (@tagInfoList) {
        my @delPaths;   # list of deleted paths
        my $tag = $$tagInfo{TagID};
        my $path = GetPropertyPath($tagInfo);
        unless ($path) {
            $et->Warn("Can't write XMP:$tag (namespace unknown)");
            next;
        }
        # skip tags that were handled specially
        if ($path eq 'rdf:about' or $path eq 'x:xmptk') {
            ++$changed;
            next;
        }
        my $isStruct = $$tagInfo{Struct};
        # change our property path namespace prefixes to conform
        # to the ones used in this file
        $path = ConformPathToNamespace($et, $path);
        # find existing property
        my $cap = $capture{$path};
        # MicrosoftPhoto screws up the case of some tags, and some other software,
        # including Adobe software, has been known to write the wrong list type or
        # not properly enclose properties in a list, so we check for this
        until ($cap) {
            # find and fix all incorrect property names if this is a structure or a flattened tag
            my @fixInfo;
            if ($isStruct or defined $$tagInfo{Flat}) {
                # get tagInfo for all containing (possibly nested) structures
                my @props = split '/', $path;
                my $tbl = $$tagInfo{Table};
                while (@props) {
                    my $info = $$tbl{GetXMPTagID(\@props)};
                    unshift @fixInfo, $info if ref $info eq 'HASH' and $$info{Struct} and
                        (not @fixInfo or $fixInfo[0] ne $info);
                    pop @props;
                }
                $et->WarnOnce("Error finding parent structure for $$tagInfo{Name}") unless @fixInfo;
            }
            # fix property path for this tag (last in the @fixInfo list)
            push @fixInfo, $tagInfo unless @fixInfo and $isStruct;
            # start from outermost containing structure, fixing incorrect list types, etc,
            # finally fixing the actual tag properties after all containing structures
            my $err;
            while (@fixInfo) {
                my $fixInfo = shift @fixInfo;
                my $fixPath = ConformPathToNamespace($et, GetPropertyPath($fixInfo));
                my $regex = quotemeta($fixPath);
                $regex =~ s/ \d+/ \\d\+/g;  # match any list index
                my $ok = $regex;
                my ($ok2, $match, $i, @fixed, %fixed, $fixed);
                # check for incorrect list types
                if ($regex =~ s{\\/rdf\\:(Bag|Seq|Alt)\\/}{/rdf:(Bag|Seq|Alt)/}g) {
                    # also look for missing bottom-level list
                    if ($regex =~ s{/rdf:\(Bag\|Seq\|Alt\)\/rdf\\:li\\ \\d\+$}{}) {
                        $regex .= '(/.*)?' unless @fixInfo;
                    }
                } elsif (not @fixInfo) {
                    $ok2 = $regex;
                    # check for properties in lists that shouldn't be (ref forum4325)
                    $regex .= '(/rdf:(Bag|Seq|Alt)/rdf:li \d+)?';
                }
                if (@fixInfo) {
                    $regex .= '(/.*)?';
                    $ok .= '(/.*)?';
                }
                my @matches = sort grep m{^$regex$}i, keys %capture;
                last unless @matches;
                if ($matches[0] =~ m{^$ok$}) {
                    unless (@fixInfo) {
                        $path = $matches[0];
                        $cap = $capture{$path};
                    }
                    next;
                }
                # needs fixing...
                my @fixProps = split '/', $fixPath;
                foreach $match (@matches) {
                    my @matchProps = split '/', $match;
                    # remove superfluous list properties if necessary
                    $#matchProps = $#fixProps if $ok2 and $#matchProps > $#fixProps;
                    for ($i=0; $i<@fixProps; ++$i) {
                        defined $matchProps[$i] or $matchProps[$i] = $fixProps[$i], next;
                        next if $matchProps[$i] =~ / \d+$/ or $matchProps[$i] eq $fixProps[$i];
                        $matchProps[$i] = $fixProps[$i];
                    }
                    $fixed = join '/', @matchProps;
                    $err = 1 if $fixed{$fixed} or ($capture{$fixed} and $match ne $fixed);
                    push @fixed, $fixed;
                    $fixed{$fixed} = 1;
                }
                my $tg = $et->GetGroup($fixInfo, 1) . ':' . $$fixInfo{Name};
                my $wrn = lc($fixed[0]) eq lc($matches[0]) ? 'tag ID case' : 'list type';
                if ($err) {
                    $et->Warn("Incorrect $wrn for existing $tg (not changed)");
                } else {
                    # fix the incorrect property paths for all values of this tag
                    my $didFix;
                    foreach $fixed (@fixed) {
                        my $match = shift @matches;
                        next if $fixed eq $match;
                        $capture{$fixed} = $capture{$match};
                        delete $capture{$match};
                        # remove xml:lang attribute from incorrect lang-alt list if necessary
                        delete $capture{$fixed}[1]{'xml:lang'} if $ok2 and $match !~ /^$ok2$/;
                        $didFix = 1;
                    }
                    $cap = $capture{$path} || $capture{$fixed[0]} unless @fixInfo;
                    if ($didFix) {
                        $et->Warn("Fixed incorrect $wrn for $tg", 1);
                        ++$changed;
                    }
                }
            }
            last;
        }
        my $nvHash = $et->GetNewValueHash($tagInfo);
        my $overwrite = $et->IsOverwriting($nvHash);
        my $writable = $$tagInfo{Writable} || '';
        my (%attrs, $deleted, $added, $existed, $newLang);
        # set up variables to save/restore paths of deleted lang-alt tags
        if ($writable eq 'lang-alt') {
            $newLang = lc($$tagInfo{LangCode} || 'x-default');
            if ($delLangPath and $delLangPath eq $path) {
                # restore paths of deleted entries for this language
                @delPaths = @{$delLangPaths{$newLang}} if $delLangPaths{$newLang};
            } else {
                undef %delLangPaths;
                $delLangPath = $path;   # base path for deleted lang-alt tags
                undef %delAllLang;
                undef $firstNewPath;    # reset first path for new lang-alt tag
            }
            if (%delAllLang) {
                # add missing paths to delete list for entries where all languages were deleted
                my ($prefix, $reSort);
                foreach $prefix (keys %delAllLang) {
                    next if grep /^$prefix/, @delPaths;
                    push @delPaths, "${prefix}10";
                    $reSort = 1;
                }
                @delPaths = sort @delPaths if $reSort;
            }
        }
        # delete existing entry if necessary
        if ($isStruct) {
            # delete all structure (or pseudo-structure) elements
            require 'Image/ExifTool/XMPStruct.pl';
            ($deleted, $added, $existed) = DeleteStruct($et, \%capture, \$path, $nvHash, \$changed);
            # don't add if it didn't exist and not IsCreating and Avoid
            undef $added if not $existed and not $$nvHash{IsCreating} and $$tagInfo{Avoid};
            next unless $deleted or $added or $et->IsOverwriting($nvHash);
            next if $existed and $$nvHash{CreateOnly};
        } elsif ($cap) {
            next if $$nvHash{CreateOnly};   # (necessary for List-type tags)
            # take attributes from old values if they exist
            %attrs = %{$$cap[1]};
            if ($overwrite) {
                my ($oldLang, $delLang, $addLang, @matchingPaths, $langPathPat, %langsHere);
                # check to see if this is an indexed list item
                if ($path =~ / /) {
                    my $pp;
                    ($pp = $path) =~ s/ \d+/ \\d\+/g;
                    @matchingPaths = sort grep(/^$pp$/, keys %capture);
                } else {
                    push @matchingPaths, $path;
                }
                my $oldOverwrite = $overwrite;
                foreach $path (@matchingPaths) {
                    my ($val, $attrs) = @{$capture{$path}};
                    if ($writable eq 'lang-alt') {
                        # get original language code (lc for comparisons)
                        $oldLang = lc($$attrs{'xml:lang'} || 'x-default');
                        # revert to original overwrite flag if this is in a different structure
                        if (not $langPathPat or $path !~ /^$langPathPat$/) {
                            $overwrite = $oldOverwrite;
                            ($langPathPat = $path) =~ s/\d+$/\\d+/;
                        }
                        # remember languages in this lang-alt list
                        $langsHere{$langPathPat}{$oldLang} = 1;
                        unless (defined $addLang) {
                            # add to lang-alt list by default if creating this tag from scratch
                            $addLang = $$nvHash{IsCreating} ? 1 : 0;
                        }
                        if ($overwrite < 0) {
                            next unless $oldLang eq $newLang;
                            # only add new tag if we are overwriting this one
                            # (note: this won't match if original XML contains CDATA!)
                            $addLang = $et->IsOverwriting($nvHash, UnescapeXML($val));
                            next unless $addLang;
                        }
                        # delete all if deleting "x-default" and writing with no LangCode
                        # (XMP spec requires x-default language exist and be first in list)
                        if ($oldLang eq 'x-default' and not $$tagInfo{LangCode}) {
                            $delLang = 1;   # delete all languages
                            $overwrite = 1; # force overwrite
                        } elsif ($$tagInfo{LangCode} and not $delLang) {
                            # only overwrite specified language
                            next unless lc($$tagInfo{LangCode}) eq $oldLang;
                        }
                    } elsif ($overwrite < 0) {
                        # only overwrite specific values
                        if ($$nvHash{Shift}) {
                            # values to be shifted are checked (hence re-formatted) late,
                            # so we must un-format the to-be-shifted value for IsOverwriting()
                            my $fmt = $$tagInfo{Writable} || '';
                            if ($fmt eq 'rational') {
                                ConvertRational($val);
                            } elsif ($fmt eq 'date') {
                                $val = ConvertXMPDate($val);
                            }
                        }
                        # (note: this won't match if original XML contains CDATA!)
                        next unless $et->IsOverwriting($nvHash, UnescapeXML($val));
                    }
                    if ($verbose > 1) {
                        my $grp = $et->GetGroup($tagInfo, 1);
                        my $tagName = $$tagInfo{Name};
                        $tagName =~ s/-$$tagInfo{LangCode}$// if $$tagInfo{LangCode};
                        $tagName .= '-' . $$attrs{'xml:lang'} if $$attrs{'xml:lang'};
                        $et->VerboseValue("- $grp:$tagName", $val);
                    }
                    # save attributes and path from first deleted property
                    # so we can replace it exactly
                    %attrs = %$attrs unless @delPaths;
                    if ($writable eq 'lang-alt') {
                        $langsHere{$langPathPat}{$oldLang} = 0; # (lang was deleted)
                    }
                    # save deleted paths so we can replace the same elements
                    # (separately for each language of a lang-alt list)
                    if ($writable ne 'lang-alt' or $oldLang eq $newLang) {
                        push @delPaths, $path;
                    } else {
                        $delLangPaths{$oldLang} or $delLangPaths{$oldLang} = [ ];
                        push @{$delLangPaths{$oldLang}}, $path;
                    }
                    # keep track of paths where we deleted all languages of a lang-alt tag
                    if ($delLang) {
                        my $p;
                        ($p = $path) =~ s/\d+$//;
                        $delAllLang{$p} = 1;
                    }
                    # delete this tag
                    delete $capture{$path};
                    ++$changed;
                    # delete rdf:type tag if it is the only thing left in this structure
                    if ($path =~ /^(.*)\// and $capture{"$1/rdf:type"}) {
                        my $pp = $1;
                        my @a = grep /^\Q$pp\E\/[^\/]+/, keys %capture;
                        delete $capture{"$pp/rdf:type"} if @a == 1;
                    }
                }
                next unless @delPaths or $$tagInfo{List} or $addLang;
                if (@delPaths) {
                    $path = shift @delPaths;
                    # make sure new path is unique
                    while ($capture{$path}) {
                        last unless $path =~ s/ \d(\d+)$/' '.length($1+1).($1+1)/e;
                    }
                    $deleted = 1;
                } else {
                    # don't change tag if we couldn't delete old copy
                    # unless this is a list or an lang-alt tag
                    next unless $$tagInfo{List} or $oldLang;
                    # avoid adding duplicate entry to lang-alt in a list
                    if ($writable eq 'lang-alt' and %langsHere) {
                        foreach (sort keys %langsHere) {
                            next unless $path =~ /^$_$/;
                            last unless $langsHere{$_}{$newLang};
                            $path =~ /(.* )\d(\d+)(.*? \d+)$/ or $et->Error('Internal error writing lang-alt list'), last;
                            my $nxt = $2 + 1;
                            $path = $1 . length($nxt) . ($nxt) . $3; # step to next index
                        }
                    }
                    # (match last index to put in same lang-alt list for Bag of lang-alt items)
                    $path =~ m/.* (\d+)/g or warn "Internal error: no list index!\n", next;
                    $added = $1;
                }
            } else {
                # we are never overwriting, so we must be adding to a list
                # match the last index unless this is a list of lang-alt lists
                my $pat = '.* (\d+)';
                if ($writable eq 'lang-alt') {
                    if ($firstNewPath) {
                        $path = $firstNewPath;
                        $overwrite = 1; # necessary to put x-default entry first below
                    } else {
                        $pat = '.* (\d+)(.*? \d+)';
                    }
                }
                if ($path =~ m/$pat/g) {
                    $added = $1;
                    # set position to end of matching index number
                    pos($path) = pos($path) - length($2) if $2;
                }
            }
            if (defined $added) {
                my $len = length $added;
                my $pos = pos($path) - $len;
                my $nxt = substr($added, 1) + 1;
                # always insert x-default lang-alt entry first (as per XMP spec)
                # (need to test $overwrite because this will be a new lang-alt entry otherwise)
                if ($overwrite and $writable eq 'lang-alt' and (not $$tagInfo{LangCode} or
                    $$tagInfo{LangCode} eq 'x-default'))
                {
                    my $saveCap = $capture{$path};
                    while ($saveCap) {
                        my $p = $path;
                        substr($p, $pos, $len) = length($nxt) . $nxt;
                        # increment index in the path of the existing item
                        my $nextCap = $capture{$p};
                        $capture{$p} = $saveCap;
                        last unless $nextCap;
                        $saveCap = $nextCap;
                        ++$nxt;
                    }
                } else {
                    # add to end of list
                    while ($capture{$path}) {
                        my $try = length($nxt) . $nxt;
                        substr($path, $pos, $len) = $try;
                        $len = length $try;
                        ++$nxt;
                    }
                }
            }
        }
        # check to see if we want to create this tag
        # (create non-avoided tags in XMP data files by default)
        my $isCreating = ($$nvHash{IsCreating} or (($isStruct or
                          ($preferred and not defined $$nvHash{Shift})) and
                          not $$tagInfo{Avoid} and not $$nvHash{EditOnly}));

        # don't add new values unless...
            # ...tag existed before and was deleted, or we added it to a list
        next unless $deleted or defined $added or
            # ...tag didn't exist before and we are creating it
            (not $cap and $isCreating);

        # get list of new values (all done if no new values specified)
        my @newValues = $et->GetNewValue($nvHash) or next;

        # set language attribute for lang-alt lists
        if ($writable eq 'lang-alt') {
            $attrs{'xml:lang'} = $$tagInfo{LangCode} || 'x-default';
            $firstNewPath = $path if defined $added;  # save path of first lang-alt tag added
        }
        # add new value(s) to %capture hash
        my $subIdx;
        for (;;) {
            my $newValue = shift @newValues;
            if ($isStruct) {
                ++$changed if AddNewStruct($et, $tagInfo, \%capture,
                                           $path, $newValue, $$tagInfo{Struct});
            } else {
                $newValue = EscapeXML($newValue);
                for (;;) { # (a cheap 'goto')
                    if ($$tagInfo{Resource}) {
                        # only store as a resource if it doesn't contain any illegal characters
                        if ($newValue !~ /[^a-z0-9\:\/\?\#\[\]\@\!\$\&\'\(\)\*\+\,\;\=\.\-\_\~]/i) {
                            $capture{$path} = [ '', { %attrs, 'rdf:resource' => $newValue } ];
                            last;
                        }
                        my $grp = $et->GetGroup($tagInfo, 1);
                        $et->Warn("$grp:$$tagInfo{Name} written as a literal because value is not a valid URI", 1);
                        # fall through to write as a string literal
                    }
                    # remove existing value and/or resource attribute if they exist
                    delete $attrs{'rdf:value'};
                    delete $attrs{'rdf:resource'};
                    $capture{$path} = [ $newValue, \%attrs ];
                    last;
                }
                if ($verbose > 1) {
                    my $grp = $et->GetGroup($tagInfo, 1);
                    $et->VerboseValue("+ $grp:$$tagInfo{Name}", $newValue);
                }
                ++$changed;
                # add rdf:type if necessary
                if ($$tagInfo{StructType}) {
                    AddStructType($et, $$tagInfo{Table}, \%capture, $path);
                }
            }
            last unless @newValues;
            # match last index except for lang-alt items where we want to put each
            # item in a different lang-alt list (so match the 2nd-last for these)
            my $pat = $writable eq 'lang-alt' ? '.* (\d+)(.*? \d+)' : '.* (\d+)';
            pos($path) = 0;
            $path =~ m/$pat/g or warn("Internal error: no list index for $tag ($path) ($pat)!\n"), next;
            my $idx = $1;
            my $len = length $1;
            my $pos = pos($path) - $len - ($2 ? length $2 : 0);
            # use sub-indices if necessary to store additional values in sequence
            if ($subIdx) {
                $idx = substr($idx, 0, -length($subIdx));   # remove old sub-index
                $subIdx = substr($subIdx, 1) + 1;
                $subIdx = length($subIdx) . $subIdx;
            } elsif (@delPaths) {
                $path = shift @delPaths;
                # make sure new path is unique
                while ($capture{$path}) {
                    last unless $path =~ s/ \d(\d+)$/' '.length($1+1).($1+1)/e;
                }
                next;
            } else {
                $subIdx = '10';
            }
            substr($path, $pos, $len) = $idx . $subIdx;
        }
        # make sure any empty structures are deleted
        # (ExifTool shouldn't write these, but other software may)
        if (defined $$tagInfo{Flat}) {
            my $p = $path;
            while ($p =~ s/\/[^\/]+$//) {
                next unless $capture{$p};
                # it is an error if this property has a value
                $et->Error("Improperly structured XMP ($p)",1) if $capture{$p}[0] =~ /\S/;
                delete $capture{$p};    # delete the (hopefully) empty structure
            }
        }
    }
    # remove the ExifTool members we created
    delete $$et{XMP_CAPTURE};
    delete $$et{XMP_NS};

    my $maxDataLen = $$dirInfo{MaxDataLen};
    # get DataPt again because it may have been set by ProcessXMP
    $dataPt = $$dirInfo{DataPt};

    # return now if we didn't change anything
    unless ($changed or ($maxDataLen and $dataPt and defined $$dataPt and
        length($$dataPt) > $maxDataLen))
    {
        return undef unless $xmpFile;   # just rewrite original XMP
        Write($$dirInfo{OutFile}, $$dataPt) or return -1 if $dataPt and defined $$dataPt;
        return 1;
    }
#
# write out the new XMP information (serialize it)
#
    # start writing the XMP data
    my (@long, @short, @resFlag);
    $long[0] = $long[1] = $short[0] = '';
    if ($$et{XMP_NO_XPACKET}) {
        # write BOM if flag is set
        $long[-2] .= "\xef\xbb\xbf" if $$et{XMP_NO_XPACKET} == 2;
    } else {
        $long[-2] .= $pktOpen;
    }
    $long[-2] .= $xmlOpen if $$et{XMP_IS_XML};
    $long[-2] .= $xmpOpen . $rdfOpen;

    # initialize current property path list
    my (@curPropList, @writeLast, @descStart, $extStart);
    my (%nsCur, $prop, $n, $path);
    my @pathList = sort TypeFirst keys %capture;
    # order properties to write large values last if we have a MaxDataLen limit
    if ($maxDataLen and @pathList) {
        my @pathTmp;
        my ($lastProp, $lastNS, $propSize) = ('', '', 0);
        my @pathLoop = (@pathList, ''); # add empty path to end of list for loop
        undef @pathList;
        foreach $path (@pathLoop) {
            $path =~ /^((\w*)[^\/]*)/;  # get path element ($1) and ns ($2)
            if ($1 eq $lastProp) {
                push @pathTmp, $path;   # accumulate all paths with same root
            } else {
                # put in list to write last if recommended or values are too large
                if ($extendedRes{$lastProp} or $extendedRes{$lastNS} or
                    $propSize > $newDescThresh)
                {
                    push @writeLast, @pathTmp;
                } else {
                    push @pathList, @pathTmp;
                }
                last unless $path;      # all done if we hit empty path
                @pathTmp = ( $path );
                ($lastProp, $lastNS, $propSize) = ($1, $2, 0);
            }
            $propSize += length $capture{$path}->[0];
        }
    }

    # write out all properties
    for (;;) {
        my (%nsNew, $newDesc);
        unless (@pathList) {
            last unless @writeLast;
            @pathList = @writeLast;
            undef @writeLast;
            $newDesc = 2;   # start with a new description for the extended data
        }
        $path = shift @pathList;
        my @propList = split('/',$path); # get property list
        # must open/close rdf:Description too
        unshift @propList, $rdfDesc;
        # make sure we have defined all necessary namespaces
        foreach $prop (@propList) {
            $prop =~ /(.*):/ or next;
            $1 eq 'rdf' and next;       # rdf namespace already defined
            my $uri = $nsUsed{$1};
            unless ($uri) {
                $uri = $nsURI{$1};      # we must have added a namespace
                unless ($uri) {
                    # (namespace prefix may be empty if trying to write empty XMP structure, forum12384)
                     if (length $1) {
                        my $err = "Undefined XMP namespace: $1";
                        if (not $xmpErr or $err ne $xmpErr) {
                            $xmpFile ? $et->Error($err) : $et->Warn($err);
                            $xmpErr = $err;
                        }
                     }
                     next;
                }
            }
            $nsNew{$1} = $uri;
            # need a new description if any new namespaces
            $newDesc = 1 unless $nsCur{$1};
        }
        my $closeTo = 0;
        if ($newDesc) {
            # look forward to see if we will want to also open other namespaces
            # at this level (this is necessary to keep lists and structures from
            # being broken if a property introduces a new namespace; plus it
            # improves formatting)
            my ($path2, $ns2);
            foreach $path2 (@pathList) {
                my @ns2s = ($path2 =~ m{(?:^|/)([^/]+?):}g);
                my $opening = $compact{OneDesc} ? 1 : 0;
                foreach $ns2 (@ns2s) {
                    next if $ns2 eq 'rdf';
                    $nsNew{$ns2} and ++$opening, next;
                    last unless $opening;
                    # get URI for this existing or new namespace
                    my $uri = $nsUsed{$ns2} || $nsURI{$ns2} or last;
                    $nsNew{$ns2} = $uri; # also open this namespace
                }
                last unless $opening;
            }
        } else {
            # find first property where the current path differs from the new path
            for ($closeTo=0; $closeTo<@curPropList; ++$closeTo) {
                last unless $closeTo < @propList;
                last unless $propList[$closeTo] eq $curPropList[$closeTo];
            }
        }
        # close out properties down to the common base path
        CloseProperty(\@curPropList, \@long, \@short, \@resFlag) while @curPropList > $closeTo;

        # open new description if necessary
        if ($newDesc) {
            $extStart = length($long[-2]) if $newDesc == 2; # extended data starts after this
            # save rdf:Description start positions so we can reorder them if necessary
            push @descStart, length($long[-2]) if $maxDataLen;
            # open the new description
            $prop = $rdfDesc;
            %nsCur = %nsNew;            # save current namespaces
            my @ns = sort keys %nsCur;
            $long[-2] .= "$nl$sp<$prop rdf:about='${about}'";
            # generate et:toolkit attribute if this is an exiftool RDF/XML output file
            if ($$et{XMP_NO_XMPMETA} and @ns and $nsCur{$ns[0]} =~ m{^http://ns.exiftool.(?:ca|org)/}) {
                $long[-2] .= "\n$sp${sp}xmlns:et='http://ns.exiftool.org/1.0/'" .
                            " et:toolkit='Image::ExifTool $Image::ExifTool::VERSION'";
            }
            $long[-2] .= "\n$sp${sp}xmlns:$_='$nsCur{$_}'" foreach @ns;
            push @curPropList, $prop;
            # set resFlag to 0 to indicate base description when Shorthand enabled
            $resFlag[0] = 0 if $compact{Shorthand};
        }
        my ($val, $attrs) = @{$capture{$path}};
        $debug and print "$path = $val\n";
        # open new properties if necessary
        my ($attr, $dummy);
        for ($n=@curPropList; $n<$#propList; ++$n) {
            $prop = $propList[$n];
            push @curPropList, $prop;
            $prop =~ s/ .*//;       # remove list index if it exists
            # (we may add parseType and shorthand properties later,
            #  so leave off the trailing ">" for now)
            $long[-1] .= ($compact{NoIndent} ? '' : ' ' x scalar(@curPropList)) . "<$prop";
            if ($prop ne $rdfDesc and ($propList[$n+1] !~ /^rdf:/ or
                ($propList[$n+1] eq 'rdf:type' and $n+1 == $#propList)))
            {
                # check for empty structure
                if ($propList[$n+1] =~ /:~dummy~$/) {
                    $long[-1] .= " rdf:parseType='Resource'/>$nl";
                    pop @curPropList;
                    $dummy = 1;
                    last;
                }
                if ($compact{Shorthand}) {
                    $resFlag[$#curPropList] = 1;
                    push @long, '';
                    push @short, '';
                } else {
                    # use rdf:parseType='Resource' to avoid new 'rdf:Description'
                    $long[-1] .= " rdf:parseType='Resource'>$nl";
                }
            } else {
                $long[-1] .= ">$nl"; # (will be no shorthand properties)
            }
        }
        my $prop2 = pop @propList;  # get new property name
        # add element unless it was a dummy structure field
        unless ($dummy or ($val eq '' and $prop2 =~ /:~dummy~$/)) {
            $prop2 =~ s/ .*//;      # remove list index if it exists
            my $pad = $compact{NoIndent} ? '' : ' ' x (scalar(@curPropList) + 1);
            # (can't write as shortcut if it has attributes or CDATA)
            if (defined $resFlag[$#curPropList] and not %$attrs and $val !~ /<!\[CDATA\[/) {
                $short[-1] .= "\n$pad$prop2='${val}'";
            } else {
                $long[-1] .= "$pad<$prop2";
                # write out attributes
                foreach $attr (sort keys %$attrs) {
                    my $attrVal = $$attrs{$attr};
                    my $quot = ($attrVal =~ /'/) ? '"' : "'";
                    $long[-1] .= " $attr=$quot$attrVal$quot";
                }
                $long[-1] .= length $val ? ">$val</$prop2>$nl" : "/>$nl";
            }
        }
    }
    # close out all open properties
    CloseProperty(\@curPropList, \@long, \@short, \@resFlag) while @curPropList;

    # limit XMP length and re-arrange if necessary to fit inside specified size
    if ($maxDataLen) {
        # adjust maxDataLen to allow room for closing elements
        $maxDataLen -= length($rdfClose) + length($xmpClose) + length($pktCloseW);
        $extStart or $extStart = length $long[-2];
        my @rtn = LimitXMPSize($et, \$long[-2], $maxDataLen, $about, \@descStart, $extStart);
        # return extended XMP information in $dirInfo
        $$dirInfo{ExtendedXMP} = $rtn[0];
        $$dirInfo{ExtendedGUID} = $rtn[1];
        # compact if necessary to fit
        $compact{NoPadding} = 1 if length($long[-2]) + 101 * $numPadLines > $maxDataLen;
    }
    $compact{NoPadding} = 1 if $$dirInfo{Compact};
#
# close out the XMP, clean up, and return our data
#
    $long[-2] .= $rdfClose;
    $long[-2] .= $xmpClose unless $$et{XMP_NO_XMPMETA};

    # remove the ExifTool members we created
    delete $$et{XMP_CAPTURE};
    delete $$et{XMP_NS};
    delete $$et{XMP_NO_XMPMETA};

    # (the XMP standard recommends writing 2k-4k of white space before the
    # packet trailer, with a newline every 100 characters)
    unless ($$et{XMP_NO_XPACKET}) {
        my $pad = (' ' x 100) . "\n";
        # get current XMP length without padding
        my $len = length($long[-2]) + length($pktCloseW);
        if ($$dirInfo{InPlace} and not ($$dirInfo{InPlace} == 2 and $len > $dirLen)) {
            # pad to specified DirLen
            if ($len > $dirLen) {
                my $str = 'Not enough room to edit XMP in place';
                $str .= '. Try Shorthand feature' unless $compact{Shorthand};
                $et->Warn($str);
                return undef;
            }
            my $num = int(($dirLen - $len) / length($pad));
            if ($num) {
                $long[-2] .= $pad x $num;
                $len += length($pad) * $num;
            }
            $len < $dirLen and $long[-2] .= (' ' x ($dirLen - $len - 1)) . "\n";
        } elsif (not $compact{NoPadding} and not $xmpFile and not $$dirInfo{ReadOnly}) {
            $long[-2] .= $pad x $numPadLines;
        }
        $long[-2] .= ($$dirInfo{ReadOnly} ? $pktCloseR : $pktCloseW);
    }
    # return empty data if no properties exist and this is allowed
    unless (%capture or $xmpFile or $$dirInfo{InPlace} or $$dirInfo{NoDelete}) {
        $long[-2] = '';
    }
    return($xmpFile ? -1 : undef) if $xmpErr;
    $$et{CHANGED} += $changed;
    $debug > 1 and $long[-2] and print $long[-2],"\n";
    return $long[-2] unless $xmpFile;
    Write($$dirInfo{OutFile}, $long[-2]) or return -1;
    return 1;
}


1; # end

__END__

=head1 NAME

Image::ExifTool::WriteXMP.pl - Write XMP meta information

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool::XMP.

=head1 DESCRIPTION

This file contains routines to write XMP metadata.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::XMP(3pm)|Image::ExifTool::XMP>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
