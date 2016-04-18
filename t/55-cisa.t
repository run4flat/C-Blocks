use strict;
use warnings;
use Test::More;
use C::Blocks;
use C::Blocks::PerlAPI;

my $var = 23;
cisa C::Blocks::Type::NV $var;
is($@, undef, 'cisa passed');

cblock { $var = 10.5; }
is($var, 10.5, 'Type::NV works');

# We should be able to change the type for a variable, and it should work
cisa C::Blocks::Type::double $var;
is($@, undef, 'cisa reset works ok');
cblock { $var = 15.25; }
is($var, 15.25, 'Type::double works');

cisa C::Blocks::Type::uint $var;
is($@, undef, 'cisa reset double -> unsigned int works ok');
cblock { $var = 5; }
is($var, 5, 'Type::uint works');

cisa C::Blocks::Type::int $var;
is($@, undef, 'cisa reset unsigned int -> int works ok');
cblock { $var = -5; }
is($var, -5, 'Type::int works');

done_testing;
