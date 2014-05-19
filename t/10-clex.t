use strict;
use warnings;

# I will construct my tap by hand in order to get the right results
BEGIN {
	$| = 1;
	print "1..7\n";
}

use C::Blocks;

# First real print
cblock {
	printf("ok 2 - printf from first C block\n");
}

# Build a function
clex {
	void print_ok(int count, char * message) {
		printf("ok %d - %s", count, message);
	}
}

print "ok 3 - clex bareword did not croak\n";

# Call the function
cblock {
	printf("ok 4 - printf from second C block\n");
	print_ok(5, "Calling previously defined C function works");
}

eval q{
	cblock {
		printf("ok 6 - string evals work\n");
	}
};

for (7 .. 7) {
	eval qq{
		cblock {
			printf("ok $_ - string evals really work!\\n");
		}
	};
}

BEGIN {
	print "ok 1 - everything compiled\n";
}
