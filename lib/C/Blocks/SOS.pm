use strict;
use warnings;
use C::Blocks;

package C::Blocks::SOS;
use Carp;

=head1 NAME

C::Blocks::SOS - a Simple Object System for C::Blocks

=head1 SYNOPSIS

 #######
 # implementing a point class
 #######
 package My::Point;
 use C::Blocks::SOS sub ($c) {
     $c->extends 'Other::Class';
     $c->has x => (isa => 'double');
     $c->has y => (isa => 'double');
     $c->method distance_from => (
         expects => [My::Point => 'other_point'],
         returns => 'double',
         language => 'C',
     );
     $c->method distance_from_xy => (
         expects => [double => 'x', double => 'y'],
         returns => 'double'
         language => 'Perl',
     );
     $c->class_has curr_canvas => (isa => 'My::Canvas');
 };
 
 sub distance_from_xy ($self, $x, $y) {
     return sqrt(($x - $self->x)**2 + ($y - $self->y)**2);
 };
 
 use C::Blocks::Filter::BlockArrowMethods;
 cshare {
     ${ My::Point->_declare }
     
     ${ My::Point->_signature('distance_from') } {
         double dx = other_point=>x() - self=>x();
         double dy = other_point=>y() - $self=>y();
         return sqrt(dx*dx + dy*dy);
     }
 }
 cblock { ${ My::Point->_initialize } }

=cut

sub import {
	my (undef, $subref) = @_;
	croak("You must provide a sub to declare your class")
		unless $subref and ref($subref) and ref($subref) eq ref(sub{});
	my $package = caller;
	my $class_obj = bless {
		package => $package,
		extends => undef,
		attributes => [],
		attr_by_name => {},
		vtable => [],
		vtable_by_name => {},
		needs_new_vtable  => undef, # true if new methods
		needs_new_object  => undef, # true if new vtable or new attributes
		# Strings that hold types and type names needed in code generation
		C_vtable_instance => $package . '::VTABLE_INSTANCE',
		C_vtable_layout   => undef, # pkg::VTABLE_LAYOUT
		C_obj_layout      => undef, # struct pkg_t
		C_class_type      => undef, # pkg (typedef'd as pointer to obj_layout)
	};
	
	# execute the code block that declares the class layout
	$subref->($class_obj);
	# execute the code block that declares the class layout
#	{
#		no strict 'refs';
#		local *{"$package\::has"} = sub { $class_obj->has(@_) };
#		local *{"$package\::method"} = sub { $class_obj->method(@_) };
#		local *{"$package\::extends"} = sub { $class_obj->extends(@_) };
#		local *{"$package\::with"} = sub { $class_obj->with(@_) };
#		$subref->();
#	}

	# Set default ISA
	$class_obj->extends('C::Blocks::SOS::Base')
		unless $class_obj->{extends} or $package eq 'C::Blocks::SOS::Class';
	
	# Set up C strings that hold per-class C-types
	$class_obj->{C_vtable_layout} = $package . '::VTABLE_LAYOUT'
		if $class_obj->{needs_new_vtable};
	if ($class_obj->{needs_new_object}) {
		$class_obj->{C_obj_layout} = 'struct ' . $package . '_t';
		$class_obj->{C_class_type} = $package;
	}
	
	# Also inject a few methods into the caller's package
	# _class, _declare, _signature, and _initialize
	no strict 'refs';
	*{"$package\::_class"} = sub { $class_obj };
	*{"$package\::_declare"} = \&_declare;
	*{"$package\::_signature"} = \&_signature;
	*{"$package\::_initialize"} = \&_initialize;
	
#	if ($package ne 'C::Blocks::SOS::Base'
#		and $package ne ''C::Blocks::SOS::Class')
#	{
#		C::Blocks::load_lib('C::Blocks::SOS::Base');
#	}
}

######################################
# Utility functions
######################################

# Allow Types
#my $basic_types = qr/^(((un)?signed($|\s+))?(char|(short|long(\s+long)?)?(\s+int)?|int)|void|float|(long )?double|.*\*)$/;
sub _validate_type {
	my ($self, $type) = @_;
	# void is fine, of course
	return 1 if $type eq 'void';
	# Starts with '^' means "don't type-check me"
	return 1 if $type =~ /^\^/;
	# Ignore subref types for the moment... too complicated
	return 1 if ref($type) and ref($type) eq ref(sub{});
	# Ignore pointers for the moment
	return 1 if $type->can("c_blocks_unpack_SV")
		and $type->can("c_blocks_pack_SV");
}

