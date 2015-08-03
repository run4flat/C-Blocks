# This calculates the first N prime numbers.

use strict;
use warnings;

use C::Blocks;
use C::Blocks::PerlAPI;
use Benchmark qw(timethese :hireswallclock);

# Generate some data
my $N;
for my $log_n (1, 1.5, 2, 2.5, 3) {
	$N = int(10**$log_n);
	print "--- For N = $N ---\n";
	
	timethese(1000, {
		perl_primes => \&perl_primes,
		CBlocks_primes => \&c_blocks_primes,
	});
}

sub perl_primes {
	my @primes = (2);
	my $candidate = 3;
	CANDIDATE: while (@primes < $N) {
		$candidate += 2;
		my $sqrt_candidate = sqrt($candidate);
		PRIME: for my $prime (@primes) {
			last PRIME if $sqrt_candidate < $prime;
			my $div = $candidate / $prime;
			next CANDIDATE if $div == int($div);
		}
		# Out here means it's prime!
		push @primes, $candidate;
	}
}

sub c_blocks_primes {
	cblock {
	}
	return $to_return;
}
