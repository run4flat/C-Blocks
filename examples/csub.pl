use strict;
use warnings;
use C::Blocks;
use C::Blocks::PerlAPI;

csub foobar {
	/* declare the mark and argument stacks */
	dVAR;
	dXSARGS;
	printf("You sent %d arguments\n", items);
}

foobar(1, 2);
print "Should have gotten two\n";

foobar(qw(a b c d e));
print "Should have gotten five\n";
