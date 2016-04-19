use strict;
use warnings;
use C::Blocks;
use C::Blocks::PerlAPI;

csub csum {
  /* get "items" variable, and stack pointer variables used by ST() */
  dXSARGS;

  int i;
  double sum = 0.;
  
  /* Sum the given numeric values. */
  for (i = 0; i < items; ++i) sum += SvNV( ST(i) );
  
  /* Prepare stack to receive return values. */
  XSprePUSH;
  /* Push the sum onto the return stack */
  mXPUSHn(sum);
  /* Indicate we're returning a single value on the stack. */
  XSRETURN(1);
}

my $limit = shift || 5;

my $return = csum(1 .. $limit);
print "sum of 1 to $limit is $return\n";
