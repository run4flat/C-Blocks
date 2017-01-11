#include <cb_mem_mgmt.h>

typedef struct executable_memory executable_memory;
struct executable_memory {
	uintptr_t curr_address;
	uintptr_t bytes_remaining;
	executable_memory * next;
	char base_address[0];
};

executable_memory * my_mem_root;
executable_memory * my_mem_tail;

void *cb_mem_alloc(size_t n_bytes) {
	if (n_bytes > my_mem_tail->bytes_remaining) {
		/* allocate requested plus 16K of memory */
		my_mem_tail->next = malloc(sizeof(executable_memory) + n_bytes + 16384);
		my_mem_tail = my_mem_tail->next;
		my_mem_tail->curr_address = (uintptr_t)my_mem_tail->base_address;
		my_mem_tail->bytes_remaining = n_bytes + 16384;
		/* check alignment */
		if ((my_mem_tail->curr_address & 63) != 0) {
			my_mem_tail->curr_address &= ~63;
			my_mem_tail->curr_address += 64;
			my_mem_tail->bytes_remaining
				-= my_mem_tail->curr_address - (uintptr_t)my_mem_tail->base_address;
		}
		my_mem_tail->next = 0;
	}
	void * to_return = (void*)my_mem_tail->curr_address;
	
	/* update and align curr_address */
	my_mem_tail->curr_address += n_bytes;
	if ((my_mem_tail->curr_address & 63) != 0) {
		my_mem_tail->curr_address &= ~63;
		my_mem_tail->curr_address += 64;
	}
	my_mem_tail->bytes_remaining
		-= my_mem_tail->curr_address - (uintptr_t)to_return;
	return to_return;
}

void cb_mem_mgmt_init() {
	my_mem_tail = my_mem_root = malloc(sizeof(executable_memory) + 16384);
	my_mem_tail->curr_address = (uintptr_t)my_mem_tail->base_address;
	my_mem_tail->bytes_remaining = 16384;
	if ((my_mem_tail->curr_address & 0x63) != 0) {
		my_mem_tail->curr_address &= ~63;
		my_mem_tail->curr_address += 64;
		my_mem_tail->bytes_remaining
			-= my_mem_tail->curr_address - (uintptr_t)my_mem_tail->base_address;
	}
	my_mem_tail->next = 0;
}

void cb_mem_mgmt_cleanup() {
	/* Remove all the code pages */
	executable_memory * to_cleanup = my_mem_root;
	while(to_cleanup) {
		executable_memory * tmp = to_cleanup->next;
		free(to_cleanup);
		to_cleanup = tmp;
	}
}

