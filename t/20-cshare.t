use strict;
use warnings;
use Test::More;
use C::Blocks;

# This tests the ability to create functions and struct definitions in
# one package and share them with other packages. It does not rely on
# libperl.

# Start with a known (blank) message
$C::Blocks::_msg = '';

###############################
# Basic communication package #
###############################

package My::Basic::Comm;
{
	# The functions defined in this package will allow for easy communication
	# for the rest of the test script. It is lexically scoped so that it does
	# not leak to other declarations automatically.
	BEGIN { $C::Blocks::_add_msg_functions = 1 }
	
	cshare {
		void* get_data() {
			return c_blocks_get_msg();
		}
	}
	cshare {
		void send_data(void * bytes_to_send, int N_bytes) {
			c_blocks_send_bytes(bytes_to_send, N_bytes);
		}
	}
}

#####################
# Compilation tests #
#####################

package main;

# Make sure things compile without trouble
BEGIN { pass 'Shared block compiles without trouble' }
pass('At runtime, shared block gets skipped without trouble');

###############
# Scope tests #
###############

# Make sure we cannot access the functions where they're not supposed to live
eval q{
	cblock { void * foo = get_data(); }
	fail('Cannot call a cshare function outside its lexical scope without package import');
	1;
} or do {
	like($@, qr/undeclared function/, 'Cannot call a cshare function outside its lexical scope without package import');
};

{
	BEGIN { My::Basic::Comm->import }
	cblock { void * foo = get_data(); }
	pass('use <package> (or equivalent thereof) makes functions available');
}

#########################
# Derived Functionality #
#########################

package My::Struct::Comm;
{
	BEGIN { My::Basic::Comm->import }
	
}

package main;

done_testing;

__END__
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
