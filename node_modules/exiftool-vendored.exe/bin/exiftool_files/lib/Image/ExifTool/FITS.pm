#------------------------------------------------------------------------------
# File:         FITS.pm
#
# Description:  Read Flexible Image Transport System metadata
#
# Revisions:    2018/03/07 - P. Harvey Created
#
# References:   1) https://fits.gsfc.nasa.gov/fits_standard.html
#------------------------------------------------------------------------------

package Image::ExifTool::FITS;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.02';

# FITS tags (ref 1)
%Image::ExifTool::FITS::Main = (
    GROUPS => { 2 => 'Image' },
    NOTES => q{
        This table lists some standard Flexible Image Transport System (FITS) tags,
        but ExifTool will extract any other tags found.  See
        L<https://fits.gsfc.nasa.gov/fits_standard.html> for the specification.
    },
    TELESCOP => 'Telescope',
    BACKGRND => 'Background',
    INSTRUME => 'Instrument',
    OBJECT   => 'Object',
    OBSERVER => 'Observer',
    DATE     => { Name => 'CreateDate', Groups => { 2 => 'Time' } },
    AUTHOR   => { Name => 'Author',     Groups => { 2 => 'Author' } },
    REFERENC => 'Reference',
   'DATE-OBS'=> { Name => 'ObservationDate',    Groups => { 2 => 'Time' } },
   'TIME-OBS'=> { Name => 'ObservationTime',    Groups => { 2 => 'Time' } },
   'DATE-END'=> { Name => 'ObservationDateEnd', Groups => { 2 => 'Time' } },
   'TIME-END'=> { Name => 'ObservationTimeEnd', Groups => { 2 => 'Time' } },
    COMMENT  => { Name => 'Comment', PrintConv => '$val =~ s/^ +//; $val',
                  Notes => 'leading spaces are removed if L<PrintConv|../ExifTool.html#PrintConv> is enabled' },
    HISTORY  => { Name => 'History', PrintConv => '$val =~ s/^ +//; $val',
                  Notes => 'leading spaces are removed if L<PrintConv|../ExifTool.html#PrintConv> is enabled' },
);

#------------------------------------------------------------------------------
# Read information in a FITS document
# Inputs: 0) ExifTool ref, 1) dirInfo ref
# Returns: 1 on success, 0 if this wasn't a valid FITS file
sub ProcessFITS($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $tag, $continue);

    return 0 unless $raf->Read($buff, 80) == 80 and $buff =~ /^SIMPLE  = {20}T/;
    $et->SetFileType();
    my $tagTablePtr = GetTagTable('Image::ExifTool::FITS::Main');

    for (;;) {
        $raf->Read($buff, 80) == 80 or $et->Warn('Truncated FITS header'), last;
        my $key = substr($buff, 0, 8);
        $key =~ s/ +$//;    # remove trailing space from key
        if ($key eq 'CONTINUE') {
            defined $continue or $et->Warn('Unexpected FITS CONTINUE keyword'), next;
        } else {
            if (defined $continue) {
                # the previous value wasn't continued, so store with the trailing '&'
                $et->HandleTag($tagTablePtr, $tag, $continue . '&');
                undef $continue;
            }
            last if $key eq 'END';
            # make sure the key is valid
            $key =~ /^[-_A-Z0-9]*$/ or $et->Warn('Format error in FITS header'), last;
            if ($key eq 'COMMENT' or $key eq 'HISTORY') {
                my $val = substr($buff, 8); # comments start in column 9
                $val =~ s/ +$//;            # remove trailing spaces
                $et->HandleTag($tagTablePtr, $key, $val);
                next;
            }
            # ignore other lines that aren't tags
            next unless substr($buff,8,2) eq '= ';
            # save tag name (avoiding potential conflict with ExifTool variables)
            $tag = $Image::ExifTool::specialTags{$key} ? "_$key" : $key;
            # add to tag table if necessary
            unless ($$tagTablePtr{$tag}) {
                my $name = ucfirst lc $tag; # make tag name lower case with leading capital
                $name =~ s/_(.)/\U$1/g;     # remove all '_' and capitalize subsequent letter
                AddTagToTable($tagTablePtr, $tag, { Name => $name });
            }
        }
        my $val = substr($buff, 10);
        # parse quoted values
        if ($val =~ /^'(.*?)'(.*)/) {
            ($val, $buff) = ($1, $2);
            while ($buff =~ /^('.*?)'(.*)/) {   # handle escaped quotes
                $val .= $1;
                $buff = $2;
            }
            $val =~ s/ +$//;            # remove trailing spaces
            if (defined $continue) {
                $val = $continue . $val;
                undef $continue;
            }
            # check for possible continuation, removing trailing '&'
            $val =~ s/\&$// and $continue = $val, next;
        } elsif (defined $continue) {
            $et->Warn('Invalid FITS CONTINUE value');
            next;
        } else {
            $val =~ s/ *(\/.*)?$//;     # remove trailing spaces and comment
            next unless length $val;    # ignore undefined values
            $val =~ s/^ +//;            # remove leading spaces
            # re-format floating-point values to use 'e'
            $val =~ tr/DE/e/ if $val =~ /^[+-]?(?=\d|\.\d)\d*(\.\d*)?([ED]([+-]?\d+))?$/;
        }
        $et->HandleTag($tagTablePtr, $tag, $val);
    }
    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::FITS - Read Flexible Image Transport System metadata

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read meta
information from FITS (Flexible Image Transport System) images.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://fits.gsfc.nasa.gov/fits_standard.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/FITS Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

