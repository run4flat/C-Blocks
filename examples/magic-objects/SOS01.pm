use strict;
use warnings;

=head1 NAME

SOS01.pm - a piece of SOS testing allocation, attaching, and destruction

=head1 QUESTION

How do I build an intertwined C/Perl object?

I have decided that a SOS01 object will own a HV, and the HV
will have magic pointing to the SOS01 pointer underlying the
object. This buys me two useful things:

=over

=item memory management

I can rely on the reference count of the HV for memory management. I can
tie the SOS01 destructor into a magic vtable for this to keep
everything coordinated.

=item returning to Perl space

When a method needs to return a Perl representation of an object, it can
just return a blessed reference to the HV already owned by the object.
This solves a problem that had dogged me in my earlier approaches to an
integrated OO design.

=back

There are two potential approaches. First, each object could hold a
C<HV*>. Whenever a Perl object needs to be returned, it would create a
new C<SV*> referring to the C<HV*> and bless it into the class. Second,
each object could hold a blessed C<SV*> referencing the C<HV*>. This
leads to refcount confusion that I would rather avoid, and it multiplies
the memory associated with each object.

I am leaning toward the first approach, but let's be a bit careful 
about this. My first thought was, "Ah, I can create the HV* only when 
needed." If there is an HV* associated, then refcounting increments and 
decrements transparently. If there is no HV*, then decrementing would
simply call the destroy method immediately, whereas incrementing would
create the HV* first. This is a nice addition because it means I only
use up the extra memory for the HV* if I really need it. Objects that
only spend their lives in C would just waste a little memory associated
with the uninitialized (null) pointer.

There is a subtlety to that, though. When the constructor creates a Perl
representation of the object, it should have a reference count of 1.
However, if one object contains another object within it, and it returns
*that* *object* by some accessor method, then the reference count should
be two. One reference accounts for the object holding this object, and
the other accounts for the Perl-side variable holding this object. Both
of these situations will create a previously nonexistent HV, but the
reference counts should differ. It seems that in this case, the
Perl-level constructor should use the same "pathway" as the one
returning the child object, but the constructor should decrement the
count by one.

=cut

package SOS01;
use C::Blocks;
use C::Blocks::PerlAPI;
use C::Blocks::Filter::BlockArrowMethods;

