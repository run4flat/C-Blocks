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
isnt($@, '', 'saying no C::Blocks should remove the C keyword and cause a Perl compile error');
note("Message is $@");

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
