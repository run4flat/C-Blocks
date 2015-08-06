#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "libtcc.h"

/* ---- Zephram's book of preprocessor hacks ---- */
#define PERL_VERSION_DECIMAL(r,v,s) (r*1000000 + v*1000 + s)
#define PERL_DECIMAL_VERSION \
        PERL_VERSION_DECIMAL(PERL_REVISION,PERL_VERSION,PERL_SUBVERSION)
#define PERL_VERSION_GE(r,v,s) \
        (PERL_DECIMAL_VERSION >= PERL_VERSION_DECIMAL(r,v,s))

/* ---- pad_findmy_pv ---- */
#ifndef pad_findmy_pv
# if PERL_VERSION_GE(5,11,2)
#  define pad_findmy_pv(name, flags) pad_findmy(name, strlen(name), flags)
# else /* <5.11.2 */
#  define pad_findmy_pv(name, flags) pad_findmy(name)
# endif /* <5.11.2 */
#endif /* !pad_findmy_pv */

int (*next_keyword_plugin)(pTHX_ char *, STRLEN, OP **);

typedef void (*my_void_func)(pTHX);

typedef struct _available_extended_symtab {
	extended_symtab_p exsymtab;
	void * dll;
} available_extended_symtab;

XOP tcc_xop;
PP(tcc_pp) {
    dVAR;
    dSP;
	IV pointer_iv = POPi;
	my_void_func p_to_call = INT2PTR(my_void_func, pointer_iv);
	p_to_call(aTHX);
	RETURN;
}

/* ---- Extended symbol table handling ---- */
typedef struct _extended_symtab_callback_data {
	TCCState * state;
	#ifdef PERL_IMPLICIT_CONTEXT
		tTHX my_perl;  /* name of field is my_perl, according to perl.h */
	#endif
	available_extended_symtab * available_extended_symtabs;
	int N_tables;
} extended_symtab_callback_data;

/******************************/
/**** Dynaloader interface ****/
/******************************/

void * dynaloader_get_symbol(pTHX_ void * dll, char * name) {
	dSP;
	int count;
	
	ENTER;
	SAVETMPS;
	
	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newSViv(PTR2IV(dll))));
	XPUSHs(sv_2mortal(newSVpv(name, 0)));
	PUTBACK;
	
	count = call_pv("DynaLoader::dl_find_symbol", G_SCALAR);
	SPAGAIN;
	if (count != 1) croak("C::Blocks expected one return value from dl_find_symbol but got %d\n", count);
	SV * returned = POPs;
	void * to_return = NULL;
	if (SvOK(returned)) to_return = INT2PTR(void*, SvIV(returned));
	
	PUTBACK;
	FREETMPS;
	LEAVE;
	
	return to_return;
}

void * dynaloader_get_lib(pTHX_ char * name) {
	dSP;
	int count;
	
	ENTER;
	SAVETMPS;
	
	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newSVpv(name, 0)));
	PUTBACK;
	
	count = call_pv("DynaLoader::dl_load_file", G_SCALAR);

	SPAGAIN;
	if (count != 1) croak("C::Blocks expected one return value from dl_load_file but got %d\n", count);
	void * to_return = INT2PTR(void*, POPi);
	
	PUTBACK;
	FREETMPS;
	LEAVE;
	
	return to_return;
}

/***************************/
/**** Testing Functions ****/
/***************************/

char * _c_blocks_get_msg() {
	dTHX;
	SV * msg_SV = get_sv("C::Blocks::_msg", 0);
	return SvPVbyte_nolen(msg_SV);
}
void _c_blocks_send_msg(char * msg) {
	dTHX;
	SV * msg_SV = get_sv("C::Blocks::_msg", 0);
	sv_setpv(msg_SV, msg);
}
void _c_blocks_send_bytes(char * msg, int bytes) {
	dTHX;
	SV * msg_SV = get_sv("C::Blocks::_msg", 0);
	sv_setpvn(msg_SV, msg, bytes);
}

/*****************************************/
/**** Extended symbol table callbacks ****/
/*****************************************/

TokenSym_p my_symtab_lookup_by_name(char * name, int len, void * data, extended_symtab_p* containing_symtab) {
	/* Unpack the callback data */
	extended_symtab_callback_data * callback_data = (extended_symtab_callback_data*)data;
	
	/* In all likelihood, name will *NOT* be null terminated */
	char name_to_find[len + 1];
	strncpy(name_to_find, name, len);
	name_to_find[len] = '\0';
	
	/* Run through all of the available extended symbol tables and look for this
	 * identifier. */
	int i;
	for (i = callback_data->N_tables - 1; i >= 0; i--) {
		extended_symtab_p my_symtab
			= callback_data->available_extended_symtabs[i].exsymtab;
		TokenSym_p ts = tcc_get_extended_tokensym(my_symtab, name_to_find);
		if (ts != NULL) {
			*containing_symtab = my_symtab;
			return ts;
		}
	}
	
	return NULL;
}

