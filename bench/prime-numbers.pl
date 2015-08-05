# This calculates the first N prime numbers.

use strict;
use warnings;

use C::Blocks;
use C::Blocks::PerlAPI;
use Benchmark qw(timethese :hireswallclock);

# Generate some data
my ($N, $printout);
$printout = 0;
for my $log_n (1, 1.5, 2, 2.5, 3) {
	$N = int(10**$log_n);
	print "--- For N = $N ---\n";
	
	timethese(1000, {
		perl_primes => \&perl_primes,
		CBlocks_primes => \&c_blocks_primes,
	});
	$printout = 1 if $log_n == 2;
	print "Perl function gave ", perl_primes(), " and C::Blocks function gave ",
		c_blocks_primes(), "\n";
	$printout = 0;
}

# Finds the Nth prime
sub perl_primes {
	my @primes = (2);
	my $candidate = 1; # so that with increment, it'll go to 3
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
	print "Perl primes: @primes\n" if $printout;
	return $primes[-1];
}

sub c_blocks_primes {
	my $to_return;
	cblock {
		/* Set up variables */
		int N = SvIV($N);
		int i, j, candidate, sqrt_candidate, N_found;
		int * prime_list;
		Newx(prime_list, N, int);
		
		/* Always start with 2 */
		prime_list[0] = 2;
		candidate = 1; /* so that with increment, it'll go to 3 */
		N_found = 1;
		
		/* mostly equivalent to Perl code above */
		NEXT_CANDIDATE: while(N_found < N) {
			candidate += 2;
			sqrt_candidate = sqrt(candidate);
			for (j = 0; j < N_found; j++) {
				int curr_prime = prime_list[j];
				if (sqrt_candidate < curr_prime) {
					/* if none of the primes below sqrt_candidate divide
					 * into it, it must be prime. */
					prime_list[N_found] = candidate;
					N_found++;
					goto NEXT_CANDIDATE;
				}
				
				/* if curr_prime divides evenly into the candidate, then
				 * the candidate is not prime. */
				if ((double)candidate / (double)curr_prime
					== (double)(candidate / curr_prime)) break;
			}
			/* Not a prime, move on to the next */
		}
		
		if (SvIV($printout)) {
			printf("C::Blocks primes: ");
			for (i = 0; i < N-1; i++) printf("%d ", prime_list[i]);
			printf("%d\n", candidate);
		}
		
		/* Clean up memory and set the to-return variable based on the
		 * last candidate */
		Safefree(prime_list);
		sv_setiv($to_return, candidate);
	}
	return $to_return;
}
