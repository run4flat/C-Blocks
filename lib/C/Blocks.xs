#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "libtcc.h"

int (*next_keyword_plugin)(pTHX_ char *, STRLEN, OP **);

typedef void (*my_void_func)(pTHX);

typedef struct _extsym_table {
	TokenSym_p* tokensym_list;
	TCCState * state;
	void * dll;
} extsym_table;

XOP tcc_xop;
PP(tcc_pp) {
    dVAR;
    dSP;
	IV pointer_iv = POPi;
	my_void_func p_to_call = INT2PTR(my_void_func, pointer_iv);
	p_to_call(aTHX);
	RETURN;
}

/*********************/
/**** linked list ****/
/*********************/

typedef struct _identifier_ll {
	char * name;
	void * pointer;
	struct _identifier_ll * next;
} identifier_ll;

/* ---- Extended symbol table handling ---- */
typedef struct _ext_sym_callback_data {
	TCCState * state;
	#ifdef PERL_IMPLICIT_CONTEXT
		tTHX my_perl;  /* name of field is my_perl, according to perl.h */
	#endif
	extsym_table * extsym_tables;
	int N_tables;
	TokenSym_p* new_symtab;
	identifier_ll* identifiers;
} ext_sym_callback_data;

void add_identifier (ext_sym_callback_data * callback_data, char * name, void * pointer) {
	/* Build the identifier */
	identifier_ll* new_id;
	Newx(new_id, 1, identifier_ll);
	new_id->name = name;
	new_id->pointer = pointer;
	new_id->next = NULL;
	
	/* Find where to put it */
	if (callback_data->identifiers == NULL) {
		callback_data->identifiers = new_id;
		return;
	}
	identifier_ll* id = callback_data->identifiers;
	while(id->next != NULL) id = id->next;
	id->next = new_id;
}

void apply_and_clear_identifiers (ext_sym_callback_data * callback_data) {
	if (callback_data->identifiers == NULL) return;
	identifier_ll * curr = callback_data->identifiers;
	identifier_ll * next;
	while(curr) {
		next = curr->next;
		tcc_add_symbol(callback_data->state, curr->name, curr->pointer);
		Safefree(curr);
		curr = next;
	}
}

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

/*****************************************/
/**** Extended symbol table callbacks ****/
/*****************************************/

void my_copy_symtab(TokenSym_p* copied_symtab, void * data) {
	/* Unpack the callback data */
	ext_sym_callback_data * callback_data = (ext_sym_callback_data*)data;
	callback_data->new_symtab = copied_symtab;
}
TokenSym_p my_symtab_lookup_by_name(char * name, int len, void * data, int is_identifier) {
	/* Unpack the callback data */
	ext_sym_callback_data * callback_data = (ext_sym_callback_data*)data;
	
	char name_to_find[len + 1];
	strncpy(name_to_find, name, len);
	name_to_find[len] = '\0';
	
	/* Run through all of the available external symbol lists and look for this
	 * identifier. This could be sped up, eventually, with a hash lookup. */
	int i, j;
	for (i = 0; i < callback_data->N_tables; i++) {
		TokenSym_p* ts_list = callback_data->extsym_tables[i].tokensym_list;
		int list_length = tcc_tokensym_list_length(ts_list);
		for (j = 0; j < list_length; j++) {
			char * curr_name = tcc_tokensym_name(ts_list[j]);
			if (strcmp(curr_name, name_to_find) == 0) return ts_list[j];
		}
	}
	
	return NULL;
}
TokenSym_p my_symtab_lookup_by_number(int tok_id, void * data, int is_identifier) {
	/* Unpack the callback data */
	ext_sym_callback_data * callback_data = (ext_sym_callback_data*)data;
	
	/* Run through all of the available TokenSym lists and look for this token.
	 */
	int i;
	for (i = 0; i < callback_data->N_tables; i++) {
		TokenSym_p* ts_list = callback_data->extsym_tables[i].tokensym_list;
		TokenSym_p ts = tcc_tokensym_by_tok(tok_id, ts_list);
		if (ts != NULL) {
			if (is_identifier) {
				/* Retrieve the pointer; add it to a linked list of items to
				 * add after the compilation has finished. */
				char * name = tcc_tokensym_name(ts);
				void * pointer;
				if (callback_data->extsym_tables[i].state) {
					pointer
						= tcc_get_symbol(callback_data->extsym_tables[i].state,
							name);
				}
				else if (callback_data->extsym_tables[i].dll) {
					#ifdef PERL_IMPLICIT_CONTEXT
						pointer = dynaloader_get_symbol(callback_data->my_perl,
							callback_data->extsym_tables[i].dll, name);
					#else
						pointer = dynaloader_get_symbol(
							callback_data->extsym_tables[i].dll, name);
					#endif
				}
				else {
					croak("C::Blocks internal error: extsym_table had neither state nor dll entry");
				}
				if (pointer != NULL) {
					add_identifier(callback_data, name, pointer);
				}
			}
			return ts;
		}
	}
	
	return NULL;
}

