=head1 NAME

sos-04-new-attribute.pl - full subclass with a new attribute

=head1 QUESTION

This script tests the subclass created in SOS04.

=cut

use strict;
use warnings;
use C::Blocks;
use SOS04;

print "=== creating SOS04 object ===\n";
my $thing = SOS04->new;
#print "thing is $thing\n";
#use Devel::Peek;
#Dump($thing);

my $new_val = int(rand(1000));
print "=== setting thing's value to $new_val ===\n";
$thing->set_val($new_val);

print "=== getting and printing thing's value ===\n";
print "thing's val is ", $thing->get_val, "\n";

print "=== getting rid of SOS04 object ===\n";
undef $thing;

print "=== All done! ===\n";

=head1 RESULTS

Everything works as expected. The SOS04 object's new methods are called 
from Perl-space as they should be. All refcounting works, as evidenced
by destruction at the proper moment.

=cut
