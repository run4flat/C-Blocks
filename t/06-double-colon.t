# This tests double-colon handling.

use strict;
use warnings;
use Test::More;

# Load cblocks
use C::Blocks;

cblock {
	int some__variable;
	some::variable = 10;
}
BEGIN { pass 'cblock using empty-string interpolation compiles fine' }
is($@, '', 'Executing double-colon-using glorified no-op is fine');

done_testing;
