#------------------------------------------------------------------------------
# File:         PLIST.pm
#
# Description:  Read Apple PLIST information
#
# Revisions:    2013-02-01 - P. Harvey Created
#
# References:   1) http://www.apple.com/DTDs/PropertyList-1.0.dtd
#               2) http://opensource.apple.com/source/CF/CF-550/CFBinaryPList.c
#
# Notes:      - Sony MODD files also use XML PLIST format, but with a few quirks
#
#             - Decodes both the binary and XML-based PLIST formats
#------------------------------------------------------------------------------

package Image::ExifTool::PLIST;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);
use Image::ExifTool::XMP;
use Image::ExifTool::GPS;

$VERSION = '1.14';

sub ExtractObject($$;$);
sub Get24u($$);

# access routines to read various-sized integer/real values (add 0x100 to size for reals)
my %readProc = (
    1 => \&Get8u,
    2 => \&Get16u,
    3 => \&Get24u,
    4 => \&Get32u,
    8 => \&Get64u,
    0x104 => \&GetFloat,
    0x108 => \&GetDouble,
);

# recognize different types of PLIST files based on certain tags
my %plistType = (
    adjustmentBaseVersion => 'AAE',
);

# PLIST tags (generated on-the-fly for most tags)
%Image::ExifTool::PLIST::Main = (
    PROCESS_PROC => \&ProcessPLIST,
    GROUPS => { 0 => 'PLIST', 1 => 'XML', 2 => 'Document' },
    VARS => { LONG_TAGS => 12 },
    NOTES => q{
        Apple Property List tags.  ExifTool reads both XML and binary-format PLIST
        files, and will extract any existing tags even if they aren't listed below.
        These tags belong to the family 0 "PLIST" group, but family 1 group may be
        either "XML" or "PLIST" depending on whether the format is XML or binary.
    },
#
# tags found in PLIST information of QuickTime iTunesInfo iTunMOVI atom (ref PH)
#
    'cast//name'          => { Name => 'Cast',          List => 1 },
    'directors//name'     => { Name => 'Directors',     List => 1 },
    'producers//name'     => { Name => 'Producers',     List => 1 },
    'screenwriters//name' => { Name => 'Screenwriters', List => 1 },
    'codirectors//name'   => { Name => 'Codirectors',   List => 1 }, # (NC)
    'studio//name'        => { Name => 'Studio',        List => 1 }, # (NC)
#
# tags found in MODD files (ref PH)
#
    'MetaDataList//DateTimeOriginal' => {
        Name => 'DateTimeOriginal',
        Description => 'Date/Time Original',
        Groups => { 2 => 'Time' },
        # Sony uses a "real" here -- number of days since Dec 31, 1899
        ValueConv => 'IsFloat($val) ? ConvertUnixTime(($val - 25569) * 24 * 3600) : $val',
        PrintConv => '$self->ConvertDateTime($val)',
    },
    'MetaDataList//Duration' => {
        Name => 'Duration',
        Groups => { 2 => 'Video' },
        PrintConv => 'ConvertDuration($val)',
    },
    'MetaDataList//Geolocation/Latitude' => {
        Name => 'GPSLatitude',
        Groups => { 2 => 'Location' },
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "N")',
    },
    'MetaDataList//Geolocation/Longitude' => {
        Name => 'GPSLongitude',
        Groups => { 2 => 'Location' },
        PrintConv => 'Image::ExifTool::GPS::ToDMS($self, $val, 1, "E")',
    },
    'MetaDataList//Geolocation/MapDatum' => {
        Name => 'GPSMapDatum',
        Groups => { 2 => 'Location' },
    },
    # slow motion stuff found in AAE files
    'slowMotion/regions/timeRange/start/flags' => {
        Name => 'SlowMotionRegionsStartTimeFlags',
        PrintConv => { BITMASK => {
            0 => 'Valid',
            1 => 'Has been rounded',
            2 => 'Positive infinity',
            3 => 'Negative infinity',
            4 => 'Indefinite',
        }},
    },
    'slowMotion/regions/timeRange/start/value'     => 'SlowMotionRegionsStartTimeValue',
    'slowMotion/regions/timeRange/start/timescale' => 'SlowMotionRegionsStartTimeScale',
    'slowMotion/regions/timeRange/start/epoch'     => 'SlowMotionRegionsStartTimeEpoch',
    'slowMotion/regions/timeRange/duration/flags'  => {
        Name => 'SlowMotionRegionsDurationFlags',
        PrintConv => { BITMASK => {
            0 => 'Valid',
            1 => 'Has been rounded',
            2 => 'Positive infinity',
            3 => 'Negative infinity',
            4 => 'Indefinite',
        }},
    },
    'slowMotion/regions/timeRange/duration/value'     => 'SlowMotionRegionsDurationValue',
    'slowMotion/regions/timeRange/duration/timescale' => 'SlowMotionRegionsDurationTimeScale',
    'slowMotion/regions/timeRange/duration/epoch'     => 'SlowMotionRegionsDurationEpoch',
    'slowMotion/regions' => 'SlowMotionRegions',
    'slowMotion/rate' => 'SlowMotionRate',
    XMLFileType => {
        # recognize MODD files by their content
        RawConv => q{
            if ($val eq 'ModdXML' and $$self{FILE_TYPE} eq 'XMP') {
                $self->OverrideFileType('MODD');
            }
            return $val;
        },
    },
    adjustmentData => { # AAE file
        Name => 'AdjustmentData',
        CompressedPLIST => 1,
        SubDirectory => { TagTable => 'Image::ExifTool::PLIST::Main' },
    },
);

