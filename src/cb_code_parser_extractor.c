#include <cb_code_parser_extractor.h>

#include <cb_utils.h>

#define DPPP_PL_parser_NO_DUMMY
#include <ppport.h>


/********************************/
/**** Types and declarations ****/
/********************************/

typedef struct _parse_state parse_state;
typedef int (*parse_func_t)(pTHX_ parse_state *);

/* The behavior of the parser is contained in the following bit of
 * state. */
struct _parse_state {
	parse_func_t default_next_char; /* what we usually do */
	parse_func_t process_next_char; /* what we're doing next */
	c_blocks_data * data;           /* reference to c_blocks build state */
	char * sigil_start;             /* location where sigil found */
	int bracket_count;              /* unmatched open curly brackets */
	int interpolation_bracket_count_start; /* number of open brackets
											* when interpolation block began */
	int interpolation_line_number;  /* line number where interpolation block began */
	char delimiter;                 /* for delimited next_char parsing */
};



/* PARSE RESULTS: Return values for the character parse functions */
enum {
	PR_CLOSING_BRACKET, /* found the final closing bracket */
	PR_MAYBE_SIGIL,     /* found character which may be a sigil (@ or %) */
	PR_NON_SIGIL,       /* called does not need to worry about sigil
						 * handling: either not a sigil, or sigil_start
						 * was already set. */
};


/*********************************************/
/**** File internal function declarations ****/
/*********************************************/

static inline int is_id_cont (char to_check) {
	if('_' == to_check || ('0' <= to_check && to_check <= '9')
		|| ('A' <= to_check && to_check <= 'Z')
		|| ('a' <= to_check && to_check <= 'z')
		|| ':' == to_check) return 1;
	return 0;
}

static inline int is_whitespace_char(char to_check) {
	if (' ' == to_check || '\n' == to_check || '\r' == to_check || '\t' == to_check) {
		return 1;
	}
	return 0;
}


static int process_next_char_no_vars (pTHX_ parse_state * pstate);

/* FIXME: The following functions are UNIMPLEMENTED */
/* Note: I tried to address this once, but found it tricky. --David */
/* static int process_next_char_sigiled_block (pTHX_ parse_state * pstate); */
/* static int process_next_char_sigil_blocks_ok (pTHX_ parse_state * pstate); */

static int process_next_char_sigil_vars_ok (pTHX_ parse_state * pstate);
static int process_next_char_delimited (pTHX_ parse_state * pstate);
static int process_next_char_C_comment (pTHX_ parse_state * pstate);
static int process_next_char_post_sigil (pTHX_ parse_state * pstate);
static int process_next_char_sigiled_var (pTHX_ parse_state * pstate);

static int process_next_char_colon(pTHX_ parse_state * pstate);
static int execute_Perl_interpolation_block(pTHX_ parse_state * pstate);

static int call_init_cleanup_builder_method(pTHX_ parse_state * pstate,
	char * type, char * long_name, int var_offset);

static int direct_replace_double_colons(char * to_check);

static void find_end_of_xsub_name(pTHX_ c_blocks_data * data);

/************************/
/**** Implementation ****/
/************************/

/* Note: contents should *not* be added to code_main here, we need
 * LEX_KEEP_PREVIOUS. Sigiled variable names and interpolation blocks
 * both utilize the parser buffer to hold some stuff before they do
 * their work. */
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


/* Functions to quickly identify our keywords, assuming that the first letter has
 * already been checked and found to be 'c' */
