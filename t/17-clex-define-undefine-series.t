use strict;
use warnings;
use Test::More;
use C::Blocks;

# Tell C::Blocks to add rudimentary communications functions for testing
BEGIN { $C::Blocks::_add_msg_functions = 1 }

###### Create a lexically scoped macros similar to those in test 15 ######

clex {
	#define get_dbl ((double*)c_blocks_get_msg())[0]
	#define send_dbl(to_send) c_blocks_send_bytes(&to_send, sizeof(double))
}

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
is($result, $double, 'C defines from previously compiled scope work (as already tested)');

###### Redefine the preprocessor macro in a lexically scoped way ######

{
	clex {
		#undef get_dbl
		#define get_dbl -125
	}
	# invoke the new definition
	cblock {
		double new_val = get_dbl;
		send_dbl(new_val);
	}
	my $result = unpack('d', $C::Blocks::_msg);
	is($result, -125, 'Lexically scoped redefines work');
}

###### Outside the lexical scope, test for the previous preprocessor macro ######

# Generate a random integer between zero and 20, send it
$number = rand(20) % 20;
$C::Blocks::_msg = pack('d', $number);

$double = $number * 2;
# Double it in C
cblock {
	double old = get_dbl;
	old *= 2.0;
	send_dbl(old);
}
$result = unpack('d', $C::Blocks::_msg);
is($result, $double, 'Lexically scoped redefines do not leak');

done_testing;
