use strict;
use warnings;
use blib;
use C::Blocks;

print "Before block\n";

C {
	printf("From C block\n");
}

print "After block\n";
