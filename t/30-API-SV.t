use strict;
use warnings;
use Test::More;
use C::Blocks;
use C::Blocks::PerlAPI;

our ($scalar, $result);

clex {
	#define get_vars SV * scalar = get_sv("scalar", 0); SV * result = get_sv("result", 0);
}

# A basic test: can I use get_sv and sv_setiv?
cblock {
	get_vars;
	sv_setiv(result, 1);
}
BEGIN { pass 'get_sv and sv_setiv compile without issue' }
is($result, 1, 'Successfuly set the result');

# A testing sub so I can succinctly write the tests that follow.
sub test_API {
	$scalar = shift @_;
	my ($func_name, $code, $expr, $expected, $explanation, $report_compile) = @_;
	undef ($result);
	eval qq{
		# Hide undefined warnings
		my \$stderr = '';
		{
			local *STDERR;
			open STDERR, '>', \\\$stderr;
			cblock {
				get_vars;
				$code;
				sv_setiv(result, $expr);
			}
		}
		1;
	} and do {
		pass("$func_name compiles without issue") if $report_compile;
		if ($expected eq 'ok') {
			ok($result, $explanation);
		}
		else {
			is($result, $expected, $explanation);
		}
		1;
	} or do {
		fail("$func_name failed to compile: $@");
	};
}

subtest SvOK => sub {
	test_API(undef, 'SvOK', '', 'SvOK(scalar)', 0, 'An undefined value is not SvOK', 1);
	test_API(25, 'SvOK', '', 'SvOK(scalar)', 'ok', 'A number is SvOK');
	test_API('foo', 'SvOK', '', 'SvOK(scalar)', 'ok', 'A string is SvOK');
	test_API('', 'SvOK', '', 'SvOK(scalar)', 'ok', 'An empty string is SvOK');
};

subtest SvTRUE => sub {
	test_API(undef, 'SvTRUE', '', 'SvTRUE(scalar)', 0, 'An undefined value is not SvTRUE', 1);
	test_API(25, 'SvTRUE', '', 'SvTRUE(scalar)', 'ok', '25 is SvTRUE');
	test_API(0, 'SvTRUE', '', 'SvTRUE(scalar)', 0, '0 is not SvTRUE');
	test_API(-2.5, 'SvTRUE', '', 'SvTRUE(scalar)', 'ok', '-2.5 is SvTRUE');
	test_API('foo', 'SvTRUE', '', 'SvTRUE(scalar)', 'ok', 'A string is SvTRUE');
	test_API('', 'SvTRUE', '', 'SvTRUE(scalar)', 0, 'An empty string is not SvTRUE');
	test_API('0', 'SvTRUE', '', 'SvTRUE(scalar)', 0, 'The string "0" is not SvTRUE');
	test_API('0 but true', 'SvTRUE', '', 'SvTRUE(scalar)', 'ok', 'The string "0 but true" is SvTRUE');
};

subtest SvIOK => sub {
	undef($scalar);
	test_API(undef, 'SvIOK', '', 'SvIOK(scalar)', 0, 'An undefined value is not SvIOK', 1);
	test_API(25, 'SvIOK', '', 'SvIOK(scalar)', 'ok', '25 is SvIOK');
	test_API(-2.5, 'SvIOK', '', 'SvIOK(scalar)', 0, '-2.5 is not SvIOK');
	test_API('foo', 'SvIOK', '', 'SvIOK(scalar)', 0, 'A string is not SvIOK');
};

subtest SvNOK => sub {
	test_API(undef, 'SvNOK', '', 'SvNOK(scalar)', 0, 'An undefined value is not SvNOK', 1);
	test_API(25, 'SvNOK', '', 'SvNOK(scalar)', 0, '25 is not SvNOK');
	test_API(-2.5, 'SvNOK', '', 'SvNOK(scalar)', 'ok', '-2.5 is SvNOK');
	test_API('foo', 'SvNOK', '', 'SvNOK(scalar)', 0, 'A string is not SvNOK');
};

subtest SvPOK => sub {
	test_API(undef, 'SvPOK', '', 'SvPOK(scalar)', 0, 'An undefined value is not SvPOK', 1);
	test_API(25, 'SvPOK', '', 'SvPOK(scalar)', 0, '25 is not SvPOK');
	test_API(-2.5, 'SvPOK', '', 'SvPOK(scalar)', 0, '-2.5 is not SvPOK');
	test_API('foo', 'SvPOK', '', 'SvPOK(scalar)', 'ok', 'A string is SvPOK');
	test_API('', 'SvPOK', '', 'SvPOK(scalar)', 'ok', 'An empty string is SvPOK');
};

subtest SvIV => sub {
	test_API(undef, 'SvIV', '', 'SvIV(scalar) == 0', 'ok', 'An undefined value has SvIV of 0', 1);
	test_API(10, 'SvIV', '', 'SvIV(scalar) == 10', 'ok', 'An integer has a defined SvIV');
	test_API(100.4, 'SvIV', '', 'SvIV(scalar) == 100', 'ok', 'SvIV(100.4) == 100');
	test_API('foo', 'SvIV', '', 'SvIV(scalar) == 0', 'ok', 'SvIV("foo") == 0');
};

subtest dualvar => sub {
	pass('to be written');
};

done_testing;
