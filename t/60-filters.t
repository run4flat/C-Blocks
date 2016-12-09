use strict;
use warnings;
use Test::More;

use C::Blocks;

{
	####################################################################
	#                      test C::Blocks::Filter                      #
	####################################################################
	use Capture::Tiny qw(capture);
	my ($stdout, $stderr, @result) = capture {
		eval q{
			use C::Blocks::Filter;
			cblock {}
		}
	};
	is($stderr, '', "C::Blocks::Filter does not issue anything to stderr");
	like($stdout, qr/void op_func/, "C::Blocks::Filter sends full C source to stdout");
}


{
	####################################################################
	#                      test BlockArrowMethods                      #
	####################################################################

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
	pass('BlockArrowMethods produces good code (when used appropriately)');
}

{
	###################################################################
	#                    test simple sub installer                    #
	###################################################################
	my $contents;
	sub copy_contents {
		$contents = $_;
	}
	use C::Blocks::Filter qw(&copy_contents);
	# String eval, so we guarantee that this runs at runtime, not
	# compile time
	eval q{
		cblock {}
	};
	like($contents, qr/void op_func/, "Installing filter sub by name works");
}

done_testing;
