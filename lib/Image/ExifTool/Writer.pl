#------------------------------------------------------------------------------
# File:         Writer.pl
#
# Description:  ExifTool write routines
#
# Notes:        Also contains some less used ExifTool functions
#
# URL:          http://owl.phy.queensu.ca/~phil/exiftool/
#
# Revisions:    12/16/2004 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool;

use strict;

use Image::ExifTool::TagLookup qw(FindTagInfo TagExists);
use Image::ExifTool::Fixup;

sub AssembleRational($$@);
sub LastInList($);
sub CreateDirectory($$);
sub NextFreeTagKey($$);
sub RemoveNewValueHash($$$);
sub RemoveNewValuesForGroup($$);
sub GetWriteGroup1($$);
sub Sanitize($$);
sub ConvInv($$$$$;$$);

my $loadedAllTables;    # flag indicating we loaded all tables
my $advFmtSelf;         # ExifTool during evaluation of advanced formatting expr

# the following is a road map of where we write each directory
# in the different types of files.
my %tiffMap = (
    IFD0         => 'TIFF',
    IFD1         => 'IFD0',
    XMP          => 'IFD0',
    ICC_Profile  => 'IFD0',
    ExifIFD      => 'IFD0',
    GPS          => 'IFD0',
    SubIFD       => 'IFD0',
    GlobParamIFD => 'IFD0',
    PrintIM      => 'IFD0',
    IPTC         => 'IFD0',
    Photoshop    => 'IFD0',
    InteropIFD   => 'ExifIFD',
    MakerNotes   => 'ExifIFD',
    CanonVRD     => 'MakerNotes', # (so VRDOffset will get updated)
    NikonCapture => 'MakerNotes', # (to allow delete by group)
);
my %exifMap = (
    IFD1         => 'IFD0',
    EXIF         => 'IFD0', # to write EXIF as a block
    ExifIFD      => 'IFD0',
    GPS          => 'IFD0',
    SubIFD       => 'IFD0',
    GlobParamIFD => 'IFD0',
    PrintIM      => 'IFD0',
    InteropIFD   => 'ExifIFD',
    MakerNotes   => 'ExifIFD',
    NikonCapture => 'MakerNotes', # (to allow delete by group)
    # (no CanonVRD trailer allowed)
);
my %jpegMap = (
    %exifMap, # covers all JPEG EXIF mappings
    JFIF         => 'APP0',
    CIFF         => 'APP0',
    IFD0         => 'APP1',
    XMP          => 'APP1',
    ICC_Profile  => 'APP2',
    FlashPix     => 'APP2',
    MPF          => 'APP2',
    Meta         => 'APP3',
    MetaIFD      => 'Meta',
    RMETA        => 'APP5',
    Ducky        => 'APP12',
    Photoshop    => 'APP13',
    Adobe        => 'APP14',
    IPTC         => 'Photoshop',
    MakerNotes   => ['ExifIFD', 'CIFF'], # (first parent is the default)
    CanonVRD     => 'MakerNotes', # (so VRDOffset will get updated)
    NikonCapture => 'MakerNotes', # (to allow delete by group)
    Comment      => 'COM',
);
my %dirMap = (
    JPEG => \%jpegMap,
    EXV  => \%jpegMap,
    TIFF => \%tiffMap,
    ORF  => \%tiffMap,
    RAW  => \%tiffMap,
    EXIF => \%exifMap,
);

# module names and write functions for each writable file type
# (defaults to "$type" and "Process$type" if not defined)
# - types that are handled specially will not appear in this list
my %writableType = (
    CRW => [ 'CanonRaw',    'WriteCRW' ],
    DR4 =>   'CanonVRD',
    EPS => [ 'PostScript',  'WritePS'  ],
    FLIF=> [ undef,         'WriteFLIF'],
    GIF =>   undef,
    ICC => [ 'ICC_Profile', 'WriteICC' ],
    IND =>   'InDesign',
    JP2 =>   'Jpeg2000',
    MIE =>   undef,
    MOV => [ 'QuickTime',   'WriteMOV' ],
    MRW =>   'MinoltaRaw',
    PDF => [ undef,         'WritePDF' ],
    PNG =>   undef,
    PPM =>   undef,
    PS  => [ 'PostScript',  'WritePS'  ],
    PSD =>   'Photoshop',
    RAF => [ 'FujiFilm',    'WriteRAF' ],
    VRD =>   'CanonVRD',
    X3F =>   'SigmaRaw',
    XMP => [ undef,         'WriteXMP' ],
);

# groups we are allowed to delete
# Notes:
# 1) these names must either exist in %dirMap, or be translated in InitWriteDirs())
# 2) any dependencies must be added to %excludeGroups
my @delGroups = qw(
    Adobe AFCP APP0 APP1 APP2 APP3 APP4 APP5 APP6 APP7 APP8 APP9 APP10 APP11 APP12
    APP13 APP14 APP15 CanonVRD CIFF Ducky EXIF ExifIFD File FlashPix FotoStation
    GlobParamIFD GPS ICC_Profile IFD0 IFD1 InteropIFD IPTC JFIF Jpeg2000 MakerNotes
    Meta MetaIFD MIE MPF NikonCapture PDF PDF-update PhotoMechanic Photoshop PNG
    PNG-pHYs PrintIM RMETA RSRC SubIFD Trailer XML XML-* XMP XMP-*
);
# family 2 group names that we can delete
my @delGroup2 = qw(
    Audio Author Camera Document ExifTool Image Location Other Preview Printing
    Time Video
);

# lookup for all valid family 2 groups (lower case)
my %family2groups = map { lc $_ => 1 } @delGroup2, 'Unknown';

# groups we don't delete when deleting all information
my $protectedGroups = '(IFD1|SubIFD|InteropIFD|GlobParamIFD|PDF-update|Adobe)';

# other group names of new tag values to remove when deleting an entire group
my %removeGroups = (
    IFD0    => [ 'EXIF', 'MakerNotes' ],
    EXIF    => [ 'MakerNotes' ],
    ExifIFD => [ 'MakerNotes', 'InteropIFD' ],
    Trailer => [ 'CanonVRD' ], #(because we can add back CanonVRD as a block)
);
# related family 0/1 groups in @delGroups (and not already in %jpegMap)
# that must be removed from delete list when excluding a group
my %excludeGroups = (
    EXIF         => [ qw(IFD0 IFD1 ExifIFD GPS MakerNotes GlobParamIFD InteropIFD PrintIM SubIFD) ],
    IFD0         => [ 'EXIF' ],
    IFD1         => [ 'EXIF' ],
    ExifIFD      => [ 'EXIF' ],
    GPS          => [ 'EXIF' ],
    MakerNotes   => [ 'EXIF' ],
    InteropIFD   => [ 'EXIF' ],
    GlobParamIFD => [ 'EXIF' ],
    PrintIM      => [ 'EXIF' ],
    CIFF         => [ 'MakerNotes' ],
    # technically correct, but very uncommon and not a good reason to avoid deleting trailer
  # IPTC         => [ qw(AFCP FotoStation Trailer) ],
    AFCP         => [ 'Trailer' ],
    FotoStation  => [ 'Trailer' ],
    CanonVRD     => [ 'Trailer' ],
    PhotoMechanic=> [ 'Trailer' ],
    MIE          => [ 'Trailer' ],
);
# translate (lower case) wanted group when writing for tags where group name may change
my %translateWantGroup = (
    ciff  => 'canonraw',
);
# group names to translate for writing
my %translateWriteGroup = (
    EXIF  => 'ExifIFD',
    Meta  => 'MetaIFD',
    File  => 'Comment',
    # any entry in this table causes the write group to be set from the
    # tag information instead of whatever the user specified...
    MIE   => 'MIE',
    APP14 => 'APP14',
);
# names of valid EXIF and Meta directories (lower case keys):
my %exifDirs = (
    gps          => 'GPS',
    exififd      => 'ExifIFD',
    subifd       => 'SubIFD',
    globparamifd => 'GlobParamIFD',
    interopifd   => 'InteropIFD',
    previewifd   => 'PreviewIFD', # (in MakerNotes)
    metaifd      => 'MetaIFD', # Kodak APP3 Meta
    makernotes   => 'MakerNotes',
);
# valid family 0 groups when WriteGroup is set to "All"
my %allFam0 = (
    exif         => 1,
    makernotes   => 1,
);

my @writableMacOSTags = qw(
    FileCreateDate MDItemFinderComment MDItemFSCreationDate MDItemFSLabel MDItemUserTags
    XAttrQuarantine
);

# min/max values for integer formats
my %intRange = (
    'int8u'  => [0, 0xff],
    'int8s'  => [-0x80, 0x7f],
    'int16u' => [0, 0xffff],
    'int16uRev' => [0, 0xffff],
    'int16s' => [-0x8000, 0x7fff],
    'int32u' => [0, 0xffffffff],
    'int32s' => [-0x80000000, 0x7fffffff],
    'int64u' => [0, 18446744073709551615],
    'int64s' => [-9223372036854775808, 9223372036854775807],
);
# lookup for file types with block-writable EXIF
my %blockExifTypes = map { $_ => 1 } qw(JPEG PNG JP2 MIE EXIF FLIF);

my $maxSegmentLen = 0xfffd;     # maximum length of data in a JPEG segment
my $maxXMPLen = $maxSegmentLen; # maximum length of XMP data in JPEG

# value separators when conversion list is used (in SetNewValue)
my %listSep = ( PrintConv => '; ?', ValueConv => ' ' );

# printConv hash keys to ignore when doing reverse lookup
my %ignorePrintConv = map { $_ => 1 } qw(OTHER BITMASK Notes);

#------------------------------------------------------------------------------
# Set tag value
# Inputs: 0) ExifTool object reference
#         1) tag key, tag name, or '*' (optionally prefixed by group name),
#            or undef to reset all previous SetNewValue() calls
#         2) new value (scalar, scalar ref or list ref), or undef to delete tag
#         3-N) Options:
#           Type => PrintConv, ValueConv or Raw - specifies value type
#           AddValue => true to add to list of existing values instead of overwriting
#           DelValue => true to delete this existing value value from a list, or
#                       or doing a conditional delete, or to shift a time value
#           Group => family 0 or 1 group name (case insensitive)
#           Replace => 0, 1 or 2 - overwrite previous new values (2=reset)
#           Protected => bitmask to write tags with specified protections
#           EditOnly => true to only edit existing tags (don't create new tag)
#           EditGroup => true to only edit existing groups (don't create new group)
#           Shift => undef, 0, +1 or -1 - shift value if possible
#           NoFlat => treat flattened tags as 'unsafe'
#           NoShortcut => true to prevent looking up shortcut tags
#           ProtectSaved => protect existing new values with a save count greater than this
#           CreateGroups => [internal use] createGroups hash ref from related tags
#           ListOnly => [internal use] set only list or non-list tags
#           SetTags => [internal use] hash ref to return tagInfo refs of set tags
#           Sanitized => [internal use] set to avoid double-sanitizing the value
# Returns: number of tags set (plus error string in list context)
# Notes: For tag lists (like Keywords), call repeatedly with the same tag name for
#        each value in the list.  Internally, the new information is stored in
#        the following members of the $$self{NEW_VALUE}{$tagInfo} hash:
#           TagInfo - tag info ref
#           DelValue - list ref for values to delete
#           Value - list ref for values to add (not defined if deleting the tag)
#           IsCreating - must be set for the tag to be added for the standard file types,
#                        otherwise just changed if it already exists.  This may be
#                        overridden for file types with a PREFERRED metadata type.
#                        Set to 2 to create inidividual tags but not new groups
#           EditOnly - flag set if tag should never be created (regardless of file type).
#                      If this is set, then IsCreating must be false
#           CreateOnly - flag set if creating only (never edit existing tag)
#           CreateGroups - hash of all family 0 group names where tag may be created
#           WriteGroup - group name where information is being written (correct case)
#           WantGroup - group name as specified in call to function (case insensitive)
#           Next - pointer to next new value hash (if more than one)
#           NoReplace - set if value was created with Replace=0
#           AddBefore - number of list items added by a subsequent Replace=0 call
#           IsNVH - Flag indicating this is a new value hash
#           Shift - shift value
#           Save - counter used by SaveNewValues()/RestoreNewValues()
#           MAKER_NOTE_FIXUP - pointer to fixup if necessary for a maker note value
sub SetNewValue($;$$%)
{
    local $_;
    my ($self, $tag, $value, %options) = @_;
    my ($err, $tagInfo, $family);
    my $verbose = $$self{OPTIONS}{Verbose};
    my $out = $$self{OPTIONS}{TextOut};
    my $protected = $options{Protected} || 0;
    my $listOnly = $options{ListOnly};
    my $setTags = $options{SetTags};
    my $noFlat = $options{NoFlat};
    my $numSet = 0;

    unless (defined $tag) {
        delete $$self{NEW_VALUE};
        $$self{SAVE_COUNT} = 0;
        $$self{DEL_GROUP} = { };
        return 1;
    }
    # allow value to be scalar or list reference
    if (ref $value) {
        if (ref $value eq 'ARRAY') {
            # value is an ARRAY so it may have more than one entry
            # - set values both separately and as a combined string if there are more than one
            if (@$value > 1) {
                # set all list-type tags first
                my $replace = $options{Replace};
                my $noJoin;
                foreach (@$value) {
                    $noJoin = 1 if ref $_;
                    my ($n, $e) = SetNewValue($self, $tag, $_, %options, ListOnly => 1);
                    $err = $e if $e;
                    $numSet += $n;
                    delete $options{Replace}; # don't replace earlier values in list
                }
                return $numSet if $noJoin;  # don't join if list contains objects
                # and now set only non-list tags
                $value = join $$self{OPTIONS}{ListSep}, @$value;
                $options{Replace} = $replace;
                $listOnly = $options{ListOnly} = 0;
            } else {
                $value = $$value[0];
                $value = $$value if ref $value eq 'SCALAR'; # (handle single scalar ref in a list)
            }
        } elsif (ref $value eq 'SCALAR') {
            $value = $$value;
        }
    }
    # un-escape as necessary and make sure the Perl UTF-8 flag is OFF for the value
    # if perl is 5.6 or greater (otherwise our byte manipulations get corrupted!!)
    $self->Sanitize(\$value) if defined $value and not ref $value and not $options{Sanitized};

    # set group name in options if specified
    ($options{Group}, $tag) = ($1, $2) if $tag =~ /(.*):(.+)/;

    # allow trailing '#' for ValueConv value
    $options{Type} = 'ValueConv' if $tag =~ s/#$//;
    my $convType = $options{Type} || ($$self{OPTIONS}{PrintConv} ? 'PrintConv' : 'ValueConv');

    my (@wantGroup, $family2);
    my $wantGroup = $options{Group};
    if ($wantGroup) {
        foreach (split /:/, $wantGroup) {
            next unless length($_) and /^(\d+)?(.*)/; # separate family number and group name
            my ($f, $g) = ($1, lc $2);
            # save group/family unless '*' or 'all'
            push @wantGroup, [ $f, $g ] unless $g eq '*' or $g eq 'all';
            if (defined $f) {
                $f > 2 and return 0;      # only allow family 0, 1 or 2
                $family2 = 1 if $f == 2;  # set flag indicating family 2 was used
            } else {
                $family2 = 1 if $family2groups{$g};
            }
        }
        undef $wantGroup unless @wantGroup;
    }

    $tag =~ s/ .*//;    # convert from tag key to tag name if necessary
    $tag = '*' if lc($tag) eq 'all';    # use '*' instead of 'all'
#
# handle group delete
#
    while ($tag eq '*' and not defined $value and not $family2 and @wantGroup < 2) {
        # set groups to delete
        my (@del, $grp);
        my $remove = ($options{Replace} and $options{Replace} > 1);
        if ($wantGroup) {
            @del = grep /^$wantGroup$/i, @delGroups unless $wantGroup =~ /^XM[LP]-\*$/i;
            # remove associated groups when excluding from mass delete
            if (@del and $remove) {
                # remove associated groups in other family
                push @del, @{$excludeGroups{$del[0]}} if $excludeGroups{$del[0]};
                # remove upstream groups according to JPEG map
                my $dirName = $del[0];
                my @dirNames;
                for (;;) {
                    my $parent = $jpegMap{$dirName};
                    if (ref $parent) {
                        push @dirNames, @$parent;
                        $parent = pop @dirNames;
                    }
                    $dirName = $parent || shift @dirNames or last;
                    push @del, $dirName;    # exclude this too
                }
            }
            # allow MIE groups to be deleted by number,
            # and allow any XMP family 1 group to be deleted
            push @del, uc($wantGroup) if $wantGroup =~ /^(MIE\d+|XM[LP]-[-\w]*\w)$/i;
        } else {
            # push all groups plus '*', except the protected groups
            push @del, (grep !/^$protectedGroups$/, @delGroups), '*';
        }
        if (@del) {
            ++$numSet;
            my @donegrps;
            my $delGroup = $$self{DEL_GROUP};
            foreach $grp (@del) {
                if ($remove) {
                    my $didExcl;
                    if ($grp =~ /^(XM[LP])(-.*)?$/) {
                        my $x = $1;
                        if ($grp eq $x) {
                            # exclude all related family 1 groups too
                            foreach (keys %$delGroup) {
                                next unless /^(-?)$x-/;
                                push @donegrps, $_ unless $1;
                                delete $$delGroup{$_};
                            }
                        } elsif ($$delGroup{"$x-*"} and not $$delGroup{"-$grp"}) {
                            # must also exclude XMP or XML to prevent bulk delete
                            if ($$delGroup{$x}) {
                                push @donegrps, $x;
                                delete $$delGroup{$x};
                            }
                            # flag XMP/XML family 1 group for exclusion with leading '-'
                            $$delGroup{"-$grp"} = 1;
                            $didExcl = 1;
                        }
                    }
                    if (exists $$delGroup{$grp}) {
                        delete $$delGroup{$grp};
                    } else {
                        next unless $didExcl;
                    }
                } else {
                    $$delGroup{$grp} = 1;
                    # add flag for XMP/XML family 1 groups if deleting all XMP
                    if ($grp =~ /^XM[LP]$/) {
                        $$delGroup{"$grp-*"} = 1;
                        push @donegrps, "$grp-*";
                    }
                    # remove all of this group from previous new values
                    $self->RemoveNewValuesForGroup($grp);
                }
                push @donegrps, $grp;
            }
            if ($verbose > 1 and @donegrps) {
                @donegrps = sort @donegrps;
                my $msg = $remove ? 'Excluding from deletion' : 'Deleting tags in';
                print $out "  $msg: @donegrps\n";
            }
        } elsif (grep /^$wantGroup$/i, @delGroup2) {
            last;   # allow tags to be deleted by group2 name
        } else {
            $err = "Not a deletable group: $wantGroup";
        }
        # all done
        return ($numSet, $err) if wantarray;
        $err and warn "$err\n";
        return $numSet;
    }

    # initialize write/create flags
    my $createOnly;
    my $editOnly = $options{EditOnly};
    my $editGroup = $options{EditGroup};
    my $writeMode = $$self{OPTIONS}{WriteMode};
    if ($writeMode ne 'wcg') {
        $createOnly = 1 if $writeMode !~ /w/i;  # don't write existing tags
        if ($writeMode !~ /c/i) {
            return 0 if $createOnly;    # nothing to do unless writing existing tags
            $editOnly = 1;              # don't create new tags
        } elsif ($writeMode !~ /g/i) {
            $editGroup = 1;             # don't create new groups
        }
    }
    my ($ifdName, $mieGroup, $movGroup, $fg);
    # set family 1 group names
    foreach $fg (@wantGroup) {
        next if defined $$fg[0] and $$fg[0] != 1;
        $_ = $$fg[1];
        # set $ifdName if this group is a valid IFD or SubIFD name
        my $grpName;
        if (/^IFD(\d+)$/i) {
            $grpName = $ifdName = "IFD$1";
        } elsif (/^SubIFD(\d+)$/i) {
            $grpName = $ifdName = "SubIFD$1";
        } elsif (/^Version(\d+)$/i) {
            $grpName = $ifdName = "Version$1"; # Sony IDC VersionIFD
        } elsif ($exifDirs{$_}) {
            $grpName = $exifDirs{$_};
            $ifdName = $grpName unless $ifdName and $allFam0{$_};
        } elsif ($allFam0{$_}) {
            $grpName = $allFam0{$_};
        } elsif (/^Track(\d+)$/i) {
            $grpName = $movGroup = "Track$1";  # QuickTime track
        } elsif (/^MIE(\d*-?)(\w+)$/i) {
            $grpName = $mieGroup = "MIE$1" . ucfirst(lc($2));
        } elsif (not $ifdName and /^XMP\b/i) {
            # must load XMP table to set group1 names
            my $table = GetTagTable('Image::ExifTool::XMP::Main');
            my $writeProc = $$table{WRITE_PROC};
            $writeProc and &$writeProc();
        }
        # fix case for known groups
        $wantGroup =~ s/$grpName/$grpName/i if $grpName and $grpName ne $_;
    }
#
# get list of tags we want to set
#
    my $origTag = $tag;
    my @matchingTags = FindTagInfo($tag);
    until (@matchingTags) {
        my $langCode;
        # allow language suffix of form "-en_CA" or "-<rfc3066>" on tag name
        if ($tag =~ /^([?*\w]+)-([a-z]{2})(_[a-z]{2})$/i or # MIE
            $tag =~ /^([?*\w]+)-([a-z]{2,3}|[xi])(-[a-z\d]{2,8}(-[a-z\d]{1,8})*)?$/i) # XMP/PNG
        {
            $tag = $1;
            # normalize case of language codes
            $langCode = lc($2);
            $langCode .= (length($3) == 3 ? uc($3) : lc($3)) if $3;
            my @newMatches = FindTagInfo($tag);
            foreach $tagInfo (@newMatches) {
                # only allow language codes in tables which support them
                next unless $$tagInfo{Table};
                my $langInfoProc = $$tagInfo{Table}{LANG_INFO} or next;
                my $langInfo = &$langInfoProc($tagInfo, $langCode);
                push @matchingTags, $langInfo if $langInfo;
            }
            last if @matchingTags;
        } elsif (not $options{NoShortcut}) {
            # look for a shortcut or alias
            require Image::ExifTool::Shortcuts;
            my ($match) = grep /^\Q$tag\E$/i, keys %Image::ExifTool::Shortcuts::Main;
            undef $err;
            if ($match) {
                $options{NoShortcut} = $options{Sanitized} = 1;
                foreach $tag (@{$Image::ExifTool::Shortcuts::Main{$match}}) {
                    my ($n, $e) = $self->SetNewValue($tag, $value, %options);
                    $numSet += $n;
                    $e and $err = $e;
                }
                undef $err if $numSet;  # no error if any set successfully
                return ($numSet, $err) if wantarray;
                $err and warn "$err\n";
                return $numSet;
            }
        }
        unless ($listOnly) {
            if (not TagExists($tag)) {
                if ($tag =~ /^[-\w*?]+$/) {
                    my $pre = $wantGroup ? $wantGroup . ':' : '';
                    $err = "Tag '$pre${origTag}' is not defined";
                    $err .= ' or has a bad language code' if $origTag =~ /-/;
                } else {
                    $err = "Invalid tag name '${tag}'";
                    $err .= " (remove the leading '\$')" if $tag =~ /^\$/;
                }
            } elsif ($langCode) {
                $err = "Tag '${tag}' does not support alternate languages";
            } elsif ($wantGroup) {
                $err = "Sorry, $wantGroup:$origTag doesn't exist or isn't writable";
            } else {
                $err = "Sorry, $origTag is not writable";
            }
            $verbose > 2 and print $out "$err\n";
        }
        # all done
        return ($numSet, $err) if wantarray;
        $err and warn "$err\n";
        return $numSet;
    }
    # get group name that we're looking for
    my $foundMatch = 0;
#
# determine the groups for all tags found, and the tag with
# the highest priority group
#
    my (@tagInfoList, @writeAlsoList, %writeGroup, %preferred, %tagPriority);
    my (%avoid, $wasProtected, $noCreate, %highestPriority);

TAG: foreach $tagInfo (@matchingTags) {
        $tag = $$tagInfo{Name};     # get tag name for warnings
        my $lcTag = lc $tag;        # get lower-case tag name for use in variables
        # initialize highest priority if we are starting a new tag
        $highestPriority{$lcTag} = -999 unless defined $highestPriority{$lcTag};
        my ($priority, $writeGroup);
        if ($wantGroup) {
            # a WriteGroup of All is special
            my $wgAll = ($$tagInfo{WriteGroup} and $$tagInfo{WriteGroup} eq 'All');
            my @grp = $self->GetGroup($tagInfo);
            foreach $fg (@wantGroup) {
                my ($fam, $lcWant) = @$fg;
                $lcWant = $translateWantGroup{$lcWant} if $translateWantGroup{$lcWant};
                # only set tag in specified group
                if (not defined $fam) {
                    if ($lcWant eq lc $grp[0]) {
                        # don't go to more generate write group of "All"
                        # if something more specific was wanted
                        $writeGroup = $grp[0] if $wgAll and not $writeGroup;
                        next;
                    }
                    next if $lcWant eq lc $grp[2];
                } elsif ($fam != 1 and not $$tagInfo{AllowGroup}) {
                    next if $lcWant eq lc $grp[$fam];
                    if ($wgAll and not $fam and $allFam0{$lcWant}) {
                        $writeGroup or $writeGroup = $allFam0{$lcWant};
                        next;
                    }
                    next TAG;   # wrong group
                }
                # handle family 1 groups specially
                if ($grp[0] eq 'EXIF' or $grp[0] eq 'SonyIDC' or $wgAll) {
                    unless ($ifdName and $lcWant eq lc $ifdName) {
                        next TAG unless $wgAll and not $fam and $allFam0{$lcWant};
                        $writeGroup = $allFam0{$lcWant} unless $writeGroup;
                        next;
                    }
                    next TAG if $wgAll and $allFam0{$lcWant} and $fam;
                    # can't yet write PreviewIFD tags (except for image)
                    $lcWant eq 'PreviewIFD' and ++$foundMatch, next TAG;
                    $writeGroup = $ifdName; # write to the specified IFD
                } elsif ($grp[0] eq 'QuickTime' and $grp[1] eq 'Track#') {
                    next TAG unless $movGroup and $lcWant eq lc($movGroup);
                    $writeGroup = $movGroup;
                } elsif ($grp[0] eq 'MIE') {
                    next TAG unless $mieGroup and $lcWant eq lc($mieGroup);
                    $writeGroup = $mieGroup; # write to specific MIE group
                    # set specific write group with document number if specified
                    if ($writeGroup =~ /^MIE\d+$/ and $$tagInfo{Table}{WRITE_GROUP}) {
                        $writeGroup = $$tagInfo{Table}{WRITE_GROUP};
                        $writeGroup =~ s/^MIE/$mieGroup/;
                    }
                } elsif (not $$tagInfo{AllowGroup} or $lcWant !~ /^$$tagInfo{AllowGroup}$/i) {
                    # allow group1 name to be specified
                    next TAG unless $lcWant eq lc $grp[1];
                }
            }
            $writeGroup or $writeGroup = ($$tagInfo{WriteGroup} || $grp[0]);
            $priority = 1000; # highest priority since group was specified
        }
        ++$foundMatch;
        # must do a dummy call to the write proc to autoload write package
        # before checking Writable flag
        my $table = $$tagInfo{Table};
        my $writeProc = $$table{WRITE_PROC};
        # load source table if this was a user-defined table
        if ($$table{SRC_TABLE}) {
            my $src = GetTagTable($$table{SRC_TABLE});
            $writeProc = $$src{WRITE_PROC} unless $writeProc;
        }
        next unless $writeProc and &$writeProc();
        # must still check writable flags in case of UserDefined tags
        my $writable = $$tagInfo{Writable};
        next unless $writable or ($$table{WRITABLE} and
            not defined $writable and not $$tagInfo{SubDirectory});
        # set specific write group (if we didn't already)
        if (not $writeGroup or ($translateWriteGroup{$writeGroup} and
            (not $$tagInfo{WriteGroup} or $$tagInfo{WriteGroup} ne 'All')))
        {
            # use default write group
            $writeGroup = $$tagInfo{WriteGroup} || $$tagInfo{Table}{WRITE_GROUP};
            # use group 0 name if no WriteGroup specified
            my $group0 = $self->GetGroup($tagInfo, 0);
            $writeGroup or $writeGroup = $group0;
            # get priority for this group
            unless ($priority) {
                $priority = $$self{WRITE_PRIORITY}{lc($writeGroup)};
                unless ($priority) {
                    $priority = $$self{WRITE_PRIORITY}{lc($group0)} || 0;
                }
            }
        }
        # don't write tag if protected
        my $prot = $$tagInfo{Protected};
        $prot = 1 if $noFlat and defined $$tagInfo{Flat};
        if ($prot) {
            $prot &= ~$protected;
            if ($prot) {
                my %lkup = ( 1=>'unsafe', 2=>'protected', 3=>'unsafe and protected');
                $wasProtected = $lkup{$prot};
                if ($verbose > 1) {
                    my $wgrp1 = $self->GetWriteGroup1($tagInfo, $writeGroup);
                    print $out "Sorry, $wgrp1:$tag is $wasProtected for writing\n";
                }
                next;
            }
        }
        # set priority for this tag
        $tagPriority{$tagInfo} = $priority;
        if ($priority > $highestPriority{$lcTag}) {
            $highestPriority{$lcTag} = $priority;
            $preferred{$lcTag} = { $tagInfo => 1 };
            $avoid{$lcTag} = $$tagInfo{Avoid} ? 1 : 0;
        } elsif ($priority == $highestPriority{$lcTag}) {
            # create all tags with highest priority
            $preferred{$lcTag}{$tagInfo} = 1;
            ++$avoid{$lcTag} if $$tagInfo{Avoid};
        }
        if ($$tagInfo{WriteAlso}) {
            # store WriteAlso tags separately so we can set them first
            push @writeAlsoList, $tagInfo;
        } else {
            push @tagInfoList, $tagInfo;
        }
        $writeGroup{$tagInfo} = $writeGroup;
    }
    # sort tag info list in reverse order of priority (higest number last)
    # so we get the highest priority error message in the end
    @tagInfoList = sort { $tagPriority{$a} <=> $tagPriority{$b} } @tagInfoList;
    # must write any tags which also write other tags first
    unshift @tagInfoList, @writeAlsoList if @writeAlsoList;

    # check priorities for each set of tags we are writing
    my $lcTag;
    foreach $lcTag (keys %preferred) {
        # don't create tags with priority 0 if group priorities are set
        if ($preferred{$lcTag} and $highestPriority{$lcTag} == 0 and
            %{$$self{WRITE_PRIORITY}})
        {
            delete $preferred{$lcTag}
        }
        # avoid creating tags with 'Avoid' flag set if there are other alternatives
        if ($avoid{$lcTag} and $preferred{$lcTag}) {
            if ($avoid{$lcTag} < scalar(keys %{$preferred{$lcTag}})) {
                # just remove the 'Avoid' tags since there are other preferred tags
                foreach $tagInfo (@tagInfoList) {
                    next unless $lcTag eq lc $$tagInfo{Name};
                    delete $preferred{$lcTag}{$tagInfo} if $$tagInfo{Avoid};
                }
            } elsif ($highestPriority{$lcTag} < 1000) {
                # look for another priority tag to create instead
                my $nextHighest = 0;
                my @nextBestTags;
                foreach $tagInfo (@tagInfoList) {
                    next unless $lcTag eq lc $$tagInfo{Name};
                    my $priority = $tagPriority{$tagInfo} or next;
                    next if $priority == $highestPriority{$lcTag};
                    next if $priority < $nextHighest;
                    next if $$tagInfo{Avoid} or $$tagInfo{Permanent};
                    next if $writeGroup{$tagInfo} eq 'MakerNotes';
                    if ($nextHighest < $priority) {
                        $nextHighest = $priority;
                        undef @nextBestTags;
                    }
                    push @nextBestTags, $tagInfo;
                }
                if (@nextBestTags) {
                    # change our preferred tags to the next best tags
                    delete $preferred{$lcTag};
                    foreach $tagInfo (@nextBestTags) {
                        $preferred{$lcTag}{$tagInfo} = 1;
                    }
                }
            }
        }
    }
#
# generate new value hash for each tag
#
    my ($prioritySet, $createGroups, %alsoWrote);

    delete $$self{CHECK_WARN};  # reset CHECK_PROC warnings

    # loop through all valid tags to find the one(s) to write
    foreach $tagInfo (@tagInfoList) {
        next if $alsoWrote{$tagInfo};   # don't rewrite tags we already wrote
        # only process List or non-List tags if specified
        next if defined $listOnly and ($listOnly xor $$tagInfo{List});
        my $noConv;
        my $writeGroup = $writeGroup{$tagInfo};
        my $permanent = $$tagInfo{Permanent};
        $writeGroup eq 'MakerNotes' and $permanent = 1 unless defined $permanent;
        my $wgrp1 = $self->GetWriteGroup1($tagInfo, $writeGroup);
        $tag = $$tagInfo{Name};     # get tag name for warnings
        my $pref = $preferred{lc $tag} || { };
        my $shift = $options{Shift};
        my $addValue = $options{AddValue};
        if (defined $shift) {
            # (can't currently shift list-type tags)
            my $shiftable;
            if ($$tagInfo{List}) {
                $shiftable = '';    # can add/delete but not shift
            } else {
                $shiftable = $$tagInfo{Shift};
                unless ($shift) {
                    # set shift according to AddValue/DelValue
                    $shift = 1 if $addValue;
                    # can shift a date/time with -=, but this is
                    # a conditional delete operation for other tags
                    $shift = -1 if $options{DelValue} and defined $shiftable and $shiftable eq 'Time';
                }
                if ($shift and (not defined $value or not length $value)) {
                    # (now allow -= to be used for shiftable tag - v8.05)
                    #$err = "No value for time shift of $wgrp1:$tag";
                    #$verbose > 2 and print $out "$err\n";
                    #next;
                    undef $shift;
                }
            }
                # can't shift List-type tag
            if ((defined $shiftable and not $shiftable) and
                # and don't try to conditionally delete if Shift is "0"
                ($shift or ($shiftable eq '0' and $options{DelValue})))
            {
                $err = "$wgrp1:$tag is not shiftable";
                $verbose > 2 and print $out "$err\n";
                next;
            }
        }
        my $val = $value;
        if (defined $val) {
            # check to make sure this is a List or Shift tag if adding
            if ($addValue and not ($shift or $$tagInfo{List})) {
                if ($addValue eq '2') {
                    undef $addValue;    # quitely reset this option
                } else {
                    $err = "Can't add $wgrp1:$tag (not a List type)";
                    $verbose > 2 and print $out "$err\n";
                    next;
                }
            }
            if ($shift) {
                if ($$tagInfo{Shift} and $$tagInfo{Shift} eq 'Time') {
                    # add '+' or '-' prefix to indicate shift direction
                    $val = ($shift > 0 ? '+' : '-') . $val;
                    # check the shift for validity
                    require 'Image/ExifTool/Shift.pl';
                    my $err2 = CheckShift($$tagInfo{Shift}, $val);
                    if ($err2) {
                        $err = "$err2 for $wgrp1:$tag";
                        $verbose > 2 and print $out "$err\n";
                        next;
                    }
                } elsif (IsFloat($val)) {
                    $val *= $shift;
                } else {
                    $err = "Shift value for $wgrp1:$tag is not a number";
                    $verbose > 2 and print $out "$err\n";
                    next;
                }
                $noConv = 1;    # no conversions if shifting tag
            } elsif (not length $val and $options{DelValue}) {
                $noConv = 1;    # no conversions for deleting empty value
            } elsif (ref $val eq 'HASH' and not $$tagInfo{Struct}) {
                $err = "Can't write a structure to $wgrp1:$tag";
                $verbose > 2 and print $out "$err\n";
                next;
            }
        } elsif ($permanent) {
            # can't delete permanent tags, so set them to DelValue or empty string instead
            if (defined $$tagInfo{DelValue}) {
                $val = $$tagInfo{DelValue};
                $noConv = 1;    # DelValue is the raw value, so no conversion necessary
            } else {
                $val = '';
            }
        } elsif ($addValue or $options{DelValue}) {
            $err = "No value to add or delete in $wgrp1:$tag";
            $verbose > 2 and print $out "$err\n";
            next;
        } else {
            if ($$tagInfo{DelCheck}) {
                #### eval DelCheck ($self, $tagInfo, $wantGroup)
                my $err2 = eval $$tagInfo{DelCheck};
                $@ and warn($@), $err2 = 'Error evaluating DelCheck';
                if (defined $err2) {
                    # (allow other tags to be set using DelCheck as a hook)
                    $err2 or goto WriteAlso; # GOTO!
                    $err2 .= ' for' unless $err2 =~ /delete$/;
                    $err = "$err2 $wgrp1:$tag";
                    $verbose > 2 and print $out "$err\n";
                    next;
                }
            }
            $noConv = 1;    # value is not defined, so don't do conversion
        }
        # apply inverse PrintConv and ValueConv conversions
        # save ValueConv setting for use in ConvInv()
        unless ($noConv) {
            # set default conversion type used by ConvInv() and CHECK_PROC routines
            $$self{ConvType} = $convType;
            my $e;
            ($val,$e) = $self->ConvInv($val,$tagInfo,$tag,$wgrp1,$$self{ConvType},$wantGroup);
            if (defined $e) {
                # empty error string causes error to be ignored without setting the value
                $e or goto WriteAlso; # GOTO!
                $err = $e;
            }
        }
        if (not defined $val and defined $value) {
            # if value conversion failed, we must still add a NEW_VALUE
            # entry for this tag it it was a DelValue
            next unless $options{DelValue};
            $val = 'xxx never delete xxx';
        }
        $$self{NEW_VALUE} or $$self{NEW_VALUE} = { };
        if ($options{Replace}) {
            # delete the previous new value
            $self->GetNewValueHash($tagInfo, $writeGroup, 'delete', $options{ProtectSaved});
            # also delete related tag previous new values
            if ($$tagInfo{WriteAlso}) {
                my ($wgrp, $wtag);
                if ($$tagInfo{WriteGroup} and $$tagInfo{WriteGroup} eq 'All' and $writeGroup) {
                    $wgrp = $writeGroup . ':';
                } else {
                    $wgrp = '';
                }
                foreach $wtag (keys %{$$tagInfo{WriteAlso}}) {
                    my ($n,$e) = $self->SetNewValue($wgrp . $wtag, undef, Replace=>2);
                    $numSet += $n;
                }
            }
            $options{Replace} == 2 and ++$numSet, next;
        }

        if (defined $val) {
            # we are editing this tag, so create a NEW_VALUE hash entry
            my $nvHash = $self->GetNewValueHash($tagInfo, $writeGroup, 'create',
                                $options{ProtectSaved}, ($options{DelValue} and not $shift));
            # ignore new values protected with ProtectSaved
            $nvHash or ++$numSet, next; # (increment $numSet to avoid warning)
            $$nvHash{NoReplace} = 1 if $$tagInfo{List} and not $options{Replace};
            $$nvHash{WantGroup} = $wantGroup;
            $$nvHash{EditOnly} = 1 if $editOnly;
            # save maker note information if writing maker notes
            if ($$tagInfo{MakerNotes}) {
                $$nvHash{MAKER_NOTE_FIXUP} = $$self{MAKER_NOTE_FIXUP};
            }
            if ($createOnly) {  # create only (never edit)
                # empty item in DelValue list to never edit existing value
                $$nvHash{DelValue} = [ '' ];
                $$nvHash{CreateOnly} = 1;
            } elsif ($options{DelValue} or $addValue or $shift) {
                # flag any AddValue or DelValue by creating the DelValue list
                $$nvHash{DelValue} or $$nvHash{DelValue} = [ ];
                if ($shift) {
                    # add shift value to list
                    $$nvHash{Shift} = $val;
                } elsif ($options{DelValue}) {
                    # don't create if we are replacing a specific value
                    $$nvHash{IsCreating} = 0 unless $val eq '' or $$tagInfo{List};
                    # add delete value to list
                    push @{$$nvHash{DelValue}}, ref $val eq 'ARRAY' ? @$val : $val;
                    if ($verbose > 1) {
                        my $verb = $permanent ? 'Replacing' : 'Deleting';
                        my $fromList = $$tagInfo{List} ? ' from list' : '';
                        my @vals = (ref $val eq 'ARRAY' ? @$val : $val);
                        foreach (@vals) {
                            if (ref $_ eq 'HASH') {
                                require 'Image/ExifTool/XMPStruct.pl';
                                $_ = Image::ExifTool::XMP::SerializeStruct($_);
                            }
                            print $out "$verb $wgrp1:$tag$fromList if value is '${_}'\n";
                        }
                    }
                }
            }
            # set priority flag to add only the high priority info
            # (will only create the priority tag if it doesn't exist,
            #  others get changed only if they already exist)
            if ($$pref{$tagInfo} or $$tagInfo{Table}{PREFERRED}) {
                if ($permanent or $shift) {
                    # don't create permanent or Shift-ed tag but define IsCreating
                    # so we know that it is the preferred tag
                    $$nvHash{IsCreating} = 0;
                } elsif (($$tagInfo{List} and not $options{DelValue}) or
                         not ($$nvHash{DelValue} and @{$$nvHash{DelValue}}) or
                         # also create tag if any DelValue value is empty ('')
                         grep(/^$/,@{$$nvHash{DelValue}}))
                {
                    $$nvHash{IsCreating} = $editOnly ? 0 : ($editGroup ? 2 : 1);
                    # add to hash of groups where this tag is being created
                    $createGroups or $createGroups = $options{CreateGroups} || { };
                    $$createGroups{$self->GetGroup($tagInfo, 0)} = 1;
                    $$nvHash{CreateGroups} = $createGroups;
                }
            }
            if ($$nvHash{IsCreating}) {
                if (%{$$self{DEL_GROUP}}) {
                    my ($grp, @grps);
                    foreach $grp (keys %{$$self{DEL_GROUP}}) {
                        next if $$self{DEL_GROUP}{$grp} == 2;
                        # set flag indicating tags were written after this group was deleted
                        $$self{DEL_GROUP}{$grp} = 2;
                        push @grps, $grp;
                    }
                    if ($verbose > 1 and @grps) {
                        @grps = sort @grps;
                        print $out "  Writing new tags after deleting groups: @grps\n";
                    }
                }
            } elsif ($createOnly) {
                $noCreate = $permanent ? 'permanent' : ($$tagInfo{Avoid} ? 'avoided' : '');
                $noCreate or $noCreate = $shift ? 'shifting' : 'not preferred';
                $verbose > 2 and print $out "Not creating $wgrp1:$tag ($noCreate)\n";
                next;   # nothing to do (not creating and not editing)
            }
            if ($shift or not $options{DelValue}) {
                $$nvHash{Value} or $$nvHash{Value} = [ ];
                if (not $$tagInfo{List}) {
                    # not a List tag -- overwrite existing value
                    $$nvHash{Value}[0] = $val;
                } elsif (defined $$nvHash{AddBefore} and @{$$nvHash{Value}} >= $$nvHash{AddBefore}) {
                    # values from a later argument have been added (ie. Replace=0)
                    # to this list, so the new values should come before these
                    splice @{$$nvHash{Value}}, -$$nvHash{AddBefore}, 0, ref $val eq 'ARRAY' ? @$val : $val;
                } else {
                    # add at end of existing list
                    push @{$$nvHash{Value}}, ref $val eq 'ARRAY' ? @$val : $val;
                }
                if ($verbose > 1) {
                    my $ifExists = $$nvHash{IsCreating} ? ( $createOnly ?
                                  ($$nvHash{IsCreating} == 2 ?
                                    " if $writeGroup exists and tag doesn't" :
                                    " if tag doesn't exist") :
                                  ($$nvHash{IsCreating} == 2 ? " if $writeGroup exists" : '')) :
                                  (($$nvHash{DelValue} and @{$$nvHash{DelValue}}) ?
                                    ' if tag was deleted' : ' if tag exists');
                    my $verb = ($shift ? 'Shifting' : ($addValue ? 'Adding' : 'Writing'));
                    print $out "$verb $wgrp1:$tag$ifExists\n";
                }
            }
        } elsif ($permanent) {
            $err = "Can't delete Permanent tag $wgrp1:$tag";
            $verbose > 1 and print $out "$err\n";
            next;
        } elsif ($addValue or $options{DelValue}) {
            $verbose > 1 and print $out "Adding/Deleting nothing does nothing\n";
            next;
        } else {
            # create empty new value hash entry to delete this tag
            $self->GetNewValueHash($tagInfo, $writeGroup, 'delete');
            my $nvHash = $self->GetNewValueHash($tagInfo, $writeGroup, 'create');
            $$nvHash{WantGroup} = $wantGroup;
            $verbose > 1 and print $out "Deleting $wgrp1:$tag\n";
        }
        $$setTags{$tagInfo} = 1 if $setTags;
        $prioritySet = 1 if $$pref{$tagInfo};
WriteAlso:
        ++$numSet;
        # also write related tags
        my $writeAlso = $$tagInfo{WriteAlso};
        if ($writeAlso) {
            my ($wgrp, $wtag, $n);
            if ($$tagInfo{WriteGroup} and $$tagInfo{WriteGroup} eq 'All' and $writeGroup) {
                $wgrp = $writeGroup . ':';
            } else {
                $wgrp = '';
            }
            local $SIG{'__WARN__'} = \&SetWarning;
            foreach $wtag (keys %$writeAlso) {
                my %opts = (
                    Type => 'ValueConv',
                    Protected   => $protected | 0x02,
                    AddValue    => $addValue,
                    DelValue    => $options{DelValue},
                    Shift       => $options{Shift},
                    Replace     => $options{Replace},   # handle lists properly
                    CreateGroups=> $createGroups,
                    SetTags     => \%alsoWrote,         # remember tags already written
                );
                undef $evalWarning;
                #### eval WriteAlso ($val)
                my $v = eval $$writeAlso{$wtag};
                $@ and $evalWarning = $@;
                unless ($evalWarning) {
                    ($n,$evalWarning) = $self->SetNewValue($wgrp . $wtag, $v, %opts);
                    $numSet += $n;
                    # count this as being set if any related tag is set
                    $prioritySet = 1 if $n and $$pref{$tagInfo};
                }
                if ($evalWarning and (not $err or $verbose > 2)) {
                    my $str = CleanWarning();
                    if ($str) {
                        $str .= " for $wtag" unless $str =~ / for [-\w:]+$/;
                        $str .= " in $wgrp1:$tag (WriteAlso)";
                        $err or $err = $str;
                        print $out "$str\n" if $verbose > 2;
                    }
                }
            }
        }
    }
    # print warning if we couldn't set our priority tag
    if (defined $err and not $prioritySet) {
        warn "$err\n" if $err and not wantarray;
    } elsif (not $numSet) {
        my $pre = $wantGroup ? $wantGroup . ':' : '';
        if ($wasProtected) {
            $verbose = 0;   # we already printed this verbose message
            unless ($options{Replace} and $options{Replace} == 2) {
                $err = "Sorry, $pre$tag is $wasProtected for writing";
            }
        } elsif (not $listOnly) {
            if ($origTag =~ /[?*]/) {
                if ($noCreate) {
                    $err = "No tags matching 'pre${origTag}' will be created";
                    $verbose = 0;   # (already printed)
                } elsif ($foundMatch) {
                    $err = "Sorry, no writable tags matching '$pre${origTag}'";
                } else {
                    $err = "No matching tags for '$pre${origTag}'";
                }
            } elsif ($noCreate) {
                $err = "Not creating $pre$tag";
                $verbose = 0;   # (already printed)
            } elsif ($foundMatch) {
                $err = "Sorry, $pre$tag is not writable";
            } elsif ($wantGroup and @matchingTags) {
                $err = "Sorry, $pre$tag doesn't exist or isn't writable";
            } else {
                $err = "Tag '$pre${tag}' is not defined";
            }
        }
        if ($err) {
            $verbose > 2 and print $out "$err\n";
            warn "$err\n" unless wantarray;
        }
    } elsif ($$self{CHECK_WARN}) {
        $err = $$self{CHECK_WARN};
        $verbose > 2 and print $out "$err\n";
    } elsif ($err and not $verbose) {
        undef $err;
    }
    return ($numSet, $err) if wantarray;
    return $numSet;
}

