########################################################################
                       package C::Blocks::Filter;
########################################################################

use strict;
use warnings;

# Any filter will need to add itself to the list of filters. These
# methods can be inherited by other filters so they can focus on the
# actual filtering, and not worry about the import/unimport.
sub import {
	# Get the name of the module that is being imported.
	my ($package) = @_;
	
	# add the package to the list of filters
	$^H{"C::Blocks/filters"} .= "$package|";
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

 # If you want to print out the code as it is sent
 # to the C compiler:
 
 use strict;
 use warnings;
 use C::Blocks;
 use C::Blocks::Filter;
 
 cblock {
     ... /* this code will be printed */
 }
 
 
 # If you want to write your own filter
 
 package My::Filter;
 use C::Blocks::Filter ();
 our @ISA = qw(C::Blocks::Filter);
 
 sub c_blocks_filter {
     # Modify $_ directly. Allow a new 'keyword'
     # called 'loop':
     s/loop/for/g;
 }
 
 # Then in another bit of code using this:
 use strict;
 use warnings;
 use C::Blocks;
 use My::Filter;
 
 cblock {
     int i;
     for (i = 0; i < 10; i++) {
         printf("i = %d\n", i);
     }
     loop (i = 0; i < 10; i++) {
         printf("i = %d\n", i);
     }
 }