void my_symtab_sym_used(char * name, int len, void * data) {
	/* Unpack the callback data */
	extended_symtab_callback_data * callback_data = (extended_symtab_callback_data*)data;
	
	/* Name *IS* null terminated */
	
	/* Run through all of the available extended symbol tables and look for this
	 * identifier. If found, add the symbol to the state. */
	int i;
	void * pointer = NULL;
	for (i = callback_data->N_tables - 1; i >= 0; i--) {
		available_extended_symtab lookup_data
			= callback_data->available_extended_symtabs[i];
		
		/* If we have a dll, then look for the name in there */
		if (lookup_data.dll != NULL) {
			#ifdef PERL_IMPLICIT_CONTEXT
				pointer = dynaloader_get_symbol(callback_data->my_perl,
					callback_data->available_extended_symtabs[i].dll, name);
			#else
				pointer = dynaloader_get_symbol(
					callback_data->available_extended_symtabs[i].dll, name);
			#endif
		}
		
		/* Otherwise, it was JIT-compiled, look for it in the exsymtab */
		else {
			pointer = tcc_get_extended_symbol(lookup_data.exsymtab, name);
		}
		
		/* found it? Then we're done */
		if (pointer != NULL) {
			tcc_add_symbol(callback_data->state, name, pointer);
			return;
		}
	}
	
	/* Out here only means one thing: couldn't find it! */
	// working here: warn("Could not find symbol '%s' to mark as used");
}

void my_prep_table (void * data) {
	/* Unpack the callback data */
	extended_symtab_callback_data * callback_data = (extended_symtab_callback_data*)data;
	
	/* Run through all of the available extended symbol tables and call the
	 * TokenSym preparation function. Order is important here: go from last
	 * to first!!! */
	int i;
	for (i = callback_data->N_tables - 1; i >= 0; i--) {
		extended_symtab_p my_symtab
			= callback_data->available_extended_symtabs[i].exsymtab;
		tcc_prep_tokensym_list(my_symtab);
	}
}


/************************/
/**** Error handling ****/
/************************/

/* Error handling should store the message and return to the normal execution
 * order. In other words, croak is inappropriate here. */
void my_tcc_error_func (void * message_ptr, const char * msg ) {
	SV* message_sv = (SV*)message_ptr;
	/* ignore "defined twice" errors */
	if (strstr(msg, "defined twice") != NULL) return;
	/* set the message in the error_message key of the compiler context */
	if (SvPOK(message_sv)) {
		sv_catpvf(message_sv, "%s\n", msg);
	}
	else {
		sv_setpvf(message_sv, "%s\n", msg);
	}
}

/********************************/
/**** Keyword Identification ****/
/********************************/

enum { IS_CBLOCK = 1, IS_CSHARE, IS_CLEX, IS_CSUB } keyword_type_list;

/* Functions to quickly identify our keywords, assuming that the first letter has
 * already been checked and found to be 'c' */
int identify_keyword (char * keyword_ptr, STRLEN keyword_len) {
	if (keyword_ptr[0] != 'c') return 0;
	if (keyword_len == 4) {
		if (	keyword_ptr[1] == 's'
			&&	keyword_ptr[2] == 'u'
			&&	keyword_ptr[3] == 'b') return IS_CSUB;
		
		if (	keyword_ptr[1] == 'l'
			&&	keyword_ptr[2] == 'e'
			&&	keyword_ptr[3] == 'x') return IS_CLEX;
		
		return 0;
	}
	if (keyword_len == 6) {
		if (	keyword_ptr[1] == 'b'
			&&	keyword_ptr[2] == 'l'
			&&	keyword_ptr[3] == 'o'
			&&	keyword_ptr[4] == 'c'
			&&	keyword_ptr[5] == 'k') return IS_CBLOCK;
		
		if (	keyword_ptr[1] == 's'
			&&	keyword_ptr[2] == 'h'
			&&	keyword_ptr[3] == 'a'
			&&	keyword_ptr[4] == 'r'
			&&	keyword_ptr[5] == 'e') return IS_CSHARE;
		
		return 0;
	}
	return 0;
}

int _is_whitespace_char(char to_check) {
	if (' ' == to_check || '\n' == to_check || '\r' == to_check || '\t' == to_check) {
		return 1;
	}
	return 0;
}

int _is_id_cont (char to_check) {
	if('_' == to_check || ('0' <= to_check && to_check <= '9')
		|| ('A' <= to_check && to_check <= 'Z')
		|| ('a' <= to_check && to_check <= 'z')) return 1;
	return 0;
}

/************************/
/**** Keyword plugin ****/
/************************/


#ifdef PL_bufptr
	#undef PL_bufptr
	#undef PL_bufend