#------------------------------------------------------------------------------
# We found a PLIST XML property name/value
# Inputs: 0) ExifTool object ref, 1) tag table ref
#         2) reference to array of XML property names (last is current property)
#         3) property value, 4) attribute hash ref (not used here)
# Returns: 1 if valid tag was found
sub FoundTag($$$$;$)
{
    my ($et, $tagTablePtr, $props, $val, $attrs) = @_;
    return 0 unless @$props;
    my $verbose = $et->Options('Verbose');
    my $keys = $$et{PListKeys} || ( $$et{PListKeys} = [] );

    my $prop = $$props[-1];
    if ($verbose > 1) {
        $et->VPrint(0, $$et{INDENT}, '[', join('/',@$props), ' = ',
                    $et->Printable($val), "]\n");
    }
    # un-escape XML character entities
    $val = Image::ExifTool::XMP::UnescapeXML($val);

    # handle the various PLIST properties
    if ($prop eq 'data') {
        if ($val =~ /^[0-9a-f]+$/ and not length($val) & 0x01) {
            # MODD files use ASCII-hex encoded "data"...
            my $buff = pack('H*', $val);
            $val = \$buff;
        } else {
            # ...but the PLIST DTD specifies Base64 encoding
            $val = Image::ExifTool::XMP::DecodeBase64($val);
        }
    } elsif ($prop eq 'date') {
        $val = Image::ExifTool::XMP::ConvertXMPDate($val);
    } elsif ($prop eq 'true' or $prop eq 'false') {
        $val = ucfirst $prop;
    } else {
        # convert from UTF8 to ExifTool Charset
        $val = $et->Decode($val, 'UTF8');
        if ($prop eq 'key') {
            if (@$props <= 3) { # top-level key should be plist/dict/key
                @$keys = ( $val );
            } else {
                # save key names to be used in tag name
                push @$keys, '' while @$keys < @$props - 3;
                pop @$keys while @$keys > @$props - 2;
                $$keys[@$props - 3] = $val;
            }
            return 0;
        }
    }

    return 0 unless @$keys; # can't store value if no associated key

    my $tag = join '/', @$keys;     # generate tag ID from 'key' values
    my $tagInfo = $$tagTablePtr{$tag};
    unless ($tagInfo) {
        $et->VPrint(0, $$et{INDENT}, "[adding $tag]\n") if $verbose;
        # generate tag name from ID
        my $name = $tag;
        $name =~ s{^MetaDataList//}{};  # shorten long MODD metadata tag names
        $name =~ s{//name$}{};          # remove unnecessary MODD "name" property
        $name =~ s/([^A-Za-z])([a-z])/$1\u$2/g; # capitalize words
        $name =~ tr/-_a-zA-Z0-9//dc;    # remove illegal characters
        $tagInfo = { Name => ucfirst($name), List => 1 };
        if ($prop eq 'date') {
            $$tagInfo{Groups}{2} = 'Time';
            $$tagInfo{PrintConv} = '$self->ConvertDateTime($val)';
        }
        AddTagToTable($tagTablePtr, $tag, $tagInfo);
    }
    # allow list-behaviour only for consecutive tags with the same ID
    if ($$et{LastPListTag} and $$et{LastPListTag} ne $tagInfo) {
        delete $$et{LIST_TAGS}{$$et{LastPListTag}};
    }
    $$et{LastPListTag} = $tagInfo;
    # override file type if applicable
    $et->OverrideFileType($plistType{$tag}) if $plistType{$tag} and $$et{FILE_TYPE} eq 'XMP';
    # handle compressed PLIST/JSON data
    my $proc;
    if ($$tagInfo{CompressedPLIST} and ref $val eq 'SCALAR' and $$val !~ /^bplist00/) {
        if (eval { require IO::Uncompress::RawInflate }) {
            my $inflated;
            if (IO::Uncompress::RawInflate::rawinflate($val => \$inflated)) {
                $val = \$inflated;
            } else {
                $et->Warn("Error inflating PLIST::$$tagInfo{Name}");
            }
        } else {
            $et->Warn('Install IO::Uncompress to decode compressed PLIST data');
        }
    }
    # save the tag
    $et->HandleTag($tagTablePtr, $tag, $val, ProcessProc => $proc);

    return 1;
}

#------------------------------------------------------------------------------
# Get big-endian 24-bit integer
# Inputs: 0) data ref, 1) offset
# Returns: integer value
sub Get24u($$)
{
    my ($dataPt, $off) = @_;
    return unpack 'N', "\0" . substr($$dataPt, $off, 3);
}

#------------------------------------------------------------------------------
# Extract object from binary PLIST file at the current file position (ref 2)
# Inputs: 0) ExifTool ref, 1) PLIST info ref, 2) parent tag ID (undef for top)
# Returns: the object, or undef on error
sub ExtractObject($$;$)
{
    my ($et, $plistInfo, $parent) = @_;
    my $raf = $$plistInfo{RAF};
    my ($buff, $val);

    $raf->Read($buff, 1) == 1 or return undef;
    my $type = ord($buff) >> 4;
    my $size = ord($buff) & 0x0f;
    if ($type == 0) {       # null/bool/fill
        $val = { 0x00=>'<null>', 0x08=>'True', 0x09=>'False', 0x0f=>'<fill>' }->{$size};
    } elsif ($type == 1 or $type == 2 or $type == 3) { # int, float or date
        $size = 1 << $size;
        my $proc = ($type == 1 ? $readProc{$size} : $readProc{$size + 0x100}) or return undef;
        $val = &$proc(\$buff, 0) if $raf->Read($buff, $size) == $size;
        if ($type == 3 and defined $val) {   # date
            # dates are referenced to Jan 1, 2001 (11323 days from Unix time zero)
            $val = Image::ExifTool::ConvertUnixTime($val + 11323 * 24 * 3600, 1);
            $$plistInfo{DateFormat} = 1;
        }
    } elsif ($type == 8) {  # UID
        ++$size;
        $raf->Read($buff, $size) == $size or return undef;
        my $proc = $readProc{$size};
        if ($proc) {
            $val = &$proc(\$buff, 0);
        } elsif ($size == 16) {
            require Image::ExifTool::ASF;
            $val = Image::ExifTool::ASF::GetGUID($buff);
        } else {
            $val = "0x" . unpack 'H*', $buff;
        }
    } else {
        # $size is the size of the remaining types
        if ($size == 0x0f) {
            # size is stored in extra integer object
            $size = ExtractObject($et, $plistInfo);
            return undef unless defined $size and $size =~ /^\d+$/;
        }
        if ($type == 4) {  # data
            if ($size < 1000000 or $et->Options('Binary')) {
                $raf->Read($buff, $size) == $size or return undef;
            } else {
                $buff = "Binary data $size bytes";
            }
            $val = \$buff;  # (return reference for binary data)
        } elsif ($type == 5) {  # ASCII string
            $raf->Read($val, $size) == $size or return undef;
        } elsif ($type == 6) {  # UCS-2BE string
            $size *= 2;
            $raf->Read($buff, $size) == $size or return undef;
            $val = $et->Decode($buff, 'UCS2');
        } elsif ($type == 10 or $type == 12 or $type == 13) { # array, set or dict
            # the remaining types store a list of references
            my $refSize = $$plistInfo{RefSize};
            my $refProc = $$plistInfo{RefProc};
            my $num = $type == 13 ? $size * 2 : $size;
            my $len = $num * $refSize;
            $raf->Read($buff, $len) == $len or return undef;
            my $table = $$plistInfo{Table};
            my ($i, $ref, @refs, @array);
            for ($i=0; $i<$num; ++$i) {
                my $ref = &$refProc(\$buff, $i * $refSize);
                return 0 if $ref >= @$table;
                push @refs, $ref;
            }
            if ($type == 13) { # dict
                # prevent infinite recursion
                if (defined $parent and length $parent > 1000) {
                    $et->Warn('Possible deep recursion while parsing PLIST');
                    return undef;
                }
                my $tagTablePtr = $$plistInfo{TagTablePtr};
                my $verbose = $et->Options('Verbose');
                $val = { }; # initialize return dictionary (will stay empty if tags are saved)
                for ($i=0; $i<$size; ++$i) {
                    # get the entry key
                    $raf->Seek($$table[$refs[$i]], 0) or return undef;
                    my $key = ExtractObject($et, $plistInfo);
                    next unless defined $key and length $key; # silently ignore bad dict entries
                    # get the entry value
                    $raf->Seek($$table[$refs[$i+$size]], 0) or return undef;
                    # generate an ID for this tag
                    my $tag = defined $parent ? "$parent/$key" : $key;
                    undef $$plistInfo{DateFormat};
                    my $obj = ExtractObject($et, $plistInfo, $tag);
                    next if not defined $obj;
                    unless ($tagTablePtr) {
                        # make sure this is a valid structure field name
                        if (not defined $key or $key !~ /^[-_a-zA-Z0-9]+$/) {
                            $key = "Tag$i"; # (generate fake tag name if it had illegal characters)
                        } elsif ($key !~ /^[_a-zA-Z]/) {
                            $key = "_$key"; # (must begin with alpha or underline)
                        }
                        $$val{$key} = $obj if defined $obj;
                        next;
                    }
                    next if ref($obj) eq 'HASH';
                    my $tagInfo = $et->GetTagInfo($tagTablePtr, $tag);
                    unless ($tagInfo) {
                        $et->VPrint(0, $$et{INDENT}, "[adding $tag]\n") if $verbose;
                        my $name = $tag;
                        $name =~ s/([^A-Za-z])([a-z])/$1\u$2/g; # capitalize words
                        $name =~ tr/-_a-zA-Z0-9//dc; # remove illegal characters
                        $name = "Tag$name" if length($name) < 2 or $name =~ /^[-0-9]/;
                        $tagInfo = { Name => ucfirst($name), List => 1 };
                        if ($$plistInfo{DateFormat}) {
                            $$tagInfo{Groups}{2} = 'Time';
                            $$tagInfo{PrintConv} = '$self->ConvertDateTime($val)';
                        }
                        AddTagToTable($tagTablePtr, $tag, $tagInfo);
                    }
                    # allow list-behaviour only for consecutive tags with the same ID
                    if ($$et{LastPListTag} and $$et{LastPListTag} ne $tagInfo) {
                        delete $$et{LIST_TAGS}{$$et{LastPListTag}};
                    }
                    $$et{LastPListTag} = $tagInfo;
                    $et->HandleTag($tagTablePtr, $tag, $obj);
                }
            } else {
                # extract the referenced objects
                foreach $ref (@refs) {
                    $raf->Seek($$table[$ref], 0) or return undef;   # seek to this object
                    $val = ExtractObject($et, $plistInfo, $parent);
                    next unless defined $val and ref $val ne 'HASH';
                    push @array, $val;
                }
                $val = \@array;
            }
        }
    }
    return $val;
}

#------------------------------------------------------------------------------
# Process binary PLIST data (ref 2)
# Inputs: 0) ExifTool object ref, 1) DirInfo ref, 2) tag table ref
# Returns: 1 on success (and returns plist value as $$dirInfo{Value})
sub ProcessBinaryPLIST($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my ($i, $buff, @table);
    my $dataPt = $$dirInfo{DataPt};

    $et->VerboseDir('Binary PLIST') unless $$dirInfo{NoVerboseDir};
    SetByteOrder('MM');

    if ($dataPt) {
        my $start = $$dirInfo{DirStart};
        if ($start or ($$dirInfo{DirLen} and $$dirInfo{DirLen} != length $$dataPt)) {
            my $buf2 = substr($$dataPt, $start || 0, $$dirInfo{DirLen});
            $$dirInfo{RAF} = File::RandomAccess->new(\$buf2);
        } else {
            $$dirInfo{RAF} = File::RandomAccess->new($dataPt);
        }
        my $strt = $$dirInfo{DirStart} || 0;
    }
    # read and parse the trailer
    my $raf = $$dirInfo{RAF} or return 0;
    $raf->Seek(-32,2) and $raf->Read($buff,32)==32 or return 0;
    my $intSize = Get8u(\$buff, 6);
    my $refSize = Get8u(\$buff, 7);
    my $numObj = Get64u(\$buff, 8);
    my $topObj = Get64u(\$buff, 16);
    my $tableOff = Get64u(\$buff, 24);

    return 0 if $topObj >= $numObj;
    my $intProc = $readProc{$intSize} or return 0;
    my $refProc = $readProc{$refSize} or return 0;

    # read and parse the offset table
    my $tableSize = $intSize * $numObj;
    $raf->Seek($tableOff, 0) and $raf->Read($buff, $tableSize) == $tableSize or return 0;
    for ($i=0; $i<$numObj; ++$i) {
        push @table, &$intProc(\$buff, $i * $intSize);
    }
    my %plistInfo = (
        RAF => $raf,
        RefSize => $refSize,
        RefProc => $refProc,
        Table => \@table,
        TagTablePtr => $tagTablePtr,
    );
    # position file pointer at the top object, and extract it
    $raf->Seek($table[$topObj], 0) or return 0;
    $$dirInfo{Value} = ExtractObject($et, \%plistInfo);
    return defined $$dirInfo{Value} ? 1 : 0;
}

#------------------------------------------------------------------------------
# Extract information from a PLIST file (binary, XML or JSON format)
# Inputs: 0) ExifTool object ref, 1) dirInfo ref, 2) tag table ref
# Returns: 1 on success, 0 if this wasn't valid PLIST
sub ProcessPLIST($$;$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my ($result, $notXML);

    if ($dataPt) {
        pos($$dataPt) = $$dirInfo{DirStart} || 0;
        $notXML = 1 unless $$dataPt =~ /\G</g;
    }
    unless ($notXML) {
        # process XML PLIST data using the XMP module
        $$dirInfo{XMPParseOpts}{FoundProc} = \&FoundTag;
        $result = Image::ExifTool::XMP::ProcessXMP($et, $dirInfo, $tagTablePtr);
        delete $$dirInfo{XMPParseOpts};
        return $result if $result;
    }
    my $buff;
    my $raf = $$dirInfo{RAF};
    if ($raf) {
        $raf->Seek(0,0) and $raf->Read($buff, 64) or return 0;
        $dataPt = \$buff;
    } else {
        return 0 unless $dataPt;
    }
    if ($$dataPt =~ /^bplist0/) {  # binary PLIST
        # binary PLIST file
        my $tagTablePtr = GetTagTable('Image::ExifTool::PLIST::Main');
        $et->SetFileType('PLIST', 'application/x-plist');
        $$et{SET_GROUP1} = 'PLIST';
        unless (ProcessBinaryPLIST($et, $dirInfo, $tagTablePtr)) {
            $et->Error('Error reading binary PLIST file');
        }
        delete $$et{SET_GROUP1};
        $result = 1;
    } elsif ($$dataPt =~ /^\{"/) { # JSON PLIST
        $raf and $raf->Seek(0);
        require Image::ExifTool::JSON;
        $result = Image::ExifTool::JSON::ProcessJSON($et, $dirInfo);
    } elsif ($$et{FILE_EXT} and $$et{FILE_EXT} eq 'PLIST' and
        $$dataPt =~ /^\xfe\xff\x00/)
    {
        # (have seen very old PLIST files encoded as UCS-2BE with leading BOM)
        $et->Error('Old PLIST format currently not supported');
        $result = 1;
    }
    return $result;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::PLIST - Read Apple PLIST information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains the routines used by Image::ExifTool to extract
information from Apple Property List files.

=head1 NOTES

This module decodes both the binary and XML-based PLIST format.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://www.apple.com/DTDs/PropertyList-1.0.dtd>

=item L<http://opensource.apple.com/source/CF/CF-550/CFBinaryPList.c>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/PLIST Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

