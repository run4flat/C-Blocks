use strict;
use warnings;
use Test::More;
use C::Blocks;
use C::Blocks::PerlAPI;

my C::NV_t $var = 23;

cblock { $var = 10.5; }
is($var, 10.5, 'C::NV_t works');

my C::uint_t $unsigned = 0;
cblock { $unsigned = 5; }
is($unsigned, 5, 'Type::uint works');

my C::int_t $signed = 0;
cblock { $signed = -5; }
is($signed, -5, 'Type::int works');


# Taken from http://stackoverflow.com/questions/483622/how-can-i-catch-the-output-from-a-carp-in-perl
my C::int_t $foo;
my $stderr = '';
{
	local *STDERR;
	open STDERR, '>', \$stderr;
	cblock {
		$foo = 3.5; /* should warn */
	}
}
like($stderr, qr/uninitialized value/, 'Standard types on uninitialized values warn');

done_testing;