#endif

#define PL_bufptr (PL_parser->bufptr)
#define PL_bufend (PL_parser->bufend)

#define ENSURE_LEX_BUFFER(end, croak_message)                   \
	if (end == PL_bufend) {                                     \
		int length_so_far = end - PL_bufptr;                    \
		if (!lex_next_chunk(LEX_KEEP_PREVIOUS)) {               \
			/* We only reach this point if we reached the end   \
			 * of the file. Croak with the given message */     \
			croak(croak_message);                               \
		}                                                       \
		/* revise our end pointer for the new buffer, which     \
		 * may have moved when pulling the next chunk */        \
		end = PL_bufptr + length_so_far;                        \
	}


void add_predeclaration_macros_to_block(pTHX) {
	/* Add a preprocessor macro that we can define with variable
	 * predeclarations *after* having extracted the code to compile. */
	lex_unstuff(PL_bufptr + 1);
	lex_stuff_pv("{C_BLOCK_PREDECLARATIONS ", 0);
	
	/* Add the function declaration. The type is a macro that will default
	 * to "void", but may be changed to PerlInterpreter later during the
	 * compilation. */
	#ifdef PERL_IMPLICIT_CONTEXT
		lex_stuff_pv("void op_func(MY_PERL_TYPE * my_perl)", 0);
	#else
		lex_stuff_pv("void op_func()", 0);
	#endif
}

typedef struct c_blocks_data {
	char * my_perl_type;
	char * end;
	char * xsub_name;
	COPHH* hints_hash;
	SV * exsymtabs;
	SV * add_test_SV;
	SV * predeclarations;
	SV * error_msg_sv;
	int N_newlines;
	int keep_curly_brackets;
//	int has_loaded_perlapi;
} c_blocks_data;

void initialize_c_blocks_data(pTHX_ c_blocks_data* data) {
	data->N_newlines = 0;
	data->xsub_name = 0;
	data->add_test_SV = 0;
	data->keep_curly_brackets = 1;
//	data->has_loaded_perlapi = 0;
	
	data->hints_hash = CopHINTHASH_get(PL_curcop);
	data->add_test_SV = get_sv("C::Blocks::_add_msg_functions", 0);
	data->predeclarations = newSVpvn(" ", 1);
	data->error_msg_sv = newSV(0);
	
	/* This is called after we have cleared out whitespace, so just assign */
	data->end = PL_bufptr;
	
	/* The type for the pointer passed to op_func will depend on whether
	 * libperl has been loaded. A preprocessor macro will eventually be set to
	 * whatever is in this string. The default assumes no libperl, in which case
	 * we should use a void pointer. */
	data->my_perl_type = "void";
	
	/* Get the current exsymtabs list. If this doesn't exist, we'll have */
	data->exsymtabs = cophh_fetch_pvs(data->hints_hash, "C::Blocks/extended_symtab_tables", 0);
}

void cleanup_c_blocks_data(pTHX_ c_blocks_data* data) {
	SvREFCNT_dec(data->predeclarations);
	SvREFCNT_dec(data->error_msg_sv);
	//if (SvPOK(data->exsymtabs)) SvREFCNT_dec(data->exsymtabs);
	Safefree(data->xsub_name);
}

#if 0
void add_perlapi(pTHX_ c_blocks_data * data) {
	if (data->has_loaded_perlapi) return;
	/* Load libperl and append to *just* *this* exsymtab list */
	SV * perlapi = newSVpvn("C::Blocks::PerlAPI", 18);
	load_module(PERL_LOADMOD_NOIMPORT, perlapi, NULL);
	sv_2mortal(perlapi);
	
	/* Get the contents and append to the exsymtabs */
	SV * perlapi_symtab = get_sv("C::Blocks::PerlAPI::__cblocks_extended_symtab_list",
			GV_ADDMULTI);
	SV * new_exsymtabs = newSVsv(data->exsymtabs);
	sv_2mortal(new_exsymtabs);
	sv_catpvn(new_exsymtabs, SvPVbyte_nolen(perlapi_symtab), sizeof(available_extended_symtab));
	data->exsymtabs = new_exsymtabs;
	
	data->has_loaded_perlapi = 1;
	
	data->my_perl_type = "PerlInterpreter";
}
#endif

void find_end_of_xsub_name(pTHX_ c_blocks_data * data) {
	data->end = PL_bufptr;
//	add_perlapi(aTHX_ data);
	
	/* extract the function name */
	while (1) {
		ENSURE_LEX_BUFFER(data->end,
			data->end == PL_bufptr
			? "C::Blocks encountered the end of the file before seeing the csub name"
			: "C::Blocks encountered the end of the file before seeing the body of the csub"
		);
		if (data->end == PL_bufptr) {
			if(!isIDFIRST(*data->end)) croak("C::Blocks expects a name after csub");
		}
		else if (_is_whitespace_char(*data->end) || *data->end == '{') {
			break;
		}
		else if (!_is_id_cont(*data->end)){
			croak("C::Blocks csub name can contain only underscores, letters, and numbers");
		}
		
		data->end++;
	}
}

