#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/* Needs tests: run_filters
 */

/* I think defining DPPP_PL_parser_NO_DUMMY breaks perls prior to 5.9.5
 * but I'm not sure (ppport suggests as much). But I also think that
 * those might have been equally broken by some of other preprocessor
 * hackery. Do we care? --Steffen
 *
 * No, I do not care about such ancient Perls. -- David */
#define DPPP_PL_parser_NO_DUMMY
#include "ppport.h"

#include "libtcc.h"

#ifndef GvCV_set
#define GvCV_set(gv, cv) (GvCV(gv) = (CV*)(cv))
#endif

#include <cb_mem_mgmt.h>
#include <cb_custom_op.h>
#include <cb_code_parser_extractor.h>
#include <cb_c_blocks_data.h>
#include <cb_utils.h>


int (*next_keyword_plugin)(pTHX_ char *, STRLEN, OP **);

typedef struct _available_extended_symtab {
	extended_symtab_p exsymtab;
	void ** dlls;
} available_extended_symtab;


#ifdef PERL_IMPLICIT_CONTEXT
	/* according to perl.h, these macros only exist we have
	 * PERL_IMPLICIT_CONTEXT defined */
	#define C_BLOCKS_THX_DECL tTHX aTHX
	#define C_BLOCKS_THX_DECL__ tTHX aTHX;
	#define C_BLOCKS_CALLBACK_MY_PERL(callback) callback->aTHX,
#else
	#define C_BLOCKS_THX_DECL
	#define C_BLOCKS_THX_DECL__
	#define C_BLOCKS_CALLBACK_MY_PERL(callback)
#endif

