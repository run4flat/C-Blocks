use strict;
use warnings;
use blib;
use C::Blocks;

print "Before block\n";

C {
	printf("From C block\n");
	int foo = 1;
	printf("foo = %d, which is %s\n", foo, (foo % 2 == 1 ? "odd" : "even"));
}

print "After first block\n";

C {
	printf("From second block\n");
}

print "All done!\n";

for (1..10) {
	eval qq{ C{
		printf("This is number $_ in the loop\n");
	}}
}
