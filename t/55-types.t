use strict;
use warnings;
use Test::More;
use C::Blocks;
use C::Blocks::Types qw(:all);

my NV $var = 23;

cblock { $var = 10.5; }
is($var, 10.5, 'NV works');

my uint $unsigned = 0;
cblock { $unsigned = 5; }
is($unsigned, 5, 'uint works');

my Int $signed = 0;
cblock { $signed = -5; }
is($signed, -5, 'Int works');


# Taken from http://stackoverflow.com/questions/483622/how-can-i-catch-the-output-from-a-carp-in-perl
my Int $foo;
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
