use strict;
use warnings;
use C::Blocks;

# removing static clears up the issue
clex {
	static unsigned int x;
}

#use C::Blocks::Filter;
cblock {
	x = 123456789;
}

