use strict;
use warnings;

package C::Blocks::Types::Pointers;
our $VERSION = '0.42';
$VERSION = eval $VERSION;

# XXXXXXXX use Package::Generator for better control?

sub import {
	my ($package, @args) = @_;
	
	while (@args) {
		my ($name, $signature) = splice @args, 0, 2;
		
		# create the type's package
		no strict 'refs';
		*{"C::Blocks::Types::Pointers::${name}::c_blocks_init_cleanup"}
			= generate_init_cleanup($signature);
		
		# Shove the short name into the caller's context. Creating a
		# separate variable $long_name is part of the trick to getting
		# Perl to believe that this is actually a constant sub.
		my $pkg = caller;
		my $long_name = "C::Blocks::Types::Pointers::$name";
		*{"${pkg}::${name}"} = sub () { $long_name };
	}
}

sub generate_init_cleanup {
	my $pointer_type = shift;
	return sub {
		my ($package, $C_name, $sigil_type, $pad_offset) = @_;
		
		my $init_code = qq{
			$sigil_type * SV_$C_name = ($sigil_type*)PAD_SV($pad_offset);
			#define $C_name (*POINTER_TO_$C_name)
			if (!SvIOK(SV_$C_name)) SvUPGRADE(SV_$C_name, SVt_IV);
			$pointer_type * POINTER_TO_$C_name = INT2PTR($pointer_type *, &SvIVX(SV_$C_name));
		};
		
		return $init_code;
	};
}

__END__

=head1 NAME

C::Blocks::Types::Pointers - declare pointer types for C::Blocks

=head1 VERSION

This documentation is for v0.42

=head1 SYNOPSIS

 use C::Blocks;
 use C::Blocks::Types::Pointers MyStruct => 'MyStruct*';
 
 # Later along in code
 my MyStruct $foo = 0;
 
 ... needs more documentation ...
