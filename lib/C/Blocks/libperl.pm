use strict;
use warnings;

package C::Blocks::libperl;

BEGIN {
	print "About to load libperl\n";
}

use C::Blocks;
use Config;
use File::Spec;

# Provide functions and macros from libperl

BEGIN {
	my $perl_inc_location = File::Spec->catfile($Config{archlib}, 'CORE');
	$C::Blocks::compiler_options = "-Wall -I$perl_inc_location";
	$C::Blocks::library_to_link = File::Spec->catfile($perl_inc_location, $Config{libperl});;
}

cshare {
	/* For Macs */
	typedef unsigned short __uint16_t, uint16_t;
	typedef unsigned int __uint32_t, uint32_t;
	typedef unsigned long __uint64_t, uint64_t;
	
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
