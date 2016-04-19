use strict;
use warnings;
use Test::More;
use C::Blocks;
use C::Blocks::PerlAPI;

# Tell C::Blocks to add rudimentary communications functions for testing
BEGIN { $C::Blocks::_add_msg_functions = 1 }

# Start with a known (blank) message
$C::Blocks::_msg = '';

# Create a csub that sets the message to a known string
csub set_msg_to_hello {
	c_blocks_send_msg("Hello!");
}

BEGIN { pass 'csub compiles without trouble' }
pass('At runtime, csub gets skipped without trouble');
is($C::Blocks::_msg, '', 'No side-effects before calling csub');

set_msg_to_hello();
is($C::Blocks::_msg, 'Hello!', 'csub has desired effect');

done_testing;
