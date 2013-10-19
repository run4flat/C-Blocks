use strict;
use warnings;
use Test::More;
use C::Blocks;

our $var = 0;

C {
	SV * var = get_sv("var");
	sv_setiv(var, 1);
}

is($var, 1, 'C code can change the value of a package global');

done_testing;
