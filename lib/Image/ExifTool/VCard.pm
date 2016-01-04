#------------------------------------------------------------------------------
# File:         VCard.pm
#
# Description:  Read vCard and iCalendar meta information
#
# Revisions:    2015/04/05 - P. Harvey Created
#               2015/05/02 - PH Added iCalendar support
#
# References:   1) http://en.m.wikipedia.org/wiki/VCard
#               2) http://tools.ietf.org/html/rfc6350
#               3) http://tools.ietf.org/html/rfc5545
#------------------------------------------------------------------------------

package Image::ExifTool::VCard;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.04';

my %unescapeVCard = ( '\\'=>'\\', ','=>',', 'n'=>"\n", 'N'=>"\n" );

# lookup for iCalendar components (used to generate family 1 group names if top level)
my %isComponent = ( Event=>1, Todo=>1, Journal=>1, Freebusy=>1, Timezone=>1, Alarm=>1 );

my %timeInfo = (
    # convert common date/time formats to EXIF style
    ValueConv => q{
        $val =~ s/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)/$1:$2:$3 $4:$5:$6$7/g;
        $val =~ s/(\d{4})(\d{2})(\d{2})/$1:$2:$3/g;
        $val =~ s/(\d{4})-(\d{2})-(\d{2})/$1:$2:$3/g;
        return $val;
    },
    PrintConv => '$self->ConvertDateTime($val)',
);

# vCard tags (ref 1/2/PH)
# Note: The case of all tag ID's is normalized to lowercase with uppercase first letter
%Image::ExifTool::VCard::Main = (
    GROUPS => { 2 => 'Document' },
    VARS => { NO_LOOKUP => 1 }, # omit tags from lookup
    NOTES => q{
        This table lists common vCard tags, but ExifTool will also extract any other
        vCard tags found.  Tag names may have "Pref" added to indicate the preferred
        instance of a vCard property, and other "TYPE" parameters may also added to
        the tag name.  VCF files may contain multiple vCard entries which are
        distinguished by the ExifTool family 3 group name (document  number). See
        L<http://tools.ietf.org/html/rfc6350> for the vCard 4.0 specification.
    },
    Version     => { Name => 'VCardVersion',   Description => 'VCard Version' },
    Fn          => { Name => 'FormattedName',  Groups => { 2 => 'Author' } },
    N           => { Name => 'Name',           Groups => { 2 => 'Author' } },
    Bday        => { Name => 'Birthday',       Groups => { 2 => 'Time' }, %timeInfo },
    Tz          => { Name => 'TimeZone',       Groups => { 2 => 'Time' } },
    Adr         => { Name => 'Address',        Groups => { 2 => 'Location' } },
    Geo => {
        Name => 'Geolocation',
        Groups => { 2 => 'Location' },
        # when used as a parameter, VCard 4.0 adds a "geo:" prefix that we need to remove
        ValueConv => '$val =~ s/^geo://; $val',
    },
    Anniversary => { },
    Email       => { },
    Gender      => { },
    Impp        => 'IMPP',
    Lang        => 'Language',
    Logo        => { },
    Nickname    => { },
    Note        => { },
    Org         => 'Organization',
    Photo       => { Groups => { 2 => 'Preview' } },
    Prodid      => 'Software',
    Rev         => 'Revision',
    Sound       => { },
    Tel         => 'Telephone',
    Title       => 'JobTitle',
    Uid         => 'UID',
    Url         => 'URL',
    'X-ablabel' => { Name => 'ABLabel', PrintConv => '$val =~ s/^_\$!<(.*)>!\$_$/$1/; $val' },
    'X-abdate'  => { Name => 'ABDate',  Groups => { 2 => 'Time' }, %timeInfo },
    'X-aim'     => 'AIM',
    'X-icq'     => 'ICQ',
    'X-abuid'   => 'AB_UID',
    'X-abrelatednames' => 'ABRelatedNames',
    'X-socialprofile'  => 'SocialProfile',
);

