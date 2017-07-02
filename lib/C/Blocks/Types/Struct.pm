use strict;
use warnings;

########################################################################
                package C::Blocks::Types::Struct;
########################################################################
use Carp;

sub import {
	my ($package, @structs) = @_;
	my $caller_package = caller;
	for my $struct_type (@structs) {
		my $C_type = my $short_name = $struct_type;
		# Unpack the two-tuple if so supplied.
		if (ref($struct_type)) {
			croak("Structs must be declared by name, or a name => C_type arrayref pair")
				if ref($struct_type) ne ref([])
					of @$struct_type != 2;
			($short_name, $C_type) = @$struct_type;
		}
		
		# Check that the Perl-level type name is a bareword
		$short_name =~ /^[a-zA-Z_]\w*$/
			or croak("`$short_name' is not a valid type name");
		
		# Build the struct's type package and inject the short name
		# into the caller's package
		{
			my $struct_package = "$caller_package\::_struct::$short_name";
			no strict 'refs';
			*{"$caller_package\::$short_name"} = sub () { $struct_package };
			@{"$struct_package\::ISA"} = qw(C::Blocks::Types::Struct);
			*{"$struct_package\::c_blocks_data_type"} = sub () { $C_type };
		}
	}
}

sub c_blocks_init_cleanup {
	my ($type_package, $C_name, $sigil_type, $pad_offset) = @_;
	my $C_type = $type_package->c_blocks_data_type;
	
	my $init_code = qq{
		$sigil_type * SV_$C_name = ($sigil_type*)PAD_SV($pad_offset);
		#define $C_name (*POINTER_TO_$C_name)
		if (!SvPOK(SV_$C_name)) {
			SvUPGRADE(SV_$C_name, SVt_PV);
			SvGROW(SV_$C_name, sizeof($C_type));
			SvCUR(SV_$C_name) = sizeof($C_type);
			SvPOK_only(SV_$C_name);
		}
		$C_type * POINTER_TO_$C_name = ($C_type *)SvPVX(SV_$C_name);
	};
	
	return $init_code;
}

# The next few methods may someday be used when I add signatures to csubs...
sub c_blocks_pack_SV {
	my ($type_package, $C_name, $SV_name, $must_declare_SV) = @_;
	my $C_type = $type_package->c_blocks_data_type;
	
	return "SV * $SV_name = newSVpvn(&$C_name, sizeof($C_type));"
		if $must_declare_SV;
	return "sv_setpvn($SV_name, &$C_name, sizeof($C_type));";
}

sub c_blocks_new_SV {
	my ($type_package, $C_name) = @_;
	my $C_type = $type_package->c_blocks_data_type;
	return "newSVpvn(&$C_name, sizeof($C_type))"
}

sub c_blocks_unpack_SV {
	my ($type_package, $SV_name, $C_name, $must_declare_name) = @_;
	my $C_type = $type_package->c_blocks_data_type;
	my $declare = '';
	$declare = "$C_type $C_name;" if $must_declare_name;
	return "$declare Copy(SvPVbyte_nolen($SV_name), $C_name, 1, $C_type);";
}

1;

__END__

XXX working with pointers; allocation for interpolated variables;
*not* represented as pointer because you can't change it's address

=head1 NAME

C::Blocks::Types::Struct - simple interface for declaring struct types

=head1 SYNOPSIS

 use C::Blocks;
 use C::Blocks::Types::Struct
   [Point => 'C_Point'],
   'Point2',
   ['Point3' => 'struct Point3'];
 
 clex {
   typedef struct C_Point_t {
     int x;
     int y;
   } C_Point;
   
   typedef struct Point2_t {
     int x;
     int y;
   } Point2;
   
   struct Point3 {
     int x;
     int y;
   };
 }
 
 my Point $thing = pack('ii', 3, 4);
 cblock {
   printf("thing's x is %d\n", $thing.x);
 }

=head1 DESCRIPTION

It is possible to get all kinds of data into Perl, including scalars 
containing byte representations of structured data. It's easy to declare
structs in C<cshare> and C<clex> blocks, and C::Blocks::Types::Struct is
a simple utility to generate C::Blocks types for those structs.

Note that the types created using this module are not easily shared.
If you want to declare types for others to use generally, you should
see L<C::Blocks::Types::IsaStruct>.

The two steps necessary for declaring your struct type are to (1) generate
the Perl package for your type using this module and (2) declare the
struct layout using a C<clex> or C<cshare> block.

The arguments for the C<use> statement of this package are individual
type descriptions, which are either simple strings or arrayrefs of the
Perl type name and the C type name:

=over

=item Single String

If you simply provide a string, this will be the short name (on the Perl
side) for your type, and it will be assumed that you have C<typedef>'d
a struct to this same name. The single string must be a valid bareword:
no double-colons, spaces, or symbols apart from the underscore. The
first character may not be a number.

For example:

  use C::Blocks::Type::Struct 'MyStruct';
  ...
  cblock {
      typedef struct MyStruct_t {
          int a;
          double b;
      } MyStruct;
  }
  ...
  my MyStruct $my_struct;
  ...
  cblock {
      ...
      $my_struct.a = 5;
      ...
  }

=item Arrayref Pair

If you provide an arrayref with a pair of strings, then the first
element will be the Perl type (as for the single string argument
described above) while the second string will be the C type. This is
helpful if you want to use a Perl type name that differs from the C
C<typedef>'d name, or if you don't want to use a C<typedef>d alias for
the struct and just want to call it C<struct some_thing>.


For example:

  use C::Blocks::Type::Struct [MyStruct => 'struct SomeStruct'];
  ...
  cblock {
      struct SomeStruct {
          int a;
          double b;
      };
  }
  ...
  my MyStruct $my_struct;
  ...
  cblock {
      ...
      $my_struct.a = 5;
      ...
  }

=back




provides a convenient means of declaring that 
layout so that you can get a usable Type for the struct. This then 
makes it possible to transparently interact with the C representation 
of the data in your C<cblock>s, while keeping the binary representation 
stored in a Perl scalar.

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


** short_name must be a valid Perl identifier
** hashref form: short_name, elements, declared_package, package,
   C_type