#------------------------------------------------------------------------------
# set new values from information in specified file
# Inputs: 0) ExifTool object reference, 1) source file name or reference, etc
#         2-N) List of tags to set (or all if none specified), or reference(s) to
#         hash for options to pass to SetNewValue.  The Replace option defaults
#         to 1 for SetNewValuesFromFile -- set this to 0 to allow multiple tags
#         to be copied to a list
# Returns: Hash of information set successfully (includes Warning or Error messages)
# Notes: Tag names may contain a group prefix, a leading '-' to exclude from copy,
#        and/or a trailing '#' to copy the ValueConv value.  The tag name '*' may
#        be used to represent all tags in a group.  An optional destination tag
#        may be specified with '>DSTTAG' ('DSTTAG<TAG' also works, but in this
#        case the source tag may also be an expression involving tag names).
sub SetNewValuesFromFile($$;@)
{
    local $_;
    my ($self, $srcFile, @setTags) = @_;
    my ($key, $tag, @exclude, @reqTags);

    # get initial SetNewValuesFromFile options
    my %opts = ( Replace => 1 );    # replace existing list items by default
    while (ref $setTags[0] eq 'HASH') {
        $_ = shift @setTags;
        foreach $key (keys %$_) {
            $opts{$key} = $$_{$key};
        }
    }
    # expand shortcuts
    @setTags and ExpandShortcuts(\@setTags);
    my $srcExifTool = new Image::ExifTool;
    # set flag to indicate we are being called from inside SetNewValuesFromFile()
    $$srcExifTool{TAGS_FROM_FILE} = 1;
    # synchronize and increment the file sequence number
    $$srcExifTool{FILE_SEQUENCE} = $$self{FILE_SEQUENCE}++;
    # set options for our extraction tool
    my $options = $$self{OPTIONS};
    # copy both structured and flattened tags by default (but flattened tags are "unsafe")
    my $structOpt = defined $$options{Struct} ? $$options{Struct} : 2;
    # copy structures only if no tags specified (since flattened tags are "unsafe")
    $structOpt = 1 if $structOpt eq '2' and not @setTags;
    # +------------------------------------------+
    # ! DON'T FORGET!!  Must consider each new   !
    # ! option to decide how it is handled here. !
    # +------------------------------------------+
    $srcExifTool->Options(
        Binary          => 1,
        Charset         => $$options{Charset},
        CharsetEXIF     => $$options{CharsetEXIF},
        CharsetFileName => $$options{CharsetFileName},
        CharsetID3      => $$options{CharsetID3},
        CharsetIPTC     => $$options{CharsetIPTC},
        CharsetPhotoshop=> $$options{CharsetPhotoshop},
        Composite       => $$options{Composite},
        CoordFormat     => $$options{CoordFormat} || '%d %d %.8f', # copy coordinates at high resolution unless otherwise specified
        DateFormat      => $$options{DateFormat},
        Duplicates      => 1,
        Escape          => $$options{Escape},
      # Exclude (set below)
        ExtendedXMP     => $$options{ExtendedXMP},
        ExtractEmbedded => $$options{ExtractEmbedded},
        FastScan        => $$options{FastScan},
        Filter          => $$options{Filter},
        FixBase         => $$options{FixBase},
        GlobalTimeShift => $$options{GlobalTimeShift},
        IgnoreMinorErrors=>$$options{IgnoreMinorErrors},
        Lang            => $$options{Lang},
        LargeFileSupport=> $$options{LargeFileSupport},
        List            => 1,
        ListItem        => $$options{ListItem},
        ListSep         => $$options{ListSep},
        MakerNotes      => $$options{FastScan} && $$options{FastScan} > 1 ? undef : 1,
        MDItemTags      => $$options{MDItemTags},
        MissingTagValue => $$options{MissingTagValue},
        NoPDFList       => $$options{NoPDFList},
        Password        => $$options{Password},
        PrintConv       => $$options{PrintConv},
        QuickTimeUTC    => $$options{QuickTimeUTC},
        RequestAll      => $$options{RequestAll} || 1, # (is this still necessary now that RequestTags are being set?)
        RequestTags     => $$options{RequestTags},
        ScanForXMP      => $$options{ScanForXMP},
        StrictDate      => defined $$options{StrictDate} ? $$options{StrictDate} : 1,
        Struct          => $structOpt,
        SystemTags      => $$options{SystemTags},
        TimeZone        => $$options{TimeZone},
        Unknown         => $$options{Unknown},
        UserParam       => $$options{UserParam},
        Validate        => $$options{Validate},
        XAttrTags       => $$options{XAttrTags},
        XMPAutoConv     => $$options{XMPAutoConv},
    );
    $$srcExifTool{GLOBAL_TIME_OFFSET} = $$self{GLOBAL_TIME_OFFSET};
    foreach $tag (@setTags) {
        next if ref $tag;
        if ($tag =~ /^-(.*)/) {
            # avoid extracting tags that are excluded
            push @exclude, $1;
            next;
        }
        # add specified tags to list of requested tags
        $_ = $tag;
        if (/(.+?)\s*(>|<)\s*(.+)/) {
            if ($2 eq '>') {
                $_ = $1;
            } else {
                $_ = $3;
                /\$/ and push(@reqTags, /\$\{?(?:[-\w]+:)*([-\w?*]+)/g), next;
            }
        }
        push @reqTags, $2 if /(^|:)([-\w?*]+)#?$/;
    }
    if (@exclude) {
        ExpandShortcuts(\@exclude, 1);
        $srcExifTool->Options(Exclude => \@exclude);
    }
    $srcExifTool->Options(RequestTags => \@reqTags) if @reqTags;
    my $printConv = $$options{PrintConv};
    if ($opts{Type}) {
        # save source type separately because it may be different than dst Type
        $opts{SrcType} = $opts{Type};
        # override PrintConv option with initial Type if given
        $printConv = ($opts{Type} eq 'PrintConv' ? 1 : 0);
        $srcExifTool->Options(PrintConv => $printConv);
    }
    my $srcType = $printConv ? 'PrintConv' : 'ValueConv';

    # get all tags from source file (including MakerNotes block)
    my $info = $srcExifTool->ImageInfo($srcFile);
    return $info if $$info{Error} and $$info{Error} eq 'Error opening file';
    delete $$srcExifTool{VALUE}{Error}; # delete so we can check this later

    # sort tags in reverse order so we get priority tag last
    my @tags = reverse sort keys %$info;
#
# simply transfer all tags from source image if no tags specified
#
    unless (@setTags) {
        # transfer maker note information to this object
        $$self{MAKER_NOTE_FIXUP} = $$srcExifTool{MAKER_NOTE_FIXUP};
        $$self{MAKER_NOTE_BYTE_ORDER} = $$srcExifTool{MAKER_NOTE_BYTE_ORDER};
        foreach $tag (@tags) {
            # don't try to set errors or warnings
            next if $tag =~ /^(Error|Warning)\b/;
            # get approprite value type if necessary
            if ($opts{SrcType} and $opts{SrcType} ne $srcType) {
                $$info{$tag} = $srcExifTool->GetValue($tag, $opts{SrcType});
            }
            # set value for this tag
            my ($n, $e) = $self->SetNewValue($tag, $$info{$tag}, %opts);
            # delete this tag if we could't set it
            $n or delete $$info{$tag};
        }
        return $info;
    }
#
# transfer specified tags in the proper order
#
    # 1) loop through input list of tags to set, and build @setList
    my (@setList, $set, %setMatches, $t);
    foreach $t (@setTags) {
        if (ref $t eq 'HASH') {
            # update current options
            foreach $key (keys %$t) {
                $opts{$key} = $$t{$key};
            }
            next;
        }
        # make a copy of the current options for this setTag
        # (also use this hash to store expression and wildcard flags, EXPR and WILD)
        my $opts = { %opts };
        $tag = lc $t;   # change tag/group names to all lower case
        my (@fg, $grp, $dst, $dstGrp, $dstTag, $isExclude);
        # handle redirection to another tag
        if ($tag =~ /(.+?)\s*(>|<)\s*(.+)/) {
            $dstGrp = '';
            my $opt;
            if ($2 eq '>') {
                ($tag, $dstTag) = ($1, $3);
                # flag add and delete (eg. '+<' and '-<') redirections
                $opt = $1 if $tag =~ s/\s*([-+])$// or $dstTag =~ s/^([-+])\s*//;
            } else {
                ($tag, $dstTag) = ($3, $1);
                $opt = $1 if $dstTag =~ s/\s*([-+])$//;
                # handle expressions
                if ($tag =~ /\$/) {
                    $tag = $t;  # restore original case
                    # recover leading whitespace (except for initial single space)
                    $tag =~ s/(.+?)\s*(>|<) ?//;
                    $$opts{EXPR} = 1; # flag this expression
                } else {
                    $opt = $1 if $tag =~ s/^([-+])\s*//;
                }
            }
            # validate tag name(s)
            $$opts{EXPR} or ValidTagName($tag) or $self->Warn("Invalid tag name '${tag}'"), next;
            ValidTagName($dstTag) or $self->Warn("Invalid tag name '${dstTag}'"), next;
            # translate '+' and '-' to appropriate SetNewValue option
            if ($opt) {
                $$opts{{ '+' => 'AddValue', '-' => 'DelValue' }->{$opt}} = 1;
                $$opts{Shift} = 0;  # shift if shiftable
            }
            ($dstGrp, $dstTag) = ($1, $2) if $dstTag =~ /(.*):(.+)/;
            # ValueConv may be specified separately on the destination with '#'
            $$opts{Type} = 'ValueConv' if $dstTag =~ s/#$//;
            # replace tag name of 'all' with '*'
            $dstTag = '*' if $dstTag eq 'all';
        }
        unless ($$opts{EXPR}) {
            $isExclude = ($tag =~ s/^-//);
            if ($tag =~ /(.*):(.+)/) {
                ($grp, $tag) = ($1, $2);
                foreach (split /:/, $grp) {
                    # save family/groups in list (ignoring 'all' and '*')
                    next unless length($_) and /^(\d+)?(.*)/;
                    push @fg, [ $1, $2 ] unless $2 eq '*' or $2 eq 'all';
                }
            }
            # allow ValueConv to be specified by a '#' on the tag name
            if ($tag =~ s/#$//) {
                $$opts{SrcType} = 'ValueConv';
                $$opts{Type} = 'ValueConv' unless $dstTag;
            }
            # replace 'all' with '*' in tag and group names
            $tag = '*' if $tag eq 'all';
            # allow wildcards in tag names (handle differently from all tags: '*')
            if ($tag =~ /[?*]/ and $tag ne '*') {
                $$opts{WILD} = 1;   # set flag indicating wildcards were used in source tag
                $tag =~ s/\*/[-\\w]*/g;
                $tag =~ s/\?/[-\\w]/g;
            }
        }
        # redirect, exclude or set this tag (Note: @fg is empty if we don't care about the group)
        if ($dstTag) {
            # redirect this tag
            $isExclude and return { Error => "Can't redirect excluded tag" };
            # set destination group the same as source if necessary
          # (removed in 7.72 so '-*:*<xmp:*' will preserve XMP family 1 groups)
          # $dstGrp = $grp if $dstGrp eq '*' and $grp;
            # write to specified destination group/tag
            $dst = [ $dstGrp, $dstTag ];
        } elsif ($isExclude) {
            # implicitly assume '*' if first entry is an exclusion
            unshift @setList, [ [ ], '*', [ '', '*' ], $opts ] unless @setList;
            # exclude this tag by leaving $dst undefined
        } else {
            $dst = [ $grp || '', $$opts{WILD} ? '*' : $tag ]; # use same group name for dest
        }
        # save in reverse order so we don't set tags before an exclude
        unshift @setList, [ \@fg, $tag, $dst, $opts ];
    }
    # 2) initialize lists of matching tags for each setTag
    foreach $set (@setList) {
        $$set[2] and $setMatches{$set} = [ ];
    }
    # 3) loop through all tags in source image and save tags matching each setTag
    my %rtnInfo;
    foreach $tag (@tags) {
        # don't try to set errors or warnings
        if ($tag =~ /^(Error|Warning)( |$)/) {
            $rtnInfo{$tag} = $$info{$tag};
            next;
        }
        # only set specified tags
        my $lcTag = lc(GetTagName($tag));
        my (@grp, %grp);
SET:    foreach $set (@setList) {
            # check first for matching tag
            unless ($$set[1] eq $lcTag or $$set[1] eq '*') {
                # handle wildcards
                next unless $$set[3]{WILD} and $lcTag =~ /^$$set[1]$/;
            }
            # then check for matching group
            if (@{$$set[0]}) {
                # get lower case group names if not done already
                unless (@grp) {
                    @grp = map(lc, $srcExifTool->GetGroup($tag));
                    $grp{$_} = 1 foreach @grp;
                }
                foreach (@{$$set[0]}) {
                    my ($f, $g) = @$_;
                    if (defined $f) {
                        next SET unless defined $grp[$f] and $g eq $grp[$f];
                    } else {
                        next SET unless $grp{$g};
                    }
                }
            }
            last unless $$set[2];   # all done if we hit an exclude
            # add to the list of tags matching this setTag
            push @{$setMatches{$set}}, $tag;
        }
    }
    # 4) loop through each setTag in original order, setting new tag values
    foreach $set (reverse @setList) {
        # get options for SetNewValue
        my $opts = $$set[3];
        # handle expressions
        if ($$opts{EXPR}) {
            my $val = $srcExifTool->InsertTagValues(\@tags, $$set[1], 'Error');
            if ($$srcExifTool{VALUE}{Error}) {
                # pass on any error as a warning
                $tag = NextFreeTagKey(\%rtnInfo, 'Warning');
                $rtnInfo{$tag} = $$srcExifTool{VALUE}{Error};
                delete $$srcExifTool{VALUE}{Error};
                next unless defined $val;
            }
            my ($dstGrp, $dstTag) = @{$$set[2]};
            $$opts{Protected} = 1 unless $dstTag =~ /[?*]/ and $dstTag ne '*';
            $$opts{Group} = $dstGrp if $dstGrp;
            my @rtnVals = $self->SetNewValue($dstTag, $val, %$opts);
            $rtnInfo{$dstTag} = $val if $rtnVals[0]; # tag was set successfully
            next;
        }
        foreach $tag (@{$setMatches{$set}}) {
            my ($val, $noWarn);
            if ($$opts{SrcType} and $$opts{SrcType} ne $srcType) {
                $val = $srcExifTool->GetValue($tag, $$opts{SrcType});
            } else {
                $val = $$info{$tag};
            }
            my ($dstGrp, $dstTag) = @{$$set[2]};
            if ($dstGrp) {
                my @dstGrp = split /:/, $dstGrp;
                # destination group of '*' writes to same group as source tag
                # (family 1 unless otherwise specified)
                foreach (@dstGrp) {
                    next unless /^(\d*)(all|\*)$/i;
                    $_ = $1 . $srcExifTool->GetGroup($tag, length $1 ? $1 : 1);
                    $noWarn = 1;    # don't warn on wildcard destinations
                }
                $$opts{Group} = join ':', @dstGrp;
            } else {
                delete $$opts{Group};
            }
            # transfer maker note information if setting this tag
            if ($$srcExifTool{TAG_INFO}{$tag}{MakerNotes}) {
                $$self{MAKER_NOTE_FIXUP} = $$srcExifTool{MAKER_NOTE_FIXUP};
                $$self{MAKER_NOTE_BYTE_ORDER} = $$srcExifTool{MAKER_NOTE_BYTE_ORDER};
            }
            if ($dstTag eq '*') {
                $dstTag = $tag;
                $noWarn = 1;
            }
            if ($$set[1] eq '*' or $$set[3]{WILD}) {
                # don't copy from protected binary tags when using wildcards
                next if $$srcExifTool{TAG_INFO}{$tag}{Protected} and
                        $$srcExifTool{TAG_INFO}{$tag}{Binary};
                # don't copy to protected tags when using wildcards
                delete $$opts{Protected};
                # don't copy flattened tags if copying structures too when copying all
                $$opts{NoFlat} = $structOpt eq '2' ? 1 : 0;
            } else {
                # allow protected tags to be copied if specified explicitly
                $$opts{Protected} = 1 unless $dstTag =~ /[?*]/;
                delete $$opts{NoFlat};
            }
            # set value(s) for this tag
            my ($rtn, $wrn) = $self->SetNewValue($dstTag, $val, %$opts);
            # this was added in version 9.14, and allowed actions like "-subject<all" to
            # write values of multiple tags into a list, but it had the side effect of
            # duplicating items if there were multiple list tags with the same name
            # (eg. -use mwg "-creator<creator"), so disable this as of ExifTool 9.36:
            # $$opts{Replace} = 0;    # accumulate values from tags matching a single argument
            if ($wrn and not $noWarn) {
                # return this warning
                $rtnInfo{NextFreeTagKey(\%rtnInfo, 'Warning')} = $wrn;
                $noWarn = 1;
            }
            $rtnInfo{$tag} = $val if $rtn;  # tag was set successfully
        }
    }
    return \%rtnInfo;   # return information that we set
}

#------------------------------------------------------------------------------
# Get new value(s) for tag
# Inputs: 0) ExifTool object reference, 1) tag name or tagInfo hash ref
#         2) optional pointer to return new value hash reference (not part of public API)
#    or   0) ExifTool ref, 1) new value hash reference (not part of public API)
# Returns: List of new Raw values (list may be empty if tag is being deleted)
# Notes: 1) Preferentially returns new value from Extra table if writable Extra tag exists
# 2) Must call AFTER IsOverwriting() returns 1 to get proper value for shifted times
# 3) Tag name is case sensitive and may be prefixed by family 0 or 1 group name
# 4) Value may have been modified by CHECK_PROC routine after ValueConv
sub GetNewValue($$;$)
{
    local $_;
    my $self = shift;
    my $tag = shift;
    my $nvHash;
    if ((ref $tag eq 'HASH' and $$tag{IsNVH}) or not defined $tag) {
        $nvHash = $tag;
    } else {
        my $newValueHashPt = shift;
        if ($$self{NEW_VALUE}) {
            my ($group, $tagInfo);
            if (ref $tag) {
                $nvHash = $self->GetNewValueHash($tag);
            } elsif (defined($tagInfo = $Image::ExifTool::Extra{$tag}) and
                     $$tagInfo{Writable})
            {
                $nvHash = $self->GetNewValueHash($tagInfo);
            } else {
                # separate group from tag name
                $group = $1 if $tag =~ s/(.*)://;
                my @tagInfoList = FindTagInfo($tag);
                # decide which tag we want
GNV_TagInfo:    foreach $tagInfo (@tagInfoList) {
                    my $nvh = $self->GetNewValueHash($tagInfo) or next;
                    # select tag in specified group if necessary
                    while ($group and $group ne $$nvh{WriteGroup}) {
                        my @grps = $self->GetGroup($tagInfo);
                        if ($grps[0] eq $$nvh{WriteGroup}) {
                            # check family 1 group only if WriteGroup is not specific
                            last if $group eq $grps[1];
                        } else {
                            # otherwise check family 0 group
                            last if $group eq $grps[0];
                        }
                        # step to next entry in list
                        $nvh = $$nvh{Next} or next GNV_TagInfo;
                    }
                    $nvHash = $nvh;
                    # give priority to the one we are creating
                    last if defined $$nvHash{IsCreating};
                }
            }
        }
        # return new value hash if requested
        $newValueHashPt and $$newValueHashPt = $nvHash;
    }
    unless ($nvHash and $$nvHash{Value}) {
        return () if wantarray;  # return empty list
        return undef;
    }
    my $vals = $$nvHash{Value};
    # do inverse raw conversion if necessary
    # - must also check after doing a Shift
    if ($$nvHash{TagInfo}{RawConvInv} or $$nvHash{Shift}) {
        my @copyVals = @$vals;  # modify a copy of the values
        $vals = \@copyVals;
        my $tagInfo = $$nvHash{TagInfo};
        my $conv = $$tagInfo{RawConvInv};
        my $table = $$tagInfo{Table};
        my ($val, $checkProc);
        $checkProc = $$table{CHECK_PROC} if $$nvHash{Shift} and $table;
        local $SIG{'__WARN__'} = \&SetWarning;
        undef $evalWarning;
        foreach $val (@$vals) {
            # must check value now if it was shifted
            if ($checkProc) {
                my $err = &$checkProc($self, $tagInfo, \$val);
                if ($err or not defined $val) {
                    $err or $err = 'Error generating raw value';
                    $self->WarnOnce("$err for $$tagInfo{Name}");
                    @$vals = ();
                    last;
                }
                next unless $conv;
            } else {
                last unless $conv;
            }
            # do inverse raw conversion
            if (ref($conv) eq 'CODE') {
                $val = &$conv($val, $self);
            } else {
                #### eval RawConvInv ($self, $val, $tagInfo)
                $val = eval $conv;
                $@ and $evalWarning = $@;
            }
            if ($evalWarning) {
                # an empty warning ("\n") ignores tag with no error
                if ($evalWarning ne "\n") {
                    my $err = CleanWarning() . " in $$tagInfo{Name} (RawConvInv)";
                    $self->WarnOnce($err);
                }
                @$vals = ();
                last;
            }
        }
    }
    # return our value(s)
    return @$vals if wantarray;
    return $$vals[0];
}

#------------------------------------------------------------------------------
# Return the total number of new values set
# Inputs: 0) ExifTool object reference
# Returns: Scalar context) Number of new values that have been set (incl pseudo)
#          List context) Number of new values (incl pseudo), number of "pseudo" values
# ("pseudo" values are those which don't require rewriting the file to change)
sub CountNewValues($)
{
    my $self = shift;
    my $newVal = $$self{NEW_VALUE};
    my ($num, $pseudo) = (0, 0);
    if ($newVal) {
        $num = scalar keys %$newVal;
        my $nv;
        foreach $nv (values %$newVal) {
            my $tagInfo = $$nv{TagInfo};
            # don't count tags that don't write anything
            $$tagInfo{WriteNothing} and --$num, next;
            # count the number of pseudo tags included
            $$tagInfo{WritePseudo} and ++$pseudo;
        }
    }
    $num += scalar keys %{$$self{DEL_GROUP}};
    return $num unless wantarray;
    return ($num, $pseudo);
}

#------------------------------------------------------------------------------
# Save new values for subsequent restore
# Inputs: 0) ExifTool object reference
# Returns: Number of times new values have been saved
# Notes: increments SAVE_COUNT flag each time routine is called
sub SaveNewValues($)
{
    my $self = shift;
    my $newValues = $$self{NEW_VALUE};
    my $saveCount = ++$$self{SAVE_COUNT};
    my $key;
    foreach $key (keys %$newValues) {
        my $nvHash = $$newValues{$key};
        while ($nvHash) {
            # set Save count if not done already
            $$nvHash{Save} or $$nvHash{Save} = $saveCount;
            $nvHash = $$nvHash{Next};
        }
    }
    # initialize hash for saving overwritten new values
    $$self{SAVE_NEW_VALUE} = { };
    # make a copy of the delete group hash
    my %delGrp = %{$$self{DEL_GROUP}};
    $$self{SAVE_DEL_GROUP} = \%delGrp;
    return $saveCount;
}

#------------------------------------------------------------------------------
# Restore new values to last saved state
# Inputs: 0) ExifTool object reference
# Notes: Restores saved new values, but currently doesn't restore them in the
# original order, so there may be some minor side-effects when restoring tags
# with overlapping groups. eg) XMP:Identifier, XMP-dc:Identifier
sub RestoreNewValues($)
{
    my $self = shift;
    my $newValues = $$self{NEW_VALUE};
    my $savedValues = $$self{SAVE_NEW_VALUE};
    my $key;
    # 1) remove any new values which don't have the Save flag set
    if ($newValues) {
        my @keys = keys %$newValues;
        foreach $key (@keys) {
            my $lastHash;
            my $nvHash = $$newValues{$key};
            while ($nvHash) {
                if ($$nvHash{Save}) {
                    $lastHash = $nvHash;
                } else {
                    # remove this entry from the list
                    if ($lastHash) {
                        $$lastHash{Next} = $$nvHash{Next};
                    } elsif ($$nvHash{Next}) {
                        $$newValues{$key} = $$nvHash{Next};
                    } else {
                        delete $$newValues{$key};
                    }
                }
                $nvHash = $$nvHash{Next};
            }
        }
    }
    # 2) restore saved new values
    if ($savedValues) {
        $newValues or $newValues = $$self{NEW_VALUE} = { };
        foreach $key (keys %$savedValues) {
            if ($$newValues{$key}) {
                # add saved values to end of list
                my $nvHash = LastInList($$newValues{$key});
                $$nvHash{Next} = $$savedValues{$key};
            } else {
                $$newValues{$key} = $$savedValues{$key};
            }
        }
        $$self{SAVE_NEW_VALUE} = { };  # reset saved new values
    }
    # 3) restore delete groups
    my %delGrp = %{$$self{SAVE_DEL_GROUP}};
    $$self{DEL_GROUP} = \%delGrp;
}

#------------------------------------------------------------------------------
# Set filesystem time from from FileModifyDate or FileCreateDate tag
# Inputs: 0) ExifTool object reference, 1) file name or file ref
#         2) time (-M or -C) of original file (used for shift; obtained from file if not given)
#         3) tag name to write (undef for 'FileModifyDate')
#         4) flag set if argument 2 has already been converted to Unix seconds
# Returns: 1=time changed OK, 0=nothing done, -1=error setting time
#          (increments CHANGED flag and sets corresponding WRITTEN tag)
sub SetFileModifyDate($$;$$$)
{
    my ($self, $file, $originalTime, $tag, $isUnixTime) = @_;
    my $nvHash;
    $tag = 'FileModifyDate' unless defined $tag;
    my $val = $self->GetNewValue($tag, \$nvHash);
    return 0 unless defined $val;
    my $isOverwriting = $self->IsOverwriting($nvHash);
    return 0 unless $isOverwriting;
    # can currently only set creation date on Windows systems
    # (and Mac now too, but that is handled with the MacOS tags)
    return 0 if $tag eq 'FileCreateDate' and $^O ne 'MSWin32';
    if ($isOverwriting < 0) {  # are we shifting time?
        # use original time of this file if not specified
        unless (defined $originalTime) {
            my ($aTime, $mTime, $cTime) = $self->GetFileTime($file);
            $originalTime = ($tag eq 'FileCreateDate') ? $cTime : $mTime;
            return 0 unless defined $originalTime;
            $isUnixTime = 1;
        }
        $originalTime = int($^T - $originalTime*(24*3600) + 0.5) unless $isUnixTime;
        return 0 unless $self->IsOverwriting($nvHash, $originalTime);
        $val = $$nvHash{Value}[0]; # get shifted value
    }
    my ($aTime, $mTime, $cTime);
    if ($tag eq 'FileCreateDate') {
        eval { require Win32::API } or $self->WarnOnce("Install Win32::API to set $tag"), return -1;
        eval { require Win32API::File } or $self->WarnOnce("Install Win32API::File to set $tag"), return -1;
        $cTime = $val;
    } else {
        $aTime = $mTime = $val;
    }
    $self->SetFileTime($file, $aTime, $mTime, $cTime, 1) or $self->Warn("Error setting $tag"), return -1;
    ++$$self{CHANGED};
    $$self{WRITTEN}{$tag} = $val;   # remember that we wrote this tag
    $self->VerboseValue("+ $tag", $val);
    return 1;
}

#------------------------------------------------------------------------------
# Change file name and/or directory from FileName and Directory tags
# Inputs: 0) ExifTool object reference, 1) current file name (including path)
#         2) new name (or undef to build from FileName and Directory tags)
#         3) option: 'Link' to create link instead of renaming file
#                    'Test' to only print new file name
#         4) 0 to indicate that a file will no longer exist (used for 'Test' only)
# Returns: 1=name changed OK, 0=nothing changed, -1=error changing name
#          (and increments CHANGED flag if filename changed)
# Notes: Will not overwrite existing file.  Creates directories as necessary.
sub SetFileName($$;$$$)
{
    my ($self, $file, $newName, $opt, $usedFlag) = @_;
    my ($nvHash, $doName, $doDir);

    $opt or $opt = '';
    # determine the new file name
    unless (defined $newName) {
        if ($opt) {
            if ($opt eq 'Link') {
                $newName = $self->GetNewValue('HardLink');
            } elsif ($opt eq 'Test') {
                $newName = $self->GetNewValue('TestName');
            }
            return 0 unless defined $newName;
        } else {
            my $filename = $self->GetNewValue('FileName', \$nvHash);
            $doName = 1 if defined $filename and $self->IsOverwriting($nvHash, $file);
            my $dir = $self->GetNewValue('Directory', \$nvHash);
            $doDir = 1 if defined $dir and $self->IsOverwriting($nvHash, $file);
            return 0 unless $doName or $doDir;  # nothing to do
            if ($doName) {
                $newName = GetNewFileName($file, $filename);
                $newName = GetNewFileName($newName, $dir) if $doDir;
            } else {
                $newName = GetNewFileName($file, $dir);
            }
        }
    }
    # validate new file name in Windows
    if ($^O eq 'MSWin32') {
        if ($newName =~ /[\0-\x1f<>"|*]/) {
            $self->Warn('New file name not allowed in Windows (contains reserved characters)');
            return -1;
        }
        if ($newName =~ /:/ and $newName !~ /^[A-Z]:[^:]*$/i) {
            $self->Warn("New file name not allowed in Windows (contains ':')");
            return -1;
        }
        if ($newName =~ /\?/ and $newName !~ m{^[\\/]{2}\?[\\/][^?]*$}) {
            $self->Warn("New file name not allowed in Windows (contains '?')");
            return -1;
        }
        if ($newName =~ m{(^|[\\/])(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.[^.]*)?$}i) {
            $self->Warn('New file name not allowed in Windows (reserved device name)');
            return -1;
        }
        if ($newName =~ /([. ])$/) {
            $self->Warn("New file name not recommended for Windows (ends with '${1}')", 2) and return -1;
        }
        if (length $newName > 259 and $newName !~ /\?/) {
            $self->Warn('New file name not recommended for Windows (exceeds 260 chars)', 2) and return -1;
        }
    } else {
        $newName =~ tr/\0//d;   # make sure name doesn't contain nulls
    }
    # protect against empty file name
    length $newName or $self->Warn('New file name is empty'), return -1;
    # don't replace existing file
    if ($self->Exists($newName) and (not defined $usedFlag or $usedFlag)) {
        if ($file ne $newName or $opt eq 'Link') {
            $self->Warn("File '${newName}' already exists");
            return -1;
        } else {
            $self->Warn('File name is unchanged');
            return 0;
        }
    }
    if ($opt eq 'Test') {
        my $out = $$self{OPTIONS}{TextOut};
        print $out "'${file}' --> '${newName}'\n";
        return 1;
    }
    # create directory for new file if necessary
    my $result;
    if (($result = $self->CreateDirectory($newName)) != 0) {
        if ($result < 0) {
            $self->Warn("Error creating directory for '${newName}'");
            return -1;
        }
        $self->VPrint(0, "Created directory for '${newName}'");
    }
    if ($opt eq 'Link') {
        unless (link $file, $newName) {
            $self->Warn("Error creating link '${newName}'");
            return -1;
        }
        ++$$self{CHANGED};
        $self->VerboseValue('+ HardLink', $newName);
        return 1;
    }
    # attempt to rename the file
    unless ($self->Rename($file, $newName)) {
        local (*EXIFTOOL_SFN_IN, *EXIFTOOL_SFN_OUT);
        # renaming didn't work, so copy the file instead
        unless ($self->Open(\*EXIFTOOL_SFN_IN, $file)) {
            $self->Warn("Error opening '${file}'");
            return -1;
        }
        unless ($self->Open(\*EXIFTOOL_SFN_OUT, $newName, '>')) {
            close EXIFTOOL_SFN_IN;
            $self->Warn("Error creating '${newName}'");
            return -1;
        }
        binmode EXIFTOOL_SFN_IN;
        binmode EXIFTOOL_SFN_OUT;
        my ($buff, $err);
        while (read EXIFTOOL_SFN_IN, $buff, 65536) {
            print EXIFTOOL_SFN_OUT $buff or $err = 1;
        }
        close EXIFTOOL_SFN_OUT or $err = 1;
        close EXIFTOOL_SFN_IN;
        if ($err) {
            $self->Unlink($newName);    # erase bad output file
            $self->Warn("Error writing '${newName}'");
            return -1;
        }
        # preserve modification time
        my ($aTime, $mTime, $cTime) = $self->GetFileTime($file);
        $self->SetFileTime($newName, $aTime, $mTime, $cTime);
        # remove the original file
        $self->Unlink($file) or $self->Warn('Error removing old file');
    }
    $$self{NewName} = $newName; # remember new file name
    ++$$self{CHANGED};
    $self->VerboseValue('+ FileName', $newName);
    return 1;
}

#------------------------------------------------------------------------------
# Set file permissions, group/user id and various MDItem tags from new tag values
# Inputs: 0) Exiftool ref, 1) file name or glob (must be a name for MDItem tags)
# Returns: 1=something was set OK, 0=didn't try, -1=error (and warning set)
# Notes: There may be errors even if 1 is returned
sub SetSystemTags($$)
{
    my ($self, $file) = @_;
    my $result = 0;

    my $perm = $self->GetNewValue('FilePermissions');
    if (defined $perm) {
        if (eval { chmod($perm & 07777, $file) }) {
            $self->VerboseValue('+ FilePermissions', $perm);
            $result = 1;
        } else {
            $self->WarnOnce('Error setting FilePermissions');
            $result = -1;
        }
    }
    my $uid = $self->GetNewValue('FileUserID');
    my $gid = $self->GetNewValue('FileGroupID');
    if (defined $uid or defined $gid) {
        defined $uid or $uid = -1;
        defined $gid or $gid = -1;
        if (eval { chown($uid, $gid, $file) }) {
            $self->VerboseValue('+ FileUserID', $uid) if $uid >= 0;
            $self->VerboseValue('+ FileGroupID', $gid) if $gid >= 0;
            $result = 1;
        } else {
            $self->WarnOnce('Error setting FileGroup/UserID');
            $result = -1 unless $result;
        }
    }
    my $tag;
    foreach $tag (@writableMacOSTags) {
        my $nvHash;
        my $val = $self->GetNewValue($tag, \$nvHash);
        next unless $nvHash;
        if ($^O eq 'darwin') {
            ref $file and $self->Warn('Setting MDItem tags requires a file name'), last;
            require Image::ExifTool::MacOS;
            my $res = Image::ExifTool::MacOS::SetMacOSTags($self, $file, \@writableMacOSTags);
            $result = $res if $res == 1 or not $result;
            last;
        } elsif ($tag ne 'FileCreateDate') {
            $self->WarnOnce('Can only set MDItem tags on OS X');
            last;
        }
    }
    return $result;
}

#------------------------------------------------------------------------------
# Write information back to file
# Inputs: 0) ExifTool object reference,
#         1) input filename, file ref, RAF ref, or scalar ref (or '' or undef to create from scratch)
#         2) output filename, file ref, or scalar ref (or undef to overwrite)
#         3) optional output file type (required only if input file is not specified
#            and output file is a reference)
# Returns: 1=file written OK, 2=file written but no changes made, 0=file write error
sub WriteInfo($$;$$)
{
    local ($_, *EXIFTOOL_FILE2, *EXIFTOOL_OUTFILE);
    my ($self, $infile, $outfile, $outType) = @_;
    my (@fileTypeList, $fileType, $tiffType, $hdr, $seekErr, $type, $tmpfile, $hardLink, $testName);
    my ($inRef, $outRef, $closeIn, $closeOut, $outPos, $outBuff, $eraseIn, $raf, $fileExt);
    my $oldRaf = $$self{RAF};
    my $rtnVal = 0;

    # initialize member variables
    $self->Init();

    # first, save original file modify date if necessary
    # (do this now in case we are modifying file in place and shifting date)
    my ($nvHash, $nvHash2, $originalTime, $createTime);
    my $setModDate = defined $self->GetNewValue('FileModifyDate', \$nvHash);
    my $setCreateDate = defined $self->GetNewValue('FileCreateDate', \$nvHash2);
    my ($aTime, $mTime, $cTime);
    if ($setModDate and $self->IsOverwriting($nvHash) < 0 and
        defined $infile and ref $infile ne 'SCALAR')
    {
        ($aTime, $mTime, $cTime) = $self->GetFileTime($infile);
        $originalTime = $mTime;
    }
    if ($setCreateDate and $self->IsOverwriting($nvHash2) < 0 and
        defined $infile and ref $infile ne 'SCALAR')
    {
        ($aTime, $mTime, $cTime) = $self->GetFileTime($infile) unless defined $cTime;
        $createTime = $cTime;
    }
#
# do quick in-place change of file dir/name or date if that is all we are doing
#
    my ($numNew, $numPseudo) = $self->CountNewValues();
    if (not defined $outfile and defined $infile) {
        $hardLink = $self->GetNewValue('HardLink');
        $testName = $self->GetNewValue('TestName');
        undef $hardLink if defined $hardLink and not length $hardLink;
        undef $testName if defined $testName and not length $testName;
        my $newFileName =  $self->GetNewValue('FileName', \$nvHash);
        my $newDir = $self->GetNewValue('Directory');
        if (defined $newDir and length $newDir) {
            $newDir .= '/' unless $newDir =~ m{/$};
        } else {
            undef $newDir;
        }
        if ($numNew == $numPseudo) {
            $rtnVal = 2;
            if (not ref $infile or UNIVERSAL::isa($infile,'GLOB')) {
                $self->SetFileModifyDate($infile) > 0 and $rtnVal = 1 if $setModDate;
                $self->SetFileModifyDate($infile, undef, 'FileCreateDate') > 0 and $rtnVal = 1 if $setCreateDate;
                $self->SetSystemTags($infile) > 0 and $rtnVal = 1;
            }
            if ((defined $newFileName or defined $newDir) and not ref $infile) {
                $self->SetFileName($infile) > 0 and $rtnVal = 1;
            }
            if (defined $hardLink or defined $testName) {
                my $src = $$self{NewName};
                $src = $infile unless defined $src;
                $hardLink and $self->SetFileName($src, $hardLink, 'Link') and $rtnVal = 1;
                $testName and $self->SetFileName($src, $testName, 'Test') and $rtnVal = 1;
            }
            return $rtnVal;
        } elsif (defined $newFileName and length $newFileName) {
            # can't simply rename file, so just set the output name if new FileName
            # --> in this case, must erase original copy
            if (ref $infile) {
                $outfile = $newFileName;
                # can't delete original
            } elsif ($self->IsOverwriting($nvHash, $infile)) {
                $outfile = GetNewFileName($infile, $newFileName);
                $eraseIn = 1; # delete original
            }
        }
        # set new directory if specified
        if (defined $newDir) {
            $outfile = $infile unless defined $outfile or ref $infile;
            if (defined $outfile) {
                $outfile = GetNewFileName($outfile, $newDir);
                $eraseIn = 1 unless ref $infile;
            }
        }
    }
#
# set up input file
#
    if (ref $infile) {
        $inRef = $infile;
        if (UNIVERSAL::isa($inRef,'GLOB')) {
            seek($inRef, 0, 0); # make sure we are at the start of the file
        } elsif (UNIVERSAL::isa($inRef,'File::RandomAccess')) {
            $inRef->Seek(0);
            $raf = $inRef;
        } elsif ($] >= 5.006 and (eval { require Encode; Encode::is_utf8($$inRef) } or $@)) {
            # convert image data from UTF-8 to character stream if necessary
            my $buff = $@ ? pack('C*',unpack($] < 5.010000 ? 'U0C*' : 'C0C*',$$inRef)) : Encode::encode('utf8',$$inRef);
            if (defined $outfile) {
                $inRef = \$buff;
            } else {
                $$inRef = $buff;
            }
        }
    } elsif (defined $infile and $infile ne '') {
        # write to a temporary file if no output file given
        $outfile = $tmpfile = "${infile}_exiftool_tmp" unless defined $outfile;
        if ($self->Open(\*EXIFTOOL_FILE2, $infile)) {
            $fileExt = GetFileExtension($infile);
            $fileType = GetFileType($infile);
            @fileTypeList = GetFileType($infile);
            $tiffType = $$self{FILE_EXT} = GetFileExtension($infile);
            $self->VPrint(0, "Rewriting $infile...\n");
            $inRef = \*EXIFTOOL_FILE2;
            $closeIn = 1;   # we must close the file since we opened it
        } else {
            $self->Error('Error opening file');
            return 0;
        }
    } elsif (not defined $outfile) {
        $self->Error("WriteInfo(): Must specify infile or outfile\n");
        return 0;
    } else {
        # create file from scratch
        $outType = GetFileExtension($outfile) unless $outType or ref $outfile;
        if (CanCreate($outType)) {
            if ($$self{OPTIONS}{WriteMode} =~ /g/i) {
                $fileType = $tiffType = $outType;   # use output file type if no input file
                $infile = "$fileType file";         # make bogus file name
                $self->VPrint(0, "Creating $infile...\n");
                $inRef = \ '';      # set $inRef to reference to empty data
            } else {
                $self->Error("Not creating new $outType file (disallowed by WriteMode)");
                return 0;
            }
        } elsif ($outType) {
            $self->Error("Can't create $outType files");
            return 0;
        } else {
            $self->Error("Can't create file (unknown type)");
            return 0;
        }
    }
    unless (@fileTypeList) {
        if ($fileType) {
            @fileTypeList = ( $fileType );
        } else {
            @fileTypeList = @fileTypes;
            $tiffType = 'TIFF';
        }
    }
#
# set up output file
#
    if (ref $outfile) {
        $outRef = $outfile;
        if (UNIVERSAL::isa($outRef,'GLOB')) {
            binmode($outRef);
            $outPos = tell($outRef);
        } else {
            # initialize our output buffer if necessary
            defined $$outRef or $$outRef = '';
            $outPos = length($$outRef);
        }
    } elsif (not defined $outfile) {
        # editing in place, so write to memory first
        # (only when infile is a file ref or scalar ref)
        if ($raf) {
            $self->Error("Can't edit File::RandomAccess object in place");
            return 0;
        }
        $outBuff = '';
        $outRef = \$outBuff;
        $outPos = 0;
    } elsif ($self->Exists($outfile)) {
        $self->Error("File already exists: $outfile");
    } elsif ($self->Open(\*EXIFTOOL_OUTFILE, $outfile, '>')) {
        $outRef = \*EXIFTOOL_OUTFILE;
        $closeOut = 1;  # we must close $outRef
        binmode($outRef);
        $outPos = 0;
    } else {
        my $tmp = $tmpfile ? ' temporary' : '';
        $self->Error("Error creating$tmp file: $outfile");
    }
#
# write the file
#
    until ($$self{VALUE}{Error}) {
        # create random access file object (disable seek test in case of straight copy)
        $raf or $raf = new File::RandomAccess($inRef, 1);
        $raf->BinMode();
        if ($numNew == $numPseudo) {
            $rtnVal = 1;
            # just do a straight copy of the file (no "real" tags are being changed)
            my $buff;
            while ($raf->Read($buff, 65536)) {
                Write($outRef, $buff) or $rtnVal = -1, last;
            }
            last;
        } elsif (not ref $infile and ($infile eq '-' or $infile =~ /\|$/)) {
            # patch for Windows command shell pipe
            $$raf{TESTED} = -1; # force buffering
        } else {
            $raf->SeekTest();
        }
       # $raf->Debug() and warn "  RAF debugging enabled!\n";
        my $inPos = $raf->Tell();
        $$self{RAF} = $raf;
        my %dirInfo = (
            RAF => $raf,
            OutFile => $outRef,
        );
        $raf->Read($hdr, 1024) or $hdr = '';
        $raf->Seek($inPos, 0) or $seekErr = 1;
        my $wrongType;
        until ($seekErr) {
            $type = shift @fileTypeList;
            # do quick test to see if this is the right file type
            if ($magicNumber{$type} and length($hdr) and $hdr !~ /^$magicNumber{$type}/s) {
                next if @fileTypeList;
                $wrongType = 1;
                last;
            }
            # save file type in member variable
            $dirInfo{Parent} = $$self{FILE_TYPE} = $$self{PATH}[0] = $type;
            # determine which directories we must write for this file type
            $self->InitWriteDirs($type);
            if ($type eq 'JPEG' or $type eq 'EXV') {
                $rtnVal = $self->WriteJPEG(\%dirInfo);
            } elsif ($type eq 'TIFF') {
                # disallow writing of some TIFF-based RAW images:
                if (grep /^$tiffType$/, @{$noWriteFile{TIFF}}) {
                    $fileType = $tiffType;
                    undef $rtnVal;
                } else {
                    $dirInfo{Parent} = $tiffType;
                    $rtnVal = $self->ProcessTIFF(\%dirInfo);
                }
            } elsif (exists $writableType{$type}) {
                my ($module, $func);
                if (ref $writableType{$type} eq 'ARRAY') {
                    $module = $writableType{$type}[0] || $type;
                    $func = $writableType{$type}[1];
                } else {
                    $module = $writableType{$type} || $type;
                }
                require "Image/ExifTool/$module.pm";
                $func = "Image::ExifTool::${module}::" . ($func || "Process$type");
                no strict 'refs';
                $rtnVal = &$func($self, \%dirInfo);
                use strict 'refs';
            } elsif ($type eq 'ORF' or $type eq 'RAW') {
                $rtnVal = $self->ProcessTIFF(\%dirInfo);
            } elsif ($type eq 'EXIF') {
                # go through WriteDirectory so block writes, etc are handled
                my $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');
                my $buff = $self->WriteDirectory(\%dirInfo, $tagTablePtr, \&WriteTIFF);
                if (defined $buff) {
                    $rtnVal = Write($outRef, $buff) ? 1 : -1;
                } else {
                    $rtnVal = 0;
                }
            } else {
                undef $rtnVal;  # flag that we don't write this type of file
            }
            # all done unless we got the wrong type
            last if $rtnVal;
            last unless @fileTypeList;
            # seek back to original position in files for next try
            $raf->Seek($inPos, 0) or $seekErr = 1, last;
            if (UNIVERSAL::isa($outRef,'GLOB')) {
                seek($outRef, 0, $outPos);
            } else {
                $$outRef = substr($$outRef, 0, $outPos);
            }
        }
        # print file format errors
        unless ($rtnVal) {
            my $err;
            if ($seekErr) {
                $err = 'Error seeking in file';
            } elsif ($fileType and defined $rtnVal) {
                if ($$self{VALUE}{Error}) {
                    # existing error message will do
                } elsif ($fileType eq 'RAW') {
                    $err = 'Writing this type of RAW file is not supported';
                } else {
                    if ($wrongType) {
                        my $type = $fileExt || ($fileType eq 'TIFF' ? $tiffType : $fileType);
                        $err = "Not a valid $type";
                        # do a quick check to see what this file looks like
                        foreach $type (@fileTypes) {
                            next unless $magicNumber{$type};
                            next unless $hdr =~ /^$magicNumber{$type}/s;
                            $err .= " (looks more like a $type)";
                            last;
                        }
                    } else {
                        $err = 'Format error in file';
                    }
                }
            } elsif ($fileType) {
                # get specific type of file from extension
                $fileType = GetFileExtension($infile) if $infile and GetFileType($infile);
                $err = "Writing of $fileType files is not yet supported";
            } else {
                $err = 'Writing of this type of file is not supported';
            }
            $self->Error($err) if $err;
            $rtnVal = 0;    # (in case it was undef)
        }
       # $raf->Close();  # only used to force debug output
        last;   # (didn't really want to loop)
    }
    # don't return success code if any error occurred
    if ($rtnVal > 0) {
        if ($outType and $type and $outType ne $type) {
            my @types = GetFileType($outType);
            unless (grep /^$type$/, @types) {
                $self->Error("Can't create $outType file from $type");
                $rtnVal = 0;
            }
        }
        if ($rtnVal > 0 and not Tell($outRef) and not $$self{VALUE}{Error}) {
            # don't write a file with zero length
            if (defined $hdr and length $hdr) {
                $type = '<unk>' unless defined $type;
                $self->Error("Can't delete all meta information from $type file");
            } else {
                $self->Error('Nothing to write');
            }
        }
        $rtnVal = 0 if $$self{VALUE}{Error};
    }

    # rewrite original file in place if required
    if (defined $outBuff) {
        if ($rtnVal <= 0 or not $$self{CHANGED}) {
            # nothing changed, so no need to write $outBuff
        } elsif (UNIVERSAL::isa($inRef,'GLOB')) {
            my $len = length($outBuff);
            my $size;
            $rtnVal = -1 unless
                seek($inRef, 0, 2) and          # seek to the end of file
                ($size = tell $inRef) >= 0 and  # get the file size
                seek($inRef, 0, 0) and          # seek back to the start
                print $inRef $outBuff and       # write the new data
                ($len >= $size or               # if necessary:
                eval { truncate($inRef, $len) }); #  shorten output file
        } else {
            $$inRef = $outBuff;                 # replace original data
        }
        $outBuff = '';  # free memory but leave $outBuff defined
    }
    # close input file if we opened it
    if ($closeIn) {
        # errors on input file are significant if we edited the file in place
        $rtnVal and $rtnVal = -1 unless close($inRef) or not defined $outBuff;
        if ($rtnVal > 0) {
            # copy Mac OS resource fork if it exists
            if ($^O eq 'darwin' and -s "$infile/..namedfork/rsrc") {
                if ($$self{DEL_GROUP}{RSRC}) {
                    $self->VPrint(0,"Deleting Mac OS resource fork\n");
                    ++$$self{CHANGED};
                } else {
                    $self->VPrint(0,"Copying Mac OS resource fork\n");
                    my ($buf, $err);
                    local (*SRC, *DST);
                    if ($self->Open(\*SRC, "$infile/..namedfork/rsrc")) {
                        if ($self->Open(\*DST, "$outfile/..namedfork/rsrc", '>')) {
                            binmode SRC; # (not necessary for Darwin, but let's be thorough)
                            binmode DST;
                            while (read SRC, $buf, 65536) {
                                print DST $buf or $err = 'copying', last;
                            }
                            close DST or $err or $err = 'closing';
                        } else {
                            # (this is normal if the destination filesystem isn't Mac OS)
                            $self->Warn('Error creating Mac OS resource fork');
                        }
                        close SRC;
                    } else {
                        $err = 'opening';
                    }
                    $rtnVal = 0 if $err and $self->Error("Error $err Mac OS resource fork", 2);
                }
            }
            # erase input file if renaming while editing information in place
            $self->Unlink($infile) or $self->Warn('Error erasing original file') if $eraseIn;
        }
    }
    # close output file if we created it
    if ($closeOut) {
        # close file and set $rtnVal to -1 if there was an error
        $rtnVal and $rtnVal = -1 unless close($outRef);
        # erase the output file if we weren't successful
        if ($rtnVal <= 0) {
            $self->Unlink($outfile);
        # else rename temporary file if necessary
        } elsif ($tmpfile) {
            $self->CopyFileAttrs($infile, $tmpfile);    # copy attributes to new file
            unless ($self->Rename($tmpfile, $infile)) {
                # some filesystems won't overwrite with 'rename', so try erasing original
                if (not $self->Unlink($infile)) {
                    $self->Unlink($tmpfile);
                    $self->Error('Error renaming temporary file');
                    $rtnVal = 0;
                } elsif (not $self->Rename($tmpfile, $infile)) {
                    $self->Error('Error renaming temporary file after deleting original');
                    $rtnVal = 0;
                }
            }
            # the output file should now have the name of the original infile
            $outfile = $infile if $rtnVal > 0;
        }
    }
    # set filesystem attributes if requested (and if possible!)
    if ($rtnVal > 0 and ($closeOut or (defined $outBuff and ($closeIn or UNIVERSAL::isa($infile,'GLOB'))))) {
        my $target = $closeOut ? $outfile : $infile;
        # set file permissions if requested
        ++$$self{CHANGED} if $self->SetSystemTags($target) > 0;
        if ($closeIn) { # (no use setting file times unless the input file is closed)
            ++$$self{CHANGED} if $setModDate and $self->SetFileModifyDate($target, $originalTime, undef, 1) > 0;
            # set FileCreateDate if requested (and if possible!)
            ++$$self{CHANGED} if $setCreateDate and $self->SetFileModifyDate($target, $createTime, 'FileCreateDate', 1) > 0;
            # create hard link if requested and no output filename specified (and if possible!)
            ++$$self{CHANGED} if defined $hardLink and $self->SetFileName($target, $hardLink, 'Link');
            defined $testName and $self->SetFileName($target, $testName, 'Test');
        }
    }
    # check for write error and set appropriate error message and return value
    if ($rtnVal < 0) {
        $self->Error('Error writing output file') unless $$self{VALUE}{Error};
        $rtnVal = 0;    # return 0 on failure
    } elsif ($rtnVal > 0) {
        ++$rtnVal unless $$self{CHANGED};
    }
    # set things back to the way they were
    $$self{RAF} = $oldRaf;

    return $rtnVal;
}

#------------------------------------------------------------------------------
# Get list of all available tags for specified group
# Inputs: 0) optional group name (or string of names separated by colons)
# Returns: tag list (sorted alphabetically)
# Notes: Can't get tags for specific IFD
sub GetAllTags(;$)
{
    local $_;
    my $group = shift;
    my (%allTags, @groups);
    @groups = split ':', $group if $group;

    my $et = new Image::ExifTool;
    LoadAllTables();    # first load all our tables
    my @tableNames = keys %allTables;

    # loop through all tables and save tag names to %allTags hash
    while (@tableNames) {
        my $table = GetTagTable(pop @tableNames);
        # generate flattened tag names for structure fields if this is an XMP table
        if ($$table{GROUPS} and $$table{GROUPS}{0} eq 'XMP') {
            Image::ExifTool::XMP::AddFlattenedTags($table);
        }
        my $tagID;
        foreach $tagID (TagTableKeys($table)) {
            my @infoArray = GetTagInfoList($table,$tagID);
            my $tagInfo;
GATInfo:    foreach $tagInfo (@infoArray) {
                my $tag = $$tagInfo{Name};
                $tag or warn("no name for tag!\n"), next;
                # don't list subdirectories unless they are writable
                next if $$tagInfo{SubDirectory} and not $$tagInfo{Writable};
                next if $$tagInfo{Hidden};  # ignore hidden tags
                if (@groups) {
                    my @tg = $et->GetGroup($tagInfo);
                    foreach $group (@groups) {
                        next GATInfo unless grep /^$group$/i, @tg;
                    }
                }
                $allTags{$tag} = 1;
            }
        }
    }
    return sort keys %allTags;
}

#------------------------------------------------------------------------------
# Get list of all writable tags
# Inputs: 0) optional group name (or names separated by colons)
# Returns: tag list (sorted alphabetically)
sub GetWritableTags(;$)
{
    local $_;
    my $group = shift;
    my (%writableTags, @groups);
    @groups = split ':', $group if $group;

    my $et = new Image::ExifTool;
    LoadAllTables();
    my @tableNames = keys %allTables;

    while (@tableNames) {
        my $tableName = pop @tableNames;
        my $table = GetTagTable($tableName);
        # generate flattened tag names for structure fields if this is an XMP table
        if ($$table{GROUPS} and $$table{GROUPS}{0} eq 'XMP') {
            Image::ExifTool::XMP::AddFlattenedTags($table);
        }
        # attempt to load Write tables if autoloaded
        my @parts = split(/::/,$tableName);
        if (@parts > 3) {
            my $i = $#parts - 1;
            $parts[$i] = "Write$parts[$i]";   # add 'Write' before class name
            my $module = join('::',@parts[0..$i]);
            eval { require $module }; # (fails silently if nothing loaded)
        }
        my $tagID;
        foreach $tagID (TagTableKeys($table)) {
            my @infoArray = GetTagInfoList($table,$tagID);
            my $tagInfo;
GWTInfo:    foreach $tagInfo (@infoArray) {
                my $tag = $$tagInfo{Name};
                $tag or warn("no name for tag!\n"), next;
                my $writable = $$tagInfo{Writable};
                next unless $writable or ($$table{WRITABLE} and
                    not defined $writable and not $$tagInfo{SubDirectory});
                next if $$tagInfo{Hidden};  # ignore hidden tags
                if (@groups) {
                    my @tg = $et->GetGroup($tagInfo);
                    foreach $group (@groups) {
                        next GWTInfo unless grep /^$group$/i, @tg;
                    }
                }
                $writableTags{$tag} = 1;
            }
        }
    }
    return sort keys %writableTags;
}

#------------------------------------------------------------------------------
# Get list of all group names
# Inputs: 0) Group family number
# Returns: List of group names (sorted alphabetically)
sub GetAllGroups($)
{
    local $_;
    my $family = shift || 0;

    $family == 3 and return('Doc#', 'Main');
    $family == 4 and return('Copy#');

    LoadAllTables();    # first load all our tables

    my @tableNames = keys %allTables;

    # loop through all tag tables and get all group names
    my %allGroups;
    while (@tableNames) {
        my $table = GetTagTable(pop @tableNames);
        my ($grps, $grp, $tag, $tagInfo);
        $allGroups{$grp} = 1 if ($grps = $$table{GROUPS}) and ($grp = $$grps{$family});
        foreach $tag (TagTableKeys($table)) {
            my @infoArray = GetTagInfoList($table, $tag);
            foreach $tagInfo (@infoArray) {
                next unless ($grps = $$tagInfo{Groups}) and ($grp = $$grps{$family});
                $allGroups{$grp} = 1;
            }
        }
    }
    delete $allGroups{'*'};     # (not a real group)
    return sort keys %allGroups;
}

#------------------------------------------------------------------------------
# get priority group list for new values
# Inputs: 0) ExifTool object reference
# Returns: List of group names
sub GetNewGroups($)
{
    my $self = shift;
    return @{$$self{WRITE_GROUPS}};
}

#------------------------------------------------------------------------------
# Get list of all deletable group names
# Returns: List of group names (sorted alphabetically)
sub GetDeleteGroups()
{
    return sort @delGroups, @delGroup2;
}

#------------------------------------------------------------------------------
# Add user-defined tags at run time
# Inputs: 0) destination table name, 1) tagID/tagInfo pairs for tags to add
# Returns: number of tags added
# Notes: will replace existing tags
sub AddUserDefinedTags($%)
{
    local $_;
    my ($tableName, %addTags) = @_;
    my $table = GetTagTable($tableName) or return 0;
    # add tags to writer lookup
    Image::ExifTool::TagLookup::AddTags(\%addTags, $tableName);
    my $tagID;
    my $num = 0;
    foreach $tagID (keys %addTags) {
        next if $specialTags{$tagID};
        delete $$table{$tagID}; # delete old entry if it existed
        AddTagToTable($table, $tagID, $addTags{$tagID}, 1);
        ++$num;
    }
    return $num;
}

#==============================================================================
# Functions below this are not part of the public API

#------------------------------------------------------------------------------
# Maintain backward compatibility for old GetNewValues function name
sub GetNewValues($$;$)
{
    my ($self, $tag, $nvHashPt) = @_;
    return $self->GetNewValue($tag, $nvHashPt);
}

#------------------------------------------------------------------------------
# Un-escape string according to options settings and clear UTF-8 flag
# Inputs: 0) ExifTool ref, 1) string ref or string ref ref
# Notes: also de-references SCALAR values
sub Sanitize($$)
{
    my ($self, $valPt) = @_;
    # de-reference SCALAR references
    $$valPt = $$$valPt if ref $$valPt eq 'SCALAR';
    # make sure the Perl UTF-8 flag is OFF for the value if perl 5.6 or greater
    # (otherwise our byte manipulations get corrupted!!)
    if ($] >= 5.006 and (eval { require Encode; Encode::is_utf8($$valPt) } or $@)) {
        local $SIG{'__WARN__'} = \&SetWarning;
        # repack by hand if Encode isn't available
        $$valPt = $@ ? pack('C*',unpack($] < 5.010000 ? 'U0C*' : 'C0C*',$$valPt)) : Encode::encode('utf8',$$valPt);
    }
    # un-escape value if necessary
    if ($$self{OPTIONS}{Escape}) {
        # (XMP.pm and HTML.pm were require'd as necessary when option was set)
        if ($$self{OPTIONS}{Escape} eq 'XML') {
            $$valPt = Image::ExifTool::XMP::UnescapeXML($$valPt);
        } elsif ($$self{OPTIONS}{Escape} eq 'HTML') {
            $$valPt = Image::ExifTool::HTML::UnescapeHTML($$valPt);
        }
    }
}

