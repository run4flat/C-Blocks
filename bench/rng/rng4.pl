# Run with perl rng/rng.pl | tee rng/rng.txt
# plot with perl plot-bench.pl rng/rng.txt
use strict;
use warnings;

use C::Blocks;
use Inline 'C';
use C::Blocks::Types qw(uint);
use Benchmark qw(:hireswallclock cmpthese);

my uint $N;
my $a = 698769069;
my ($x, $y, $z, $c) = (123456789, 362436000, 521288629, 7654321);
my $reps = 10;
for my $log_n (1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5) {
	$N = int(10**$log_n);
	print "--- For N = $N ---\n";
	cmpthese(-1, { Inline => \&Inline_rng, CBlocks => \&c_blocks_rng,
			Perl => \&Perl_rng});
}

sub Perl_rng {
	my $rand;
	for (1 .. $N) {
		my $t;
		$x = 69069*$x+12345;
		$y ^= ($y<<13); $y ^= ($y>>17); $y ^= ($y<<5); 
		$t = $a*$z+$c; $c = ($t>>32);
		$z = $t;
		$rand = $x+$y+$z;
	}
	return $rand;
}

clex {
	/* Note: y must never be set to zero;
	 * z and c must not be simultaneously zero */
	unsigned int x = 123456789,y = 362436000,
		z = 521288629,c = 7654321; /* State variables */
	
	unsigned int KISS() {
		unsigned long long t, a = 698769069ULL;
		x = 69069*x+12345;
		y ^= (y<<13); y ^= (y>>17); y ^= (y<<5); 
		t = a*z+c; c = (t>>32);
		return x+y+(z=t);
	}
}

sub c_blocks_rng {
	my uint $to_return = 0;
	cblock {
		for (int i = 0; i < $N; i++) $to_return = KISS();
	}
	return $to_return;
}

sub Inline_rng {
	inl_rng($N);
}

__END__

__C__

	/* Note: y must never be set to zero;
	 * z and c must not be simultaneously zero */
	static unsigned int x = 123456789,y = 362436000,
		z = 521288629,c = 7654321; /* State variables */
	
	unsigned int inline_KISS() {
		unsigned long long t, a = 698769069ULL;
		x = 69069*x+12345;
		y ^= (y<<13); y ^= (y>>17); y ^= (y<<5); 
		t = a*z+c; c = (t>>32);
		return x+y+(z=t);
	}

	unsigned int inl_rng(unsigned int N) {
		int i;
		unsigned int to_return;
		for (i = 0; i < N; i++) to_return = inline_KISS();
		return to_return;
	}
