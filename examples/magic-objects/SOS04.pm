use strict;
use warnings;

=head1 NAME

SOS04.pm - full-blown subclass of SOS01

=head1 QUESTION

Continuing from SOS03, how many lines of code are involved if add a new
attribute, including implementing the Perl-side metehods in "XS"?

I will keep all other aspects the same but add an attribute, and XS
implementations of the Perl-methods. Let's see how that goes.

=cut

package SOS04;
use C::Blocks;
use C::Blocks::Types qw(Int);
use SOS01;
use SOS02; # for SV -> C-obj
use C::Blocks::PerlAPI;
use C::Blocks::Filter::BlockArrowMethods;
our @ISA = qw(SOS01);

cshare {
	/* vtable and object layouts */
	typedef struct SOS04_t * SOS04;
	/* vtable struct declaration */
	typedef struct SOS04::VTABLE_LAYOUT_t {
		SOS04 (*new)();
		void (*refcount_inc)(SOS04 self);
		void (*refcount_dec)(SOS04 self);
		void (*destroy)(SOS04 self);
		int _class_size;
		HV * _class_stash;
		HV * (*get_HV)(pTHX_ SOS04 self);
		void (*attach_SV)(SOS04 self, pTHX_ SV* to_attach);
		// new accessors for "val", an integer
		int (*get_val)(SOS04 self);
		void (*set_val)(SOS04 self, int new_value);
	} SOS04::VTABLE_LAYOUT;
	/* object layout */
	struct SOS04_t {
		SOS04::VTABLE_LAYOUT * methods;
		HV * perl_obj;
		int val;
	};
	
	/* accessor methods new for this class */
	int SOS04::get_val(SOS04 self) {
		entering;
		leaving;
		return self->val;
	}
	XSPROTO(from_perl::SOS04::get_val) {
		entering;
		dXSARGS;
		/* get the Perl self from the stack */
		SV * SV_self = POPs;
		/* get C representation */
		SOS04 c_self = SOS01::Magic::obj_ptr_from_SV_ref(aTHX_ SV_self);
		/* Prepare stack to receive return values. */
		XSprePUSH;
		/* push integer onto the stack */
		mXPUSHi(c_self=>get_val());
		/* Indicate we're returning a single value on the stack. */
		leaving;
		XSRETURN(1);
	}
	void SOS04::set_val(SOS04 self, int new_value) {
		entering;
		leaving;
		self->val = new_value;
	}
	XSPROTO(from_perl::SOS04::set_val) {
		entering;
		dXSARGS;
		/* get the Perl self from the stack */
		SV * SV_self = ST(0);
		/* get the new value from the stack */
		int new_val = SvIV(ST(1));
		/* get C representation */
		SOS04 c_self = SOS01::Magic::obj_ptr_from_SV_ref(aTHX_ SV_self);
		/* set the value */
		c_self=>set_val(new_val);
		/* Indicate we're not returning anything. */
		leaving;
		XSRETURN_EMPTY;
	}
	
	/* In order to initialize (most of) the vtable instance statically,
	 * the new() method needs to be *declared* before the vtable
	 * and *defined* afterwrd. All other methods should be defined
	 * earleir. */
	SOS04 SOS04::new();
	
	/* We'll need a new vtable instance, but the structure is identical */
	SOS04::VTABLE_LAYOUT SOS04::VTABLE_INSTANCE = {
		SOS04::new,
		(void (*)(SOS04 self))SOS01::refcount_inc,
		(void (*)(SOS04 self))SOS01::refcount_dec,
		(void (*)(SOS04 self))SOS01::destroy,
		sizeof(struct SOS04_t),
		NULL,
		(HV * (*)(pTHX_ SOS04 self))SOS01::get_HV,
		(void (*)(SOS04 self, pTHX_ SV* to_attach))SOS01::attach_SV,
		SOS04::get_val,
		SOS04::set_val
	};
	
	/* create a constructor that allocates the memory */
	SOS04 SOS04::new() {
		entering;
		/* just allocate memory for object */
		SOS04 to_return = SOS01::alloc(SOS04);
		leaving;
		return to_return;
	}
	
	XSPROTO(from_perl::SOS04::new) {
		entering;
		dXSARGS;
		/* create the C representation of self */
		SOS04 self = SOS04::new();
		/* create an mortal SV ref attached to self */
		SV * SV_ret = sv_newmortal();
		self=>attach_SV(aTHX_ SV_ret);
		/* fix the refcount */
		self=>refcount_dec();
		/* Prepare stack to receive return values. */
		XSprePUSH;
		/* push the SV to return onto the stack. */
		XPUSHs(SV_ret);
		/* Indicate we're returning a single value on the stack. */
		leaving;
		XSRETURN(1);
	}
}

cblock {
	_entering("SOS04 Initialization block");
	/* Initialize the only dynamic element of the table. Everything else
	 * was already assigned statically. */
	SOS04::VTABLE_INSTANCE._class_stash = gv_stashpv("SOS04", GV_ADD);
	/* import the xsubs */
	newXS("SOS04::new", from_perl::SOS04::new, __FILE__);
	newXS("SOS04::set_val", from_perl::SOS04::set_val, __FILE__);
	newXS("SOS04::get_val", from_perl::SOS04::get_val, __FILE__);
	_leaving("SOS04 Initialization block");
}

1;

=head1 RESULTS

F<sos-04-new-attribute.pl> verifies that this works. The answer to my
question is that it takes about 130 lines of code to create a subclass
that adds a new C method to a previous class.

=cut
