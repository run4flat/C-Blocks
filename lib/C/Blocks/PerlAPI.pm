use strict;
use warnings;

package C::Blocks::PerlAPI;

# Figure out where the symbol table serialization file lives
use File::ShareDir;
use File::Spec;
our $symtab_file_location;
BEGIN {
	$symtab_file_location = File::Spec->catfile(
		File::ShareDir::dist_dir('C-Blocks'),'perl.h.cache'
	);
}

require DynaLoader;
our @ISA = qw( DynaLoader C::Blocks::libloader );

our $VERSION = '0.40_01';
bootstrap C::Blocks::PerlAPI $VERSION;
$VERSION = eval $VERSION;

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
package C::NV_t;
our @ISA = qw(C::Blocks::PerlAPI::Type);
sub data_type { 'NV' }
sub getter { 'SvNV' }
sub setter { 'sv_setnv' }

package C::double_t;
our @ISA = qw(C::NV_t);
sub data_type { 'double' }

package C::float_t;
our @ISA = qw(C::NV_t);
sub data_type { 'float' }

########################################################################
#               Signed Integers
########################################################################
package C::IV_t;
our @ISA = qw(C::Blocks::PerlAPI::Type);
sub data_type { 'IV' }
sub getter { 'SvIV' }
sub setter { 'sv_setiv' }

package C::int_t;
our @ISA = qw(C::IV_t);
sub data_type { 'int' }

package C::short_t;
our @ISA = qw(C::IV_t);
sub data_type { 'short' }

########################################################################
#               Unsigned Integers
########################################################################
package C::UV_t;
our @ISA = qw(C::Blocks::PerlAPI::Type);
sub data_type { 'UV' }
sub getter { 'SvUV' }
sub setter { 'sv_setuv' }

package C::uint_t;
our @ISA = qw(C::UV_t);
sub data_type { 'unsigned int' }

########################################################################
#               Buffers
########################################################################
package C::pdouble_t;
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

package C::pfloat_t;
our @ISA = qw(C::pdouble_t);
sub data_type { 'float' }

package C::pint_t;
our @ISA = qw(C::pdouble_t);
sub data_type { 'int' }

package C::pchar_t;
our @ISA = qw(C::pdouble_t);
sub data_type { 'char' }

# Other types:
# int2ptr
# uint2ptr

1;

__END__

=head1 NAME

C::Blocks::PerlAPI - C interface for interacting with Perl

=head1 SYNOPSIS

 use strict;
 use warnings;
 use C::Blocks;
 use C::Blocks::PerlAPI;
 
 cshare {
     void say_hi() {
         PerlIO_stdoutf("hi!");
     }
 }

=head1 DESCRIPTION

This C::Blocks module provides access to the Perl C library. It is roughly
equivalent to including these lines at the top of your cblocks:

 #define PERL_NO_GET_CONTEXT
 #include "EXTERN.h"
 #include "perl.h"
 #include "XSUB.h"

as well as linking to F<libperl>. Of course, as a C::Blocks module, it also
avoids the re-parsing necessary if you were to include those at the top of each
of your cblocks.

The Perl C library is vast, and a tutorial for it may be useful at some point.
Until that time, I will simply refer you to L<perlapi> and L<perlguts>.

=cut
