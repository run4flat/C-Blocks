# The first test for C::Blocks::Types::IsaStruct. This is essentially a
# test version of the synopsis.
use strict;
use warnings;

############
# package with struct
############
package My::Point;
# testing hack: make it possible to "use" this package
BEGIN { $INC{'My/Point.pm'} = __FILE__ }
use C::Blocks;
use C::Blocks::Types::IsaStruct;
cshare {
	typedef struct My::Point_t {
		int x;
		int y;
	} My::Point;
}

############
# back to the testing...
############
package main;
use Test::More;
use C::Blocks;
use My::Point;

my Point $thing = pack('ii', 3, 4);
BEGIN { $C::Blocks::_add_msg_functions = 1 }
cblock {
	if ($thing.x == 3) {
		c_blocks_send_msg("worked");
	}
	else {
		c_blocks_send_msg("");
	}
	$thing.y = 5; //==  syntax hiliting... grumble grumble
}

ok $C::Blocks::_msg, "thing's x-value was properly set by pack and reachable via struct member";
my (undef, $y) = unpack('ii', $thing);
is $y, 5 => "Able to set thing's y-value via struct member assignment";

done_testing;