int cb_identify_keyword (char * keyword_ptr, STRLEN keyword_len) {
	if (keyword_ptr[0] != 'c') return 0;
	if (keyword_len == 2) {
		if (keyword_ptr[1] == 'q') return IS_CQ;
		return 0;
	}
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

void cb_fixup_xsub_name(pTHX_ c_blocks_data * data) {
	/* Find where the name ends, copy it, and replace it with the correct
	 * declaration */
	
	/* Find the name */
	find_end_of_xsub_name(aTHX_ data);
	data->xsub_name = savepvn(PL_bufptr, data->end - PL_bufptr);
	
	/* create the package name */
	char * name_buffer = form("%s::%s", SvPVbyte_nolen(PL_curstname),
		data->xsub_name);
	data->xs_perl_name = savepv(name_buffer);
	int perl_name_length = strlen(name_buffer);
	
	/* create the related, munged c function name. */
	Newx(data->xs_c_name, perl_name_length + 4, char);
	data->xs_c_name[0] = 'x';
	data->xs_c_name[1] = 's';
	data->xs_c_name[2] = '_';
	int i;
	for (i = 0; i <= perl_name_length; i++) {
		if (data->xs_perl_name[i] == ':')
			data->xs_c_name[i+3] = '_';
		else
			data->xs_c_name[i+3] = data->xs_perl_name[i];
	}
	
	/* copy also into the main code container */
	sv_catpvf(data->code_main, "XSPROTO(%s) {", data->xs_c_name);
	
	/* remove the name from the buffer. At the moment, data->end points
	 * to the first character *after* the name, so we are resetting the
	 * start of the buffer to *that* character. */
	lex_unstuff(data->end);
}

char * cb_replace_double_colons_with_double_underscores(pTHX_ SV * to_replace) {
	/* Replace any double-colons with double-underscores */
	int is_in_string;
	STRLEN i, len;
	char * to_return;
	
	to_return = SvPV(to_replace, len);
	is_in_string = to_return[0] == '"';
	for (i = 1; i < len; i++) {
		if (is_in_string) {
			if (to_return[i] == '"' && to_return[i-1] != '\\') {
				is_in_string = 0;
			}
		}
		else {
			if (to_return[i-1] == ':' && to_return[i] == ':') {
				to_return[i-1] = to_return[i] = '_';
			}
			else if (to_return[i] == '"' && to_return[i-1] != '\\') {
				is_in_string = 1;
			}
		}
	}
	return to_return;
}



void cb_extract_c_code(pTHX_ c_blocks_data * data, int keyword_type) {
	/* copy data out of the buffer until we encounter the matching
	 * closing bracket, accounting for brackets that may occur in
	 * comments and strings. Process sigiled variables as well. */
	
	/* Set up the parser state */
	parse_state my_parse_state;
	my_parse_state.data = data;
	my_parse_state.sigil_start = 0;
	my_parse_state.bracket_count = 0;
	my_parse_state.interpolation_bracket_count_start = 0;
	if (keyword_type == IS_CBLOCK) {
		my_parse_state.process_next_char = process_next_char_sigil_vars_ok;
		my_parse_state.default_next_char = process_next_char_sigil_vars_ok;
	}
	else {
		my_parse_state.process_next_char = process_next_char_no_vars;
		my_parse_state.default_next_char = process_next_char_no_vars;
	}
	
	
	data->end = PL_bufptr;
	int still_working;
	do {
		ENSURE_LEX_BUFFER(data->end, "C::Blocks expected closing curly brace but did not find it");
		
		if (*data->end == '\n') data->N_newlines++;
		still_working = my_parse_state.process_next_char(aTHX_ &my_parse_state);
		data->end++;
	} while (still_working);
	
	/* Finish by moving the (remaining) contents of the lexical buffer
	 * into the main code container. Don't copy the final bracket, so
	 * that bottom's code can be appended later. */
	sv_catpvn(data->code_main, PL_bufptr, data->end - PL_bufptr - 1);
	/* end points to the first character after the closing bracket,
	 * which is where we want PL_bufptr to be, so update it. */
	lex_unstuff(data->end);
	data->end = PL_bufptr;
	/* Add the closing bracket to the end, if appropriate */
	if (data->keep_curly_brackets) sv_catpvn(data->code_bottom, "}", 1);
}

/* Replace :: with __  in NUL terminated string */
static int direct_replace_double_colons(char * to_check) {
	if (to_check[0] == 0) return 0;
	int found = 0;
	for (to_check++; *to_check != 0; to_check++) {
		if (to_check[-1] == ':' && to_check[0] == ':') {
			to_check[-1] = to_check[0] = '_';
			found = 1;
		}
	}
	return found;
}


/* Base parser, and default text parser for clex and cshare. This parser
 * does not handle variables, but it does track where $-sigils are found
 * because interpolation blocks can be used anywhere. This is written
 * such that the variable-handling parsers call this function first, and
 * perform follow-ups if they get PR_MAYBE_SIGIL. Reinstates normal
 * parsing after interpolation blocks have been identified.
 *
 * NOTE: this is used also to extract Perl interpolation blocks. It is
 * smart enough not to interfere with double-colons or sigils, and that
 * handles all concerns *except* for comments or pod with unmatched
 * curly brackets. It would be nice to have a specialized Perl-code
 * parser, but for now this is sufficient. */
static int process_next_char_no_vars (pTHX_ parse_state * pstate) {
	switch (pstate->data->end[0]) {
		case '{':
			pstate->bracket_count++;
			if (pstate->bracket_count == 1) {
				/* Remove first bracket from the buffer */
				lex_unstuff(pstate->data->end + 1);
				pstate->data->end = PL_bufptr - 1;
			}
			return PR_NON_SIGIL;
		case '}':
			pstate->bracket_count--;
			if (pstate->bracket_count == 0) return PR_CLOSING_BRACKET;
			if (pstate->interpolation_bracket_count_start == pstate->bracket_count)
				return execute_Perl_interpolation_block(aTHX_ pstate);
			return PR_NON_SIGIL;
		case '\'': case '\"':
			/* Setup "delimited" extraction state, matching on the
			 * quotation character we just saw. */
			pstate->process_next_char = process_next_char_delimited;
			pstate->delimiter = pstate->data->end[0];
			return PR_NON_SIGIL;
		case '/':
			if (pstate->data->end > PL_bufptr && pstate->data->end[-1] == '/') {
				/* Handling C++ style comments is easy. They run until
				 * the newline, so set up a parse state that is
				 * delimited by a newline :-) */
				pstate->process_next_char = process_next_char_delimited;
				pstate->delimiter = '\n';
			}
			return PR_NON_SIGIL;
		case '*':
			if (pstate->data->end > PL_bufptr && pstate->data->end[-1] == '/') {
				/* C-style comments have their own parser */
				pstate->process_next_char = process_next_char_C_comment;
			}
			return PR_NON_SIGIL;
		case ':':
			/* No processing if we're extracting an interpolation block */
			if (pstate->interpolation_bracket_count_start) return PR_NON_SIGIL;
			/* This is a colon following something other than a colon,
			   and outside an interpolation block. Set up the parser to
			   detect and act on a potential second colon. */
			pstate->process_next_char = process_next_char_colon;
			return PR_NON_SIGIL;
		case '$':
			/* No processing if we're extracting an interpolation block */
			if (pstate->interpolation_bracket_count_start) return PR_NON_SIGIL;
			/* Otherwise setup post-sigil handling. Clear out the
			 * lexical buffer up to but not including this character
			 * and set up the parser. */
			sv_catpvn(pstate->data->code_main, PL_bufptr,
				pstate->data->end - PL_bufptr);
			lex_unstuff(pstate->data->end);
			pstate->data->end = PL_bufptr;
			pstate->process_next_char = process_next_char_post_sigil;
			pstate->sigil_start = pstate->data->end;
			return PR_NON_SIGIL;
			
	}
	/* Out here means it's not one of the special characters considered
	 * above, though it may be an array or hash sigil. */
	return PR_MAYBE_SIGIL;
}

/* Default text parser for cblock */
static int process_next_char_sigil_vars_ok (pTHX_ parse_state * pstate) {
	int no_vars_result = process_next_char_no_vars(aTHX_ pstate);
	if (no_vars_result != PR_MAYBE_SIGIL) return no_vars_result;
	if (*pstate->data->end == '@' || *pstate->data->end == '%') {
		/* Clear out the lexical buffer up to but not including this
		 * character. */
		sv_catpvn(pstate->data->code_main, PL_bufptr,
			pstate->data->end - PL_bufptr);
		lex_unstuff(pstate->data->end);
		pstate->data->end = PL_bufptr;
		
		/* Set up the variable name extractor */
		pstate->process_next_char = process_next_char_post_sigil;
		pstate->sigil_start = pstate->data->end;
	}
	return PR_NON_SIGIL;
}

static int process_next_char_delimited (pTHX_ parse_state * pstate) {
	if (pstate->data->end[0] == pstate->delimiter && pstate->data->end[-1] != '\\') {
		/* Reset to normal parse state */
		pstate->process_next_char = pstate->default_next_char;
	}
	else if (pstate->delimiter != '\n' && pstate->data->end[0] == '\n') {
		/* Strings do not wrap */
		pstate->process_next_char = pstate->default_next_char;
	}
	return PR_NON_SIGIL;
}

static int process_next_char_C_comment (pTHX_ parse_state * pstate) {
	if (pstate->data->end[0] == '/' && pstate->data->end[-1] == '*') {
		/* Found comment closer. Reset to normal parse state */
		pstate->process_next_char = pstate->default_next_char;
	}
	return PR_NON_SIGIL;
}

static int process_next_char_colon(pTHX_ parse_state * pstate) {
	/* No matter what, reset to the default parser. */
	pstate->process_next_char = pstate->default_next_char;
	if (pstate->data->end[0] == ':') {
		/* we just encountered a double-colon. Replace it with a
		   double-underscore. */
		pstate->data->end[0] = pstate->data->end[-1] = '_';
		/* Indicate we've handled this character */
		return PR_NON_SIGIL;
	}
	/* revert to the default parser to handle this character since it is
	   not a colon. */
	return pstate->default_next_char(aTHX_ pstate);
}

static int process_next_char_post_sigil(pTHX_ parse_state * pstate) {
	/* Only called on the first character after the sigil. */
	
	/* If the sigil is a dollar sign and the next character is an
	 * opening bracket, then we have an interpolation block. */
	if (pstate->data->end[-1] == '$' && pstate->data->end[0] == '{') {
		pstate->process_next_char = process_next_char_no_vars;
		pstate->interpolation_bracket_count_start = pstate->bracket_count++;
		pstate->interpolation_line_number = CopLINE(PL_curcop) + pstate->data->N_newlines;
		return PR_NON_SIGIL;
	}
	
	/* IF our default parser accepts sigiled variables, then check for a
	 * valid identifier character and set up continued searching for the
	 * end of the variable name. */
	if (pstate->default_next_char == process_next_char_sigil_vars_ok
		&& is_id_cont(pstate->data->end[0]))
	{
		pstate->process_next_char = process_next_char_sigiled_var;
		return PR_NON_SIGIL;
	}
	
	/* We either have a lone sigil character followed by a space or a
	 * sigiled variable name being parsed when sigiled variable names
	 * are not allowed. Reset the state and defer to the default
	 * handler. */
	pstate->process_next_char = pstate->default_next_char;
	return pstate->default_next_char(aTHX_ pstate);
}

static int process_next_char_sigiled_var(pTHX_ parse_state * pstate) {
	/* keep collecting if the current character looks like a valid
	 * identifier character */
	if (is_id_cont(pstate->data->end[0])) return PR_NON_SIGIL;
	
	/* We just identified the character that is one past the end of our
	 * Perl variable name. Identify the type and construct the mangled
	 * name for the C-side variable. */
	char backup = *pstate->data->end;
	*pstate->data->end = '\0';
	char * type;
	char * long_name;
	if (*pstate->sigil_start == '$') {
		type = "SV";
		long_name = savepv(form("_PERL_SCALAR_%s", 
			pstate->sigil_start + 1));
	}
	else if (*pstate->sigil_start == '@') {
		type = "AV";
		long_name = savepv(form("_PERL_ARRAY_%s", 
			pstate->sigil_start + 1));
	}
	else if (*pstate->sigil_start == '%') {
		type = "HV";
		long_name = savepv(form("_PERL_HASH_%s", 
			pstate->sigil_start + 1));
	}
	else {
		/* should never happen */
		*pstate->data->end = backup;
		croak("C::Blocks internal error: unknown sigil %c\n",
			*pstate->sigil_start);
	}
	
	/* replace any double-colons */
	int is_package_global = direct_replace_double_colons(long_name);
	
	/* Check if we need to add a declaration for the C-side variable */
	if (strstr(SvPVbyte_nolen(pstate->data->code_top), long_name) == NULL) {
		/* Add a new declaration for it */
		
		/* NOTE: pad_findmy_pv expects the sigil, but get_sv/get_av/get_hv
		   do not!! */
		
		if (is_package_global) {
			sv_catpvf(pstate->data->code_top, "%s * %s = (%s(\"%s\", GV_ADD)); ",
				type, long_name,
				  *pstate->sigil_start == '$' ? "get_sv"
				: *pstate->sigil_start == '@' ? "get_av"
				:                               "get_hv",
				pstate->sigil_start + 1);
		}
		else {
			int var_offset = (int)pad_findmy_pv(pstate->sigil_start, 0);
			/* Ensure that the variable exists in the pad */
			if (var_offset == NOT_IN_PAD) {
				CopLINE(PL_curcop) += pstate->data->N_newlines;
				*pstate->data->end = backup;
				croak("Could not find lexically scoped \"%s\"",
					pstate->sigil_start);
			}
			
			/* If the variable has an annotated type, use the type's
			 * code builder. Otherwise, declare the basic type. */
			if (!call_init_cleanup_builder_method(aTHX_ pstate, type,
					long_name, var_offset))
			{
				sv_catpvf(pstate->data->code_top, "%s * %s = (%s*)PAD_SV(%d); ",
					type, long_name, type, var_offset);
			}
		}
	}
	
	/* Reset the character just following the var name */
	*pstate->data->end = backup;
	
	/* Add the long name to the main code block in place of the sigiled
	 * expression, and remove the sigiled varname from the buffer. */
	sv_catpv_nomg(pstate->data->code_main, long_name);
	lex_unstuff(pstate->data->end);
	pstate->data->end = PL_bufptr;
	
	/* Cleanup memory */
	Safefree(long_name);
	
	/* Reset the parser state and process the current character with
	 * the default parser */
	pstate->process_next_char = pstate->default_next_char;
	return pstate->default_next_char(aTHX_ pstate);
}

/* Support for type-annotated variables. Save the SV in an even
 * more obfuscated variable, and the given type in the expected
 * variable. */
static int call_init_cleanup_builder_method(pTHX_ parse_state * pstate,
	char * type, char * long_name, int var_offset)
{
	/* does this variable have a type? */
	HV * stash = PAD_COMPNAME_TYPE(var_offset);
	if (stash == 0) return 0;
	
	/* get the method; warn and exit if we can't find it */
	GV * declaration_gv;
	CV * declaration_cv;
	declaration_gv = gv_fetchmeth_autoload(stash, "c_blocks_init_cleanup", 21, 0);
	if (declaration_gv != 0) declaration_cv = GvCV(declaration_gv);
	if (declaration_gv == 0 || declaration_cv == 0) {
		cb_warnif (aTHX_ "type", sv_2mortal(newSVpvf("C::Blocks could "
			"not find method 'c_blocks_init_cleanup' for %s's type, %s",
			pstate->sigil_start, HvENAME(stash))));
		return 0;
	}
	
	/* prepare the call stack for the init_cleanup method */
	dSP;
	int count;
	ENTER;
	SAVETMPS;
	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newSVpv(HvENAME(stash), 0))); // class name
	XPUSHs(sv_2mortal(newSVpv(long_name, 0))); // long C name
	XPUSHs(sv_2mortal(newSVpv(type, 0)));      // var type: SV, AV, HV
	XPUSHs(sv_2mortal(newSViv(var_offset)));   // pad offset
	PUTBACK;
	
	/* call the init_cleanup method */
	count = call_sv((SV*)declaration_cv, G_ARRAY); /* G_EVAL | G_KEEPERR ??? */
	SPAGAIN;
	
	/* make sure we got the init and cleanup code */
	while (count > 2) {
		POPs;
		count--;
	}
	if (count == 2) {
		sv_catpv_nomg(pstate->data->code_bottom, 
			cb_replace_double_colons_with_double_underscores(aTHX_ POPs));
		count--;
	}
	if (count == 1) {
		sv_catpv_nomg(pstate->data->code_top, 
			cb_replace_double_colons_with_double_underscores(aTHX_ POPs));
	}
	
	/* final stack cleanup */
	PUTBACK;
	FREETMPS;
	LEAVE;
	
	/* warn and return failure if we didn't get any return values */
	if (count == 0) {
		cb_warnif (aTHX_ "type", sv_2mortal(newSVpvf("C::Blocks expected "
			"one or two return values from %s::c_blocks_init_cleanup' "
			"but got none", HvENAME(stash))));
		return 0;
	}

	// success!
	return 1;
}

