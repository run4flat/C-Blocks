# This tests interpolation blocks.

use strict;
use warnings;
use Test::More;

# Load cblocks
use C::Blocks;

cblock {
	${''}
}
BEGIN { pass 'cblock using empty-string interpolation compiles fine' }
is($@, '', 'Executing empty block is fine');

our $package_var;
my $lexical_var;
BEGIN {
	is($package_var, undef, 'package_var is not initially defined');
	is($lexical_var, undef, 'lexical_var is not initially defined');
}
cblock {
	${
		$package_var = 2;
		$lexical_var = 2;
		''
	}
}

BEGIN {
	is($package_var, 2, 'Interpolation blocks execute at BEGIN time');
	TODO: {
		local $TODO = 'Lexical vars get reset after parse and before BEGIN blocks for older Perls'
			if $^V lt v5.17.0;
		is($lexical_var, 2, 'Interpolation blocks execute at BEGIN time');
	}
}

# Actually use and test the code interpolation
BEGIN { $C::Blocks::_add_msg_functions = 1 }
$C::Blocks::_msg = '';
for (1 .. 3) {
	cblock {
		c_blocks_send_msg("block " ${
			'"' . (++$package_var) . (++$lexical_var) . '"'
		});
	}
}
BEGIN {
	is($package_var, 3, 'Again, interpolation blocks execute at BEGIN time');
	TODO: {
		local $TODO = 'Lexical vars get reset after parse and before BEGIN blocks for older Perls'
			if $^V lt v5.17.0;
		is($lexical_var, 3, 'Again, interpolation blocks execute at BEGIN time');
	}
}
is ($C::Blocks::_msg, 'block 33', "Interpolation occurs at compile time");

done_testing;
