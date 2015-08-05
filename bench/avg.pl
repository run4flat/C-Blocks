use strict;
use warnings;

use C::Blocks;
use C::Blocks::PerlAPI;
use PDL;
use Benchmark qw(timethese :hireswallclock);

# Generate some data
my ($pdl_data, $packed_data, $N);
for my $log_n (1, 2, 3, 4, 5, 6, 7) {
	$N = 10**$log_n;
	print "--- For N = $N ---\n";
	
	my @data = map { rand() } 1 .. $N;
	$pdl_data = pdl(\@data);
	$packed_data = pack('d*', @data);
	
	timethese(1000, {  PDL => \&pdl_avg, CBlocks => \&c_blocks_avg});
	print "PDL returned ", pdl_avg(), " and c_blocks_avg returned ",
		c_blocks_avg(), "\n";
}

sub pdl_avg {
	return $pdl_data->avg;
}

sub c_blocks_avg {
	my $to_return;
	cblock {
		double accum = 0;
		int i, N;
		double * data;
		
		data = (double*)(SvPVbyte_nolen($packed_data));
		N = SvIV($N);
		for (i = 0; i < N; i++) {
			accum += data[i];
		}
		sv_setnv($to_return, accum / N);
	}
	return $to_return;
}
