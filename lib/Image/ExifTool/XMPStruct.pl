#------------------------------------------------------------------------------
# File:         XMPStruct.pl
#
# Description:  XMP structure support
#
# Revisions:    01/01/2011 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::XMP;

use strict;
use vars qw(%specialStruct %stdXlatNS);

use Image::ExifTool qw(:Utils);
use Image::ExifTool::XMP;

sub SerializeStruct($;$);
sub InflateStruct($;$);
sub DumpStruct($;$);
sub CheckStruct($$$);
sub AddNewStruct($$$$$$);
sub ConvertStruct($$$$;$);

#------------------------------------------------------------------------------
# Serialize a structure (or other object) into a simple string
# Inputs: 0) HASH ref, ARRAY ref, or SCALAR, 1) closing bracket (or undef)
# Returns: serialized structure string
# eg) "{field=text with {braces|}|, and a comma, field2=val2,field3={field4=[a,b]}}"
sub SerializeStruct($;$)
{
    my ($obj, $ket) = @_;
    my ($key, $val, @vals, $rtnVal);

    if (ref $obj eq 'HASH') {
        foreach $key (sort keys %$obj) {
            push @vals, $key . '=' . SerializeStruct($$obj{$key}, '}');
        }
        $rtnVal = '{' . join(',', @vals) . '}';
    } elsif (ref $obj eq 'ARRAY') {
        foreach $val (@$obj) {
            push @vals, SerializeStruct($val, ']');
        }
        $rtnVal = '[' . join(',', @vals) . ']';
    } elsif (defined $obj) {
        $obj = $$obj if ref $obj eq 'SCALAR';
        # escape necessary characters in string (closing bracket plus "," and "|")
        my $pat = $ket ? "\\$ket|,|\\|" : ',|\\|';
        ($rtnVal = $obj) =~  s/($pat)/|$1/g;
        # also must escape opening bracket or whitespace at start of string
        $rtnVal =~ s/^([\s\[\{])/|$1/;
    } else {
        $rtnVal = '';   # allow undefined list items
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Inflate structure (or other object) from a serialized string
# Inputs: 0) reference to object in string form (serialized using the '|' escape)
#         1) extra delimiter for scalar values delimiters
# Returns: 0) object as a SCALAR, HASH ref, or ARRAY ref (or undef on error),
#          1) warning string (or undef)
# Notes: modifies input string to remove parsed objects
sub InflateStruct($;$)
{
    my ($obj, $delim) = @_;
    my ($val, $warn, $part);

    if ($$obj =~ s/^\s*\{//) {
        my %struct;
        while ($$obj =~ s/^\s*([-\w:]+#?)\s*=//s) {
            my $tag = $1;
            my ($v, $w) = InflateStruct($obj, '}');
            $warn = $w if $w and not $warn;
            return(undef, $warn) unless defined $v;
            $struct{$tag} = $v;
            # eat comma separator, or all done if there wasn't one
            last unless $$obj =~ s/^\s*,//s;
        }
        # eat closing brace and warn if we didn't find one
        unless ($$obj =~ s/^\s*\}//s or $warn) {
            if (length $$obj) {
                ($part = $$obj) =~ s/^\s*//s;
                $part =~ s/[\x0d\x0a].*//s;
                $part = substr($part,0,27) . '...' if length($part) > 30;
                $warn = "Invalid structure field at '$part'";
            } else {
                $warn = 'Missing closing brace for structure';
            }
        }
        $val = \%struct;
    } elsif ($$obj =~ s/^\s*\[//) {
        my @list;
        for (;;) {
            my ($v, $w) = InflateStruct($obj, ']');
            $warn = $w if $w and not $warn;
            return(undef, $warn) unless defined $v;
            push @list, $v;
            last unless $$obj =~ s/^\s*,//s;
        }
        # eat closing bracket and warn if we didn't find one
        $$obj =~ s/^\s*\]//s or $warn or $warn = 'Missing closing bracket for list';
        $val = \@list;
    } else {
        $$obj =~ s/^\s+//s; # remove leading whitespace
        # read scalar up to specified delimiter (or "," if not defined)
        $val = '';
        $delim = $delim ? "\\$delim|,|\\||\$" : ',|\\||$';
        for (;;) {
            $$obj =~ s/^(.*?)($delim)//s and $val .= $1;
            last unless $2;
            $2 eq '|' or $$obj = $2 . $$obj, last;
            $$obj =~ s/^(.)//s and $val .= $1;  # add escaped character
        }
    }
    return($val, $warn);
}

#------------------------------------------------------------------------------
# Get XMP language code from tag name string
# Inputs: 0) tag name string
# Returns: 0) separated tag name, 1) language code (in standard case), or '' if
#          language code was 'x-default', or undef if the tag had no language code
sub GetLangCode($)
{
    my $tag = shift;
    if ($tag =~ /^(\w+)[-_]([a-z]{2,3}|[xi])([-_][a-z\d]{2,8}([-_][a-z\d]{1,8})*)?$/i) {
        # normalize case of language codes
        my ($tg, $langCode) = ($1, lc($2));
        $langCode .= (length($3) == 3 ? uc($3) : lc($3)) if $3;
        $langCode =~ tr/_/-/;   # RFC 3066 specifies '-' as a separator
        $langCode = '' if lc($langCode) eq 'x-default';
        return($tg, $langCode);
    } else {
        return($tag, undef);
    }
}

#------------------------------------------------------------------------------
# Debugging routine to dump a structure, list or scalar
# Inputs: 0) scalar, ARRAY ref or HASH ref, 1) indent (or undef)
sub DumpStruct($;$)
{
    local $_;
    my ($obj, $indent) = @_;

    $indent or $indent = '';
    if (ref $obj eq 'HASH') {
        print "{\n";
        foreach (sort keys %$obj) {
            print "$indent  $_ = ";
            DumpStruct($$obj{$_}, "$indent  ");
        }
        print $indent, "},\n";
    } elsif (ref $obj eq 'ARRAY') {
        print "[\n";
        foreach (@$obj) {
            print "$indent  ";
            DumpStruct($_, "$indent  ");
        }
        print $indent, "],\n",
    } else {
        print "\"$obj\",\n";
    }
}

#------------------------------------------------------------------------------
# Recursively validate structure fields (tags)
# Inputs: 0) ExifTool ref, 1) Structure ref, 2) structure table definition ref
# Returns: 0) validated structure ref, 1) error string, or undef on success
# Notes:
# - fixes field names in structure and applies inverse conversions to values
# - copies structure to avoid interdependencies with calling code on referenced values
# - handles lang-alt tags, and '#' on field names
# - resets UTF-8 flag of SCALAR values
# - un-escapes for XML or HTML as per Escape option setting
sub CheckStruct($$$)
{
    my ($et, $struct, $strTable) = @_;

    my $strName = $$strTable{STRUCT_NAME} || ('XMP ' . RegisterNamespace($strTable));
    ref $struct eq 'HASH' or return wantarray ? (undef, "Expecting $strName structure") : undef;

    my ($key, $err, $warn, %copy, $rtnVal, $val);
Key:
    foreach $key (keys %$struct) {
        my $tag = $key;
        # allow trailing '#' to disable print conversion on a per-field basis
        my ($type, $fieldInfo);
        $type = 'ValueConv' if $tag =~ s/#$//;
        $fieldInfo = $$strTable{$tag} unless $specialStruct{$tag};
        # fix case of field name if necessary
        unless ($fieldInfo) {
            # (sort in reverse to get lower case (not special) tags first)
            my ($fix) = reverse sort grep /^$tag$/i, keys %$strTable;
            $fieldInfo = $$strTable{$tag = $fix} if $fix and not $specialStruct{$fix};
        }
        until (ref $fieldInfo eq 'HASH') {
            # generate wildcard fields on the fly (eg. mwg-rs:Extensions)
            unless ($$strTable{NAMESPACE}) {
                my ($grp, $tg, $langCode);
                ($grp, $tg) = $tag =~ /^(.+):(.+)/ ? (lc $1, $2) : ('', $tag);
                undef $grp if $grp eq 'XMP'; # (a group of 'XMP' is implied)
                require Image::ExifTool::TagLookup;
                my @matches = Image::ExifTool::TagLookup::FindTagInfo($tg);
                # also look for lang-alt tags
                unless (@matches) {
                    ($tg, $langCode) = GetLangCode($tg);
                    @matches = Image::ExifTool::TagLookup::FindTagInfo($tg) if defined $langCode;
                }
                my ($tagInfo, $priority, $ti, $g1);
                # find best matching tag
                foreach $ti (@matches) {
                    my @grps = $et->GetGroup($ti);
                    next unless $grps[0] eq 'XMP';
                    next if $grp and $grp ne lc $grps[1];
                    # must be lang-alt tag if we are writing an alternate language
                    next if defined $langCode and not ($$ti{Writable} and $$ti{Writable} eq 'lang-alt');
                    my $pri = $$ti{Priority} || 1;
                    $pri -= 10 if $$ti{Avoid};
                    next if defined $priority and $priority >= $pri;
                    $priority = $pri;
                    $tagInfo = $ti;
                    $g1 = $grps[1];
                }
                $tagInfo or $warn =  "'$tag' is not a writable XMP tag", next Key;
                GetPropertyPath($tagInfo);  # make sure property path is generated for this tag
                $tag = $$tagInfo{Name};
                $tag = "$g1:$tag" if $grp;
                $tag .= "-$langCode" if $langCode;
                $fieldInfo = $$strTable{$tag};
                # create new structure field if necessary
                $fieldInfo or $fieldInfo = $$strTable{$tag} = {
                    %$tagInfo, # (also copies the necessary TagID and PropertyPath)
                    Namespace => $$tagInfo{Table}{NAMESPACE},
                    LangCode  => $langCode,
                };
                # delete stuff we don't need (shouldn't cause harm, but better safe than sorry)
                # - need to keep StructType and Table in case we need to call AddStructType later
                delete $$fieldInfo{Description};
                delete $$fieldInfo{Groups};
                last; # write this dynamically-generated field
            }
            # generate lang-alt fields on the fly (eg. Iptc4xmpExt:AOTitle)
            my ($tg, $langCode) = GetLangCode($tag);
            if (defined $langCode) {
                $fieldInfo = $$strTable{$tg} unless $specialStruct{$tg};
                unless ($fieldInfo) {
                    my ($fix) = reverse sort grep /^$tg$/i, keys %$strTable;
                    $fieldInfo = $$strTable{$tg = $fix} if $fix and not $specialStruct{$fix};
                }
                if (ref $fieldInfo eq 'HASH' and $$fieldInfo{Writable} and
                    $$fieldInfo{Writable} eq 'lang-alt')
                {
                    my $srcInfo = $fieldInfo;
                    $tag = $tg . '-' . $langCode if $langCode;
                    $fieldInfo = $$strTable{$tag};
                    # create new structure field if necessary
                    $fieldInfo or $fieldInfo = $$strTable{$tag} = {
                        %$srcInfo,
                        TagID    => $tg,
                        LangCode => $langCode,
                    };
                    last; # write this lang-alt field
                }
            }
            $warn = "'$tag' is not a field of $strName";
            next Key;
        }
        if (ref $$struct{$key} eq 'HASH') {
            $$fieldInfo{Struct} or $warn = "$tag is not a structure in $strName", next Key;
            # recursively check this structure
            ($val, $err) = CheckStruct($et, $$struct{$key}, $$fieldInfo{Struct});
            $err and $warn = $err, next Key;
            $copy{$tag} = $val;
        } elsif (ref $$struct{$key} eq 'ARRAY') {
            $$fieldInfo{List} or $warn = "$tag is not a list in $strName", next Key;
            # check all items in the list
            my ($item, @copy);
            my $i = 0;
            foreach $item (@{$$struct{$key}}) {
                if (not ref $item) {
                    $item = '' unless defined $item; # use empty string for missing items
                    if ($$fieldInfo{Struct}) {
                        # (allow empty structures)
                        $item =~ /^\s*$/ or $warn = "$tag items are not valid structures", next Key;
                        $copy[$i] = { }; # create hash for empty structure
                    } else {
                        $et->Sanitize(\$item);
                        ($copy[$i],$err) = $et->ConvInv($item,$fieldInfo,$tag,$strName,$type,'');
                        $copy[$i] = '' unless defined $copy[$i];    # avoid undefined item
                        $err and $warn = $err, next Key;
                        $err = CheckXMP($et, $fieldInfo, \$copy[$i]);
                        $err and $warn = "$err in $strName $tag", next Key;
                    }
                } elsif (ref $item eq 'HASH') {
                    $$fieldInfo{Struct} or $warn = "$tag is not a structure in $strName", next Key;
                    ($copy[$i], $err) = CheckStruct($et, $item, $$fieldInfo{Struct});
                    $err and $warn = $err, next Key;
                } else {
                    $warn = "Invalid value for $tag in $strName";
                    next Key;
                }
                ++$i;
            }
            $copy{$tag} = \@copy;
        } elsif ($$fieldInfo{Struct}) {
            $warn = "Improperly formed structure in $strName $tag";
        } else {
            $et->Sanitize(\$$struct{$key});
            ($val,$err) = $et->ConvInv($$struct{$key},$fieldInfo,$tag,$strName,$type,'');
            $err and $warn = $err, next Key;
            next Key unless defined $val;   # check for undefined
            $err = CheckXMP($et, $fieldInfo, \$val);
            $err and $warn = "$err in $strName $tag", next Key;
            # turn this into a list if necessary
            $copy{$tag} = $$fieldInfo{List} ? [ $val ] : $val;
        }
    }
    if (%copy or not $warn) {
        $rtnVal = \%copy;
        undef $err;
        $$et{CHECK_WARN} = $warn if $warn;
    } else {
        $err = $warn;
    }
    return wantarray ? ($rtnVal, $err) : $rtnVal;
}

#------------------------------------------------------------------------------
# Delete matching structures from existing linearized XMP
# Inputs: 0) ExifTool ref, 1) capture hash ref, 2) structure path ref,
#         3) new value hash ref, 4) reference to change counter
# Returns: 0) delete flag, 1) list index of deleted structure if adding to list
#          2) flag set if structure existed
# Notes: updates path to new base path for structure to be added
sub DeleteStruct($$$$$)
{
    my ($et, $capture, $pathPt, $nvHash, $changed) = @_;
    my ($deleted, $added, $existed, $p, $pp, $val, $delPath);
    my (@structPaths, @matchingPaths, @delPaths);

    # find all existing elements belonging to this structure
    ($pp = $$pathPt) =~ s/ \d+/ \\d\+/g;
    @structPaths = sort grep(/^$pp(\/|$)/, keys %$capture);
    $existed = 1 if @structPaths;
    # delete only structures with matching fields if necessary
    if ($$nvHash{DelValue}) {
        if (@{$$nvHash{DelValue}}) {
            my $strTable = $$nvHash{TagInfo}{Struct};
            # all fields must match corresponding elements in the same
            # root structure for it to be deleted
            foreach $val (@{$$nvHash{DelValue}}) {
                next unless ref $val eq 'HASH';
                my (%cap, $p2, %match);
                next unless AddNewStruct(undef, undef, \%cap, $$pathPt, $val, $strTable);
                foreach $p (keys %cap) {
                    if ($p =~ / /) {
                        ($p2 = $p) =~ s/ \d+/ \\d\+/g;
                        @matchingPaths = sort grep(/^$p2$/, @structPaths);
                    } else {
                        push @matchingPaths, $p;
                    }
                    foreach $p2 (@matchingPaths) {
                        $p2 =~ /^($pp)/ or next;
                        # language attribute must also match if it exists
                        my $attr = $cap{$p}[1];
                        if ($$attr{'xml:lang'}) {
                            my $a2 = $$capture{$p2}[1];
                            next unless $$a2{'xml:lang'} and $$a2{'xml:lang'} eq $$attr{'xml:lang'};
                        }
                        if ($$capture{$p2} and $$capture{$p2}[0] eq $cap{$p}[0]) {
                            # ($1 contains root path for this structure)
                            $match{$1} = ($match{$1} || 0) + 1;
                        }
                    }
                }
                my $num = scalar(keys %cap);
                foreach $p (keys %match) {
                    # do nothing unless all fields matched the same structure
                    next unless $match{$p} == $num;
                    # delete all elements of this structure
                    foreach $p2 (@structPaths) {
                        push @delPaths, $p2 if $p2 =~ /^$p/;
                    }
                    # remember path of first deleted structure
                    $delPath = $p if not $delPath or $delPath gt $p;
                }
            }
        } # (else don't delete anything)
    } elsif (@structPaths) {
        @delPaths = @structPaths;   # delete all
        $structPaths[0] =~ /^($pp)/;
        $delPath = $1;
    }
    if (@delPaths) {
        my $verbose = $et->Options('Verbose');
        @delPaths = sort @delPaths if $verbose > 1;
        foreach $p (@delPaths) {
            $et->VerboseValue("- XMP-$p", $$capture{$p}[0]) if $verbose > 1;
            delete $$capture{$p};
            $deleted = 1;
            ++$$changed;
        }
        $delPath or warn("Internal error 1 in DeleteStruct\n"), return(undef,undef,$existed);
        $$pathPt = $delPath;    # return path of first element deleted
    } elsif ($$nvHash{TagInfo}{List}) {
        # NOTE: we don't yet properly handle lang-alt elements!!!!
        if (@structPaths) {
            $structPaths[-1] =~ /^($pp)/ or warn("Internal error 2 in DeleteStruct\n"), return(undef,undef,$existed);
            my $path = $1;
            # delete any improperly formatted xmp
            if ($$capture{$path}) {
                my $cap = $$capture{$path};
                # an error unless this was an empty structure
                $et->Error("Improperly structured XMP ($path)",1) if ref $cap ne 'ARRAY' or $$cap[0];
                delete $$capture{$path};
            }
            # (match last index to put in same lang-alt list for Bag of lang-alt items)
            $path =~ m/.* (\d+)/g or warn("Internal error 3 in DeleteStruct\n"), return(undef,undef,$existed);
            $added = $1;
            # add after last item in list
            my $len = length $added;
            my $pos = pos($path) - $len;
            my $nxt = substr($added, 1) + 1;
            substr($path, $pos, $len) = length($nxt) . $nxt;
            $$pathPt = $path;
        } else {
            $added = '10';
        }
    }
    return($deleted, $added, $existed);
}

#------------------------------------------------------------------------------
# Add new element to XMP capture hash
# Inputs: 0) ExifTool ref, 1) TagInfo ref, 2) capture hash ref,
#         3) resource path, 4) value ref, 5) hash ref for last used index numbers
sub AddNewTag($$$$$$)
{
    my ($et, $tagInfo, $capture, $path, $valPtr, $langIdx) = @_;
    my $val = EscapeXML($$valPtr);
    my %attrs;
    # support writing RDF "resource" values
    if ($$tagInfo{Resource}) {
        $attrs{'rdf:resource'} = $val;
        $val = '';
    }
    if ($$tagInfo{Writable} and $$tagInfo{Writable} eq 'lang-alt') {
        # write the lang-alt tag
        my $langCode = $$tagInfo{LangCode};
        # add indexed lang-alt list properties
        my $i = $$langIdx{$path} || 0;
        $$langIdx{$path} = $i + 1; # save next list index
        if ($i) {
            my $idx = length($i) . $i;
            $path =~ s/(.*) \d+/$1 $idx/;   # set list index
        }
        $attrs{'xml:lang'} = $langCode || 'x-default';
    }
    $$capture{$path} = [ $val, \%attrs ];
    # print verbose message
    if ($et and $et->Options('Verbose') > 1) {
        $et->VerboseValue("+ XMP-$path", $val);
    }
}

#------------------------------------------------------------------------------
# Add new structure to capture hash for writing
# Inputs: 0) ExifTool object ref (or undef for no warnings),
#         1) tagInfo ref (or undef if no ExifTool), 2) capture hash ref,
#         3) base path, 4) struct ref, 5) struct hash ref
# Returns: number of tags changed
# Notes: Escapes values for XML
sub AddNewStruct($$$$$$)
{
    my ($et, $tagInfo, $capture, $basePath, $struct, $strTable) = @_;
    my $verbose = $et ? $et->Options('Verbose') : 0;
    my ($tag, %langIdx);

    my $ns = $$strTable{NAMESPACE} || '';
    my $changed = 0;

    # add dummy field to allow empty structures (name starts with '~' so it will come
    # after all valid structure fields, which is necessary when serializing the XMP later)
    %$struct or $$struct{'~dummy~'} = '';

    foreach $tag (sort keys %$struct) {
        my $fieldInfo = $$strTable{$tag};
        unless ($fieldInfo) {
            next unless $tag eq '~dummy~'; # check for dummy field
            $fieldInfo = { }; # create dummy field info for dummy structure
        }
        my $val = $$struct{$tag};
        my $propPath = $$fieldInfo{PropertyPath};
        unless ($propPath) {
            $propPath = ($$fieldInfo{Namespace} || $ns) . ':' . ($$fieldInfo{TagID} || $tag);
            if ($$fieldInfo{List}) {
                $propPath .= "/rdf:$$fieldInfo{List}/rdf:li 10";
            }
            if ($$fieldInfo{Writable} and $$fieldInfo{Writable} eq 'lang-alt') {
                $propPath .= "/rdf:Alt/rdf:li 10";
            }
            $$fieldInfo{PropertyPath} = $propPath;  # save for next time
        }
        my $path = $basePath . '/' . ConformPathToNamespace($et, $propPath);
        my $addedTag;
        if (ref $val eq 'HASH') {
            my $subStruct = $$fieldInfo{Struct} or next;
            $changed += AddNewStruct($et, $tagInfo, $capture, $path, $val, $subStruct);
        } elsif (ref $val eq 'ARRAY') {
            next unless $$fieldInfo{List};
            my $i = 0;
            my ($item, $p);
            # loop through all list items (note: can't yet write multi-dimensional lists)
            foreach $item (@{$val}) {
                if ($i) {
                    # update first index in field property (may be list of lang-alt lists)
                    $p = ConformPathToNamespace($et, $propPath);
                    my $idx = length($i) . $i;
                    $p =~ s/ \d+/ $idx/;
                    $p = "$basePath/$p";
                } else {
                    $p = $path;
                }
                if (ref $item eq 'HASH') {
                    my $subStruct = $$fieldInfo{Struct} or next;
                    AddNewStruct($et, $tagInfo, $capture, $p, $item, $subStruct) or next;
                } elsif (length $item) { # don't write empty items in list
                    AddNewTag($et, $fieldInfo, $capture, $p, \$item, \%langIdx);
                    $addedTag = 1;
                }
                ++$changed;
                ++$i;
            }
        } else {
            AddNewTag($et, $fieldInfo, $capture, $path, \$val, \%langIdx);
            $addedTag = 1;
            ++$changed;
        }
        # this is tricky, but we must add the rdf:type for contained structures
        # in the case that a whole hierarchy was added at once by writing a
        # flattened tag inside a variable-namespace structure
        if ($addedTag and $$fieldInfo{StructType} and $$fieldInfo{Table}) {
            AddStructType($et, $$fieldInfo{Table}, $capture, $propPath, $basePath);
        }
    }
    # add 'rdf:type' property if necessary
    if ($$strTable{TYPE} and $changed) {
        my $path = $basePath . '/' . ConformPathToNamespace($et, "rdf:type");
        unless ($$capture{$path}) {
            $$capture{$path} = [ '', { 'rdf:resource' => $$strTable{TYPE} } ];
            $et->VerboseValue("+ XMP-$path", $$strTable{TYPE}) if $verbose > 1;
        }
    }
    return $changed;
}

#------------------------------------------------------------------------------
# Convert structure field values for printing
# Inputs: 0) ExifTool ref, 1) tagInfo ref for structure tag, 2) value,
#         3) conversion type: PrintConv, ValueConv or Raw (Both not allowed)
#         4) tagID of parent structure (needed only if there was no flattened tag)
# Notes: Makes a copy of the hash so any applied escapes won't affect raw values
sub ConvertStruct($$$$;$)
{
    my ($et, $tagInfo, $value, $type, $parentID) = @_;
    if (ref $value eq 'HASH') {
        my (%struct, $key);
        my $table = $$tagInfo{Table};
        $parentID = $$tagInfo{TagID} unless $parentID;
        foreach $key (keys %$value) {
            my $tagID = $parentID . ucfirst($key);
            my $flatInfo = $$table{$tagID};
            unless ($flatInfo) {
                # handle variable-namespace structures
                if ($key =~ /^XMP-(.*?:)(.*)/) {
                    $tagID = $1 . $parentID . ucfirst($2);
                    $flatInfo = $$table{$tagID};
                }
                $flatInfo or $flatInfo = $tagInfo;
            }
            my $v = $$value{$key};
            if (ref $v) {
                $v = ConvertStruct($et, $flatInfo, $v, $type, $tagID);
            } else {
                $v = $et->GetValue($flatInfo, $type, $v);
            }
            $struct{$key} = $v if defined $v;  # save the converted value
        }
        return \%struct;
    } elsif (ref $value eq 'ARRAY') {
        if (defined $$et{OPTIONS}{ListItem}) {
            my $li = $$et{OPTIONS}{ListItem};
            return undef unless defined $$value[$li];
            undef $$et{OPTIONS}{ListItem};      # only do top-level list
            my $val = ConvertStruct($et, $tagInfo, $$value[$li], $type, $parentID);
            $$et{OPTIONS}{ListItem} = $li;
            return $val;
        } else {
            my (@list, $val);
            foreach $val (@$value) {
                my $v = ConvertStruct($et, $tagInfo, $val, $type, $parentID);
                push @list, $v if defined $v;
            }
            return \@list;
        }
    } else {
        return $et->GetValue($tagInfo, $type, $value);
    }
}

#------------------------------------------------------------------------------
# Restore XMP structures in extracted information
# Inputs: 0) ExifTool object ref, 1) flag to keep original flattened tags
# Notes: also restores lists (including multi-dimensional)
sub RestoreStruct($;$)
{
    local $_;
    my ($et, $keepFlat) = @_;
    my ($key, %structs, %var, %lists, $si, %listKeys);
    my $ex = $$et{TAG_EXTRA};
    my $valueHash = $$et{VALUE};
    my $tagExtra = $$et{TAG_EXTRA};
    foreach $key (keys %{$$et{TAG_INFO}}) {
        $$ex{$key} or next;
        my $structProps = $$ex{$key}{Struct} or next;
        delete $$ex{$key}{Struct}; # (don't re-use)
        my $tagInfo = $$et{TAG_INFO}{$key};   # tagInfo for flattened tag
        my $table = $$tagInfo{Table};
        my $prop = shift @$structProps;
        my $tag = $$prop[0];
        # get reference to structure tag (or normal list tag if not a structure)
        my $strInfo = @$structProps ? $$table{$tag} : $tagInfo;
        if ($strInfo) {
            ref $strInfo eq 'HASH' or next; # (just to be safe)
            if (@$structProps and not $$strInfo{Struct}) {
                # this could happen for invalid XMP containing mixed lists
                # (or for something like this -- what should we do here?:
                # <meta:user-defined meta:name="License">test</meta:user-defined>)
                $et->Warn("$$strInfo{Name} is not a structure!") unless $$et{NO_STRUCT_WARN};
                next;
            }
        } else {
            # create new entry in tag table for this structure
            my $g1 = $$table{GROUPS}{0} || 'XMP';
            my $name = $tag;
            # tag keys will have a group 1 prefix when coming from import of XML from -X option
            if ($tag =~ /(.+):(.+)/) {
                my $ns;
                ($ns, $name) = ($1, $2);
                $ns =~ s/^XMP-//; # remove leading "XMP-" if it exists because we add it later
                $ns = $stdXlatNS{$ns} if $stdXlatNS{$ns};
                $g1 .= "-$ns";
            }
            $strInfo = {
                Name => ucfirst $name,
                Groups => { 1 => $g1 },
                Struct => 'Unknown',
            };
            # add Struct entry if this is a structure
            if (@$structProps) {
                # this is a structure
                $$strInfo{Struct} = { STRUCT_NAME => 'XMP Unknown' } if @$structProps;
            } elsif ($$tagInfo{LangCode}) {
                # this is lang-alt list
                $tag = $tag . '-' . $$tagInfo{LangCode};
                $$strInfo{LangCode} = $$tagInfo{LangCode};
            }
            AddTagToTable($table, $tag, $strInfo);
        }
        # use strInfo ref for base key to avoid collisions
        $tag = $strInfo;
        my $struct = \%structs;
        my $oldStruct = $structs{$strInfo};
        # (fyi: 'lang-alt' Writable type will be valid even if tag is not pre-defined)
        my $writable = $$tagInfo{Writable} || '';
        # walk through the stored structure property information
        # to rebuild this structure
        my ($err, $i);
        for (;;) {
            my $index = $$prop[1];
            if ($index and not @$structProps) {
                # ignore this list if it is a simple lang-alt tag
                if ($writable eq 'lang-alt') {
                    pop @$prop; # remove lang-alt index
                    undef $index if @$prop < 2;
                }
                # add language code if necessary
                if ($$tagInfo{LangCode} and not ref $tag) {
                    $tag = $tag . '-' . $$tagInfo{LangCode};
                }
            }
            my $nextStruct = $$struct{$tag};
            if (defined $index) {
                # the field is a list
                $index = substr $index, 1;  # remove digit count
                if ($nextStruct) {
                    ref $nextStruct eq 'ARRAY' or $err = 2, last;
                    $struct = $nextStruct;
                } else {
                    $struct = $$struct{$tag} = [ ];
                }
                $nextStruct = $$struct[$index];
                # descend into multi-dimensional lists
                for ($i=2; $$prop[$i]; ++$i) {
                    if ($nextStruct) {
                        ref $nextStruct eq 'ARRAY' or last;
                        $struct = $nextStruct;
                    } else {
                        $lists{$struct} = $struct;
                        $struct = $$struct[$index] = [ ];
                    }
                    $nextStruct = $$struct[$index];
                    $index = substr $$prop[$i], 1;
                }
                if (ref $nextStruct eq 'HASH') {
                    $struct = $nextStruct;  # continue building sub-structure
                } elsif (@$structProps) {
                    $lists{$struct} = $struct;
                    $struct = $$struct[$index] = { };
                } else {
                    $lists{$struct} = $struct;
                    $$struct[$index] = $$valueHash{$key};
                    last;
                }
            } else {
                if ($nextStruct) {
                    ref $nextStruct eq 'HASH' or $err = 3, last;
                    $struct = $nextStruct;
                } elsif (@$structProps) {
                    $struct = $$struct{$tag} = { };
                } else {
                    $$struct{$tag} = $$valueHash{$key};
                    last;
                }
            }
            $prop = shift @$structProps or last;
            $tag = $$prop[0];
            if ($tag =~ /(.+):(.+)/) {
                # tag in variable-namespace tables will have a leading
                # XMP namespace on the tag name.  In this case, add
                # the corresponding group1 name to the tag ID.
                my ($ns, $name) = ($1, $2);
                $ns = $stdXlatNS{$ns} if $stdXlatNS{$ns};
                $tag = "XMP-$ns:" . ucfirst $name;
            } else {
                $tag = ucfirst $tag;
            }
        }
        if ($err) {
            # this may happen if we have a structural error in the XMP
            # (like an improperly contained list for example)
            unless ($$et{NO_STRUCT_WARN}) {
                my $ns = $$tagInfo{Namespace} || $$tagInfo{Table}{NAMESPACE} || '';
                $et->Warn("Error $err placing $ns:$$tagInfo{TagID} in structure or list", 1);
            }
            delete $structs{$strInfo} unless $oldStruct;
        } elsif ($tagInfo eq $strInfo) {
            # just a regular list tag
            if ($oldStruct) {
                # keep tag with lowest numbered key (well, not exactly, since
                # "Tag (10)" is lt "Tag (2)", but at least "Tag" is lt
                # everything else, and this is really what we care about)
                my $k = $listKeys{$oldStruct};
                $k lt $key and $et->DeleteTag($key), next;
                $et->DeleteTag($k);   # remove tag with greater copy number
            }
            # replace existing value with new list
            $$valueHash{$key} = $structs{$strInfo};
            $listKeys{$structs{$strInfo}} = $key;   # save key for this list tag
        } else {
            # save strInfo ref and file order
            if ($var{$strInfo}) {
                # set file order to just before the first associated flattened tag
                if ($var{$strInfo}[1] > $$et{FILE_ORDER}{$key}) {
                    $var{$strInfo}[1] = $$et{FILE_ORDER}{$key} - 0.5;
                }
            } else {
                $var{$strInfo} = [ $strInfo, $$et{FILE_ORDER}{$key} - 0.5 ];
            }
            # preserve original flattened tags if requested
            if ($keepFlat) {
                my $extra = $$tagExtra{$key} or next;
                # restore list behaviour of this flattened tag
                if ($$extra{NoList}) {
                    $$valueHash{$key} = $$extra{NoList};
                    delete $$extra{NoList};
                } elsif ($$extra{NoListDel}) {
                    # delete this tag since its value was included another list
                    $et->DeleteTag($key);
                }
            } else {
                $et->DeleteTag($key); # delete the flattened tag
            }
        }
    }
    # fill in undefined items in lists.  In theory, undefined list items should
    # be fine, but in practice the calling code may not check for this (and
    # historically this wasn't necessary, so do this for backward compatibility)
    foreach $si (keys %lists) {
        defined $_ or $_ = '' foreach @{$lists{$si}};
    }
    # save new structure tags
    foreach $si (keys %structs) {
        next unless $var{$si};  # already handled regular lists
        $key = $et->FoundTag($var{$si}[0], '');
        $$valueHash{$key} = $structs{$si};
        $$et{FILE_ORDER}{$key} = $var{$si}[1];
    }
}


1;  #end

__END__

=head1 NAME

Image::ExifTool::XMPStruct.pl - XMP structure support

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This file contains routines to provide read/write support of structured XMP
information.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/XMP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
