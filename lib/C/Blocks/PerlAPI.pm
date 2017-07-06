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
our @ISA = qw( DynaLoader );
use C::Blocks ();
*import = \&C::Blocks::load_lib;

our $VERSION = '0.42';
bootstrap C::Blocks::PerlAPI $VERSION;
$VERSION = eval $VERSION;

1;

__END__

=head1 NAME

C::Blocks::PerlAPI - C interface for interacting with Perl

=head1 SYNOPSIS

 # implicitly loaded with C::Blocks:
 use C::Blocks;
 
 cshare {
     void say_hi() {
         PerlIO_stdoutf("hi!");
     }
 }
 
 # Can be explicitly not loaded with C::Blocks via
 use C::Blocks -noPerlAPI;
 
 # Can later be explicitly loaded via
 use C::Blocks::PerlAPI;


=head1 DESCRIPTION

This C::Blocks module provides access to the Perl C library. The Perl C
library includes most of the C standard library, and so is a convenient
means for pulling in that functionality.

Originally the PerlAPI was not loaded automatically, except when a
sigiled variable was detected. It has become clear that the presence of
the PerlAPI is the rule, not the exception. As such, it is automatically
loaded when you C<use C::Blocks>, unless you explicitly request it not
load with C<use C::Blocks -noPerlAPI>.

Using C::Blocks::PerlaPI is roughly equivalent to including these lines
at the top of your cblocks:

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
