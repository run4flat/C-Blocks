# For now, this tests two things. First, if a compilation fails, all the
# memory associated with the compilation must be freed. Second, all
# global variables are properly localized, namely $_. Eventually I would
# also like to test that a string-eval'd cblock gets cleaned up, but
# that's not part of this test yet.

use strict;
use warnings;
use Test::More;

# Load cblocks
use C::Blocks -noPerlAPI;
$C::Blocks::_add_msg_functions = 1;

########################################################################
# syntax error
########################################################################

undef $C::Blocks::_cleanup_called;
eval q{
	cblock {
		int i (
	}
};
my $death_note = $@;
subtest "C syntax error" => sub {
	like($death_note, qr/C::Blocks compiler error/, "triggerred syntax error");
	is ($C::Blocks::_cleanup_called, 1, "calls low-level cleanup method");
};

########################################################################
# type croak
########################################################################

sub Foo::c_blocks_init_cleanup { die "What happens now?" }

undef $C::Blocks::_cleanup_called;
eval q{
	my Foo $thing;
	cblock {
		$thing = 5;
	}
};
$death_note = $@;
subtest "type with c_blocks_init_cleanup function that croaks" => sub {
	like($death_note, qr/What happens now/, "triggerred croak in type");
	is ($C::Blocks::_cleanup_called, 1, "calls low-level cleanup method");
};

########################################################################
# croaking filter
########################################################################

undef $C::Blocks::_cleanup_called;
$_ = 'not clobbered';
sub my_filter {
	die "What happens now?";
}
eval q{
	use C::Blocks::Filter '&my_filter';
	cblock {}
};
$death_note = $@;
subtest "Croaking filter" => sub {
	like ($death_note, qr/What happens now/, "Die propogated/caught");
	is ($_, 'not clobbered', 'does not clobber $_');
	is ($C::Blocks::_cleanup_called, 1, "calls low-level cleanup method");
};

done_testing;
