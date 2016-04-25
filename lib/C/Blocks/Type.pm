use strict;
use warnings;
########################################################################
                      package C::Blocks::Type;
########################################################################

use C::Blocks;

sub is_defined {
	my $package = shift @_;
	$@ = '';
	while (@_) {
		my ($arg_name, $arg) = splice @_, 0, 2;
		$@ .= "$arg_name is not defined\n" and next if not defined $arg;
	}
	if ($@ eq '') {
		undef $@;
		return 1;
	}
	croak($@);
}

cshare {
	#define just_gimme_zero(arg) 0
}

########################################################################
                           # double #
########################################################################
$C::Blocks::Type::double_no_init::TYPE
	= $C::Blocks::Type::double_local::TYPE
	= 'double';
$C::Blocks::Type::double_local::INIT = 'SvNV';
$C::Blocks::Type::double_no_init::INIT = 'just_gimme_zero';
$C::Blocks::Type::double_no_init::CLEANUP = 'sv_setnv';
*C::Blocks::Type::double_local::check_var_types
	= *C::Blocks::Type::double_no_init::check_var_types
	= \&C::Blocks::Type::NV::check_var_types;

########################################################################
                           # float #
########################################################################
$C::Blocks::Type::float_no_init::TYPE
	= $C::Blocks::Type::float_local::TYPE
	= 'float';
$C::Blocks::Type::float_local::INIT = 'SvNV';
$C::Blocks::Type::float_no_init::INIT = 'just_gimme_zero';
$C::Blocks::Type::float_no_init::CLEANUP = 'sv_setnv';
*C::Blocks::Type::float_local::check_var_types
	= *C::Blocks::Type::float_no_init::check_var_types
	= \&C::Blocks::Type::NV::check_var_types;

########################################################################
                           # int #
########################################################################
$C::Blocks::Type::int_no_init::TYPE
	= $C::Blocks::Type::int_local::TYPE
	= 'int';
$C::Blocks::Type::int_local::INIT = 'SvIV';
$C::Blocks::Type::int_no_init::INIT = 'just_gimme_zero';
$C::Blocks::Type::int_no_init::CLEANUP = 'sv_setiv';
*C::Blocks::Type::int_local::check_var_types
	= *C::Blocks::Type::int_no_init::check_var_types
	= \&C::Blocks::Type::NV::check_var_types;

########################################################################
                           # unsigned int #
########################################################################
$C::Blocks::Type::uint_no_init::TYPE
	= $C::Blocks::Type::uint_local::TYPE
	= 'unsigned int';
$C::Blocks::Type::uint_local::INIT = 'SvUV';
$C::Blocks::Type::uint_no_init::INIT = 'just_gimme_zero';
$C::Blocks::Type::uint_no_init::CLEANUP = 'sv_setuv';
*C::Blocks::Type::uint_local::check_var_types
	= *C::Blocks::Type::uint_no_init::check_var_types
	= \&C::Blocks::Type::NV::check_var_types;


########################################################################
                           # buffers #
########################################################################
$C::Blocks::Type::Buffer::char::TYPE   = 'char *';
$C::Blocks::Type::Buffer::int::TYPE    = 'int *';
$C::Blocks::Type::Buffer::float::TYPE  = 'float *';
$C::Blocks::Type::Buffer::double::TYPE = 'double *';

$C::Blocks::Type::Buffer::char::INIT   = 'SvPVbyte_nolen';
$C::Blocks::Type::Buffer::int::INIT    = '(int*)SvPVbyte_nolen';
$C::Blocks::Type::Buffer::float::INIT  = '(float*)SvPVbyte_nolen';
$C::Blocks::Type::Buffer::double::INIT = '(double*)SvPVbyte_nolen';

*C::Blocks::Type::Buffer::char::check_var_types
	= *C::Blocks::Type::Buffer::int::check_var_types
	= *C::Blocks::Type::Buffer::float::check_var_types
	= *C::Blocks::Type::Buffer::double::check_var_types
	= \&C::Blocks::Type::is_defined;


1;