#------------------------------------------------------------------------------
# Apply inverse conversions
# Inputs: 0) ExifTool ref, 1) value, 2) tagInfo (or Struct item) ref,
#         3) tag name, 4) group 1 name, 5) conversion type (or undef),
#         6) [optional] want group ("" for structure field)
# Returns: 0) converted value, 1) error string (or undef on success)
# Notes:
# - uses ExifTool "ConvType" member when conversion type is undef
# - conversion types other than 'ValueConv' and 'PrintConv' are treated as 'Raw'
sub ConvInv($$$$$;$$)
{
    my ($self, $val, $tagInfo, $tag, $wgrp1, $convType, $wantGroup) = @_;
    my ($err, $type);

Conv: for (;;) {
        if (not defined $type) {
            # split value into list if necessary
            if ($$tagInfo{List}) {
                my $listSplit = $$tagInfo{AutoSplit} || $$self{OPTIONS}{ListSplit};
                if (defined $listSplit and not $$tagInfo{Struct} and
                    ($wantGroup or not defined $wantGroup))
                {
                    $listSplit = ',?\s+' if $listSplit eq '1' and $$tagInfo{AutoSplit};
                    my @splitVal = split /$listSplit/, $val;
                    $val = \@splitVal if @splitVal > 1;
                }
            }
            $type = $convType || $$self{ConvType} || 'PrintConv';
        } elsif ($type eq 'PrintConv') {
            $type = 'ValueConv';
        } else {
            # split raw value if necessary
            if ($$tagInfo{RawJoin} and $$tagInfo{List} and not ref $val) {
                my @splitVal = split ' ', $val;
                $val = \@splitVal if @splitVal > 1;
            }
            # finally, do our value check
            my ($err2, $v);
            if ($$tagInfo{WriteCheck}) {
                #### eval WriteCheck ($self, $tagInfo, $val)
                $err2 = eval $$tagInfo{WriteCheck};
                $@ and warn($@), $err2 = 'Error evaluating WriteCheck';
            }
            unless ($err2) {
                my $table = $$tagInfo{Table};
                if ($table and $$table{CHECK_PROC} and not $$tagInfo{RawConvInv}) {
                    my $checkProc = $$table{CHECK_PROC};
                    if (ref $val eq 'ARRAY') {
                        # loop through array values
                        foreach $v (@$val) {
                            $err2 = &$checkProc($self, $tagInfo, \$v);
                            last if $err2;
                        }
                    } else {
                        $err2 = &$checkProc($self, $tagInfo, \$val);
                    }
                }
            }
            if (defined $err2) {
                if ($err2) {
                    $err = "$err2 for $wgrp1:$tag";
                    $self->VPrint(2, "$err\n");
                    undef $val;     # value was invalid
                } else {
                    $err = $err2;   # empty error (quietly don't write tag)
                }
            }
            last;
        }
        my $conv = $$tagInfo{$type};
        my $convInv = $$tagInfo{"${type}Inv"};
        # nothing to do at this level if no conversion defined
        next unless defined $conv or defined $convInv;

        my (@valList, $index, $convList, $convInvList);
        if (ref $val eq 'ARRAY') {
            # handle ValueConv of ListSplit and AutoSplit values
            @valList = @$val;
            $val = $valList[$index = 0];
        } elsif (ref $conv eq 'ARRAY' or ref $convInv eq 'ARRAY') {
            # handle conversion lists
            @valList = split /$listSep{$type}/, $val;
            $val = $valList[$index = 0];
            if (ref $conv eq 'ARRAY') {
                $convList = $conv;
                $conv = $$conv[0];
            }
            if (ref $convInv eq 'ARRAY') {
                $convInvList = $convInv;
                $convInv = $$convInv[0];
            }
        }
        # loop through multiple values if necessary
        for (;;) {
            if ($convInv) {
                # capture eval warnings too
                local $SIG{'__WARN__'} = \&SetWarning;
                undef $evalWarning;
                if (ref($convInv) eq 'CODE') {
                    $val = &$convInv($val, $self);
                } else {
                    #### eval PrintConvInv/ValueConvInv ($val, $self, $wantGroup)
                    $val = eval $convInv;
                    $@ and $evalWarning = $@;
                }
                if ($evalWarning) {
                    # an empty warning ("\n") ignores tag with no error
                    if ($evalWarning eq "\n") {
                        $err = '' unless defined $err;
                    } else {
                        $err = CleanWarning() . " in $wgrp1:$tag (${type}Inv)";
                        $self->VPrint(2, "$err\n");
                    }
                    undef $val;
                    last Conv;
                } elsif (not defined $val) {
                    $err = "Error converting value for $wgrp1:$tag (${type}Inv)";
                    $self->VPrint(2, "$err\n");
                    last Conv;
                }
            } elsif ($conv) {
                if (ref $conv eq 'HASH') {
                    my ($multi, $lc);
                    # insert alternate language print conversions if required
                    if ($$self{CUR_LANG} and $type eq 'PrintConv' and
                        ref($lc = $$self{CUR_LANG}{$tag}) eq 'HASH' and
                        ($lc = $$lc{PrintConv}))
                    {
                        my %newConv;
                        foreach (keys %$conv) {
                            my $val = $$conv{$_};
                            defined $$lc{$val} or $newConv{$_} = $val, next;
                            $newConv{$_} = $self->Decode($$lc{$val}, 'UTF8');
                        }
                        if ($$conv{BITMASK}) {
                            foreach (keys %{$$conv{BITMASK}}) {
                                my $val = $$conv{BITMASK}{$_};
                                defined $$lc{$val} or $newConv{BITMASK}{$_} = $val, next;
                                $newConv{BITMASK}{$_} = $self->Decode($$lc{$val}, 'UTF8');
                            }
                        }
                        $conv = \%newConv;
                    }
                    undef $evalWarning;
                    if ($$conv{BITMASK}) {
                        my $lookupBits = $$conv{BITMASK};
                        my ($wbits, $tbits) = @$tagInfo{'BitsPerWord','BitsTotal'};
                        my ($val2, $err2) = EncodeBits($val, $lookupBits, $wbits, $tbits);
                        if ($err2) {
                            # ok, try matching a straight value
                            ($val, $multi) = ReverseLookup($val, $conv);
                            unless (defined $val) {
                                $err = "Can't encode $wgrp1:$tag ($err2)";
                                $self->VPrint(2, "$err\n");
                                last Conv;
                            }
                        } elsif (defined $val2) {
                            $val = $val2;
                        } else {
                            delete $$conv{BITMASK};
                            ($val, $multi) = ReverseLookup($val, $conv);
                            $$conv{BITMASK} = $lookupBits;
                        }
                    } else {
                        ($val, $multi) = ReverseLookup($val, $conv);
                    }
                    if (not defined $val) {
                        my $prob = $evalWarning ? lcfirst CleanWarning() : ($multi ? 'matches more than one ' : 'not in ') . $type;
                        $err = "Can't convert $wgrp1:$tag ($prob)";
                        $self->VPrint(2, "$err\n");
                        last Conv;
                    } elsif ($evalWarning) {
                        $self->VPrint(2, CleanWarning() . " for $wgrp1:$tag\n");
                    }
                } elsif (not $$tagInfo{WriteAlso}) {
                    $err = "Can't convert value for $wgrp1:$tag (no ${type}Inv)";
                    $self->VPrint(2, "$err\n");
                    undef $val;
                    last Conv;
                }
            }
            last unless @valList;
            $valList[$index] = $val;
            if (++$index >= @valList) {
                # leave AutoSplit lists in ARRAY form, or join conversion lists
                $val = $$tagInfo{List} ? \@valList : join ' ', @valList;
                last;
            }
            $conv = $$convList[$index] if $convList;
            $convInv = $$convInvList[$index] if $convInvList;
            $val = $valList[$index];
        }
    } # end ValueConv/PrintConv loop

    return($val, $err);
}

