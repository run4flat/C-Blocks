package TestType;
package main;

use strict;
use warnings;
use C::Blocks;
use C::Blocks::PerlAPI;
my TestType $foo;

cblock {
	printf("PL_compcv is 0x%p\n", PL_compcv);
	printf("Perl thinks this is ");
	if (!CvISXSUB(PL_compcv)) printf("not ");
	printf("an XSUB\n");
//	HV * stash = PadnameTYPE($foo);
//	printf("stash has address %p\n", stash);
//	if (stash) printf("$foo has a type %s\n", HvNAME(stash));
}
