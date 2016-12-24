use strict;
use warnings;
package C::Blocks::StretchyBuffer;
use C::Blocks;
use C::Blocks::PerlAPI;
our $VERSION = '0.42';
$VERSION = eval $VERSION;
no warnings qw(C::Blocks::compiler);

cshare {
	#define sbfree(a)         ((a) ? Safefree(stb__sbraw(a)),a=0,0 : 0)
	#define sbpush(a,v)       (stb__sbmaybegrow(a,1), (a)[stb__N_used(a)++] = (v))
	#define sbpop(a)          ((a && stb__N_used(a)) ? (a)[--stb__N_used(a)] : 0)
	#define sbcount(a)        ((a) ? stb__N_used(a) : 0)
	#define sbadd(a,n)        (stb__sbmaybegrow(a,n), stb__N_used(a)+=(n), &(a)[stb__N_used(a)-(n)])
	#define sbremove(a,n)     ((a) ? (stb__N_used(a) > n ? (stb__N_used(a) -= n) : (stb__N_used(a) = 0)) : 0)
	#define sblast(a)         ((a)[stb__N_used(a)-1])

	#define stb__sbraw(a) ((int *) (a) - 2)
	#define stb__N_items(a)   stb__sbraw(a)[0]
	#define stb__N_used(a)    stb__sbraw(a)[1]

	#define stb__sbneedgrow(a,n)  ((a)==0 || stb__N_used(a)+n >= stb__N_items(a))
	#define stb__sbmaybegrow(a,n) (stb__sbneedgrow(a,(n)) ? stb__sbgrow(a,n) : 0)
	#define stb__sbgrow(a,n)  stb__sbgrowf(aTHX_ (void **) &(a), (n), sizeof(*(a)))

	static void stb__sbgrowf(pTHX_ void **arr, int increment, int itemsize)
	{
		int N_items;
		int * p;
		if (*arr) {
			/* If the array was previously allocated, then call for a
			 * reallocation. */
			p = stb__sbraw(*arr);
			N_items = stb__N_items(*arr)+increment;
			Renewc(p, itemsize * N_items + sizeof(int)*2, char, int* );
		}
		else {
			/* If the array was previously unallocated, call for a new
			 * block of memory. */
			N_items = increment + 1;
			Newxc(p, itemsize * N_items + sizeof(int)*2, char, int* );
		}
		if (p == 0) croak("C::Blocks::StretchyBuffer: Unable to allocate memory");
		/* First integer indicates how much room we have */
		p[0] = N_items;
		/* Second integer indicates how many items are "used", which will
		 * not change during this procedure. However, if the initial array
		 * was empty, then the newly allocated stretchy has no "used" slots,
		 * so mark it as such. */
		if (!*arr) p[1] = 0;
		/* Re-assign the array to its new memory slot */
		*arr = (void *) (p + 2);
	}
}

use C::Blocks::Types::Pointers generic_buffer => 'void *';
use C::Blocks::Types qw(uint);
sub sbcount {
	my generic_buffer $buffer = shift;
	my uint $count = 0;
	cblock {
		$count = sbcount($buffer);
	}
	return $count;
}
sub sbfree {
	my generic_buffer $buffer = shift;
	cblock {
		sbfree($buffer);
	}
}

sub sbremove {
	my generic_buffer $buffer = shift;
	my uint $N_to_remove = shift;
	my uint $to_return = 0;
	cblock {
		$to_return = sbremove($buffer, $N_to_remove);
	}
	return $to_return;
}

use Exporter ();
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(sbcount sbfree sbremove);

no warnings 'C::Blocks::import', 'redefine';
sub import {
	C::Blocks::load_lib(@_);
	__PACKAGE__->export_to_level(1, @_);
}

1;

__END__

=head1 NAME

C::Blocks::StretchyBuffer - Enabling stretchy buffers in your context

=head1 SYNOPSIS

 use C::Blocks;
 use C::Blocks::StretchyBuffer qw(sbcount sbfree);
 use C::Blocks::Types::Pointers dbuffer => 'double *';
 
 # Create a function that uses stretchy buffers:
 my dbuffer $list = 0;
 cblock {
     /* Push some values onto the list */
     sbpush($list, 3.2);
     sbpush($list, -2.9);
     sbpush($list, 5);
 }
 
 print "I just pushed ", sbcount($list), " items onto my list\n";
 
 cblock {
     /* Eh, let's change that last one from 5 to 22 */
     $list[2] = 22;
     
     /* run through the list */
     for (int i = 0; i < sbcount($list); i++) {
         printf("%dth item is %g\n", i, $list[i]);
	 }
	 
	 /* remove last item */
	 double removed = sbpop($list);
	 printf("Just removed %g; now list has %d items\n",
         removed, sbcount($list));
     
     /* Allocate room for five more */
     sbadd($list, 5);
     
     /* Set the last element */
     sblast($list) = 100;
     
     /* Remove two elements */
     int N_remaining = sbremove($list, 2);
     
     /* When we're all done, free the memory, restoring the value to null */
     sbfree($list);
     
     printf("list is at %p\n", $list);
 }
 
 # It's ok if we ask for the length of a null value:
 print "After freeing, length is ", sbcount($list), "\n";
 
 # Or we could use the Perl-side function. It is safe to call this
 # twice, because the pointer was set to null after it was freed.
 sbfree($list);

