use strict;
use warnings;

use C::Blocks;
use ImportTest;
cblock {
	foo();
}
print "Done!\n";
