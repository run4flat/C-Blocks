use strict;
use warnings;
use Test::More;
use C::Blocks;

# Tell C::Blocks to add rudimentary communications functions for testing
BEGIN { $C::Blocks::_add_msg_functions = 1 }

# Start with a known (blank) message
$C::Blocks::_msg = '';

# Build a single function that calls the messaging interface
clex {
	void snd_msg(char * msg) {
		c_blocks_send_msg(msg);
	}
}

BEGIN { pass 'Lexical block compiles without trouble' }
pass('At runtime, lexical block gets skipped without trouble');

# Test it
cblock { snd_msg("First!"); }
BEGIN { pass 'cblock after first lexical block compiles without trouble' }
pass 'cblock after first lexical block runs without trouble';
is($C::Blocks::_msg, 'First!', 'Function call in cblock after first lexical block has desired side-effect');

### Second clex ###
clex {
	void send_hello () {
		c_blocks_send_msg("Hello!");
	}
}

# Make sure it compiled ok
BEGIN { pass 'Second lexical block compiles without trouble' }
pass('At runtime, second lexical block gets skipped without trouble');

# Make sure it didn't screw up previous stuff
cblock { snd_msg("Second!"); }
BEGIN { pass 'cblock after second lexical block compiles without trouble' }
pass 'cblock after second lexical block runs without trouble';
is($C::Blocks::_msg, 'Second!', 'Function call in cblock after second lexical block has desired side-effect');

# Test new function
cblock { send_hello(); }
BEGIN { pass 'second cblock after second lexical block compiles without trouble' }
pass 'cblock is called and run without trouble';
is($C::Blocks::_msg, 'Hello!', 'Function call in second cblock after second lexical block has desired side-effect');

done_testing;
