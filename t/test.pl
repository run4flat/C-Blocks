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

print "After block\n";
