#ifndef CB_CUSTOM_OP_H_
#define CB_CUSTOM_OP_H_

/* Logic related to implementing, creating, and managing the C::Blocks
 * custom ops. */

#include <EXTERN.h>
#include <perl.h>

extern XOP tcc_xop;

/* Create a new OP that'll execute the given symbol pointer. */
OP * cb_build_op(pTHX_ void *sym_pointer);

/* Sets up the global state related to our custom OP(s).
 * To be called once before using any of them (eg. BEGIN time of C::Blocks) */
void cb_init_custom_op(pTHX);


#endif
