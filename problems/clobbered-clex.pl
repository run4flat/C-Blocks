use strict;
use warnings;
use C::Blocks;

# clex works as advertised:
clex {
	void func1() {}
}
cblock {
	func1();
}

# A second clex does not clobber first:
clex {
	void func2() {}
}
cblock {
	func1();
	func2();
}

print "So far, so good!\n";

# Two pragmatic modules do not clobber each other:
eval q{
	use C::Blocks::StretchyBuffer;
	clex {
		void func3() {}
	}
	use C::Blocks::PerlAPI;

	cblock {
		printf("Address of stb__sbgrowf is %p\n", &stb__sbgrowf);
	}
	print "No problem finding stb__sbgrowf\n";
} or do {
	print "$@\n";
};

# Two pragmatic modules do not clobber each other, even with a clex in
# between.
eval q{
	use C::Blocks::StretchyBuffer;
	clex {
		void func3() {}
	}
	use C::Blocks::PerlAPI;

	cblock {
		printf("Address of stb__sbgrowf is %p\n", &stb__sbgrowf);
	}
	print "No problem finding stb__sbgrowf\n";
} or do {
	print "$@\n";
};

# A pragmatic module clobbers clex entries:
eval q{
	use C::Blocks::PerlAPI;

	cblock {
		printf("Address of func1 is %p\n", &func1);
	}
	print "No problem finding func1\n";
} or do {
	print "$@\n";
};

print "*** All done ***\n";
