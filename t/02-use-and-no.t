use strict;
use warnings;
use Test::More;

# In order to delay the compilation until run (i.e. test) time, we have
# to wrap these in string evals.
eval q{
	# Should work
	use C::Blocks;
	cblock {
		int i = 0;
	}
};
is($@, '', 'Compilation works fine');

eval q{
	# Should work
	use C::Blocks;
	cblock {
		int i = 0;
	}
	
	# Should fail to compile
	no C::Blocks;
	cblock {
		int i = 0;
	}
};
isnt($@, '', 'saying no C::Blocks then using "cblock" issues exception');
like($@, qr/syntax error .* near "cblock/, 'the exception is due to bad "cblock" keyword');

eval q{
	use C::Blocks;
	cblock {
		int i = 0;
	}
	
	no C::Blocks;
	
	my $foo = 1;
	
	use C::Blocks;
	cblock {
		int i = 0;
	}
};

is($@, '', 'use => no => use again lets us compile');

done_testing;
