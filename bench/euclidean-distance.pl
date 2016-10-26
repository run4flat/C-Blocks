use strict;
use warnings;

use C::Blocks;
use PDL;
BEGIN { delete $main::{double} }
use C::Blocks::Types qw(double double_array);
use Benchmark qw(timethese :hireswallclock);

# Generate some data
my (@data, $pdl_data, $N);
my double_array $packed_data;
for my $log_n (1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7) {
	$N = 10**$log_n;
	print "--- For N = $N ---\n";
	
	my @data = map { rand() } 1 .. $N;
	$pdl_data = pdl(\@data);
	$packed_data = pack('d*', @data);
	
	timethese(1000, {  PDL => \&pdl_euclid, CBlocks => \&c_blocks_euclid});
	print "PDL returned ", pdl_euclid(), " and c_blocks_avg returned ",
		c_blocks_euclid(), "\n";
}

sub pdl_euclid {
	return sqrt(sum($pdl_data*$pdl_data));
}

sub c_blocks_euclid {
	my double $sum = 0;
	cblock {
		for (int i = 0; i < array_length($packed_data); i++) {
			$sum += $packed_data[i] * $packed_data[i];
		}
	}
	return sqrt($sum);
}