%Image::ExifTool::VCard::VCalendar = (
    GROUPS => { 1 => 'VCalendar', 2 => 'Document' },
    VARS => { NO_LOOKUP => 1 }, # omit tags from lookup
    NOTES => q{
        The VCard module is also used to process iCalendar ICS files since they use
        a format similar to vCard.  The following table lists standard iCalendar
        tags, but any existing tags will be extracted.  Top-level iCalendar
        components (eg. Event, Todo, Timezone, etc.) are used for the family 1 group
        names, and embedded components (eg. Alarm) are added as a prefix to the tag
        name.  See L<http://tools.ietf.org/html/rfc5545> for the official iCalendar
        2.0 specification.
    },
    Version     => { Name => 'VCalendarVersion',   Description => 'VCalendar Version' },
    Calscale    => 'CalendarScale',
    Method      => { },
    Prodid      => 'Software',
    Attach      => 'Attachment',
    Categories  => { },
    Class       => 'Classification',
    Comment     => { },
    Description => { },
    Geo => {
        Name => 'Geolocation',
        Groups => { 2 => 'Location' },
        ValueConv => '$val =~ s/^geo://; $val',
    },
    Location    => { Name => 'Location',            Groups => { 2 => 'Location' } },
    'Percent-complete' => 'PercentComplete',
    Priority    => { },
    Resources   => { },
    Status      => { },
    Summary     => { },
    Completed   => { Name => 'DateTimeCompleted',   Groups => { 2 => 'Time' }, %timeInfo },
    Dtend       => { Name => 'DateTimeEnd',         Groups => { 2 => 'Time' }, %timeInfo },
    Due         => { Name => 'DateTimeDue',         Groups => { 2 => 'Time' }, %timeInfo },
    Dtstart     => { Name => 'DateTimeStart',       Groups => { 2 => 'Time' }, %timeInfo },
    Duration    => { },
    Freebusy    => 'FreeBusyTime',
    Transp      => 'TimeTransparency',
    Tzid        => { Name => 'TimezoneID',          Groups => { 2 => 'Time' } },
    Tzname      => { Name => 'TimezoneName',        Groups => { 2 => 'Time' } },
    Tzoffsetfrom=> { Name => 'TimezoneOffsetFrom',  Groups => { 2 => 'Time' } },
    Tzoffsetto  => { Name => 'TimezoneOffsetTo',    Groups => { 2 => 'Time' } },
    Tzurl       => { Name => 'TimeZoneURL',         Groups => { 2 => 'Time' } },
    Attendee    => { },
    Contact     => { },
    Organizer   => { },
    'Recurrence-id' => 'RecurrenceID',
    'Related-to'    => 'RelatedTo',
    Url         => 'URL',
    Uid         => 'UID',
    Exdate      => { Name => 'ExceptionDateTimes',  Groups => { 2 => 'Time' }, %timeInfo },
    Rdate       => { Name => 'RecurrenceDateTimes', Groups => { 2 => 'Time' }, %timeInfo },
    Rrule       => { Name => 'RecurrenceRule',      Groups => { 2 => 'Time' } },
    Action      => { },
    Repeat      => { },
    Trigger     => { },
    Created     => { Name => 'DateCreated',         Groups => { 2 => 'Time' }, %timeInfo },
    Dtstamp     => { Name => 'DateTimeStamp',       Groups => { 2 => 'Time' }, %timeInfo },
    'Last-modified' => { Name => 'ModifyDate',      Groups => { 2 => 'Time' }, %timeInfo },
    Sequence    => 'SequenceNumber',
    'Request-status' => 'RequestStatus',
    Acknowledged=> { Name => 'Acknowledged',        Groups => { 2 => 'Time' }, %timeInfo },
);

#------------------------------------------------------------------------------
# Get vCard tag, creating if necessary
# Inputs: 0) ExifTool ref, 1) tag table ref, 2) tag ID, 3) tag Name,
#         4) source tagInfo ref, 5) lang code
# Returns: tagInfo ref
sub GetVCardTag($$$$;$$)
{
    my ($et, $tagTablePtr, $tag, $name, $srcInfo, $langCode) = @_;
    my $tagInfo = $$tagTablePtr{$tag};
    unless ($tagInfo) {
        if ($srcInfo) {
            $tagInfo = { %$srcInfo };
        } else {
            $tagInfo = { };
            $et->VPrint(0, $$et{INDENT}, "[adding $tag]\n");
        }
        $$tagInfo{Name} = $name;
        delete $$tagInfo{Description};  # create new description
        AddTagToTable($tagTablePtr, $tag, $tagInfo);
    }
    # handle alternate languages (the "language" parameter)
    $tagInfo = Image::ExifTool::GetLangInfo($tagInfo, $langCode) if $langCode;
    return $tagInfo;
}

