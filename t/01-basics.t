use strict;
use warnings;

# I will construct my tap by hand in order to get the right results
BEGIN {
	$| = 1;
	print "1..7\n";
}

# Make sure it loads
use C::Blocks;
BEGIN {
	print "ok 1 - loaded C::Blocks\n";
}

# First real print
cblock {
	#include <stdio.h>
	printf("ok 2 - printf from C block\n");
}

cblock {
	#include <stdio.h>
	printf("ok 3 - multiple C blocks compile and run correctly\n");
}

eval q{
	cblock {
		#include <stdio.h>
		printf("ok 4 - string evals work\n");
	}
	1;
} or do {
	print "not ok 4 - string evals work\n";
};

for (5 .. 7) {
	eval qq{
		cblock {
			#include <stdio.h>
			printf("ok $_ - repeated string evals work!\\n");
		}
		1;
	} or do {
		printf("not ok $_ - repeated string evals work!\n");
	}
}