void fixup_xsub_name(pTHX_ c_blocks_data * data) {
	/* Find where the name ends, copy it, and replace it with the correct
	 * declaration */
	
	/* Find and copy */
	find_end_of_xsub_name(aTHX_ data);
	data->xsub_name = savepvn(PL_bufptr, data->end - PL_bufptr);
	
	/* remove the name from the buffer */
	lex_unstuff(data->end);
	
	/* re-add what we want in reverse order (LIFO) */
	lex_stuff_pv(")", 0);
	lex_stuff_pv(data->xsub_name, 0);
	lex_stuff_pv("XS_INTERNAL(", 0);
}

/* Add testing functions if requested */
void add_msg_function_decl(pTHX_ c_blocks_data * data) {
	if (SvOK(data->add_test_SV)) {
		/* The stuff position depends on whether we are going to get rid of the
		 * first curly bracket or not. */
		if (!data->keep_curly_brackets) lex_unstuff(PL_bufptr + 1);
		
		lex_stuff_pv("void c_blocks_send_msg(char * msg);"
			"void c_blocks_send_bytes(void * msg, int bytes);"
			"char * c_blocks_get_msg();"
			, 0);
		
		if (!data->keep_curly_brackets) lex_stuff_pv("{", 0);
	}
}

/* Make the current module a child class of C::Blocks::libloader. */
void use_parent_libloader(pTHX) {
	int i;
	AV * parents = mro_get_linear_isa(PL_curstash);
	
	/* Are any parents from C::Blocks::libloader? */
	for (i = 0; i <= av_len(parents); i++) {
		SV * parent = *(av_fetch(parents, i, 0));
		if (strEQ("C::Blocks::libloader", SvPVbyte_nolen(parent))) return;
	}
	
	/* if not, add it to the isa list */
	AV *isa = perl_get_av(form("%s::ISA", SvPVbyte_nolen(PL_curstname)), GV_ADDMULTI | GV_ADD);
	av_push(isa, newSVpvn("C::Blocks::libloader", 20));
}

/* State-aware parse functions. Each of these know how to look at data
 * coming from the buffer in a state-dependent way. They return the
 * proper parse function for the next character. */
struct parse_state_t;
typedef struct parse_state_t parse_state;
typedef int (*parse_func_t)(pTHX_ parse_state *);
struct parse_state_t {
	parse_func_t process_next_char;
	parse_func_t default_next_char;
	c_blocks_data * data;
	char * sigil_start;
	int bracket_count;
	char delimiter;
};
int process_next_char_with_sigils (pTHX_ parse_state * pstate);
int process_next_char_no_sigils (pTHX_ parse_state * pstate);
int process_next_char_delimited (pTHX_ parse_state * pstate);
int process_next_char_C_comment (pTHX_ parse_state * pstate);
int process_next_char_sigiled_var (pTHX_ parse_state * pstate);

/* Default text parser for clex and cshare. Make use of the range of
 * nonzero return values so the sigil-handler can call this and be
 * smart about any additional work. */
int process_next_char_no_sigils (pTHX_ parse_state * pstate) {
	switch (pstate->data->end[0]) {
		case '{':
			pstate->bracket_count++;
			return 2;
		case '}':
			pstate->bracket_count--;
			if (pstate->bracket_count == 0) return 0;
			return 2;
		case '\'': case '\"':
			/* Shift to quote extraction state */
			pstate->process_next_char = process_next_char_delimited;
			pstate->delimiter = pstate->data->end[0];
			return 2;
		case '/':
			if (pstate->data->end > PL_bufptr && pstate->data->end[-1] == '/') {
				pstate->process_next_char = process_next_char_delimited;
				pstate->delimiter = '\n';
			}
			return 2;
		case '*':
			if (pstate->data->end > PL_bufptr && pstate->data->end[-1] == '/') {
				pstate->process_next_char = process_next_char_C_comment;
				pstate->delimiter = '\n';
			}
			return 2;
	}
	/* Out here means it's a normal character: nothing special */
	return 1;
}

/* Default text parser for cblock */
int process_next_char_with_sigils (pTHX_ parse_state * pstate) {
	int no_sigils_result = process_next_char_no_sigils(aTHX_ pstate);
	if (no_sigils_result != 1) return no_sigils_result;
	if (*pstate->data->end == '$' || *pstate->data->end == '@'
		|| *pstate->data->end == '%'
	) {
		/* Set up the variable name extractor */
		pstate->process_next_char = process_next_char_sigiled_var;
		pstate->sigil_start = pstate->data->end;
	}
	return 1;
}