# Utility function for getting references to package variables
sub _get_package_ref {
	my ($sigil, $package, $refname) = @_;
	return eval '\\' . $sigil . $package . '::' . $refname;
}

######################################
# extends and with - declaring parent classes and roles
######################################

# declare parent class: import methods
sub extends {
	return $_[0]->{extends} if @_ == 1;
	my ($self, $parent_package) = @_;
	my $parent = $parent_package->_class;
	# Only declare "extends" once
	croak("Already declared a parent class `$self->{extends}'")
		if $self->{extends};
	# ensure we're extending a C::Blocks::SOS class
	croak("Cannot extend `$parent_package'; not a C::Blocks::SOS class")
		unless $parent_package->isa('C::Blocks::SOS::Class');
	# Update the attributes and methods.
	for my $attr (reverse @{$parent->{attributes}}) {
		my %copy = %$attr;
print "self's attribute names are ", join(', ', keys %{$self->{attr_by_name}}), "\n"
	if exists $self->{attr_by_name}{$copy{name}};
		croak("Already-declared attribute `$copy{name}' shares name with inherited attribute")
			if exists $self->{attr_by_name}{$copy{name}};
		unshift @{$self->{attributes}}, \%copy;
		$self->{attr_by_name}{$copy{name}} = \%copy;
	}
	for my $meth (reverse @{$parent->{vtable}}) {
		my %copy = %$meth;
		# Can be either a method or a class attribute.
		
		# check for duplication.
		if (exists $self->{vtable_by_name}{$copy{name}}) {
			my $declared_noun = 'method';
			$declared_noun = 'class attribute'
				if $parent->{vtable_by_name}{$copy{name}}{isa};
			my $inherited_noun = 'method';
			$inherited_noun = 'class attribute'
				if $self->{vtable_by_name}{$copy{name}}{isa};
			croak("Already-declared $declared_noun `$copy{name}' shares name with inherited $inherited_noun");
		}
		
		if ($copy{isa}) {
			# Attribute
			unshift @{$self->{vtable}}, \%copy;
			$self->{vtable_by_name}{$copy{name}} = \%copy;
		}
		else {
			# Method
			$copy{expects} = [ @{$copy{expects}} ]; # explicit copy of ref
			unshift @{$self->{vtable}}, \%copy;
			$self->{vtable_by_name}{$copy{name}} = \%copy;
		}
	}
	
	# Copy C code generation strings if we don't have them already
	for my $k (qw(C_vtable_layout C_obj_layout C_class_type)) {
		$self->{$k} ||= $parent->{$k};
	}
	
	C::Blocks::load_lib($parent_package);
	$self->{extends} = $parent_package;
	
	# Explicitly indicate Perl-level inheritance:
	my $ISA = _get_package_ref ('@', $self->{package}, 'ISA');
	push @$ISA, $parent_package;
}

# provide a keyword to incorporate roles
# roles must provide the "apply" method. This method should die, rather
# than croak, when it encounters exceptional behavior.
sub with {
	my ($self, $role, @args) = @_;
	eval {
		$role->apply($self, @args);
		1;
	} or do{
		my $to_croak = $@;
		$to_croak =~ s/\n$//;
		croak($to_croak);
	};
}

# Roles may require functionality.
sub requires {
	my ($self, $required_method) = @_;
	die("Missing required method $required_method\n")
		unless $self->{vtable_by_name}{$required_method};
}

######################################
# has - declaring attributes
######################################

