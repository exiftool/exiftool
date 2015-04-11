#------------------------------------------------------------------------------
# File:         VCard.pm
#
# Description:  vCard meta information
#
# Revisions:    2015/04/05 - P. Harvey Created
#
# References:   1) http://en.m.wikipedia.org/wiki/VCard
#               2) http://tools.ietf.org/html/rfc6350
#------------------------------------------------------------------------------

package Image::ExifTool::VCard;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.00';

my %unescapeVCard = ( '\\'=>'\\', ','=>',', 'n'=>"\n", 'N'=>"\n" );

# VCard tags (ref 1)
%Image::ExifTool::VCard::Main = (
    GROUPS => { 2 => 'Document' },
    NOTES => q{
        This table lists only those VCard tags which are renamed by ExifTool, but
        any existing VCard tag will be extracted.  Tag names may have "Pref" added
        to indicate the preferred instance of a VCard property.  Other "TYPE"
        parameters are also added to the tag name. See
        L<https://tools.ietf.org/html/rfc6350> for the VCard 4.0 specification.
    },
    Version => 'VCardVersion',
    VCardVersion => { Description => 'VCard Version', Hidden => 1 }, # (for the Description)
    Prodid => 'Software',
    Fn   => { Name => 'FormattedName',  Groups => { 2 => 'Author' } },
    N    => { Name => 'Name',           Groups => { 2 => 'Author' } },
    Bday => { Name => 'Birthday',       Groups => { 2 => 'Time' } },
    Tz   => { Name => 'TimeZone',       Groups => { 2 => 'Time' } },
    Adr  => { Name => 'Address',        Groups => { 2 => 'Location' } },
    Geo  => { Name => 'Geolocation',    Groups => { 2 => 'Location' } },
    Rev  => 'Revision',
    Org  => 'Organization',
    Tel  => 'Telephone',
    Uid  => 'UID',
);

#------------------------------------------------------------------------------
# Get VCard tag, creating if necessary
# Inputs: 0) tag table ref, 1) tag ID, 2) source tagInfo ref, 3) language code
# Returns: tagInfo ref
sub GetVCardTag($$;$$)
{
    my ($tagTablePtr, $tag, $srcInfo, $langCode) = @_;
    my $tagInfo = $$tagTablePtr{$tag};
    unless ($tagInfo) {
        $tagInfo = $srcInfo ? { %$srcInfo } : { };
        $$tagInfo{Name} = $tag;
        delete $$tagInfo{Description};  # create new description
        AddTagToTable($tagTablePtr, $tag, $tagInfo);
    }
    # handle alternate languages (the "language" parameter)
    $tagInfo = Image::ExifTool::GetLangInfo($tagInfo, $langCode) if $langCode;
    return $tagInfo;
}

#------------------------------------------------------------------------------
# Decode VCard text
# Inputs: 0) ExifTool ref, 1) VCard text, 2) encoding
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
# Read information in a VCard file
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid VCard file
sub ProcessVCard($$)
{
    local $_;
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $val, $ok);

    return 0 unless $raf->Read($buff, 16) and $raf->Seek(0,0) and $buff=~/^BEGIN:VCARD\r\n/i;
    $et->SetFileType();
    local $/ = "\r\n";
    my $tagTablePtr = GetTagTable('Image::ExifTool::VCard::Main');
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
        if ($val =~ /^(BEGIN|END):VCARD$/i) {
            $ok = 1 if uc($1) eq 'END'; # (OK if this is the last line)
            next;
        } elsif ($ok) {
            $ok = 0;
            $$et{DOC_NUM} = ++$$et{DOC_COUNT};  # read next card as a new document
        }
        unless ($val =~ s/^([-A-Za-z0-9.]+)//) {
            $et->WarnOnce('Unrecognized line in VCard file');
            next;
        }
        my $tag = $1;
        # set group if it exists
        if ($tag =~ s/^([-A-Za-z0-9]+)\.//) {
            $$et{SET_GROUP1} = ucfirst lc $1; 
        } else {
            delete $$et{SET_GROUP1};
        }
        # avoid ugly all-caps tag names
        $tag = ucfirst($tag =~ /[a-z]/ ? $tag : lc $tag);
        my (%param, $p, @val);
        while ($val =~ s/^;([-A-Za-z0-9]*)(=?)//) {
            $p = lc $1;
            # convert old VCard 2.x parameters to the new "TYPE=" format
            $2 or $val = $1 . $val, $p = 'type';
            for (;;) {
                last unless $val =~ s/^"([^"]*)",?// or $val =~ s/^([^";:,]+,?)//;
                my $v = $p eq 'type' ? ucfirst lc $1 : $1;
                $param{$p} = defined($param{$p}) ? $param{$p} . $v : $v;
            }
            if (defined $param{$p}) {
                $param{$p} =~ s/\\(.)/$unescapeVCard{$1}||$1/sge;
            } else {
                $param{$p} = '';
            }
        }
        $val =~ s/^:// or $et->WarnOnce('Invalid line in VCard file'), next;
        # get source tagInfo reference
        my $srcInfo = $et->GetTagInfo($tagTablePtr, $tag);
        $tag = $$srcInfo{Name} if $srcInfo;     # translate name if necessary
        $tag .= $param{type} if $param{type};   # add 'type' parameter to name
        # convert base64-encoded data
        if ($val =~ s{^data:(\w+)/(\w+);base64,}{}) {
            $tag .= ucfirst(lc $1) . ucfirst(lc $2);
            $param{encoding} = 'base64';
        }
        $val = DecodeVCardText($et, $val, $param{encoding});
        my $tagInfo = GetVCardTag($tagTablePtr, $tag, $srcInfo, $param{language});
        $et->HandleTag($tagTablePtr, $tag, $val, TagInfo => $tagInfo);
        foreach $p (qw(geo label)) {
            next unless defined $param{$p};
            my $t = $tag . ucfirst($p);
            # set group 2 to "Location" for "geo" parameters
            my $srcTag2;
            if ($p eq 'geo') {
                $srcTag2 = { Groups => { 2 => 'Location' } };
                $param{$p} =~ s/^geo://;    # remove "geo:" prefix of VCard 4.0
            }
            $val = DecodeVCardText($et, $param{$p});
            $tagInfo = GetVCardTag($tagTablePtr, $t, $srcTag2, $param{language});
            $et->HandleTag($tagTablePtr, $t, $val, TagInfo => $tagInfo);
        }
    }
    delete $$et{SET_GROUP1};
    delete $$et{DOC_NUM};
    $ok or $et->Warn('Missing VCard end');
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::VCard - Read vCard meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read meta
information from VCard files.

=head1 AUTHOR

Copyright 2003-2015, Phil Harvey (phil at owl.phy.queensu.ca)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://en.m.wikipedia.org/wiki/VCard>

=item L<http://tools.ietf.org/html/rfc6350>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/VCard Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

