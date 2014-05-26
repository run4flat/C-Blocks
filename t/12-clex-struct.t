use strict;
use warnings;
use Test::More;
use C::Blocks;

# Tell C::Blocks to add rudimentary communications functions for testing
BEGIN { $C::Blocks::_add_msg_functions = 1 }

# Build a few functions that call the messaging interface
clex {
	/* Note that I must use c_blocks_send_bytes to send data from C
	 * back to Perl. */
	struct my_data {
		double x;
		double y;
	};
}

$C::Blocks::_msg = pack('d', 0);
my $double_size = length($C::Blocks::_msg);

cblock {
	int x_offset = ((int)(&((struct my_data*)0)->x));
	c_blocks_send_bytes(&x_offset, sizeof(int));
}
my ($offset) = unpack('i', $C::Blocks::_msg);
is($offset, 0, 'Sensible offset for x member');

cblock {
	int y_offset = ((int)(&((struct my_data*)0)->y));
	c_blocks_send_bytes(&y_offset, sizeof(int));
}
($offset) = unpack('i', $C::Blocks::_msg);
is($offset, $double_size, 'Sensible offset for y member');

cblock {
	int x_offset = ((int)(&((struct my_data*)0)->x));
	c_blocks_send_bytes(&x_offset, sizeof(int));
}
($offset) = unpack('i', $C::Blocks::_msg);
is($offset, 0, 'Sensible offset for x member (again)');

cblock {
	int y_offset = ((int)(&((struct my_data*)0)->y));
	c_blocks_send_bytes(&y_offset, sizeof(int));
}
($offset) = unpack('i', $C::Blocks::_msg);
is($offset, $double_size, 'Sensible offset for y member (again)');





BEGIN { pass 'Lexical block with struct definition compiles without trouble' }
pass('At runtime, lexical block with struct gets skipped without trouble');

# Start by packing in an interesting piece of data (gotta end with a null byte)
$C::Blocks::_msg = pack('dd', 10, 5);

#### Unpack that data, perform the subtraction, and send back the result
cblock {
	struct my_data * data = (void*) c_blocks_get_msg();
	double prod = data->x * data->y;
	double div = data->x / data->y;
	data->x = prod;
	data->y = div;
}
BEGIN { pass 'first cblock after lexical block compiles without trouble' }
pass 'first cblock is called and run without trouble';
my ($x, $y) = unpack('dd', $C::Blocks::_msg);
is($x, 50, 'Computes and packs the product');
is($y, 2, 'Computes and packs the ratio');

# Ensure we have enough memory for the next step. There's no simple way for me
# to allocate memory within a cblock, so I have to preallocate it here.
$C::Blocks::_msg = pack('dd', 0.3, 0.1);

#### Modify with another cblock
cblock {
	struct my_data * data = (void*) c_blocks_get_msg();
	data->x = -10;
	data->y = -5;
}
BEGIN { pass 'second cblock after lexical block compiles without trouble' }
pass 'second cblock is called and run without incident';
($x, $y) = unpack('dd', $C::Blocks::_msg);

is($x, -10, 'Second modification works');
is($y, -5, 'Second modification works');

done_testing;
