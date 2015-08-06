use strict;
use warnings;

use C::Blocks;
use C::Blocks::PerlAPI;
use Benchmark qw(timethese :hireswallclock);

# Generate some data
my $N;
for my $log_n (1, 2, 3, 4, 5, 6) {
	$N = 10**$log_n;
	print "--- For N = $N ---\n";
	
	timethese(1000, {
		perl_allocate => \&perl_alloc,
		perl_push => \&perl_push,
		perl_map => \&perl_map,
		CBlocks_allocate => \&c_blocks_alloc,
#		CBlocks_push => \&c_blocks_push,
	});
}

# Push N zeros onto an array
sub perl_push {
	my @array;
	push (@array, 0) for 1 .. $N;
}

sub perl_map {
	my @array = map { 0 } (1 .. $N);
}

sub perl_alloc {
	my @array;
	$#array = $N - 1;
	$array[$_] = 0 foreach (0 .. $N - 1);
}

sub c_blocks_alloc {
	my @array;
	cblock {
		int i;
		int N = SvIV($N);
		
		/* Dereference to get the original array */
		av_extend(@array, N);
		
		for (i = 0; i < N; i++) {
			sv_setiv(*(av_fetch(@array, i, 1)), 0);
		}
	}
}

#sub c_blocks_push {
#}
