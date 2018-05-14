use strict;
use warnings;
use C::Blocks;

sub salutation_filter {
	s/Hello/Goodbye/g;
}
use C::Blocks::Filter qw(&salutation_filter);

print "Here is a block of C code\n[", cq { printf("Hello!\n"); }, "]\n";

my $var = 'Foo';

my $code = cq {
	Foo
	interpolated: "$var"
	Escapes: "\n"
};

print "funny code is [$code]\n";

print '-' x 20, "\n";

#line 1 cq.pl
my $func_name = 'sum';
my $op = '+';
my $code = cq {
    printf("Performing '$func_name'\n");
    RESULT = a $op b;
};
print "Code is [$code]\n";
