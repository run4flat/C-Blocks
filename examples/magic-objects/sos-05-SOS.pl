=head1 NAME

sos-05-SOS.pl - trying out the real module

=head1 QUESTION

L<SOS05> creates a simple class that implements a two-dimensional point.
This script exercises it. Can we create the point? Can we call methods
on it?

=cut

use strict;
use warnings;
use SOS05;
use C::Blocks;
use C::Blocks::Filter::BlockArrowMethods;

print "=== create thing ===\n";
my SOS05 $thing = SOS05->new;
print "=== destroy thing ===\n";
undef $thing;
print "=== create another thing and set x and y ===\n";
$thing = SOS05->new;
$thing->set_x(4);
$thing->set_y(3);
print "=== get the magnitude and direction ===\n";
print "thing's magnitude is ", $thing->magnitude, "\n";
cblock {
	printf("from C, thing's magnitude is %f\n", $thing=>magnitude());
}

print "thing's direction (in radians) is ", $thing->direction, "\n";
cblock {
	printf("from C, thing's direction is %f\n", $thing=>direction());
}

=head1 RESULTS

This works as expected. Allocation and deallocation do not cause any
trouble. It is possible to create two new attributes and then work with
them using either the C interface or Perl interface.
