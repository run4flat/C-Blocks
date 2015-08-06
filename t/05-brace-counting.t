# This tests the brace counting logic to make sure it catches the
# important situations.

use strict;
use warnings;
use Test::More;

# Load cblocks
use C::Blocks;

eval q{
	cblock {
		/* } { */
	}
};
is($@, '', 'Braces are ignored in C-style blocks');

eval q{
	cblock {
		char * foo = " } { ";
	}
};
is($@, '', 'Braces are ignored in double-quoted strings');

eval q{
	cblock {
		// } {
	}
};
is($@, '', 'Braces are ignored in C++ comments');

eval q{
	cblock {
		// } \
		{
	}
};
is($@, '', 'Braces are ignored in pathological C++ comments');


eval q{
	cblock {
		char a = '}';
		char b = '{';
	}
};
is($@, '', 'Braces are ignored in single-quoted strings');

done_testing;
