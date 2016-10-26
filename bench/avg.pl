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
for my $log_n (1, 2, 3, 4, 5, 6, 7) {
	$N = 10**$log_n;
	print "--- For N = $N ---\n";
	
	@data = map { rand() } 1 .. $N;
	$pdl_data = pdl(\@data);
	$packed_data = pack('d*', @data);
	
	timethese(1000, {  PDL => \&pdl_avg, CBlocks => \&c_blocks_avg, Perl => \&perl_avg});
	print "PDL returned ", pdl_avg(), " and c_blocks_avg returned ",
		c_blocks_avg(), "\n";
}

sub pdl_avg {
	return $pdl_data->avg;
}

sub perl_avg {
	my $sum = 0;
	$sum += $_ foreach @data;
	return $sum / @data;
}

sub c_blocks_avg {
	my double $sum = 0;
	cblock {
		for (int i = 0; i < array_length($packed_data); i++) {
			$sum += $packed_data[i];
		}
	}
	return $sum / $N;
}
