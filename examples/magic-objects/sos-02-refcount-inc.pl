# sos-02-refcount-inc.pl - make sure SOS01 refcounting works as expected
use strict;
use warnings;
use C::Blocks;
use SOS02;
use C::Blocks::Filter;
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