/************************/
/**** Error handling ****/
/************************/

/* Error handling should store the message and return to the normal execution
 * order. In other words, croak is inappropriate here. */
void my_tcc_error_func (void * message_ptr, const char * msg ) {
	SV* message_sv = (SV*)message_ptr;
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

enum { IS_CBLOCK = 1, IS_CSHARE, IS_CLEX, IS_CSUB, IS_CUSE } keyword_type;

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
		
		if (	keyword_ptr[1] == 'u'
			&&	keyword_ptr[2] == 's'
			&&	keyword_ptr[3] == 'e') return IS_CUSE;
		
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

#define ENSURE_LEX_BUFFER(croak_message)                        \
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


void keyword_cuse(pTHX_
	char *keyword_ptr, STRLEN keyword_len, OP **op_ptr
) {
}

int my_keyword_plugin(pTHX_
	char *keyword_ptr, STRLEN keyword_len, OP **op_ptr
) {
	char * package_suffix = "__cblocks_tokensym_list";
	int N_newlines = 0;
	
	/* See if this is a keyword we know */
	int keyword_type = identify_keyword(keyword_ptr, keyword_len);
	if (!keyword_type)
		return next_keyword_plugin(aTHX_ keyword_ptr, keyword_len, op_ptr);
	
	/* Clear out any leading whitespace, including comments */
	lex_read_space(0);
	char *end = PL_bufptr;
	
	/**********************/
	/*   Initialization   */
	/**********************/
	
	/* Get the hint hash for later retrieval */
	COPHH* hints_hash = CopHINTHASH_get(PL_curcop);
	SV * extsym_tables_SV = cophh_fetch_pvs(hints_hash, "C::Blocks/tokensym_tables", 0);
	if (extsym_tables_SV == &PL_sv_placeholder) extsym_tables_SV = newSVpvn("", 0);
	
	int keep_curly_brackets = 1;
	char * xsub_name = NULL;
	if (keyword_type == IS_CBLOCK) {
		/* check if libperl is loaded; if so, use pTHX */
		if (0) {
			lex_stuff_pv("void op_func(pTHX)", 0);
		}
		else {
			#ifdef PERL_IMPLICIT_CONTEXT
				lex_stuff_pv("void op_func(void * my_perl)", 0);
			#else
				lex_stuff_pv("void op_func()", 0);
			#endif
		}
	}
	else if (keyword_type == IS_CSUB) {
		/* Load libperl if it's not already loaded */
		if (0) {
			/* load libperl, add to this context */
		}
		/* extract the function name */
		while (1) {
			ENSURE_LEX_BUFFER(
				end == PL_bufptr
				? "C::Blocks encountered the end of the file before seeing the csub name"
				: "C::Blocks encountered the end of the file before seeing the body of the csub"
			);
			if (end == PL_bufptr) {
				if(!isIDFIRST(*end)) croak("C::Blocks expects a name after csub");
			}
			else if (_is_whitespace_char(*end) || *end == '{') {
				break;
			}
			else if (!_is_id_cont(*end)){
				croak("C::Blocks csub name can contain only underscores, letters, and numbers");
			}
			
			end++;
		}
		/* Having reached here, the xsub name ends one character before end.
		 * Copy that name, then clobber the buffer up to (but not including)
		 * the end. */
		xsub_name = savepvn(PL_bufptr, end - PL_bufptr);
		lex_unstuff(end);

		/* re-add what we want in reverse order (LIFO) */
		lex_stuff_pv(")", 0);
		lex_stuff_pv(xsub_name, 0);
		lex_stuff_pv("XS_INTERNAL(", 0);
	}
	else if (keyword_type == IS_CSHARE || keyword_type == IS_CLEX) {
		keep_curly_brackets = 0;
	}
	else if (keyword_type == IS_CUSE) {
		/* Extract the stash name */
		while (1) {
			ENSURE_LEX_BUFFER("C::Blocks encountered the end of the file before seeing the cuse package name");
			
			if (end == PL_bufptr && !isIDFIRST(*end)) {
				/* Invalid first character. */
				croak("C::Blocks cuse name must be a valid Perl package name");
			}
			else if (_is_whitespace_char(*end) || *end == ';') {
				break;
			}
			else if (!_is_id_cont(*end) && *end != ':'){
				croak("C::Blocks cuse name must be a valid Perl package name");
			}
			end++;
		}
		
		/* Having reached here, we should have a valid package name. See if
		 * the package global already exists, and use it if so. */
		SV * import_package_name = newSVpv(PL_bufptr, end - PL_bufptr);
		SV * tokensym_list_name = newSVsv(import_package_name);
		sv_catpvf(tokensym_list_name, "::%s", package_suffix);
		SV * imported_tables_SV = get_sv(SvPVbyte_nolen(tokensym_list_name), 0);
		
		/* Otherwise, try importing a module with the given name and check
		 * again. */
		if (imported_tables_SV == NULL) {
			load_module(PERL_LOADMOD_NOIMPORT, import_package_name, NULL, NULL);
			
			imported_tables_SV = get_sv(SvPVbyte_nolen(tokensym_list_name), 0);
			if (imported_tables_SV == NULL) {
				croak("C::Blocks did not find any shared blocks in package %s",
					SvPVbyte_nolen(import_package_name));
			}
		}
		
		/* Copy these to the hints hash entry, creating said entry if necessary */
		sv_catsv_mg(extsym_tables_SV, imported_tables_SV);
		hints_hash = cophh_store_pvs(hints_hash, "C::Blocks/tokensym_tables", extsym_tables_SV, 0);
		CopHINTHASH_set(PL_curcop, hints_hash);
		
		/* Mortalize the SVs so they get cleared eventually. */
		//sv_2mortal(import_package_name);  // XXX why not mortalize this?
		sv_2mortal(tokensym_list_name);
		
		/* Replace this keyword with a null op */
		*op_ptr = newOP(OP_NULL, 0);
		
		/* Skip over all the rest until the end of the function. */
		goto all_done;
	}
	
	/**********************/
	/* Extract the C code */
	/**********************/
	
	/* expand the buffer until we encounter the matching closing bracket */
	int nest_count = 0;
	end = PL_bufptr;
	while (1) {
		ENSURE_LEX_BUFFER("C::Blocks expected closing curly brace but did not find it");
		
		if (*end == '{') nest_count++;
		else if (*end == '}') {
			nest_count--;
			if (nest_count == 0) break;
		}
		else if (*end == '\n') {
			N_newlines++;
		}
		
		end++;
	}
	end++;
	
	/************/
	/* Compile! */
	/************/
	
	int len = (int)(end - PL_bufptr);
	
	/* Build the compiler */
	TCCState * state = tcc_new();
	if (!state) {
		croak("Unable to create C::TinyCompiler state!\n");
	}
	
	/* Get and reset the compiler options */
	SV * compiler_options = get_sv("C::Blocks::compiler_options", 0);
	tcc_set_options(state, SvPVbyte_nolen(compiler_options));
	SvSetMagicSV(compiler_options, get_sv("C::Blocks::default_compiler_options", 0));
	
	/* Setup error handling */
	SV * error_msg_sv = newSV(0);
	tcc_set_error_func(state, error_msg_sv, my_tcc_error_func);
	tcc_set_output_type(state, TCC_OUTPUT_MEMORY);
	
	/* Set the extended callback handling */
	#ifdef PERL_IMPLICIT_CONTEXT
		ext_sym_callback_data callback_data = { state, aTHX, NULL, 0, NULL, NULL };
	#else
		ext_sym_callback_data callback_data = { state, NULL, 0, NULL, NULL };
	#endif
	/* Set the extended symbol table lists if they exist */
	if (SvPOK(extsym_tables_SV) && SvCUR(extsym_tables_SV)) {
		callback_data.N_tables = SvCUR(extsym_tables_SV) / sizeof(extsym_table);
		callback_data.extsym_tables = (extsym_table*) SvPV_nolen(extsym_tables_SV);
	}
	extended_symtab_copy_callback copy_callback
		= (keyword_type == IS_CSHARE || keyword_type == IS_CLEX)
		?	&my_copy_symtab
		:	NULL;
	tcc_set_extended_symtab_callbacks(state,
		copy_callback,
		&my_symtab_lookup_by_name, &my_symtab_lookup_by_number, 
		&callback_data
	);
	
	/* compile the code */
	tcc_compile_string_ex(state, PL_bufptr + 1 - keep_curly_brackets,
		end - PL_bufptr - 2 + 2*keep_curly_brackets, CopFILE(PL_curcop),
		CopLINE(PL_curcop));
	
	/*****************************/
	/* Handle compilation errors */
	/*****************************/
	if (SvPOK(error_msg_sv)) {
		if (strstr(SvPV_nolen(error_msg_sv), "error")) {
			croak("C::Blocks error:\n%s", SvPV_nolen(error_msg_sv));
		}
		else {
			warn("C::Blocks warning:\n%s", SvPV_nolen(error_msg_sv));
		}
	}
	
	/******************************************/
	/* Apply the list of symbols and relocate */
	/******************************************/
	
	apply_and_clear_identifiers(&callback_data);
	
	/* Link to statically linked library, if appropriate and capable */
	SV * lib_to_link = get_sv("C::Blocks::library_to_link", 0);
	if (SvPOK(lib_to_link) && SvCUR(lib_to_link) > 3) {
		STRLEN len;
		char * lib_string = SvPVbyte(lib_to_link, len);
		#ifdef __APPLE__
			if (lib_string[len-1] == 'a' && lib_string[len-2] == '.') {
				croak("C::Blocks does not yet support static libraries on Mac");
			}
			// consider converting using this formula:
			// http://stackoverflow.com/questions/16082470/osx-how-do-i-convert-a-static-library-to-a-dynamic-one
		#else
			if
			#ifdef __GNUC__
				(lib_string[len-1] == 'a' && lib_string[len-2] == '.')
			#else
				( && lib_string[len-4] == '.' && lib_string[len-3] == 'l'
				  && lib_string[len-2] == 'i' && lib_string[len-1] == 'b')
			#endif
				{
					int return_value = tcc_add_library(state, lib_string);
					if (return_value) {
						croak("C::Blocks: Unable to load static library [%s]", lib_string);
					}
					SvSetMagicSV_nosteal(lib_to_link, &PL_sv_undef);
				}
		#endif
	}
	
	/* prepare for relocation; store in a global so that we can free everything
	 * at the end of the Perl program's execution. */
	AV * machine_code_cache = get_av("C::Blocks::__code_cache_array", 1);
	SV * machine_code_SV = newSV(tcc_relocate(state, 0));
	tcc_relocate(state, SvPVX(machine_code_SV));
	av_push(machine_code_cache, machine_code_SV);
	
	/********************************************************/
	/* Build the op tree or serialize the tokensym pointers */
	/********************************************************/

	if (keyword_type == IS_CBLOCK) {
		/* build the optree. */
		IV pointer_IV = PTR2IV(tcc_get_symbol(state, "op_func"));
		if (pointer_IV == 0) {
			croak("C::Blocks internal error: got null pointer for op function!");
		}
		
		OP * o = newUNOP(OP_RAND, 0, newSVOP(OP_CONST, 0, newSViv(pointer_IV)));
		o->op_ppaddr = Perl_tcc_pp;
	
		/* Set the op to my newly built one */
		*op_ptr = o;
	}
	else {
		// build a null op
		*op_ptr = newOP(OP_NULL, 0);
	}
	if (keyword_type == IS_CSUB) {
		/* Extract the xsub */
		XSUBADDR_t xsub_fcn_ptr = tcc_get_symbol(state, xsub_name);
		
		/* Add the xsub to the package's symbol table */
		char * filename = CopFILE(PL_curcop);
		char * full_func_name = form("%s::%s", SvPVbyte_nolen(PL_curstname), xsub_name);
		newXS(full_func_name, xsub_fcn_ptr, filename);
	}
	else if (keyword_type == IS_CSHARE || keyword_type == IS_CLEX) {
		/* Build an extsym table to serialize */
		extsym_table new_table;
		new_table.tokensym_list = callback_data.new_symtab;
		if (SvPOK(lib_to_link) && SvCUR(lib_to_link) > 0) {
			new_table.state = NULL;
			new_table.dll = dynaloader_get_lib(aTHX_ SvPVbyte_nolen(lib_to_link));
			if (new_table.dll == NULL) {
				croak("C::Blocks/DynaLoader unable to load library [%s]",
					SvPVbyte_nolen(lib_to_link));
			}
			SvSetMagicSV_nosteal(lib_to_link, &PL_sv_undef);
		}
		else {
			new_table.state = state;
			new_table.dll = NULL;
		}
		
		/* add the serialized pointer address to the hints hash entry */
		if (SvPOK(extsym_tables_SV)) {
			sv_catpvn_mg(extsym_tables_SV, (char*)&new_table, sizeof(extsym_table));
		}
		else {
			sv_setpvn_mg(extsym_tables_SV, (char*)&new_table, sizeof(extsym_table));
		}
		hints_hash = cophh_store_pvs(hints_hash, "C::Blocks/tokensym_tables", extsym_tables_SV, 0);
		CopHINTHASH_set(PL_curcop, hints_hash);
		
		if (keyword_type == IS_CSHARE) {
			/* add the serialized pointer address to the published pointer
			 * addresses. */
			SV * package_lists = get_sv(form("%s::%s", SvPVbyte_nolen(PL_curstname),
				package_suffix), GV_ADD);

			if (SvPOK(package_lists) && SvCUR(package_lists) > 0) {
				sv_catpvn_mg(package_lists, (char*)&new_table, sizeof(extsym_table));
			}
			else {
				sv_setpvn_mg(package_lists, (char*)&new_table, sizeof(extsym_table));
			}
		}
	}
	
	if (keyword_type == IS_CSHARE || keyword_type == IS_CLEX) {
		/* place the tcc state in "static" memory so we can retrieve function
		 * pointers later without causing segfaults. We will clean these up
		 * when the program is done. */
		AV * state_cache = get_av("C::Blocks::__state_cache_array", 1);
		av_push(state_cache, newSViv(PTR2IV(state)));
	}
	else {
		tcc_delete(state);
	}
	
	/* cleanup */
	sv_2mortal(error_msg_sv);
	Safefree(xsub_name);
	
	/* insert a semicolon to make the parser happy */
	end--;
	*end = ';';

all_done:
	lex_unstuff(end);
	/* Make the parser count the number of lines correctly */
	int i;
	for (i = 0; i < N_newlines; i++) lex_stuff_pv("\n", 0);
	
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
	SV * extsym_tables_SV = cophh_fetch_pvs(hints_hash, "C::Blocks/tokensym_tables", 0);
	if (extsym_tables_SV == &PL_sv_placeholder) extsym_tables_SV = newSVpvn("", 0);
	hints_hash = cophh_store_pvs(hints_hash, "C::Blocks/tokensym_tables", extsym_tables_SV, 0);
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
	/* Remove all of the saved code blocks and compiler states */
	AV * cache = get_av("C::Blocks::__state_cache_array", 1);
	int i;
	SV ** elem_p;
	for (i = 0; i < av_len(cache); i++) {
		elem_p = av_fetch(cache, i, 0);
		if (elem_p != 0) {
			tcc_delete(INT2PTR(TCCState*, SvIV(*elem_p)));
		}
		else {
			warn("C::Blocks had trouble freeing TCCState");
		}
	}

BOOT:
	/* Set up the keyword plugin to a useful initial value. */
	next_keyword_plugin = PL_keyword_plugin;
	
	/* Set up the custom op */
	XopENTRY_set(&tcc_xop, xop_name, "tccop");
	XopENTRY_set(&tcc_xop, xop_desc, "Op to run jit-compiled C code");
	Perl_custom_op_register(aTHX_ Perl_tcc_pp, &tcc_xop);
