use strict;
use warnings;
use Test::More;
use C::Blocks;

use C::Blocks::PerlAPI;
use C::Blocks::StretchyBuffer;
BEGIN { pass 'StretchyBuffer imports without trouble' }

my ($sb_pointer, $info_to_test);

cblock {
	double * data = NULL;
	sbadd(data, 20);
	for (int i = 0; i < sbcount(data); data[i] = i++);
	sv_setiv($sb_pointer, PTR2IV(data));
}
BEGIN { pass 'Use of StretchyBuffer compiles without issue' }

cblock {
	/* Get the first element */
	double * data = INT2PTR(double*, SvIV($sb_pointer));
	sv_setiv($info_to_test, data[0]);
}

is($info_to_test, 0, 'First element is zero');

cblock {
	/* Get the length */
	double * data = INT2PTR(double*, SvIV($sb_pointer));
	sv_setiv($info_to_test, sbcount(data));
}

is($info_to_test, 20, 'Size is correctly stored and accessible');

cblock {
	/* Pop the last element off */
	double * data = INT2PTR(double*, SvIV($sb_pointer));
	sv_setiv($info_to_test, sbpop(data));
}
is($info_to_test, 19, 'Popping off the last item of a 20-item');

cblock {
	double * data = INT2PTR(double*, SvIV($sb_pointer));
	sv_setiv($info_to_test, sbcount(data));
}
is($info_to_test, 19, 'After popping, buffer reports only 19 elements');

cblock {
	double * data = INT2PTR(double*, SvIV($sb_pointer));
	sbfree(data);
}
pass 'Freeing data does not segfault';

done_testing;

BEGIN { pass 'Remainder of test script compiled without issue' }