#------------------------------------------------------------------------------
# convert tag names to values in a string (eg. '${EXIF:ISO}x $$' --> '100x $')
# Inputs: 0) ExifTool object ref, 1) reference to list of found tags
#         2) string with embedded tag names, 3) Options:
#               undef    - set missing tags to ''
#              'Error'   - issue minor error on missing tag (and return undef)
#              'Warn'    - issue minor warning on missing tag (and return undef)
#              'Silent'  - just return undef on missing tag (no errors/warnings)
#               Hash ref - hash for return of tag/value pairs
#         4) document group name if extracting from a specific document
#         5) hash ref to cache tag keys for subsequent calls in document loop
# Returns: string with embedded tag values (or '$info{TAGNAME}' entries with Hash ref option)
# Notes:
# - tag names are not case sensitive and may end with '#' for ValueConv value
# - uses MissingTagValue option if set
# - '$GROUP:all' evaluates to 1 if any tag from GROUP exists, or 0 otherwise
# - advanced feature allows Perl expressions inside braces (eg. '${model;tr/ //d}')
# - an error/warning in an advanced expression ("${TAG;EXPR}") generates an error
#   if option set to 'Error', or a warning otherwise
sub InsertTagValues($$$;$$$)
{
    local $_;
    my ($self, $foundTags, $line, $opt, $docGrp, $cache) = @_;
    my $rtnStr = '';
    my $docNum;
    if ($docGrp) {
        $docNum = $docGrp =~ /(\d+)$/ ? $1 : 0;
    } else {
        undef $cache;   # no cache if no document groups
    }
    while ($line =~ s/(.*?)\$(\{\s*)?([-\w]*\w|\$|\/)//s) {
        my ($pre, $bra, $var) = ($1, $2, $3);
        my (@tags, $val, $tg, @val, $type, $expr, $didExpr, $level, $asList);
        # "$$" represents a "$" symbol, and "$/" is a newline
        if ($var eq '$' or $var eq '/') {
            $var = "\n" if $var eq '/';
            $rtnStr .= "$pre$var";
            $line =~ s/^\s*\}// if $bra;
            next;
        }
        # allow multiple group names
        while ($line =~ /^:([-\w]*\w)(.*)/s) {
            my $group = $var;
            ($var, $line) = ($1, $2);
            $var = "$group:$var";
        }
        # allow trailing '#' to indicate ValueConv value
        $type = 'ValueConv' if $line =~ s/^#//;
        # (undocumented feature to allow '@' to evaluate list values separately, but only in braces)
        if ($bra and $line =~ s/^\@(#)?//) {
            $asList = 1;
            $type = 'ValueConv' if $1;
        }
        # remove trailing bracket if there was a leading one
        # and extract Perl expression from inside brackets if it exists
        if ($bra and $line !~ s/^\s*\}// and $line =~ s/^\s*;\s*(.*?)\s*\}//s) {
            my $part = $1;
            $expr = '';
            for ($level=0; ; --$level) {
                # increase nesting level for each opening brace
                ++$level while $part =~ /\{/g;
                $expr .= $part;
                last unless $level and $line =~ s/^(.*?)\s*\}//s; # get next part
                $part = $1;
                $expr .= '}';  # this brace was part of the expression
            }
            # use default Windows filename filter if expression is empty
            $expr = 'tr(/\\\\?*:|"<>\\0)()d' unless length $expr;
        }
        push @tags, $var;
        ExpandShortcuts(\@tags);
        @tags or $rtnStr .= $pre, next;
        # save advanced formatting expression to allow access by user-defined ValueConv
        $$self{FMT_EXPR} = $expr;

        for (;;) {
            # temporarily reset ListJoin option if evaluating list values separately
            my $oldListJoin = $self->Options(ListJoin => undef) if $asList;
            my $tag = shift @tags;
            my $lcTag = lc $tag;
            if ($cache and $lcTag !~ /(^|:)all$/) {
                # remove group from tag name (but not lower-case version)
                my $group;
                $tag =~ s/^(.*):// and $group = $1;
                # cache tag keys to speed processing for a large number of sub-documents
                # (similar to code in BuildCompositeTags(), but this is case-insensitive)
                my $cacheTag = $$cache{$lcTag};
                unless ($cacheTag) {
                    $cacheTag = $$cache{$lcTag} = [ ];
                    # find all matching keys, organize into groups, and store in cache
                    my $ex = $$self{TAG_EXTRA};
                    my @matches = grep /^$tag(\s|$)/i, @$foundTags;
                    @matches = $self->GroupMatches($group, \@matches) if defined $group;
                    foreach (@matches) {
                        my $doc = $$ex{$_} ? $$ex{$_}{G3} || 0 : 0;
                        if (defined $$cacheTag[$doc]) {
                            next unless $$cacheTag[$doc] =~ / \((\d+)\)$/;
                            my $cur = $1;
                            # keep the most recently extracted tag
                            next if / \((\d+)\)$/ and $1 < $cur;
                        }
                        $$cacheTag[$doc] = $_;
                    }
                }
                my $doc = $lcTag =~ /\b(main|doc(\d+)):/ ? ($2 || 0) : $docNum;
                $val = $self->GetValue($$cacheTag[$doc], $type) if $$cacheTag[$doc];
            } else {
                # add document number to tag if specified and it doesn't already exist
                if ($docGrp and $lcTag !~ /\b(main|doc\d+):/) {
                    $tag = $docGrp . ':' . $tag;
                    $lcTag = lc $tag;
                }
                if ($lcTag eq 'all') {
                    $val = 1;   # always some tag available
                } elsif (defined $$self{OPTIONS}{UserParam}{$lcTag}) {
                    $val = $$self{OPTIONS}{UserParam}{$lcTag};
                } elsif ($tag =~ /(.*):(.+)/) {
                    my $group;
                    ($group, $tag) = ($1, $2);
                    if (lc $tag eq 'all') {
                        # see if any tag from the specified group exists
                        my $match = $self->GroupMatches($group, $foundTags);
                        $val = $match ? 1 : 0;
                    } else {
                        # find the specified tag
                        my @matches = grep /^$tag(\s|$)/i, @$foundTags;
                        @matches = $self->GroupMatches($group, \@matches);
                        foreach $tg (@matches) {
                            if (defined $val and $tg =~ / \((\d+)\)$/) {
                                # take the most recently extracted tag
                                my $tagNum = $1;
                                next if $tag !~ / \((\d+)\)$/ or $1 > $tagNum;
                            }
                            $val = $self->GetValue($tg, $type);
                            $tag = $tg;
                            last unless $tag =~ / /;    # all done if we got our best match
                        }
                    }
                } else {
                    # get the tag value
                    $val = $self->GetValue($tag, $type);
                    unless (defined $val) {
                        # check for tag name with different case
                        ($tg) = grep /^$tag$/i, @$foundTags;
                        if (defined $tg) {
                            $val = $self->GetValue($tg, $type);
                            $tag = $tg;
                        }
                    }
                }
            }
            $self->Options(ListJoin => $oldListJoin) if $asList;
            if (ref $val eq 'ARRAY') {
                push @val, @$val;
                undef $val;
                last unless @tags;
            } elsif (ref $val eq 'SCALAR') {
                if ($$self{OPTIONS}{Binary} or $$val =~ /^Binary data/) {
                    $val = $$val;
                } else {
                    $val = 'Binary data ' . length($$val) . ' bytes';
                }
            } elsif (ref $val eq 'HASH') {
                require 'Image/ExifTool/XMPStruct.pl';
                $val = Image::ExifTool::XMP::SerializeStruct($val);
            } elsif (not defined $val) {
                $val = $$self{OPTIONS}{MissingTagValue} if $asList;
            }
            last unless @tags;
            push @val, $val if defined $val;
            undef $val;
        }
        if (@val) {
            push @val, $val if defined $val;
            $val = join $$self{OPTIONS}{ListSep}, @val;
        } else {
            push @val, $val if defined $val; # (so the eval has access to @val if required)
        }
        # evaluate advanced formatting expression if given (eg. "${TAG;EXPR}")
        if (defined $expr and defined $val) {
            local $SIG{'__WARN__'} = \&SetWarning;
            undef $evalWarning;
            $advFmtSelf = $self;
            if ($asList) {
                foreach (@val) {
                    #### eval advanced formatting expression ($_, $self, @val, $advFmtSelf)
                    eval $expr;
                    $@ and $evalWarning = $@;
                }
                # join back together if any values are still defined
                @val = grep defined, @val;
                $val = @val ? join $$self{OPTIONS}{ListSep}, @val : undef;
            } else {
                $_ = $val;
                #### eval advanced formatting expression ($_, $self, @val, $advFmtSelf)
                eval $expr;
                $@ and $evalWarning = $@;
                $val = ref $_ eq 'ARRAY' ? join($$self{OPTIONS}{ListSep}, @$_): $_;
            }
            if ($evalWarning) {
                my $g3 = ($docGrp and $var !~ /\b(main|doc\d+):/i) ? $docGrp . ':' : '';
                my $str = CleanWarning() . " for '$g3${var}'";
                if ($opt) {
                    if ($opt eq 'Error') {
                        $self->Error($str);
                    } elsif ($opt ne 'Silent') {
                        $self->Warn($str);
                    }
                }
            }
            undef $advFmtSelf;
            $didExpr = 1;   # set flag indicating an expression was evaluated
        }
        unless (defined $val or ref $opt) {
            $val = $$self{OPTIONS}{MissingTagValue};
            unless (defined $val) {
                my $g3 = ($docGrp and $var !~ /\b(main|doc\d+):/i) ? $docGrp . ':' : '';
                my $msg = $didExpr ? "Advanced formatting expression returned undef for '$g3${var}'" :
                                     "Tag '$g3${var}' not defined";
                no strict 'refs';
                $opt and ($opt eq 'Silent' or &$opt($self, $msg, 2)) and return $$self{FMT_EXPR} = undef;
                $val = '';
            }
        }
        if (ref $opt eq 'HASH') {
            $var .= '#' if $type;
            if (defined $expr) {
                # generate unique variable name for this modified tag value
                my $i = 1;
                ++$i while exists $$opt{"$var.expr$i"};
                $var .= '.expr' . $i;
            }
            $rtnStr .= "$pre\$info{'${var}'}";
            $$opt{$var} = $val;
        } else {
            $rtnStr .= "$pre$val";
        }
    }
    $$self{FMT_EXPR} = undef;
    return $rtnStr . $line;
}

#------------------------------------------------------------------------------
# Reformat date/time value in $_ based on specified format string
# Inputs: 0) date/time format string
sub DateFmt($)
{
    my $et = bless { OPTIONS => { DateFormat => shift, StrictDate => 1 } };
    my $shift;
    if ($advFmtSelf and defined($shift = $$advFmtSelf{OPTIONS}{GlobalTimeShift})) {
        $$et{OPTIONS}{GlobalTimeShift} = $shift;
        $$et{GLOBAL_TIME_OFFSET} = $$advFmtSelf{GLOBAL_TIME_OFFSET};
    }
    $_ = $et->ConvertDateTime($_);
    defined $_ or warn "Error converting date/time\n";
    $$advFmtSelf{GLOBAL_TIME_OFFSET} = $$et{GLOBAL_TIME_OFFSET} if $shift;
}

#------------------------------------------------------------------------------
# Utility routine to remove duplicate items from default input string
# Inputs: 0) true to set $_ to undef if not changed
# Notes: - for use only in advanced formatting expressions
sub NoDups
{
    my %seen;
    my $sep = $advFmtSelf ? $$advFmtSelf{OPTIONS}{ListSep} : ', ';
    my $new = join $sep, grep { !$seen{$_}++ } split /\Q$sep\E/, $_;
    $_ = ($_[0] and $new eq $_) ? undef : $new;
}

#------------------------------------------------------------------------------
# Is specified tag writable
# Inputs: 0) tag name, case insensitive (optional group name currently ignored)
# Returns: 0=exists but not writable, 1=writable, undef=doesn't exist
sub IsWritable($)
{
    my $tag = shift;
    $tag =~ s/^(.*)://; # ignore group name
    my @tagInfo = FindTagInfo($tag);
    unless (@tagInfo) {
        return 0 if TagExists($tag);
        return undef;
    }
    my $tagInfo;
    foreach $tagInfo (@tagInfo) {
        return $$tagInfo{Writable} ? 1 : 0 if defined $$tagInfo{Writable};
        return 1 if $$tagInfo{Table}{WRITABLE};
        # must call WRITE_PROC to autoload writer because this may set the writable tag
        my $writeProc = $$tagInfo{Table}{WRITE_PROC};
        next unless $writeProc;
        &$writeProc();  # dummy call to autoload writer
        return 1 if $$tagInfo{Writable};
    }
    return 0;
}

