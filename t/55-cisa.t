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


# Taken from http://stackoverflow.com/questions/483622/how-can-i-catch-the-output-from-a-carp-in-perl
undef $var;
my $stderr = '';
{
	local *STDERR;
	open STDERR, '>', \$stderr;
	cblock {
		$var = 3.5; /* should warn */
	}
}
like($stderr, qr/uninitialized value/, 'Standard types on uninitialized values warn');


####################################
use C::Blocks::Type;

my $var2;
cisa C::Blocks::Type::double_local $var;
cisa C::Blocks::Type::double_no_init $var2;

$stderr = '';
{
	local *STDERR;
	open STDERR, '>', \$stderr;
	cblock {
		$var = 13.5; /* should not propogate */
		$var2 = -3.5; /* should not warn */
	}
}
is($stderr, '', 'no_init on uninitialized value does not warn' );
is($var, 3, 'local typing works as advertised');
is($var2, -3.5, 'no-init typing saves result');


done_testing;
