########################################################################
             package C::Blocks::Filter::BlockArrowMethods;
########################################################################

use strict;
use warnings;
use C::Blocks::Filter ();
our @ISA = qw(C::Blocks::Filter);

sub c_blocks_filter {
	s/(\w+)=>(\w+)\(\)/$1->methods->$2($1)/g;
	s/(\w+)=>(\w+)\(/$1->methods->$2($1, /g;
}

1;

__END__

=head1 NAME

C::Blocks::Filter::BlockArrowMethods - invoke methods succinctly

=head1 SYNOPSIS

 use strict;
 use warnings;
 use C::Blocks;
 use C::Blocks::Filter::BlockArrowMethods;
 
 cblock {
	 /* These are equivalent */
     a=>some_thing(arg1, arg2);
     a->methods->some_thing(a, arg1, arg2);
 }

=head1 DESCRIPTION

When invoking methods on vtable-based classes, you need to extract the 
method by dereferencing the vtable, and then you have to pass the 
object as the first argument of the method. If the vtable pointer is 
registered under the name C<methods>, you might invoke the method
C<some_action> as

 obj->methods->some_action(obj, other, args);

The C<C::Blocks::Filter::BlockArrowMethods> filter would let you use the
following more succinct statement:

 obj=>some_action(other, args);

This would be converted to the previous more verbose example.