=head1 DESCRIPTION

This C::Blocks package provides Sean Barrett's implementation of stretchy buffers, as
well as a couple of extensions by David Mertens for popping and removing values
off the end. For more of Sean Barrett's cool work, see his website at
L<http://nothings.org/>.

How do you begin? Always start by declaring a null pointer of whatever type you
want, like so:

 int * data = 0;
 char * input = 0;
 special_type * array_of_structs = 0;

You then allocate memory using C<sbpush> and C<sbadd>. Thanks to the magic of
preprocessor macros, accessing data in stretchy buffers is B<completely identical>
to accessing data from a normal array. The difference
between the two is the way that memory is managed for you (or not):

 /* Memory allocation is less verbose and includes the assertion */
 double * observations = 0;
 sbadd(observations, 20);
 /* Iterating over values is identical */
 int i;
 for (i = 0; i < 20; ++i) {
     observations[i] = get_observation(i);
 }
 /* Different function for cleanup */
 sbfree(observations);
 
 /* Memory allocation is more verbose */
 double * observations = (double *) malloc (20 * sizeof(double));
 assert(observations);
 /* Iterating over values is identical */
 for (i = 0; i < 20; ++i) {
     observations[i] = get_observation(i);
 }
 /* Different function for cleanup */
 free(observations);

Again, the really cool part about stretchy buffers is that they automatically
handle extending the memory block when you push values or request the addition
of more space on the 'far' end. That is, pushing and popping data off the end is
easy and relatively fast (though shifting and unshifting off the front is not
provided).

C::Blocks::StretchyBuffer provides a number of C functions, and a couple
of Perl functions. Perl functions must be explicitly requested in the
use statement, i.e. 

 use C::Blocks::StretchyBuffer qw(sbfree);

The C functions are automatically available to any of your C code.

=over

=item sbpush (array, value)

C only. Pushes the given value onto the array, extending it if neccesary.
This returns the value that was just added to the list.

=item sbcount (array)

C and Perl. Returns the number of elements currently available for use.
Note that the stretchy buffer may have more room allocated than is
indicated with this function.

=item sbadd (array, count)

C only. Makes C<count> more elements available, allocating more memory
if necessary. This updates C<array> to point to the new address, and
also returns the address of the new section of memory.

=item sblast (array)

C only. Returns the last available element in the array, an lvalue! Note
that this assumes that the array is B<not> null, so only call this when
you know your array is allocated.

=item sbpop (array)

C only. Returns (the value of) the last available element in the array
(or zero if the array is empty), reducing the array length by 1 (unless
the array is empty). This does not deallocate the memory, however; that
sticks around in case you later perform a push or add.

=item sbremove (array, count)

C and Perl. Removes C<count> elements from the array, or if C<count> is
greater than the number of elements, empties the array. As with pop,
this does not deallocate any memory but rather holds onto it in case it
can be used for a later push or add. As an unplanned but pleasant
side-effect, it returns the number of elements that remain after the
removal.

=item sbfree (array)

C and Perl. Frees the memory associated with the stretchy buffer, if
any is allocated. It always returns 0.

=back

=head1 AUTHORS

Sean Barrett, C<< http://nothings.org/ >>
David Mertens, C<< <dcmertens.perl at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests at the project's main github page:
L<http://github.com/run4flat/perl-TCC/issues>.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc C::Blocks::StretchyBuffer

You can also look for information at:

=over 4

=item * The Github issue tracker (report bugs here)

L<http://github.com/run4flat/C-Blocks/issues>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/C-Blocks>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/C-Blocks>

=item * Search CPAN

L<http://p3rl.org/C::Blocks>
L<http://search.cpan.org/dist/C-Blocks/>

=back

=head1 ACKNOWLEDGEMENTS

Sean Barett, of course, for creating such a simple but useful chunk of code, and
for putting that code in the public domain!

=head1 LICENSE AND COPYRIGHT

Sean Barett's original code is in the public domain. All modifications made by
David Mertens are Copyright 2012 Northwestern University, 2015
Dickinson College, and 2016 Eckerd College.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
