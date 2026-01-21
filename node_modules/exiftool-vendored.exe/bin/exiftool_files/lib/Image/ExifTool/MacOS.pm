#------------------------------------------------------------------------------
# File:         MacOS.pm
#
# Description:  Read/write MacOS system tags
#
# Revisions:    2017/03/01 - P. Harvey Created
#               2020/10/13 - PH Added ability to read MacOS "._" files
#------------------------------------------------------------------------------

package Image::ExifTool::MacOS;
use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.14';

sub MDItemLocalTime($);
sub ProcessATTR($$$);

my %mdDateInfo = (
    ValueConv => \&MDItemLocalTime,
    PrintConv => '$self->ConvertDateTime($val)',
);

my %delXAttr = (
    XAttrQuarantine => 'com.apple.quarantine',
    XAttrMDItemWhereFroms => 'com.apple.metadata:kMDItemWhereFroms',
);

# Information decoded from Mac OS sidecar files
%Image::ExifTool::MacOS::Main = (
    GROUPS => { 0 => 'File', 1 => 'MacOS' },
    NOTES => q{
        Note that on some filesystems, MacOS creates sidecar files with names that
        begin with "._".  ExifTool will read these files if specified, and extract
        the information listed in the following table without the need for extra
        options, but these files are not writable directly.
    },
    2 => {
        Name => 'RSRC',
        SubDirectory => { TagTable => 'Image::ExifTool::RSRC::Main' },
    },
    9 => {
        Name => 'ATTR',
        SubDirectory => {
            TagTable => 'Image::ExifTool::MacOS::XAttr',
            ProcessProc => \&ProcessATTR,
        },
    },
);

