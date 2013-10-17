#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/*#include "ppport.h"*/
#include "libtcc.h"

int (*next_keyword_plugin)(pTHX_ char *, STRLEN, OP **);
XOP tcc_xop;
OP *tcc_pp(pTHX);

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
	#if pTHX
		lex_stuff_pv("void op_func(void * thread_context)", 0);
	#else
		lex_stuff_pv("void op_func(
	#endif

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
	
	/* at this point I will compile the code */
	int len = (int)(end - PL_bufptr);
	printf("Found %d characters in your C block\n", len);
	printf("First three characters in your C block is [%c%c%c]\n", PL_bufptr[0], PL_bufptr[1], PL_bufptr[2]);
	int hash;
	char * string_ptr_to_hash = PL_bufptr;
	PERL_HASH(hash, string_ptr_to_hash, len);
	printf("hash for this string is %d\n", hash);
	
	/* insert a semicolon to make the parser happy */
	*end = ';';
	lex_unstuff(end);
	
	/* Set the op to my newly built one */
	*op_ptr = newOP(OP_NULL,0);
	
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
	Perl_custom_op_register(aTHX_ tcc_pp, &tcc_xop);
 