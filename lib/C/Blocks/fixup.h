/* A simple object-oriented setup for lexically scoped compiler modification */

#define cblocks_fixup_base \
	TokenSym_p (*lookup_by_name)(struct cbf_base * table, char * name, int hash); \
	TokenSym_p (*lookup_by_tid)(struct cbf_base * table, int tid); \
	void * (*get_symbol)(struct cbf_base * table, char * name); \
	void (*destroy)(struct cbf_base * table); \
	TokenSym_p* tokensym_list;

/* virtual base class */
struct cbf_base { cblocks_fixup_base }

typedef TokenSym_p (*cbf_lookup_by_name_t)(struct cbf_base*, char *, int);
typedef TokenSym_p (*cbf_lookup_by_number_t)(struct cbf_base*, int);
typedef void * (*cbf_get_symbol_t)(struct cbf_base*, char *);
typedef void (*cbf_destroy_t)(struct cbf_base*);

TokenSym_p cbf_default_lookup_by_name (struct cbf_base * self, char * name,
	int hash
) {
	/* No use of the hash table, just iterate through the list */
	TokenSym_p* ts_list = self->tokensym_list;
	int list_length = tcc_tokensym_list_length(ts_list);
	for (j = 0; j < list_length; j++) {
		char * curr_name = tcc_tokensym_name(ts_list[j]);
		if (strcmp(curr_name, name) == 0) return ts_list[j];
	}
	return NULL;
}

TokenSym_p cbf_default_lookup_by_number (struct cbf_base * self, int tid) {
	TokenSym_p* ts_list = self->tokensym_list;
	TokenSym_p ts = tcc_tokensym_by_tok(tok_id, ts_list);
	if ((ts != NULL) && is_identifier) {
		/* Retrieve the pointer; add it to a linked list of items to
		 * add after the compilation has finished. */
		void * pointer = cbf_base->get_symbol(self, tcc_tokensym_name(ts));
		if (pointer != NULL) {
			add_identifier(callback_data, name, pointer, ts);
		}
	}
	return ts;
}

void * cbf_default_get_symbol (struct cbf_base * self, char * name) {
	printf("Virtual base class method for symbol table lookup!!! Bah!!!\n");
	abort();
}

void cbf_default_destroy (struct cbf_base * self) {
	free(self);
}

void cbf_default_init(struct cbf_base * self, TokenSym_p tlist) {
	/* Set up the virtual function pointers */
	self->lookup_by_name = cbf_default_lookup_by_name;
	self->lookup_by_tid = cbf_default_lookup_by_tid;
	self->get_symbol = cbf_default_get_symbol;
	self->destroy = cbf_default_destroy;
	self->tokensym_list = tlist;
}

/* derived class that includes a tcc state for the get_symbol function */
#define cblocks_fixup_tcc \
	cblocks_fixup_base \
	TCCState * state;

struct cbf_tcc { cblocks_fixup_tcc }

void * cbf_state_get_symbol (struct cbf_tcc * self, char * name) {
	return tcc_get_symbol(self->state, name);
}

void cbf_state_init(struct cbf_state * self, TokenSym_p tlist, TCCState * state) {
	cbf_default_init((cbf_base*)self, tlist);
	self->get_symbol = (cbf_get_symbol_t)cbf_state_get_symbol;
	self->state = state;
}

struct cbf_lib {
	cblocks_fixup_tcc
	void ** lib_handles;
	int N_libs;
}

void * cbf_lib_get_symbol (struct cbf_lib * self, char * name) {
	/* working here */
}

void cbf_lib_init(struct cbf_state * self, TokenSym_p tlist, TCCState * state,
	int N_libs, ...
) {
	
}
