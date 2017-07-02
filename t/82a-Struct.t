# The first test for C::Blocks::Types::Struct. This is essentially a
# test version of the synopsis.
use strict;
use warnings;
use Test::More;
use C::Blocks;

# Set up a basic class that overrides rudimentary functions to log
# what's going on...

use C::Blocks::Types::Struct 'Point';
clex {
	typedef struct Point_t {
		int x;
		int y;
	} Point;
}

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

use C::Blocks::Types::Struct [struct_point => 'struct Point_t'];
my struct_point $thing2; # uninitialized!!!
cblock {
	$thing2.x = 5;
	$thing2.y = -5;
}
(my $x, $y) = unpack ('ii', $thing2);
ok ($x == 5 && $y == -5, "Automatic data allocation works; two-argument declaration works")
	or diag "x is $x and y is $y";

done_testing;