int process_next_char_delimited (pTHX_ parse_state * pstate) {
	if (pstate->data->end[0] == pstate->delimiter && pstate->data->end[-1] != '\\') {
		/* Reset to normal parse state */
		pstate->process_next_char = pstate->default_next_char;
	}
	else if (pstate->delimiter != '\n' && pstate->data->end[0] == '\n') {
		/* Strings do not wrap */
		pstate->process_next_char = pstate->default_next_char;
	}
	return 1;
}

int process_next_char_C_comment (pTHX_ parse_state * pstate) {
	if (pstate->data->end[0] == '/' && pstate->data->end[-1] == '*') {
		/* Found comment closer. Reset to normal parse state */
		pstate->process_next_char = pstate->default_next_char;
	}
	return 1;
}

int process_next_char_sigiled_var(pTHX_ parse_state * pstate) {
	/* keep collecting if the current character looks like a valid
	 * identifier character */
	if (_is_id_cont(pstate->data->end[0])) return 1;
	
	/* We may have found the end of the identifier name. */
	if (pstate->data->end == pstate->sigil_start + 1) {
		/* a lone sigil character followed by a space. This isn't
		 * actually a Perl sigiled variable, so reset the state and
		 * defer to the default handler */
		pstate->process_next_char = pstate->default_next_char;
		return pstate->default_next_char(aTHX_ pstate);
	}
	
	/* We just identified the character that is one past the end of our
	 * Perl variable name. Identify the type and construct the mangled
	 * name for the C-side variable. */
	char backup = *pstate->data->end;
	*pstate->data->end = '\0';
	char * type;
	char * long_name;
	if (*pstate->sigil_start == '$') {
		type = "SV";
		long_name = savepv(form("_PERL_LEXICAL_SCALAR_%s", 
			pstate->sigil_start + 1));
	}
	else if (*pstate->sigil_start == '@') {
		type = "AV";
		long_name = savepv(form("_PERL_LEXICAL_ARRAY_%s", 
			pstate->sigil_start + 1));
	}
	else if (*pstate->sigil_start == '%') {
		type = "HV";
		long_name = savepv(form("_PERL_LEXICAL_HASH_%s", 
			pstate->sigil_start + 1));
	}
	else {
		/* should never happen */
		*pstate->data->end = backup;
		croak("C::Blocks internal error: unknown sigil %c\n",
			*pstate->sigil_start);
	}
	
	/* Check if we need to add a declaration for the C-side variable */
	if (strstr(SvPVbyte_nolen(pstate->data->predeclarations), long_name) == NULL) {
		/* Add a new declaration for it */
		/* NOTE: pad_findmy_pv expects the sigil!! */
		int var_offset = (int)pad_findmy_pv(pstate->sigil_start, 0);
		/* Ensure that the variable exists in the pad */
		if (var_offset == NOT_IN_PAD) {
			CopLINE(PL_curcop) += pstate->data->N_newlines;
			*pstate->data->end = backup;
			croak("Could not find lexically scoped \"%s\"",
				pstate->sigil_start);
		}
		
		/* XXX fix this so that I don't need the ifdef/else */
		//add_perlapi(aTHX_ data);

		#ifdef PERL_IMPLICIT_CONTEXT
			sv_catpvf(pstate->data->predeclarations, "%s * %s = "
				"(%s*)(((PerlInterpreter *)my_perl)->Icurpad)[%d]; ",
				type, long_name, type, var_offset);
		#else
			sv_catpvf(pstate->data->predeclarations, "%s * %s = (%s*)PAD_SV(%d); ",
				type, long_name, type, var_offset);
		#endif
	}
	
	/* Reset the character just following the var name */
	*pstate->data->end = backup;
	
	/* Replace the sigiled expression with the long name. We need to be
	 * tricky here and temporarily change what the lexer thinks of as
	 * the "start" of the buffer. This should be safe because
	 * lex_unstuff does not allocate new memory, it just moves stuff
	 * around */
	int buffptr_relative_to_varname_start = pstate->sigil_start - PL_bufptr;
	PL_bufptr = pstate->sigil_start;
	
	/* Get rid of sigiled varname and replace with the long
	 * name */
	lex_unstuff(pstate->data->end);
	lex_stuff_pv(long_name, 0);
	
	/* Reset the buffer pointers */
	pstate->data->end = PL_bufptr + 1;
	PL_bufptr -= buffptr_relative_to_varname_start;
	
	/* Cleanup memory */
	Safefree(long_name);
	
	/* Reset the parser state and process the current character with
	 * the default parser */
	pstate->process_next_char = pstate->default_next_char;
	return pstate->default_next_char(aTHX_ pstate);
}

