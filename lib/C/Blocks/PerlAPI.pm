use strict;
use warnings;

package C::Blocks::PerlAPI;

# Figure out where the symbol table serialization file lives
use File::ShareDir;
use File::Spec;
our $symtab_file_location;
BEGIN {
	$symtab_file_location = File::Spec->catfile(
		File::ShareDir::dist_dir('C-Blocks'),'perl.h.cache'
	);
}

require DynaLoader;
our @ISA = qw( DynaLoader C::Blocks::libloader );

our $VERSION = '0.40_02';
bootstrap C::Blocks::PerlAPI $VERSION;
$VERSION = eval $VERSION;

1;

__END__

=head1 NAME

C::Blocks::PerlAPI - C interface for interacting with Perl

=head1 SYNOPSIS

 use strict;
 use warnings;
 use C::Blocks;
 use C::Blocks::PerlAPI;
 
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
