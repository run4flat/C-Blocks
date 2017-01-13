#ifndef CB_CODE_PARSER_EXTRACTOR_H_
#define CB_CODE_PARSER_EXTRACTOR_H_

/* Logic related to scanning, parsing, and extracting the C code in
 * clex/cblock/csub/.... In future will likely include the C function
 * signature parsing logic. */

#include <EXTERN.h>
#include <perl.h>

#include <cb_c_blocks_data.h>

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

#ifndef pad_compname_type
#define pad_compname_type(a)	Perl_pad_compname_type(aTHX_ a)
#endif

enum { IS_CBLOCK = 1, IS_CSHARE, IS_CLEX, IS_CSUB } keyword_type_list;

int cb_identify_keyword (char * keyword_ptr, STRLEN keyword_len);

void cb_extract_c_code(pTHX_ c_blocks_data *data, int keyword_type);

/* TODO: ideally, these wouldn't be public. */
void cb_fixup_xsub_name(pTHX_ c_blocks_data *data);
char * cb_replace_double_colons_with_double_underscores(pTHX_ SV * to_replace);

#endif