# Add a new data member. Valid args include:
# isa        => C type
# accessors  => both/getter/setter/0
# class_attr => boolean, default is false, i.e. an object attribute
# C_init     => optional C expression that generates a value to
#               initialize this attribute
sub has {
	my ($self, $new_member, %attr) = @_;
	my ($list, $attr_name_lookup) = $attr{class_attr}
	                     ? ($self->{vtable}, $self->{vtable_by_name})
	                     : ($self->{attributes}, $self->{attr_by_name});
	# Make sure it doesn't already exist
	if (exists $attr_name_lookup->{$new_member}) {
		my $meta = 'Attribute';
		$meta = 'Method or class attribute' if $attr{class_attr};
		croak("$meta with name $new_member already exists")
	}
	
	# Indicate we'll need to create a new object struct layout
	$self->{needs_new_object} = 1;
	
	# Check the type	
	croak("Attribute must have a type") if not exists $attr{isa};
	croak("Invalid type") unless $self->_validate_type($attr{isa});
	
	$attr{name} = $new_member;
	# Handle accessors
	if (not exists $attr{accessors} or $attr{accessors} =~ /^(both|1)$/) {
		$self->_add_getter(%attr);
		$self->_add_setter(%attr);
	}
	elsif ($attr{accessors} eq 'getter') {
		$self->_add_getter(%attr);
	}
	elsif ($attr{accessors} eq 'setter') {
		$self->_add_setter(%attr);
	}
	elsif (!$attr{accessors}) {
		# OK, but do nothing
	}
	else {
		croak("Invalid `accessors' value `$attr{accessors}'");
	}
	
	# Clear out the "don't check my type" if so indicated
	$attr{isa} =~ s/^\^// unless ref($attr{isa});
	
	# Last step: add this to our list of attributes
	$attr_name_lookup->{$new_member} = \%attr;
	push @$list, \%attr;
	
}
# Two utility methods to creating accessors for an attribute.
sub _add_getter {
	my ($self, %attr) = @_;
	my $dereference = $attr{name};
	$dereference = "methods->$attr{name}" if $attr{class_attr};
	$self->method ("get_$attr{name}" => 
		language => 'C',
		returns => $attr{isa},
		C_code => qq{
			return self->$dereference;
		},
	);
}
sub _add_setter {
	my ($self, %attr) = @_;
	my $dereference = $attr{name};
	$dereference = "methods->$attr{name}" if $attr{class_attr};
	$self->method ("set_$attr{name}" =>
		language => 'C',
		returns => 'void',
		expects => [$attr{isa} => 'new_val'],
		C_code => qq{
			self->$dereference = new_val;
		},
	);
}

######################################
# method - declaring methods
######################################

# Add a new method; override an existing one. Valid args include:
# returns       C return type
# language      Perl, C, or C-only
# expects       list of type => name pairs
# C_code        optional string of C code to define this method
#               ** this is removed after the code is implemented
# class_method  boolean indicating if self or class is automatically
#               added as the first argument
#
# When done, these attributes will be present in the method's hash, and
# the following additional keys will be available:
# name     the short method name
# package  package containing the most recent implementation
# Perl_to_C_thunk, C_to_Perl_thunk
#          full function names of the C thunk functions; these will be
#          declared and defined in the original package
sub method {
	my ($self, $new_meth_name, %attr) = @_;
	if ($self->{vtable_by_name}{$new_meth_name}) {
		$self->_override_method($new_meth_name, %attr);
	}
	else {
		$self->_add_new_method($new_meth_name, %attr);
	}
}

sub _add_new_method {
	my ($self, $new_meth_name, %attr) = @_;
	# Make sure we have a return value
	croak("No return value for method `$new_meth_name'")
		unless exists $attr{returns};
	croak("Invalid return type for method `$new_meth_name'")
		if $attr{language} ne 'C-only'
			and not $self->_validate_type($attr{returns});
	$attr{returns} =~ s/^\^// unless ref($attr{returns});
	
	# Ensure a language specification; default to Perl
	$attr{language}
		= $self->_check_method_language($attr{language}, qw(Perl C C-only))
			|| 'Perl';
	
	# Indicate we'll need to create new vtable and object struct layouts
	$self->{needs_new_object} = $self->{needs_new_vtable} = 1;
	
	# Copy the arguments and validate
	my @arg_type_name_pairs = @{$attr{expects} || []};
	ARG_PAIRS: for (my $i = 0; $i < @arg_type_name_pairs; $i += 2) {
		my ($type, $name) = @arg_type_name_pairs[$i, $i+1];
		# Use standard type handling checking
		croak("Invalid type for $name, " . ($i/2+1) . "th argument to $new_meth_name")
			if $attr{language} ne 'C-only'
				and not $self->_validate_type($attr{returns});
		$arg_type_name_pairs[$i] =~ s/^\^//
			unless ref ($arg_type_name_pairs[$i]);
	}
	# Add self unless this is a class method.
	if ($attr{class_method}) {
		unshift @arg_type_name_pairs, sub { shift->{C_vtable_layout} . '*' } => 'class';
	}
	else {
		unshift @arg_type_name_pairs, sub { shift->{C_class_type} } => 'self';
	}
	
	# set up other bits of info
	$attr{expects} = \@arg_type_name_pairs;
	$attr{name} = $new_meth_name;
	$attr{package} = $self->{package};
	# Set up the C names for the thunks
	$attr{Perl_to_C_thunk} = "from_perl::$self->{package}::$new_meth_name";
	$attr{C_to_Perl_thunk} = "call_perl::$self->{package}::$new_meth_name";
	
	# Add to vtable and by-name lookup table
	push @{$self->{vtable}}, \%attr;
	$self->{vtable_by_name}{$new_meth_name} = \%attr;
}

