package C::Blocks;

use strict;
use warnings;
use Alien::TinyCC;
use XSLoader;

# Use David Golden's version numbering suggestions. Note that we have to call
# the XSLoader before evaling the version string because XS modules check the
# version *string*, not the version *number*, at boot time.
our $VERSION = "0.000_001";
XSLoader::load('C::Blocks', $VERSION);
$VERSION = eval $VERSION;

our (%__code_cache_hash, @__code_cache_array);

sub import {
	my $class  = shift;
	my $caller = caller;
	no strict 'refs';
	*{$caller.'::C'} = sub () {};
	_import();
}

1;
