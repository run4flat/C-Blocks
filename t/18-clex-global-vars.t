use strict;
use warnings;
use Test::More;
use C::Blocks;

###### Create a lexically scoped global variable ######

# Declare a global that we'll use throughout
clex { double A; }

BEGIN { pass('Lexical block with global compiles fine') }

# Initialize the global
cblock { A = 20; }

BEGIN { pass('Block that uses the global compiles fine') }
pass('Block that sets the global runs without trouble');

#### Does the value of the variable live beyond the end of the block? ####

BEGIN { $C::Blocks::_add_msg_functions = 1 }
cblock {
	c_blocks_send_bytes(&A, sizeof(double));
}

my $result = unpack('d', $C::Blocks::_msg);
is($result, 20, 'Global variables have static storage');

done_testing;