# Makes sure the langauge is one of the specified strings, which are "C"
# "C-only" or "Perl", or a subset thereof. Croaks otherwise. Returns
# undef (and does *not* croak) if undef is supplied. Returns the
# indicated language on success.
sub _check_method_language {
	my ($self, $language, @allowed) = @_;
	return if not defined $language;
	croak("Method language must be chosen from: `" . join("', `", @allowed) . "'")
		unless grep { $_ eq $language } @allowed;
	return $language;
}

# When overriding a method, the language must be specified.
sub _override_method {
	my ($self, $meth_name, %attr) = @_;
	croak("Override to $meth_name cannot change arguments")
		if exists $attr{expects};
	croak("Override to $meth_name cannot change return type")
		if exists $attr{returns};
	
	# Same hashref is also in $self->{vtable}, so modifying this should
	# also modify the other.
	my $method_attributes = $self->{vtable_by_name}{$meth_name};
	
	# Set the language (which may or may not have changed)
	if ($method_attributes->{language} eq 'C-only') {
		$self->_check_method_language($attr{language}, qw(C C-only));
	}
	else {
		$method_attributes->{language} = $attr{language}
			if $self->_check_method_language($attr{language}, qw(Perl C));
	}
	
	# Indicate that this package has the C function's definition
	$method_attributes->{package} = $self->{package}
		if $attr{language} =~ /^C/;
}

######################################
# _declare
######################################

# Declares the class layout struct and function prototypes
sub _declare {
	my ($package) = @_;
	my $class = $package->_class;
	
	# Assemble the struct declarations
	my $struct_decl = $class->_gen_struct_decl;
	
	# Get the function declarations (or definitions if we have C_code)
	my $function_decl = $class->_gen_func_decl;
	
	# Get the vtable instance definition
	my $vtable_instance_decl = $class->_gen_vtable_def;
	
	# Return all of these put together
	return "$struct_decl$function_decl$vtable_instance_decl";
}

sub _gen_struct_decl {
	my $class = shift;
	# create object layout typedef (i.e. the class)
	my $to_return = '';
	$to_return .= "typedef $class->{C_obj_layout} * $class->{C_class_type};\n"
		if $class->{needs_new_object};
	# create the vtable layout
	if ($class->{needs_new_vtable}) {
		$to_return .= "typedef struct $class->{C_vtable_layout}_t $class->{C_vtable_layout};\n";
		$to_return .= "struct $class->{C_vtable_layout}_t {\n";
		for my $entry (@{$class->{vtable}}) {
			if ($entry->{isa}) {
				$to_return .= $class->_gen_attribute($entry);
			}
			else {
				$to_return .= $class->_gen_function_pointer($entry->{name}, $entry);
			}
			$to_return .= ";\n";
		}
		$to_return .= "};\n";
	}
	# create the object layout
	if ($class->{needs_new_object}) {
		$to_return .= "$class->{C_obj_layout} {\n";
		for my $entry (@{$class->{attributes}}) {
			$to_return .= $class->_gen_attribute($entry) . ";\n";
		}
		$to_return .= "};\n";
	}
	return $to_return;
}

sub _get_data_type_for {
	my ($self, $type_thing) = @_;
	return 'void' if $type_thing eq 'void';
	# Evaluate subref if it's a subref
	$type_thing = $type_thing->($self) if ref($type_thing);
	# get data type from package, or just return the type
	return $type_thing->c_blocks_data_type
		if $type_thing->can("c_blocks_data_type");
	return $type_thing;
	
}

