# For now, this tests two things. First, if a compilation fails, all the
# memory associated with the compilation must be freed. Second, all
# global variables are properly localized, namely $_. Eventually I would
# also like to test that a string-eval'd cblock gets cleaned up, but
# that's not part of this test yet.

use strict;
use warnings;
use Test::More;

# Load cblocks
use C::Blocks -noPerlAPI;

########################################################################
# Does a croaking filter leave $_ modified?
########################################################################

$_ = 'not clobbered';
sub my_filter {
	die "What happens now?";
}
eval q{
	use C::Blocks::Filter '&my_filter';
	cblock {}
};

is ($_, 'not clobbered', 'Filter that croaks does not clobber $_');

done_testing;