void extract_C_code(pTHX_ c_blocks_data * data, int keyword_type) {
	/* expand the buffer until we encounter the matching closing bracket,
	 * accounting for brackets that may occur in comments and strings.
	 * Process sigiled variables as well. */
	
	/* Set up the parser state */
	parse_state my_parse_state;
	my_parse_state.data = data;
	my_parse_state.sigil_start = 0;
	my_parse_state.bracket_count = 0;
	if (keyword_type == IS_CBLOCK) {
		my_parse_state.process_next_char = process_next_char_with_sigils;
		my_parse_state.default_next_char = process_next_char_with_sigils;
	}
	else {
		my_parse_state.process_next_char = process_next_char_no_sigils;
		my_parse_state.default_next_char = process_next_char_no_sigils;
	}
	
	
	data->end = PL_bufptr;
	int still_working;
	do {
		ENSURE_LEX_BUFFER(data->end, "C::Blocks expected closing curly brace but did not find it");
		
		if (*data->end == '\n') data->N_newlines++;
		still_working = my_parse_state.process_next_char(aTHX_ &my_parse_state);
		data->end++;
	} while (still_working);
}

void setup_compiler (pTHX_ TCCState * state, c_blocks_data * data) {
	/* Get and reset the compiler options */
	SV * compiler_options = get_sv("C::Blocks::compiler_options", 0);
	if (SvPOK(compiler_options)) tcc_set_options(state, SvPVbyte_nolen(compiler_options));
	SvSetMagicSV(compiler_options, get_sv("C::Blocks::default_compiler_options", 0));
	
	/* Ensure output goes to memory */
	tcc_set_output_type(state, TCC_OUTPUT_MEMORY);
	
	/* Set the error function to write to the error message SV */
	tcc_set_error_func(state, data->error_msg_sv, my_tcc_error_func);
}

void execute_compiler (pTHX_ TCCState * state, c_blocks_data * data, int keyword_type) {
	int len = (int)(data->end - PL_bufptr);
	
	/* Set the extended callback handling */
	#ifdef PERL_IMPLICIT_CONTEXT
		extended_symtab_callback_data callback_data = { state, aTHX, NULL, 0 };
	#else
		extended_symtab_callback_data callback_data = { state, NULL, 0 };
	#endif
	
	/* Set the extended symbol table lists if they exist */
	if (SvPOK(data->exsymtabs) && SvCUR(data->exsymtabs)) {
		callback_data.N_tables = SvCUR(data->exsymtabs) / sizeof(available_extended_symtab);
		callback_data.available_extended_symtabs = (available_extended_symtab*) SvPV_nolen(data->exsymtabs);
	}
	tcc_set_extended_symtab_callbacks(state, &my_symtab_lookup_by_name,
		&my_symtab_sym_used, &my_prep_table, &callback_data);
	
	/* set the predeclarations */
	if (keyword_type == IS_CBLOCK) {
		tcc_define_symbol(state, "C_BLOCK_PREDECLARATIONS",
			SvPVbyte_nolen(data->predeclarations));
		tcc_define_symbol(state, "MY_PERL_TYPE", data->my_perl_type);
	}
	
//printf("About to compile:\n-----\n%.*s\n-----\n", data->end - PL_bufptr, PL_bufptr);
	/* compile the code */
	tcc_compile_string_ex(state, PL_bufptr + 1 - data->keep_curly_brackets,
		data->end - PL_bufptr - 2 + 2*data->keep_curly_brackets, CopFILE(PL_curcop),
		CopLINE(PL_curcop));
	
	/* Handle any compilation errors */
	if (SvPOK(data->error_msg_sv)) {
		/* rewrite implicit function declarations as errors */
		char * loc;
		while(loc = strstr(SvPV_nolen(data->error_msg_sv),
			"warning: implicit declaration of function")
		) {
			/* replace "warning: implicit declaration of" with an error */
			sv_insert(data->error_msg_sv, loc - SvPV_nolen(data->error_msg_sv),
				32, "error: undeclared", 17);
		}
		/* Look for errors and croak */
		if (strstr(SvPV_nolen(data->error_msg_sv), "error")) {
			croak("C::Blocks compiler error:\n%s", SvPV_nolen(data->error_msg_sv));
		}
		/* Otherwise, look for warnings, warn, and clear */
		warn("C::Blocks compiler warning:\n%s", SvPV_nolen(data->error_msg_sv));
		SvPOK_off(data->error_msg_sv);
	}
}

OP * build_op(pTHX_ TCCState * state, int keyword_type) {
	/* build a null op if not creating a cblock */
	if (keyword_type != IS_CBLOCK) return newOP(OP_NULL, 0);
	
	/* get the function pointer for the block */
	IV pointer_IV = PTR2IV(tcc_get_symbol(state, "op_func"));
	if (pointer_IV == 0) {
		croak("C::Blocks internal error: got null pointer for op function!");
	}
	
	/* Store the address of the function pointer on the stack */
	OP * o = newUNOP(OP_RAND, 0, newSVOP(OP_CONST, 0, newSViv(pointer_IV)));
	
	/* Create an op that pops the address off the stack and invokes it */
	o->op_ppaddr = Perl_tcc_pp;
	
	return o;
}

