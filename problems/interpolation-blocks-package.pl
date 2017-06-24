# Test of 
use strict;
use warnings;

# Uncomment to trigger compile-time error:
#  Undefined subroutine &main::foo called at (eval 7) line 2.
#package TEST;

use C::Blocks;
use C::Blocks::PerlAPI;

sub foo {
	print "caller is " . caller . "\n";
	''
}

cblock {
	printf("from C\n");
	${
		foo();
	}
}
