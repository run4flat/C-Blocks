# This is a customized benchmark that compares prime number calculation
# by C::Blocks and Inline::C.

use strict;
use warnings;

use File::Path qw(remove_tree);
END {
	# Keep things from getting messy
	remove_tree('_Inline');
}

use C::Blocks;
use C::Blocks::PerlAPI;
use Inline 'C';

# First, our C::Blocks function to perform the prime number calculation.
# The Inline::C version is given below, a copy of this one.
clex {
	
	/* Note: no need for aTHX_ because Newx and Safefree do not need
	 * them. */
	int get_Nth_prime(int n) {
		/* Set up variables */
		int i, j, candidate, sqrt_candidate, N_found;
		int * prime_list;
		Newx(prime_list, n, int);
		
		/* Always start with 2 */
		prime_list[0] = 2;
		candidate = 1; /* so that with increment, it'll go to 3 */
		N_found = 1;
		
		/* mostly equivalent to Perl code above */
		NEXT_CANDIDATE: while(N_found < n) {
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
		
		/* Clean up memory and set the to-return variable based on the
		 * last candidate */
		Safefree(prime_list);
		return candidate;
	}
}

sub c_blocks_sub_Nth_prime {
	my $N = shift;
	my $to_return;
	cblock { sv_setiv($to_return, get_Nth_prime(SvIV($N))); }
	return $to_return;
}

use Time::HiRes qw(gettimeofday tv_interval);

my $N_iterations = 1000;
for my $log_N (1, 1.5, 2, 2.5, 3, 3.5, 4) {
	my $N = int(10**$log_N);
	print "--- N = $N ---\n";
	
	# C::Blocks test
	my $C_Blocks_accum = 0;
	my $C_Blocks_result;
	for (1 .. $N_iterations) {
		my $t0 = [gettimeofday];
		cblock { sv_setiv($C_Blocks_result, get_Nth_prime(SvIV($N))); }
		my $ellapsed = tv_interval ($t0);
		$C_Blocks_accum += $ellapsed;
	}
	my $C_Blocks_time = $C_Blocks_accum / $N_iterations;
	
	# C::Blocks sub test
	my $C_Blocks_sub_accum = 0;
	my $C_Blocks_sub_result;
	for (1 .. $N_iterations) {
		my $t0 = [gettimeofday];
		$C_Blocks_sub_result = c_blocks_sub_Nth_prime($N);
		my $ellapsed = tv_interval ($t0);
		$C_Blocks_sub_accum += $ellapsed;
	}
	my $C_Blocks_sub_time = $C_Blocks_sub_accum / $N_iterations;
	
	# Inline::C test
	my $Inline_C_accum = 0;
	my $Inline_C_result;
	for (1 .. $N_iterations) {
		my $t0 = [gettimeofday];
		$Inline_C_result = get_Nth_prime($N);
		my $ellapsed = tv_interval ($t0);
		$Inline_C_accum += $ellapsed;
	}
	my $Inline_C_time = $Inline_C_accum / $N_iterations;
	
	print "C::Blocks/sub took $C_Blocks_sub_accum seconds, $C_Blocks_sub_time on average\n";
	print "C::Blocks took $C_Blocks_accum seconds, $C_Blocks_time on average\n";
	print "Inline::C took $Inline_C_accum seconds, $Inline_C_time on average\n";
	print "C::Blocks gave $C_Blocks_result; C::Blocks/sub gave $C_Blocks_sub_result; Inline::C gave $Inline_C_result\n";
}

__END__

__C__

	int get_Nth_prime(int n) {
		/* Set up variables */
		int i, j, candidate, sqrt_candidate, N_found;
		int * prime_list;
		Newx(prime_list, n, int);
		
		/* Always start with 2 */
		prime_list[0] = 2;
		candidate = 1; /* so that with increment, it'll go to 3 */
		N_found = 1;
		
		/* mostly equivalent to Perl code above */
		NEXT_CANDIDATE: while(N_found < n) {
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
		
		/* Clean up memory and set the to-return variable based on the
		 * last candidate */
		Safefree(prime_list);
		return candidate;
	}