#------------------------------------------------------------------------------
# Create directory for specified file
# Inputs: 0) ExifTool ref, 1) complete file name including path
# Returns: 1 = directory created, 0 = nothing done, -1 = error
my $k32CreateDir;
sub CreateDirectory($$)
{
    local $_;
    my ($self, $file) = @_;
    my $rtnVal = 0;
    my $enc = $$self{OPTIONS}{CharsetFileName};
    my $dir;
    ($dir = $file) =~ s/[^\/]*$//;  # remove filename from path specification
    # recode as UTF-8 if necessary
    if ($dir and not $self->IsDirectory($dir)) {
        my @parts = split /\//, $dir;
        $dir = '';
        foreach (@parts) {
            $dir .= $_;
            if (length $dir and not $self->IsDirectory($dir)) {
                # create directory since it doesn't exist
                my $d2 = $dir; # (must make a copy in case EncodeFileName recodes it)
                if ($self->EncodeFileName($d2)) {
                    # handle Windows Unicode directory names
                    unless (eval { require Win32::API }) {
                        $self->Warn('Install Win32::API to create directories with Unicode names');
                        return -1;
                    }
                    unless ($k32CreateDir) {
                        return -1 if defined $k32CreateDir;
                        $k32CreateDir = new Win32::API('KERNEL32', 'CreateDirectoryW', 'PP', 'I');
                        unless ($k32CreateDir) {
                            $self->Warn('Error calling Win32::API::CreateDirectoryW');
                            $k32CreateDir = 0;
                            return -1;
                        }
                    }
                    $k32CreateDir->Call($d2, 0) or return -1;
                } else {
                    mkdir($d2, 0777) or return -1;
                }
                $rtnVal = 1;
            }
            $dir .= '/';
        }
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Copy file attributes from one file to another
# Inputs: 0) ExifTool ref, 1) source file name, 2) destination file name
# Notes: eventually add support for extended attributes?
sub CopyFileAttrs($$$)
{
    my ($self, $src, $dst) = @_;
    my ($mode, $uid, $gid) = (stat($src))[2, 4, 5];
    # copy file attributes unless we already set them
    if (defined $mode and not defined $self->GetNewValue('FilePermissions')) {
        eval { chmod($mode & 07777, $dst) };
    }
    my $newUid = $self->GetNewValue('FileUserID');
    my $newGid = $self->GetNewValue('FileGroupID');
    if (defined $uid and defined $gid and (not defined $newUid or not defined $newGid)) {
        defined $newGid and $gid = $newGid;
        defined $newUid and $uid = $newUid;
        eval { chown($uid, $gid, $dst) };
    }
}

#------------------------------------------------------------------------------
# Get new file path name
# Inputs: 0) existing name (may contain directory),
#         1) new file name, new directory, or new path (dir+name)
# Returns: new file path name
sub GetNewFileName($$)
{
    my ($oldName, $newName) = @_;
    my ($dir, $name) = ($oldName =~ m{(.*/)(.*)});
    ($dir, $name) = ('', $oldName) unless defined $dir;
    if ($newName =~ m{/$}) {
        $newName = "$newName$name"; # change dir only
    } elsif ($newName !~ m{/}) {
        $newName = "$dir$newName";  # change name only if newname doesn't specify dir
    }                               # else change dir and name
    return $newName;
}

#------------------------------------------------------------------------------
# Get next available tag key
# Inputs: 0) hash reference (keys are tag keys), 1) tag name
# Returns: next available tag key
sub NextFreeTagKey($$)
{
    my ($info, $tag) = @_;
    return $tag unless exists $$info{$tag};
    my $i;
    for ($i=1; ; ++$i) {
        my $key = "$tag ($i)";
        return $key unless exists $$info{$key};
    }
}

#------------------------------------------------------------------------------
# Reverse hash lookup
# Inputs: 0) value, 1) hash reference
# Returns: Hash key or undef if not found (plus flag for multiple matches in list context)
sub ReverseLookup($$)
{
    my ($val, $conv) = @_;
    return undef unless defined $val;
    my $multi;
    if ($val =~ /^Unknown\s*\((.*)\)$/i) {
        $val = $1;    # was unknown
        if ($val =~ /^0x([\da-fA-F]+)$/) {
            $val = hex($val);   # convert hex value
        }
    } else {
        my $qval = $val;
        $qval =~ s/\s+$//;      # remove trailing whitespace
        $qval = quotemeta $qval;
        my @patterns = (
            "^$qval\$",         # exact match
            "^(?i)$qval\$",     # case-insensitive
            "^(?i)$qval",       # beginning of string
            "(?i)$qval",        # substring
        );
        # hash entries to ignore in reverse lookup
        my ($pattern, $found, $matches);
PAT:    foreach $pattern (@patterns) {
            $matches = scalar grep /$pattern/, values(%$conv);
            next unless $matches;
            # multiple matches are bad unless they were exact
            if ($matches > 1 and $pattern !~ /\$$/) {
                # don't match entries that we should ignore
                foreach (keys %ignorePrintConv) {
                    --$matches if defined $$conv{$_} and $$conv{$_} =~ /$pattern/;
                }
                last if $matches > 1;
            }
            foreach (sort keys %$conv) {
                next if $$conv{$_} !~ /$pattern/ or $ignorePrintConv{$_};
                $val = $_;
                $found = 1;
                last PAT;
            }
        }
        unless ($found) {
            # call OTHER conversion routine if available
            if ($$conv{OTHER}) {
                local $SIG{'__WARN__'} = \&SetWarning;
                undef $evalWarning;
                $val = &{$$conv{OTHER}}($val,1,$conv);
            } else {
                $val = undef;
            }
            $multi = 1 if $matches > 1;
        }
    }
    return ($val, $multi) if wantarray;
    return $val;
}

#------------------------------------------------------------------------------
# Return true if we are deleting or overwriting the specified tag
# Inputs: 0) ExifTool object ref, 1) new value hash reference
#         2) optional tag value (before RawConv) if deleting specific values
# Returns: >0 - tag should be overwritten
#          =0 - the tag should be preserved
#          <0 - not sure, we need the value to know
# Notes: $$nvHash{Value} is updated with the new value when shifting a value
sub IsOverwriting($$;$)
{
    my ($self, $nvHash, $val) = @_;
    return 0 unless $nvHash;
    # overwrite regardless if no DelValues specified
    return 1 unless $$nvHash{DelValue};
    # never overwrite if DelValue list exists but is empty
    my $shift = $$nvHash{Shift};
    return 0 unless @{$$nvHash{DelValue}} or defined $shift;
    # return "don't know" if we don't have a value to test
    return -1 unless defined $val;
    # apply raw conversion if necessary
    my $tagInfo = $$nvHash{TagInfo};
    my $conv = $$tagInfo{RawConv};
    if ($conv) {
        local $SIG{'__WARN__'} = \&SetWarning;
        undef $evalWarning;
        if (ref $conv eq 'CODE') {
            $val = &$conv($val, $self);
        } else {
            my ($priority, @grps);
            my $tag = $$tagInfo{Name};
            #### eval RawConv ($self, $val, $tag, $tagInfo, $priority, @grps)
            $val = eval $conv;
            $@ and $evalWarning = $@;
        }
        return -1 unless defined $val;
    }
    # do not overwrite if only creating
    return 0 if $$nvHash{CreateOnly};
    # apply time/number shift if necessary
    if (defined $shift) {
        my $shiftType = $$tagInfo{Shift};
        unless ($shiftType and $shiftType eq 'Time') {
            unless (IsFloat($val)) {
                # do the ValueConv to try to get a number
                my $conv = $$tagInfo{ValueConv};
                if (defined $conv) {
                    local $SIG{'__WARN__'} = \&SetWarning;
                    undef $evalWarning;
                    if (ref $conv eq 'CODE') {
                        $val = &$conv($val, $self);
                    } elsif (not ref $conv) {
                        #### eval ValueConv ($val, $self)
                        $val = eval $conv;
                        $@ and $evalWarning = $@;
                    }
                    if ($evalWarning) {
                        $self->Warn("ValueConv $$tagInfo{Name}: " . CleanWarning());
                        return 0;
                    }
                }
                unless (defined $val and IsFloat($val)) {
                    $self->Warn("Can't shift $$tagInfo{Name} (not a number)");
                    return 0;
                }
            }
            $shiftType = 'Number';  # allow any number to be shifted
        }
        require 'Image/ExifTool/Shift.pl';
        my $err = $self->ApplyShift($shiftType, $shift, $val, $nvHash);
        if ($err) {
            $self->Warn("$err when shifting $$tagInfo{Name}");
            return 0;
        }
        # ensure that the shifted value is valid and reformat if necessary
        my $checkVal = $self->GetNewValue($nvHash);
        return 0 unless defined $checkVal;
        # don't bother overwriting if value is the same
        return 0 if $val eq $$nvHash{Value}[0];
        return 1;
    }
    # return 1 if value matches a DelValue
    my $delVal;
    foreach $delVal (@{$$nvHash{DelValue}}) {
        return 1 if $val eq $delVal;
    }
    return 0;
}

#------------------------------------------------------------------------------
# Get write group for specified tag
# Inputs: 0) new value hash reference
# Returns: Write group name
sub GetWriteGroup($)
{
    return $_[0]{WriteGroup};
}

#------------------------------------------------------------------------------
# Get name of write group or family 1 group
# Inputs: 0) ExifTool ref, 1) tagInfo ref, 2) write group name
# Returns: Name of group for verbose message
sub GetWriteGroup1($$)
{
    my ($self, $tagInfo, $writeGroup) = @_;
    return $writeGroup unless $writeGroup =~ /^(MakerNotes|XMP|Composite)$/;
    return $self->GetGroup($tagInfo, 1);
}

#------------------------------------------------------------------------------
# Get new value hash for specified tagInfo/writeGroup
# Inputs: 0) ExifTool object reference, 1) reference to tag info hash
#         2) Write group name, 3) Options: 'delete' or 'create' new value hash
#         4) optional ProtectSaved value, 5) true if we are deleting a value
# Returns: new value hash reference for specified write group
#          (or first new value hash in linked list if write group not specified)
# Notes: May return undef when 'create' is used with ProtectSaved
sub GetNewValueHash($$;$$$$)
{
    my ($self, $tagInfo, $writeGroup, $opts) = @_;
    my $nvHash = $$self{NEW_VALUE}{$tagInfo};

    my %opts;   # quick lookup for options
    $opts and $opts{$opts} = 1;
    $writeGroup = '' unless defined $writeGroup;

    if ($writeGroup) {
        # find the new value in the list with the specified write group
        # (QuickTime and All are special cases because all group1 tags may be updated at once)
        while ($nvHash and $$nvHash{WriteGroup} ne $writeGroup and
            $$nvHash{WriteGroup} !~ /^(QuickTime|All)$/)
        {
            $nvHash = $$nvHash{Next};
        }
    }
    # remove this entry if deleting, or if creating a new entry and
    # this entry is marked with "Save" flag
    if (defined $nvHash and ($opts{'delete'} or ($opts{'create'} and $$nvHash{Save}))) {
        my $protect = (defined $_[4] and defined $$nvHash{Save} and $$nvHash{Save} > $_[4]);
        # this is a bit tricky:  we want to add to a protected nvHash only if we
        # are adding a conditional delete ($_[5] true or DelValue with no Shift)
        # or accumulating List items (NoReplace true)
        if ($protect and not ($opts{create} and ($$nvHash{NoReplace} or $_[5] or
            ($$nvHash{DelValue} and not defined $$nvHash{Shift}))))
        {
            return undef;   # honour ProtectSaved value by not writing this tag
        } elsif ($opts{'delete'}) {
            $self->RemoveNewValueHash($nvHash, $tagInfo);
            undef $nvHash;
        } else {
            # save a copy of this new value hash
            my %copy = %$nvHash;
            # make copy of Value and DelValue lists
            my $key;
            foreach $key (keys %copy) {
                next unless ref $copy{$key} eq 'ARRAY';
                $copy{$key} = [ @{$copy{$key}} ];
            }
            my $saveHash = $$self{SAVE_NEW_VALUE};
            # add to linked list of saved new value hashes
            $copy{Next} = $$saveHash{$tagInfo};
            $$saveHash{$tagInfo} = \%copy;
            delete $$nvHash{Save}; # don't save it again
            $$nvHash{AddBefore} = scalar @{$$nvHash{Value}} if $protect and $$nvHash{Value};
        }
    }
    if (not defined $nvHash and $opts{'create'}) {
        # create a new entry
        $nvHash = {
            TagInfo => $tagInfo,
            WriteGroup => $writeGroup,
            IsNVH => 1, # set flag so we can recognize a new value hash
        };
        # add entry to our NEW_VALUE hash
        if ($$self{NEW_VALUE}{$tagInfo}) {
            # add to end of linked list
            my $lastHash = LastInList($$self{NEW_VALUE}{$tagInfo});
            $$lastHash{Next} = $nvHash;
        } else {
            $$self{NEW_VALUE}{$tagInfo} = $nvHash;
        }
    }
    return $nvHash;
}

#------------------------------------------------------------------------------
# Load all tag tables
sub LoadAllTables()
{
    return if $loadedAllTables;

    # load all of our non-referenced tables (first our modules)
    my $table;
    foreach $table (@loadAllTables) {
        my $tableName = "Image::ExifTool::$table";
        $tableName .= '::Main' unless $table =~ /:/;
        GetTagTable($tableName);
    }
    # (then our special tables)
    GetTagTable('Image::ExifTool::Extra');
    GetTagTable('Image::ExifTool::Composite');
    # recursively load all tables referenced by the current tables
    my @tableNames = keys %allTables;
    my %pushedTables;
    while (@tableNames) {
        $table = GetTagTable(shift @tableNames);
        # call write proc if it exists in case it adds tags to the table
        my $writeProc = $$table{WRITE_PROC};
        $writeProc and &$writeProc();
        # recursively scan through tables in subdirectories
        foreach (TagTableKeys($table)) {
            my @infoArray = GetTagInfoList($table,$_);
            my $tagInfo;
            foreach $tagInfo (@infoArray) {
                my $subdir = $$tagInfo{SubDirectory} or next;
                my $tableName = $$subdir{TagTable} or next;
                # next if table already loaded or queued for loading
                next if $allTables{$tableName} or $pushedTables{$tableName};
                push @tableNames, $tableName;   # must scan this one too
                $pushedTables{$tableName} = 1;
            }
        }
    }
    $loadedAllTables = 1;
}

#------------------------------------------------------------------------------
# Remove new value hash from linked list (and save if necessary)
# Inputs: 0) ExifTool object reference, 1) new value hash ref, 2) tagInfo ref
sub RemoveNewValueHash($$$)
{
    my ($self, $nvHash, $tagInfo) = @_;
    my $firstHash = $$self{NEW_VALUE}{$tagInfo};
    if ($nvHash eq $firstHash) {
        # remove first entry from linked list
        if ($$nvHash{Next}) {
            $$self{NEW_VALUE}{$tagInfo} = $$nvHash{Next};
        } else {
            delete $$self{NEW_VALUE}{$tagInfo};
        }
    } else {
        # find the list element pointing to this hash
        $firstHash = $$firstHash{Next} while $$firstHash{Next} ne $nvHash;
        # remove from linked list
        $$firstHash{Next} = $$nvHash{Next};
    }
    # save the existing entry if necessary
    if ($$nvHash{Save}) {
        my $saveHash = $$self{SAVE_NEW_VALUE};
        # add to linked list of saved new value hashes
        $$nvHash{Next} = $$saveHash{$tagInfo};
        $$saveHash{$tagInfo} = $nvHash;
    }
}

#------------------------------------------------------------------------------
# Remove all new value entries for specified group
# Inputs: 0) ExifTool object reference, 1) group name
sub RemoveNewValuesForGroup($$)
{
    my ($self, $group) = @_;

    return unless $$self{NEW_VALUE};

    # make list of all groups we must remove
    my @groups = ( $group );
    push @groups, @{$removeGroups{$group}} if $removeGroups{$group};

    my ($out, @keys, $hashKey);
    $out = $$self{OPTIONS}{TextOut} if $$self{OPTIONS}{Verbose} > 1;

    # loop though all new values, and remove any in this group
    @keys = keys %{$$self{NEW_VALUE}};
    foreach $hashKey (@keys) {
        my $nvHash = $$self{NEW_VALUE}{$hashKey};
        # loop through each entry in linked list
        for (;;) {
            my $nextHash = $$nvHash{Next};
            my $tagInfo = $$nvHash{TagInfo};
            my ($grp0,$grp1) = $self->GetGroup($tagInfo);
            my $wgrp = $$nvHash{WriteGroup};
            # use group1 if write group is not specific
            $wgrp = $grp1 if $wgrp eq $grp0;
            if (grep /^($grp0|$wgrp)$/i, @groups) {
                $out and print $out "Removed new value for $wgrp:$$tagInfo{Name}\n";
                # remove from linked list
                $self->RemoveNewValueHash($nvHash, $tagInfo);
            }
            $nvHash = $nextHash or last;
        }
    }
}

#------------------------------------------------------------------------------
# Get list of tagInfo hashes for all new data
# Inputs: 0) ExifTool object reference, 1) optional tag table pointer
# Returns: list of tagInfo hashes
sub GetNewTagInfoList($;$)
{
    my ($self, $tagTablePtr) = @_;
    my @tagInfoList;
    my $nv = $$self{NEW_VALUE};
    if ($nv) {
        my $hashKey;
        foreach $hashKey (keys %$nv) {
            my $tagInfo = $$nv{$hashKey}{TagInfo};
            next if $tagTablePtr and $tagTablePtr ne $$tagInfo{Table};
            push @tagInfoList, $tagInfo;
        }
    }
    return @tagInfoList;
}

#------------------------------------------------------------------------------
# Get hash of tagInfo references keyed on tagID for a specific table
# Inputs: 0) ExifTool object reference, 1-N) tag table pointers
# Returns: hash reference
# Notes: returns only one tagInfo ref for each conditional list
sub GetNewTagInfoHash($@)
{
    my $self = shift;
    my (%tagInfoHash, $hashKey);
    my $nv = $$self{NEW_VALUE};
    while ($nv) {
        my $tagTablePtr = shift || last;
        foreach $hashKey (keys %$nv) {
            my $tagInfo = $$nv{$hashKey}{TagInfo};
            next if $tagTablePtr and $tagTablePtr ne $$tagInfo{Table};
            $tagInfoHash{$$tagInfo{TagID}} = $tagInfo;
        }
    }
    return \%tagInfoHash;
}

#------------------------------------------------------------------------------
# Get a tagInfo/tagID hash for subdirectories we need to add
# Inputs: 0) ExifTool object reference, 1) parent tag table reference
#         2) parent directory name (taken from GROUP0 of tag table if not defined)
# Returns: Reference to Hash of subdirectory tagInfo references keyed by tagID
#          (plus Reference to edit directory hash in list context)
sub GetAddDirHash($$;$)
{
    my ($self, $tagTablePtr, $parent) = @_;
    $parent or $parent = $$tagTablePtr{GROUPS}{0};
    my $tagID;
    my %addDirHash;
    my %editDirHash;
    my $addDirs = $$self{ADD_DIRS};
    my $editDirs = $$self{EDIT_DIRS};
    foreach $tagID (TagTableKeys($tagTablePtr)) {
        my @infoArray = GetTagInfoList($tagTablePtr,$tagID);
        my $tagInfo;
        foreach $tagInfo (@infoArray) {
            next unless $$tagInfo{SubDirectory};
            # get name for this sub directory
            # (take directory name from SubDirectory DirName if it exists,
            #  otherwise Group0 name of SubDirectory TagTable or tag Group1 name)
            my $dirName = $$tagInfo{SubDirectory}{DirName};
            unless ($dirName) {
                # use tag name for directory name and save for next time
                $dirName = $$tagInfo{Name};
                $$tagInfo{SubDirectory}{DirName} = $dirName;
            }
            # save this directory information if we are writing it
            if ($$editDirs{$dirName} and $$editDirs{$dirName} eq $parent) {
                $editDirHash{$tagID} = $tagInfo;
                $addDirHash{$tagID} = $tagInfo if $$addDirs{$dirName};
            }
        }
    }
    return (\%addDirHash, \%editDirHash) if wantarray;
    return \%addDirHash;
}

#------------------------------------------------------------------------------
# Get localized version of tagInfo hash (used by MIE, XMP, PNG and QuickTime)
# Inputs: 0) tagInfo hash ref, 1) locale code (eg. "en_CA" for MIE)
# Returns: new tagInfo hash ref, or undef if invalid
# - sets LangCode member in new tagInfo
sub GetLangInfo($$)
{
    my ($tagInfo, $langCode) = @_;
    # make a new tagInfo hash for this locale
    my $table = $$tagInfo{Table};
    my $tagID = $$tagInfo{TagID} . '-' . $langCode;
    my $langInfo = $$table{$tagID};
    unless ($langInfo) {
        # make a new tagInfo entry for this locale
        $langInfo = {
            %$tagInfo,
            Name => $$tagInfo{Name} . '-' . $langCode,
            Description => Image::ExifTool::MakeDescription($$tagInfo{Name}) .
                           " ($langCode)",
            LangCode => $langCode,
            SrcTagInfo => $tagInfo, # save reference to original tagInfo
        };
        AddTagToTable($table, $tagID, $langInfo);
    }
    return $langInfo;
}

#------------------------------------------------------------------------------
# initialize ADD_DIRS and EDIT_DIRS hashes for all directories that need
# to be created or will have tags changed in them
# Inputs: 0) ExifTool object reference, 1) file type string (or map hash ref)
#         2) preferred family 0 group name for creating tags
# Notes:
# - the ADD_DIRS and EDIT_DIRS keys are the directory names, and the values
#   are the names of the parent directories (undefined for a top-level directory)
# - also initializes FORCE_WRITE lookup
sub InitWriteDirs($$;$)
{
    my ($self, $fileType, $preferredGroup) = @_;
    my $editDirs = $$self{EDIT_DIRS} = { };
    my $addDirs = $$self{ADD_DIRS} = { };
    my $fileDirs = $dirMap{$fileType};
    unless ($fileDirs) {
        return unless ref $fileType eq 'HASH';
        $fileDirs = $fileType;
    }
    my @tagInfoList = $self->GetNewTagInfoList();
    my ($tagInfo, $nvHash);

    # save the preferred group
    $$self{PreferredGroup} = $preferredGroup;

    foreach $tagInfo (@tagInfoList) {
        # cycle through all hashes in linked list
        for ($nvHash=$self->GetNewValueHash($tagInfo); $nvHash; $nvHash=$$nvHash{Next}) {
            # are we creating this tag? (otherwise just deleting or editing it)
            my $isCreating = $$nvHash{IsCreating};
            if ($isCreating) {
                # if another group is taking priority, only create
                # directory if specifically adding tags to this group
                # or if this tag isn't being added to the priority group
                $isCreating = 0 if $preferredGroup and
                    $preferredGroup ne $self->GetGroup($tagInfo, 0) and
                    $$nvHash{CreateGroups}{$preferredGroup};
            } else {
                # creating this directory if any tag is preferred and has a value
                $isCreating = 1 if ($preferredGroup and $$nvHash{Value} and
                    $preferredGroup eq $self->GetGroup($tagInfo, 0)) and
                    not $$nvHash{EditOnly};
            }
            # tag belongs to directory specified by WriteGroup, or by
            # the Group0 name if WriteGroup not defined
            my $dirName = $$nvHash{WriteGroup};
            # remove MIE copy number(s) if they exist
            if ($dirName =~ /^MIE\d*(-[a-z]+)?\d*$/i) {
                $dirName = 'MIE' . ($1 || '');
            }
            my @dirNames;
            # allow a group name of '*' to force writing EXIF/IPTC/XMP (ForceWrite tag)
            if ($dirName eq '*' and $$nvHash{Value}) {
                my $val = $$nvHash{Value}[0];
                if ($val) {
                    foreach (qw(EXIF IPTC XMP FixBase)) {
                        next unless $val =~ /\b($_|All)\b/i;
                        push @dirNames, $_;
                        push @dirNames, 'EXIF' if $_ eq 'FixBase';
                        $$self{FORCE_WRITE}{$_} = 1;
                    }
                }
                $dirName = shift @dirNames;
            }
            while ($dirName) {
                my $parent = $$fileDirs{$dirName};
                if (ref $parent) {
                    push @dirNames, reverse @$parent;
                    $parent = pop @dirNames;
                }
                $$editDirs{$dirName} = $parent;
                $$addDirs{$dirName} = $parent if $isCreating and $isCreating != 2;
                $dirName = $parent || shift @dirNames
            }
        }
    }
    if (%{$$self{DEL_GROUP}}) {
        # add delete groups to list of edited groups
        foreach (keys %{$$self{DEL_GROUP}}) {
            next if /^-/;   # ignore excluded groups
            my $dirName = $_;
            # translate necessary group 0 names
            $dirName = $translateWriteGroup{$dirName} if $translateWriteGroup{$dirName};
            # convert XMP group 1 names
            $dirName = 'XMP' if $dirName =~ /^XMP-/;
            my @dirNames;
            while ($dirName) {
                my $parent = $$fileDirs{$dirName};
                if (ref $parent) {
                    push @dirNames, reverse @$parent;
                    $parent = pop @dirNames;
                }
                $$editDirs{$dirName} = $parent;
                $dirName = $parent || shift @dirNames
            }
        }
    }
    # special case to edit JFIF to get resolutions if editing EXIF information
    if ($$editDirs{IFD0} and $$fileDirs{JFIF}) {
        $$editDirs{JFIF} = 'IFD1';
        $$editDirs{APP0} = undef;
    }

    if ($$self{OPTIONS}{Verbose}) {
        my $out = $$self{OPTIONS}{TextOut};
        print $out "  Editing tags in: ";
        foreach (sort keys %$editDirs) { print $out "$_ "; }
        print $out "\n";
        return unless $$self{OPTIONS}{Verbose} > 1;
        print $out "  Creating tags in: ";
        foreach (sort keys %$addDirs) { print $out "$_ "; }
        print $out "\n";
    }
}

#------------------------------------------------------------------------------
# Write an image directory
# Inputs: 0) ExifTool object reference, 1) source directory information reference
#         2) tag table reference, 3) optional reference to writing procedure
# Returns: New directory data or undefined on error (or empty string to delete directory)
sub WriteDirectory($$$;$)
{
    my ($self, $dirInfo, $tagTablePtr, $writeProc) = @_;
    my ($out, $nvHash);

    $tagTablePtr or return undef;
    $out = $$self{OPTIONS}{TextOut} if $$self{OPTIONS}{Verbose};
    # set directory name from default group0 name if not done already
    my $dirName = $$dirInfo{DirName};
    my $dataPt = $$dirInfo{DataPt};
    my $grp0 = $$tagTablePtr{GROUPS}{0};
    $dirName or $dirName = $$dirInfo{DirName} = $grp0;
    if (%{$$self{DEL_GROUP}}) {
        my $delGroup = $$self{DEL_GROUP};
        # delete entire directory if specified
        my $grp1 = $dirName;
        my $delFlag = ($$delGroup{$grp0} or $$delGroup{$grp1});
        if ($delFlag) {
            unless ($blockExifTypes{$$self{FILE_TYPE}}) {
                # restrict delete logic to prevent entire tiff image from being killed
                # (don't allow IFD0 to be deleted, and delete only ExifIFD if EXIF specified)
                if ($$self{FILE_TYPE} eq 'PSD') {
                    # don't delete Photoshop directories from PSD image
                    undef $grp1 if $grp0 eq 'Photoshop';
                } elsif ($$self{FILE_TYPE} =~ /^(EPS|PS)$/) {
                    # allow anything to be deleted from PostScript files
                } elsif ($grp1 eq 'IFD0') {
                    my $type = $$self{TIFF_TYPE} || $$self{FILE_TYPE};
                    $$delGroup{IFD0} and $self->Warn("Can't delete IFD0 from $type",1);
                    undef $grp1;
                } elsif ($grp0 eq 'EXIF' and $$delGroup{$grp0}) {
                    undef $grp1 unless $$delGroup{$grp1} or $grp1 eq 'ExifIFD';
                }
            }
            if ($grp1) {
                if ($dataPt or $$dirInfo{RAF}) {
                    ++$$self{CHANGED};
                    $out and print $out "  Deleting $grp1\n";
                    # can no longer validate TIFF_END if deleting an entire IFD
                    delete $$self{TIFF_END} if $dirName =~ /IFD/;
                }
                # don't add back into the wrong location
                my $right = $$self{ADD_DIRS}{$grp1};
                # (take care because EXIF directory name may be either EXIF or IFD0,
                #  but IFD0 will be the one that appears in the directory map)
                $right = $$self{ADD_DIRS}{IFD0} if not $right and $grp1 eq 'EXIF';
                if ($delFlag == 2 and $right) {
                    # also check grandparent because some routines create 2 levels in 1
                    my $right2 = $$self{ADD_DIRS}{$right} || '';
                    my $parent = $$dirInfo{Parent};
                    if (not $parent or $parent eq $right or $parent eq $right2) {
                        # prevent duplicate directories from being recreated at the same path
                        my $path = join '-', @{$$self{PATH}}, $dirName;
                        $$self{Recreated} or $$self{Recreated} = { };
                        if ($$self{Recreated}{$path}) {
                            my $p = $parent ? " in $parent" : '';
                            $self->Warn("Not recreating duplicate $grp1$p",1);
                            return '';
                        }
                        $$self{Recreated}{$path} = 1;
                        # empty the directory
                        my $data = '';
                        $$dirInfo{DataPt}   = \$data;
                        $$dirInfo{DataLen}  = 0;
                        $$dirInfo{DirStart} = 0;
                        $$dirInfo{DirLen}   = 0;
                        delete $$dirInfo{RAF};
                        delete $$dirInfo{Base};
                        delete $$dirInfo{DataPos};
                    } else {
                        $self->Warn("Not recreating $grp1 in $parent (should be in $right)",1);
                        return '';
                    }
                } else {
                    return '' unless $$dirInfo{NoDelete};
                }
            }
        }
    }
    # use default proc from tag table if no proc specified
    $writeProc or $writeProc = $$tagTablePtr{WRITE_PROC} or return undef;

    # are we rewriting a pre-existing directory?
    my $isRewriting = ($$dirInfo{DirLen} or (defined $dataPt and length $$dataPt) or $$dirInfo{RAF});

    # copy or delete new directory as a block if specified
    my $blockName = $dirName;
    $blockName = 'EXIF' if $blockName eq 'IFD0';
    my $tagInfo = $Image::ExifTool::Extra{$blockName} || $$dirInfo{TagInfo};
    while ($tagInfo and ($nvHash = $$self{NEW_VALUE}{$tagInfo}) and
        $self->IsOverwriting($nvHash) and not ($$nvHash{CreateOnly} and $isRewriting))
    {
        # protect against writing EXIF to wrong file types, etc
        if ($blockName eq 'EXIF') {
            unless ($blockExifTypes{$$self{FILE_TYPE}}) {
                $self->Warn("Can't write EXIF as a block to $$self{FILE_TYPE} file");
                last;
            }
            # this can happen if we call WriteDirectory for an EXIF directory without  going
            # through WriteTIFF as the WriteProc (which happens if conditionally replacing
            # the EXIF block and the condition fails), but we never want to do a block write
            # in this case because the EXIF block would end up with two TIFF headers
            last unless $writeProc eq \&Image::ExifTool::WriteTIFF;
        }
        last unless $self->IsOverwriting($nvHash, $dataPt ? $$dataPt : '');
        my $verb = 'Writing';
        my $newVal = $self->GetNewValue($nvHash);
        unless (defined $newVal and length $newVal) {
            return '' unless $dataPt or $$dirInfo{RAF}; # nothing to do if block never existed
            $verb = 'Deleting';
            $newVal = '';
        }
        $$dirInfo{BlockWrite} = 1;  # set flag indicating we did a block write
        $out and print $out "  $verb $blockName as a block\n";
        ++$$self{CHANGED};
        return $newVal;
    }
    # guard against writing the same directory twice
    if (defined $dataPt and defined $$dirInfo{DirStart} and defined $$dirInfo{DataPos}) {
        my $addr = $$dirInfo{DirStart} + $$dirInfo{DataPos} + ($$dirInfo{Base}||0) + $$self{BASE};
        # (Phase One P25 IIQ files have ICC_Profile duplicated in IFD0 and IFD1)
        if ($$self{PROCESSED}{$addr} and ($dirName ne 'ICC_Profile' or $$self{TIFF_TYPE} ne 'IIQ')) {
            if (defined $$dirInfo{DirLen} and not $$dirInfo{DirLen} and $dirName ne $$self{PROCESSED}{$addr}) {
                # it is hypothetically possible to have 2 different directories
                # with the same address if one has a length of zero
            } elsif ($self->Error("$dirName pointer references previous $$self{PROCESSED}{$addr} directory", 2)) {
                return undef;
            } else {
                $self->Warn("Deleting duplicate $dirName directory");
                $out and print $out "  Deleting $dirName\n";
                # delete the duplicate directory (don't recreate it when writing new
                # tags to prevent propagating a duplicate IFD in cases like when the
                # same ExifIFD exists in both IFD0 and IFD1)
                return '';
            }
        } else {
            $$self{PROCESSED}{$addr} = $dirName;
        }
    }
    my $oldDir = $$self{DIR_NAME};
    my @save = @$self{'Compression','SubfileType'};
    my $name;
    if ($out) {
        $name = ($dirName eq 'MakerNotes' and $$dirInfo{TagInfo}) ?
                 $$dirInfo{TagInfo}{Name} : $dirName;
        if (not defined $oldDir or $oldDir ne $name) {
            my $verb = $isRewriting ? 'Rewriting' : 'Creating';
            print $out "  $verb $name\n";
        }
    }
    my $saveOrder = GetByteOrder();
    my $oldChanged = $$self{CHANGED};
    $$self{DIR_NAME} = $dirName;
    push @{$$self{PATH}}, $dirName;
    $$dirInfo{IsWriting} = 1;
    my $newData = &$writeProc($self, $dirInfo, $tagTablePtr);
    pop @{$$self{PATH}};
    # nothing changed if error occurred or nothing was created
    $$self{CHANGED} = $oldChanged unless defined $newData and (length($newData) or $isRewriting);
    $$self{DIR_NAME} = $oldDir;
    @$self{'Compression','SubfileType'} = @save;
    SetByteOrder($saveOrder);
    print $out "  Deleting $name\n" if $out and defined $newData and not length $newData;
    return $newData;
}

#------------------------------------------------------------------------------
# Uncommon utility routines to for reading binary data values
# Inputs: 0) data reference, 1) offset into data
sub Get64s($$)
{
    my ($dataPt, $pos) = @_;
    my $pt = GetByteOrder() eq 'MM' ? 0 : 4;    # get position of high word
    my $hi = Get32s($dataPt, $pos + $pt);       # preserve sign bit of high word
    my $lo = Get32u($dataPt, $pos + 4 - $pt);
    return $hi * 4294967296 + $lo;
}
sub Get64u($$)
{
    my ($dataPt, $pos) = @_;
    my $pt = GetByteOrder() eq 'MM' ? 0 : 4;    # get position of high word
    my $hi = Get32u($dataPt, $pos + $pt);       # (unsigned this time)
    my $lo = Get32u($dataPt, $pos + 4 - $pt);
    return $hi * 4294967296 + $lo;
}
sub GetFixed64s($$)
{
    my ($dataPt, $pos) = @_;
    my $val = Get64s($dataPt, $pos) / 4294967296;
    # remove insignificant digits
    return int($val * 1e10 + ($val>0 ? 0.5 : -0.5)) / 1e10;
}
# Decode extended 80-bit float used by Apple SANE and Intel 8087
# (note: different than the IEEE standard 80-bit float)
sub GetExtended($$)
{
    my ($dataPt, $pos) = @_;
    my $pt = GetByteOrder() eq 'MM' ? 0 : 2;    # get position of exponent
    my $exp = Get16u($dataPt, $pos + $pt);
    my $sig = Get64u($dataPt, $pos + 2 - $pt);  # get significand as int64u
    my $sign = $exp & 0x8000 ? -1 : 1;
    $exp = ($exp & 0x7fff) - 16383 - 63; # (-63 to fractionalize significand)
    return $sign * $sig * 2 ** $exp;
}

#------------------------------------------------------------------------------
# Dump data in hex and ASCII to console
# Inputs: 0) data reference, 1) length or undef, 2-N) Options:
# Options: Start => offset to start of data (default=0)
#          Addr => address to print for data start (default=DataPos+Base+Start)
#          DataPos => position of data within block (relative to Base)
#          Base => base offset for pointers from start of file
#          Width => width of printout (bytes, default=16)
#          Prefix => prefix to print at start of line (default='')
#          MaxLen => maximum length to dump
#          Out => output file reference
#          Len => data length
sub HexDump($;$%)
{
    my $dataPt = shift;
    my $len    = shift;
    my %opts   = @_;
    my $start  = $opts{Start}  || 0;
    my $addr   = $opts{Addr};
    my $wid    = $opts{Width}  || 16;
    my $prefix = $opts{Prefix} || '';
    my $out    = $opts{Out}    || \*STDOUT;
    my $maxLen = $opts{MaxLen};
    my $datLen = length($$dataPt) - $start;
    my $more;
    $len = $opts{Len} if defined $opts{Len};

    $addr = $start + ($opts{DataPos} || 0) + ($opts{Base} || 0) unless defined $addr;
    $len = $datLen unless defined $len;
    if ($maxLen and $len > $maxLen) {
        # print one line less to allow for $more line below
        $maxLen = int(($maxLen - 1) / $wid) * $wid;
        $more = $len - $maxLen;
        $len = $maxLen;
    }
    if ($len > $datLen) {
        print $out "$prefix    Warning: Attempted dump outside data\n";
        print $out "$prefix    ($len bytes specified, but only $datLen available)\n";
        $len = $datLen;
    }
    my $format = sprintf("%%-%ds", $wid * 3);
    my $tmpl = 'H2' x $wid; # ('(H2)*' would have been nice, but older perl versions don't support it)
    my $i;
    for ($i=0; $i<$len; $i+=$wid) {
        $wid > $len-$i and $wid = $len-$i, $tmpl = 'H2' x $wid;
        printf $out "$prefix%8.4x: ", $addr+$i;
        my $dat = substr($$dataPt, $i+$start, $wid);
        my $s = join(' ', unpack($tmpl, $dat));
        printf $out $format, $s;
        $dat =~ tr /\x00-\x1f\x7f-\xff/./;
        print $out "[$dat]\n";
    }
    $more and print $out "$prefix    [snip $more bytes]\n";
}

#------------------------------------------------------------------------------
# Print verbose tag information
# Inputs: 0) ExifTool object reference, 1) tag ID
#         2) tag info reference (or undef)
#         3-N) extra parms:
# Parms: Index => Index of tag in menu (starting at 0)
#        Value => Tag value
#        DataPt => reference to value data block
#        DataPos => location of data block in file
#        Base => base added to all offsets
#        Size => length of value data within block
#        Format => value format string
#        Count => number of values
#        Extra => Extra Verbose=2 information to put after tag number
#        Table => Reference to tag table
#        --> plus any of these HexDump() options: Start, Addr, Width
sub VerboseInfo($$$%)
{
    my ($self, $tagID, $tagInfo, %parms) = @_;
    my $verbose = $$self{OPTIONS}{Verbose};
    my $out = $$self{OPTIONS}{TextOut};
    my ($tag, $line, $hexID);

    # generate hex number if tagID is numerical
    if (defined $tagID) {
        $tagID =~ /^\d+$/ and $hexID = sprintf("0x%.4x", $tagID);
    } else {
        $tagID = 'Unknown';
    }
    # get tag name
    if ($tagInfo and $$tagInfo{Name}) {
        $tag = $$tagInfo{Name};
    } else {
        my $prefix;
        $prefix = $parms{Table}{TAG_PREFIX} if $parms{Table};
        if ($prefix or $hexID) {
            $prefix = 'Unknown' unless $prefix;
            $tag = $prefix . '_' . ($hexID ? $hexID : $tagID);
        } else {
            $tag = $tagID;
        }
    }
    my $dataPt = $parms{DataPt};
    my $size = $parms{Size};
    $size = length $$dataPt unless defined $size or not $dataPt;
    my $indent = $$self{INDENT};

    # Level 1: print tag/value information
    $line = $indent;
    my $index = $parms{Index};
    if (defined $index) {
        $line .= $index . ') ';
        $line .= ' ' if length($index) < 2;
        $indent .= '    '; # indent everything else to align with tag name
    }
    $line .= $tag;
    if ($tagInfo and $$tagInfo{SubDirectory}) {
        $line .= ' (SubDirectory) -->';
    } else {
        my $maxLen = 90 - length($line);
        my $val = $parms{Value};
        if (defined $val) {
            $val = '[' . join(',',@$val) . ']' if ref $val eq 'ARRAY';
            $line .= ' = ' . $self->Printable($val, $maxLen);
        } elsif ($dataPt) {
            my $start = $parms{Start} || 0;
            $line .= ' = ' . $self->Printable(substr($$dataPt,$start,$size), $maxLen);
        }
    }
    print $out "$line\n";

    # Level 2: print detailed information about the tag
    if ($verbose > 1 and ($parms{Extra} or $parms{Format} or
        $parms{DataPt} or defined $size or $tagID =~ /\//))
    {
        $line = $indent . '- Tag ';
        if ($hexID) {
            $line .= $hexID;
        } else {
            $tagID =~ s/([\0-\x1f\x7f-\xff])/sprintf('\\x%.2x',ord $1)/ge;
            $line .= "'${tagID}'";
        }
        $line .= $parms{Extra} if defined $parms{Extra};
        my $format = $parms{Format};
        if ($format or defined $size) {
            $line .= ' (';
            if (defined $size) {
                $line .= "$size bytes";
                $line .= ', ' if $format;
            }
            if ($format) {
                $line .= $format;
                $line .= '['.$parms{Count}.']' if $parms{Count};
            }
            $line .= ')';
        }
        $line .= ':' if $verbose > 2 and $parms{DataPt};
        print $out "$line\n";
    }

    # Level 3: do hex dump of value
    if ($verbose > 2 and $parms{DataPt} and (not $tagInfo or not $$tagInfo{ReadFromRAF})) {
        $parms{Out} = $out;
        $parms{Prefix} = $indent;
        # limit dump length if Verbose < 5
        $parms{MaxLen} = $verbose == 3 ? 96 : 2048 if $verbose < 5;
        HexDump($dataPt, $size, %parms);
    }
}

#------------------------------------------------------------------------------
# Dump trailer information
# Inputs: 0) ExifTool object ref, 1) dirInfo hash (RAF, DirName, DataPos, DirLen)
# Notes: Restores current file position before returning
sub DumpTrailer($$)
{
    my ($self, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my $curPos = $raf->Tell();
    my $trailer = $$dirInfo{DirName} || 'Unknown';
    my $pos = $$dirInfo{DataPos};
    my $verbose = $$self{OPTIONS}{Verbose};
    my $htmlDump = $$self{HTML_DUMP};
    my ($buff, $buf2);
    my $size = $$dirInfo{DirLen};
    $pos = $curPos unless defined $pos;

    # get full trailer size if not specified
    for (;;) {
        unless ($size) {
            $raf->Seek(0, 2) or last;
            $size = $raf->Tell() - $pos;
            last unless $size;
        }
        $raf->Seek($pos, 0) or last;
        if ($htmlDump) {
            my $num = $raf->Read($buff, $size) or return;
            my $desc = "$trailer trailer";
            $desc = "[$desc]" if $trailer eq 'Unknown';
            $self->HDump($pos, $num, $desc, undef, 0x08);
            last;
        }
        my $out = $$self{OPTIONS}{TextOut};
        printf $out "$trailer trailer (%d bytes at offset 0x%.4x):\n", $size, $pos;
        last unless $verbose > 2;
        my $num = $size;    # number of bytes to read
        # limit size if not very verbose
        if ($verbose < 5) {
            my $limit = $verbose < 4 ? 96 : 512;
            $num = $limit if $num > $limit;
        }
        $raf->Read($buff, $num) == $num or return;
        # read the end of the trailer too if not done already
        if ($size > 2 * $num) {
            $raf->Seek($pos + $size - $num, 0);
            $raf->Read($buf2, $num);
        } elsif ($size > $num) {
            $raf->Seek($pos + $num, 0);
            $raf->Read($buf2, $size - $num);
            $buff .= $buf2;
            undef $buf2;
        }
        HexDump(\$buff, undef, Addr => $pos, Out => $out);
        if (defined $buf2) {
            print $out "    [snip ", $size - $num * 2, " bytes]\n";
            HexDump(\$buf2, undef, Addr => $pos + $size - $num, Out => $out);
        }
        last;
    }
    $raf->Seek($curPos, 0);
}

#------------------------------------------------------------------------------
# Dump unknown trailer information
# Inputs: 0) ExifTool ref, 1) dirInfo ref (with RAF, DataPos and DirLen defined)
# Notes: changes dirInfo elements
sub DumpUnknownTrailer($$)
{
    my ($self, $dirInfo) = @_;
    my $pos = $$dirInfo{DataPos};
    my $endPos = $pos + $$dirInfo{DirLen};
    # account for preview/MPF image trailer
    my $prePos = $$self{VALUE}{PreviewImageStart} || $$self{PreviewImageStart};
    my $preLen = $$self{VALUE}{PreviewImageLength} || $$self{PreviewImageLength};
    my $tag = 'PreviewImage';
    my $mpImageNum = 0;
    my (%image, $lastOne);
    for (;;) {
        # add to Preview block list if valid and in the trailer
        $image{$prePos} = [$tag, $preLen] if $prePos and $preLen and $prePos+$preLen > $pos;
        last if $lastOne;   # checked all images
        # look for MPF images (in the the proper order)
        ++$mpImageNum;
        $prePos = $$self{VALUE}{"MPImageStart ($mpImageNum)"};
        if (defined $prePos) {
            $preLen = $$self{VALUE}{"MPImageLength ($mpImageNum)"};
        } else {
            $prePos = $$self{VALUE}{'MPImageStart'};
            $preLen = $$self{VALUE}{'MPImageLength'};
            $lastOne = 1;
        }
        $tag = "MPImage$mpImageNum";
    }
    # dump trailer sections in order
    $image{$endPos} = [ '', 0 ];    # add terminator "image"
    foreach $prePos (sort { $a <=> $b } keys %image) {
        if ($pos < $prePos) {
            # dump unknown trailer data
            $$dirInfo{DirName} = 'Unknown';
            $$dirInfo{DataPos} = $pos;
            $$dirInfo{DirLen} = $prePos - $pos;
            $self->DumpTrailer($dirInfo);
        }
        ($tag, $preLen) = @{$image{$prePos}};
        last unless $preLen;
        # dump image if verbose (it is htmlDump'd by ExtractImage)
        if ($$self{OPTIONS}{Verbose}) {
            $$dirInfo{DirName} = $tag;
            $$dirInfo{DataPos} = $prePos;
            $$dirInfo{DirLen}  = $preLen;
            $self->DumpTrailer($dirInfo);
        }
        $pos = $prePos + $preLen;
    }
}

#------------------------------------------------------------------------------
# Find last element in linked list
# Inputs: 0) element in list
# Returns: Last element in list
sub LastInList($)
{
    my $element = shift;
    while ($$element{Next}) {
        $element = $$element{Next};
    }
    return $element;
}

#------------------------------------------------------------------------------
# Print verbose value while writing
# Inputs: 0) ExifTool object ref, 1) heading "eg. '+ IPTC:Keywords',
#         2) value, 3) [optional] extra text after value
sub VerboseValue($$$;$)
{
    return unless $_[0]{OPTIONS}{Verbose} > 1;
    my ($self, $str, $val, $xtra) = @_;
    my $out = $$self{OPTIONS}{TextOut};
    $xtra or $xtra = '';
    my $maxLen = 81 - length($str) - length($xtra);
    $val = $self->Printable($val, $maxLen);
    print $out "    $str = '${val}'$xtra\n";
}

#------------------------------------------------------------------------------
# Pack Unicode numbers into UTF8 string
# Inputs: 0-N) list of Unicode numbers
# Returns: Packed UTF-8 string
sub PackUTF8(@)
{
    my @out;
    while (@_) {
        my $ch = pop;
        unshift(@out, $ch), next if $ch < 0x80;
        unshift(@out, 0x80 | ($ch & 0x3f));
        $ch >>= 6;
        unshift(@out, 0xc0 | $ch), next if $ch < 0x20;
        unshift(@out, 0x80 | ($ch & 0x3f));
        $ch >>= 6;
        unshift(@out, 0xe0 | $ch), next if $ch < 0x10;
        unshift(@out, 0x80 | ($ch & 0x3f));
        $ch >>= 6;
        unshift(@out, 0xf0 | ($ch & 0x07));
    }
    return pack('C*', @out);
}

#------------------------------------------------------------------------------
# Unpack numbers from UTF8 string
# Inputs: 0) UTF-8 string
# Returns: List of Unicode numbers (sets $evalWarning on error)
sub UnpackUTF8($)
{
    my (@out, $pos);
    pos($_[0]) = $pos = 0;  # start at beginning of string
    for (;;) {
        my ($ch, $newPos, $val, $byte);
        if ($_[0] =~ /([\x80-\xff])/g) {
            $ch = ord($1);
            $newPos = pos($_[0]) - 1;
        } else {
            $newPos = length $_[0];
        }
        # unpack 7-bit characters
        my $len = $newPos - $pos;
        push @out, unpack("x${pos}C$len",$_[0]) if $len;
        last unless defined $ch;
        $pos = $newPos + 1;
        # minimum lead byte for 2-byte sequence is 0xc2 (overlong sequences
        # not allowed), 0xf8-0xfd are restricted by RFC 3629 (no 5 or 6 byte
        # sequences), and 0xfe and 0xff are not valid in UTF-8 strings
        if ($ch < 0xc2 or $ch >= 0xf8) {
            push @out, ord('?');    # invalid UTF-8
            $evalWarning = 'Bad UTF-8';
            next;
        }
        # decode 2, 3 and 4-byte sequences
        my $n = 1;
        if ($ch < 0xe0) {
            $val = $ch & 0x1f;      # 2-byte sequence
        } elsif ($ch < 0xf0) {
            $val = $ch & 0x0f;      # 3-byte sequence
            ++$n;
        } else {
            $val = $ch & 0x07;      # 4-byte sequence
            $n += 2;
        }
        unless ($_[0] =~ /\G([\x80-\xbf]{$n})/g) {
            pos($_[0]) = $pos;      # restore position
            push @out, ord('?');    # invalid UTF-8
            $evalWarning = 'Bad UTF-8';
            next;
        }
        foreach $byte (unpack 'C*', $1) {
            $val = ($val << 6) | ($byte & 0x3f);
        }
        push @out, $val;    # save Unicode character value
        $pos += $n;         # position at end of UTF-8 character
    }
    return @out;
}

#------------------------------------------------------------------------------
# Generate a new, random GUID
# Inputs: <none>
# Returns: GUID string
my $guidCount;
sub NewGUID()
{
    my @tm = localtime time;
    $guidCount = 0 unless defined $guidCount and ++$guidCount < 0x100;
    return sprintf('%.4d%.2d%.2d%.2d%.2d%.2d%.2X%.4X%.4X%.4X%.4X',
                   $tm[5]+1900, $tm[4]+1, $tm[3], $tm[2], $tm[1], $tm[0], $guidCount,
                   $$ & 0xffff, rand(0x10000), rand(0x10000), rand(0x10000));
}

#------------------------------------------------------------------------------
# Make TIFF header for raw data
# Inputs: 0) width, 1) height, 2) num colour components, 3) bits, 4) resolution
#         5) color-map data for palette-color image (8 or 16 bit)
# Returns: TIFF header
# Notes: Multi-byte data must be little-endian
sub MakeTiffHeader($$$$;$$)
{
    my ($w, $h, $cols, $bits, $res, $cmap) = @_;
    $res or $res = 72;
    my $saveOrder = GetByteOrder();
    SetByteOrder('II');
    if (not $cmap) {
        $cmap = '';
    } elsif (length $cmap == 3 * 2**$bits) {
        # convert to short
        $cmap = pack 'v*', map { $_ | ($_<<8) } unpack 'C*', $cmap;
    } elsif (length $cmap != 6 * 2**$bits) {
        $cmap = '';
    }
    my $cmo = $cmap ? 12 : 0;   # offset due to ColorMap IFD entry
    my $hdr =
    "\x49\x49\x2a\0\x08\0\0\0\x0e\0" .                  # 0x00 14 menu entries:
    "\xfe\x00\x04\0\x01\0\0\0\x00\0\0\0" .              # 0x0a SubfileType = 0
    "\x00\x01\x04\0\x01\0\0\0" . Set32u($w) .           # 0x16 ImageWidth
    "\x01\x01\x04\0\x01\0\0\0" . Set32u($h) .           # 0x22 ImageHeight
    "\x02\x01\x03\0" . Set32u($cols) .                  # 0x2e BitsPerSample
     Set32u($cols == 1 ? $bits : 0xb6 + $cmo) .
    "\x03\x01\x03\0\x01\0\0\0\x01\0\0\0" .              # 0x3a Compression = 1
    "\x06\x01\x03\0\x01\0\0\0" .                        # 0x46 PhotometricInterpretation
     Set32u($cmap ? 3 : $cols == 1 ? 1 : 2) .
    "\x11\x01\x04\0\x01\0\0\0" .                        # 0x52 StripOffsets
     Set32u(0xcc + $cmo + length($cmap)) .
    "\x15\x01\x03\0\x01\0\0\0" . Set32u($cols) .        # 0x5e SamplesPerPixel
    "\x16\x01\x04\0\x01\0\0\0" . Set32u($h) .           # 0x6a RowsPerStrip
    "\x17\x01\x04\0\x01\0\0\0" .                        # 0x76 StripByteCounts
     Set32u($w * $h * $cols * int(($bits+7)/8)) .
    "\x1a\x01\x05\0\x01\0\0\0" . Set32u(0xbc + $cmo) .  # 0x82 XResolution
    "\x1b\x01\x05\0\x01\0\0\0" . Set32u(0xc4 + $cmo) .  # 0x8e YResolution
    "\x1c\x01\x03\0\x01\0\0\0\x01\0\0\0" .              # 0x9a PlanarConfiguration = 1
    "\x28\x01\x03\0\x01\0\0\0\x02\0\0\0" .              # 0xa6 ResolutionUnit = 2
    ($cmap ?                                            # 0xb2 ColorMap [optional]
    "\x40\x01\x03\0" . Set32u(3 * 2**$bits) . "\xd8\0\0\0" : '') .
    "\0\0\0\0" .                                        # 0xb2+$cmo (no IFD1)
    (Set16u($bits) x 3) .                               # 0xb6+$cmo BitsPerSample value
    Set32u($res) . "\x01\0\0\0" .                       # 0xbc+$cmo XResolution = 72
    Set32u($res) . "\x01\0\0\0" .                       # 0xc4+$cmo YResolution = 72
    $cmap;                                              # 0xcc or 0xd8 (cmap and data go here)
    SetByteOrder($saveOrder);
    return $hdr;
}

#------------------------------------------------------------------------------
# Return current time in EXIF format
# Inputs: 0) [optional] ExifTool ref, 1) flag to include timezone (0 to disable,
#            undef or 1 to include)
# Returns: time string
# - a consistent value is returned for each processed file
sub TimeNow(;$$)
{
    my ($self, $tzFlag) = @_;
    my $timeNow;
    ref $self or $tzFlag = $self, $self = { };
    if ($$self{Now}) {
        $timeNow = $$self{Now}[0];
    } else {
        my $time = time();
        my @tm = localtime $time;
        my $tz = TimeZoneString(\@tm, $time);
        $timeNow = sprintf("%4d:%.2d:%.2d %.2d:%.2d:%.2d",
                    $tm[5]+1900, $tm[4]+1, $tm[3],
                    $tm[2], $tm[1], $tm[0]);
        $$self{Now} = [ $timeNow, $tz ];
    }
    $timeNow .= $$self{Now}[1] if $tzFlag or not defined $tzFlag;
    return $timeNow;
}

#------------------------------------------------------------------------------
# Inverse date/time print conversion (reformat to YYYY:mm:dd HH:MM:SS[.ss][+-HH:MM|Z])
# Inputs: 0) ExifTool object ref, 1) Date/Time string, 2) timezone flag:
#               0     - remove timezone and sub-seconds if they exist
#               1     - add timezone if it doesn't exist
#               undef - leave timezone alone
#         3) flag to allow date-only (YYYY, YYYY:mm or YYYY:mm:dd) or time without seconds
# Returns: formatted date/time string (or undef and issues warning on error)
# Notes: currently accepts different separators, but doesn't use DateFormat yet
my $strptimeLib; # strptime library name if available
sub InverseDateTime($$;$$)
{
    my ($self, $val, $tzFlag, $dateOnly) = @_;
    my ($rtnVal, $tz);
    # strip off timezone first if it exists
    if ($val =~ s/([+-])(\d{1,2}):?(\d{2})\s*$//i) {
        $tz = sprintf("$1%.2d:$3", $2);
    } elsif ($val =~ s/Z$//i) {
        $tz = 'Z';
    } else {
        $tz = '';
        # allow special value of 'now'
        return $self->TimeNow($tzFlag) if lc($val) eq 'now';
    }
    my $fmt = $$self{OPTIONS}{DateFormat};
    # only convert date if a format was specified and the date is recognizable
    if ($fmt) {
        unless (defined $strptimeLib) {
            if (eval { require POSIX::strptime }) {
                $strptimeLib = 'POSIX::strptime';
            } elsif (eval { require Time::Piece }) {
                $strptimeLib = 'Time::Piece';
                # (call use_locale() to convert localized date/time,
                #  only available in Time::Piece 1.32 and later)
                eval { Time::Piece->use_locale() };
            } else {
                $strptimeLib = '';
            }
        }
        my ($lib, $wrn, @a);
TryLib: for ($lib=$strptimeLib; ; $lib='') {
            if (not $lib) {
                last unless $$self{OPTIONS}{StrictDate};
                warn $wrn || "Install POSIX::strptime or Time::Piece for inverse date/time conversions\n";
                return undef;
            } elsif ($lib eq 'POSIX::strptime') {
                @a = eval { POSIX::strptime($val, $fmt) };
            } else {
                @a = eval {
                    my $t = Time::Piece->strptime($val, $fmt);
                    return ($t->sec, $t->min, $t->hour, $t->mday, $t->_mon, $t->_year);
                };
            }
            if (defined $a[5] and length $a[5]) {
                $a[5] += 1900; # add 1900 to year
            } else {
                $wrn = "Invalid date/time (no year) using $lib\n";
                next;
            }
            ++$a[4] if defined $a[4] and length $a[4];  # add 1 to month
            my $i;
            foreach $i (0..4) {
                if (not defined $a[$i] or not length $a[$i]) {
                    if ($i < 2 or $dateOnly) { # (allow missing minutes/seconds)
                        $a[$i] = '  ';
                    } else {
                        $wrn = "Incomplete date/time specification using $lib\n";
                        next TryLib;
                    }
                } elsif (length($a[$i]) < 2) {
                    $$a[$i] = "0$a[$i]";# pad to 2 digits if necessary
                }
            }
            $val = join(':', @a[5,4,3]) . ' ' . join(':', @a[2,1,0]);
            last;
        }
    }
    if ($val =~ /(\d{4})/g) {           # get YYYY
        my $yr = $1;
        my @a = ($val =~ /\d{1,2}/g);   # get mm, dd, HH, and maybe MM, SS
        length($_) < 2 and $_ = "0$_" foreach @a;   # pad to 2 digits if necessary
        if (@a >= 3) {
            my $ss = $a[4];             # get SS
            push @a, '00' while @a < 5; # add MM, SS if not given
            # get sub-seconds if they exist (must be after SS, and have leading ".")
            my $fs = (@a > 5 and $val =~ /(\.\d+)\s*$/) ? $1 : '';
            # add/remove timezone if necessary
            if ($tzFlag) {
                if (not $tz) {
                    if (eval { require Time::Local }) {
                        # determine timezone offset for this time
                        my @args = ($a[4],$a[3],$a[2],$a[1],$a[0]-1,$yr-1900);
                        my $diff = Time::Local::timegm(@args) - TimeLocal(@args);
                        $tz = TimeZoneString($diff / 60);
                    } else {
                        $tz = 'Z';  # don't know time zone
                    }
                }
            } elsif (defined $tzFlag) {
                $tz = $fs = ''; # remove timezone and sub-seconds
            }
            if (defined $ss) {
                $ss = ":$ss";
            } elsif ($dateOnly) {
                $ss = '';
            } else {
                $ss = ':00';
            }
            # construct properly formatted date/time string
            $rtnVal = "$yr:$a[0]:$a[1] $a[2]:$a[3]$ss$fs$tz";
        } elsif ($dateOnly) {
            $rtnVal = join ':', $yr, @a;
        }
    }
    $rtnVal or warn "Invalid date/time (use YYYY:mm:dd HH:MM:SS[.ss][+/-HH:MM|Z])\n";
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Set byte order according to our current preferences
# Inputs: 0) ExifTool object ref
# Returns: new byte order ('II' or 'MM') and sets current byte order
# Notes: takes the first of the following that is valid:
#  1) ByteOrder option
#  2) new value for ExifByteOrder
#  3) makenote byte order from last file read
#  4) big endian
sub SetPreferredByteOrder($)
{
    my $self = shift;
    my $byteOrder = $self->Options('ByteOrder') ||
                    $self->GetNewValue('ExifByteOrder') ||
                    $$self{MAKER_NOTE_BYTE_ORDER} || 'MM';
    unless (SetByteOrder($byteOrder)) {
        warn "Invalid byte order '${byteOrder}'\n" if $self->Options('Verbose');
        $byteOrder = $$self{MAKER_NOTE_BYTE_ORDER} || 'MM';
        SetByteOrder($byteOrder);
    }
    return GetByteOrder();
}

#------------------------------------------------------------------------------
# Assemble a continuing fraction into a rational value
# Inputs: 0) numerator, 1) denominator
#         2-N) list of fraction denominators, deepest first
# Returns: numerator, denominator (in list context)
sub AssembleRational($$@)
{
    @_ < 3 and return @_;
    my ($num, $denom, $frac) = splice(@_, 0, 3);
    return AssembleRational($frac*$num+$denom, $num, @_);
}

#------------------------------------------------------------------------------
# Convert a floating point number (or 'inf' or 'undef' or a fraction) into a rational
# Inputs: 0) floating point number, 1) optional maximum value (defaults to 0x7fffffff)
# Returns: numerator, denominator (in list context)
# Notes:
# - the returned rational will be accurate to at least 8 significant figures if possible
# - eg. an input of 3.14159265358979 returns a rational of 104348/33215,
#   which equals    3.14159265392142 and is accurate to 10 significant figures
# - the returned rational will be reduced to the lowest common denominator except when
#   the input is a fraction in which case the input is returned unchanged
# - these routines were a bit tricky, but fun to write!
sub Rationalize($;$)
{
    my $val = shift;
    return (1, 0) if $val eq 'inf';
    return (0, 0) if $val eq 'undef';
    return ($1,$2) if $val =~ m{^([-+]?\d+)/(\d+)$}; # accept fractional values
    # Note: Just testing "if $val" doesn't work because '0.0' is true!  (ugghh!)
    return (0, 1) if $val == 0;
    my $sign = $val < 0 ? ($val = -$val, -1) : 1;
    my ($num, $denom, @fracs);
    my $frac = $val;
    my $maxInt = shift || 0x7fffffff;
    for (;;) {
        my ($n, $d) = AssembleRational(int($frac + 0.5), 1, @fracs);
        if ($n > $maxInt or $d > $maxInt) {
            last if defined $num;
            return ($sign, $maxInt) if $val < 1;
            return ($sign * $maxInt, 1);
        }
        ($num, $denom) = ($n, $d);      # save last good values
        my $err = ($n/$d-$val) / $val;  # get error of this rational
        last if abs($err) < 1e-8;       # all done if error is small
        my $int = int($frac);
        unshift @fracs, $int;
        last unless $frac -= $int;
        $frac = 1 / $frac;
    }
    return ($num * $sign, $denom);
}

#------------------------------------------------------------------------------
# Utility routines to for writing binary data values
# Inputs: 0) value, 1) data ref, 2) offset
# Notes: prototype is (@) so values can be passed from list if desired
sub Set16s(@)
{
    my $val = shift;
    $val < 0 and $val += 0x10000;
    return Set16u($val, @_);
}
sub Set32s(@)
{
    my $val = shift;
    $val < 0 and $val += 0xffffffff, ++$val;
    return Set32u($val, @_);
}
sub Set64u(@)
{
    my $val = shift;
    my $hi = int($val / 4294967296);
    my $lo = Set32u($val - $hi * 4294967296);
    $hi = Set32u($hi);
    $val = GetByteOrder() eq 'MM' ? $hi . $lo : $lo . $hi;
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetRational64u(@) {
    my ($numer,$denom) = Rationalize($_[0],0xffffffff);
    my $val = Set32u($numer) . Set32u($denom);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetRational64s(@) {
    my ($numer,$denom) = Rationalize($_[0]);
    my $val = Set32s($numer) . Set32u($denom);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetRational32u(@) {
    my ($numer,$denom) = Rationalize($_[0],0xffff);
    my $val = Set16u($numer) . Set16u($denom);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetRational32s(@) {
    my ($numer,$denom) = Rationalize($_[0],0x7fff);
    my $val = Set16s($numer) . Set16u($denom);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetFixed16u(@) {
    my $val = int(shift() * 0x100 + 0.5);
    return Set16u($val, @_);
}
sub SetFixed16s(@) {
    my $val = shift;
    return Set16s(int($val * 0x100 + ($val < 0 ? -0.5 : 0.5)), @_);
}
sub SetFixed32u(@) {
    my $val = int(shift() * 0x10000 + 0.5);
    return Set32u($val, @_);
}
sub SetFixed32s(@) {
    my $val = shift;
    return Set32s(int($val * 0x10000 + ($val < 0 ? -0.5 : 0.5)), @_);
}
sub SetFloat(@) {
    my $val = SwapBytes(pack('f',$_[0]), 4);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
sub SetDouble(@) {
    # swap 32-bit words (ARM quirk) and bytes if necessary
    my $val = SwapBytes(SwapWords(pack('d',$_[0])), 8);
    $_[1] and substr(${$_[1]}, $_[2], length($val)) = $val;
    return $val;
}
#------------------------------------------------------------------------------
# hash lookups for writing binary data values
my %writeValueProc = (
    int8s => \&Set8s,
    int8u => \&Set8u,
    int16s => \&Set16s,
    int16u => \&Set16u,
    int16uRev => \&Set16uRev,
    int32s => \&Set32s,
    int32u => \&Set32u,
    int64u => \&Set64u,
    rational32s => \&SetRational32s,
    rational32u => \&SetRational32u,
    rational64s => \&SetRational64s,
    rational64u => \&SetRational64u,
    fixed16u => \&SetFixed16u,
    fixed16s => \&SetFixed16s,
    fixed32u => \&SetFixed32u,
    fixed32s => \&SetFixed32s,
    float => \&SetFloat,
    double => \&SetDouble,
    ifd => \&Set32u,
);
# verify that we can write floats on this platform
{
    my %writeTest = (
        float =>  [ -3.14159, 'c0490fd0' ],
        double => [ -3.14159, 'c00921f9f01b866e' ],
    );
    my $format;
    my $oldOrder = GetByteOrder();
    SetByteOrder('MM');
    foreach $format (keys %writeTest) {
        my ($val, $hex) = @{$writeTest{$format}};
        # add floating point entries if we can write them
        next if unpack('H*', &{$writeValueProc{$format}}($val)) eq $hex;
        delete $writeValueProc{$format};    # we can't write them
    }
    SetByteOrder($oldOrder);
}

#------------------------------------------------------------------------------
# write binary data value (with current byte ordering)
# Inputs: 0) value, 1) format string
#         2) number of values:
#               undef = 1 for numerical types, or data length for string/undef types
#                  -1 = number of space-delimited values in the input string
#         3) optional data reference, 4) value offset (may be negative for bytes from end)
# Returns: packed value (and sets value in data) or undef on error
# Notes: May modify input value to round for integer formats
sub WriteValue($$;$$$$)
{
    my ($val, $format, $count, $dataPt, $offset) = @_;
    my $proc = $writeValueProc{$format};
    my $packed;

    if ($proc) {
        my @vals = split(' ',$val);
        if ($count) {
            $count = @vals if $count < 0;
        } else {
            $count = 1;   # assume 1 if count not specified
        }
        $packed = '';
        while ($count--) {
            $val = shift @vals;
            return undef unless defined $val;
            # validate numerical formats
            if ($format =~ /^int/) {
                unless (IsInt($val) or IsHex($val)) {
                    return undef unless IsFloat($val);
                    # round to nearest integer
                    $val = int($val + ($val < 0 ? -0.5 : 0.5));
                    $_[0] = $val;
                }
            } elsif (not IsFloat($val)) {
                return undef unless $format =~ /^rational/ and ($val eq 'inf' or
                    $val eq 'undef' or IsRational($val));
            }
            $packed .= &$proc($val);
        }
    } elsif ($format eq 'string' or $format eq 'undef') {
        $format eq 'string' and $val .= "\0";   # null-terminate strings
        if ($count and $count > 0) {
            my $diff = $count - length($val);
            if ($diff) {
                #warn "wrong string length!\n";
                # adjust length of string to match specified count
                if ($diff < 0) {
                    if ($format eq 'string') {
                        return undef unless $count;
                        $val = substr($val, 0, $count - 1) . "\0";
                    } else {
                        $val = substr($val, 0, $count);
                    }
                } else {
                    $val .= "\0" x $diff;
                }
            }
        } else {
            $count = length($val);
        }
        $dataPt and substr($$dataPt, $offset, $count) = $val;
        return $val;
    } else {
        warn "Sorry, Can't write $format values on this platform\n";
        return undef;
    }
    $dataPt and substr($$dataPt, $offset, length($packed)) = $packed;
    return $packed;
}

#------------------------------------------------------------------------------
# Encode bit mask (the inverse of DecodeBits())
# Inputs: 0) value to encode, 1) Reference to hash for encoding (or undef)
#         2) optional number of bits per word (defaults to 32), 3) total bits
# Returns: bit mask or undef on error (plus error string in list context)
sub EncodeBits($$;$$)
{
    my ($val, $lookup, $bits, $num) = @_;
    $bits or $bits = 32;
    $num or $num = $bits;
    my $words = int(($num + $bits - 1) / $bits);
    my @outVal = (0) x $words;
    if ($val ne '(none)') {
        my @vals = split /\s*,\s*/, $val;
        foreach $val (@vals) {
            my $bit;
            if ($lookup) {
                $bit = ReverseLookup($val, $lookup);
                # (Note: may get non-numerical $bit values from Unknown() tags)
                unless (defined $bit) {
                    if ($val =~ /\[(\d+)\]/) { # numerical bit specification
                        $bit = $1;
                    } else {
                        # don't return error string unless more than one value
                        return undef unless @vals > 1 and wantarray;
                        return (undef, "no match for '${val}'");
                    }
                }
            } else {
                $bit = $val;
            }
            unless (IsInt($bit) and $bit < $num) {
                return undef unless wantarray;
                return (undef, IsInt($bit) ? 'bit number too high' : 'not an integer');
            }
            my $word = int($bit / $bits);
            $outVal[$word] |= (1 << ($bit - $word * $bits));
        }
    }
    return "@outVal";
}

#------------------------------------------------------------------------------
# get current position in output file (or end of file if a scalar reference)
# Inputs: 0) file or scalar reference
# Returns: Current position or -1 on error
sub Tell($)
{
    my $outfile = shift;
    if (UNIVERSAL::isa($outfile,'GLOB')) {
        return tell($outfile);
    } else {
        return length($$outfile);
    }
}

#------------------------------------------------------------------------------
# write to file or memory
# Inputs: 0) file or scalar reference, 1-N) list of stuff to write
# Returns: true on success
sub Write($@)
{
    my $outfile = shift;
    if (UNIVERSAL::isa($outfile,'GLOB')) {
        return print $outfile @_;
    } elsif (ref $outfile eq 'SCALAR') {
        $$outfile .= join('', @_);
        return 1;
    }
    return 0;
}

#------------------------------------------------------------------------------
# Write trailer buffer to file (applying fixups if necessary)
# Inputs: 0) ExifTool object ref, 1) trailer dirInfo ref, 2) output file ref
# Returns: 1 on success
sub WriteTrailerBuffer($$$)
{
    my ($self, $trailInfo, $outfile) = @_;
    if ($$self{DEL_GROUP}{Trailer}) {
        $self->VPrint(0, "  Deleting trailer ($$trailInfo{Offset} bytes)\n");
        ++$$self{CHANGED};
        return 1;
    }
    my $pos = Tell($outfile);
    my $trailPt = $$trailInfo{OutFile};
    # apply fixup if necessary (AFCP requires this)
    if ($$trailInfo{Fixup}) {
        if ($pos > 0) {
            # shift offsets to final AFCP location and write it out
            $$trailInfo{Fixup}{Shift} += $pos;
            $$trailInfo{Fixup}->ApplyFixup($trailPt);
        } else {
            $self->Error("Can't get file position for trailer offset fixup",1);
        }
    }
    return Write($outfile, $$trailPt);
}

#------------------------------------------------------------------------------
# Add trailers as a block
# Inputs: 0) ExifTool object ref, 1) [optional] trailer data raf,
#         1 or 2-N) trailer types to add (or none to add all)
# Returns: new trailer ref, or undef
# - increments CHANGED if trailer was added
sub AddNewTrailers($;@)
{
    my ($self, @types) = @_;
    my $trailPt;
    ref $types[0] and $trailPt = shift @types;
    $types[0] or shift @types; # (in case undef data ref is passed)
    # add all possible trailers if none specified (currently only CanonVRD)
    @types or @types = qw(CanonVRD CanonDR4);
    # add trailers as a block (if not done already)
    my $type;
    foreach $type (@types) {
        next unless $$self{NEW_VALUE}{$Image::ExifTool::Extra{$type}};
        next if $$self{"Did$type"};
        my $val = $self->GetNewValue($type) or next;
        # DR4 record must be wrapped in VRD trailer package
        if ($type eq 'CanonDR4') {
            next if $$self{DidCanonVRD};    # (only allow one VRD trailer)
            require Image::ExifTool::CanonVRD;
            $val = Image::ExifTool::CanonVRD::WrapDR4($val);
            $$self{DidCanonVRD} = 1;
        }
        my $verb = $trailPt ? 'Writing' : 'Adding';
        $self->VPrint(0, "  $verb $type as a block\n");
        if ($trailPt) {
            $$trailPt .= $val;
        } else {
            $trailPt = \$val;
        }
        $$self{"Did$type"} = 1;
        ++$$self{CHANGED};
    }
    return $trailPt;
}

#------------------------------------------------------------------------------
# Write segment, splitting up into multiple segments if necessary
# Inputs: 0) file or scalar reference, 1) segment marker
#         2) segment header, 3) segment data ref, 4) segment type
# Returns: number of segments written, or 0 on error
# Notes: Writes a single empty segment if data is empty
sub WriteMultiSegment($$$$;$)
{
    my ($outfile, $marker, $header, $dataPt, $type) = @_;
    $type or $type = '';
    my $len = length($$dataPt);
    my $hdr = "\xff" . chr($marker);
    my $count = 0;
    my $maxLen = $maxSegmentLen - length($header);
    $maxLen -= 2 if $type eq 'ICC'; # leave room for segment counters
    my $num = int(($len + $maxLen - 1) / $maxLen);  # number of segments to write
    my $n = 0;
    # write data, splitting into multiple segments if necessary
    # (each segment gets its own header)
    for (;;) {
        ++$count;
        my $size = $len - $n;
        if ($size > $maxLen) {
            $size = $maxLen;
            # avoid starting an Extended EXIF segment with a valid TIFF header
            # (because we would interpret that as a separate EXIF segment)
            --$size if $type eq 'EXIF' and $n+$maxLen <= $len-4 and
                substr($$dataPt, $n+$maxLen, 4) =~ /^(MM\0\x2a|II\x2a\0)/;
        }
        my $buff = substr($$dataPt,$n,$size);
        $n += $size;
        $size += length($header);
        if ($type eq 'ICC') {
            $buff = pack('CC', $count, $num) . $buff;
            $size += 2;
        }
        # write the new segment with appropriate header
        my $segHdr = $hdr . pack('n', $size + 2);
        Write($outfile, $segHdr, $header, $buff) or return 0;
        last if $n >= $len;
    }
    return $count;
}

#------------------------------------------------------------------------------
# Write XMP segment(s) to JPEG file
# Inputs: 0) ExifTool object ref, 1) outfile ref, 2) XMP data ref,
#         3) extended XMP data ref, 4) 32-char extended XMP GUID (or undef if no extended data)
# Returns: true on success, false on write error
sub WriteMultiXMP($$$$$)
{
    my ($self, $outfile, $dataPt, $extPt, $guid) = @_;
    my $success = 1;

    # write main XMP segment
    my $size = length($$dataPt) + length($xmpAPP1hdr);
    if ($size > $maxXMPLen) {
        $self->Error("XMP block too large for JPEG segment! ($size bytes)", 1);
        return 1;
    }
    my $app1hdr = "\xff\xe1" . pack('n', $size + 2);
    Write($outfile, $app1hdr, $xmpAPP1hdr, $$dataPt) or $success = 0;
    # write extended XMP segment(s) if necessary
    if (defined $guid) {
        $size = length($$extPt);
        my $maxLen = $maxXMPLen - 75; # maximum size without 75-byte header
        my $off;
        for ($off=0; $off<$size; $off+=$maxLen) {
            # header(75) = signature(35) + guid(32) + size(4) + offset(4)
            my $len = $size - $off;
            $len = $maxLen if $len > $maxLen;
            $app1hdr = "\xff\xe1" . pack('n', $len + 75 + 2);
            $self->VPrint(0, "Writing extended XMP segment ($len bytes)\n");
            Write($outfile, $app1hdr, $xmpExtAPP1hdr, $guid, pack('N2', $size, $off),
                  substr($$extPt, $off, $len)) or $success = 0;
        }
    }
    return $success;
}

#------------------------------------------------------------------------------
# WriteJPEG : Write JPEG image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid JPEG file, or -1 if
#          an output file was specified and a write error occurred
sub WriteJPEG($$)
{
    my ($self, $dirInfo) = @_;
    my $outfile = $$dirInfo{OutFile};
    my $raf = $$dirInfo{RAF};
    my ($ch, $s, $length,$err, %doneDir, $isEXV, $creatingEXV);
    my $verbose = $$self{OPTIONS}{Verbose};
    my $out = $$self{OPTIONS}{TextOut};
    my $rtnVal = 0;
    my %dumpParms = ( Out => $out );
    my ($writeBuffer, $oldOutfile); # used to buffer writing until PreviewImage position is known

    # check to be sure this is a valid JPG or EXV file
    unless ($raf->Read($s,2) == 2 and $s eq "\xff\xd8") {
        if (defined $s and length $s) {
            return 0 unless $s eq "\xff\x01" and $raf->Read($s,5) == 5 and $s eq 'Exiv2';
        } else {
            return 0 unless $$self{FILE_TYPE} eq 'EXV';
            $s = 'Exiv2';
            $creatingEXV = 1;
        }
        Write($outfile,"\xff\x01") or $err = 1;
        $isEXV = 1;
    }
    $dumpParms{MaxLen} = 128 unless $verbose > 3;

    delete $$self{PREVIEW_INFO};   # reset preview information
    delete $$self{DEL_PREVIEW};    # reset flag to delete preview

    Write($outfile, $s) or $err = 1;
    # figure out what segments we need to write for the tags we have set
    my $addDirs = $$self{ADD_DIRS};
    my $editDirs = $$self{EDIT_DIRS};
    my $delGroup = $$self{DEL_GROUP};
    my $path = $$self{PATH};
    my $pn = scalar @$path;

    # set input record separator to 0xff (the JPEG marker) to make reading quicker
    local $/ = "\xff";
#
# pre-scan image to determine if any create-able segment already exists
#
    my $pos = $raf->Tell();
    my ($marker, @dirOrder, %dirCount);
    Prescan: for (;;) {
        # read up to next marker (JPEG markers begin with 0xff)
        $raf->ReadLine($s) or last;
        # JPEG markers can be padded with unlimited 0xff's
        for (;;) {
            $raf->Read($ch, 1) or last Prescan;
            $marker = ord($ch);
            last unless $marker == 0xff;
        }
        my $dirName;
        # stop pre-scan at SOS (end of meta information) or EOI (end of image)
        if ($marker == 0xda or $marker == 0xd9) {
            $dirName = $jpegMarker{$marker};
            push(@dirOrder, $dirName);
            $dirCount{$dirName} = 1;
            last;
        }
        # handle SOF markers: SOF0-SOF15, except DHT(0xc4), JPGA(0xc8) and DAC(0xcc)
        if (($marker & 0xf0) == 0xc0 and ($marker == 0xc0 or $marker & 0x03)) {
            last unless $raf->Seek(7, 1);
        # read data for all markers except stand-alone
        # markers 0x00, 0x01 and 0xd0-0xd7 (NULL, TEM, RST0-RST7)
        } elsif ($marker!=0x00 and $marker!=0x01 and ($marker<0xd0 or $marker>0xd7)) {
            # read record length word
            last unless $raf->Read($s, 2) == 2;
            my $len = unpack('n',$s);   # get data length
            last unless defined($len) and $len >= 2;
            $len -= 2;  # subtract size of length word
            if (($marker & 0xf0) == 0xe0) {  # is this an APP segment?
                my $n = $len < 64 ? $len : 64;
                $raf->Read($s, $n) == $n or last;
                $len -= $n;
                # Note: only necessary to recognize APP segments that we can create,
                # or delete as a group (and the names below should match @delGroups)
                if ($marker == 0xe0) {
                    $s =~ /^JFIF\0/         and $dirName = 'JFIF';
                    $s =~ /^JFXX\0\x10/     and $dirName = 'JFXX';
                    $s =~ /^(II|MM).{4}HEAPJPGM/s and $dirName = 'CIFF';
                } elsif ($marker == 0xe1) {
                    if ($s =~ /^(.{0,4})$exifAPP1hdr(.{1,4})/is) {
                        $dirName = 'IFD0';
                        my ($junk, $bytes) = ($1, $2);
                        # support multi-segment EXIF
                        if (@dirOrder and $dirOrder[-1] =~ /^(IFD0|ExtendedEXIF)$/ and
                            not length $junk and $bytes !~ /^(MM\0\x2a|II\x2a\0)/)
                        {
                            $dirName = 'ExtendedEXIF';
                        }
                    }
                    $s =~ /^$xmpAPP1hdr/    and $dirName = 'XMP';
                    $s =~ /^$xmpExtAPP1hdr/ and $dirName = 'XMP';
                } elsif ($marker == 0xe2) {
                    $s =~ /^ICC_PROFILE\0/  and $dirName = 'ICC_Profile';
                    $s =~ /^FPXR\0/         and $dirName = 'FlashPix';
                    $s =~ /^MPF\0/          and $dirName = 'MPF';
                } elsif ($marker == 0xe3) {
                    $s =~ /^(Meta|META|Exif)\0\0/ and $dirName = 'Meta';
                } elsif ($marker == 0xe5) {
                    $s =~ /^RMETA\0/        and $dirName = 'RMETA';
                } elsif ($marker == 0xec) {
                    $s =~ /^Ducky/          and $dirName = 'Ducky';
                } elsif ($marker == 0xed) {
                    $s =~ /^$psAPP13hdr/    and $dirName = 'Photoshop';
                } elsif ($marker == 0xee) {
                    $s =~ /^Adobe/          and $dirName = 'Adobe';
                }
                # initialize doneDir as a flag that the directory exists
                # (unless we are deleting it anyway)
                $doneDir{$dirName} = 0 if defined $dirName and not $$delGroup{$dirName};
            }
            $raf->Seek($len, 1) or last;
        }
        $dirName or $dirName = JpegMarkerName($marker);
        $dirCount{$dirName} = ($dirCount{$dirName} || 0) + 1;
        push @dirOrder, $dirName;
    }
    unless ($marker and $marker == 0xda) {
        $isEXV or $self->Error('Corrupted JPEG image'), return 1;
        $marker and $marker ne 0xd9 and $self->Error('Corrupted EXV file'), return 1;
    }
    $raf->Seek($pos, 0) or $self->Error('Seek error'), return 1;
#
# re-write the image
#
    my ($combinedSegData, $segPos, $firstSegPos, %extendedXMP);
    my (@iccChunk, $iccChunkCount, $iccChunksTotal);
    # read through each segment in the JPEG file
    Marker: for (;;) {

        # read up to next marker (JPEG markers begin with 0xff)
        my $segJunk;
        $raf->ReadLine($segJunk) or $segJunk = '';
        # remove the 0xff but write the rest of the junk up to this point
        # (this will handle the data after the first 7 bytes of SOF segments)
        chomp($segJunk);
        Write($outfile, $segJunk) if length $segJunk;
        # JPEG markers can be padded with unlimited 0xff's
        for (;;) {
            if ($raf->Read($ch, 1)) {
                $marker = ord($ch);
                last unless $marker == 0xff;
            } elsif ($creatingEXV) {
                # create EXV from scratch
                $marker = 0xd9; # EOI
                push @dirOrder, 'EOI';
                $dirCount{EOI} = 1;
                last;
            } else {
                $self->Error('Format error');
                return 1;
            }
        }
        # read the segment data
        my $segData;
        # handle SOF markers: SOF0-SOF15, except DHT(0xc4), JPGA(0xc8) and DAC(0xcc)
        if (($marker & 0xf0) == 0xc0 and ($marker == 0xc0 or $marker & 0x03)) {
            last unless $raf->Read($segData, 7) == 7;
        # read data for all markers except stand-alone
        # markers 0x00, 0x01 and 0xd0-0xd7 (NULL, TEM, EOI, RST0-RST7)
        } elsif ($marker!=0x00 and $marker!=0x01 and $marker!=0xd9 and
            ($marker<0xd0 or $marker>0xd7))
        {
            # read record length word
            last unless $raf->Read($s, 2) == 2;
            my $len = unpack('n',$s);   # get data length
            last unless defined($len) and $len >= 2;
            $segPos = $raf->Tell();
            $len -= 2;  # subtract size of length word
            last unless $raf->Read($segData, $len) == $len;
        }
        # initialize variables for this segment
        my $hdr = "\xff" . chr($marker);    # segment header
        my $markerName = JpegMarkerName($marker);
        my $dirName = shift @dirOrder;      # get directory name
#
# create all segments that must come before this one
# (nothing comes before SOI or after SOS)
#
        while ($markerName ne 'SOI') {
            if (exists $$addDirs{JFIF} and not defined $doneDir{JFIF}) {
                $doneDir{JFIF} = 1;
                if (defined $doneDir{Adobe}) {
                    # JFIF overrides Adobe APP14 colour components, so don't allow this
                    # (ref https://docs.oracle.com/javase/8/docs/api/javax/imageio/metadata/doc-files/jpeg_metadata.html)
                    $self->Warn('Not creating JFIF in JPEG with Adobe APP14');
                } else {
                    if ($verbose) {
                        print $out "Creating APP0:\n";
                        print $out "  Creating JFIF with default values\n";
                    }
                    my $jfif = "\x01\x02\x01\0\x48\0\x48\0\0";
                    SetByteOrder('MM');
                    my $tagTablePtr = GetTagTable('Image::ExifTool::JFIF::Main');
                    my %dirInfo = (
                        DataPt   => \$jfif,
                        DirStart => 0,
                        DirLen   => length $jfif,
                        Parent   => 'JFIF',
                    );
                    # must temporarily remove JFIF from DEL_GROUP so we can
                    # delete JFIF and add it back again in a single step
                    my $delJFIF = $$delGroup{JFIF};
                    delete $$delGroup{JFIF};
                    $$path[$pn] = 'JFIF';
                    my $newData = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                    $$delGroup{JFIF} = $delJFIF if defined $delJFIF;
                    if (defined $newData and length $newData) {
                        my $app0hdr = "\xff\xe0" . pack('n', length($newData) + 7);
                        Write($outfile,$app0hdr,"JFIF\0",$newData) or $err = 1;
                    }
                }
            }
            # don't create anything before APP0 or APP1 EXIF (containing IFD0)
            last if $markerName eq 'APP0' or $dirCount{IFD0} or $dirCount{ExtendedEXIF};
            # EXIF information must come immediately after APP0
            if (exists $$addDirs{IFD0} and not defined $doneDir{IFD0}) {
                $doneDir{IFD0} = 1;
                $verbose and print $out "Creating APP1:\n";
                # write new EXIF data
                $$self{TIFF_TYPE} = 'APP1';
                my $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');
                my %dirInfo = (
                    DirName => 'IFD0',
                    Parent  => 'APP1',
                );
                $$path[$pn] = 'APP1';
                my $buff = $self->WriteDirectory(\%dirInfo, $tagTablePtr, \&WriteTIFF);
                if (defined $buff and length $buff) {
                    if (length($buff) + length($exifAPP1hdr) > $maxSegmentLen) {
                        $self->Warn('Creating multi-segment EXIF',1);
                    }
                    # switch to buffered output if required
                    if (($$self{PREVIEW_INFO} or $$self{LeicaTrailer}) and not $oldOutfile) {
                        $writeBuffer = '';
                        $oldOutfile = $outfile;
                        $outfile = \$writeBuffer;
                        # account for segment, EXIF and TIFF headers
                        $$self{PREVIEW_INFO}{Fixup}{Start} += 18 if $$self{PREVIEW_INFO};
                        $$self{LeicaTrailer}{Fixup}{Start} += 18 if $$self{LeicaTrailer};
                    }
                    # write as multi-segment
                    my $n = WriteMultiSegment($outfile, 0xe1, $exifAPP1hdr, \$buff, 'EXIF');
                    if (not $n) {
                        $err = 1;
                    } elsif ($n > 1 and $oldOutfile) {
                        # (punt on this because updating the pointers would be a real pain)
                        $self->Error("Can't write multi-segment EXIF with external pointers");
                    }
                    ++$$self{CHANGED};
                }
            }
            # APP13 Photoshop segment next
            last if $dirCount{Photoshop};
            if (exists $$addDirs{Photoshop} and not defined $doneDir{Photoshop}) {
                $doneDir{Photoshop} = 1;
                $verbose and print $out "Creating APP13:\n";
                # write new APP13 Photoshop record to memory
                my $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Main');
                my %dirInfo = (
                    Parent => 'APP13',
                );
                $$path[$pn] = 'APP13';
                my $buff = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                if (defined $buff and length $buff) {
                    WriteMultiSegment($outfile, 0xed, $psAPP13hdr, \$buff) or $err = 1;
                    ++$$self{CHANGED};
                }
            }
            # then APP1 XMP segment
            last if $dirCount{XMP};
            if (exists $$addDirs{XMP} and not defined $doneDir{XMP}) {
                $doneDir{XMP} = 1;
                $verbose and print $out "Creating APP1:\n";
                # write new XMP data
                my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
                my %dirInfo = (
                    Parent      => 'APP1',
                    # specify MaxDataLen so XMP is split if required
                    MaxDataLen  => $maxXMPLen - length($xmpAPP1hdr),
                );
                $$path[$pn] = 'APP1';
                my $buff = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                if (defined $buff and length $buff) {
                    WriteMultiXMP($self, $outfile, \$buff, $dirInfo{ExtendedXMP},
                                  $dirInfo{ExtendedGUID}) or $err = 1;
                }
            }
            # then APP2 ICC_Profile segment
            last if $dirCount{ICC_Profile};
            if (exists $$addDirs{ICC_Profile} and not defined $doneDir{ICC_Profile}) {
                $doneDir{ICC_Profile} = 1;
                next if $$delGroup{ICC_Profile} and $$delGroup{ICC_Profile} != 2;
                $verbose and print $out "Creating APP2:\n";
                # write new ICC_Profile data
                my $tagTablePtr = GetTagTable('Image::ExifTool::ICC_Profile::Main');
                my %dirInfo = (
                    Parent   => 'APP2',
                );
                $$path[$pn] = 'APP2';
                my $buff = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                if (defined $buff and length $buff) {
                    WriteMultiSegment($outfile, 0xe2, "ICC_PROFILE\0", \$buff, 'ICC') or $err = 1;
                    ++$$self{CHANGED};
                }
            }
            # then APP12 Ducky segment
            last if $dirCount{Ducky};
            if (exists $$addDirs{Ducky} and not defined $doneDir{Ducky}) {
                $doneDir{Ducky} = 1;
                $verbose and print $out "Creating APP12 Ducky:\n";
                # write new Ducky segment data
                my $tagTablePtr = GetTagTable('Image::ExifTool::APP12::Ducky');
                my %dirInfo = (
                    Parent   => 'APP12',
                );
                $$path[$pn] = 'APP12';
                my $buff = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                if (defined $buff and length $buff) {
                    my $size = length($buff) + 5;
                    if ($size <= $maxSegmentLen) {
                        # write the new segment with appropriate header
                        my $app12hdr = "\xff\xec" . pack('n', $size + 2);
                        Write($outfile, $app12hdr, 'Ducky', $buff) or $err = 1;
                    } else {
                        $self->Warn("APP12 Ducky segment too large! ($size bytes)");
                    }
                }
            }
            # then APP14 Adobe segment
            last if $dirCount{Adobe};
            if (exists $$addDirs{Adobe} and not defined $doneDir{Adobe}) {
                $doneDir{Adobe} = 1;
                my $buff = $self->GetNewValue('Adobe');
                if ($buff) {
                    $verbose and print $out "Creating APP14:\n  Creating Adobe segment\n";
                    my $size = length($buff);
                    if ($size <= $maxSegmentLen) {
                        # write the new segment with appropriate header
                        my $app14hdr = "\xff\xee" . pack('n', $size + 2);
                        Write($outfile, $app14hdr, $buff) or $err = 1;
                        ++$$self{CHANGED};
                    } else {
                        $self->Warn("APP14 Adobe segment too large! ($size bytes)");
                    }
                }
            }
            # finally, COM segment
            last if $dirCount{COM};
            if (exists $$addDirs{COM} and not defined $doneDir{COM}) {
                $doneDir{COM} = 1;
                next if $$delGroup{File} and $$delGroup{File} != 2;
                my $newComment = $self->GetNewValue('Comment');
                if (defined $newComment) {
                    if ($verbose) {
                        print $out "Creating COM:\n";
                        $self->VerboseValue('+ Comment', $newComment);
                    }
                    WriteMultiSegment($outfile, 0xfe, '', \$newComment) or $err = 1;
                    ++$$self{CHANGED};
                }
            }
            last;   # didn't want to loop anyway
        }
        $$path[$pn] = $markerName;
        # decrement counter for this directory since we are about to process it
        --$dirCount{$dirName};
#
# rewrite existing segments
#
        # handle SOF markers: SOF0-SOF15, except DHT(0xc4), JPGA(0xc8) and DAC(0xcc)
        if (($marker & 0xf0) == 0xc0 and ($marker == 0xc0 or $marker & 0x03)) {
            $verbose and print $out "JPEG $markerName:\n";
            Write($outfile, $hdr, $segData) or $err = 1;
            next;
        } elsif ($marker == 0xda) {             # SOS
            pop @$path;
            $verbose and print $out "JPEG SOS\n";
            # write SOS segment
            $s = pack('n', length($segData) + 2);
            Write($outfile, $hdr, $s, $segData) or $err = 1;
            my ($buff, $endPos, $trailInfo);
            my $delPreview = $$self{DEL_PREVIEW};
            $trailInfo = IdentifyTrailer($raf) unless $$delGroup{Trailer};
            unless ($oldOutfile or $delPreview or $trailInfo or $$delGroup{Trailer}) {
                # blindly copy the rest of the file
                while ($raf->Read($buff, 65536)) {
                    Write($outfile, $buff) or $err = 1, last;
                }
                $rtnVal = 1;  # success unless we have a file write error
                last;         # all done
            }
            # write the rest of the image (as quickly as possible) up to the EOI
            my $endedWithFF;
            for (;;) {
                my $n = $raf->Read($buff, 65536) or last Marker;
                if (($endedWithFF and $buff =~ m/^\xd9/sg) or
                    $buff =~ m/\xff\xd9/sg)
                {
                    $rtnVal = 1; # the JPEG is OK
                    # write up to the EOI
                    my $pos = pos($buff);
                    Write($outfile, substr($buff, 0, $pos)) or $err = 1;
                    $buff = substr($buff, $pos);
                    last;
                }
                unless ($n == 65536) {
                    $self->Error('JPEG EOI marker not found');
                    last Marker;
                }
                Write($outfile, $buff) or $err = 1;
                $endedWithFF = substr($buff, 65535, 1) eq "\xff" ? 1 : 0;
            }
            # remember position of last data copied
            $endPos = $raf->Tell() - length($buff);
            # rewrite trailers if they exist
            if ($trailInfo) {
                my $tbuf = '';
                $raf->Seek(-length($buff), 1);  # seek back to just after EOI
                $$trailInfo{OutFile} = \$tbuf;  # rewrite the trailer
                $$trailInfo{ScanForAFCP} = 1;   # scan if necessary
                $self->ProcessTrailers($trailInfo) or undef $trailInfo;
            }
            if (not $oldOutfile) {
                # do nothing special
            } elsif ($$self{LeicaTrailer}) {
                my $trailLen;
                if ($trailInfo) {
                    $trailLen = $$trailInfo{DataPos} - $endPos;
                } else {
                    $raf->Seek(0, 2) or $err = 1;
                    $trailLen = $raf->Tell() - $endPos;
                }
                my $fixup = $$self{LeicaTrailer}{Fixup};
                $$self{LeicaTrailer}{TrailPos} = $endPos;
                $$self{LeicaTrailer}{TrailLen} = $trailLen;
                # get _absolute_ position of new Leica trailer
                my $absPos = Tell($oldOutfile) + length($$outfile);
                require Image::ExifTool::Panasonic;
                my $dat = Image::ExifTool::Panasonic::ProcessLeicaTrailer($self, $absPos);
                # allow some junk before Leica trailer (just in case)
                my $junk = $$self{LeicaTrailerPos} - $endPos;
                # set MakerNote pointer and size (subtract 10 for segment and EXIF headers)
                $fixup->SetMarkerPointers($outfile, 'LeicaTrailer', length($$outfile) - 10 + $junk);
                # use this fixup to set the size too (sneaky)
                my $trailSize = defined($dat) ? length($dat) - $junk : $$self{LeicaTrailer}{Size};
                $$fixup{Start} -= 4;  $$fixup{Shift} += 4;
                $fixup->SetMarkerPointers($outfile, 'LeicaTrailer', $trailSize) if defined $trailSize;
                $$fixup{Start} += 4;  $$fixup{Shift} -= 4;
                # clean up and write the buffered data
                $outfile = $oldOutfile;
                undef $oldOutfile;
                Write($outfile, $writeBuffer) or $err = 1;
                undef $writeBuffer;
                if (defined $dat) {
                    Write($outfile, $dat) or $err = 1;  # write new Leica trailer
                    $delPreview = 1;                    # delete existing Leica trailer
                }
            } else {
                # locate preview image and fix up preview offsets
                my $scanLen = $$self{Make} =~ /^SONY/i ? 65536 : 1024;
                if (length($buff) < $scanLen) { # make sure we have enough trailer to scan
                    my $buf2;
                    $buff .= $buf2 if $raf->Read($buf2, $scanLen - length($buff));
                }
                # get new preview image position, relative to EXIF base
                my $newPos = length($$outfile) - 10; # (subtract 10 for segment and EXIF headers)
                my $junkLen;
                # adjust position if image isn't at the start (eg. Olympus E-1/E-300)
                if ($buff =~ /(\xff\xd8\xff.|.\xd8\xff\xdb)(..)/sg) {
                    my ($jpegHdr, $segLen) = ($1, $2);
                    $junkLen = pos($buff) - 6;
                    # Sony previewimage trailer has a 32 byte header
                    if ($$self{Make} =~ /^SONY/i and $junkLen > 32) {
                        # with some newer Sony models, the makernotes preview pointer
                        # points to JPEG at end of EXIF inside MPImage preview (what a pain!)
                        if ($jpegHdr eq "\xff\xd8\xff\xe1") {   # is the first segment EXIF?
                            $segLen = unpack('n', $segLen);     # the EXIF segment length
                            # Sony PreviewImage starts with last 2 bytes of EXIF segment
                            # (and first byte is usually "\0", not "\xff", so don't check this)
                            if (length($buff) > $junkLen + $segLen + 6 and
                                substr($buff, $junkLen + $segLen + 3, 3) eq "\xd8\xff\xdb")
                            {
                                $junkLen += $segLen + 2;
                                # (note: this will not copy the trailer after PreviewImage,
                                #  which is a 14kB block full of zeros for the A77)
                            }
                        }
                        $junkLen -= 32;
                    }
                    $newPos += $junkLen;
                }
                # fix up the preview offsets to point to the start of the new image
                my $previewInfo = $$self{PREVIEW_INFO};
                delete $$self{PREVIEW_INFO};
                my $fixup = $$previewInfo{Fixup};
                $newPos += ($$previewInfo{BaseShift} || 0);
                # adjust to absolute file offset if necessary (Samsung STMN)
                $newPos += Tell($oldOutfile) + 10 if $$previewInfo{Absolute};
                if ($$previewInfo{Relative}) {
                    # adjust for our base by looking at how far the pointer got shifted
                    $newPos -= ($fixup->GetMarkerPointers($outfile, 'PreviewImage') || 0);
                } elsif ($$previewInfo{ChangeBase}) {
                    # Leica S2 uses relative offsets for the preview only (leica sucks)
                    my $makerOffset = $fixup->GetMarkerPointers($outfile, 'LeicaTrailer');
                    $newPos -= $makerOffset if $makerOffset;
                }
                $fixup->SetMarkerPointers($outfile, 'PreviewImage', $newPos);
                # clean up and write the buffered data
                $outfile = $oldOutfile;
                undef $oldOutfile;
                Write($outfile, $writeBuffer) or $err = 1;
                undef $writeBuffer;
                # write preview image
                if ($$previewInfo{Data} ne 'LOAD_PREVIEW') {
                    # write any junk that existed before the preview image
                    Write($outfile, substr($buff,0,$junkLen)) or $err = 1 if $junkLen;
                    # write the saved preview image
                    Write($outfile, $$previewInfo{Data}) or $err = 1;
                    delete $$previewInfo{Data};
                    # (don't increment CHANGED because we could be rewriting existing preview)
                    $delPreview = 1;    # remove old preview
                }
            }
            # copy over preview image if necessary
            unless ($delPreview) {
                my $extra;
                if ($trailInfo) {
                    # copy everything up to start of first processed trailer
                    $extra = $$trailInfo{DataPos} - $endPos;
                } else {
                    # copy everything up to end of file
                    $raf->Seek(0, 2) or $err = 1;
                    $extra = $raf->Tell() - $endPos;
                }
                if ($extra > 0) {
                    if ($$delGroup{Trailer}) {
                        $verbose and print $out "  Deleting unknown trailer ($extra bytes)\n";
                        ++$$self{CHANGED};
                    } else {
                        # copy over unknown trailer
                        $verbose and print $out "  Preserving unknown trailer ($extra bytes)\n";
                        $raf->Seek($endPos, 0) or $err = 1;
                        CopyBlock($raf, $outfile, $extra) or $err = 1;
                    }
                }
            }
            # write trailer if necessary
            if ($trailInfo) {
                $self->WriteTrailerBuffer($trailInfo, $outfile) or $err = 1;
                undef $trailInfo;
            }
            last;   # all done parsing file

        } elsif ($marker==0xd9 and $isEXV) {
            # write EXV EOI (any trailer will be lost)
            Write($outfile, "\xff\xd9") or $err = 1;
            $rtnVal = 1;
            last;

        } elsif ($marker==0x00 or $marker==0x01 or ($marker>=0xd0 and $marker<=0xd7)) {
            $verbose and $marker and print $out "JPEG $markerName:\n";
            # handle stand-alone markers 0x00, 0x01 and 0xd0-0xd7 (NULL, TEM, RST0-RST7)
            Write($outfile, $hdr) or $err = 1;
            next;
        }
        #
        # NOTE: A 'next' statement after this point will cause $$segDataPt
        #       not to be written if there is an output file, so in this case
        #       the $$self{CHANGED} flags must be updated
        #
        my $segDataPt = \$segData;
        $length = length($segData);
        if ($verbose) {
            print $out "JPEG $markerName ($length bytes):\n";
            if ($verbose > 2 and $markerName =~ /^APP/) {
                HexDump($segDataPt, undef, %dumpParms);
            }
        }
        # group delete of APP segements
        if ($$delGroup{$dirName}) {
            $verbose and print $out "  Deleting $dirName segment\n";
            ++$$self{CHANGED};
            next Marker;
        }
        my ($segType, $del);
        # rewrite this segment only if we are changing a tag which is contained in its
        # directory (or deleting '*', in which case we need to identify the segment type)
        while (exists $$editDirs{$markerName} or $$delGroup{'*'}) {
            if ($marker == 0xe0) {              # APP0 (JFIF, CIFF)
                if ($$segDataPt =~ /^JFIF\0/) {
                    $segType = 'JFIF';
                    $$delGroup{JFIF} and $del = 1, last;
                    last unless $$editDirs{JFIF};
                    SetByteOrder('MM');
                    my $tagTablePtr = GetTagTable('Image::ExifTool::JFIF::Main');
                    my %dirInfo = (
                        DataPt   => $segDataPt,
                        DataPos  => $segPos,
                        DataLen  => $length,
                        DirStart => 5,     # directory starts after identifier
                        DirLen   => $length-5,
                        Parent   => $markerName,
                    );
                    my $newData = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                    if (defined $newData and length $newData) {
                        $$segDataPt = "JFIF\0" . $newData;
                    }
                } elsif ($$segDataPt =~ /^JFXX\0\x10/) {
                    $segType = 'JFXX';
                    $$delGroup{JFIF} and $del = 1;
                } elsif ($$segDataPt =~ /^(II|MM).{4}HEAPJPGM/s) {
                    $segType = 'CIFF';
                    $$delGroup{CIFF} and $del = 1, last;
                    last unless $$editDirs{CIFF};
                    my $newData = '';
                    my %dirInfo = (
                        RAF => new File::RandomAccess($segDataPt),
                        OutFile => \$newData,
                    );
                    require Image::ExifTool::CanonRaw;
                    if (Image::ExifTool::CanonRaw::WriteCRW($self, \%dirInfo) > 0) {
                        if (length $newData) {
                            $$segDataPt = $newData;
                        } else {
                            undef $segDataPt;
                            $del = 1;   # delete this segment
                        }
                    }
                }
            } elsif ($marker == 0xe1) {         # APP1 (EXIF, XMP)
                # check for EXIF data
                if ($$segDataPt =~ /^(.{0,4})$exifAPP1hdr/is) {
                    my $hdrLen = length $exifAPP1hdr;
                    if (length $1) {
                        $hdrLen += length $1;
                        $self->Error('Unknown garbage at start of EXIF segment',1);
                    } elsif ($$segDataPt !~ /^Exif\0/) {
                        $self->Error('Incorrect EXIF segment identifier',1);
                    }
                    $segType = 'EXIF';
                    last unless $$editDirs{IFD0};
                    # add this data to the combined data if it exists
                    if (defined $combinedSegData) {
                        $combinedSegData .= substr($$segDataPt,$hdrLen);
                        $segDataPt = \$combinedSegData;
                        $segPos = $firstSegPos;
                        $length = length $combinedSegData;  # update length
                    }
                    # peek ahead to see if the next segment is extended EXIF
                    if ($dirOrder[0] eq 'ExtendedEXIF') {
                        # initialize combined data if necessary
                        unless (defined $combinedSegData) {
                            $combinedSegData = $$segDataPt;
                            $firstSegPos = $segPos;
                            $self->Warn('File contains multi-segment EXIF',1);
                        }
                        next Marker;    # get the next segment to combine
                    }
                    $doneDir{IFD0} and $self->Warn('Multiple APP1 EXIF records');
                    $doneDir{IFD0} = 1;
                    # check del groups now so we can change byte order in one step
                    if ($$delGroup{IFD0} or $$delGroup{EXIF}) {
                        delete $doneDir{IFD0};  # delete so we will create a new one
                        $del = 1;
                        last;
                    }
                    # rewrite EXIF as if this were a TIFF file in memory
                    my %dirInfo = (
                        DataPt   => $segDataPt,
                        DataPos  => -$hdrLen, # (remember: relative to Base!)
                        DirStart => $hdrLen,
                        Base     => $segPos + $hdrLen,
                        Parent   => $markerName,
                        DirName  => 'IFD0',
                    );
                    # write new EXIF data to memory
                    my $tagTablePtr = GetTagTable('Image::ExifTool::Exif::Main');
                    my $buff = $self->WriteDirectory(\%dirInfo, $tagTablePtr, \&WriteTIFF);
                    if (defined $buff) {
                        undef $$segDataPt;  # free the old buffer
                        $segDataPt = \$buff;
                    } else {
                        last Marker unless $self->Options('IgnoreMinorErrors');
                    }
                    # delete segment if IFD contains no entries
                    length $$segDataPt or $del = 1, last;
                    if (length($$segDataPt) + length($exifAPP1hdr) > $maxSegmentLen) {
                        $self->Warn('Writing multi-segment EXIF',1);
                    }
                    # switch to buffered output if required
                    if (($$self{PREVIEW_INFO} or $$self{LeicaTrailer}) and not $oldOutfile) {
                        $writeBuffer = '';
                        $oldOutfile = $outfile;
                        $outfile = \$writeBuffer;
                        # must account for segment, EXIF and TIFF headers
                        $$self{PREVIEW_INFO}{Fixup}{Start} += 18 if $$self{PREVIEW_INFO};
                        $$self{LeicaTrailer}{Fixup}{Start} += 18 if $$self{LeicaTrailer};
                    }
                    # write as multi-segment
                    my $n = WriteMultiSegment($outfile, $marker, $exifAPP1hdr, $segDataPt, 'EXIF');
                    if (not $n) {
                        $err = 1;
                    } elsif ($n > 1 and $oldOutfile) {
                        # (punt on this because updating the pointers would be a real pain)
                        $self->Error("Can't write multi-segment EXIF with external pointers");
                    }
                    undef $combinedSegData;
                    undef $$segDataPt;
                    next Marker;
                # check for XMP data
                } elsif ($$segDataPt =~ /^($xmpAPP1hdr|$xmpExtAPP1hdr)/) {
                    $segType = 'XMP';
                    $$delGroup{XMP} and $del = 1, last;
                    $doneDir{XMP} = ($doneDir{XMP} || 0) + 1;
                    last unless $$editDirs{XMP};
                    if ($doneDir{XMP} + $dirCount{XMP} > 1) {
                        # must assemble all XMP segments before writing
                        my ($guid, $extXMP);
                        if ($$segDataPt =~ /^$xmpExtAPP1hdr/) {
                            # save extended XMP data
                            if (length $$segDataPt < 75) {
                                $extendedXMP{Error} = 'Truncated data';
                            } else {
                                my ($size, $off) = unpack('x67N2', $$segDataPt);
                                $guid = substr($$segDataPt, 35, 32);
                                if ($guid =~ /[^A-Za-z0-9]/) { # (technically, should be uppercase)
                                    $extendedXMP{Error} = 'Invalid GUID';
                                } else {
                                    # remember extended data for each GUID
                                    $extXMP = $extendedXMP{$guid};
                                    if ($extXMP) {
                                        $size == $$extXMP{Size} or $extendedXMP{Error} = 'Inconsistent size';
                                    } else {
                                        $extXMP = $extendedXMP{$guid} = { };
                                    }
                                    $$extXMP{Size} = $size;
                                    $$extXMP{$off} = substr($$segDataPt, 75);
                                }
                            }
                        } else {
                            # save all main XMP segments (should normally be only one)
                            $extendedXMP{Main} = [] unless $extendedXMP{Main};
                            push @{$extendedXMP{Main}}, substr($$segDataPt, length $xmpAPP1hdr);
                        }
                        # continue processing only if we have read all the segments
                        next Marker if $dirCount{XMP};
                        # reconstruct an XMP super-segment
                        $$segDataPt = $xmpAPP1hdr;
                        my $goodGuid = '';
                        foreach (@{$extendedXMP{Main}}) {
                            # get the HasExtendedXMP GUID if it exists
                            if (/:HasExtendedXMP\s*(=\s*['"]|>)(\w{32})/) {
                                # warn of subsequent XMP blocks specifying a different
                                # HasExtendedXMP (have never seen this)
                                if ($goodGuid and $goodGuid ne $2) {
                                    $self->WarnOnce('Multiple XMP segments specifying different extended XMP GUID');
                                }
                                $goodGuid = $2; # GUID for the standard extended XMP
                            }
                            $$segDataPt .= $_;
                        }
                        # GUID of the extended XMP that we want to read
                        my $readGuid = $$self{OPTIONS}{ExtendedXMP} || 0;
                        $readGuid = $goodGuid if $readGuid eq '1';
                        foreach $guid (sort keys %extendedXMP) {
                            next unless length $guid == 32;     # ignore other (internal) keys
                            if ($guid ne $readGuid and $readGuid ne '2') {
                                my $non = $guid eq $goodGuid ? '' : 'non-';
                                $self->Warn("Ignored ${non}standard extended XMP (GUID $guid)");
                                next;
                            }
                            if ($guid ne $goodGuid) {
                                $self->Warn("Reading non-standard extended XMP (GUID $guid)");
                            }
                            $extXMP = $extendedXMP{$guid};
                            next unless ref $extXMP eq 'HASH';  # (just to be safe)
                            my $size = $$extXMP{Size};
                            my (@offsets, $off);
                            for ($off=0; $off<$size; ) {
                                last unless defined $$extXMP{$off};
                                push @offsets, $off;
                                $off += length $$extXMP{$off};
                            }
                            if ($off == $size) {
                                # add all XMP to super-segment
                                $$segDataPt .= $$extXMP{$_} foreach @offsets;
                            } else {
                                $self->Error("Incomplete extended XMP (GUID $guid)", 1);
                            }
                        }
                        $self->Error("$extendedXMP{Error} in extended XMP", 1) if $extendedXMP{Error};
                    }
                    my $start = length $xmpAPP1hdr;
                    my $tagTablePtr = GetTagTable('Image::ExifTool::XMP::Main');
                    my %dirInfo = (
                        DataPt     => $segDataPt,
                        DirStart   => $start,
                        Parent     => $markerName,
                        # limit XMP size and create extended XMP if necessary
                        MaxDataLen => $maxXMPLen - length($xmpAPP1hdr),
                    );
                    my $newData = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                    if (defined $newData) {
                        undef %extendedXMP;
                        if (length $newData) {
                            # write multi-segment XMP (XMP plus extended XMP if necessary)
                            WriteMultiXMP($self, $outfile, \$newData, $dirInfo{ExtendedXMP},
                                          $dirInfo{ExtendedGUID}) or $err = 1;
                            undef $$segDataPt;  # free the old buffer
                            next Marker;
                        } else {
                            $$segDataPt = '';   # delete the XMP
                        }
                    } else {
                        $verbose and print $out "    [XMP rewritten with no changes]\n";
                        if ($doneDir{XMP} > 1) {
                            # re-write original multi-segment XMP
                            my ($dat, $guid, $extXMP, $off);
                            foreach $dat (@{$extendedXMP{Main}}) {      # main XMP
                                next unless length $dat;
                                $s = pack('n', length($xmpAPP1hdr) + length($dat) + 2);
                                Write($outfile, $hdr, $s, $xmpAPP1hdr, $dat) or $err = 1;
                            }
                            foreach $guid (sort keys %extendedXMP) {    # extended XMP
                                next unless length $guid == 32;
                                $extXMP = $extendedXMP{$guid};
                                next unless ref $extXMP eq 'HASH';
                                my $size = $$extXMP{Size} or next;
                                for ($off=0; defined $$extXMP{$off}; $off += length $$extXMP{$off}) {
                                    $s = pack('n', length($xmpExtAPP1hdr) + length($$extXMP{$off}) + 42);
                                    Write($outfile, $hdr, $s, $xmpExtAPP1hdr, $guid,
                                          pack('N2', $size, $off), $$extXMP{$off}) or $err = 1;
                                }
                            }
                            undef $$segDataPt;  # free the old buffer
                            undef %extendedXMP;
                            next Marker;
                        }
                        # continue on to re-write original single-segment XMP
                    }
                    $del = 1 unless length $$segDataPt;
                } elsif ($$segDataPt =~ /^http/ or $$segDataPt =~ /<exif:/) {
                    $self->Warn('Ignored APP1 XMP segment with non-standard header', 1);
                }
            } elsif ($marker == 0xe2) {         # APP2 (ICC Profile, FPXR, MPF)
                if ($$segDataPt =~ /^ICC_PROFILE\0/ and $length >= 14) {
                    $segType = 'ICC_Profile';
                    $$delGroup{ICC_Profile} and $del = 1, last;
                    # must concatenate blocks of profile
                    my $chunkNum = Get8u($segDataPt, 12);
                    my $chunksTot = Get8u($segDataPt, 13);
                    if (defined $iccChunksTotal) {
                        # abort parsing ICC_Profile if the total chunk count is inconsistent
                        if ($chunksTot != $iccChunksTotal and defined $iccChunkCount) {
                            # an error because the accumulated profile data will be lost
                            $self->Error('Inconsistent ICC_Profile chunk count', 1);
                            undef $iccChunkCount; # abort ICC_Profile parsing
                            undef $chunkNum;      # avoid 2nd warning below
                            ++$$self{CHANGED};    # we are deleting the bad chunks before this one
                        }
                    } else {
                        $iccChunkCount = 0;
                        $iccChunksTotal = $chunksTot;
                        $self->Warn('ICC_Profile chunk count is zero') if !$chunksTot;
                    }
                    if (defined $iccChunkCount) {
                        # save this chunk
                        if (defined $iccChunk[$chunkNum]) {
                            $self->Warn("Duplicate ICC_Profile chunk number $chunkNum");
                            $iccChunk[$chunkNum] .= substr($$segDataPt, 14);
                        } else {
                            $iccChunk[$chunkNum] = substr($$segDataPt, 14);
                        }
                        # continue accumulating chunks unless we have all of them
                        next Marker unless ++$iccChunkCount >= $iccChunksTotal;
                        undef $iccChunkCount;   # prevent reprocessing
                        $doneDir{ICC_Profile} = 1;
                        # combine the ICC_Profile chunks
                        my $icc_profile = '';
                        defined $_ and $icc_profile .= $_ foreach @iccChunk;
                        undef @iccChunk;   # free memory
                        $segDataPt = \$icc_profile;
                        $length = length $icc_profile;
                        my $tagTablePtr = GetTagTable('Image::ExifTool::ICC_Profile::Main');
                        my %dirInfo = (
                            DataPt   => $segDataPt,
                            DataPos  => $segPos + 14,
                            DataLen  => $length,
                            DirStart => 0,
                            DirLen   => $length,
                            Parent   => $markerName,
                        );
                        my $newData = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                        if (defined $newData) {
                            undef $$segDataPt;  # free the old buffer
                            $segDataPt = \$newData;
                        }
                        length $$segDataPt or $del = 1, last;
                        # write as ICC multi-segment
                        WriteMultiSegment($outfile, $marker, "ICC_PROFILE\0", $segDataPt, 'ICC') or $err = 1;
                        undef $$segDataPt;
                        next Marker;
                    } elsif (defined $chunkNum) {
                        $self->WarnOnce('Invalid or extraneous ICC_Profile chunk(s)');
                        # fall through to preserve this extra profile...
                    }
                } elsif ($$segDataPt =~ /^FPXR\0/) {
                    $segType = 'FPXR';
                    $$delGroup{FlashPix} and $del = 1;
                } elsif ($$segDataPt =~ /^MPF\0/) {
                    $segType = 'MPF';
                    $$delGroup{MPF} and $del = 1;
                }
            } elsif ($marker == 0xe3) {         # APP3 (Kodak Meta)
                if ($$segDataPt =~ /^(Meta|META|Exif)\0\0/) {
                    $segType = 'Kodak Meta';
                    $$delGroup{Meta} and $del = 1, last;
                    $doneDir{Meta} and $self->Warn('Multiple APP3 Meta segments');
                    $doneDir{Meta} = 1;
                    last unless $$editDirs{Meta};
                    # rewrite Meta IFD as if this were a TIFF file in memory
                    my %dirInfo = (
                        DataPt   => $segDataPt,
                        DataPos  => -6, # (remember: relative to Base!)
                        DirStart => 6,
                        Base     => $segPos + 6,
                        Parent   => $markerName,
                        DirName  => 'Meta',
                    );
                    # write new data to memory
                    my $tagTablePtr = GetTagTable('Image::ExifTool::Kodak::Meta');
                    my $buff = $self->WriteDirectory(\%dirInfo, $tagTablePtr, \&WriteTIFF);
                    if (defined $buff) {
                        # update segment with new data
                        $$segDataPt = substr($$segDataPt,0,6) . $buff;
                    } else {
                        last Marker unless $self->Options('IgnoreMinorErrors');
                    }
                    # delete segment if IFD contains no entries
                    $del = 1 unless length($$segDataPt) > 6;
                }
            } elsif ($marker == 0xe5) {         # APP5 (Ricoh RMETA)
                if ($$segDataPt =~ /^RMETA\0/) {
                    $segType = 'Ricoh RMETA';
                    $$delGroup{RMETA} and $del = 1;
                }
            } elsif ($marker == 0xec) {         # APP12 (Ducky)
                if ($$segDataPt =~ /^Ducky/) {
                    $segType = 'Ducky';
                    $$delGroup{Ducky} and $del = 1, last;
                    $doneDir{Ducky} and $self->Warn('Multiple APP12 Ducky segments');
                    $doneDir{Ducky} = 1;
                    last unless $$editDirs{Ducky};
                    my $tagTablePtr = GetTagTable('Image::ExifTool::APP12::Ducky');
                    my %dirInfo = (
                        DataPt   => $segDataPt,
                        DataPos  => $segPos,
                        DataLen  => $length,
                        DirStart => 5,     # directory starts after identifier
                        DirLen   => $length-5,
                        Parent   => $markerName,
                    );
                    my $newData = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                    if (defined $newData) {
                        undef $$segDataPt;  # free the old buffer
                        # add header to new segment unless empty
                        $newData = 'Ducky' . $newData if length $newData;
                        $segDataPt = \$newData;
                    }
                    $del = 1 unless length $$segDataPt;
                }
            } elsif ($marker == 0xed) {         # APP13 (Photoshop)
                if ($$segDataPt =~ /^$psAPP13hdr/) {
                    $segType = 'Photoshop';
                    # add this data to the combined data if it exists
                    if (defined $combinedSegData) {
                        $combinedSegData .= substr($$segDataPt,length($psAPP13hdr));
                        $segDataPt = \$combinedSegData;
                        $length = length $combinedSegData;  # update length
                    }
                    # peek ahead to see if the next segment is photoshop data too
                    if ($dirOrder[0] eq 'Photoshop') {
                        # initialize combined data if necessary
                        $combinedSegData = $$segDataPt unless defined $combinedSegData;
                        next Marker;    # get the next segment to combine
                    }
                    if ($doneDir{Photoshop}) {
                        $self->Warn('Multiple Photoshop records');
                        # only rewrite the first Photoshop segment when deleting this group
                        # (to remove multiples when deleting and adding back in one step)
                        $$delGroup{Photoshop} and $del = 1, last;
                    }
                    $doneDir{Photoshop} = 1;
                    # process APP13 Photoshop record
                    my $tagTablePtr = GetTagTable('Image::ExifTool::Photoshop::Main');
                    my %dirInfo = (
                        DataPt   => $segDataPt,
                        DataPos  => $segPos,
                        DataLen  => $length,
                        DirStart => 14,     # directory starts after identifier
                        DirLen   => $length-14,
                        Parent   => $markerName,
                    );
                    my $newData = $self->WriteDirectory(\%dirInfo, $tagTablePtr);
                    if (defined $newData) {
                        undef $$segDataPt;  # free the old buffer
                        $segDataPt = \$newData;
                    }
                    length $$segDataPt or $del = 1, last;
                    # write as multi-segment
                    WriteMultiSegment($outfile, $marker, $psAPP13hdr, $segDataPt) or $err = 1;
                    undef $combinedSegData;
                    undef $$segDataPt;
                    next Marker;
                }
            } elsif ($marker == 0xee) {         # APP14 (Adobe)
                if ($$segDataPt =~ /^Adobe/) {
                    $segType = 'Adobe';
                    # delete it and replace it later if editing
                    if ($$delGroup{Adobe} or $$editDirs{Adobe}) {
                        $del = 1;
                        undef $doneDir{Adobe};  # so we can add it back again above
                    }
                }
            } elsif ($marker == 0xfe) {         # COM (JPEG comment)
                my $newComment;
                unless ($doneDir{COM}) {
                    $doneDir{COM} = 1;
                    unless ($$delGroup{File} and $$delGroup{File} != 2) {
                        my $tagInfo = $Image::ExifTool::Extra{Comment};
                        my $nvHash = $self->GetNewValueHash($tagInfo);
                        my $val = $segData;
                        $val =~ s/\0+$//;   # allow for stupid software that adds NULL terminator
                        if ($self->IsOverwriting($nvHash, $val) or $$delGroup{File}) {
                            $newComment = $self->GetNewValue($nvHash);
                        } else {
                            delete $$editDirs{COM}; # we aren't editing COM after all
                            last;
                        }
                    }
                }
                $self->VerboseValue('- Comment', $$segDataPt);
                if (defined $newComment) {
                    # write out the comments
                    $self->VerboseValue('+ Comment', $newComment);
                    WriteMultiSegment($outfile, 0xfe, '', \$newComment) or $err = 1;
                } else {
                    $verbose and print $out "  Deleting COM segment\n";
                }
                ++$$self{CHANGED};      # increment the changed flag
                undef $segDataPt;       # don't write existing comment
            }
            last;   # didn't want to loop anyway
        }

        # delete necessary segments (including unknown segments if deleting all)
        if ($del or ($$delGroup{'*'} and not $segType and $marker>=0xe0 and $marker<=0xef)) {
            $segType = 'unknown' unless $segType;
            $verbose and print $out "  Deleting $markerName $segType segment\n";
            ++$$self{CHANGED};
            next Marker;
        }
        # write out this segment if $segDataPt is still defined
        if (defined $segDataPt and defined $$segDataPt) {
            # write the data for this record (the data could have been
            # modified, so recalculate the length word)
            my $size = length($$segDataPt);
            if ($size > $maxSegmentLen) {
                $segType or $segType = 'Unknown';
                $self->Error("$segType $markerName segment too large! ($size bytes)");
                $err = 1;
            } else {
                $s = pack('n', length($$segDataPt) + 2);
                Write($outfile, $hdr, $s, $$segDataPt) or $err = 1;
            }
            undef $$segDataPt;  # free the buffer
            undef $segDataPt;
        }
    }
    # make sure the ICC_Profile was complete
    $self->Error('Incomplete ICC_Profile record', 1) if defined $iccChunkCount;
    pop @$path if @$path > $pn;
    # if oldOutfile is still set, there was an error copying the JPEG
    $oldOutfile and return 0;
    if ($rtnVal) {
        # add any new trailers we are creating
        my $trailPt = $self->AddNewTrailers();
        Write($outfile, $$trailPt) or $err = 1 if $trailPt;
    }
    # set return value to -1 if we only had a write error
    $rtnVal = -1 if $rtnVal and $err;
    if ($creatingEXV and $rtnVal > 0 and not $$self{CHANGED}) {
        $self->Error('Nothing written');
        $rtnVal = -1;
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Validate an image for writing
# Inputs: 0) ExifTool object reference, 1) raw value reference
# Returns: error string or undef on success
sub CheckImage($$)
{
    my ($self, $valPtr) = @_;
    if (length($$valPtr) and $$valPtr!~/^\xff\xd8/ and not
        $self->Options('IgnoreMinorErrors'))
    {
        return '[Minor] Not a valid image';
    }
    return undef;
}

#------------------------------------------------------------------------------
# check a value for validity
# Inputs: 0) value reference, 1) format string, 2) optional count
# Returns: error string, or undef on success
# Notes: May modify value (if a count is specified for a string, it is null-padded
# to the specified length, and floating point values are rounded to integer if required)
sub CheckValue($$;$)
{
    my ($valPtr, $format, $count) = @_;
    my (@vals, $val, $n);

    if ($format eq 'string' or $format eq 'undef') {
        return undef unless $count and $count > 0;
        my $len = length($$valPtr);
        if ($format eq 'string') {
            $len >= $count and return 'String too long';
        } else {
            $len > $count and return 'Data too long';
        }
        if ($len < $count) {
            $$valPtr .= "\0" x ($count - $len);
        }
        return undef;
    }
    if ($count and $count != 1) {
        @vals = split(' ',$$valPtr);
        $count < 0 and ($count = @vals or return undef);
    } else {
        $count = 1;
        @vals = ( $$valPtr );
    }
    if (@vals != $count) {
        my $str = @vals > $count ? 'Too many' : 'Not enough';
        return "$str values specified ($count required)";
    }
    for ($n=0; $n<$count; ++$n) {
        $val = shift @vals;
        if ($format =~ /^int/) {
            # make sure the value is integer
            unless (IsInt($val)) {
                if (IsHex($val)) {
                    $val = $$valPtr = hex($val);
                } else {
                    # round single floating point values to the nearest integer
                    return 'Not an integer' unless IsFloat($val) and $count == 1;
                    $val = $$valPtr = int($val + ($val < 0 ? -0.5 : 0.5));
                }
            }
            my $rng = $intRange{$format} or return "Bad int format: $format";
            return "Value below $format minimum" if $val < $$rng[0];
            # (allow 0xfeedfeed code as value for 16-bit pointers)
            return "Value above $format maximum" if $val > $$rng[1] and $val != 0xfeedfeed;
        } elsif ($format =~ /^rational/ or $format eq 'float' or $format eq 'double') {
            # make sure the value is a valid floating point number
            unless (IsFloat($val)) {
                # allow 'inf', 'undef' and fractional rational values
                if ($format =~ /^rational/) {
                    next if $val eq 'inf' or $val eq 'undef';
                    if ($val =~ m{^([-+]?\d+)/(\d+)$}) {
                        next unless $1 < 0 and $format =~ /u$/;
                        return 'Must be an unsigned rational';
                    }
                }
                return 'Not a floating point number';
            }
            if ($format =~ /^rational\d+u$/ and $val < 0) {
                return 'Must be a positive number';
            }
        }
    }
    return undef;   # success!
}

#------------------------------------------------------------------------------
# check new value for binary data block
# Inputs: 0) ExifTool object ref, 1) tagInfo hash ref, 2) raw value ref
# Returns: error string or undef (and may modify value) on success
sub CheckBinaryData($$$)
{
    my ($self, $tagInfo, $valPtr) = @_;
    my $format = $$tagInfo{Format};
    unless ($format) {
        my $table = $$tagInfo{Table};
        if ($table and $$table{FORMAT}) {
            $format = $$table{FORMAT};
        } else {
            # use default 'int8u' unless specified
            $format = 'int8u';
        }
    }
    my $count;
    if ($format =~ /(.*)\[(.*)\]/) {
        $format = $1;
        $count = $2;
        # can't evaluate $count now because we don't know $size yet
        undef $count if $count =~ /\$size/;
    }
    return CheckValue($valPtr, $format, $count);
}

#------------------------------------------------------------------------------
# Rename a file (with patch for Windows Unicode file names, and other problem)
# Inputs: 0) ExifTool ref, 1) old name, 2) new name
# Returns: true on success
sub Rename($$$)
{
    my ($self, $old, $new) = @_;
    my ($result, $try, $winUni);

    if ($self->EncodeFileName($old)) {
        $self->EncodeFileName($new, 1);
        $winUni = 1;
    } elsif ($self->EncodeFileName($new)) {
        $old = $_[1];
        $self->EncodeFileName($old, 1);
        $winUni = 1;
    }
    for (;;) {
        if ($winUni) {
            $result = eval { Win32API::File::MoveFileExW($old, $new,
                Win32API::File::MOVEFILE_REPLACE_EXISTING() |
                Win32API::File::MOVEFILE_COPY_ALLOWED()) };
        } else {
            $result = rename($old, $new);
        }
        last if $result or $^O ne 'MSWin32';
        # keep trying for up to 0.5 seconds
        # (patch for Windows denial-of-service susceptibility)
        $try = ($try || 1) + 1;
        last if $try > 50;
        select(undef,undef,undef,0.01); # sleep for 0.01 sec
    }
    return $result;
}

#------------------------------------------------------------------------------
# Delete a file (with patch for Windows Unicode file names)
# Inputs: 0) ExifTool ref, 1-N) names of files to delete
# Returns: number of files deleted
sub Unlink($@)
{
    my $self = shift;
    my $result = 0;
    while (@_) {
        my $file = shift;
        if ($self->EncodeFileName($file)) {
            ++$result if eval { Win32API::File::DeleteFileW($file) };
        } else {
            ++$result if unlink $file;
        }
    }
    return $result;
}

#------------------------------------------------------------------------------
# Set file times (Unix seconds since the epoch)
# Inputs: 0) ExifTool ref, 1) file name or ref, 2) access time, 3) modification time,
#         4) inode change or creation time (or undef for any time to avoid setting)
#         5) flag to suppress warning
# Returns: 1 on success, 0 on error
my $k32SetFileTime;
sub SetFileTime($$;$$$$)
{
    my ($self, $file, $atime, $mtime, $ctime, $noWarn) = @_;
    my $saveFile;
    local *FH;

    # open file by name if necessary
    unless (ref $file) {
        # (file will be automatically closed when *FH goes out of scope)
        $self->Open(\*FH, $file, '+<') or $self->Warn('Error opening file for update'), return 0;
        $saveFile = $file;
        $file = \*FH;
    }
    # on Windows, try to work around incorrect file times when daylight saving time is in effect
    if ($^O eq 'MSWin32') {
        if (not eval { require Win32::API }) {
            $self->WarnOnce('Install Win32::API for proper handling of Windows file times');
        } elsif (not eval { require Win32API::File }) {
            $self->WarnOnce('Install Win32API::File for proper handling of Windows file times');
        } else {
            # get Win32 handle, needed for SetFileTime
            my $win32Handle = eval { Win32API::File::GetOsFHandle($file) };
            unless ($win32Handle) {
                $self->Warn('Win32API::File::GetOsFHandle returned invalid handle');
                return 0;
            }
            # convert Unix seconds to FILETIME structs
            my $time;
            foreach $time ($atime, $mtime, $ctime) {
                # set to NULL if not defined (i.e. do not change)
                defined $time or $time = 0, next;
                # convert to 100 ns intervals since 0:00 UTC Jan 1, 1601
                # (89 leap years between 1601 and 1970)
                my $wt = ($time + (((1970-1601)*365+89)*24*3600)) * 1e7;
                my $hi = int($wt / 4294967296);
                $time = pack 'LL', int($wt - $hi * 4294967296), $hi; # pack FILETIME struct
            }
            unless ($k32SetFileTime) {
                return 0 if defined $k32SetFileTime;
                $k32SetFileTime = new Win32::API('KERNEL32', 'SetFileTime', 'NPPP', 'I');
                unless ($k32SetFileTime) {
                    $self->Warn('Error calling Win32::API::SetFileTime');
                    $k32SetFileTime = 0;
                    return 0;
                }
            }
            unless ($k32SetFileTime->Call($win32Handle, $ctime, $atime, $mtime)) {
                $self->Warn('Win32::API::SetFileTime returned ' . Win32::GetLastError());
                return 0;
            }
            return 1;
        }
    }
    # other OS (or Windows fallback)
    if (defined $atime and defined $mtime) {
        my $success;
        local $SIG{'__WARN__'} = \&SetWarning; # (this may not be necessary)
        for (;;) {
            undef $evalWarning;
            # (this may fail on the first try if futimes is not implemented)
            $success = eval { utime($atime, $mtime, $file) };
            last if $success or not defined $saveFile;
            close $file;
            $file = $saveFile;
            undef $saveFile;
        }
        unless ($noWarn) {
            if ($@ or $evalWarning) {
                $self->Warn(CleanWarning($@ || $evalWarning));
            } elsif (not $success) {
                $self->Warn('Error setting file time');
            }
        }
        return $success;
    }
    return 1; # (nothing to do)
}

#------------------------------------------------------------------------------
# Copy data block from RAF to output file in max 64kB chunks
# Inputs: 0) RAF ref, 1) outfile ref, 2) block size
# Returns: 1 on success, 0 on read error, undef on write error
sub CopyBlock($$$)
{
    my ($raf, $outfile, $size) = @_;
    my $buff;
    for (;;) {
        last unless $size > 0;
        my $n = $size > 65536 ? 65536 : $size;
        $raf->Read($buff, $n) == $n or return 0;
        Write($outfile, $buff) or return undef;
        $size -= $n;
    }
    return 1;
}

#------------------------------------------------------------------------------
# copy image data from one file to another
# Inputs: 0) ExifTool object reference
#         1) reference to list of image data [ position, size, pad bytes ]
#         2) output file ref
# Returns: true on success
sub CopyImageData($$$)
{
    my ($self, $imageDataBlocks, $outfile) = @_;
    my $raf = $$self{RAF};
    my ($dataBlock, $err);
    my $num = @$imageDataBlocks;
    $self->VPrint(0, "  Copying $num image data blocks\n") if $num;
    foreach $dataBlock (@$imageDataBlocks) {
        my ($pos, $size, $pad) = @$dataBlock;
        $raf->Seek($pos, 0) or $err = 'read', last;
        my $result = CopyBlock($raf, $outfile, $size);
        $result or $err = defined $result ? 'read' : 'writ';
        # pad if necessary
        Write($outfile, "\0" x $pad) or $err = 'writ' if $pad;
        last if $err;
    }
    if ($err) {
        $self->Error("Error ${err}ing image data");
        return 0;
    }
    return 1;
}

#------------------------------------------------------------------------------
# write to binary data block
# Inputs: 0) ExifTool object ref, 1) source dirInfo ref, 2) tag table ref
# Returns: Binary data block or undefined on error
sub WriteBinaryData($$$)
{
    my ($self, $dirInfo, $tagTablePtr) = @_;
    $self or return 1;    # allow dummy access to autoload this package

    # get default format ('int8u' unless specified)
    my $dataPt = $$dirInfo{DataPt} or return undef;
    my $defaultFormat = $$tagTablePtr{FORMAT} || 'int8u';
    my $increment = FormatSize($defaultFormat);
    unless ($increment) {
        warn "Unknown format $defaultFormat\n";
        return undef;
    }
    # extract data members first if necessary
    my @varOffsets;
    if ($$tagTablePtr{DATAMEMBER}) {
        $$dirInfo{DataMember} = $$tagTablePtr{DATAMEMBER};
        $$dirInfo{VarFormatData} = \@varOffsets;
        $self->ProcessBinaryData($dirInfo, $tagTablePtr);
        delete $$dirInfo{DataMember};
        delete $$dirInfo{VarFormatData};
    }
    my $dirStart = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || length($$dataPt) - $dirStart;
    my $newData = substr($$dataPt, $dirStart, $dirLen) or return undef;
    my $dirName = $$dirInfo{DirName};
    my $varSize = 0;
    my @varInfo = @varOffsets;
    my $tagInfo;
    $dataPt = \$newData;
    foreach $tagInfo (sort { $$a{TagID} <=> $$b{TagID} } $self->GetNewTagInfoList($tagTablePtr)) {
        my $tagID = $$tagInfo{TagID};
        # evaluate conditional tags now if necessary
        if (ref $$tagTablePtr{$tagID} eq 'ARRAY' or $$tagInfo{Condition}) {
            my $writeInfo = $self->GetTagInfo($tagTablePtr, $tagID);
            next unless $writeInfo and $writeInfo eq $tagInfo;
        }
        # add offsets for variable-sized tags if necessary
        my $varFmt;
        while (@varInfo and $varInfo[0][0] < $tagID) {
            $varSize = $varInfo[0][1];  # get accumulated variable size
            shift @varInfo;
        }
        my $count = 1;
        my $format = $$tagInfo{Format};
        my $entry = int($tagID) * $increment + $varSize; # relative offset of this entry
        if ($format) {
            if ($format =~ /(.*)\[(.*)\]/) {
                $format = $1;
                $count = $2;
                my $size = $dirLen; # used in eval
                # evaluate count to allow count to be based on previous values
                #### eval Format size ($size, $self) - NOTE: %val not supported for writing
                $count = eval $count;
                $@ and warn($@), next;
            } elsif ($format eq 'string') {
                # string with no specified count runs to end of block
                $count = ($dirLen > $entry) ? $dirLen - $entry : 0;
            }
        } else {
            $format = $defaultFormat;
        }
        # read/write using variable format if changed in Hook
        $format = $varInfo[0][2] if @varInfo and $varInfo[0][0] == $tagID;
        my $val = ReadValue($dataPt, $entry, $format, $count, $dirLen-$entry);
        next unless defined $val;
        my $nvHash = $self->GetNewValueHash($tagInfo, $$self{CUR_WRITE_GROUP});
        next unless $self->IsOverwriting($nvHash, $val);
        my $newVal = $self->GetNewValue($nvHash);
        next unless defined $newVal;    # can't delete from a binary table
        # only write masked bits if specified
        my $mask = $$tagInfo{Mask};
        $newVal = (($newVal << $$tagInfo{BitShift}) & $mask) | ($val & ~$mask) if $mask;
        # set the size
        if ($$tagInfo{DataTag} and not $$tagInfo{IsOffset}) {
            warn 'Internal error' unless $newVal == 0xfeedfeed;
            my $data = $self->GetNewValue($$tagInfo{DataTag});
            $newVal = length($data) if defined $data;
            my $format = $$tagInfo{Format} || $$tagTablePtr{FORMAT} || 'int32u';
            if ($format =~ /^int16/ and $newVal > 0xffff) {
                $self->Error("$$tagInfo{DataTag} is too large (64 kB max. for this file)");
            }
        }
        my $rtnVal = WriteValue($newVal, $format, $count, $dataPt, $entry);
        if (defined $rtnVal) {
            $self->VerboseValue("- $dirName:$$tagInfo{Name}", $val);
            $self->VerboseValue("+ $dirName:$$tagInfo{Name}", $newVal);
            ++$$self{CHANGED};
        }
    }
    # add necessary fixups for any offsets
    if ($$tagTablePtr{IS_OFFSET} and $$dirInfo{Fixup}) {
        $varSize = 0;
        @varInfo = @varOffsets;
        my $fixup = $$dirInfo{Fixup};
        my $tagID;
        foreach $tagID (@{$$tagTablePtr{IS_OFFSET}}) {
            $tagInfo = $self->GetTagInfo($tagTablePtr, $tagID) or next;
            while (@varInfo and $varInfo[0][0] < $tagID) {
                $varSize = $varInfo[0][1];
                shift @varInfo;
            }
            my $entry = $tagID * $increment + $varSize; # (no offset to dirStart for new dir data)
            next unless $entry <= $dirLen - 4;
            # (Ricoh has 16-bit preview image offsets, so can't just assume int32u)
            my $format = $$tagInfo{Format} || $$tagTablePtr{FORMAT} || 'int32u';
            my $offset = ReadValue($dataPt, $entry, $format, 1, $dirLen-$entry);
            # ignore if offset is zero (eg. Ricoh DNG uses this to indicate no preview)
            next unless $offset;
            $fixup->AddFixup($entry, $$tagInfo{DataTag}, $format);
            # handle the preview image now if this is a JPEG file
            next unless $$self{FILE_TYPE} eq 'JPEG' and $$tagInfo{DataTag} and
                $$tagInfo{DataTag} eq 'PreviewImage' and defined $$tagInfo{OffsetPair};
            # NOTE: here we assume there are no var-sized tags between the
            # OffsetPair tags.  If this ever becomes possible we must recalculate
            # $varSize for the OffsetPair tag here!
            $entry = $$tagInfo{OffsetPair} * $increment + $varSize;
            my $size = ReadValue($dataPt, $entry, $format, 1, $dirLen-$entry);
            my $previewInfo = $$self{PREVIEW_INFO};
            $previewInfo or $previewInfo = $$self{PREVIEW_INFO} = {
                Fixup => new Image::ExifTool::Fixup,
            };
            # set flag indicating we are using short pointers
            $$previewInfo{IsShort} = 1 unless $format eq 'int32u';
            $$previewInfo{Absolute} = 1 if $$tagInfo{IsOffset} and $$tagInfo{IsOffset} eq '3';
            # get the value of the Composite::PreviewImage tag
            $$previewInfo{Data} = $self->GetNewValue($Image::ExifTool::Composite{PreviewImage});
            unless (defined $$previewInfo{Data}) {
                if ($offset >= 0 and $offset + $size <= $$dirInfo{DataLen}) {
                    $$previewInfo{Data} = substr(${$$dirInfo{DataPt}},$offset,$size);
                } else {
                    $$previewInfo{Data} = 'LOAD_PREVIEW'; # flag to load preview later
                }
            }
        }
    }
    # write any necessary SubDirectories
    if ($$tagTablePtr{IS_SUBDIR}) {
        $varSize = 0;
        @varInfo = @varOffsets;
        my $tagID;
        foreach $tagID (@{$$tagTablePtr{IS_SUBDIR}}) {
            my $tagInfo = $self->GetTagInfo($tagTablePtr, $tagID);
            next unless defined $tagInfo;
            while (@varInfo and $varInfo[0][0] < $tagID) {
                $varSize = $varInfo[0][1];
                shift @varInfo;
            }
            my $entry = int($tagID) * $increment + $varSize;
            last if $entry >= $dirLen;
            # get value for Condition if necessary
            unless ($tagInfo) {
                my $more = $dirLen - $entry;
                $more = 128 if $more > 128;
                my $v = substr($newData, $entry, $more);
                $tagInfo = $self->GetTagInfo($tagTablePtr, $tagID, \$v);
                next unless $tagInfo;
            }
            next unless $$tagInfo{SubDirectory}; # (just to be safe)
            my %subdirInfo = ( DataPt => \$newData, DirStart => $entry );
            my $subTablePtr = GetTagTable($$tagInfo{SubDirectory}{TagTable});
            my $dat = $self->WriteDirectory(\%subdirInfo, $subTablePtr);
            substr($newData, $entry) = $dat if defined $dat and length $dat;
        }
    }
    return $newData;
}

#------------------------------------------------------------------------------
# Write TIFF as a directory
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: New directory data or undefined on error
sub WriteTIFF($$$)
{
    my ($self, $dirInfo, $tagTablePtr) = @_;
    my $buff = '';
    $$dirInfo{OutFile} = \$buff;
    return $buff if $self->ProcessTIFF($dirInfo, $tagTablePtr) > 0;
    return undef;
}

1; # end

__END__

=head1 NAME

Image::ExifTool::Writer.pl - ExifTool routines for writing meta information

=head1 SYNOPSIS

These routines are autoloaded by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains ExifTool write routines and other infrequently
used routines.

=head1 AUTHOR

Copyright 2003-2018, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