/* ---- Extended symbol table handling ---- */
typedef struct _extended_symtab_callback_data {
	TCCState * state;
	C_BLOCKS_THX_DECL__
	available_extended_symtab * available_extended_symtabs;
	STRLEN N_tables;
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
		
		/* Scan the dlls first */
		void ** curr_dll = lookup_data.dlls;
		if (curr_dll != NULL) {
			while (*curr_dll != NULL) {
				pointer = dynaloader_get_symbol(
					C_BLOCKS_CALLBACK_MY_PERL(callback_data) *curr_dll, name);
				if (pointer) break;
				curr_dll++;
			}
		}
		
		/* If we didn't find it, check if it's in the exsymtab */
		if (pointer == NULL) {
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

/*********************************/
/**** C code parser/extractor ****/
/*********************************/

void post_filter_restore_underbar(pTHX_ void* under_backup) {
	/* XXX Is this really the only way to "local $_" in C??? */
	SV * underbar = find_rundefsv();
	sv_setsv(underbar, (SV*)under_backup);
	SvREFCNT_dec((SV*)under_backup);
}

void run_filters (pTHX_ c_blocks_data * data, int keyword_type) {
	/* back up $_ and setup a restore point, i.e. localize it */
	SV * underbar = find_rundefsv();
	SV * under_backup = newSVsv(underbar);
	SAVEDESTRUCTOR_X(post_filter_restore_underbar, under_backup);
	
	/* place the code in $_ */
	sv_setpvf(underbar, "%s%s%s", SvPVbyte_nolen(data->code_top),
		SvPVbyte_nolen(data->code_main), SvPVbyte_nolen(data->code_bottom));
	
	/* Apply the different filters */

	SV ** filters_SV_p = hv_fetchs(GvHV(PL_hintgv), "C::Blocks/filters", 0);
	if (filters_SV_p) {
		dSP;
		char * filters = SvPVbyte_nolen(*filters_SV_p);
		char * start = filters;
		char backup;
		while(1) {
			if (*filters == '\0' && start == filters) break;
			if (*filters == '|') {
				backup = *filters;
				*filters = '\0';
				/* construct the function name to call */
				char * full_method;
				/* if it starts with an ampersand, it's a function name */
				if (*start == '&') {
					full_method = start + 1;
				}
				else {
					/* we have the package name; append the normal method */
					full_method = form("%s::c_blocks_filter", start);
				}
				PUSHMARK(SP);
				/* XXX If this croaks will I have screwed up the list of
				 * filters since I didn't re-establish the backup? Needs
				 * a test... */
				call_pv(full_method, G_DISCARD|G_NOARGS);
				start = filters + 1;
				*filters = backup;
			}
			filters++;
		}
	}
	
	/* copy contents of underbar into main */
	sv_setsv(data->code_main, underbar);
}

/*************************/
/**** Keyword plugin ****/
/************************/

void initialize_c_blocks_data(pTHX_ c_blocks_data* data) {
	data->N_newlines = 0;
	data->xs_c_name = 0;
	data->xs_perl_name = 0;
	data->xsub_name = 0;
	data->keep_curly_brackets = 1;
	
	data->add_test = SvOK(get_sv("C::Blocks::_add_msg_functions", 0));
	data->code_top = newSVpvn("", 0);
	data->code_main = newSVpvf("\n#line %d \"%s\"\n", CopLINE(PL_curcop),
		CopFILE(PL_curcop));
	data->code_bottom = newSVpvn("", 0);
	data->error_msg_sv = newSV(0);
	
	/* This is called after we have cleared out whitespace, so just assign */
	data->end = PL_bufptr;
	
	/* Get the current exsymtabs list. If it doesn't exist, set
	 * exsymtabs to null to indicate as much. */
	PL_hints |= HINT_LOCALIZE_HH;
	gv_HVadd(PL_hintgv); /* Make sure the hints hash entry is valid */
	SV** exsymtabs_p = hv_fetchs(GvHV(PL_hintgv), "C::Blocks/extended_symtab_tables", 0);
	data->exsymtabs = exsymtabs_p ? *exsymtabs_p : 0;
}

void add_function_signature_to_block(pTHX_ c_blocks_data* data) {
	/* Add the function declaration. The definition of the THX_DECL
	 * macro will be defined later. */
	sv_catpv_nomg(data->code_top, "void op_func(C_BLOCKS_THX_DECL) {");
}

void cleanup_c_blocks_data(pTHX_ void* data_vp) {
	c_blocks_data * data = (c_blocks_data *)data_vp;
	SvREFCNT_dec(data->error_msg_sv);
	SvREFCNT_dec(data->code_top);
	SvREFCNT_dec(data->code_main);
	SvREFCNT_dec(data->code_bottom);
	/* Bottom and top, if they were even used, should have been
	 * de-allocated already. */
	//if (data->exsymtabs) SvREFCNT_dec(data->exsymtabs);
	Safefree(data->xs_c_name);
	Safefree(data->xs_perl_name);
	Safefree(data->xsub_name);
	/* indicate successful cleanup of data */
	if (data->add_test) {
		SV * cleanup_indicator = get_sv("C::Blocks::_cleanup_called",
			GV_ADD | GV_ADDMULTI);
		sv_setiv(cleanup_indicator, 1);
	}
}

/* Add testing functions if requested. This must be called before
 * add_function_signature_to_block is called. */
void add_msg_function_decl(pTHX_ c_blocks_data * data) {
	if (data->add_test) {
		sv_catpv(data->code_top, "void c_blocks_send_msg(char * msg);"
			"void c_blocks_send_bytes(void * msg, int bytes);"
			"char * c_blocks_get_msg();"
		);
	}
}

/* inject C::Blocks::load_lib as import method in the current package */
void inject_import(pTHX) {
	char * warn_message = "no warning (yet)";
	SV * name = NULL;
	/* Get CV for C::Blocks::load_lib */
	CV * import_method_to_inject
		= get_cvn_flags("C::Blocks::load_lib", 19, 0);
	if (!import_method_to_inject) {
		warn_message = "could not load C::Blocks::load_lib";
		goto fail;
	}
	
	/* Get the symbol (hash) table entry */
	name = newSVpv("import", 6);
	HE * entry = hv_fetch_ent(PL_curstash, name, 1, 0);
	if (!entry) {
		warn_message = "unable to load symbol table entry for 'import'";
		goto fail;
	}
	
	/* Get the glob for the symbol table entry. Make sure it isn't
	 * already initialized. */
	GV * glob = (GV*)HeVAL(entry);
	if (isGV(glob)) {
		cb_warnif(aTHX_ "import", sv_2mortal(newSVpvf("Could not inject 'import' "
			"into package %s: 'import' method already found",
			SvPVbyte_nolen(PL_curstname))));
		SvREFCNT_dec(name);
		return;
	}
	
	/* initialize the glob */
	SvREFCNT_inc(glob);
	gv_init(glob, PL_curstash, "import", 6, 1);
	if (HeVAL(entry)) {
		SvREFCNT_dec(HeVAL(entry));
	}
	HeVAL(entry) = (SV*)glob;
	
	/* Add the method to the symbol table entry. See Package::Stash::XS
	 * GvSetCV preprocessor macro (specifically taken from v0.28) */
	SvREFCNT_dec(GvCV(glob));
	GvCV_set(glob, import_method_to_inject);
	GvIMPORTED_CV_on(glob);
	GvASSUMECV_on(glob);
	GvCVGEN(glob) = 0;
	mro_method_changed_in(GvSTASH(glob));

	SvREFCNT_dec(name);
	return;

fail:
	if (name != NULL) SvREFCNT_dec(name);
	warn("Internal error while injecting 'import' into package %s: %s",
		SvPVbyte_nolen(PL_curstname), warn_message);
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
	extended_symtab_callback_data callback_data = { state, aTHX_ NULL, 0 };
	
	/* Set the extended symbol table lists if they exist. We could skip
	 * this if exsymtabs is an empty string, but this'll work as-is
	 * because it'll set N_tables to 0. */
	if (data->exsymtabs) {
		callback_data.available_extended_symtabs
			= (available_extended_symtab*) SvPV(data->exsymtabs, callback_data.N_tables);
		callback_data.N_tables /= sizeof(available_extended_symtab);
	}
	tcc_set_extended_symtab_callbacks(state, &my_symtab_lookup_by_name,
		&my_symtab_sym_used, &my_prep_table, &callback_data);
	
	/* set the block function's argument, if any */
	if (keyword_type == IS_CBLOCK) {
		/* If this is a block, we need to define C_BLOCKS_THX_DECL.
		 * This will be based on whether tTHX is available or not. */
		#ifdef PERL_IMPLICIT_CONTEXT
			void * return_value_ignored;
			if (my_symtab_lookup_by_name("aTHX", 4, &callback_data, (void*) &return_value_ignored))
				tcc_define_symbol(state, "C_BLOCKS_THX_DECL", "PerlInterpreter * my_perl");
			else
				tcc_define_symbol(state, "C_BLOCKS_THX_DECL", "void * my_perl_NOT_USED");
		#else
			tcc_define_symbol(state, "C_BLOCKS_THX_DECL", "");
		#endif
	}
	
	/* compile the code, which is (by this time) stored entirely in main */
	STRLEN main_len;
	char * to_compile = SvPVbyte(data->code_main, main_len);
	tcc_compile_string(state, to_compile);
	
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
		
		/* Otherwise, report and clear the compiler warnings */
		cb_warnif(aTHX_ "compiler", sv_2mortal(newSVsv(data->error_msg_sv)));
		SvPOK_off(data->error_msg_sv);
	}
}

void extract_xsub (pTHX_ TCCState * state, c_blocks_data * data) {
	/* Extract the xsub */
	XSUBADDR_t xsub_fcn_ptr = tcc_get_symbol(state, data->xs_c_name);
	if (xsub_fcn_ptr == NULL)
		croak("C::Blocks internal error: Unable to get pointer to csub %s\n", data->xsub_name);
	
	/* Add the xsub to the package's symbol table */
	char * filename = CopFILE(PL_curcop);
	newXS(data->xs_perl_name, xsub_fcn_ptr, filename);
}

void serialize_symbol_table(pTHX_ TCCState * state, c_blocks_data * data, int keyword_type) {
	/* Build an extended symbol table to serialize */
	available_extended_symtab new_table;
	new_table.exsymtab = tcc_get_extended_symbol_table(state);
	
	/* Store the pointers to the extended symtabs so that we can clean up
	 * when everything is over. */
	AV * extended_symtab_cache = get_av("C::Blocks::__symtab_cache_array", GV_ADDMULTI | GV_ADD);
	av_push(extended_symtab_cache, newSViv(PTR2IV(new_table.exsymtab)));

	/* Get the dll pointers if this is to be linked against dlls */
	AV * libs_to_link = get_av("C::Blocks::libraries_to_link", 0);
	new_table.dlls = NULL;
	if (libs_to_link != NULL && av_len(libs_to_link) >= 0) {
		int N_libs = av_len(libs_to_link) + 1;
		int i = 0;
		new_table.dlls = Newx(new_table.dlls, N_libs + 1, void*);
		while(av_len(libs_to_link) >= 0) {
			SV * lib_to_link = av_shift(libs_to_link);
			new_table.dlls[i] = dynaloader_get_lib(aTHX_ SvPVbyte_nolen(lib_to_link));
			if (new_table.dlls[i] == NULL) {
				croak("C::Blocks/DynaLoader unable to load library [%s]",
					SvPVbyte_nolen(lib_to_link));
			}
			SvSetMagicSV_nosteal(lib_to_link, &PL_sv_undef);
			i++;
		}
		new_table.dlls[i] = NULL;
		
		/* Store a copy so we can later clean up memory */
		AV * dll_list = get_av("C::Blocks::__dll_list_array", GV_ADDMULTI | GV_ADD);
		av_push(dll_list, newSViv(PTR2IV(new_table.dlls)));
	}
	
	/* add the serialized pointer address to the hints hash entry. Note
	 * the current contents of data->exsymtabs may have the Perl API
	 * added, so pull a fresh copy of the exsymtabs from the hints hash. */
	SV** exsymtab_p = hv_fetchs(GvHV(PL_hintgv), "C::Blocks/extended_symtab_tables", 1);
	if (exsymtab_p) {
		if (SvPOK(*exsymtab_p)) {
			sv_catpvn_mg(*exsymtab_p, (char*)&new_table, sizeof(available_extended_symtab));
		}
		else {
			sv_setpvn_mg(*exsymtab_p, (char*)&new_table, sizeof(available_extended_symtab));
		}
	}
	else {
		warn("C::Blocks internal warning: Unable to retrieve or append "
			"to hints hash entry for extended symbol table list\n");
	}
	
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
		
		/* inject the import method */
		SV * has_import = get_sv(form("%s::__cblocks_injected_import",
			SvPVbyte_nolen(PL_curstname)), GV_ADDMULTI | GV_ADD);
		if (!SvOK(has_import)) {
			inject_import(aTHX);
			sv_setuv(has_import, 1);
		}
	}
}




