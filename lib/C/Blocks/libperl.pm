use strict;
use warnings;

package C::Blocks::libperl;

BEGIN {
	print "About to load libperl\n";
}

use C::Blocks;
use Config;
use File::Spec;
use Carp;

# Provide functions and macros from libperl

BEGIN {
	# Find the header files
	my $perl_inc_location = File::Spec->catfile($Config{archlib}, 'CORE');
	croak("Your Perl header files are onstensibly located at [$perl_inc_location] but I could not find that directory!")
		unless -d $perl_inc_location;
	croak("Could not find perl.h where I expected to see it [$perl_inc_location]")
		unless -f File::Spec->catfile($perl_inc_location, 'perl.h');
	# Good to go with that, so add that directory as an include dir
	$C::Blocks::compiler_options .= " -I$perl_inc_location ";
	
	# Can we find the shared library?
	my $shared_location = File::Spec->catfile($perl_inc_location, $Config{libperl});
	if (not -f $shared_location) {
		# Try a guess for linux
		$shared_location = (glob('/usr/lib/libperl.so*'),
			glob('/usr/lib/libperl.a*'))[0] if $^O eq 'linux';
		
		# check if our new guesses are correct
		croak('Unable to find libperl') unless -f $shared_location;
	}
	
	$C::Blocks::library_to_link = $shared_location;
}

cshare {
	#ifdef _C_BLOCKS_OS_darwin
		typedef unsigned short __uint16_t, uint16_t;
		typedef unsigned int __uint32_t, uint32_t;
		typedef unsigned long __uint64_t, uint64_t;
	#endif
	
	#define PERL_NO_GET_CONTEXT
	#include "EXTERN.h"
	#include "perl.h"
	#include "XSUB.h"
}

print "All done loading libperl\n";

1;

__END__

=head1 NAME

C::Blocks::libperl - C interface for interacting with Perl

=head1 SYNOPSIS

 use strict;
 use warnings;
 use C::Blocks;
 use C::Blocks::libperl;
 
 cshare {
     void say_hi() {
         PerlIO_stdoutf("hi!");
     }
 }

=head1 DESCRIPTION

This C::Blocks module provides access to the Perl C library. It is roughly
equivalent to including these lines at the top of your cblocks:

 #define PERL_NO_GET_CONTEXT
 #include "EXTERN.h"
 #include "perl.h"
 #include "XSUB.h"

as well as linking to F<libperl>. Of course, as a C::Blocks module, it also
avoids the re-parsing necessary if you were to include those at the top of each
of your cblocks.

The Perl C library is vast, and a tutorial for it may be useful at some point.
Until that time, I will simply refer you to L<perlapi> and L<perlguts>.

=cut
