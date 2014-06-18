use strict;
use warnings;
use Test::More;
use C::Blocks;

cuse C::Blocks::libperl;
clex {
	#define sbfree(a)         ((a) ? Safefree(stb__sbraw(a)),0 : 0)
	#define sbpush(a,v)       (stb__sbmaybegrow(a,1), (a)[stb__N_used(a)++] = (v))
	#define sbpop(a)          ((a && stb__N_used(a)) ? (a)[--stb__N_used(a)] : 0)
	#define sbcount(a)        ((a) ? stb__N_used(a) : 0)
	#define sbadd(a,n)        (stb__sbmaybegrow(a,n), stb__N_used(a)+=(n), &(a)[stb__N_used(a)-(n)])
	#define sbremove(a,n)     ((a) ? (stb__N_used(a) > n ? (stb__N_used(a) -= n) : (stb__N_used(a) = 0)) : 0)
	#define sblast(a)         ((a)[stb__N_used(a)-1])

	#define stb__sbraw(a) ((int *) (a) - 2)
	#define stb__N_items(a)   stb__sbraw(a)[0]
	#define stb__N_used(a)    stb__sbraw(a)[1]

	#define stb__sbneedgrow(a,n)  ((a)==0 || stb__N_used(a)+n >= stb__N_items(a))
	#define stb__sbmaybegrow(a,n) (stb__sbneedgrow(a,(n)) ? stb__sbgrow(a,n) : 0)
	#define stb__sbgrow(a,n)  stb__sbgrowf(aTHX_ (void **) &(a), (n), sizeof(*(a)))

	static void stb__sbgrowf(pTHX_ void **arr, int increment, int itemsize)
	{
		int N_items;
		int * p;
		if (arr) {
			/* If the array was previously allocated, then call for a
			 * reallocation. */
			p = stb__sbraw(*arr);
			N_items = stb__N_items(*arr)+increment;
			Renewc(p, itemsize * N_items + sizeof(int)*2, char, int* );
		}
		else {
			/* If the array was previously unallocated, call for a new
			 * block of memory. */
			N_items = increment + 1;
			Newxc(p, itemsize * N_items + sizeof(int)*2, char, int* );
		}
		if (p == 0) croak("C::Blocks::StretchyBuffer: Unable to allocate memory");
		/* First integer indicates how much room we have */
		p[0] = N_items;
		/* Second integer indicates how many items are "used", which will
		 * not change during this procedure. However, if the initial array
		 * was empty, then the newly allocated stretchy has no "used" slots,
		 * so mark it as such. */
		if (!*arr) p[1] = 0;
		/* Re-assign the array to its new memory slot */
		*arr = (void *) (p + 2);
	}
}


#cuse C::Blocks::StretchyBuffer;
BEGIN { pass 'StretchyBuffer imports without trouble' }

my ($sb_pointer, $info_to_test);

cblock {
	double * data = NULL;
	sbadd(data, 20);
	for (int i = 0; i < sbcount(data); data[i++] = i);
	sv_setiv($sb_pointer, PTR2IV(data));
}
BEGIN { pass 'Use of StretchyBuffer compiles without issue' }

cblock {
	double * data = INT2PTR(double*, SvIV($sb_pointer));
	SvIV($info_to_test, sbcount(data));
}

is($info_to_test, 20, 'Size is correctly stored and accessible');

cblock {
	double * data = INT2PTR(double*, SvIV($sb_pointer));
	SvIV($info_to_test, sbpop($sb_pointer));
}
is($info_to_test, 19, 'Popping off the last item of a 20-item');

cblock {
	double * data = INT2PTR(double*, SvIV($sb_pointer));
	SvIV($info_to_test, sbcount(data));
}
is($info_to_test, 19, 'After popping, buffer reports only 19 elements');

cblock {
	double * data = INT2PTR(double*, SvIV($sb_pointer));
	sbfree(data);
}
pass 'Freeing data does not segfault';

done_testing;