void extract_xsub (pTHX_ TCCState * state, c_blocks_data * data) {
	/* Extract the xsub */
	XSUBADDR_t xsub_fcn_ptr = tcc_get_symbol(state, data->xsub_name);
	if (xsub_fcn_ptr == NULL)
		croak("C::Blocks internal error: Unable to get pointer to csub %s\n", data->xsub_name);
	
	/* Add the xsub to the package's symbol table */
	char * filename = CopFILE(PL_curcop);
	char * full_func_name = form("%s::%s", SvPVbyte_nolen(PL_curstname), data->xsub_name);
	newXS(full_func_name, xsub_fcn_ptr, filename);
}

void serialize_symbol_table(pTHX_ TCCState * state, c_blocks_data * data, int keyword_type) {
	SV * lib_to_link = get_sv("C::Blocks::library_to_link", 0);
	/* Build an extended symbol table to serialize */
	available_extended_symtab new_table;
	new_table.exsymtab = tcc_get_extended_symbol_table(state);
	
	/* Store the pointers to the extended symtabs so that we can clean up
	 * when everything is over. */
	AV * extended_symtab_cache = get_av("C::Blocks::__symtab_cache_array", GV_ADDMULTI | GV_ADD);
	av_push(extended_symtab_cache, newSViv(PTR2IV(new_table.exsymtab)));
	
	/* Get the dll pointer if this is linked against a dll */
	new_table.dll = NULL;
	if (SvPOK(lib_to_link) && SvCUR(lib_to_link) > 0) {
		new_table.dll = dynaloader_get_lib(aTHX_ SvPVbyte_nolen(lib_to_link));
		if (new_table.dll == NULL) {
			croak("C::Blocks/DynaLoader unable to load library [%s]",
				SvPVbyte_nolen(lib_to_link));
		}
		SvSetMagicSV_nosteal(lib_to_link, &PL_sv_undef);
	}
	
	/* add the serialized pointer address to the hints hash entry */
	if (SvPOK(data->exsymtabs)) {
		data->exsymtabs = newSVsv(data->exsymtabs);
		sv_catpvn(data->exsymtabs, (char*)&new_table, sizeof(available_extended_symtab));
	}
	else {
		data->exsymtabs = newSVpvn((char*)&new_table, sizeof(available_extended_symtab));
	}
	data->hints_hash = cophh_store_pvs(data->hints_hash, "C::Blocks/extended_symtab_tables", data->exsymtabs, 0);
	CopHINTHASH_set(PL_curcop, data->hints_hash);
	
	/* add the serialized pointer address to the package symtab list */
	if (keyword_type == IS_CSHARE) {
		SV * package_lists = get_sv(form("%s::__cblocks_extended_symtab_list",
			SvPVbyte_nolen(PL_curstname)), GV_ADDMULTI | GV_ADD);
		if (SvPOK(package_lists)) {
			sv_catpvn_mg(package_lists, (char*)&new_table, sizeof(available_extended_symtab));
		}
		else {
			sv_setpvn_mg(package_lists, (char*)&new_table, sizeof(available_extended_symtab));
		}
		
		/* Add C::Blocks::libloader to @ISA if necessary */
		use_parent_libloader(aTHX);
	}
}

