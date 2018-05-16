# This tests the basic operation of C::Blocks. It uses a special, simplified
# communication interface that lets the C code communicate with Perl without
# having to load libperl.

use strict;
use warnings;
use Test::More;

# Load cblocks
use C::Blocks -noPerlAPI;
# Tell C::Blocks to add rudimentary communications functions for testing
BEGIN { $C::Blocks::_add_msg_functions = 1 }

# See if basic communicaton works
$C::Blocks::_msg = '';

cblock {
	c_blocks_send_msg("Hello!");
}

BEGIN { pass("First cblock compiles") }

is($C::Blocks::_msg, 'Hello!', 'First cblock has desired side-effect');

# Pick a random digit between 0 and 4, to be doubled. I am restricting my
# attention to 0 through 4 so that the doubled value is still a single digit.
my @sample_data = (0 .. 4);
my $datum = $sample_data[rand(@sample_data)];
$C::Blocks::_msg = $datum;

cblock {
	char * msg = c_blocks_get_msg();
	// convert the first char to a number
	int num = (int)(msg[0] - '0');
	// double and store back in the string
	msg[0] = (char)(2 * num) + '0';
	// send back the result
	c_blocks_send_msg(msg);
}

BEGIN { pass("Second cblock compiles") }

is($C::Blocks::_msg, 2*$datum, 'Second cblock can retrieve and manipulate data');

# Test string evals with simple manipulation test
eval q{
	cblock {
		c_blocks_send_msg("50");
	}
	BEGIN { pass "cblock compiles within string eval" }
	is($C::Blocks::_msg, 50, 'Simple string eval');
	1;
} or do {
	fail 'Simple string eval';
	diag($@);
};

for (1..3) {
	eval qq{
		cblock {
			c_blocks_send_msg("$_");
		}
		is(\$C::Blocks::_msg, $_, 'Repeated string eval number $_');
		1;
	} or do {
		fail "Repeated string eval number $_\n";
	};
}

$C::Blocks::cq_line_directives = 1;
my $code = cq {
	printf("Hello, world!\n");
};

like($code, qr/#line \d+/, "cq code string has line directive");
like($code, qr/printf\("Hello, world!\\n"\);/, "cq code string contains correct code");

done_testing;
