use strict;
use warnings;
use Test::More;
use C::Blocks;

# Tell C::Blocks to add rudimentary communications functions for testing
BEGIN { $C::Blocks::_add_msg_functions = 1 }

# Define a function to be used later
clex {
	double subtract(double first, double second) {
		return first - second;
	}
	double * get_numbers() {
		return (double*)c_blocks_get_msg();
	}
}

BEGIN { pass 'outer clex compiles fine' }

# Generate two random numbers; make it easy to msg them
my @numbers = map { rand() } (1 .. 2);
sub copy_numbers_to_msg {
	$C::Blocks::_msg = pack('d*', @numbers);
}

# Enter a block; clex material should stay within the block
{
	# Ensure the cblock works as expected
	copy_numbers_to_msg;  # send data
	cblock {
		double * numbers = get_numbers();                 // get data
		double result = subtract(numbers[0], numbers[1]); // subtract
		c_blocks_send_bytes(&result, sizeof(double));     // send result
	}
	
	BEGIN { pass 'inner cblock compiles fine' }
	
	my $answer = unpack('d', $C::Blocks::_msg);
	is($answer, $numbers[0] - $numbers[1], 'get_numbers and subtract work in nested block');
	
	# Define a function that performs the check for us
	clex {
		void perform_subtract_check() {
			double * numbers = get_numbers();                 // get data
			double result = subtract(numbers[0], numbers[1]); // subtract
			c_blocks_send_bytes(&result, sizeof(double));     // send result
		}
	}
	BEGIN { pass 'inner clex compiles fine' }
	# Send the data, call the subtraction function
	copy_numbers_to_msg;
	cblock { perform_subtract_check(); }
	BEGIN { pass 'inner cblock compiles fine' }
	
	$answer = unpack('d', $C::Blocks::_msg);
	is($answer, $numbers[0] - $numbers[1], 'get_numbers and subtract work in nested function');
}

BEGIN { pass 'exiting block works fine' }
eval q{
	copy_numbers_to_msg;
	cblock { perform_subtract_check(); }
	fail('Cannot call a function outside its lexical scope');
	1;
} or do {
	like($@, qr/undeclared function/, 'Cannot call a function outside its lexical scope');
};

done_testing;
