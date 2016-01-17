use strict;
use warnings;
use Test::More;
use C::Blocks;
use C::Blocks::PerlAPI;
use C::Blocks::Type::NV;

my $foo = 23;
my $var = 5;
cisa C::Blocks::Type::NV $var, $foo;
cblock {
	$var = 10;
}
is($var, 10, 'Type::NV works');

done_testing;
