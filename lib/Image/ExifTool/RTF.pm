#------------------------------------------------------------------------------
# File:         RTF.pm
#
# Description:  Read Rich Text Format meta information
#
# Revisions:    2010/06/17 - P. Harvey Created
#
# References:   1) http://download.microsoft.com/download/2/f/5/2f599e18-07ee-4ec5-a1e7-f4e6a9423592/Word2007RTFSpec9.doc
#               2) http://search.cpan.org/dist/RTF-Writer/lib/RTF/Cookbook.pod
#------------------------------------------------------------------------------

package Image::ExifTool::RTF;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.04';

sub ProcessUserProps($$$);

# supported RTF character entities
my %rtfEntity = (
    par       => 0x0a,
    tab       => 0x09,
    endash    => 0x2013,
    emdash    => 0x2014,
    lquote    => 0x2018,
    rquote    => 0x2019,
    ldblquote => 0x201c,
    rdblquote => 0x201d,
    bullet    => 0x2022,
);

# RTF tags (ref 1)
%Image::ExifTool::RTF::Main = (
    GROUPS => { 2 => 'Document' },
    NOTES => q{
        This table lists standard tags of the RTF information group, but ExifTool
        will also extract any non-standard tags found in this group.  As well,
        ExifTool will extract any custom properties that are found.  See
        L<http://www.microsoft.com/en-ca/download/details.aspx?id=10725> for the
        specification.
    },
    title    => { },
    subject  => { },
    author   => { Groups => { 2 => 'Author' } },
    manager  => { },
    company  => { },
    copyright=> { Groups => { 2 => 'Author' } }, # (written by Apple TextEdit)
    operator => { Name => 'LastModifiedBy' },
    category => { },
    keywords => { },
    comment  => { },
    doccomm  => { Name => 'Comments' },
    hlinkbase=> { Name => 'HyperlinkBase' },
    creatim  => {
        Name => 'CreateDate',
        Format => 'date',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    revtim   => {
        Name => 'ModifyDate',
        Format => 'date',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    printim  => {
        Name => 'LastPrinted',
        Format => 'date',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    buptim   => {
        Name => 'BackupTime',
        Format => 'date',
        Groups => { 2 => 'Time' },
        PrintConv => '$self->ConvertDateTime($val)',
    },
    edmins   => {
        Name => 'TotalEditTime', # in minutes
        PrintConv => 'ConvertTimeSpan($val, 60)',
    },
    nofpages => { Name => 'Pages' },
    nofwords => { Name => 'Words' },
    nofchars => { Name => 'Characters' },
    nofcharsws=>{
        Name => 'CharactersWithSpaces',
        Notes => q{
            according to the 2007 Microsoft RTF specification this is clearly the number
            of characters NOT including spaces, but Microsoft Word writes this as the
            number WITH spaces, so ExifTool names this tag according to the de facto
            standard
        },
    },
    id       => { Name => 'InternalIDNumber' },
    version  => { Name => 'RevisionNumber' },
    vern     => { Name => 'InternalVersionNumber' },
);

# lookup for user-defined properties
# (none are pre-defined and this table doesn't appear in the docs)
%Image::ExifTool::RTF::UserProps = (
    GROUPS => { 2 => 'Document' },
);

#------------------------------------------------------------------------------
# Read to nested closing curly bracket "}"
# Inputs: 0) data ref, 1) optional RAF ref to read more data if available
# Returns: text inside brackets, or undef on error
# Notes: On entry the current position in the data must be set to immediately
#        after the command that opens the bracket.  On return the current
#        position is immediately following the closing brace if the return
#        value is defined.
sub ReadToNested($;$)
{
    my ($dataPt, $raf) = @_;
    my $pos = pos $$dataPt;
    my $level = 1;
    for (;;) {
        # look for the next bracket
        unless ($$dataPt =~ /(\\*)([{}])/g) {
            # must read some more data
            my $p = length $$dataPt;
            my $buff;
            last unless $raf and $raf->Read($buff, 65536);
            $$dataPt .= $buff;
            # rewind position to include any leading backslashes
            --$p while $p and substr($$dataPt, $p - 1, 1) eq '\\';
            pos($$dataPt) = $p; # set position to continue search
            next;
        }
        # bracket is escaped if preceded by an odd number of backslashes
        next if $1 and length($1) & 0x01;
        $2 eq '{' and ++$level, next;
        next unless --$level <= 0;
        return substr($$dataPt, $pos, pos($$dataPt) - $pos - 1);
    }
    return undef;
}

#------------------------------------------------------------------------------
# Unescape RTF escape sequences
# Inputs: 0) ExifTool ref, 1) RTF text, 2) RTF character set (for hex characters)
# Returns: Unescaped text (in current ExifTool Charset)
sub UnescapeRTF($$$)
{
    my ($et, $val, $charset) = @_;

    # return now unless we have a control sequence
    unless ($val =~ /\\/) {
        $val =~ tr/\n\r//d; # ignore CR's and LF's
        return $val;
    }
    # CR/LF is significant if it terminates a control sequence (so change these to a space)
    # (was $val =~ s/(^|[^\\])((?:\\\\)*)(\\[a-zA-Z]+(?:-?\d+)?)[\n\r]/$1$2$3 /g;)
    $val =~ s/\\(?:([a-zA-Z]+(?:-?\d+)?)[\n\r]|(.))/'\\'.($1 ? "$1 " : $2)/sge;
    # protect the newline control sequence by converting to a \par command
    # (was $val =~ s/(^|[^\\])((?:\\\\)*)(\\[\n\r])/$1$2\\par /g;)
    $val =~ s/(\\[\n\r])|(\\.)/$2 || '\\par '/sge;
    # all other CR/LF's are ignored (so delete them)
    $val =~ tr/\n\r//d;

    my $rtnVal = '';
    my $len = length $val;
    my $skip = 1;   # default Unicode skip count
    my $p0 = 0;

    for (;;) {
        # find next backslash
        my $p1 = ($val =~ /\\/g) ? pos($val) : $len + 1;
        # add text up to start of this control sequence (or up to end)
        my $n = $p1 - $p0 - 1;
        $rtnVal .= substr($val, $p0, $n) if $n > 0;
        # all done if at the end or if control sequence is empty
        last if $p1 >= $len;
        # look for an ASCII-letter control word or Unicode control
        if ($val =~ /\G([a-zA-Z]+)(-?\d+)? ?/g) {
            # interpret command if recognized
            if ($1 eq 'uc') {       # \ucN
                $skip = $2;
            } elsif ($1 eq 'u') {   # \uN
                if ($2 < 0) {
                    $et->Warn('Invalid Unicode character(s) in text');
                    $rtnVal .= '?';
                } else {
                    require Image::ExifTool::Charset;
                    $rtnVal .= Image::ExifTool::Charset::Recompose($et, [$2]);
                    if ($skip) {
                        # must skip the specified number of characters
                        # (not simple because RTF control words count as a single character)
                        last unless $val =~ /\G([^\\]|\\([a-zA-Z]+)(-?\d+)? ?|\\'.{2}|\\.){$skip}/g;
                    }
                }
            } elsif ($rtfEntity{$1}) {
                require Image::ExifTool::Charset;
                $rtnVal .= Image::ExifTool::Charset::Recompose($et, [$rtfEntity{$1}]);
            } # (else ignore the command)
        } else {
            my $ch = substr($val, $p1, 1);
            if ($ch eq "'") {
                # hex character code
                last if $p1 + 3 > $len;
                my $hex = substr($val, $p1 + 1, 2);
                if ($hex =~ /^[0-9a-fA-F]{2}$/) {
                    require Image::ExifTool::Charset;
                    $rtnVal .= $et->Decode(chr(hex($hex)), $charset);
                }
                pos($val) = $p1 + 3;    # skip to after the hex code
            } else {
                # assume a standard control symbol (\, {, }, etc)
                # (note, this may not be valid for some uncommon
                #  control symbols like \~ for non-breaking space)
                $rtnVal .= $ch;
                pos($val) = $p1 + 1;    # skip to after this character
            }
        }
        $p0 = pos($val);
    }
    return $rtnVal;
}

#------------------------------------------------------------------------------
# Read information in a RTF document
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid RTF file
sub ProcessRTF($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $buf2, $cs);

    return 0 unless $raf->Read($buff, 64) and $raf->Seek(0,0);
    return 0 unless $buff =~ /^[\n\r]*\{[\n\r]*\\rtf[^a-zA-Z]/;
    $et->SetFileType();
#
# determine the RTF character set
#
    if ($buff=~ /\\ansicpg(\d*)/) {
        $cs = "cp$1";
    } elsif ($buff=~ /\\(ansi|mac|pc|pca)[^a-zA-Z]/) {
        my %trans = (
            ansi => 'Latin',
            mac  => 'MacRoman',
            pc   => 'cp437',
            pca  => 'cp850',
        );
        $cs = $trans{$1};
    } else {
        $et->Warn('Unspecified RTF encoding. Will assume Latin');
        $cs = 'Latin';
    }
    my $charset = $Image::ExifTool::charsetName{lc $cs};
    unless ($charset) {
        $et->Warn("Unsupported RTF encoding $cs. Will assume Latin.");
        $charset = 'Latin';
    }
    my $tagTablePtr = GetTagTable('Image::ExifTool::RTF::Main');
    undef $buff;
#
# scan for \info group
#
    for (;;) {
        $raf->Read($buf2, 65536) or last;
        if (defined $buff) {
            # read more but leave some overlap for the match
            $buff = substr($buff, -16) . $buf2;
        } else {
            $buff = $buf2;
        }
        next unless $buff =~ /[^\\]\{[\n\r]*\\info([^a-zA-Z])/g;
        # anything but a space is included in the contents
        pos($buff) = pos($buff) - 1 if $1 ne ' ';
        my $info = ReadToNested(\$buff, $raf);
        unless (defined $info) {
            $et->Warn('Unterminated information group');
            last;
        }
        # process info commands (eg. "\author", "\*\copyright");
        while ($info =~ /\{[\n\r]*(\\\*[\n\r]*)?\\([a-zA-Z]+)([^a-zA-Z])/g) {
            pos($info) = pos($info) - 1 if $3 ne ' ';
            my $tag = $2;
            my $val = ReadToNested(\$info);
            last unless defined $val;
            my $tagInfo = $$tagTablePtr{$tag};
            if ($tagInfo and $$tagInfo{Format} and $$tagInfo{Format} eq 'date') {
                # parse RTF date commands
                my %idx = (yr=>0,mo=>1,dy=>2,hr=>3,min=>4,sec=>5);
                my @t = (0) x 6;
                while ($val =~ /\\([a-z]+)(\d+)/g) {
                    next unless defined $idx{$1};
                    $t[$idx{$1}] = $2;
                }
                $val = sprintf("%.4d:%.2d:%.2d %.2d:%.2d:%.2d", @t);
            } else {
                # unescape RTF string value
                $val = UnescapeRTF($et, $val, $charset);
            }
            # create tagInfo for unknown tags
            if (not $tagInfo) {
                AddTagToTable($tagTablePtr, $tag, { Name => ucfirst($tag) });
            }
            $et->HandleTag($tagTablePtr, $tag, $val);
        }
    }
    return 1 unless defined $buff;
#
# scan for \userprops (but don't read more from file to find the start of this command)
#
    pos($buff) = 0;
    while ($buff =~ /[^\\]\{[\n\r]*\\\*[\n\r]*\\userprops([^a-zA-Z])/g) {
        # Note: The RTF spec places brackets around each propinfo structure,
        # but Microsoft Word doesn't write it this way, so tolerate either.
        pos($buff) = pos($buff) - 1 if $1 ne ' ';
        my $props = ReadToNested(\$buff, $raf);
        $tagTablePtr = Image::ExifTool::GetTagTable('Image::ExifTool::RTF::UserProps');
        unless (defined $props) {
            $et->Warn('Unterminated user properties');
            last;
        }
        # process user properties
        my $tag;
        while ($props =~ /\{[\n\r]*(\\\*[\n\r]*)?\\([a-zA-Z]+)([^a-zA-Z])/g) {
            pos($props) = pos($props) - 1 if $3 ne ' ';
            my $t = $2;
            my $val = ReadToNested(\$props);
            last unless defined $val;
            $val = UnescapeRTF($et, $val, $charset);
            if ($t eq 'propname') {
                $tag = $val;
                next;
            } elsif ($t ne 'staticval' or not defined $tag) {
                next;   # ignore \linkval and \proptype for now
            }
            $tag =~ s/\s(.)/\U$1/g;     # capitalize all words in tag name
            $tag =~ tr/-_a-zA-Z0-9//dc; # remove illegal characters
            next unless $tag;
            # create tagInfo for unknown tags
            unless ($$tagTablePtr{$tag}) {
                AddTagToTable($tagTablePtr, $tag, { Name => $tag });
            }
            $et->HandleTag($tagTablePtr, $tag, $val);
        }
        last;   # (didn't really want to loop)
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::RTF - Read Rich Text Format meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read meta
information from RTF (Rich Text Format) documents.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://download.microsoft.com/download/2/f/5/2f599e18-07ee-4ec5-a1e7-f4e6a9423592/Word2007RTFSpec9.doc>

=item L<http://search.cpan.org/dist/RTF-Writer/lib/RTF/Cookbook.pod>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/RTF Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