sub _gen_attribute {
	my ($self, $entry) = @_;
	my $type = $self->_get_data_type_for($entry->{isa});
	return "$type $entry->{name}";
}

sub _gen_function_signature {
	my ($self, $name, $entry) = @_;
	# Get the return type
	my $return_type = $self->_get_data_type_for($entry->{returns});
	# Opening salvo
	my $to_return = "$return_type $name(";
	# Collect the arguments
	my @args = @{$entry->{expects}};
	for (my $j = 0; $j < @args; $j += 2) {
		$to_return .= ', ' if $j > 0;
		my ($arg_type, $arg_name) = @args[$j, $j+1];
		$arg_type = $self->_get_data_type_for($arg_type);
		$to_return .= "$arg_type $arg_name";
	}
	# closing bracket
	$to_return .= ")";
	
	return $to_return;
}
sub _gen_function_pointer {
	my ($self, $name, $entry) = @_;
	return $self->_gen_function_signature("(*$name)", $entry);
}
sub _gen_function_pointer_cast {
	my ($self, $entry) = @_;
	return '(' . $self->_gen_function_signature("(*)", $entry) . ')';
}

sub _gen_func_decl {
	my $self = shift;
	my $to_return = '';
	for my $entry (@{$self->{vtable}}) {
		# We only need to declare new functions
		next if $entry->{isa} or $entry->{package} ne $self->{package};
		
		my $full_name = $entry->{package} . '::' . $entry->{name};
		$to_return .= $self->_gen_function_signature($full_name, $entry);
		# If C_code is provided, create the function. Otherwise
		# just declare it.
		if ($entry->{C_code}) {
			$to_return .= "{\n$entry->{C_code}\n}\n";
			delete $entry->{C_code};
		}
		else {
			$to_return .= ";\n";
		}
		# Also generate the thunks for this
		$to_return .= $self->_gen_Perl_to_C_thunk($entry);
		$to_return .= $self->_gen_C_to_Perl_thunk($entry);
	}
	return $to_return;
}

sub _gen_Perl_to_C_thunk {
	my ($self, $entry) = @_;
	return '' if $entry->{language} eq 'C-only';
	my $to_return .= "XSPROTO($entry->{Perl_to_C_thunk}) {\n";
	# Unpack the Perl stack
	my @args = @{$entry->{expects}};
	my $arg_names;
	for (my $i = 0; $i < @args; $i += 2) {
		my $stack_index = $i / 2;
		my ($type_package, $name) = @args[$i, $i+1];
		$type_package = $type_package->($self) if ref($type_package);
		# Now we have the bona-fide package name for this type
		# Use its unpack code. Final arg of one means unpack needs to
		# include a declaration of $name in its returned string.
		$to_return .= $type_package->c_blocks_unpack_SV("ST($stack_index)"
			=> $name, 1);
		$arg_names .= ", " if $arg_names;
		$arg_names .= $name;
	}
	
	# generate return value variable declaration (if needed)
	my $capture_returned = '';
	if ($entry->{returns} ne 'void') {
		$to_return .= $self->_get_data_type_for($entry->{returns})
			. " TO_RETURN;\n";
		$capture_returned = "TO_RETURN =";
	}
	# Call the method
	$to_return .= "$capture_returned self->methods->$entry->{name}($arg_names);\n";
	
	# Push return value onto the stack
	if ($entry->{returns} eq 'void') {
		# Return empty if it's a void function
		$to_return .= "XSRETURN_EMPTY;\n";
	}
	else {
		my $return_package = $entry->{returns};
		$return_package = $return_package->($self) if ref ($return_package);
		# Wrap value in an SV and push it onto the stack
		$to_return .= "XSprePUSH;\n";
		$to_return .= "SV * SV_TO_RETURN = sv_newmortal();\n";
		$to_return .= $return_package->c_blocks_pack_SV($entry->{name} => "SV_TO_RETURN") . ";\n";
		$to_return .= "XPUSHs(SV_TO_RETURN);\n";
		$to_return .= "XSRETURN(1);\n";
	}
	$to_return .= "}\n";
	return $to_return;
}

