use strict;
use warnings;
use C::Blocks::Types::Struct;

########################################################################
                package C::Blocks::Types::IsaStruct;
########################################################################
our $VERSION = '0.42';
$VERSION = eval $VERSION;
use Carp;

# To document: short_name  => String [last bareword of caller's package]
#            : C_type      => same as caller's package
sub import {
	my ($package, %args) = @_;
	my $caller_package = caller;
	
	# Figure our short name. Use given, or if none, deduce from package
	my $short_name = $args{short_name};
	if (not $short_name) {
		$short_name = $caller_package;
		$short_name =~ s/.*:://;
	}
	
	# Figure out the C type
	my $C_type = $args{C_type} || $caller_package;
	
	# Add the C type method to caller's package, and make caller's
	# package inherit from the struct base class for general reuse
	{
		no strict 'refs';
		
		# Set up the type's data type method
		*{"$caller_package\::c_blocks_data_type"} = sub () { $C_type };
		
		# Add this package to caller's @ISA
		push @{"$caller_package\::ISA"}, 'C::Blocks::Types::Struct';
		
		# Set up a method that produces the default short name; make
		# copy of short_name to suppress warnings for const subs
		my $short_name2 = $short_name;
		*{"$caller_package\::default_short_name"} = sub () { $short_name2 };
		
		# Explicitly inject import method into calling package
		*{"$caller_package\::import"} = \&C::Blocks::Types::IsaStruct::Base::import;
		
		# Turn off C::Blocks warnings in caller about import method...
		warnings->unimport('C::Blocks::import');
	}
}

########################################################################
             package C::Blocks::Types::IsaStruct::Base;
########################################################################
# The class that implements all of the reusable methods. Actually,
# C::Blocks::Types::Struct implements all of the resuable methods except
# for the import method, so we'll implement that and inheret the rest.

our @ISA = qw(C::Blocks::Types::Struct);
sub import {
	my ($package, %args) = @_;
	my $caller_package = caller;
	
	# install this type's short name in caller's package
	my $short_name = $args{short_name} || $package->default_short_name;
	no strict 'refs';
	# Suppress a warning by making a very local variable
	my $package_const = $package;
	*{"$caller_package\::$short_name"} = sub () { $package_const };
	
	# Load this package's shared code if there is any
	my $symtab = ${"$package\::__cblocks_extended_symtab_list"};
	C::Blocks::load_lib($package) if defined $symtab;
}

1;

__END__

=head1 NAME

C::Blocks::Types::IsaStruct - declare sharable struct types stored as packed data

=head1 VERSION

This documentation is for v0.42

=head1 SYNOPSIS

 ## Basic usage
 package My::Struct::Type;
 use C::Blocks;
 use C::Blocks::Types::IsaStruct;
 cshare {
     typedef struct My::Struct::Type_t {
         int x;
         int y;
     } My::Struct::Type;
 }

=head1 DESCRIPTION

The goal of C::Blocks::Types::IsaStruct is to let you create a struct 
type that can be easily shared, and then get out of your way. That is, 
this is the module you will use to create the C::Blocks type for a 
struct that others can use to seamlessly transition their C<$variable> 
between Perl and C.

If you just need to quickly create a type for an internal struct, you
should look into L<C::Blocks::Types::Struct>. That module provides an
interface for creating a type that is more expedient, but less
sharable.

This module helps you create a I<type> class. This does not create a 
full-blown class for your struct, and specifically it does not create 
Perl methods to access and modify members. A full-blown class system is 
in order for that case, and that is beyond the scope of the approach
provided by C::Blocks::Types::IsaStruct.

There are two basic approaches to creating a module whose job is to 
share struct types. The first approach is to create one module file for 
each struct type. This approach makes sense when you don't have too 
many structs to declare, and also when the structs have a library of 
functions for manipulating them. The alternative approach is to place 
all of the struct declarations and type classes into a single module 
file. This makes sense when you have lots of structs or when you need 
to generate struct and/or type information on the fly. In that case, 
the package associated with the module file should have an import 
method that knows how to parcel out the different struct types that 
might or might not be wanted by the caller.

=head2 One struct per module file

When you're using C::Blocks::Types::IsaStruct, the simplest approach is
to have one struct per module file. Such a module would:

=over

=item declare the package

The package statement must match the module file name.

=item use C::Blocks

This is not imported for you by IsaStruct automatically, and you will
need it to declare a C<cshare> block with the C struct layout.

=item use C::Blocks::Types::IsaStruct

This will endow your package with all of the type methods your package
will need to serve as a type class. There are some use-time arguments
that you might include, discussed below.

=item cshare with struct

This will provide the C symbol table that gets shared with callers when 
they use this module. It will need the struct layout, and should 
include any functions that your caller might find useful for 
manipulating the structs you provide.

=back

Beyond these bare minimum aspects, you may also feel compelled to 
provide Perl methods for manipuating your structs. Your pod will also
document this struct and its interface in detail. That last part may
serve as a litmus test: if you could reduce duplicate documentation or
Perl code by combining many of your structs into a single module, you
might consider the next approach.

=head2 Many structs in a single module file

When many structs are declared in a single module file, you need to
provide a mechanism for your caller to C<use> your module and select
which struct symbol tables get pushed into their lexical scope. Such a
module file will likely contain:

=over

=item package matching module name

This package will implement an C<import> method that takes user 
arguments and selectively imports the symbol tables and types defined 
elsewhere in the module. A sensible way to achieve this is to take a
list of type short-names and delegate to their C<import> method. If
the structs are declared in a C<cshare> under this package, it will
need to be loaded in the C<import> method with an explicit call to
C<C::Blocks::load_lib>.

=item one package for each struct type

Each struct will need to have a unique package with a structue matching 
the one outlined above for a single module per type. That package will 
C<use> C::Blocks::Types::IsaStruct, and so will have a well-defined 
C<import> method even though there is no way to C<use> the package 
directly. The struct layout will either be part of the package, or it
will be defined in a C<cshare> block belonging to the main package for
this module.

=back
