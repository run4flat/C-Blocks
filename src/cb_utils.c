#include <cb_utils.h>

#include <ppport.h>

void cb_warnif (pTHX_ const char * category, SV * message) {
	dSP;
	
	/* Prepare the stack */
	ENTER;
	SAVETMPS;
	
	/* Push the category and message onto the stack. The message must
	 * be a mortalized SV. */
	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newSVpvf("C::Blocks::%s", category)));
	XPUSHs(message);
	PUTBACK;
	
	/* Call */
	/* XXX why can't I just call warnings::warnif??? */
	call_pv("C::Blocks::warnif", G_VOID);
	
	/* cleanup */
	FREETMPS;
	LEAVE;
}

