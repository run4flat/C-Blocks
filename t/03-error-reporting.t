use strict;
use warnings;
use Test::More;

# In order to delay the compilation until run (i.e. test) time, we have
# to wrap these in string evals.
eval q{
#line 9 "t/03-error-reporting.t"
	# Should croak with the appropriate line
	use C::Blocks;
	cblock {
		int i 5
	}
};
like($@, qr/C::Blocks compile-time error/, 'Compilation fails with informative message');

my $file = quotemeta(__FILE__);
like($@, qr/$file/, 'Error is reported in this file');

unlike($@, qr/<string>/, 'Error does not report from "<string>"');

like($@, qr/line 12/, 'Error is reported from the correct line');

done_testing;