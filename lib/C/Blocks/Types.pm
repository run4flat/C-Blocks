package C::Blocks::Types;
use strict;
use warnings;

# The purpose of this package is to provide short type names that are
# associated with the lengthy package names:
use constant {
	# floating point
	NV => 'C::Blocks::Type::NV',
	double => 'C::Blocks::Type::double',
	float => 'C::Blocks::Type::float',
	# basic integer types
	IV => 'C::Blocks::Type::IV',
	short => 'C::Blocks::Type::short',
	Int => 'C::Blocks::Type::int',
	long => 'C::Blocks::Type::long',
	UV => 'C::Blocks::Type::UV',
	uint => 'C::Blocks::Type::uint',
	ushort => 'C::Blocks::Type::ushort',
	ulong => 'C::Blocks::Type::ulong',
	# array types
	double_array => 'C::Blocks::Type::double_array',
	float_array => 'C::Blocks::Type::float_array',
	int_array => 'C::Blocks::Type::int_array',
	char_array => 'C::Blocks::Type::char_array',
};

use Exporter qw(import);
our @EXPORT_OK = qw(NV double float IV short Int long UV uint
	double_array float_array int_array char_array);
our %EXPORT_TAGS = (
	basic => [qw(short Int long ushort uint ulong float double)],
	perl_num => [qw(NV IV UV)],
	all => [@EXPORT_OK],
);

########################################################################
                   package C::Blocks::PerlAPI::Type;
########################################################################

sub c_blocks_init_cleanup {
	my ($package, $C_name, $sigil_type, $pad_offset) = @_;
	my $data_type = $package->data_type;
	my $getter = $package->getter;
	my $setter = $package->setter;
	
	my $init_code = "$sigil_type * _hidden_$C_name = ($sigil_type*)PAD_SV($pad_offset); "
		. "$data_type $C_name = $getter(_hidden_$C_name); ";
	my $cleanup_code = "$setter(_hidden_$C_name, $C_name);";
	
	return ($init_code, $cleanup_code);
}

########################################################################
#                   Floating point
########################################################################
package C::Blocks::Type::NV;
our @ISA = qw(C::Blocks::PerlAPI::Type);
sub data_type { 'NV' }
sub getter { 'SvNV' }
sub setter { 'sv_setnv' }

package C::Blocks::Type::double;
our @ISA = qw(C::Blocks::Type::NV);
sub data_type { 'double' }

package C::Blocks::Type::float;
our @ISA = qw(C::Blocks::Type::NV);
sub data_type { 'float' }

########################################################################
#               Signed Integers
########################################################################
package C::Blocks::Type::IV;
our @ISA = qw(C::Blocks::PerlAPI::Type);
sub data_type { 'IV' }
sub getter { 'SvIV' }
sub setter { 'sv_setiv' }

package C::Blocks::Type::int;
our @ISA = qw(C::Blocks::Type::IV);
sub data_type { 'int' }

package C::Blocks::Type::short;
our @ISA = qw(C::Blocks::Type::IV);
sub data_type { 'short' }

package C::Blocks::Type::long;
our @ISA = qw(C::Blocks::Type::IV);
sub data_type { 'long' }

########################################################################
#               Unsigned Integers
########################################################################
package C::Blocks::Type::UV;
our @ISA = qw(C::Blocks::PerlAPI::Type);
sub data_type { 'UV' }
sub getter { 'SvUV' }
sub setter { 'sv_setuv' }

package C::Blocks::Type::uint;
our @ISA = qw(C::Blocks::Type::UV);
sub data_type { 'unsigned int' }

package C::Blocks::Type::ushort;
our @ISA = qw(C::Blocks::Type::UV);
sub data_type { 'unsigned short' }

package C::Blocks::Type::ulong;
our @ISA = qw(C::Blocks::Type::UV);
sub data_type { 'unsigned long' }

########################################################################
#               Arrays
########################################################################
package C::Blocks::Type::double_array;
sub data_type { 'double' }
sub c_blocks_init_cleanup {
	my ($package, $C_name, $sigil_type, $pad_offset) = @_;
	my $data_type = $package->data_type;
	
	my $init_code = join(";\n",
		"$sigil_type * _hidden_$C_name = ($sigil_type*)PAD_SV($pad_offset)",
		"STRLEN _length_$C_name",
		"$data_type * $C_name = ($data_type*)SvPVbyte(_hidden_$C_name, _length_$C_name)",
		"_length_$C_name /= sizeof($data_type)",
		'',
	);
	
	return $init_code;
}

package C::Blocks::Type::float_array;
our @ISA = qw(C::Blocks::Type::double_array);
sub data_type { 'float' }

package C::Blocks::Type::int_array;
our @ISA = qw(C::Blocks::Type::double_array);
sub data_type { 'int' }

package C::Blocks::Type::char_array;
our @ISA = qw(C::Blocks::Type::double_array);
sub data_type { 'char' }

# Other types:
# int2ptr
# uint2ptr
