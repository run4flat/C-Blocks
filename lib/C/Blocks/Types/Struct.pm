use strict;
use warnings;
use C::Blocks;

########################################################################
                package C::Blocks::Types::Struct;
########################################################################
use Carp;

# I could emulate one of two interfaces. I have C::Blocks::SOS and
# C::Blocks::Types::Pointers. For now, I am going to emulate
# C::Blocks::Types::Pointers, as it is more aligned with the
# data-munging spirit of the basic types. If I wanted to create accessor
# methods and such, I think that would go under C::Blocks::Class::Struct
# or similar.

sub import {
	my ($package, @args) = @_;
	my $pkg = caller;
	while (@args) {
		my ($name, $elements) = splice @args, 0, 2;
		
		# set up the type information for this struct. The struct
		# generation only does something if the package has not yet
		# been created.
		my $struct_package = generate_struct_package($name, $elements);
		
		# Types are in place. Load the struct into the caller's scope.
		C::Blocks::load_lib($struct_package);
		
		no strict 'refs';
		*{"${pkg}::${name}"} = sub () { $struct_package };
	}
}

sub generate_struct_package {
	my ($name, $elements) = @_;
	my $struct_package = "C::Blocks::Types::Struct::${name}";
	# Just return the package name if it's already generated.
	return $struct_package
		if $struct_package->can('c_blocks_init_cleanup');
	
	# Make sure they gave a valid list of elements
	croak("Definition of struct `$name' must be an array reference of `type => name' pairs")
		if not $elements or not ref($elements)
			or ref($elements) ne ref([])
			or @$elements % 2 == 1;
	# Handle struct "declarations", which presume that the layout was
	# declared elsewhere.
	croak("Declaration of struct '$struct_package' without prior definition")
		if @$elements == 0;
	
	# We need to build the struct package. Assemble the member
	# declarations:
	my $member_declarations = '';
	for (my $i = 0; $i < @$elements; $i += 2) {
		my ($type, $name) = (@$elements)[$i, $i+1];
		$member_declarations .= "\t\t\t\t$type $name;\n";
	}
	
	eval qq{
		package $struct_package;
		our \@ISA = qw(C::Blocks::Types::Struct);
		use C::Blocks;
		use C::Blocks::PerlAPI;
		cshare {
			typedef struct ${struct_package}_t {\n$member_declarations
			} $struct_package;
		}
		1;
	} or die $@;
	
	return $struct_package;
}

sub c_blocks_init_cleanup {
	my ($type_name, $C_name, $sigil_type, $pad_offset) = @_;
	
	my $init_code = qq{
		$sigil_type * SV_$C_name = ($sigil_type*)PAD_SV($pad_offset);
		#define $C_name (*POINTER_TO_$C_name)
		if (!SvPOK(SV_$C_name)) {
			SvUPGRADE(SV_$C_name, SVt_PV);
			SvGROW(SV_$C_name, sizeof($type_name));
			SvCUR(SV_$C_name) = sizeof($type_name);
			SvPOK_only(SV_$C_name);
		}
		$type_name * POINTER_TO_$C_name = ($type_name *)SvPVX(SV_$C_name);
	};
	
	return $init_code;
}

sub c_blocks_pack_SV {
	my ($type_name, $C_name, $SV_name, $must_declare_SV) = @_;
	return "SV * $SV_name = newSVpvn(&$C_name, sizeof($type_name));"
		if $must_declare_SV;
	return "sv_setpvn($SV_name, &$C_name, sizeof($type_name));";
}

sub c_blocks_new_SV {
	my ($type_name, $C_name) = @_;
	return "newSVpvn(&$C_name, sizeof($type_name))"
}

sub c_blocks_unpack_SV {
	my ($type_name, $SV_name, $C_name, $must_declare_name) = @_;
	my $declare = '';
	$declare = "$type_name $C_name;" if $must_declare_name;
	return "$declare Copy(SvPVbyte_nolen($SV_name), $C_name, 1, $type_name);";
}

sub c_blocks_data_type { return $_[0] }

1;

__END__

=head1 NAME

C::Blocks::Types::Struct - struct types that play well with packed data

=head1 SYNOPSIS

 use C::Blocks;
 use C::Blocks::Types::Struct;
   Point => [
     int => 'x',
     int => 'y',
   ];
 
 my Point $thing = pack('ii', 3, 4);
 cblock {
   printf("thing's x is %d\n", $thing.x);
 }

=head1 DESCRIPTION

It is possible to get all kinds of data into Perl, including byte
representations of structured data. C::Blocks::Types::Struct provides a
convenient means of declaring that layout so that you can get a usable
Type for the struct. This then makes it possible to transparently
interact with the C representation of the data in your C<cblock>s,
while keeping the binary representation stored in a Perl scalar.

Just like C<C::Blocks::Types::Pointers>, this module does not create a
full-blown class for your struct. In particular, it does not create
Perl methods to access and modify members of the struct. For that, a
full-blown class system is really in order.

=head2 Defining Struct Types

To declare a struct type, simply provide a short name for your struct
type and an arrayref of the struct layout. The arrayref should contain
pairs in the form of C<< C-type => name >>. The C type is not checked;
it is assumed you know what you are doing.

For example, this C struct:

  typede struct {
      int x;
      int y;
  } Point;

is equivalent to saying:

  use C::Blocks::Types::Struct
    Point => [
        int => 'x',
        int => 'y',
    ];

The key difference between a C<cshare> block with the first and the
declaration of the second is that that second provides all of the type
information and marshalling you need to directly us a perl C<$scalar> in
your cblock.

=head2 Reusing Previously Defined Types

If you know that a struct layout has already been defined, you can
simply pull in its layout by passing an empty array-ref:

 use C::Blocks::Types::Struct Point => [];

This will check that underlying package has indeed been defined already,
then perform the rest of the necessary setup for you lexical scope.


