use strict;
use warnings;
use Test::More;
use C::Blocks;

# Tell C::Blocks to add rudimentary communications functions for testing
BEGIN { $C::Blocks::_add_msg_functions = 1 }
$C::Blocks::_msg = '';

# Build a few functions that call the messaging interface
clex {
	void send_hello () {
		c_blocks_send_msg("Hello!");
	}
	void send_second() {
		c_blocks_send_msg("Second");
	}
}

BEGIN { pass 'Lexical block compiles without trouble' }
pass('At runtime, lexical block gets skipped without trouble');

# Invoke those functions

cblock {
	send_hello();
}
BEGIN { pass 'cblock after lexical block compiles without trouble' }
pass 'cblock is called and run without trouble';
is($C::Blocks::_msg, 'Hello!', 'Function call in cblock has desired side-effect');

cblock {
	send_second();
}
BEGIN { pass 'second cblock after lexical block compiles without trouble' }
pass 'second cblock is called and run without trouble';
is($C::Blocks::_msg, 'Second', 'Function call in second cblock has desired side-effect');

cblock {
	send_hello();
}
BEGIN { pass 'third cblock after lexical block compiles without trouble' }
pass 'third cblock is called and run without trouble';
is($C::Blocks::_msg, 'Hello!', 'Function call in third cblock has desired side-effect');

#$C::Blocks::_msg = '';
#eval q{
#	cblock {
#		// call hello again
#		send_hello();
#	}
#	BEGIN { pass "string-eval'd code with lexical block compiles without trouble" }
#	pass "string-eval'd code with lexical block runs without trouble";
#	is($C::Blocks::_msg, 'Hello', "string-eval'd code has desired side-effect");
#	1;
#} or do {
#	fail "string-eval'd code has access to lexically scoped functions";
#	diag $@;
#};

done_testing;
