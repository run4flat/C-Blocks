use strict;
use warnings;
use Test::More;
use C::Blocks;

{
	local $TODO = 'Fix visiblity for clex following loop';
	ok(eval q{
		for (1) {}
		clex { int foo() {} }
		cblock { foo(); }
		1;
	}, "Declarations in clex immediately following for-loop are visible")
	or diag "**Error message was** $@";

	ok(eval q{
		while (0) {}
		clex { int foo() {} }
		cblock { foo(); }
		1;
	}, "Declarations in clex immediately following while-loop are visible")
	or diag "**Error message was** $@";

	ok(eval q{
		until (1) {}
		clex { int foo() {} }
		cblock { foo(); }
		1;
	}, "Declarations in clex immediately following until-loop are visible")
	or diag "**Error message was** $@";

	ok(eval q{
		if (0) {}
		clex { int foo() {} }
		cblock { foo(); }
		1;
	}, "Declarations in clex immediately following if block are visible")
	or diag "**Error message was** $@";

	ok(eval q{
		unless (1) {}
		clex { int foo() {} }
		cblock { foo(); }
		1;
	}, "Declarations in clex immediately following unless block are visible")
	or diag "**Error message was** $@";
	
	ok(eval q{
		if (0) {}
		elsif (0) {}
		clex { int foo() {} }
		cblock { foo(); }
		1;
	}, "Declarations in clex immediately following if-elsif block are visible")
	or diag "**Error message was** $@";
}

ok(eval q{
	if (0) {}
	else {}
	clex { int foo() {} }
	cblock { foo(); }
	1;
}, "Declarations in clex immediately following if-else block are visible")
or diag "**Error message was** $@";

ok(eval q{
	do {};
	clex { int foo() {} }
	cblock { foo(); }
	1;
}, "Declarations in clex immediately following do block are visible")
or diag "**Error message was** $@";

ok(eval q{
	SOME_LABEL: {
		my $a = 5;
		redo SOME_LABEL if $a > 6;
	}
	continue {
		$a--;
	}
	clex { int foo() {} }
	cblock { foo(); }
	1;
}, "Declarations in clex immediately following bare block with continue are visible")
or diag "**Error message was** $@";

ok(eval q{
	SOME_LABEL: {
		my $a = 5;
		next SOME_LABEL if $a > 6;
	}
	clex { int foo() {} }
	cblock { foo(); }
	1;
}, "Declarations in clex immediately following bare block are visible")
or diag "**Error message was** $@";

done_testing;