static void find_end_of_xsub_name(pTHX_ c_blocks_data * data) {
	data->end = PL_bufptr;
	
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
		else if (is_whitespace_char(*data->end) || *data->end == '{') {
			break;
		}
		else if (!is_id_cont(*data->end)){
			croak("C::Blocks csub name can contain only underscores, letters, and numbers");
		}
		
		data->end++;
	}
}

static int execute_Perl_interpolation_block(pTHX_ parse_state * pstate) {
	/* Temporarily replace the closing bracket with null so we can
	 * use it as a null-terminated string in the following newSVpvf. */
	*pstate->data->end = '\0';
	
	int N_newlines_added = 0;
	int i;
	/* Note first two chars are '$' and '{', so skip those */
	for (i = 2; pstate->sigil_start[i]; i++) {
		/* newlines in the interpolation block are going to be removed,
		 * so subtract. */
		if (pstate->sigil_start[i] == '\n') N_newlines_added--;
	}
	
	/* Create a string with proper package and line number information */
	SV * to_eval = newSVpvf("package %s;\n#line %d \"%s\"\n%s",
		SvPVbyte_nolen(PL_curstname),
		pstate->interpolation_line_number,
		CopFILE(PL_curcop),
		pstate->sigil_start + 2
	);
	/* mortalize so it goes away soon */
	sv_2mortal(to_eval);
	SV * returned_sv = eval_pv(SvPVbyte_nolen(to_eval), 1);
	
	char * fixed_returned
		= cb_replace_double_colons_with_double_underscores(aTHX_ returned_sv);
	
	/* count the lines added */
	for (i = 0; fixed_returned[i]; i++) {
		if (fixed_returned[i] == '\n') N_newlines_added++;
	}
	
	
	/* Replace the interpolation block with contents of eval. Be sure
	 * to get rid of the entire block up to the closing bracket, which
	 * is now the null character added above. */
	sv_catpv_nomg(pstate->data->code_main, fixed_returned);
	sv_catpvf(pstate->data->code_main, "\n#line %d \"%s\"\n",
		CopLINE(PL_curcop) + pstate->data->N_newlines + N_newlines_added,
		CopFILE(PL_curcop)
	);
	/* Set the buffer so it begins with the first character after the
	 * closing curly bracket */
	lex_unstuff(pstate->data->end + 1);
	/* Set the end so that it advances *to* the first character in the buffer */
	pstate->data->end = PL_bufptr - 1;
//	SvREFCNT_dec(returned_sv); // XXX is this correct?
	
	/* XXX working here - add #line to make sure tcc correctly indicates
	 * the line number of material that follows. There is no guarantee
	 * that the evaluated text has the same number of lines as the
	 * original block of Perl code just evaluated. */
	
	/* Return to default parse state */
	pstate->sigil_start = 0;
	pstate->process_next_char = pstate->default_next_char;
	pstate->interpolation_bracket_count_start = 0;
	
	/* There shall not be any need for sigil handling by any calling
	 * parsers. */
	return PR_NON_SIGIL;
}

