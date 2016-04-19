use strict;
use warnings;
use C::Blocks;
use C::Blocks::PerlAPI;

csub csum {
  /* Get the top "mark" offset from the stack of marks. */
  I32 ax = *PL_markstack_ptr--;
  /* PL_stack_base is the pointer to the bottom of the
   * argument stack. */
  SV **mark = PL_stack_base + ax;

  /* Local copy of the global Perl argument stack pointer.
   * This is the top of the stack, not the base! */
  SV **sp = PL_stack_sp;

  /* And finally, the number of parameters for this function. */
  I32 items = (I32)(sp - mark);

  int i;
  double sum = 0.;
  
  /* Move stack pointer back by number of arguments.
   * Basically, this means argument access by increasing index
   * in "first to last" order instead of access in
   * "last to first" order by using negative offsets. */
  sp -= items;

  /* Go through arguments (as SVs) and add their *N*umeric *V*alue to
   * the output sum. */
  for (i = 0; i < items; ++i)
    sum += SvNV( *(sp + i+1) ); /* sp+i+1 is the i-th arg on the stack */
  
  const IV num_return_values = 1;
  /* Make sure we have space on the stack (in case the function was
   * called without arguments) */
  if (PL_stack_max - sp < (ssize_t)num_return_values) {
    /* Oops, not enough space, extend. Needs to reset the
     * sp variable since it might have caused a proper realloc. */
    sp = Perl_stack_grow(aTHX_ sp, sp, (ssize_t)num_return_values);
  }

  /* Push return value on the Perl stack, convert number to Perl SV. */
  /* Also makes the value mortal, that is avoiding a memory leak. */
  *++sp = sv_2mortal( newSVnv(sum) );

  /* Commit the changes we've done to the stack by setting the global
   * top-of-stack pointer to our modified copy. */
  PL_stack_sp = sp;

  return;
}

my $return = csum(1 .. 5);
print "sum of 1 to 5 is $return\n";