int my_keyword_plugin(pTHX_
	char *keyword_ptr, STRLEN keyword_len, OP **op_ptr
) {
	/* See if this is a keyword we know */
	int keyword_type = identify_keyword(keyword_ptr, keyword_len);
	if (!keyword_type)
		return next_keyword_plugin(aTHX_ keyword_ptr, keyword_len, op_ptr);
	
	/**********************/
	/*   Initialization   */
	/**********************/
	
	/* Clear out any leading whitespace, including comments. Do this before
	 * initialization so that the assignment of the end pointer is correct. */
	lex_read_space(0);
	
	/* Create the compilation data struct */
	c_blocks_data data;
	initialize_c_blocks_data(aTHX_ &data);
	
	if (keyword_type == IS_CBLOCK) add_predeclaration_macros_to_block(aTHX);
	else if (keyword_type == IS_CSUB) fixup_xsub_name(aTHX_ &data);
	else if (keyword_type == IS_CSHARE || keyword_type == IS_CLEX) {
		data.keep_curly_brackets = 0;
	}
	add_msg_function_decl(aTHX_ &data);
	
	/************************/
	/* Extract and compile! */
	/************************/
	
	extract_C_code(aTHX_ &data, keyword_type);
	
	TCCState * state = tcc_new();
	if (!state) croak("Unable to create C::TinyCompiler state!\n");
	setup_compiler(aTHX_ state, &data);
	
	/* Ask to save state if it's a cshare or clex block*/
	if (keyword_type == IS_CSHARE || keyword_type == IS_CLEX) {
		tcc_save_extended_symtab(state);
	}
	
	/* Compile the extracted code */
	execute_compiler(aTHX_ state, &data, keyword_type);
	
	/******************************************/
	/* Apply the list of symbols and relocate */
	/******************************************/
	
	/* test symbols */
	if (SvOK(data.add_test_SV)) {
		tcc_add_symbol(state, "c_blocks_send_msg", _c_blocks_send_msg);
		tcc_add_symbol(state, "c_blocks_send_bytes", _c_blocks_send_bytes);
		tcc_add_symbol(state, "c_blocks_get_msg", _c_blocks_get_msg);
	}
	
	/* prepare for relocation; store in a global so that we can free everything
	 * at the end of the Perl program's execution. */
	AV * machine_code_cache = get_av("C::Blocks::__code_cache_array", GV_ADDMULTI | GV_ADD);
	SV * machine_code_SV = newSV(tcc_relocate(state, 0));
	int relocate_returned = tcc_relocate(state, SvPVX(machine_code_SV));
	if (SvPOK(data.error_msg_sv)) {
		/* Look for errors and croak */
		if (strstr(SvPV_nolen(data.error_msg_sv), "error")) {
			croak("C::Blocks linker error:\n%s", SvPV_nolen(data.error_msg_sv));
		}
		/* Otherwise report warnings */
		warn("C::Blocks linker warning:\n%s", SvPV_nolen(data.error_msg_sv));
	}
	if (relocate_returned < 0) {
		croak("C::Blocks linker error: unable to relocate\n");
	}
	av_push(machine_code_cache, machine_code_SV);
	
	/********************************************************/
	/* Build op tree or serialize the symbol table; cleanup */
	/********************************************************/

	*op_ptr = build_op(aTHX_ state, keyword_type);
	if (keyword_type == IS_CSUB) extract_xsub(aTHX_ state, &data);
	else if (keyword_type == IS_CSHARE || keyword_type == IS_CLEX) {
		serialize_symbol_table(aTHX_ state, &data, keyword_type);
	}
	
	/* cleanup */
	cleanup_c_blocks_data(aTHX_ &data);
	tcc_delete(state);
	
	/* insert a semicolon to make the parser happy */
	data.end--;
	*data.end = ';';

	lex_unstuff(data.end);
	/* Make the parser count the number of lines correctly */
	int i;
	for (i = 0; i < data.N_newlines; i++) lex_stuff_pv("\n", 0);
	
	/* Return success */
	return KEYWORD_PLUGIN_STMT;
}

MODULE = C::Blocks       PACKAGE = C::Blocks

void
_import()
CODE:
	if (PL_keyword_plugin != my_keyword_plugin) {
		PL_keyword_plugin = my_keyword_plugin;
	}
	
	/*
	COPHH* hints_hash = CopHINTHASH_get(PL_curcop);
	SV * extended_symtab_tables_SV = cophh_fetch_pvs(hints_hash, "C::Blocks/extended_symtab_tables", 0);
	if (extended_symtab_tables_SV == &PL_sv_placeholder) extended_symtab_tables_SV = newSVpvn("", 0);
	hints_hash = cophh_store_pvs(hints_hash, "C::Blocks/extended_symtab_tables", extended_symtab_tables_SV, 0);
	*/


void
unimport(...)
CODE:
	/* This appears to be broken. But I'll put it on the backburner
	 * for now and see if switching to Devel::CallChecker and
	 * Devel::CallParser fix it. */
	PL_keyword_plugin = next_keyword_plugin;

void
_cleanup()
CODE:
	/* Remove all of the extended symol tables. Note that the code pages
	 * were stored directly into Perl SV's, which were pushed into an
	 * array, so they are cleaned up for us automatically. */
	AV * cache = get_av("C::Blocks::__symtab_cache_array", GV_ADDMULTI | GV_ADD);
	int i;
	SV ** elem_p;
	for (i = 0; i < av_len(cache); i++) {
		elem_p = av_fetch(cache, i, 0);
		if (elem_p != 0) {
			tcc_delete_extended_symbol_table(INT2PTR(extended_symtab_p, SvIV(*elem_p)));
		}
		else {
			warn("C::Blocks had trouble freeing extended symbol table, index %d", i);
		}
	}

BOOT:
	/* Set up the keyword plugin to a useful initial value. */
	next_keyword_plugin = PL_keyword_plugin;
	
	/* Set up the custom op */
	XopENTRY_set(&tcc_xop, xop_name, "tccop");
	XopENTRY_set(&tcc_xop, xop_desc, "Op to run jit-compiled C code");
	Perl_custom_op_register(aTHX_ Perl_tcc_pp, &tcc_xop);
