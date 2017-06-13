=head1 NAME

sos-02-refcount-inc.pl - make sure SOS01 refcounting works as expected

=head1 QUESTION

I wanted to test the reference counting more thoroughly. This required
a new function, discussed and implemented in L<SOS02>. Now we can check
C-side reference counting, too.

=cut

use strict;
use warnings;
use C::Blocks;
use SOS01;
use SOS02;
use C::Blocks::Filter::BlockArrowMethods;

clex {
	SOS01 c_self;
}

# Create a Perl-side copy
print "=== creating object ===\n";
my $thing = SOS01->new;

# Create a C-side copy in a global variable
print "=== creating C-side copy ===\n";
cblock {
	c_self = SOS01::Magic::obj_ptr_from_SV_ref(aTHX_ $thing);
	c_self=>refcount_inc();
}

print "=== getting rid of Perl-side copy ===\n";
undef $thing;

print "=== getting rid of C-side copy ===\n";
cblock {
	c_self=>refcount_dec();
}

print "All done!\n";

=head1 RESULTS

Whereas F<sos-01-create-destroy.pl> exercises the basic creation and 
destruction behavior from Perl code, F<sos-02-refcount-inc.pl> 
exercises reference counting directly on the C representation. 
Achieving that required this module to implement the mapping from SV -> 
SOS01 pointer, implemented in L<SOS02>.

The results are wonderfully satisfying. Undefining the Perl-side 
variable does not lead to the destruction of the object so long as the 
reference count is held up by the C pointer. This is evidenced by the 
lack of anything printed between "getting rid of Perl-side copy" and
"getting rid of C-side copy".