cshare {
	/* for pretty enter/leave printing */
	int indentation_level = 0;
	#define entering _entering(__func__)
	void _entering(char * name) {
		for (int i = 0; i < indentation_level; i++) printf(" ");
		printf("entering %s\n", name);
		indentation_level++;
	}
	#define leaving _leaving(__func__)
	void _leaving(char * name) {
		indentation_level--;
		for (int i = 0; i < indentation_level; i++) printf(" ");
		printf("leaving %s\n", name);
	}
	
	/*******************************************************************
	 * vtable and object layouts (structs) must be defined as early
	 * as possible. The actual vtable for this class (as distinct from
	 * its layout) will be declared and defined near the end, after
	 * the methods have been defined (or at least declared). Order
	 * matters for this, it must come first!!
	 ******************************************************************/
	typedef struct SOS01_t * SOS01;

	/* vtable struct declaration */
	typedef struct SOS01::VTABLE_LAYOUT_t {
		// memory management
		SOS01 (*new)();
		void (*refcount_inc)(SOS01 self);
		void (*refcount_dec)(SOS01 self);
		void (*destroy)(SOS01 self);
		int _class_size;
		// mapping C class to Perl class
		// to get the package name, use HvNAME
		HV * _class_stash;
		HV * (*get_HV)(pTHX_ SOS01 self);
		void (*attach_SV)(SOS01 self, pTHX_ SV* to_attach);
	} SOS01::VTABLE_LAYOUT;
	
	/* object layout */
	struct SOS01_t {
		SOS01::VTABLE_LAYOUT * methods;
		HV * perl_obj;
	};
	
	/*******************************************************************
	 * MAGIC stuff needed to invoke object destruction when the HV's
	 * refcount drops to zero.
	 ******************************************************************/
	
	/* free method just calls the object's destroy method */
	int SOS01::Magic::free(pTHX_ SV* sv, MAGIC* mg) {
		entering;
		SOS01 obj = (SOS01)(mg->mg_ptr);
		obj=>destroy();
		leaving;
		return 1;
	}
	
	/* magic vtable, copied almost verbatim from C::Blocks::Object::Magic */
	MGVTBL SOS01::Magic::Vtable = {
		NULL, /* get */
		NULL, /* set */
		NULL, /* len */
		NULL, /* clear */
		SOS01::Magic::free, /* free */
	#if MGf_COPY
		NULL, /* copy */
	#endif /* MGf_COPY */
	#if MGf_DUP
		NULL, /* dup */
	#endif /* MGf_DUP */
	#if MGf_LOCAL
		NULL, /* local */
	#endif /* MGf_LOCAL */
	};
	
	/*******************************************************************
	 * C -> Perl methods
	 ******************************************************************/
	
	/* Only create the HV if needed. When that happens, attach the
	 * package stash to the HV, that is, bless it into the Perl-side
	 * package. */
	HV * SOS01::get_HV (pTHX_ SOS01 self) {
		entering;
		/* Create the HV if it does not already exist */
		if (!self->perl_obj) {
			self->perl_obj = newHV();
printf("** Attached magic, with self located at %p\n", self);
			sv_magicext((SV*)self->perl_obj, NULL, PERL_MAGIC_ext,
				&SOS01::Magic::Vtable, (char*)self, 0 );
		}
		leaving;
		return self->perl_obj;
	}
	
	/* Sets the given SV to be a reference to our HV, upgrading it to
	 * an RV if necessary, and blessing. */
	void SOS01::attach_SV (SOS01 self, pTHX_ 
		SV * to_attach)
	{
		entering;
		HV * my_HV = self->methods->get_HV(aTHX_ self);
		/* upgrade the SV that we're attaching to a RV */
		SvUPGRADE(to_attach, SVt_RV);
		/* have to_attach point to my_HV */
		SvROK_on(to_attach);
		SvRV_set(to_attach, (SV*)my_HV);
		/* bless */
		sv_bless(to_attach, self->methods->_class_stash);
		/* must increment reference count of my_HV manually */
		SvREFCNT_inc(my_HV);
		leaving;
	}
	
	/*******************************************************************
	 * refcounting and memory cleanup
	 ******************************************************************/
	
	/* refcounting. If there is no affiliated Perl object, then the
	 * refcount is implicitly one. Incrementing means we get the HV,
	 * possibly creating it in the process. Decrementing means we either
	 * destroy the object if there is no affiliated Perl HV, or we
	 * decrement the HV's refcount. The latter may trigger a magic
	 * destruction. */
	void SOS01::refcount_inc(SOS01 self) {
		entering;
		dTHX;
		HV * perl_obj = self->methods->get_HV(aTHX_ self);
		SvREFCNT_inc((SV*)perl_obj);
		leaving;
	}
	void SOS01::refcount_dec(SOS01 self) {
		entering;
		dTHX;
		if (self->perl_obj == NULL) self=>destroy();
		else SvREFCNT_dec((SV*)self->perl_obj);
		leaving;
	}
	/* memory cleanup. This is never called directly, but is instead
	 * called as Perl Magic method when the associated SV is to be
	 * destroyed. */
	void SOS01::destroy(SOS01 self) {
		entering;
		/* just free the associated memory */
		printf("** freeing self, located at %p\n", self);
		free(self);
		leaving;
	}
	
	/* General-purpose object allocator, to be used by subclasses via
	 * the macro defined a the end of this function */
	SOS01 SOS01::_alloc(SOS01::VTABLE_LAYOUT * class) {
		entering;
		/* allocate memory for object */
		SOS01 to_return = malloc(class->_class_size);
		to_return->methods = class;
		to_return->perl_obj = NULL;
		leaving;
		return to_return;
	}
	#define SOS01::alloc(classname) (classname)SOS01::_alloc(\
		(SOS01::VTABLE_LAYOUT *)&classname##::VTABLE_INSTANCE)
	
	/*******************************************************************
	 * constructor and vtable layout. Order matters for this: it must
	 * come after all the methods have been defined (or at least
	 * declared) above.
	 ******************************************************************/
	
	/* must be declared before VTABLE_INSTANCE, and defined afterward */
	SOS01 SOS01::new();
	
	/* actual vtable for SOS01. Define as much as we can statically */
	SOS01::VTABLE_LAYOUT SOS01::VTABLE_INSTANCE = {
		SOS01::new,
		SOS01::refcount_inc,
		SOS01::refcount_dec,
		SOS01::destroy,
		sizeof(struct SOS01_t),
		NULL, /* package stash, to be assigned later */
		SOS01::get_HV,
		SOS01::attach_SV
	};
	
	/* new, defined once the VTABLE_INSTANCE has been declared */
	SOS01 SOS01::new() {
		/* no members, so just allocate memory for object */
		return SOS01::alloc(SOS01);
	}
}

cblock {
	_entering("Initialization block");
	/* Initialize the class's Perl-related stash */
	SOS01::VTABLE_INSTANCE._class_stash
		= gv_stashpv("SOS01", GV_ADD);
	_leaving("Initialization block");
}

# Perl-side constructor
sub new {
	print "Entering Perl-side new()\n";
	my $to_return;
	cblock {
		_entering("C-side new()");
		/* Create and attach the object */
		SOS01 self = SOS01::new();
		self=>attach_SV(aTHX_ $to_return);
		/* the constructor double-counts the refcount, so backup by 1 */
		self=>refcount_dec();
		_leaving("C-side new()");
	}
	print "Leaving Perl-side new()\n";
	return $to_return;
}

1;

=head1 RESULTS

After lots of trial and error I have finally got this basic test of 
things working. See F<sos-01-create-destroy.pl> for the results.