/* Global C::Blocks cleanup handler - executed using Perl_call_atexit. Any
 * C::Blocks code executed after this will break badly. */
void c_blocks_final_cleanup(pTHX_ void *ptr) {
	/* Remove all of the extended symol tables. */
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
	cache = get_av("C::Blocks::__dll_list_array", GV_ADDMULTI | GV_ADD);
	for (i = 0; i < av_len(cache); i++) {
		elem_p = av_fetch(cache, i, 0);
		if (elem_p != 0) {
			Safefree(INT2PTR(void*, SvIV(*elem_p)));
		}
		else {
			warn("C::Blocks had trouble freeing dll list, index %d", i);
		}
	}

	cb_mem_mgmt_cleanup();
}

/* Keyword plugin for parsing cq expression. This is called by
 * _my_keyword_plugin */
STATIC int _cq_keyword_plugin(pTHX_ OP **op_ptr, c_blocks_data * data) {
	/* remove line-number spec */
	sv_setpvs(data->code_main, "");
	
	/* extract the cq block */
	data->keep_curly_brackets = 0;
	cb_extract_c_code(aTHX_ data, IS_CQ);
	
	/* Wrap everything in function-call parens and qq curly brackets.
	 * The actual cq is a Perl function that adds the line number
	 * directive and applies the filters. */
	lex_stuff_pv(form("( qq{%s} )", SvPVbyte_nolen(data->code_main)), 0);
	
	/* pretend we didn't do anything... */
	return KEYWORD_PLUGIN_DECLINE;
}

