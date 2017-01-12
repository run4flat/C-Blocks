#ifndef CB_MEM_MGMT_H_
#define CB_MEM_MGMT_H_

/* Logic related to implementing, creating, and managing the C::Blocks
 * custom ops. */

#include <EXTERN.h>
#include <perl.h>

void *cb_mem_alloc(size_t n_bytes);

/* Needs to be called before using C::Blocks to initialize the
 * executable_memory state. */
void cb_mem_mgmt_init();
/* Needs to be called during global destruction to free the
 * executable_memory state. */
void cb_mem_mgmt_cleanup();

#endif
