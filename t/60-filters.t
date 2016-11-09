use strict;
use warnings;
use Test::More;

use C::Blocks;
use C::Blocks::Filter::BlockArrowMethods;

# Build the vtable and object layouts
clex {
	/* typedef for the object layout */
	typedef struct bar_t bar;
	/* typedef for vtable */
	typedef struct foo_t {
		int (*silly)(bar * obj);
	} foo;
	/* lone method */
	int my_silly(bar * obj) {
		/* not do anything here */
	}
	/* object layout */
	struct bar_t {
		foo * methods;
	};
}

cblock {
	foo my_foo;
	my_foo.silly = my_silly;
	
	bar my_bar_actual;
	bar* my_bar = &my_bar_actual;
	my_bar->methods = &my_foo;
	
	/* As written, this is invalid C code. If the filter works correctly
	 * then this will compile and turn this whole block into a boring
	 * no-op. */
	my_bar=>silly();
}

pass('Filters (as tested using block arrows) does not break anything');
done_testing;
