use strict;
use warnings;
use Test::More;
use C::Blocks;
use C::Blocks::PerlAPI;

# Try allocating a double array and filling it with numbers.
my $c_array_ptr;

clex {
	#define N 10
}

cblock {
	double * c_array;
	int i;
	Newx(c_array, N, double);
	
	for (i = 0; i < N; i++) {
		c_array[i] = i;
	}
	
	sv_setiv($c_array_ptr, PTR2IV(c_array));
}
BEGIN { pass 'Use of Newx, sv_setiv, and PTR2IV compiles without issue' }

my $sum;
cblock {
	/* sum the array */
	int i;
	double sum = 0;
	double * data = INT2PTR(double*, SvIV($c_array_ptr));
	for (i = 0; i < N; i++) {
		sum += data[i];
	}
	sv_setnv($sum, sum);
}

is($sum, 45, 'Sum of data is correct; probably correctly stored');

cblock {
	double * data = INT2PTR(double*, SvIV($c_array_ptr));
	Safefree(data);
}
BEGIN { pass 'Use of Safefree compiles without issue' }
pass 'Freeing data does not segfault';

done_testing;

BEGIN { pass 'Remainder of test script compiled without issue' }