#------------------------------------------------------------------------------
# Decode vCard text
# Inputs: 0) ExifTool ref, 1) vCard text, 2) encoding
# Returns: decoded text (or array ref for a list of values)
sub DecodeVCardText($$;$)
{
    my ($et, $val, $enc) = @_;
    $enc = defined($enc) ? lc $enc : '';
    if ($enc eq 'b' or $enc eq 'base64') {
        require Image::ExifTool::XMP;
        $val = Image::ExifTool::XMP::DecodeBase64($val);
    } else {
        if ($enc eq 'quoted-printable') {
            # convert "=HH" hex codes to characters
            $val =~ s/=([0-9a-f]{2})/chr(hex($1))/ige;
        }
        $val = $et->Decode($val, 'UTF8');   # convert from UTF-8
        # split into separate items if it contains an unescaped comma
        my $list = $val =~ s/(^|[^\\])((\\\\)*),/$1$2\0/g;
        # unescape necessary characters in value
        $val =~ s/\\(.)/$unescapeVCard{$1}||$1/sge;
        if ($list) {
            my @vals = split /\0/, $val;
            $val = \@vals;
        }
    }
    return $val;
}

#------------------------------------------------------------------------------
# Read information in a vCard file
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid vCard file
sub ProcessVCard($$)
{
    local $_;
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $val, $ok, $component, %compNum, @count);

    return 0 unless $raf->Read($buff, 24) and $raf->Seek(0,0) and $buff=~/^BEGIN:(VCARD|VCALENDAR)\r\n/i;
    my ($type, $lbl, $tbl, $ext) = uc($1) eq 'VCARD' ? qw(VCard vCard Main VCF) : qw(ICS iCalendar VCalendar ICS);
    $et->SetFileType($type, undef, $ext);
    return 1 if $$et{OPTIONS}{FastScan} and $$et{OPTIONS}{FastScan} == 3;
    local $/ = "\r\n";
    my $tagTablePtr = GetTagTable("Image::ExifTool::VCard::$tbl");
    my $more = $raf->ReadLine($buff);   # read first line
    chomp $buff if $more;
    while ($more) {
        # retrieve previous line from $buff
        $val = $buff if defined $buff;
        # read ahead to next line to see if is a continuation
        $more = $raf->ReadLine($buff);
        if ($more) {
            chomp $buff;
            # add continuation line if necessary
            $buff =~ s/^[ \t]// and $val .= $buff, undef($buff), next;
        }
        if ($val =~ /^(BEGIN|END):(V?)(\w+)$/i) {
            my ($begin, $v, $what) = ((lc($1) eq 'begin' ? 1 : 0), $2, ucfirst lc $3);
            if ($what eq 'Card' or $what eq 'Calendar') {
                if ($begin) {
                    @count = ( { } );   # reset group counters
                } else {
                    $ok = 1;    # ok if we read at least on full VCARD or VCALENDAR
                }
                next;
            }
            # absorb top-level component into family 1 group name
            if ($isComponent{$what}) {
                if ($begin) {
                    unless ($component) {
                        # begin a new top-level component
                        @count = ( { } );
                        $component = $what;
                        $compNum{$component} = ($compNum{$component} || 0) + 1;
                        next;
                    }
                } elsif ($component and $component eq $what) {
                    # this top-level component has ended
                    undef $component;
                    next;
                }
            }
            # keep count of each component at this level
            if ($begin) {
                $count[-1]{$what} = ($count[-1]{$what} || 0) + 1 if $v;
                push @count, { obj => $what };
            } elsif (@count > 1) {
                pop @count;
            }
            next;
        } elsif ($ok) {
            $ok = 0;
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};  # read next card as a new document
        }
        unless ($val =~ s/^([-A-Za-z0-9.]+)//) {
            $et->WarnOnce("Unrecognized line in $lbl file");
            next;
        }
        my $tag = $1;
        # set group if it exists
        if ($tag =~ s/^([-A-Za-z0-9]+)\.//) {
            $$et{SET_GROUP1} = ucfirst lc $1;
        } elsif ($component) {
            $$et{SET_GROUP1} = $component . $compNum{$component};
        } else {
            delete $$et{SET_GROUP1};
        }
        my ($name, %param, $p, @val);
        # vCard tag ID's are case-insensitive, so normalize to lowercase with
        # an uppercase first letter for use as a tag name
        $name = ucfirst $tag if $tag =~ /[a-z]/;    # preserve mixed case in name if it exists
        $tag = ucfirst lc $tag;
        # get source tagInfo reference
        my $srcInfo = $et->GetTagInfo($tagTablePtr, $tag);
        if ($srcInfo) {
            $name = $$srcInfo{Name};    # use our name
        } else {
            $name or $name = $tag;
            # remove leading "X-" from name if it exists
            $name =~ s/^X-// and $name = ucfirst $name;
        }
        # add object name(s) to tag if necessary
        if (@count > 1) {
            my $i;
            for ($i=$#count-1; $i>=0; --$i) {
                my $pre = $count[$i-1]{obj};    # use containing object name as tag prefix
                my $c = $count[$i]{$pre};       # add index for object number
                $c = '' unless defined $c;
                $tag = $pre . $c . $tag;
                $name = $pre . $c . $name;
            }
        }
        # parse parameters
        while ($val =~ s/^;([-A-Za-z0-9]*)(=?)//) {
            $p = ucfirst lc $1;
            # convert old vCard 2.x parameters to the new "TYPE=" format
            $2 or $val = $1 . $val, $p = 'Type';
            # read parameter value
            for (;;) {
                last unless $val =~ s/^"([^"]*)",?// or $val =~ s/^([^";:,]+,?)//;
                my $v = $p eq 'Type' ? ucfirst lc $1 : $1;
                $param{$p} = defined($param{$p}) ? $param{$p} . $v : $v;
            }
            if (defined $param{$p}) {
                $param{$p} =~ s/\\(.)/$unescapeVCard{$1}||$1/sge;
            } else {
                $param{$p} = '';
            }
        }
        $val =~ s/^:// or $et->WarnOnce("Invalid line in $lbl file"), next;
        # add 'Type' parameter to id and name if it exists
        $param{Type} and $tag .= $param{Type}, $name .= $param{Type};
        # convert base64-encoded data
        if ($val =~ s{^data:(\w+)/(\w+);base64,}{}) {
            my $xtra = ucfirst(lc $1) . ucfirst(lc $2);
            $tag .= $xtra;
            $name .= $xtra;
            $param{Encoding} = 'base64';
        }
        $val = DecodeVCardText($et, $val, $param{Encoding});
        my $tagInfo = GetVCardTag($et, $tagTablePtr, $tag, $name, $srcInfo, $param{Language});
        $et->HandleTag($tagTablePtr, $tag, $val, TagInfo => $tagInfo);
        # handle some other parameters that we care about (ignore the rest for now)
        foreach $p (qw(Geo Label Tzid)) {
            next unless defined $param{$p};
            # use tag attributes from our table if it exists
            my $srcTag2 = $et->GetTagInfo($tagTablePtr, $p);
            my $pn = $srcTag2 ? $$srcTag2{Name} : $p;
            $val = DecodeVCardText($et, $param{$p});
            # add parameter to tag ID and name
            my ($tg, $nm) = ($tag . $p, $name . $pn);
            $tagInfo = GetVCardTag($et, $tagTablePtr, $tg, $nm, $srcTag2, $param{Language});
            $et->HandleTag($tagTablePtr, $tg, $val, TagInfo => $tagInfo);
        }
    }
    delete $$et{SET_GROUP1};
    delete $$et{DOC_NUM};
    $ok or $et->Warn("Missing $lbl end");
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::VCard - Read vCard and iCalendar meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read meta
information from vCard VCF and iCalendar ICS files.

=head1 AUTHOR

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://en.m.wikipedia.org/wiki/VCard>

=item L<http://tools.ietf.org/html/rfc6350>

=item L<http://tools.ietf.org/html/rfc5545>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/VCard Tags>,
L<Image::ExifTool::TagNames/VCard VCalendar Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

