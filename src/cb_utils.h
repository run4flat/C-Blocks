#ifndef CB_UTILS_H_
#define CB_UTILS_H_

/* General utilities that have to be used across multiple files.
 * Obviously, adding things here should be done sparingly... */

#include <EXTERN.h>
#include <perl.h>

/* Lexical Perl warnings */
void cb_warnif (pTHX_ const char * category, SV * message);
  
#endif
