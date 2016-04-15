use strict;
use warnings;
use mgpoint;

my $thing = mgpoint->new;
$thing->set(3, 4);

print "Distance is ", $thing->distance, "\n";

use C::Blocks;
cisa mgpoint $thing;
die $@ if $@;
cblock {
	$thing->x = 7;
}

print "After cblock, distance is ", $thing->distance, "\n";

my $foo = 8;
cisa mgpoint $foo;

die $@ if $@;
