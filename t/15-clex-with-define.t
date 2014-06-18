use strict;
use warnings;
use Test::More;
use C::Blocks;
cuse C::Blocks::libperl;

# Build a function that sets a global for me.
our $shuttle;
clex {
	int Perl_get_shuttle_i(pTHX) {
		#define get_shuttle_i() Perl_get_shuttle(aTHX)
		SV * shuttle = get_sv("shuttle", 0);
		return SvIV(shuttle);
	}
	void Perl_set_shuttle_i(pTHX_ int new_value) {
		#define set_shuttle_i(new_value) Perl_set_shuttle_i(aTHX_ new_value)
		SV * shuttle = get_sv("shuttle", 0);
		sv_setiv(shuttle, 5);
	}
}

BEGIN {
	pass('Lexical block compiles without trouble');
}
pass('At runtime, lexical block gets skipped without trouble');

# Generate a random integer between zero and 20
$shuttle = rand(20) % 20;
my $double = $shuttle * 2;
# Double it
cblock {
	int old = get_shuttle_i();
	set_shuttle_i(old * 2);
}
is($shuttle, $double, 'C functions from previously compiled scope work');

BEGIN {
	pass('cblock following lexical block compiles without trouble');
}

done_testing;
