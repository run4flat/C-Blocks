# Ensures that sigiled variables are correctly interpolated into the
# compiling context.
use strict;
use warnings;
use Test::More;

# Load cblocks; PerlAPI gets loaded implicitly
use C::Blocks;

# lexical scalars are properly interpreted
eval q{
	my $lexical = 5;

	cblock {
		sv_setiv($lexical, 15);
	}
	is($lexical, 15, 'Sigil substitution');
	
	cblock {
		sv_setpv($lexical, "fun times");
	}
	is($lexical, 'fun times', 'More sigil substitution');
} or do {
	fail('Unexpected croak during sigil substitution');
	diag($@);
};

# sigils need not be carefully wrapped
eval q{
	my $shuttle;
	cblock {
		sv_setpv($shuttle, "$money");
	}
	BEGIN{ pass 'Sigils need not be carefully wrapped' }
	is($shuttle, '$money', 'Successfully set string with dollar sign in it');
	1;
} or do {
	fail 'Sigils need not be carefully wrapped';
	diag($@);
};

# C variable names can be identical to Perl variable names
eval q{
	my $N;
	cblock {
		int N = 12;
		sv_setiv($N, N);
	}
	is($N, 12, 'C variable names can be identical to Perl variable names')
} or do {
	fail 'C variable names can be identical to Perl variable names';
	diag($@);
};

# lexical arrays are properly interpreted
eval q{
	my @array = (1, 3, 5);

	cblock {
		/* Append another element to the array */
		av_push(@array, newSViv(7));
	}
	is(0+@array, 4, 'Array was appended to') and
	is($array[-1], 7, 'Correct value was placed onto the array');
} or do {
	fail('Lexical arrays are properly interpreted');
	diag($@);
};

# lexical hashes are properly interpreted
eval q{
	my %hash = (one => 1, two => 2);

	cblock {
		/* delete the "second" entry */
		hv_delete(%hash, "two", 3, G_DISCARD);
	}
	ok((not exists $hash{two}), "Hash member was removed");
} or do {
	fail('Lexical hashes are properly interpreted');
	diag($@);
};

eval q{
	my $lexical = 5;

	cblock {
		sv_setpvf($lexical, "Integer is %d", 8);
	}
	is($lexical, 'Integer is 8', 'printf-style stuff usually works');
	
	cblock {
		/* Throw off the parser with this double-quote: " */
		sv_setpvf($lexical, "Integer is %d", 10);
	}
	is($lexical, 'Integer is 10', 'Errant double-quotes do not mess things up');
	1;
} or do {
	fail('Proper double-quote and sigil interactions failed to compile');
	diag($@);
};

eval q{
	$Some::Package::Variable = 5;

	cblock {
		sv_setiv($Some::Package::Variable, 8);
	}
	is($Some::Package::Variable, 8, 'Package variables are properly resolved');
	1;
} or do {
	fail('Package variable name resolution failed to compile');
	diag($@);
};


TODO: {
	our $test_name = '"our $bar" gets detected as a package var';
	local $TODO = "pad_find_my returns a pad slot for package vars declared with our() (it's an alias of sorts)";
	unless(eval qq[
			use C::Blocks::Types qw(double);
			our double \$bar = 12;
			cblock {
				\$bar = 13;
			}
			is(\$bar, 13, '$::test_name: desired output');
			1;
		])
	{
		fail($test_name);
		diag($@);
	}
	else {
		pass($test_name);
	}
}

done_testing;