sub _gen_C_to_Perl_thunk {
	my ($self, $entry) = @_;
	return '' if $entry->{language} eq 'C-only';
	# Signature
	my $to_return = $self->_gen_function_signature(
		$entry->{C_to_Perl_thunk}, $entry);
	
	# opening salvo
	my @args = @{$entry->{expects}};
	my $N_args = @args / 2;
	$to_return .= "{
		dSP;
		int count;
		ENTER;
		SAVETMPS;
		PUSHMARK(SP);
		EXTEND(SP, $N_args);\n";
	
	# pack the Perl stack
	for (my $i = 0; $i < @args; $i += 2) {
		my ($type_package, $name) = @args[$i, $i+1];
		$type_package = $type_package->($self) if ref($type_package);
		# Now we have the bona-fide package name for this type
		$to_return .= "PUSHs(sv_2mortal("
			. $type_package->c_blocks_new_SV($name) . "));\n";
	}
	$to_return .= "PUTBACK;\n";
	
	# Find and call the method
	my $return_type = $entry->{returns};
	my $flags = $return_type eq 'void' ? 'G_VOID' : 'G_SCALAR';
	$to_return .= "CV * to_call = GvCV(gv_fetchmethod_autoload(
		self->methods->_class_stash, \"$self->{package}::$entry->{name}\",
		1));
	count = call_sv(to_call, $flags);\n";
	
	# Handle the return value
	if ($return_type ne 'void') {
		$return_type = $return_type->($self) if ref ($return_type);
		# reset the stack pointer
		$to_return .= "SPAGAIN;\n";
		
		# XXX check return count some day?
		
		# Pop the value off the stack and put it onto TO_RETURN
		$to_return .= $return_type->c_blocks_upack_SV('POPs', 'TO_RETURN', 1);
		
		$to_return .= "PUTBACK;\n";
	}
	
	# Close everything out
	$to_return .= "FREETMPS;
	LEAVE;\n";
	
	$to_return .= "return TO_RETURN;\n" if $return_type ne 'void';
	
	return $to_return . "}\n";
}

sub _gen_vtable_def {
	my $self = shift;
	my $to_return = "$self->{C_vtable_layout} $self->{C_vtable_instance} = {\n";
	for my $entry (@{$self->{vtable}}) {
		if ($entry->{isa}) {
			# an attribute, always initialized to zero
			$to_return .= "0";
		}
		else {
			# Add the function pointer cast
			$to_return .= $self->_gen_function_pointer_cast($entry);
			# If this is a Perl method, use the thunk
			if ($entry->{language} eq 'Perl') {
				$to_return .= $entry->{C_to_Perl_thunk};
			}
			# otherwise use the last defined C function
			else {
				$to_return .= $entry->{package} . '::' . $entry->{name};
			}
		}
		$to_return .= ",\n"; # trailing commas ok
	}
	$to_return .= "};\n";
	return $to_return;
}

# produces a C function signature so the programmer doesn't have to
# worry about getting the right arguments and order
sub _signature {
	my ($package, $method_name) = @_;
	my $class = $package->_class;
	croak("Unknown method `$method_name'")
		unless exists $class->{vtable_by_name}{$method_name};
	my $method = $class->{vtable_by_name}{$method_name};
	return $class->_gen_function_signature("$package::$method_name", $method);
}

# Performs any remaining vtable struct initialization, and hooks up the
# appropriate xsubs.
sub _initialize {
	my $package = shift;
	my $class = $package->_class;
	my $to_return = '';
	for my $entry (@{$class->{vtable}}) {
		if ($entry->{C_init}) {
			my $init = $entry->{C_init};
			$init = $init->($class) if ref($init) and ref($init) eq ref(sub{});
			$to_return .= "$class->{C_vtable_instance}.$entry->{name} = $init;\n";
		}
		elsif ($entry->{language} eq 'C') {
			$to_return .= "newXS(\"$class\::$entry->{name}\", $entry->{Perl_to_C_thunk}, __FILE__);\n";
		}
	}
	return $to_return;
}

########################################################################
                  package C::Blocks::SOS::Class;
