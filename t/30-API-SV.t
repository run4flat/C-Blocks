use strict;
use warnings;
use Test::More;
use C::Blocks;

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
is($result, 1, 'Successfuly set the result package variable');

################# test_API #################
# A testing sub so I can succinctly write the tests that follow.
# This test closes over a couple of variables whose values are meant to
# be shared across a number of tests. To use this function, you should:
# 1) Set $final_line, a line of C code that sets the value of $result,
#    a package variable that is available for testing after the cblock
#    has run.
# 2) Call test_API with the following arguments:
#    input-value: a Perl value that will be accessible as the SV* scalar
#    description: a description of the test
#    key/value pairs:
#     - intermediary_code for manipulations before $final_line
#       (if not specified, no code is inserted)
#     - expected for the expected value of $result
#       if not specified, we use ok($result, $description)
#       if specified, we use is($result, $expected, $description)
#     - report_compile for whether we should report a successful
#       compilation, usually set only for the first function call for
#       the API function
my $final_line;
sub test_API {
	$scalar = shift @_;
	my $description = shift @_;
	my %options = (
		intermediary_code => '',
		@_
	);
	
	undef ($result);
	my $to_eval = qq{
		# Hide undefined warnings
		my \$stderr = '';
		{
			local *STDERR;
			open STDERR, '>', \\\$stderr;
			cblock {
				get_vars;
				$options{intermediary_code};
				$final_line;
			}
		}
		1;
	};
	eval $to_eval and do {
		pass("Compiles without issue") if $options{report_compile};
		if (exists $options{expected}) {
			is($result, $options{expected}, $description);
		}
		else {
			ok($result, $description);
		}
		1;
	} or do {
		fail("\"$description\" compiles ok");
		if ($options{report_compile}) {
			diag($@);
			diag($to_eval);
		}
	};
}

subtest SvOK => sub {
	$final_line = 'sv_setiv(result, SvOK(scalar))';
	
	test_API(undef, 'An undefined value is not SvOK', expected => 0,
		report_compile => 1);
	test_API(25, 'A number is SvOK');
	test_API('foo', 'A string is SvOK');
	test_API('', 'An empty string is SvOK');
};

subtest SvTRUE => sub {
	# Not SvTRUE
	$final_line = 'sv_setiv(result, !SvTRUE(scalar))';
	test_API(undef, 'An undefined value is not SvTRUE',
		report_compile => 1);
	test_API(0, '0 is not SvTRUE');
	test_API('', 'An empty string is not SvTRUE');
	test_API('0', 'The string "0" is not SvTRUE');
	
	# is SvTRUE
	$final_line = 'sv_setiv(result, SvTRUE(scalar))';
	test_API(25, '25 is SvTRUE');
	test_API(-2.5, '-2.5 is SvTRUE');
	test_API('foo', 'A non-empty, non-numeric string is SvTRUE');
	test_API('0 but true', 'The string "0 but true" is SvTRUE');
};

subtest SvIOK => sub {
	# Not SvIOK
	$final_line = 'sv_setiv(result, !SvIOK(scalar))';
	test_API(undef, 'An undefined value is not SvIOK',
		report_compile => 1);
	test_API(-2.5, '-2.5 is not SvIOK');
	test_API('foo', 'A string is not SvIOK');
	
	# Is SvIOK
	$final_line = 'sv_setiv(result, SvIOK(scalar))';
	test_API(25, '25 is SvIOK');
};

subtest SvNOK => sub {
	# Not SvNOK
	$final_line = 'sv_setiv(result, !SvNOK(scalar))';
	test_API(undef, 'An undefined value is not SvNOK',
		report_compile => 1);
	test_API(25, '25 is not SvNOK');
	test_API('foo', 'A string is not SvNOK');
	
	# is SvNOK
	$final_line = 'sv_setiv(result, SvNOK(scalar))';
	test_API(-2.5, '-2.5 is SvNOK');
};

subtest SvPOK => sub {
	# not SvPOK
	$final_line = 'sv_setiv(result, !SvPOK(scalar))';
	test_API(undef, 'An undefined value is not SvPOK',
		report_compile => 1);
	test_API(25, '25 is not SvPOK');
	test_API(-2.5, '-2.5 is not SvPOK');
	
	# is SvPOK
	$final_line = 'sv_setiv(result, SvPOK(scalar))';
	test_API('foo', 'A string is SvPOK');
	test_API('', 'An empty string is SvPOK');
};

subtest SvIV => sub {
	$final_line = 'sv_setiv(result, SvIV(scalar))';
	test_API(undef, 'An undefined value has SvIV of 0', expected => 0,
		report_compile => 1);
	test_API(10, "An integer's SvIV is its value", expected => 10);
	test_API(100.4, "A floating-point's SvIV is its value rounded",
		expected => 100);
	test_API('foo', "A string's SvIV is 0", expected => 0);
	
	$final_line = 'sv_setiv(result, 5*SvIV(scalar))';
	test_API(10, "Successful integer multiplication in C code",
		expected => 50);
};

subtest SvNV => sub {
	$final_line = 'sv_setnv(result, SvNV(scalar))';
	test_API(undef, 'An undefined value has SvNV of 0', expected => 0,
		report_compile => 1);
	test_API(10, "An integer's SvNV is its value", expected => 10);
	test_API(0.5, "A floating-point's SvNV is its value",
		expected => 0.5);
	test_API('foo', "A string's SvNV is 0", expected => 0);
	
	$final_line = 'sv_setnv(result, 5*SvNV(scalar))';
	test_API(10, "Successful floating-point multiplication in C code",
		expected => 50);
};

subtest dualvar => sub {
	pass('to be written');
};

done_testing;
