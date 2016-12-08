	# MyRNG.pm
	package MyRNG;
	use strict;
	use warnings;
	use C::Blocks;
	use C::Blocks::Types qw(uint);
	
	# Implement KISS random number generator, copy-and-pasted from
	# http://www0.cs.ucl.ac.uk/staff/d.jones/GoodPracticeRNG.pdf
	cshare {
		unsigned int x = 123456789,y = 362436000,
			z = 521288629,c = 7654321; /* State variables */
	    
		unsigned int KISS() {
			unsigned long long t, a = 698769069ULL;
			x = 69069*x+12345;
			y ^= (y<<13); y ^= (y>>17); y ^= (y<<5); 
			t = a*z+c; c = (t>>32);
			return x+y+(z=t);
		}
	}
	1;

