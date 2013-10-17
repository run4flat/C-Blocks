package C::Blocks;

use strict;
use warnings;
use Alien::TinyCC;

our $VERSION = "0.000_001";
$VERSION = eval $VERSION;

use XSLoader;

XSLoader::load('C::Blocks', $VERSION);

sub import {
	my $class  = shift;
	my $caller = caller;
	no strict 'refs';
	*{$caller.'::C'} = sub () {};
	_import();
}

1;
