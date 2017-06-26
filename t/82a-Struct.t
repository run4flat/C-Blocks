# The first test for C::Blocks::Types::Struct. This is essentially a
# test version of the synopsis.
use strict;
use warnings;
use Test::More;
use C::Blocks;

# Set up a basic class that overrides rudimentary functions to log
# what's going on...

{
	use C::Blocks::Types::Struct
		Point => [
			int => 'x',
			int => 'y',
		];

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
}

# Different package, different lexical scope, uninitialized variable.
package Foo;
use C::Blocks::Types::Struct Point => [];
my Point $other_thing;
cblock {
	$other_thing.x = -10;
}
package main;
my ($x) = unpack('i', $other_thing);
is $x, -10 => 'Second struct declaration does not require a full type spec';

done_testing;
