#------------------------------------------------------------------------------
# File:         WritePhotoshop.pl
#
# Description:  Write Photoshop IRB meta information
#
# Revisions:    12/17/2004 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Photoshop;

use strict;

#------------------------------------------------------------------------------
# Strip resource name from value prepare resource name for writing into IRB
# Inputs: 0) tagInfo ref, 1) resource name (padded pascal string), 2) new value ref
# Returns: none (updates name and value if necessary)
sub SetResourceName($$$)
{
    my ($tagInfo, $name, $valPt) = @_;
    my $setName = $$tagInfo{SetResourceName};
    if (defined $setName) {
        # extract resource name from value
        if ($$valPt =~ m{.*/#(.{0,255})#/$}s) {
            $name = $1;
            # strip name from value
            $$valPt = substr($$valPt, 0, -4 - length($name));
        } elsif ($setName eq '1') {
            return;     # use old name
        } else {
            $name = $setName;
        }
        # convert to padded pascal string
        $name = chr(length $name) . $name;
        $name .= "\0" if length($name) & 0x01;
        $_[1] = $name;  # return new name
    }
}

#------------------------------------------------------------------------------
# Write Photoshop IRB resource
# Inputs: 0) ExifTool object reference, 1) source dirInfo reference,
#         2) tag table reference
# Returns: IRB resource data (may be empty if no Photoshop data)
# Notes: Increments ExifTool CHANGED flag for each tag changed
sub WritePhotoshop($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    $et or return 1;    # allow dummy access to autoload this package
    my $dataPt = $$dirInfo{DataPt};
    unless ($dataPt) {
        my $emptyData = '';
        $dataPt = \$emptyData;
    }
    my $start = $$dirInfo{DirStart} || 0;
    my $dirLen = $$dirInfo{DirLen} || (length($$dataPt) - $start);
    my $dirEnd = $start + $dirLen;
    my $newData = '';

    # make a hash of new tag info, keyed on tagID
    my $newTags = $et->GetNewTagInfoHash($tagTablePtr);

    my ($addDirs, $editDirs) = $et->GetAddDirHash($tagTablePtr);

    SetByteOrder('MM');     # Photoshop is always big-endian
#
# rewrite existing tags in the old directory, deleting ones as necessary
# (the Photoshop directory entries aren't in any particular order)
#
    # Format: 0) Type, 4 bytes - '8BIM' (or the rare 'PHUT', 'DCSR', 'AgHg' or 'MeSa')
    #         1) TagID,2 bytes
    #         2) Name, pascal string padded to even no. bytes
    #         3) Size, 4 bytes - N
    #         4) Data, N bytes
    my ($pos, $value, $size, $tagInfo, $tagID);
    for ($pos=$start; $pos+8<$dirEnd; $pos+=$size) {
        # each entry must be on same even byte boundary as directory start
        ++$pos if ($pos ^ $start) & 0x01;
        my $type = substr($$dataPt, $pos, 4);
        if ($type !~ /^(8BIM|PHUT|DCSR|AgHg|MeSa)$/) {
            $et->Error("Bad Photoshop IRB resource");
            undef $newData;
            last;
        }
        $tagID = Get16u($dataPt, $pos + 4);
        # get resource block name (pascal string padded to an even # of bytes)
        my $namelen = 1 + Get8u($dataPt, $pos + 6);
        ++$namelen if $namelen & 0x01;
        if ($pos + $namelen + 10 > $dirEnd) {
            $et->Error("Bad APP13 resource block");
            undef $newData;
            last;
        }
        my $name = substr($$dataPt, $pos + 6, $namelen);
        $size = Get32u($dataPt, $pos + 6 + $namelen);
        $pos += $namelen + 10;
        if ($size + $pos > $dirEnd) {
            $et->Error("Bad APP13 resource data size $size");
            undef $newData;
            last;
        }
        if ($$newTags{$tagID} and $type eq '8BIM') {
            $tagInfo = $$newTags{$tagID};
            delete $$newTags{$tagID};
            my $nvHash = $et->GetNewValueHash($tagInfo);
            # check to see if we are overwriting this tag
            $value = substr($$dataPt, $pos, $size);
            my $isOverwriting = $et->IsOverwriting($nvHash, $value);
            # handle special 'new' and 'old' values for IPTCDigest
            if (not $isOverwriting and $tagInfo eq $iptcDigestInfo) {
                if (grep /^new$/, @{$$nvHash{DelValue}}) {
                    $isOverwriting = 1 if $$et{NewIPTCDigest} and
                                          $$et{NewIPTCDigest} eq $value;
                }
                if (grep /^old$/, @{$$nvHash{DelValue}}) {
                    $isOverwriting = 1 if $$et{OldIPTCDigest} and
                                          $$et{OldIPTCDigest} eq $value;
                }
            }
            if ($isOverwriting) {
                $et->VerboseValue("- Photoshop:$$tagInfo{Name}", $value);
                # handle IPTCDigest specially because we want to write it last
                # so the new IPTC digest will be known
                if ($tagInfo eq $iptcDigestInfo) {
                    $$newTags{$tagID} = $tagInfo;   # add later
                    $value = undef;
                } else {
                    $value = $et->GetNewValue($nvHash);
                }
                ++$$et{CHANGED};
                next unless defined $value;     # next if tag is being deleted
                # set resource name if necessary
                SetResourceName($tagInfo, $name, \$value);
                $et->VerboseValue("+ Photoshop:$$tagInfo{Name}", $value);
            }
        } else {
            if ($type eq '8BIM') {
                $tagInfo = $$editDirs{$tagID};
                unless ($tagInfo) {
                    # process subdirectory anyway if writable (except EXIF to avoid recursion)
                    # --> this allows IPTC to be processed if found here in TIFF images
                    # (but allow EXIF to be written in PSD files if XMP or IPTC tags are
                    #  being written because I have seen cases of XMP in PSD-EXIFInfo-IFD0
                    #  and IPTC in PSD-EXIFInfo-IFD0-IPTC, see forum10768 and forum13198)
                    my $tmpInfo = $et->GetTagInfo($tagTablePtr, $tagID);
                    if ($tmpInfo and $$tmpInfo{SubDirectory} and
                        ($tmpInfo->{SubDirectory}->{TagTable} ne 'Image::ExifTool::Exif::Main' or
                         ($$et{FILE_TYPE} eq 'PSD' and ($$editDirs{0x0404} or $$editDirs{0x0424}))))
                    {
                        my $table = Image::ExifTool::GetTagTable($tmpInfo->{SubDirectory}->{TagTable});
                        $tagInfo = $tmpInfo if $$table{WRITE_PROC};
                    }
                }
            }
            if ($tagInfo) {
                $$addDirs{$tagID} and delete $$addDirs{$tagID};
                my %subdirInfo = (
                    DataPt => $dataPt,
                    DirStart => $pos,
                    DataLen => $dirLen,
                    DirLen => $size,
                    Parent => $$dirInfo{DirName},
                );
                my $subTable = Image::ExifTool::GetTagTable($tagInfo->{SubDirectory}->{TagTable});
                my $writeProc = $tagInfo->{SubDirectory}->{WriteProc};
                my $newValue = $et->WriteDirectory(\%subdirInfo, $subTable, $writeProc);
                if (defined $newValue) {
                    next unless length $newValue;   # remove subdirectory entry
                    $value = $newValue;
                    SetResourceName($tagInfo, $name, \$value);
                } else {
                    $value = substr($$dataPt, $pos, $size); # rewrite old directory
                }
            } else {
                $value = substr($$dataPt, $pos, $size);
            }
        }
        my $newSize = length $value;
        # write this directory entry
        $newData .= $type . Set16u($tagID) . $name . Set32u($newSize) . $value;
        $newData .= "\0" if $newSize & 0x01;    # must null pad to even byte
    }
#
# write any remaining entries we didn't find in the old directory
# (might as well write them in numerical tag order)
#
    my @tagsLeft = sort { $a <=> $b } keys(%$newTags), keys(%$addDirs);
    foreach $tagID (@tagsLeft) {
        my $name = "\0\0";
        if ($$newTags{$tagID}) {
            $tagInfo = $$newTags{$tagID};
            my $nvHash = $et->GetNewValueHash($tagInfo);
            $value = $et->GetNewValue($nvHash);
            # handle new IPTCDigest value specially
            if ($tagInfo eq $iptcDigestInfo and defined $value) {
                if ($value eq 'new') {
                    $value = $$et{NewIPTCDigest};
                } elsif ($value eq 'old') {
                    $value = $$et{OldIPTCDigest};
                }
                # (we already know we want to create this tag)
            } else {
                # don't add this tag unless specified
                next unless $$nvHash{IsCreating};
            }
            next unless defined $value;     # next if tag is being deleted
            $et->VerboseValue("+ Photoshop:$$tagInfo{Name}", $value);
            ++$$et{CHANGED};
        } else {
            $tagInfo = $$addDirs{$tagID};
            # create new directory
            my %subdirInfo = (
                Parent => $$dirInfo{DirName},
            );
            my $subTable = Image::ExifTool::GetTagTable($tagInfo->{SubDirectory}->{TagTable});
            my $writeProc = $tagInfo->{SubDirectory}->{WriteProc};
            $value = $et->WriteDirectory(\%subdirInfo, $subTable, $writeProc);
            next unless $value;
        }
        # set resource name if necessary
        SetResourceName($tagInfo, $name, \$value);
        $size = length($value);
        # write the new directory entry
        $newData .= '8BIM' . Set16u($tagID) . $name . Set32u($size) . $value;
        $newData .= "\0" if $size & 0x01;   # must null pad to even numbered byte
        ++$$et{CHANGED};
    }
    return $newData;
}


1; # end

__END__

=head1 NAME

Image::ExifTool::WritePhotoshop.pl - Write Photoshop IRB meta information

=head1 SYNOPSIS

This file is autoloaded by Image::ExifTool::Photoshop.

=head1 DESCRIPTION

This file contains routines to write Photoshop metadata.

=head1 NOTES

Photoshop IRB blocks may have an associated resource name.  By default, the
existing name is preserved when rewriting a resource, and an empty name is
used when creating a new resource.  However, a different resource name may
be specified by defining a C<SetResourceName> entry in the tag information
hash.  With this defined, a new resource name may be appended to the value
in the form "VALUE/#NAME#/" (the slashes and hashes are literal).  If
C<SetResourceName> is anything other than '1', the value is used as a
default resource name, and applied if no appended name is provided.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::Photoshop(3pm)|Image::ExifTool::Photoshop>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
