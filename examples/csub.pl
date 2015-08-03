use strict;
use warnings;
use C::Blocks;
use C::Blocks::PerlAPI;

csub foobar {
	/* declare the mark and argument stacks */
	dVAR;
	dXSARGS;
	int myval = 5;
	printf("You sent %d arguments\n");
}

count_args(1, 2);
print "Should have gotten two\n";
