use strict;
use warnings;

=head1 NAME

SOS02.pm - adding Perl -> C

=head1 QUESTION

The functionality and reference counting is present for me to make a
C copy of a SOS01 object, but I can't get the C-representation in a
C<cblock> to perform that action! I need to add the ability to retrieve
the C pointer given the C<SV*>. How do I do that?

=cut

package SOS02;
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
	SOS01::VTABLE_LAYOUT SOS01::VTABLE_INSTANCE;
	
	/* object layout */
	struct SOS01_t {
		SOS01::VTABLE_LAYOUT * methods;
		HV * perl_obj;
	};
	
	/* MAGIC function to invoke object destruction */
	int SOS01::Magic::free(pTHX_ SV* sv, MAGIC* mg) {
		entering;
		SOS01 obj = (SOS01)(mg->mg_ptr);
		obj=>destroy();
		leaving;
		return 1;
	}
	/* magic vtable, copied almost verbatim from C::Blocks::Object::Magic */
	STATIC MGVTBL SOS01::Magic::Vtable = {
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
	
	void * SOS01::Magic::obj_ptr_from_SV_ref (pTHX_ SV* sv_ref) {
		entering;
		MAGIC *mg;
		if (!SvROK(sv_ref))
			croak("obj_ptr_from_SV called with non-ref scalar");
		SV * sv = SvRV(sv_ref);

		if (SvTYPE(sv) >= SVt_PVMG) {
			for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic) {
				if ((mg->mg_type == PERL_MAGIC_ext)
					&& (mg->mg_virtual == &SOS01::Magic::Vtable))
				{
					_leaving("SOS02::Magic::obj_ptr_from_HV, returning non-null");
					return mg->mg_ptr;
				}
			}
		}
		_leaving("SOS02::Magic::obj_ptr_from_HV, returning null");
		return NULL;
	}
	
	/* new */
	SOS01 SOS01::_alloc(SOS01::VTABLE_LAYOUT * class) {
		entering;
		/* allocate memory for object */
		SOS01 to_return = malloc(class->_class_size);
		to_return->methods = class;
		to_return->perl_obj = NULL;
		leaving;
		return to_return;
	}
	#define SOS01::alloc(classname) (classname)SOS01::_alloc(&classname##::VTABLE_INSTANCE)
	SOS01 SOS01::new() {
		/* no members, so just allocate memory for object */
		return SOS01::alloc(SOS01);
	}
	
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
		/* create a new reference, then copy it */
		HV * my_HV = self->methods->get_HV(aTHX_ self);
		SV * to_copy = newRV_inc((SV*)my_HV);
		sv_setsv(to_attach, to_copy);
		sv_bless(to_attach, self->methods->_class_stash);
		SvREFCNT_dec(to_copy);
		leaving;
	}
	
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
}

cblock {
	_entering("Initialization block");
	/* Initialize the elements of the table */
	SOS01::VTABLE_INSTANCE.new = SOS01::new;
	SOS01::VTABLE_INSTANCE._class_size
		= sizeof(struct SOS01_t);
	SOS01::VTABLE_INSTANCE._class_stash
		= gv_stashpv("SOS01", GV_ADD);
	SOS01::VTABLE_INSTANCE.refcount_inc
		= SOS01::refcount_inc;
	SOS01::VTABLE_INSTANCE.refcount_dec
		= SOS01::refcount_dec;
	SOS01::VTABLE_INSTANCE.destroy
		= SOS01::destroy;
	SOS01::VTABLE_INSTANCE.get_HV
		= SOS01::get_HV;
	SOS01::VTABLE_INSTANCE.attach_SV	
		= SOS01::attach_SV;
	_leaving("Initialization block");
}

# Perl-side constructor
sub SOS01::new {
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

After *lots* of trial and error I have finally got this basic test of 
things working.

Had to copy all of sos01, no "inheritance" or simple glomming on.

WHY NOT? This is worthy of a test!


F<sos-01-create-destroy.pl> exercises the basic 
creation and destruction behavior and illustrates that everything works 
without a hitch, and that the call stack is not very deep in any of 
this.
