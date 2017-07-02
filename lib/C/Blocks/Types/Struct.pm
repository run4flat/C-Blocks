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
					or @$struct_type != 2;
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

=head1 NAME

C::Blocks::Types::Struct - a simple interface for declaring struct types

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
 
 my Point $thing2;
 cblock {
   // $thing2's memory is allocated for us!!
   $thing2.x = 5;
   $thing2.y = 10;
 }

=head1 DESCRIPTION

It is possible to get all kinds of data into Perl, including scalars 
containing byte representations of structured data. It's also easy to
declare structs in C<cshare> and C<clex> blocks. C::Blocks::Types::Struct
is a simple utility to generate the SV-to-C-type mapping, i.e. the
C::Blocks types, for those structs.

Just like C<C::Blocks::Types::Pointers>, this module does not create a 
full-blown class for your struct. In particular, it does not create 
Perl methods to access and modify members of the struct. Instead, it 
takes a very lean approach. Just like a scalar built using Perl's 
C<pack>, your Perl variable that has been typed to one of these structs 
should be thought of as an opaque buffer. The contents can only be 
modified within a C<cblock>, but the type system provides for fluid
transitions between C and Perl code.

Furthermore, the types created using this module are not meant to be 
shared: they are only meant for local use. If you want to declare types 
for others to use generally, you should see 
L<C::Blocks::Types::IsaStruct>.

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

=head1 ALLOCATION AND MEMBER ACCESS

C::Blocks::Types::Struct tries to make allocation and de-allocation 
seemless. It accomplishes this by utelizing the scalar's PV buffer for 
the struct data. In the examples above, the typed variables were not 
initialized in any way, so there was nothing in the Perl code that 
would have allocated any memory for the struct. However, the 
initialization code for the type (which is responsible for translating 
from the Perl SV to a variable of the given C type) checks that the 
scalar has enough space for your struct. If it is not the correct SV 
type, it'll be converted to being a PV scalar; if it doesn't have 
enough room, more space will be allocated.

In short, any time you use a typed and sigiled variable in a cblock,
it'll always have enough memory and you should not need to worry about
memory-access-related segmentation faults.

Second, data members are accessed with direct member dereference, i.e.
with the C<.> operator. If a struct contains the member C<x>, it is 
accessed via ".x" below:

  $thing.x = 5;

As you probaby know about C, if this were a pointer we would need to use
the arrow operator, i.e. 

  pointer_to_struct->x = 5;

Of course, C::Blocks::Types::Struct is using a pointer under the hood, 
so how does it manage to provide an interface with direct member 
access? The actual means for accessing the struct involves a convoluted 
macro-wrapped dereferenced access to a pointer. I take this approach
because of the similarities between a C struct declared in automatic
memory (on the stack) and one of these structs. In either case, you (the
programmer) are explicitly forbidden from managing the memory. You can
access and change struct I<members>, but you cannot set the memory
location of the struct itself. (In this case, if you had direct
access to the pointer in the SV's PVX slot then you could change it,
breaking a number of assumptions about the SV internals.) By
providing an access that hides the nature of the pointer, I strongly
discourage these sorts of mistakes from cropping up.