########################################################################
# Only the most rudimentary of functionality. It doesn't even have a
# member for the vtable
use C::Blocks;
use C::Blocks::PerlAPI;
use C::Blocks::Filter::BlockArrowMethods;
use C::Blocks::Types qw(UV);
BEGIN {
	C::Blocks::SOS->import (sub {
		my $c = shift;
		$c->{C_class_type} = 'C::Blocks::SOS::Class';
		$c->has (_class_stash =>
			isa        => '^HV*',
			accessors  => 0,
			class_attr => 1,
			C_init => sub { 'gv_stashpv("' . (shift->{package}) . '", GV_ADD)' },
		);
		$c->method (_new => 
			returns => sub { shift->{C_class_type} },
			class_method => 1,
			language => 'C-only',
		);
		$c->method (destroy => 
			returns => 'void',
			language => 'C-only',
			C_code => q{ free(self); },
		);
		$c->has (_size =>
			isa => UV,
			accessors => 0,
			class_attr => 1,
			C_init => sub { 'sizeof(' . (shift->{C_obj_layout}) . ')' }
		);
		$c->has (methods =>
			isa => sub { shift->{C_vtable_layout}.'*' },
			accessors => 0,
		);
	})
}

cshare {
	${ C::Blocks::SOS::Class->_declare }
	
	// new //
	${ C::Blocks::SOS::Class->_signature('_new') } {
		C::Blocks::SOS::Class self = calloc(1, class->_size);
		self->methods = class;
		return self;
	}
	#define C::Blocks::SOS::Class::new(package, varname) package varname = (package)C::Blocks::SOS::Class::_new((C::Blocks::SOS::Class::VTABLE_LAYOUT *)&package##::VTABLE_INSTANCE)
}

cblock {
	${ C::Blocks::SOS::Class->_initialize }
}

########################################################################
                  package C::Blocks::SOS::Base;
########################################################################
use C::Blocks;
use C::Blocks::PerlAPI;
use C::Blocks::Filter::BlockArrowMethods;

BEGIN {
	C::Blocks::SOS->import (sub {
		my $c = shift;
		$c->extends('C::Blocks::SOS::Class');
		
		# Core attributes
		$c->has (perl_obj =>
			isa       => '^HV*',
			C_init    => 'NULL',
			accessors => 0, # we'll add get_HV later...
		);
		
		# Don't need to override new; calloc sets perl_obj to zero anyway
		
		#### Methods
		# get_HV produces the cached HV, or creates a new one if there is
		# none yet cached. Attaches "free" magic to the HV.
		$c->method ( get_HV => returns => '^HV*', language => 'C-only');
		
		# refcounting methods
		$c->method ( refcount_inc => returns => 'void', language => 'C-only');
		$c->method ( refcount_dec => returns => 'void', language => 'C-only');
		
		# Produce a blessed SV ref to the object's HV, something which
		# can be returned to Perl land. Could we revise things to allow
		# for pTHX_ ??
		$c->method (attach_SV => returns => 'void', language => 'C-only',
			expects => ['^SV*' => 'to_attach']);
	});
}
cshare {
	${ C::Blocks::SOS::Base->_declare }

	/*******************************************************************
	 * MAGIC stuff needed to invoke object destruction when the HV's
	 * refcount drops to zero.
	 ******************************************************************/
	
	/* MAGIC function to invoke object destruction */
	int C::Blocks::SOS::Magic::free(pTHX_ SV* sv, MAGIC* mg) {
		C::Blocks::SOS::Base obj = (C::Blocks::SOS::Base)(mg->mg_ptr);
		obj=>destroy();
		return 1;
	}
	
	/* magic vtable, copied with only one change from
	 * C::Blocks::Object::Magic */
	STATIC MGVTBL C::Blocks::SOS::Magic::Vtable = {
		NULL, /* get */
		NULL, /* set */
		NULL, /* len */
		NULL, /* clear */
		C::Blocks::SOS::Magic::free, /* free */
	#if MGf_COPY
		NULL, /* copy */
	#endif /* MGf_COPY */
	#if MGf_DUP
		NULL, /* dup */
	#endif /* MGf_DUP */
	#if MGf_LOCAL
		NULL, /* local */
	#endif /* MGf_LOCAL */
	};
	
	/*******************************************************************
	 * Marshalling data between Perl and C.
	 ******************************************************************/
	
	/* Given a ref to the HV-side of the object, obtain the C pointer
	 * from the magic. Cobbled from C::Blocks::Object::Magic */
	void * C::Blocks::SOS::Magic::obj_ptr_from_SV_ref (pTHX_ SV* sv_ref) {
		MAGIC *mg;
		if (!SvROK(sv_ref))
			croak("obj_ptr_from_SV called with non-ref scalar");
		SV * sv = SvRV(sv_ref);

		if (SvTYPE(sv) >= SVt_PVMG) {
			for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic) {
				if ((mg->mg_type == PERL_MAGIC_ext)
					&& (mg->mg_virtual == &C::Blocks::SOS::Magic::Vtable))
				{
					return mg->mg_ptr;
				}
			}
		}

		return NULL;
	}
	
	/* Given the C-pointer-side of the object, get or create the HV-side. */
	${ C::Blocks::SOS::Base->_signature('get_HV') } {
		dTHX;
		/* Create the HV if it does not already exist */
		if (!self->perl_obj) {
			self->perl_obj = newHV();
			/* attach destructor magic */
			sv_magicext((SV*)self->perl_obj, NULL, PERL_MAGIC_ext,
				&C::Blocks::SOS::Magic::Vtable, (char*)self, 0 );
		}
		return self->perl_obj;
	}
	
	/* Sets the given SV to be a reference to our HV, upgrading it to
	 * an RV if necessary. */
	${ C::Blocks::SOS::Base->_signature('attach_SV') } {
		dTHX;
		HV * my_HV = self=>get_HV();
		/* upgrade the SV that we're attaching to a RV */
		SvUPGRADE(to_attach, SVt_RV);
		/* have to_attach point to my_HV */
		SvROK_on(to_attach);
		SvRV_set(to_attach, (SV*)my_HV);
		/* bless */
		sv_bless(to_attach, self->methods->_class_stash);
		/* must increment reference count of my_HV manually */
		SvREFCNT_inc(my_HV);
	}
	SV * C::Blocks::SOS::Base::get_SV(pTHX_ C::Blocks::SOS::Base self) {
		SV * SV_ret = sv_newmortal();
		self=>attach_SV(SV_ret);
		/* fix the refcount */
		self=>refcount_dec();
		return SV_ret;
	}
	
	/*******************************************************************
	 * refcounting and memory cleanup
	 ******************************************************************/
	
	/* refcounting. If there is no affiliated Perl object, then the
	 * refcount is implicitly one. Incrementing means we get the HV,
	 * possibly creating it in the process. Decrementing means we either
	 * destroy the object if there is no affiliated Perl HV, or we
	 * decrement the HV's refcount. The latter may trigger a magic
	 * destruction. */
	${ C::Blocks::SOS::Base->_signature('refcount_inc') } {
		dTHX;
		HV * perl_obj = self=>get_HV();
		SvREFCNT_inc((SV*)perl_obj);
	}
	${ C::Blocks::SOS::Base->_signature('refcount_dec') } {
		dTHX;
		if (self->perl_obj == NULL) self=>destroy();
		else SvREFCNT_dec((SV*)self->perl_obj);
	}
}

