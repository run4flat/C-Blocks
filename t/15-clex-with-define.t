use strict;
use warnings;
use Test::More;
use C::Blocks;

# Tell C::Blocks to add rudimentary communications functions for testing
BEGIN { $C::Blocks::_add_msg_functions = 1 }

# Build a function that sets a global for me.
clex {
	#define get_dbl ((double*)c_blocks_get_msg())[0]
	#define send_dbl(to_send) c_blocks_send_bytes(&to_send, sizeof(double))
}

BEGIN {
	pass('Lexical block with defines compiles without trouble');
}
pass('At runtime, lexical block gets skipped without trouble');

# Generate a random integer between zero and 20, send it
my $number = rand(20) % 20;
$C::Blocks::_msg = pack('d', $number);

my $double = $number * 2;
# Double it in C
cblock {
	double old = get_dbl;
	old *= 2.0;
	send_dbl(old);
}
my $result = unpack('d', $C::Blocks::_msg);
is($result, $double, 'C defines from previously compiled scope work');

BEGIN {
	pass('cblock following lexical block compiles without trouble');
}

done_testing;