/* See below: my_keyword_plugin is a shim around this function */
STATIC int _my_keyword_plugin(pTHX_ char *keyword_ptr,
	STRLEN keyword_len, OP **op_ptr, int keyword_type, c_blocks_data * data
) {
	/**********************/
	/*   Initialization   */
	/**********************/
	/* Clear out any leading whitespace, including comments. Do this before
	 * initialization so that the assignment of the end pointer is correct. */
	lex_read_space(0);
	
	/* cq backdoor */
	if (keyword_type == IS_CQ) return _cq_keyword_plugin(aTHX_ op_ptr,
		data);
	
	add_msg_function_decl(aTHX_ data);
	if (keyword_type == IS_CBLOCK) add_function_signature_to_block(aTHX_ data);
	else if (keyword_type == IS_CSUB) cb_fixup_xsub_name(aTHX_ data);
	else if (keyword_type == IS_CSHARE || keyword_type == IS_CLEX) {
		data->keep_curly_brackets = 0;
	}
	
	/*****************/
	/*   Debugging   */
	/*****************/
	if (data->add_test) {
		SV * cleanup_indicator = get_sv("C::Blocks::_cleanup_called",
			GV_ADD | GV_ADDMULTI);
		sv_setiv(cleanup_indicator, 0);
	}
	
	/************************/
	/* Extract and compile! */
	/************************/
	
	cb_extract_c_code(aTHX_ data, keyword_type);
	run_filters(aTHX_ data, keyword_type);
	
	TCCState * state = tcc_new();
	if (!state) croak("Unable to create C::TinyCompiler state!\n");
	setup_compiler(aTHX_ state, data);
	
	/* Ask to save state if it's a cshare or clex block*/
	if (keyword_type == IS_CSHARE || keyword_type == IS_CLEX) {
		tcc_save_extended_symtab(state);
	}
	
	/* Compile the extracted code */
	execute_compiler(aTHX_ state, data, keyword_type);
	
	/******************************************/
	/* Apply the list of symbols and relocate */
	/******************************************/
	
	/* test symbols */
	if (data->add_test) {
		tcc_add_symbol(state, "c_blocks_send_msg", _c_blocks_send_msg);
		tcc_add_symbol(state, "c_blocks_send_bytes", _c_blocks_send_bytes);
		tcc_add_symbol(state, "c_blocks_get_msg", _c_blocks_get_msg);
	}
	
	/* prepare for relocation; store in a global so that we can free everything
	 * at the end of the Perl program's execution. Allocate up to on page size
	 * more memory than we need so that we can align the code at the start of
	 * the page. */
	int machine_code_size = tcc_relocate(state, 0);
	sv_setiv(get_sv("C::Blocks::_last_machine_code_size", GV_ADD | GV_ADDMULTI),
		machine_code_size);
	if (machine_code_size > 0) {
		/* XXX IDEA: allocate SV to hold machine code and store the
		 * SV in a *hash*, keyed by either the symtab pointer or the
		 * machine code pointer (needs to be fleshed out). When a new
		 * block utilizes this machine code, the SV's refcount goes up;
		 * when a block is destroyed (known via some sort of destruct
		 * magic attached to the block), the SV's refcount goes down. 
		 * This would make it possible to de-allocate machine code that
		 * is no longer in user, which would be especially helpful for
		 * string eval'd cblocks. */
		void * machine_code = cb_mem_alloc(machine_code_size);
		int relocate_returned = tcc_relocate(state, machine_code);
		if (SvPOK(data->error_msg_sv)) {
			/* Look for errors and croak */
			if (strstr(SvPV_nolen(data->error_msg_sv), "error")) {
				croak("C::Blocks linker error:\n%s", SvPV_nolen(data->error_msg_sv));
			}
			/* Otherwise report warnings */
			cb_warnif(aTHX_ "linker", sv_2mortal(newSVsv(data->error_msg_sv)));
		}
		if (relocate_returned < 0) {
			croak("C::Blocks linker error: unable to relocate\n");
		}
	}

	/********************************************************/
	/* Build op tree or serialize the symbol table; cleanup */
	/********************************************************/

        /* build a null op if not creating a cblock */
	if (keyword_type != IS_CBLOCK)
		*op_ptr = newOP(OP_NULL, 0);
	else {
		/* get the function pointer for the block */
		void *sym_pointer = tcc_get_symbol(state, "op_func");
		if (sym_pointer == NULL)
			croak("C::Blocks internal error: got null pointer for op function!");
		*op_ptr = cb_build_op(aTHX_ sym_pointer);
	}

	if (keyword_type == IS_CSUB) extract_xsub(aTHX_ state, data);
	else if (keyword_type == IS_CSHARE || keyword_type == IS_CLEX) {
		serialize_symbol_table(aTHX_ state, data, keyword_type);
	}
	
	/* cleanup */
	/* Note: The c_blocks_data is cleaned up automatically by LEAVE. */
	tcc_delete(state);
	
	/* Make the parser count the number of lines correctly */
	CopLINE(PL_curcop) += data->N_newlines;

	/* Return success */
	return KEYWORD_PLUGIN_STMT;
}


