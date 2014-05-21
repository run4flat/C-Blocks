use strict;
use warnings;

package C::Blocks::libperl;

BEGIN {
	print "About to load libperl\n";
}

use C::Blocks;
use ExtUtils::Embed;
use File::Spec;
use Config;
use Carp;

# Provide functions and macros from libperl

BEGIN {
	# Utilize ExtUtils::Embed to get some build info
	$C::Blocks::compiler_options = ccopts;
	
	# tcc doesn't know how to use quotes in -I paths; remove them if found.
	$C::Blocks::compiler_options =~ s/-I"([^"]*)"/-I$1/g if $^O =~ /MSWin/;
	
	# Finding the library is much trickier, and OS dependent
	my $shared_location;
	if ($^O =~ /MSWin/) {
		# the dll file is probably in the same directory as the interpreter
		my $perlbin_folder = $^X;
		$perlbin_folder =~ s/[^\\]+$//;
		# Look for something resembling a perl dll
		my @files = glob("$perlbin_folder*perl*.dll");
		carp("More than one perl-looking dll; taking first option: $files[0]")
			if @files > 1;
		croak('Unable to find libperl') unless @files;
		
		$shared_location = $files[0];
	}
	else {
		# Mine the EU::Embed linker options for library folders. Extract the
		# folders associated with "-L" flags
		my @linker_dirs = map { /^-L(.*)/ } split (/\s+/, ldopts);
		# Add a default option for linux
		push @linker_dirs, '/usr/lib' if $^O eq 'linux';
		# See if anything sticks
		for my $dir (@linker_dirs) {
			if (-f File::Spec->catfile($dir, $Config{libperl})) {
				$shared_location = File::Spec->catfile($dir, $Config{libperl});
				last;
			}
		}
		# make sure we found something
		croak('Unable to find libperl') unless $shared_location and -f $shared_location;
	}
		
	$C::Blocks::library_to_link = $shared_location;
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
