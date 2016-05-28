use strict;
use Test::More;
use Test::Warn;
use C::Blocks;



# no "use warnings", no warning
$C::Blocks::_add_msg_functions = 1;
$C::Blocks::_msg = '';
warning_is {eval q{
	cblock {
		int *a;
		double b;
		a = &b;
		c_blocks_send_msg("1");
	}
}} undef, 'Nothing reported if no "use warnings"';
is ($C::Blocks::_msg, 1, "unreported compiler warnings still allow execution");


use warnings;
$C::Blocks::_add_msg_functions = 1;
# redefinition warning
warning_like {eval q{
	cblock {
		int *a;
		double b;
		a = &b;
		c_blocks_send_msg("hello");
	}
}} qr/incompatible pointer type/, '"use warnings" turns on compiler warnings';
is ($C::Blocks::_msg, "hello", "reported compiler warnings still allow execution");

# silenced redefinition warning
warning_is {eval q{
	no warnings 'C::Blocks::compiler';
	cblock {
		int *a;
		double b;
		a = &b;
		c_blocks_send_msg("-0.5");
	}
}} undef, 'Explicitly turning off C::Blocks::compiler avoids warning';
is ($C::Blocks::_msg, "-0.5", "specifically ignored compiler warnings still allow execution");

done_testing;
