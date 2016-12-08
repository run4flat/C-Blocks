# Run with perl rng/rng.pl | tee rng/rng.txt
# plot with perl plot-bench.pl rng/rng.txt
use strict;
use warnings;

# Speed tabulations:
# sfssssssssssssssssffssssssssfsfsfs

use File::Path qw(remove_tree);
END {
	# Keep things from getting messy
	remove_tree('_Inline');
}

BEGIN { print "Compiling...\n" }
print "Here we go!\n";
use C::Blocks;
use Inline 'C';
use C::Blocks::Types qw(uint);
use Time::HiRes qw(time);

my uint $N;
my $a = 698769069;
my ($x, $y, $z, $c) = (123456789, 362436000, 521288629, 7654321);
my $reps = 10;
for my $log_n (1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5, 5.5) {
	$N = int(10**$log_n);
	print "--- For N = $N ---\n";
	
	my ($cblocks_result, $inline_result, $perl_result, $start);
	my ($cblocks_duration, $inline_duration, $perl_duration) = (0, 0, 0);
	for (1 .. $reps) {
		# Time a single C::Blocks call
		my $start = time;
		$cblocks_result = c_blocks_rng();
		$cblocks_duration += time() - $start;
		# Inline::C
		$start = time;
		$inline_result = Inline_rng();
		$inline_duration += time() - $start;
		# Pure Perl
		$start = time;
		$perl_result = Perl_rng();
		$perl_duration += time() - $start;
		# Check for consistency
		if ($cblocks_result != $inline_result
			and $perl_result != $inline_result
			and $cblocks_result != $perl_result)
		{
			print "No agreement! C::Blocks gave $cblocks_result, Inline gave $inline_result, Perl gave $perl_result\n";
		}
		elsif ($cblocks_result != $inline_result and $cblocks_result != $perl_result) {
			print "C::Blocks result ($cblocks_result) disagrees with Perl and Inline ($inline_result)\n";
		}
		elsif ($cblocks_result != $inline_result) {
			print "Inline result ($inline_result) disagrees with Perl and C::Blocks ($perl_result)\n";
		}
	}
	
	print "CBlocks: $cblocks_duration wallclock seconds\n";
	print " Inline: $inline_duration  wallclock seconds\n";
	print "   Perl: $perl_duration  wallclock seconds\n";
}


sub Perl_rng {
	my $rand;
	for (1 .. $N) {
		my $t;
		$x = 69069*$x+12345;
		$y ^= ($y<<13); $y ^= ($y>>17); $y ^= ($y<<5); 
		$t = $a*$z+$c; $c = ($t>>32);
		$z = $t;
		$rand = $x+$y+$z;
	}
	return $rand;
}

{
	my uint ($x, $y, $z, $c);
	sub c_blocks_rng {
		($x, $y, $z, $c) = (123456789, 362436000, 521288629, 7654321)
			if not defined $x;
		my uint $to_return = 0;
		cblock {
			for (int i = 0; i < $N; i++) {
				unsigned long long t, a = 698769069ULL;
				$x = 69069*$x+12345;
				$y ^= ($y<<13); $y ^= ($y>>17); $y ^= ($y<<5); 
				t = a*$z+$c; $c = (t>>32);
				$to_return = $x+$y+($z=t);
			}
		}
		return $to_return;
	}
}

sub Inline_rng {
	inl_rng($N);
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

	unsigned int inl_rng(unsigned int N) {
		int i;
		unsigned int to_return;
		for (i = 0; i < N; i++) to_return = inline_KISS();
		return to_return;
	}
