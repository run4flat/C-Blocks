use strict;
use warnings;

=head1 NAME

SOS03.pm - subclassing SOS01

=head1 QUESTION

How do I subclass SOS01? More specifically, what is the minimum amount 
of work I need to do to create a new class with a different method, but 
same structure?

Thankfully, I will not need to worry about implementing the magic again.
That is a problem I only need to solve once.

If I wanted to add a new method, I would need to create a new vtable,
and if I had a new vtable, I would need to create a new class with a
vtable pointer of the correct type. I would have to go through the same
effort if I wanted to add a new attribute (whether or not I created
accessors for that attribute).

But, for now, I just want a different implementation of a method. What
can I get away with?

=cut

package SOS03;
use C::Blocks;
use SOS01;
use C::Blocks::PerlAPI;
use C::Blocks::Filter::BlockArrowMethods;
our @ISA = qw(SOS01);

cshare {
	/* create new refcount_dec that simply wraps the parent method,
	 * after logging its presence */
	void SOS03::refcount_dec(SOS01 self) {
		entering;
		/* call parent method */
		SOS01::refcount_dec(self);
		leaving;
	}
	
	/* In order to initialize (most of) the vtable instance statically,
	 * the new() method needs to be *declared* before the vtable
	 * and *defined* afterwrd. All other methods should be defined
	 * earleir. */
	SOS01 SOS03::new();
	
	/* We'll need a new vtable instance, but the structure is identical */
	SOS01::VTABLE_LAYOUT SOS03::VTABLE_INSTANCE = {
		SOS03::new,
		SOS01::refcount_inc,
		SOS03::refcount_dec,
		SOS01::destroy,
		sizeof(struct SOS01_t),
		NULL,
		SOS01::get_HV,
		SOS01::attach_SV
	};
	typedef SOS01 SOS03;
	
	/* create a constructor that properly "blesses" this object */
	SOS01 SOS03::new() {
		/* just allocate memory for object */
		return SOS01::alloc(SOS03);
	}
}

cblock {
	_entering("SOS03 Initialization block");
	/* Initialize the only dynamic element of the table. Everything else
	 * was already assigned statically. */
	SOS03::VTABLE_INSTANCE._class_stash = gv_stashpv("SOS01", GV_ADD);
	_leaving("SOS03 Initialization block");
}

# Perl-side constructor
sub new {
	print "Entering Perl-side SOS03 new()\n";
	my $to_return;
	cblock {
		_entering("C-side SOS03 new()");
		/* Create and attach the object */
		SOS01 self = SOS03::new();
		self=>attach_SV(aTHX_ $to_return);
		/* the constructor double-counts the refcount, so backup by 1 */
		self=>refcount_dec();
		_leaving("C-side SOS03 new()");
	}
	print "Leaving Perl-side SOS03 new()\n";
	return $to_return;
}

1;

=head1 RESULTS

F<sos-03-simple-subclass.pl> verifies that this works. The answer to my
question is that it takes about 60 lines of code to create a subclass
that simply overrides one C method with another.

=cut
