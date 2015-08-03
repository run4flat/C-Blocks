use strict;
use warnings;

use C::Blocks;
use C::Blocks::PerlAPI;
use PDL;
use Benchmark qw(timethese :hireswallclock);

# Generate some data
my ($pdl_data, $packed_data, $N);
for my $log_n (1, 2, 3, 4, 5, 6) {
	$N = 10**$log_n;
	print "--- For N = $N ---\n";
	
	my @data = map { rand() } 1 .. $N;
	$pdl_data = pdl(\@data);
	$packed_data = pack('d*', @data);
	
	timethese(1000, {  PDL => \&pdl_euclid, CBlocks => \&c_blocks_euclid});
}

sub pdl_euclid {
	return sqrt(sum($pdl_data*$pdl_data));
}

sub c_blocks_euclid {
	my $to_return;
	cblock {
		double accum = 0;
		int i, N_data;
		double * data;
		
		data = (double*)(SvPVbyte_nolen($packed_data));
		N_data = SvIV($N);
		for (i = 0; i < N_data; i++) {
			accum += data[i] * data[i];
		}
		sv_setnv($to_return, sqrt(accum));
	}
	return $to_return;
}