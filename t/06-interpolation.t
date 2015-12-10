# This tests interpolation blocks.

use strict;
use warnings;
use Test::More;

# Load cblocks
use C::Blocks;
use C::Blocks::PerlAPI;

cblock {
	${''}
}
BEGIN { pass 'cblock using empty-string interpolation compiles fine' }
is($@, '', 'Executing empty block is fine');

my $var;
BEGIN { is($var, undef, 'var is not defined') }
cblock {
	${
		$var = 2;
		''
	}
}

BEGIN { is($var, 2, 'Interpolation blocks execute at BEGIN time') }

# Actually use and test the code interpolation
BEGIN { $C::Blocks::_add_msg_functions = 1 }
$C::Blocks::_msg = '';
for (1 .. 3) {
	cblock {
		c_blocks_send_msg("block " ${
			'"' . (++$var) . '"'
		});
	}
}
BEGIN { is($var, 3, 'Again, interpolation blocks execute at BEGIN time') }
is ($C::Blocks::_msg, 'block 3', "Interpolation occurs at compile time");

done_testing;
