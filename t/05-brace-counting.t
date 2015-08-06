# This tests the brace counting logic to make sure it catches the
# important situations.

use strict;
use warnings;
use Test::More;

# Load cblocks
use C::Blocks;

local $TODO = 'Brace counting needs to be improved';

eval q{
	cblock {
		/* } { */
	}
};
is($@, undef, 'Braces are ignored in C-style blocks');

eval q{
	cblock {
		char * foo = " } { ";
	}
};
is($@, undef, 'Braces are ignored in double-quoted strings');

eval q{
	cblock {
		// } {
	}
};
is($@, undef, 'Braces are ignored in C++ comments');

eval q{
	cblock {
		// } \
		{
	}
};
is($@, undef, 'Braces are ignored in pathological C++ comments');


eval q{
	cblock {
		char a = '}';
		char b = '{';
	}
};
is($@, undef, 'Braces are ignored in single-quoted strings');

done_testing;
