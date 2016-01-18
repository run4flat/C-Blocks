use strict;
use warnings;
use Test::More;
use C::Blocks;
use C::Blocks::PerlAPI;

my $foo = 23;
my $var = 5;
cisa C::Blocks::Type::NV $var, $foo
	or fail('bad!');

is($@, undef, 'cisa passed');

cblock {
	$var = 10;
}
is($var, 10, 'Type::NV works');

done_testing;
