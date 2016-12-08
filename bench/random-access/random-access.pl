# Run with perl random-access/random-access.pl | tee random-access/results.txt
# plot with perl plot-bench.pl random-access/results.txt
use strict;
use warnings;

use File::Path qw(remove_tree);
END {
	# Keep things from getting messy
	remove_tree('_Inline');
}

BEGIN { print "Compiling...\n" }
print "Here we go!\n";
use C::Blocks;
use Inline 'C';
use C::Blocks::Types qw(uint Int int_array);
use Time::HiRes qw(time);

my uint $N;
my int_array $random_data;
vec($random_data, 100_000_000, 32) = 0;
setup_random_data();
my $reps = 100;
for my $log_n (1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6) {
	$N = int(10**$log_n);
	print "--- For N = $N ---\n";
	my ($cblocks_result, $inline_result, $start);
	my $cblocks_duration = 0;
	my $inline_duration = 0;
	for (1 .. $reps) {
		# Time a single C::Blocks call
		my $start = time;
		$cblocks_result = c_blocks_rng();
		$cblocks_duration += time() - $start;
		$start = time;
		$inline_result = Inline_rng();
		$inline_duration += time() - $start;
		if ($cblocks_result != $inline_result) {
			print "For cblocks I got $cblocks_result but for inline I got $inline_result\n";
		}
	}
	print "CBlocks: $cblocks_duration wallclock seconds\n";
	print " Inline: $inline_duration  wallclock seconds\n";
}

sub Inline_rng {
	inl_rng($N, $random_data);
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

sub setup_random_data {
	cblock {
		for (int i = 0; i < 100000000; i++) {
			if (KISS() > 2147483646) {
				$random_data[i] = 1;
			}
			else {
				$random_data[i] = -1;
			}
		}
		
		/* reset state */
		x = 123456789, y = 362436000, z = 521288629, c = 7654321;
	}
}

sub c_blocks_rng {
	my Int $to_return = 0;
	cblock {
		for (int i = 0; i < $N; i++) {
			$to_return += $random_data[KISS() % 100000000];
		}
	}
	return $to_return;
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

	int inl_rng(unsigned int N, char * random_data_) {
		int i;
		int * random_data = (int*)random_data_;
		int to_return = 0;
		for (i = 0; i < N; i++) {
			to_return += random_data[inline_KISS() % 100000000];
		}
		return to_return;
	}
