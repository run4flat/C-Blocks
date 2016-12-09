########################################################################
                       package C::Blocks::Filter;
########################################################################

use strict;
use warnings;
our $VERSION = '0.41_01';
$VERSION = eval $VERSION;

# Any filter will need to add itself to the list of filters. These
# methods can be inherited by other filters so they can focus on the
# actual filtering, and not worry about the import/unimport.
sub import {
	# Get the name of the module that is being imported.
	my ($package, @filters) = @_;
	if (@filters == 0 or $package ne __PACKAGE__) {
		# add the package to the list of filters
		$^H{"C::Blocks/filters"} .= "$package|";
	}
	for my $filter (@filters) {
		if (ref($filter)) {
			warn("C::Blocks does not support references as filters");
		}
		else {
			$^H{"C::Blocks/filters"} .= "$filter|";
		}
	}
}

sub unimport {
	# Get the name of the module that is being unimported.
	my ($package) = @_;
	
	# remove the package from the list of filters
	$^H{"C::Blocks/filters"} =~ s/$package\|//;
}

sub c_blocks_filter {
	print '#' x 50,
		"\n$_\n",
		'#' x 50,
		"\n";
}

1;

__END__

=head1 NAME

C::Blocks::Filter - base package for writing filters for C::Blocks

=head1 SYNOPSIS

If you want to see the actual code sent to the compiler, apply this
module at the command-line:
 
 $ perl -MC::Blocks::Filter your-script.pl

Or include it in your script:

 use strict;
 use warnings;
 use C::Blocks;
 use C::Blocks::Filter;
 
 cblock {
     ... /* this code will be printed */
 }

You can apply your own filter function:

 # Replace loop {} with while(1) {}
 sub my_filter {
     s/loop/while(1)/g;
 }
 use C::Blocks::Filter qw(&my_filter);
 
 cblock {
     loop {
         ... infinite loop code...
         ... hopefully you have a break in here somewhere
     }
 }

Or you can write your own filter module:

 package My::Filter;
 use C::Blocks::Filter ();
 our @ISA = qw(C::Blocks::Filter); # for import/unimport
 
 # Your module must include this function:
 sub c_blocks_filter {
     s/loop/while(1)/g;
 }

You can then use that module:

 use strict;
 use warnings;
 use C::Blocks;
 use My::Filter;
 
 cblock {
     int i;
     for (i = 0; i < 10; i++) {
         printf("i = %d\n", i);
     }
     loop {
         i++;
         printf("i = %d\n", i);
         if (i > 20) break;
     }
 }

=head1 DESCRIPTION

L<C::Blocks> supports lexically-scoped source filters. This module makes
it easy to install source filters and write modules that serve as
source filters.

Source filters are called without any arguments. The C code to be
filtered is simply in C<$_>, and the filter function should modify the
contents of C<$_> directly. Any return value from the filter function
will be ignored.

=head2 Writing a one-time filter

The simplest way to write a filter is to create a C<sub> that modifies
the contents of C<$_> however you want. Then, you install the filter
by passing the string C<&your_filter_funcion> as an argument to 
C<use C::Blocks::Filter>. The ampersand is important! An example is
given in the synopsis with C<my_filter>.

One caveat with this approach: the sub must be I<defined> before the
L<C::Blocks> block that uses it. The reason for this is that the funcion
is called at code compile time. If your function is defined below the
block, it will not have been compiled by the time it is needed. Unless
you are using string evals, this means it needs to be defined "above"
your block, or in some module that is C<use>d before your block.

=head2 Writing a reusable filter

If you want to write a filter that can be easily used in many different
modules or scripts, it is easiest to create a filter module. Such a
module needs to have an import method that correctly adds the package to
the L<C::Blocks> list of filter packages. The specific symantics are
still subject to change, so the best future-proof way to do this is to
have your filter module inherit from C::Blocks::Filter. Other than that,
you simply need to provide a C<c_blocks_filter> sub in your module. Note
that your module must contain this function; it cannot inherit it from
a parent module.
