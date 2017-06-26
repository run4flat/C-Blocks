# The first test for C::Blocks::Types::Struct. This is essentially a
# test version of the synopsis.
use strict;
use warnings;
use Test::More;
use C::Blocks;

# Set up a basic class that overrides rudimentary functions to log
# what's going on...

use C::Blocks::Types::Struct {
	short_name => 'Point2D',
	elements => [
		int => 'x',
		int => 'y',
	],
	package => 'My::2DPoint::Struct',
};
use C::Blocks::Types::Struct {
	short_name => 'Point3D',
	elements => [
		@My::2DPoint::Struct::elements,
		int => 'z',
	],
	package => 'My::3DPoint::Struct',
};

#print "2d point elements are @My::2DPoint::Struct::elements\n";

my Point2D $pair = pack('ii', 0, 0);
cblock {
	$pair.x = 10;
}
is (unpack('i', $pair), 10, 'Able to set Point2D element via cblock');

my Point3D $triple;
cblock {
	$triple.x = 5;
	$triple.y = 10; //==
	$triple.z = 20;
}
my ($x, $y, $z) = unpack('iii', $triple);
is ($x, 5, 'Point3D x is 5');
is ($y, 10, 'Point3D y is 10');
is ($z, 20, 'Point3D z is 20');

# Treat the triple as a pair
my Point2D $other_pair = $triple;
cblock {
	$other_pair.x = -5;
}
($x, $y, $z) = unpack('iii', $other_pair);
is ($x, -5, 'Point3D cast as Point2D x was changed to -5');
is ($y, 10, 'Point3D cast as Point2D y is still 10');
is ($z, 20, 'Point3D cast as Point2D z is still 20');

($x, $y, $z) = unpack('iii', $triple);
is ($x, 5, 'Point3D x is still 5 (value copied)');
is ($y, 10, 'Point3D y is still 10 (value copied)');
is ($z, 20, 'Point3D z is still 20 (value copied)');

done_testing;
