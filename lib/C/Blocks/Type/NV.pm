use strict;
use warnings;
package C::Blocks::Type::NV;

use C::Blocks;
use C::Blocks::PerlAPI;
our $TYPE = 'double';
our $INIT = 'SvNV';
our $CLEANUP = 'sv_setnv';

use Scalar::Util;
use Carp;

sub check_var_types {
	my $package = shift @_;
	while (@_) {
		my ($arg_name, $arg) = splice @_, 0, 2;
		croak("$arg_name is an object!") if Scalar::Util::blessed($arg);
		croak("$arg_name does not look like a number")
			unless Scalar::Util::looks_like_number($arg);
	}
}

1;
