#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/*#include "ppport.h"*/
#include "libtcc.h"

typedef void (*my_void_func)(void);

int (*next_keyword_plugin)(pTHX_ char *, STRLEN, OP **);
XOP tcc_xop;
PP(tcc_pp) {
    dVAR;
    dSP;
	IV pointer_iv = POPi;
	my_void_func p_to_call = INT2PTR(my_void_func, pointer_iv);
	p_to_call();
	RETURN;
}

void say (char * something) {
	printf("%s", something);
}

/* Error handling should store the message and return to the normal execution
 * order. In other words, croak is inappropriate here. */
void my_tcc_error_func (void * message_sv, const char * msg ) {
	/* set the message in the error_message key of the compiler context */
	sv_catpvf((SV*)message_sv, "C::Blocks compiler-time error - %s", msg);
}

#define PL_bufptr (PL_parser->bufptr)
#define PL_bufend (PL_parser->bufend)

int my_keyword_plugin(pTHX_
	char *keyword_ptr, STRLEN keyword_len, OP **op_ptr
) {
	
	/* Move along if this is not my keyword */
	if (keyword_len != 1 || keyword_ptr[0] != 'C') {
		return next_keyword_plugin(aTHX_
			keyword_ptr, keyword_len, op_ptr);
	}
	
	/* Add the code necessary for the function declaration */
/*	#if pTHX==void
*/		lex_stuff_pv("void say(char * something); void op_func()", 0);
/*	#else
		lex_stuff_pv("void op_func(void * thread_context)", 0);
	#endif
*/
	
	/**********************/
	/* Extract the C code */
	/**********************/
	
	/* expand the buffer until we encounter the matching closing bracket */
	char *end = PL_bufptr;
	int nest_count = 0;
	while (1) {
		/* do we need to prime the pump? */
		if (end == PL_bufend) {
			int length_so_far = end - PL_bufptr;
			if (!lex_next_chunk(LEX_KEEP_PREVIOUS)) {
				/* We only reach this point if we reached the end of the
				 * file without finding the closing curly brace. */
				croak("C::Blocks expected closing curly brace but did not find it");
			}
			/* revise our end pointer for the new buffer, which may have
			 * moved when pulling the next chunk */
			end = PL_bufptr + length_so_far;
		}
		
		if (*end == '{') nest_count++;
		else if (*end == '}') {
			nest_count--;
			if (nest_count == 0) break;
		}
		
		end++;
	}
	end++;
	
	/********************************************/
	/* Get a (possibly cached) function pointer */
	/********************************************/
	
	/* at this point I will compile the code */
	int len = (int)(end - PL_bufptr);
	/* Check hash if there is something already compiled for it */
	HV * code_cache = get_hv("C::Blocks::__code_cache_hash", GV_ADD);
	SV ** code_cache_SV_p = hv_fetch(code_cache, PL_bufptr, len, 1);
	
	/* Hope this doesn't happen, but better to issue an error */
	if (code_cache_SV_p == 0) {
		croak("C::Blocks: Unable to retrieve code cache entry!");
	}
	
	/* If it's not already in the cache... */
	if (!SvOK(*code_cache_SV_p)) {
		/* Build the compiler */
		/* create a new state with error handling */
		TCCState * state = tcc_new();
		if (!state) {
			croak("Unable to create C::TinyCompiler state!\n");
		}
		SV * error_msg_sv = newSV(0);
		tcc_set_error_func(state, error_msg_sv, my_tcc_error_func);
		tcc_set_output_type(state, TCC_OUTPUT_MEMORY);
		
		/* Add/compiler the code, temporarily adding a null terminator */
		char backup = *end;
		*end = 0;
		tcc_compile_string(state, PL_bufptr);
		*end = backup;
		
		/* Link in the say function */
		tcc_add_symbol(state, "say", say);
		
		/* Check for compile errors */
		if (SvOK(error_msg_sv)) croak_sv(error_msg_sv);
		
		/* prepare for relocation */
		AV * machine_code_cache = get_av("C::Blocks::__code_cache_array", 1);
		SV * machine_code_SV = newSV(tcc_relocate(state, 0));
		tcc_relocate(state, SvPVX(machine_code_SV));
		av_push(machine_code_cache, machine_code_SV);
		
		/* Store the function pointer in the code cache */
		sv_setiv(*code_cache_SV_p, PTR2IV(tcc_get_symbol(state, "op_func")));
		
		/* cleanup */
		tcc_delete(state);
		sv_2mortal(error_msg_sv);
	}
	
	/*********************/
	/* Build the op tree */
	/*********************/
	
	/* o = newUNOP(OP_RAND, 0, newSVOP(OP_CONST, 0, newSViv(42))); o->op_ppaddr = pp_mything; and get an SV holding the IV 42 using POPs or whatever in pp_mything */
	/* or get PL_op in the function and retrieve the function pointer from some entry in the (customized) struct */
	/* Params::Classify, Scope::Cleanup, Memoize::Once */
	
	/* Finally, get the pointer IV and build the optree. */
	IV pointer_IV = SvIV(*code_cache_SV_p);
	OP * o = newUNOP(OP_RAND, 0, newSVOP(OP_CONST, 0, newSViv(pointer_IV)));
	o->op_ppaddr = Perl_tcc_pp;
	
	/* Set the op to my newly built one */
	*op_ptr = o;
	
	/* All done, cleanup for the compiler to keep going */
	
/*	printf("Found %d characters in your C block\n", len);
	printf("First three characters in your C block is [%c%c%c]\n", PL_bufptr[0], PL_bufptr[1], PL_bufptr[2]);
	int hash;
	char * string_ptr_to_hash = PL_bufptr;
	PERL_HASH(hash, string_ptr_to_hash, len);
	printf("hash for this string is %d\n", hash);
*/	
	
	/* insert a semicolon to make the parser happy */
	*end = ';';
	lex_unstuff(end);
	
	/* Return success */
	return KEYWORD_PLUGIN_STMT;
}

MODULE = C::Blocks       PACKAGE = C::Blocks

void
_import()
CODE:
	next_keyword_plugin = PL_keyword_plugin;
	PL_keyword_plugin = my_keyword_plugin;

void
unimport(...)
CODE:
	PL_keyword_plugin = next_keyword_plugin;

BOOT:
	/* Set up the keyword plugin to a useful initial value. */
	next_keyword_plugin = PL_keyword_plugin;
	
	/* Set up the custom op */
	XopENTRY_set(&tcc_xop, xop_name, "tccop");
	XopENTRY_set(&tcc_xop, xop_desc, "Op to run jit-compiled C code");
	Perl_custom_op_register(aTHX_ Perl_tcc_pp, &tcc_xop);
