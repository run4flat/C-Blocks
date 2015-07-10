=head1 NAME

libprima - providing the C interface to the Prima GUI toolkit

=cut

package libprima;
use strict;
use warnings;
use Prima;
use Prima::Config;

use C::Blocks;

BEGIN {
	# Set the include flags and library to load
	$C::Blocks::compiler_options = $Prima::Config::Config{inc};
	$C::Blocks::library_to_link = $Prima::Config::Config{dlname};
}