cblock {
	${ C::Blocks::SOS::Base->_initialize }
}

sub new {
	my $to_return;
	cblock {
		/* Create and attach the object */
		C::Blocks::SOS::Class::new(C::Blocks::SOS::Base, self);
		self=>attach_SV($to_return);
		/* the constructor double-counts the refcount, so backup by 1 */
		self=>refcount_dec();
	}
	return $to_return;
}

# Some Perl-only methods related to the type system
sub c_blocks_init_cleanup {
	my ($package, $C_name, $sigil_type, $pad_offset) = @_;
	return "$package $C_name = C::Blocks::SOS::Magic::obj_ptr_from_SV_ref(aTHX_ PAD_SV($pad_offset)); "
}

sub c_blocks_pack_SV {
	my ($package, $C_name, $SV_name, $must_declare_SV) = @_;
	my $to_return = '';
	$to_return = "SV * $SV_name = newSV(0)" if $must_declare_SV;
	return "$to_return; $C_name=>attach_SV($SV_name);";
}

sub c_blocks_new_SV {
	my ($package, $C_name) = @_;
	return "C::Blocks::SOS::Base::get_SV(aTHX_ (C::Blocks::SOS::Base)$C_name)";
}

sub c_blocks_unpack_SV {
	my ($package, $SV_name, $C_name, $must_declare_name) = @_;
	my $declaration = '';
	$declaration = $package . ' ' if $must_declare_name;
	return "$declaration$C_name = C::Blocks::SOS::Magic::obj_ptr_from_SV_ref(aTHX_ $SV_name);";
}


1;
