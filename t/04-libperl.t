# This tests PerlAPI to make sure that we can communicate between
# the perl interpreter and the cblocks. This requires a fairly
# substantial amount of the C::Blocks machinery to be functional, so it
# is perhaps not the best thing to rely on for so much of the testing.
# But then again, if it works we know that quite a bit of C::Blocks
# works, too.

use strict;
use warnings;
use Test::More;

# Load cblocks and PerlAPI
use C::Blocks;
use C::Blocks::PerlAPI;

# Work with package globals for now
our $shuttle;

cblock {
	SV * shuttle = Perl_get_sv(my_perl, "shuttle", 0);
	Perl_sv_setiv(my_perl, shuttle, 5);
}
BEGIN { pass 'cblock using basic Perl functions compiles fine' }
is($shuttle, 5, 'Can set Perl data in a cblock using direct function calls');

cblock {
	SV * shuttle = get_sv("shuttle", 0);
	sv_setiv(shuttle, -5);
}
BEGIN { pass 'cblock using Perl function macros compiles fine' }
is($shuttle, -5, 'Can set Perl data using macros');

cblock {
	SV * shuttle = get_sv("shuttle", 0);
	sv_setiv(shuttle, 10);
}
BEGIN { pass 'cblock using Perl function macros again compiles fine' }
is($shuttle, 10, 'Repeated cblocks work correctly');

cblock {
	sv_setiv(get_sv("shuttle", 0), 15);
}
BEGIN { pass 'cblock using nested Perl function macros compiles fine' }
is ($shuttle, 15, 'nested function calls do not cause segfaults');

eval q{
	cblock {
		SV * shuttle = get_sv("shuttle", 0);
		sv_setiv(shuttle, 50);
	}
	is($shuttle, 50, 'Simple string eval');
	1;
} or do {
	fail "Simple string eval\n";
};

for (1..3) {
	eval qq{
		cblock {
			SV * shuttle = get_sv("shuttle", 0);
			sv_setiv(shuttle, $_);
		}
		is(\$shuttle, $_, 'Repeated string eval number $_');
		1;
	} or do {
		fail "Repeated string eval number $_\n";
	};
}

eval q{
	my $lexical = 5;

	cblock {
			sv_setiv($lexical, 15);
	}
	is($lexical, 15, 'Sigil substitution');
} or do {
	if ($^V lt v5.18.0) {
		# We expected a croak. Make sure the message is correct
		like ($@, qr/You must use Perl 5\.18 or newer for variable interpolation/,
			'Sigil substitution croaks for perls before 5.18');
	}
	else {
		fail('Unexpected croak during sigil substitution');
		diag($@);
	}
};

# Dollar-signs can be carefully wrapped
eval q{
	$shuttle = undef;
	cblock {
		sv_setpv(get_sv("shuttle", 0), "$""money");
	}
	BEGIN{ pass 'Can carefully wrap dollar signs in C code' }
	is($shuttle, '$money', 'Successfully set string with dollar sign in it');
	1;
} or do {
	fail 'Can carefully wrap dollar signs in C code';
	diag($@);
};


done_testing;
