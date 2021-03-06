#ifndef CB_C_BLOCKS_DATA_H_
#define CB_C_BLOCKS_DATA_H_

/* For now, this header will hold the widely-used typedefs/struct definitions
 * for the global state. That's not an ideal structure, but transiently
 * unavoidable. */

typedef struct c_blocks_data {
	char * end;
	char * xs_c_name;
	char * xs_perl_name;
	char * xsub_name;
	SV * exsymtabs;
	SV * code_top;
	SV * code_main;
	SV * code_bottom;
	SV * error_msg_sv;
	int N_newlines;
	int keep_curly_brackets;
	int add_test;
} c_blocks_data;



#endif
