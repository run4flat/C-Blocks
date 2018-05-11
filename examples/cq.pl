use strict;
use warnings;
use C::Blocks;

sub salutation_filter {
	s/Hello/Goodbye/g;
}
use C::Blocks::Filter qw(&salutation_filter);

print "Here is a block of C code\n[", cq { printf("Hello!\n"); }, "]\n";

my $code = cq {
	Foo
	${
		cq {
			Bar
		}
	}Baz
};

print "funny code is [$code]\n";
