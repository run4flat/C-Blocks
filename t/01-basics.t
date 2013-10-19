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
C {
	printf("ok 2 - printf from C block\n");
}

C {
	printf("ok 3 - multiple C blocks compile and run correctly\n");
}

eval q{
	C {
		printf("ok 4 - string evals work\n");
	}
};

for (5 .. 7) {
	eval qq{
		C {
			printf("ok $_ - string evals really work!\\n");
		}
	};
}
