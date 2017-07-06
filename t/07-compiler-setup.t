# This tests compiler setup.

use strict;
use warnings;
use Test::More;

# Load cblocks
use C::Blocks -noPerlAPI;

# Does -D work?
BEGIN {
	$C::Blocks::_add_msg_functions = 1;
	$C::Blocks::compiler_options = '-Wall -Dtest_foo';
}
$C::Blocks::_msg = '';
cblock {
	#ifdef test_foo
		c_blocks_send_msg("1");
	#endif
}
ok ($C::Blocks::_msg, "compiler_options supports -D preprocessor definitions");

# Is compiler option cleared after block is compiled?
BEGIN { $C::Blocks::_add_msg_functions = 1 }
cblock {
	#ifdef test_foo
		c_blocks_send_msg("2");
	#else
		c_blocks_send_msg("3");
	#endif
}
is ($C::Blocks::_msg, 3, "compiler_options cleared before next block");


done_testing;
