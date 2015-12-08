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
		$var = 5;
		''
	}
}

BEGIN { is($var, 5, 'Interpolation blocks execute at BEGIN time') }

done_testing;
