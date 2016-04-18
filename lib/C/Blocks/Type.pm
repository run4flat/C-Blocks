use strict;
use warnings;
########################################################################
                      package C::Blocks::Type;
########################################################################

use C::Blocks;

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
               package C::Blocks::Type::float_local;
########################################################################
our $TYPE = 'float';
our $INIT = 'SvNV';
*check_var_types = \&C::Blocks::Type::NV::check_var_types;

########################################################################
               package C::Blocks::Type::float_no_init;
########################################################################
our $TYPE = 'float';
our $INIT = 'just_gimme_zero';
our $CLEANUP = 'sv_setnv';
*check_var_types = \&C::Blocks::Type::NV::check_var_types;

########################################################################
               package C::Blocks::Type::int_local;
########################################################################
our $TYPE = 'int';
our $INIT = 'SvIV';
*check_var_types = \&C::Blocks::Type::NV::check_var_types;

########################################################################
               package C::Blocks::Type::int_no_init;
########################################################################
our $TYPE = 'int';
our $INIT = 'just_gimme_zero';
our $CLEANUP = 'sv_setiv';
*check_var_types = \&C::Blocks::Type::NV::check_var_types;

########################################################################
               package C::Blocks::Type::uint_local;
########################################################################
our $TYPE = 'unsigned int';
our $INIT = 'SvUV';
# Should check sign, too
*check_var_types = \&C::Blocks::Type::NV::check_var_types;

########################################################################
               package C::Blocks::Type::uint_no_init;
########################################################################
our $TYPE = 'unsigned int';
our $INIT = 'just_gimme_zero';
our $CLEANUP = 'sv_setuv';
# Should check sign, too
*check_var_types = \&C::Blocks::Type::NV::check_var_types;




1;
