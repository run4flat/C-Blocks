use strict;
use warnings;

package C::Blocks::libperltemp;

# Figure out where the symbol table serialization file lives
use File::ShareDir;
use File::Spec;
our $symtab_file_location;
BEGIN {
	$symtab_file_location = File::Spec->catfile(
		File::ShareDir::dist_dir('C-Blocks'),'perltemp.h.cache'
	);
}

require DynaLoader;
our @ISA = qw( DynaLoader C::Blocks::libloader );

our $VERSION = '0.000_001';
bootstrap C::Blocks::libperltemp $VERSION;

1;

__END__

=head1 NAME

C::Blocks::libperltemp - temporary interface to some of Perl's C API

=head1 SYNOPSIS

 use strict;
 use warnings;
 use C::Blocks;
 use C::Blocks::libperltemp;
 
 cshare {
     void say_hi() {
         printf("hi!");
     }
 }

=head1 DESCRIPTION

This pre-alpha C::Blocks module provides access to selected functions
from Perl's C API. Presently, some of the functions provided by libperl
lead to segmentation faults, for reasons I do not understand. This
module is designed as a stop-gap until the bugs in tcc and C::Blocks are
ironed out.

The linker checks each symbol table in order of inclusion. This means
that you can use this in combinaton with C::Blocks::libperl as long as
you C<use> it before you C<use> libperl:

 use C::Blocks::libperltemp;
 use C::Blocks::libperl;

=head1 FUNCTIONS

This modules provides Newx, Newxc, Newxz, Renew, Renewc, Safefree, croak,
and printf.

=cut
