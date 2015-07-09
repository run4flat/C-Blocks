use strict;
use warnings;

package C::Blocks::libperl;

BEGIN {
	print "About to load libperl\n";
}

use C::Blocks;
use ExtUtils::Embed;
use Carp;

# Provide functions and macros from libperl

BEGIN {
	# Utilize ExtUtils::Embed to get some build info
	$C::Blocks::compiler_options = join(' ', ccopts, ldopts);
	
	# tcc doesn't know how to use quotes in -I paths; remove them if found.
	$C::Blocks::compiler_options =~ s/-I"([^"]*)"/-I$1/g if $^O =~ /MSWin/;
	
	# Scrub all linker (-Wl,...) options
	$C::Blocks::compiler_options =~ s/-Wl,[^\s]+//g;
}

cshare {
	#ifdef PERL_DARWIN
		typedef unsigned short __uint16_t, uint16_t;
		typedef unsigned int __uint32_t, uint32_t;
		typedef unsigned long __uint64_t, uint64_t;
	#elif defined WIN32
		#define __C89_NAMELESS __extension__
		#define __MINGW_EXTENSION __extension__
		typedef long uid_t;
		typedef long gid_t;
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
