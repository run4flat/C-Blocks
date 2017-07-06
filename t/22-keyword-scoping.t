# This tests the import/unimport lexical behavior of the C::Blocks keywords.

use strict;
use warnings;
use Test::More tests => 3;

SCOPE: {
	use C::Blocks -noPerlAPI;
	ok(
		eval q[cblock { int i; } 1],
		"Compiled C block within C::Blocks scope"
	);
	SCOPE: {
		no C::Blocks;
		local $SIG{__WARN__} = sub {};
		ok(
			!eval q[cblock { int i; } 1],
			"Expectedly failed to compile C block within 'no C::Blocks' scope"
		);
	}
}


local $SIG{__WARN__} = sub {};
ok(
	!eval q[cblock { int i; } 1],
	"Expectedly failed to compile C block outside C::Blocks scope"
);




