use strict;
use warnings;
use Test::More;
use C::Blocks;

# Tell C::Blocks to add rudimentary communications functions for testing
BEGIN { $C::Blocks::_add_msg_functions = 1 }

# Build a few functions that call the messaging interface
clex {
	/* Note that the message passing interface uses null-terminated strings,
	 * which is a bit restrictive for binary data. I have to make sure that
	 * none of the bytes in any of the data are zero, so I ether pick
	 * outlandish (and likely not cross-platform) floating point values, or
	 * I work with chars and refrain from using zero. */
	struct my_data {
		char x;
		char y;
		char name[14];
	};
}

BEGIN { pass 'Lexical block with struct definition compiles without trouble' }
pass('At runtime, lexical block with struct gets skipped without trouble');

# Start by packing in an interesting piece of data
$C::Blocks::_msg = pack('ccZ', 10, 5, 'subtract');

#### Unpack that data, perform the subtraction, and send back the result
cblock {
	struct my_data * data = (void*) c_blocks_get_msg();
	char diff = data->x - data->y;
	data->x = diff;
	data->y = -1;
	
	/* Set the new name with a string copy by hand */
	char * new_name = "difference";
	for (int i = 0; new_name[i] != 0; i++) data->name[i] = new_name[i];
	data->name[i] = 0;
}
BEGIN { pass 'first cblock after lexical block compiles without trouble' }
pass 'first cblock is called and run without trouble';
my ($diff, $filler, $description) = unpack('ccZ', $C::Blocks::_msg);
is($diff, 5, 'Computes and packs the difference');
is($filler, -1, 'Stores a filler byte');
is($description, 'difference', 'packs a description');



done_testing;
