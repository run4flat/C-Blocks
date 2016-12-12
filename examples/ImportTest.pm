package ImportTest;

use strict;
use warnings;
use C::Blocks;
use C::Blocks::PerlAPI;

cshare {
	int foo() {
		printf("Hello from TestMe!\n");
	}
}

no warnings 'C::Blocks::import', 'redefine';
sub import {
	print "Importing from TestMe\n";
#	goto &C::Blocks::load_lib
	C::Blocks::load_lib(@_);
}

1;
