=head1 NAME

examples::libprima - providing the C interface to the Prima GUI toolkit

=head1 TO USE

I have not put too much effort into making this run from anywhere, so
you will have to be a bit careful in how you use this example module.
The script F<examples/prima-lib-ellipse.pl> is an example that uses this
module. To run that script, or any script that uses this, you will have
to invoke the script from the root directory of this distribution.

=cut

package examples::libprima;
use strict;
use warnings;
use Prima::Config;
use ExtUtils::Embed;

use C::Blocks;

# Link to the Prima library:
BEGIN {
	# Utilize ExtUtils::Embed to get some build info
	$C::Blocks::compiler_options = join(' ', $Prima::Config::Config{inc}, ccopts);
	
	# tcc doesn't know how to use quotes in -I paths; remove them if found.
	$C::Blocks::compiler_options =~ s/-I"([^"]*)"/-I$1/g if $^O =~ /MSWin/;
	
	# Set the Prima library
	$C::Blocks::library_to_link = $Prima::Config::Config{dlname};
}
cshare {
	#include <apricot.h>
	#include <generic/Drawable.h>
}

1;
