use strict;
use warnings;
use mgpoint;

# Perl-side constructor and methods
my $thing = mgpoint->new;
$thing->set(3, 4);
print "Distance to ", $thing->name, " is ", $thing->distance_1, "\n";
$thing->name('Random Point');

# Access data from C-side...
use C::Blocks;
cblock {
	data_from_SV($thing)->x = 5;
}
# ... and illustrate that the modifications are Perl accessible
print "After manual cblock, distance to ", $thing->name, " is ", $thing->distance_2, "\n";

# Use cisa to make data manipulation code even cleaner
cisa mgpoint $thing;
cblock {
	$thing->x = 7;
}
print "After cblock, distance to ", $thing->name, " is ", $thing->distance_3, "\n";

# cisa validation won't let us use bad variables:
my $foo = 8;
cisa mgpoint $foo; #BOOM! (a good boom here!)
cblock {
	$foo->x = 7;
}
