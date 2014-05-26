use strict;
use warnings;
use Test::More;
use C::Blocks;

# Tell C::Blocks to add rudimentary communications functions for testing
BEGIN { $C::Blocks::_add_msg_functions = 1 }

# Start with a known (blank) message
$C::Blocks::_msg = '';

# Build a few functions that call the messaging interface
clex {
	void snd_msg(char * msg) {
		c_blocks_send_msg(msg);
	}
	void send_hello () {
		c_blocks_send_msg("Hello!");
	}
	void send_second() {
		c_blocks_send_msg("Second");
	}
}

BEGIN { pass 'Lexical block compiles without trouble' }
pass('At runtime, lexical block gets skipped without trouble');

# Don't need the basic communication function any more; we'll be accessing
# that functionality through the newly written functions instead.
#BEGIN { $C::Blocks::_add_msg_functions = 0 }

#### Invoke hello for the first time ####
cblock {
	send_hello();
}
BEGIN { pass 'cblock after lexical block compiles without trouble' }
pass 'cblock is called and run without trouble';
is($C::Blocks::_msg, 'Hello!', 'Function call in cblock has desired side-effect');

#### Invoke second for the first time ####
cblock {
	send_second();
}
BEGIN { pass 'second cblock after lexical block compiles without trouble' }
pass 'second cblock is called and run without trouble';
is($C::Blocks::_msg, 'Second', 'Function call in second cblock has desired side-effect');

#### Invoke snd_msg three times in a row ####
cblock {
	snd_msg("foo");
}
BEGIN { pass 'Nth cblock after lexical block compiles without trouble' }
pass 'Nth cblock is called and run without trouble';
is($C::Blocks::_msg, 'foo', 'sendign foo works');
cblock {
	snd_msg("bar");
}
BEGIN { pass 'Nth cblock after lexical block compiles without trouble' }
pass 'Nth cblock is called and run without trouble';
is($C::Blocks::_msg, 'bar', 'sending bar works');
cblock {
	snd_msg("baz");
}
BEGIN { pass 'Nth cblock after lexical block compiles without trouble' }
pass 'Nth cblock is called and run without trouble';
is($C::Blocks::_msg, 'baz', 'sending baz works');



#### Invoke hello for the second time ####
cblock {
	send_hello();
}
BEGIN { pass 'Nth cblock after lexical block compiles without trouble' }
pass 'Nth cblock is called and run without trouble';
is($C::Blocks::_msg, 'Hello!', 'Function call in third cblock has desired side-effect');

$C::Blocks::_msg = '';
eval q{
	cblock {
		// call hello again
		send_hello();
	}
	BEGIN { pass "string-eval'd code with lexical block compiles without trouble" }
	pass "string-eval'd code with lexical block runs without trouble";
	is($C::Blocks::_msg, 'Hello!', "string-eval'd code has desired side-effect");
	1;
} or do {
	fail "string-eval'd code has access to lexically scoped functions";
	diag $@;
};

done_testing;
