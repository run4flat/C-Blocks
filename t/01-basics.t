# This tests the basic operation of C::Blocks. It uses a special, simplified
# communication interface that lets the C code communicate with Perl without
# having to load libperl.

use strict;
use warnings;
use Test::More;

# Load cblocks
use C::Blocks;
# Tell C::Blocks to add rudimentary communications functions for testing
BEGIN {
	$C::Blocks::_add_msg_functions = 1;
}

# See if basic communicaton works
$C::Blocks::_msg = '';

cblock {
	c_blocks_send_msg("Hello!");
}

BEGIN {
	pass("First cblock compiles");
}

is($C::Blocks::_msg, 'Hello!', 'First cblock has desired side-effect');

=for later

is($shuttle, 5, 'Can set Perl data in a cblock using direct function calls');

cblock {
	SV * shuttle = get_sv("shuttle", 0);
	sv_setiv(shuttle, -5);
}

is($shuttle, -5, 'Can set Perl data using macros');

cblock {
	SV * shuttle = get_sv("shuttle", 0);
	sv_setiv(shuttle, 10);
}

is($shuttle, 10, 'Repeated cblocks work correctly');

eval q{
	cblock {
		SV * shuttle = get_sv("shuttle", 0);
		sv_setiv(shuttle, 50);
	}
	is($shuttle, 50, 'Simple string eval');
	1;
} or do {
	fail "Simple string eval\n";
};

for (1..3) {
	eval qq{
		cblock {
			SV * shuttle = get_sv("shuttle", 0);
			sv_setiv(shuttle, $_);
		}
		is(\$shuttle, $_, 'Repeated string eval number $_');
		1;
	} or do {
		fail "Repeated string eval number $_\n";
	};
}

=cut back

done_testing;