/* This wrapper around the real keyword plugin implementation is to
 * prevent accidentally return()ing out of the ENTER/LEAVE pair without
 * executing LEAVE. */
int my_keyword_plugin(pTHX_
	char *keyword_ptr, STRLEN keyword_len, OP **op_ptr
) {
	/* Note: We shouldn't execute next_keyword_plugin() within our ENTER/LEAVE,
	 * so all checking on "does our keyword apply" needs to happen before the
	 * ENTER. */

	HV *hints;
	/* Enforce lexical scope of this keyword plugin */
	if (!(hints = GvHV(PL_hintgv)) || !(hv_fetchs(hints, "C::Blocks/keywords", 0)))
		return next_keyword_plugin(aTHX_ keyword_ptr, keyword_len, op_ptr);

	/* See if this is a keyword we know */
	int keyword_type = cb_identify_keyword(keyword_ptr, keyword_len);
	if (!keyword_type)
		return next_keyword_plugin(aTHX_ keyword_ptr, keyword_len, op_ptr);

	/* Create the compilation data struct */
	c_blocks_data data;
	initialize_c_blocks_data(aTHX_ &data);

	/* We protect the entire execution of the keyword plugin with a Perl
	 * pseudo-block ENTER/LEAVE pair. This allows us to simplify memory
	 * management significantly in the face of exceptions by simply
	 * registering cleanup handlers instead of manually trapping all
	 * possible exceptions. */
	ENTER;
	
	/* Note: Since we're passing a pointer to a struct on the stack, the LEAVE
	 * that triggers this callback MUST happen before the end of THIS function. */
	SAVEDESTRUCTOR_X(cleanup_c_blocks_data, &data);
	int retval = _my_keyword_plugin(aTHX_ keyword_ptr, keyword_len, op_ptr, keyword_type, &data);
	
	LEAVE;
	return retval;
}

MODULE = C::Blocks       PACKAGE = C::Blocks

BOOT:
	/* Set up the keyword plugin to a useful initial value. */
	next_keyword_plugin = PL_keyword_plugin;
	PL_keyword_plugin = my_keyword_plugin;
	
        cb_init_custom_op(aTHX);
	cb_mem_mgmt_init();
	
        /* Register our cleanup handler to run as late as possible. */
        Perl_call_atexit(aTHX_ c_blocks_final_cleanup, NULL);
