# This benchmark is taken from XS::TCC's author tools example script.
# It does not compare C::Blocks to XS::TCC, however.

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
		perl_math => \&perl_math,
		CBlocks_math => \&c_blocks_math,
	});
	print "Perl version returned ", perl_math(), " and C::Blocks version returned ",
		c_blocks_math(), "\n";
}

sub perl_math {
	my $n = $N;
	--$n;
	my $res = 0;
	for my $i (0..$n) {
		$res += $i / ($_ == 0 ? 1 : $_) for 0..$n;
	}
	return $res;	
}

sub c_blocks_math {
	my $to_return;
	cblock {
		int i, j;
		int n = SvIV($N);
		double ans;
		
		for (i = 0; i < n; i++) {
			for (j = 0; j < n; j++) {
				ans += i / (double)(j == 0 ? 1 : j);
			}
		}
		sv_setnv($to_return, ans);
	}
	return $to_return;
}
