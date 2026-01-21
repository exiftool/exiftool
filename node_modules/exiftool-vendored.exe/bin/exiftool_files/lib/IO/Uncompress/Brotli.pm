package IO::Uncompress::Brotli;

use 5.014000;
use strict;
use warnings;
use parent qw/Exporter/;

our @EXPORT = qw/unbro/;
our @EXPORT_OK = @EXPORT;

our $VERSION = '0.004001';

require XSLoader;
XSLoader::load('IO::Compress::Brotli', $VERSION);

1;
__END__

=encoding utf-8

=head1 NAME

IO::Uncompress::Brotli - Read Brotli buffers/streams

=head1 SYNOPSIS

  use IO::Uncompress::Brotli;

  # uncompress a buffer (yielding at most 10MB)
  my $decoded = unbro $encoded, 10_000_000;

  # uncompress a stream
  my $bro = IO::Uncompress::Brotli->create;
  while(have_input()) {
     my $block = get_input_block();
     my $decoded_block = $bro->decompress($block);
     handle_output_block($decoded_block);
  }

=head1 DESCRIPTION

IO::Uncompress::Brotli is a module that decompresses Brotli buffers
and streams. Despite its name, it is not a subclass of
L<IO::Uncompress::Base> and does not implement its interface. This
will be rectified in a future release.

=head2 One-shot interface

If you have the whole buffer in a Perl scalar use the B<unbro>
function.

=over

=item B<unbro>(I<$input>, I<$maximum_decoded_size>)

Takes a whole compressed buffer as input and returns the decompressed
data. It allocates a buffer of size I<$maximum_decoded_size> to store
the decompressed data, if this is not sufficient (or there is another
error) this function will croak.

Exported by default.

=back

=head2 Streaming interface

If you want to process the data in blocks use the object oriented
interface. The available methods are:

=over

=item IO::Uncompress::Brotli->B<create>

Returns a IO::Uncompress::Brotli instance. Please note that a single
instance cannot be used to decompress multiple streams.

=item $bro->B<decompress>(I<$block>)

Takes the a block of compressed data and returns a block of
uncompressed data. Dies on error.

=back

=head1 SEE ALSO

Brotli Compressed Data Format Internet-Draft:
L<https://www.ietf.org/id/draft-alakuijala-brotli-08.txt>

Brotli source code: L<https://github.com/google/brotli/>

=head1 AUTHOR

Marius Gavrilescu, E<lt>marius@ieval.roE<gt>

The encoder bindings, modernisation of the decoder bindings and a
clean up of the overall project were contributed by:

=over

=item Quim Rovira, E<lt>quim@rovira.catE<gt>

=item Ævar Arnfjörð Bjarmason, E<lt>avarab@gmail.comE<gt>

=item Marcell Szathmári

=item Mattia Barbon, E<lt>mattia@barbon.orgE<gt>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015-2018 by Marius Gavrilescu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.20.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
