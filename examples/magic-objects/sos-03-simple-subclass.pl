=head1 NAME

sos-03-simple-subclass.pl - simple subclassing, just changing a method

=head1 QUESTION

This script tests the subclass created in SOS03. The only difference is
that new() and the reference count decrement should indicate they were
defined in SOS03; the others are still from SOS01.

=cut

use strict;
use warnings;
use C::Blocks;
use SOS01;
use SOS03;
use C::Blocks::Filter::BlockArrowMethods;

print "=== creating SOS01 object ===\n";
my $thing = SOS01->new;

print "=== getting rid of SOS01 object ===\n";
undef $thing;

print "=== creating SOS03 object ===\n";
$thing = SOS03->new;

print "=== All done! ===\n";

=head1 RESULTS

Everything works as expected. The SOS01 object is created and destroyed
as expected. The SOS03 object utilizes the SOS01 methods for most of its
functionality, but calls SOS03::refcount_dec at the appropriate time.

=cut
