# Ensures that sigiled variables are correctly interpolated into the
# compiling context.
use strict;
use warnings;
use Test::More;

# Load cblocks and PerlAPI
use C::Blocks;
use C::Blocks::PerlAPI;


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

# Dollar-signs can be carefully wrapped
eval q{
	my $shuttle = undef;
	cblock {
		sv_setpv($shuttle, "$""money");
	}
	BEGIN{ pass 'Can carefully wrap dollar signs in C code' }
	is($shuttle, '$money', 'Successfully set string with dollar sign in it');
	1;
} or do {
	fail 'Can carefully wrap dollar signs in C code';
	diag($@);
};

# C variable names can be identical to Perl variable names
eval q{
	my ($N, $N_times_2);
	$N = int(rand(50));
	cblock {
		int N = SvIV($N);
		sv_setiv($N_times_2, 2 * N);
	}
	is($N_times_2, 2 * $N, 'C variable names can be identical to Perl variable names')
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

done_testing;