# "mdls" tags (ref PH)
%Image::ExifTool::MacOS::MDItem = (
    WRITE_PROC => \&Image::ExifTool::DummyWriteProc,
    VARS => { ID_FMT => 'none' },
    GROUPS => { 0 => 'File', 1 => 'MacOS', 2 => 'Other' },
    NOTES => q{
        MDItem tags are extracted using the "mdls" utility.  They are extracted if
        any "MDItem*" tag or the MacOS group is specifically requested, or by
        setting the API L<MDItemTags|../ExifTool.html#MDItemTags> option to 1 or the API L<RequestAll|../ExifTool.html#RequestAll> option to 2 or
        higher.  Note that these tags do not necessarily reflect the current
        metadata of a file -- it may take some time for the MacOS mdworker daemon to
        index the file after a metadata change.
    },
    MDItemFinderComment => {
        Writable => 1,
        WritePseudo => 1,
        Protected => 1, # (all writable pseudo tags must be protected)
    },
    MDItemFSLabel => {
        Writable => 1,
        WritePseudo => 1,
        Protected => 1, # (all writable pseudo tags must be protected)
        WriteCheck => '$val =~ /^[0-7]$/ ? undef : "Not an integer in the range 0-7"',
        PrintConv => {
            0 => '0 (none)',
            1 => '1 (Gray)',
            2 => '2 (Green)',
            3 => '3 (Purple)',
            4 => '4 (Blue)',
            5 => '5 (Yellow)',
            6 => '6 (Red)',
            7 => '7 (Orange)',
        },
    },
    MDItemFSCreationDate => {
        Writable => 1,
        WritePseudo => 1,
        DelCheck => q{"Can't delete"},
        Protected => 1, # (all writable pseudo tags must be protected)
        Shift => 'Time', # (but not supported yet)
        Notes => q{
            file creation date.  Requires "setfile" for writing.  Note that when
            reading, it may take a few seconds after writing a file before this value
            reflects the change.  However, L<FileCreateDate|Extra.html> is updated immediately
        },
        Groups => { 2 => 'Time' },
        ValueConv => \&MDItemLocalTime,
        ValueConvInv => '$val',
        PrintConv => '$self->ConvertDateTime($val)',
        PrintConvInv => '$self->InverseDateTime($val)',
    },
    MDItemAcquisitionMake         => { Groups => { 2 => 'Camera' } },
    MDItemAcquisitionModel        => { Groups => { 2 => 'Camera' } },
    MDItemAltitude                => { Groups => { 2 => 'Location' } },
    MDItemAperture                => { Groups => { 2 => 'Camera' } },
    MDItemAudioBitRate            => { Groups => { 2 => 'Audio' } },
    MDItemAudioChannelCount       => { Groups => { 2 => 'Audio' } },
    MDItemAuthors                 => { Groups => { 2 => 'Author' } },
    MDItemBitsPerSample           => { Groups => { 2 => 'Image' } },
    MDItemCity                    => { Groups => { 2 => 'Location' } },
    MDItemCodecs                  => { },
    MDItemColorSpace              => { Groups => { 2 => 'Image' } },
    MDItemComment                 => { },
    MDItemContentCreationDate     => { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemContentCreationDateRanking => { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemContentModificationDate => { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemContentType             => { },
    MDItemContentTypeTree         => { },
    MDItemContributors            => { },
    MDItemCopyright               => { Groups => { 2 => 'Author' } },
    MDItemCountry                 => { Groups => { 2 => 'Location' } },
    MDItemCreator                 => { Groups => { 2 => 'Document' } },
    MDItemDateAdded               => { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemDescription             => { },
    MDItemDisplayName             => { },
    MDItemDownloadedDate          => { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemDurationSeconds         => { PrintConv => 'ConvertDuration($val)' },
    MDItemEncodingApplications    => { },
    MDItemEXIFGPSVersion          => { Groups => { 2 => 'Location' }, Description => 'MD Item EXIF GPS Version' },
    MDItemEXIFVersion             => { },
    MDItemExposureMode            => { Groups => { 2 => 'Camera' } },
    MDItemExposureProgram         => { Groups => { 2 => 'Camera' } },
    MDItemExposureTimeSeconds     => { Groups => { 2 => 'Camera' } },
    MDItemFlashOnOff              => { Groups => { 2 => 'Camera' } },
    MDItemFNumber                 => { Groups => { 2 => 'Camera' } },
    MDItemFocalLength             => { Groups => { 2 => 'Camera' } },
    MDItemFSContentChangeDate     => { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemFSCreatorCode           => { Groups => { 2 => 'Author' } },
    MDItemFSFinderFlags           => { },
    MDItemFSHasCustomIcon         => { },
    MDItemFSInvisible             => { },
    MDItemFSIsExtensionHidden     => { },
    MDItemFSIsStationery          => { },
    MDItemFSName                  => { },
    MDItemFSNodeCount             => { },
    MDItemFSOwnerGroupID          => { },
    MDItemFSOwnerUserID           => { },
    MDItemFSSize                  => { },
    MDItemFSTypeCode              => { },
    MDItemGPSDateStamp            => { Groups => { 2 => 'Time' } },
    MDItemGPSStatus               => { Groups => { 2 => 'Location' } },
    MDItemGPSTrack                => { Groups => { 2 => 'Location' } },
    MDItemHasAlphaChannel         => { Groups => { 2 => 'Image' } },
    MDItemImageDirection          => { Groups => { 2 => 'Location' } },
    MDItemInterestingDateRanking  => { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemISOSpeed                => { Groups => { 2 => 'Camera' } },
    MDItemKeywords                => { },
    MDItemKind                    => { },
    MDItemLastUsedDate            => { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemLastUsedDate_Ranking    => { },
    MDItemLatitude                => { Groups => { 2 => 'Location' } },
    MDItemLensModel               => { },
    MDItemLogicalSize             => { },
    MDItemLongitude               => { Groups => { 2 => 'Location' } },
    MDItemMediaTypes              => { },
    MDItemNumberOfPages           => { },
    MDItemOrientation             => { Groups => { 2 => 'Image' } },
    MDItemOriginApplicationIdentifier => { },
    MDItemOriginMessageID         => { },
    MDItemOriginSenderDisplayName => { },
    MDItemOriginSenderHandle      => { },
    MDItemOriginSubject           => { },
    MDItemPageHeight              => { Groups => { 2 => 'Image' } },
    MDItemPageWidth               => { Groups => { 2 => 'Image' } },
    MDItemPhysicalSize            => { Groups => { 2 => 'Image' } },
    MDItemPixelCount              => { Groups => { 2 => 'Image' } },
    MDItemPixelHeight             => { Groups => { 2 => 'Image' } },
    MDItemPixelWidth              => { Groups => { 2 => 'Image' } },
    MDItemProfileName             => { Groups => { 2 => 'Image' } },
    MDItemRedEyeOnOff             => { Groups => { 2 => 'Camera' } },
    MDItemResolutionHeightDPI     => { Groups => { 2 => 'Image' } },
    MDItemResolutionWidthDPI      => { Groups => { 2 => 'Image' } },
    MDItemSecurityMethod          => { },
    MDItemSpeed                   => { Groups => { 2 => 'Location' } },
    MDItemStateOrProvince         => { Groups => { 2 => 'Location' } },
    MDItemStreamable              => { },
    MDItemTimestamp               => { Groups => { 2 => 'Time' } }, # (time only)
    MDItemTitle                   => { },
    MDItemTotalBitRate            => { },
    MDItemUseCount                => { },
    MDItemUsedDates               => { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemUserDownloadedDate      => { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemUserDownloadedUserHandle=> { },
    MDItemUserSharedReceivedDate  => { },
    MDItemUserSharedReceivedRecipient => { },
    MDItemUserSharedReceivedRecipientHandle => { },
    MDItemUserSharedReceivedSender=> { },
    MDItemUserSharedReceivedSenderHandle => { },
    MDItemUserSharedReceivedTransport => { },
    MDItemUserTags                => {
        List => 1,
        Writable => 1,
        WritePseudo => 1,
        Protected => 1, # (all writable pseudo tags must be protected)
        Notes => q{
            requires "tag" utility for writing -- install with "brew install tag".  Note
            that user tags may not contain a comma, and that duplicate user tags will
            not be written
        },
    },
    MDItemVersion                 => { },
    MDItemVideoBitRate            => { Groups => { 2 => 'Video' } },
    MDItemWhereFroms              => { },
    MDItemWhiteBalance            => { Groups => { 2 => 'Image' } },
    # tags used by Apple Mail on .emlx files
    com_apple_mail_dateReceived   => { Name => 'AppleMailDateReceived', Groups => { 2 => 'Time' }, %mdDateInfo },
    com_apple_mail_dateSent       => { Name => 'AppleMailDateSent',     Groups => { 2 => 'Time' }, %mdDateInfo },
    com_apple_mail_flagged        => { Name => 'AppleMailFlagged' },
    com_apple_mail_messageID      => { Name => 'AppleMailMessageID' },
    com_apple_mail_priority       => { Name => 'AppleMailPriority' },
    com_apple_mail_read           => { Name => 'AppleMailRead' },
    com_apple_mail_repliedTo      => { Name => 'AppleMailRepliedTo' },
    com_apple_mail_isRemoteAttachment => { Name => 'AppleMailIsRemoteAttachment' },
    MDItemAccountHandles          => { },
    MDItemAccountIdentifier       => { },
    MDItemAuthorEmailAddresses    => { },
    MDItemBundleIdentifier        => { },
    MDItemContentCreationDate_Ranking=>{Groups=> { 2 => 'Time' }, %mdDateInfo },
    MDItemDateAdded_Ranking       => { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemEmailConversationID     => { },
    MDItemIdentifier              => { },
    MDItemInterestingDate_Ranking => { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemIsApplicationManaged    => { },
    MDItemIsExistingThread        => { },
    MDItemIsLikelyJunk            => { },
    MDItemMailboxes               => { },
    MDItemMailDateReceived_Ranking=> { Groups => { 2 => 'Time' }, %mdDateInfo },
    MDItemPrimaryRecipientEmailAddresses => { },
    MDItemRecipients              => { },
    MDItemSubject                 => { },
);

# "xattr" tags
%Image::ExifTool::MacOS::XAttr = (
    WRITE_PROC => \&Image::ExifTool::DummyWriteProc,
    GROUPS => { 0 => 'File', 1 => 'MacOS', 2 => 'Other' },
    VARS => { ID_FMT => 'none' }, # (id's are too long)
    NOTES => q{
        XAttr tags are extracted using the "xattr" utility.  They are extracted if
        any "XAttr*" tag or the MacOS group is specifically requested, or by setting
        the API L<XAttrTags|../ExifTool.html#XAttrTags> option to 1 or the API L<RequestAll|../ExifTool.html#RequestAll> option to 2 or higher.
        And they are extracted by default from MacOS "._" files when reading
        these files directly.
    },
    'com.apple.FinderInfo' => {
        Name => 'XAttrFinderInfo',
        ConvertBinary => 1,
        # ref https://opensource.apple.com/source/CarbonHeaders/CarbonHeaders-9A581/Finder.h
        ValueConv => q{
            my @a = unpack('a4a4n3x10nx2N', $$val);
            tr/\0//d, $_="'${_}'" foreach @a[0,1];
            return "@a";
        },
        PrintConv => q{
            $val =~ s/^('.*?') ('.*?') //s or return $val;
            my ($type, $creator) = ($1, $2);
            my ($flags, $y, $x, $exFlags, $putAway) = split ' ', $val;
            my $label = ($flags >> 1) & 0x07;
            my $flags = DecodeBits((($exFlags<<16) | $flags) & 0xfff1, {
                0 => 'OnDesk',
                6 => 'Shared',
                7 => 'HasNoInits',
                8 => 'Inited',
                10 => 'CustomIcon',
                11 => 'Stationery',
                12 => 'NameLocked',
                13 => 'HasBundle',
                14 => 'Invisible',
                15 => 'Alias',
                # extended flags
                22 => 'HasRoutingInfo',
                23 => 'ObjectBusy',
                24 => 'CustomBadge',
                31 => 'ExtendedFlagsValid',
            });
            my $str = "Type=$type Creator=$creator Flags=$flags Label=$label Pos=($x,$y)";
            $str .= " Putaway=$putAway" if $putAway;
            return $str;
        },
    },
    'com.apple.quarantine' => {
        Name => 'XAttrQuarantine',
        Writable => 1,
        WritePseudo => 1,
        WriteCheck => '"May only delete this tag"',
        Protected => 1,
        Notes => q{
            quarantine information for files downloaded from the internet.  May only be
            deleted when writing
        },
        # ($a[1] is the time when the quarantine tag was set)
        PrintConv => q{
            my @a = split /;/, $val;
            $a[0] = 'Flags=' . $a[0];
            $a[1] = 'set at ' . ConvertUnixTime(hex $a[1]);
            $a[2] = 'by ' . $a[2];
            return join ' ', @a;
        },
        PrintConvInv => '$val',
    },
    'com.apple.metadata:com_apple_mail_dateReceived' => {
        Name => 'XAttrAppleMailDateReceived',
        Groups => { 2 => 'Time' },
    },
    'com.apple.metadata:com_apple_mail_dateSent' => {
        Name => 'XAttrAppleMailDateSent',
        Groups => { 2 => 'Time' },
    },
    'com.apple.metadata:com_apple_mail_isRemoteAttachment' => {
        Name => 'XAttrAppleMailIsRemoteAttachment',
    },
    'com.apple.metadata:kMDItemDownloadedDate' => {
        Name => 'XAttrMDItemDownloadedDate',
        Groups => { 2 => 'Time' },
    },
    'com.apple.metadata:kMDItemFinderComment'  => { Name => 'XAttrMDItemFinderComment' },
    'com.apple.metadata:kMDItemWhereFroms' => {
        Name => 'XAttrMDItemWhereFroms',
        Writable => 1,
        WritePseudo => 1,
        WriteCheck => '"May only delete this tag"',
        Protected => 1,
        Notes => q{
            information about where the file came from.  May only be deleted when
            writing
        },
    },
    'com.apple.metadata:kMDLabel'              => { Name => 'XAttrMDLabel', Binary => 1 },
    'com.apple.ResourceFork'                   => { Name => 'XAttrResourceFork', Binary => 1 },
    'com.apple.lastuseddate#PS'                => {
        Name => 'XAttrLastUsedDate',
        Groups => { 2 => 'Time' },
        # (first 4 bytes are date/time.  Not sure what remaining 12 bytes are for)
        RawConv => 'ConvertUnixTime(unpack("V",$$val))',
        PrintConv => '$self->ConvertDateTime($val)',
    },
);

#------------------------------------------------------------------------------
# Convert OS MDItem time string to standard EXIF-formatted local time
# Inputs: 0) time string (eg. "2017-02-21 17:21:43 +0000")
# Returns: EXIF-formatted local time string with timezone
sub MDItemLocalTime($)
{
    my $val = shift;
    $val =~ tr/-/:/;
    $val =~ s/ ?([-+]\d{2}):?(\d{2})/$1:$2/;
    # convert from UTC to local time
    if ($val =~ /\+00:00$/) {
        my $time = Image::ExifTool::GetUnixTime($val);
        $val = Image::ExifTool::ConvertUnixTime($time, 1) if $time;
    }
    return $val;
}

#------------------------------------------------------------------------------
# Set MacOS MDItem and XAttr tags from new tag values
# Inputs: 0) ExifTool ref, 1) file name, 2) list of tags to set
# Returns: 1=something was set OK, 0=didn't try, -1=error (and warning set)
# Notes: There may be errors even if 1 is returned
sub SetMacOSTags($$$)
{
    my ($et, $file, $setTags) = @_;
    my $result = 0;
    my $tag;

    foreach $tag (@$setTags) {
        my ($nvHash, $f, $v, $attr, $cmd, $err, $silentErr);
        my $val = $et->GetNewValue($tag, \$nvHash);
        next unless $nvHash;
        my $overwrite = $et->IsOverwriting($nvHash);
        unless ($$nvHash{TagInfo}{List}) {
            next unless $overwrite;
            if ($overwrite < 0) {
                my $operation = $$nvHash{Shift} ? 'Shifting' : 'Conditional replacement';
                $et->Warn("$operation of MacOS $tag not yet supported");
                next;
            }
        }
        if ($tag eq 'MDItemFSCreationDate' or $tag eq 'FileCreateDate') {
            ($f = $file) =~ s/'/'\\''/g;
            # convert to local time if value has a time zone
            if ($val =~ /[-+Z]/) {
                my $time = Image::ExifTool::GetUnixTime($val, 1);
                $val = Image::ExifTool::ConvertUnixTime($time, 1) if $time;
                $val =~ s/[-+].*//; # remove time zone
            }
            $val =~ s{(\d{4}):(\d{2}):(\d{2})}{$2/$3/$1};   # reformat for setfile
            $cmd = "/usr/bin/setfile -d '${val}' '${f}'";
        } elsif ($tag eq 'MDItemUserTags') {
            # (tested with "tag" version 0.9.0)
            ($f = $file) =~ s/'/'\\''/g;
            my @vals = $et->GetNewValue($nvHash);
            if ($overwrite < 0 and @{$$nvHash{DelValue}}) {
                # delete specified tags
                my @dels = @{$$nvHash{DelValue}};
                s/'/'\\''/g foreach @dels;
                my $del = join ',', @dels;
                $err = system "/usr/local/bin/tag -r '${del}' '${f}'>/dev/null 2>&1";
                unless ($err) {
                    $et->VerboseValue("- $tag", $del);
                    $result = 1;
                    undef $err if @vals;    # more to do if there are tags to add
                }
            }
            unless (defined $err) {
                # add new tags, or overwrite or delete existing tags
                s/'/'\\''/g foreach @vals;
                my $opt = $overwrite > 0 ? '-s' : '-a';
                $val = @vals ? join(',', @vals) : '';
                $cmd = "/usr/local/bin/tag $opt '${val}' '${f}'";
                $et->VPrint(1,"    - $tag = (all)\n") if $overwrite > 0;
                undef $val if $val eq '';
            }
        } elsif ($delXAttr{$tag}) {
            ($f = $file) =~ s/'/'\\''/g;
            $cmd = "/usr/bin/xattr -d $delXAttr{$tag} '${f}'";
            $silentErr = 256;   # (will get this error if attribute doesn't exist)
        } else {
            ($f = $file) =~ s/(["\\])/\\$1/g;   # escape necessary characters for script
            $f =~ s/'/'"'"'/g;
            if ($tag eq 'MDItemFinderComment') {
                # (write finder comment using osascript instead of xattr
                # because it is more work to construct the necessary bplist)
                $val = '' unless defined $val;  # set to empty string instead of deleting
                $v = $et->Encode($val, 'UTF8');
                $v =~ s/(["\\])/\\$1/g;
                $v =~ s/'/'"'"'/g;
                $attr = 'comment';
            } else { # $tag eq 'MDItemFSLabel'
                $v = $val ? 8 - $val : 0;       # convert from label to label index (0 for no label)
                $attr = 'label index';
            }
            $cmd = qq(/usr/bin/osascript -e 'set fp to POSIX file "$f" as alias' -e \\
                'tell application "Finder" to set $attr of file fp to "$v"');
        }
        if (defined $cmd) {
            $err = system $cmd . '>/dev/null 2>&1'; # (pipe all output to /dev/null)
        }
        if (not $err) {
            $et->VerboseValue("+ $tag", $val) if defined $val;
            $result = 1;
        } elsif (not $silentErr or $err != $silentErr) {
            $cmd =~ s/ .*//s;
            $et->Warn(qq{Error $err running "$cmd" to set $tag});
            $result = -1 unless $result;
        }
    }
    return $result;
}

#------------------------------------------------------------------------------
# Extract MacOS metadata item tags
# Inputs: 0) ExifTool object ref, 1) file name
sub ExtractMDItemTags($$)
{
    local $_;
    my ($et, $file) = @_;
    my ($fn, $tag, $val, $tmp);

    ($fn = $file) =~ s/([`"\$\\])/\\$1/g;   # escape necessary characters
    $et->VPrint(0, '(running mdls)');
    my @mdls = `/usr/bin/mdls "$fn" 2> /dev/null`;   # get MacOS metadata
    if ($? or not @mdls) {
        $et->Warn('Error running "mdls" to extract MDItem tags');
        return;
    }
    my $tagTablePtr = GetTagTable('Image::ExifTool::MacOS::MDItem');
    $$et{INDENT} .= '| ';
    $et->VerboseDir('MDItem');
    foreach (@mdls) {
        chomp;
        if (ref $val ne 'ARRAY') {
            s/^k?(\w+)\s*= // or next;
            $tag = $1;
            $_ eq '(' and $val = [ ], next; # (start of a list)
            $_ = '' if $_ eq '(null)';
            s/^"// and s/"$//;  # remove quotes if they exist
            $val = $_;
        } elsif ($_ eq ')') {   # (end of a list)
            $_ = $$val[0];
            next unless defined $_;
        } else {
            # add item to list
            s/^    //;          # remove leading spaces
            s/,$//;             # remove trailing comma
            $_ = '' if $_ eq '(null)';
            s/^"// and s/"$//;  # remove quotes if they exist
            s/\\"/"/g;          # un-escape quotes
            $_ = $et->Decode($_, 'UTF8');
            push @$val, $_;
            next;
        }
        # add to Extra tags if not done already
        unless ($$tagTablePtr{$tag}) {
            # check for a date/time format
            my %tagInfo;
            %tagInfo = (
                Groups => { 2 => 'Time' },
                ValueConv => \&MDItemLocalTime,
                PrintConv => '$self->ConvertDateTime($val)',
            ) if /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/;
            # change tags like "com_apple_mail_xxx" to "AppleMailXxx"
            ($tmp = $tag) =~ s/^com_//; # remove leading "com_"
            $tmp =~ s/_([a-z])/\u$1/g;  # use CamelCase
            $tagInfo{Name} = Image::ExifTool::MakeTagName($tmp);
            $tagInfo{List} = 1 if ref $val eq 'ARRAY';
            $tagInfo{Groups}{2} = 'Audio' if $tag =~ /Audio/;
            $tagInfo{Groups}{2} = 'Author' if $tag =~ /(Copyright|Author)/;
            $et->VPrint(0, "  [adding $tag]\n");
            AddTagToTable($tagTablePtr, $tag, \%tagInfo);
        }
        $val = $et->Decode($val, 'UTF8') unless ref $val;
        $et->HandleTag($tagTablePtr, $tag, $val);
        undef $val;
    }
    $$et{INDENT} =~ s/\| $//;
}

#------------------------------------------------------------------------------
# Read MacOS XAttr value
# Inputs: 0) ExifTool object ref, 1) file name
sub ReadXAttrValue($$$$)
{
    my ($et, $tagTablePtr, $tag, $val) = @_;
    # add to our table if necessary
    unless ($$tagTablePtr{$tag}) {
        my $name;
        # generate tag name from attribute name
        if ($tag =~ /^com\.apple\.(.*)$/) {
            ($name = $1) =~ s/^metadata:_?k//;
            $name =~ s/^metadata:(com_)?//;
        } else {
            $name = $tag;
        }
        $name =~ s/[.:_]([a-z])/\U$1/g;
        $name = 'XAttr' . ucfirst $name;
        my %tagInfo = ( Name => $name );
        $tagInfo{Groups} = { 2 => 'Time' } if $tag=~/Date$/;
        $et->VPrint(0, "  [adding $tag]\n");
        AddTagToTable($tagTablePtr, $tag, \%tagInfo);
    }
    if ($val =~ /^bplist0/) {
        my %dirInfo = ( DataPt => \$val );
        require Image::ExifTool::PLIST;
        if (Image::ExifTool::PLIST::ProcessBinaryPLIST($et, \%dirInfo, $tagTablePtr)) {
            return undef if ref $dirInfo{Value} eq 'HASH';
            $val = $dirInfo{Value}
        } else {
            $et->Warn("Error decoding $$tagTablePtr{$tag}{Name}");
            return undef;
        }
    }
    if (not ref $val and ($val =~ /\0/ or length($val) > 200) or $tag eq 'XAttrMDLabel') {
        my $buff = $val;
        $val = \$buff;
    }
    return $val;
}

#------------------------------------------------------------------------------
# Read MacOS extended attribute tags using 'xattr' utility
# Inputs: 0) ExifTool object ref, 1) file name
sub ExtractXAttrTags($$)
{
    local $_;
    my ($et, $file) = @_;
    my ($fn, $tag, $val, $warn);

    ($fn = $file) =~ s/([`"\$\\])/\\$1/g;       # escape necessary characters
    $et->VPrint(0, '(running xattr)');
    my @xattr = `/usr/bin/xattr -lx "$fn" 2> /dev/null`; # get MacOS extended attributes
    if ($? or not @xattr) {
        $? and $et->Warn('Error running "xattr" to extract XAttr tags');
        return;
    }
    my $tagTablePtr = GetTagTable('Image::ExifTool::MacOS::XAttr');
    $$et{INDENT} .= '| ';
    $et->VerboseDir('XAttr');
    push @xattr, '';    # (for a list terminator)
    foreach (@xattr) {
        chomp;
        if (s/^[\dA-Fa-f]{8}//) {
            $tag or $warn = 1, next;
            s/\|.*//;
            tr/ //d;
            (/[^\dA-Fa-f]/ or length($_) & 1) and $warn = 2, next;
            $val = '' unless defined $val;
            $val .= pack('H*', $_);
            next;
        } elsif ($tag and defined $val) {
            $val = ReadXAttrValue($et, $tagTablePtr, $tag, $val);
            $et->HandleTag($tagTablePtr, $tag, $val) if defined $val;
            undef $tag;
            undef $val;
        }
        next unless length;
        s/:$// or $warn = 3, next;  # attribute name must have trailing ":"
        defined $val and $warn = 4, undef $val;
        # remove random ID after kMDLabel in tag ID
        ($tag = $_) =~ s/^com.apple.metadata:kMDLabel_.*/com.apple.metadata:kMDLabel/s;
    }
    $warn and $et->Warn(qq{Error $warn parsing "xattr" output});
    $$et{INDENT} =~ s/\| $//;
}

#------------------------------------------------------------------------------
# Extract MacOS file creation date/time
# Inputs: 0) ExifTool object ref, 1) file name
sub GetFileCreateDate($$)
{
    local $_;
    my ($et, $file) = @_;
    my ($fn, $tag, $val, $tmp);

    ($fn = $file) =~ s/([`"\$\\])/\\$1/g;   # escape necessary characters
    $et->VPrint(0, '(running stat)');
    my $time = `/usr/bin/stat -f '%SB' -t '%Y:%m:%d %H:%M:%S%z' "$fn" 2> /dev/null`;
    if ($? or not $time or $time !~ s/([-+]\d{2})(\d{2})\s*$/$1:$2/) {
        $et->Warn('Error running "stat" to extract FileCreateDate');
        return;
    }
    $$et{SET_GROUP1} = 'MacOS';
    $et->FoundTag(FileCreateDate => $time);
    delete $$et{SET_GROUP1};
}

#------------------------------------------------------------------------------
# Read ATTR metadata from "._" file
# Inputs: 0) ExifTool ref, 1) dirInfo ref, 2) tag table ref
# Return: 1 on success
# (ref https://www.swiftforensics.com/2018/11/the-dot-underscore-file-format.html)
sub ProcessATTR($$$)
{
    my ($et, $dirInfo, $tagTablePtr) = @_;
    my $dataPt = $$dirInfo{DataPt};
    my $dataPos = $$dirInfo{DataPos};
    my $dataLen = length $$dataPt;

    $dataLen >= 58 and $$dataPt =~ /^.{34}ATTR/s or $et->Warn('Invalid ATTR header'), return 0;
    my $entries = Get32u($dataPt, 66);
    $et->VerboseDir('ATTR', $entries);
    # (Note: The RAF is not in $dirInfo because it would break RSRC reading --
    # the RSCR block uses relative offsets, while the ATTR block uses absolute! grrr!)
    my $raf = $$et{RAF};
    my $pos = 70;       # first entry is after ATTR header
    my $i;
    for ($i=0; $i<$entries; ++$i) {
        $pos + 12 > $dataLen and $et->Warn('Truncated ATTR entry'), last;
        my $off = Get32u($dataPt, $pos);
        my $len = Get32u($dataPt, $pos + 4);
        my $n = Get8u($dataPt, $pos + 10);  # number of characters in tag name
        $pos + 11 + $n > $dataLen and $et->Warn('Truncated ATTR name'), last;
        $off -= $dataPos;       # convert to relative offset (grrr!)
        $off < 0 or $off > $dataLen and $et->Warn('Invalid ATTR offset'), last;
        my $tag = substr($$dataPt, $pos + 11, $n);
        $tag =~ s/\0+$//;       # remove null terminator
        # remove random ID after kMDLabel in tag ID
        $tag =~ s/^com.apple.metadata:kMDLabel_.*/com.apple.metadata:kMDLabel/s;
        $off + $len > $dataLen and $et->Warn('Truncated ATTR value'), last;
        my $val = ReadXAttrValue($et, $tagTablePtr, $tag, substr($$dataPt, $off, $len));
        $et->HandleTag($tagTablePtr, $tag, $val,
            DataPt  => $dataPt,
            DataPos => $dataPos,
            Start   => $off,
            Size    => $len,
        ) if defined $val;
        $pos += (11 + $n + 3) & -4; # step to next entry (on even 4-byte boundary)
    }
    return 1;
}

#------------------------------------------------------------------------------
# Read information from a MacOS "._" sidecar file
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid "._" file
# (ref https://www.swiftforensics.com/2018/11/the-dot-underscore-file-format.html)
sub ProcessMacOS($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($hdr, $buff, $i);

    return 0 unless $raf->Read($hdr, 26) == 26 and $hdr =~ /^\0\x05\x16\x07\0(.)\0\0Mac OS X        /s;
    my $ver = ord $1;
    # (extension may be anything, so just echo back the incoming file extension if it exists)
    $et->SetFileType(undef, undef, $$et{FILE_EXT});
    $ver == 2 or $et->Warn("Unsupported file version $ver"), return 1;
    SetByteOrder('MM');
    my $tagTablePtr = GetTagTable('Image::ExifTool::MacOS::Main');
    my $entries = Get16u(\$hdr, 0x18);
    $et->VerboseDir('MacOS', $entries);
    $raf->Read($hdr, $entries * 12) == $entries * 12 or $et->Warn('Truncated header'), return 1;
    for ($i=0; $i<$entries; ++$i) {
        my $pos = $i * 12;
        my $tag = Get32u(\$hdr, $pos);
        my $off = Get32u(\$hdr, $pos + 4);
        my $len = Get32u(\$hdr, $pos + 8);
        $len > 100000000 and $et->Warn('Record size too large'), last;
        $raf->Seek($off,0) and $raf->Read($buff,$len) == $len or $et->Warn('Truncated record'), last;
        $et->HandleTag($tagTablePtr, $tag, undef, DataPt => \$buff, DataPos => $off, Index => $i);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::MacOS - Read/write MacOS system tags

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to extract
MDItem* and XAttr* tags on MacOS systems using the "mdls" and "xattr"
utilities respectively.  It also reads metadata directly from the MacOS "_."
sidecar files that are used on some filesystems to store file attributes.
Writable tags use "xattr", "setfile" or "osascript" for writing.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/MacOS Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

