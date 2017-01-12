#include <cb_custom_op.h>

XOP tcc_xop;

typedef void (*my_void_func)(pTHX);

PP(tcc_pp) {
	dSP;
	void *ptr = INT2PTR(my_void_func, (UV)PL_op->op_targ);
	my_void_func p_to_call = ptr;
	p_to_call(aTHX);
	RETURN;
}


Perl_ophook_t original_opfreehook;

static void
op_free_hook(pTHX_ OP *o) {
	if (original_opfreehook != NULL)
		original_opfreehook(aTHX_ o);

	if (o->op_ppaddr == Perl_tcc_pp) {
		o->op_targ = 0; /* important or Perl will use it to access the pad */
	}
}

OP * cb_build_op(pTHX_ void *sym_pointer) {
	/* create new OP that gets the sym_pointer from its op_targ slot
	 * and invokes it */
	OP * o;
	NewOp(1101, o, 1, OP);

	o->op_type = (OPCODE)OP_CUSTOM;
	o->op_next = (OP*)o;
	o->op_private = 0;
	o->op_flags = 0;
	o->op_targ = (PADOFFSET)PTR2UV(sym_pointer);
	o->op_ppaddr = Perl_tcc_pp;
	
	return o;
}




void cb_init_custom_op(pTHX) {
	/* Setup our callback for cleaning up OPs during global cleanup */
	original_opfreehook = PL_opfreehook;
	PL_opfreehook = op_free_hook;

	/* Set up the custom op */
	XopENTRY_set(&tcc_xop, xop_name, "tccop");
	XopENTRY_set(&tcc_xop, xop_desc, "Op to run jit-compiled C code");
	XopENTRY_set(&tcc_xop, xop_class, OA_BASEOP);

	Perl_custom_op_register(aTHX_ Perl_tcc_pp, &tcc_xop);
}

