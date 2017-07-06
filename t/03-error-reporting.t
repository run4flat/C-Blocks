use strict;
use warnings;
use Test::More;

#################
# Single cblock #
#################

# In order to delay the compilation until run (i.e. test) time, we have
# to wrap these in string evals.
eval q{
#line 9 "t/03-error-reporting.t"
	# Should croak with the appropriate line
	use C::Blocks -noPerlAPI;
	cblock {
		int i 5
	}
};
like($@, qr/error/, 'Compilation fails with informative message');

my $file = __FILE__;
$file =~ tr/\\/\//;  # windows backslash fix
$file = quotemeta($file);
like($@, qr/$file/, 'Error is reported in this file');

unlike($@, qr/<string>/, 'Error does not report from "<string>"');

like($@, qr/:12:/, 'Error is reported from the correct line');


####################
# Multiple cblocks #
####################

eval q{
#line 9 "t/03-error-reporting.t"
	# Should croak with the appropriate line
	use C::Blocks -noPerlAPI;
	cblock {
		int i = 5;
	}
	
	cblock {}
	
	cblock {
		int i 5
	}
};
like($@, qr/error/, 'Compilation fails with informative message');
like($@, qr/$file/, 'Error is reported in this file');
unlike($@, qr/<string>/, 'Error does not report from "<string>"');
like($@, qr/:18:/, 'Error is reported from the correct line');

done_testing;
