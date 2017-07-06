use strict;
use warnings;

########################################################################
package mgpoint;
########################################################################
# The package using Object::Magic, which we will exercise shortly
use C::Blocks;
use C::Blocks::Object::Magic;
use C::Blocks::Types qw(double);

sub c_blocks_init_cleanup {
	my ($package, $C_name, $sigil_type, $pad_offset) = @_;
	
	my $init_code = "$sigil_type * _hidden_$C_name = ($sigil_type*)PAD_SV($pad_offset); "
		. "point * $C_name = data_from_SV(_hidden_$C_name); ";
	
	return $init_code;
}

cshare {
	/* Define a simple x/y data pint using a struct */
	typedef struct point {
		double x;
		double y; /* ;;; syntax hilite :-( */
	} point;
	
	/* C-side constructor allocates memory and initializes
	 * the data to point to the origin. Note the macro
	 * wrapper, which makes working with threaded perls a
	 * little bit cleaner. */
	point * new_point(pTHX) {
		#define new_point() new_point(aTHX)
		point * to_return;
		Newx(to_return, 1, point);
		to_return->x = 0;
		to_return->y = 0;
		return to_return;
	}
	
	/* C-side function that retrieves and properly casts
	 * the struct from the Perl-side SV. */
	point * data_from_SV(pTHX_ SV * perl_side) {
		#define data_from_SV(perl_side) data_from_SV(aTHX_ perl_side)
		return xs_object_magic_get_struct_rv(aTHX_ perl_side);
	}
}

# Perl-side constructor. Build an empty hash and attach the
# point struct to it.
sub new {
	my $class = shift;
	my $self = bless {}, $class;
	
	cblock {
		point * to_attach = new_point();
		xs_object_magic_attach_struct(aTHX_ SvRV($self), to_attach);
	}
	
	return $self;
}

# Perl-side accessor for setting the point's coordinate.
csub set {
	dXSARGS;
	if (items != 3) croak("set method expects both x and y values");
	point * data = data_from_SV(ST(0));
	data->x = SvNV(ST(1));
	data->y = SvNV(ST(2));
}

# Different versions of Perl-side methods for computing the distance.

# csub, i.e. pure C
csub distance_1 {
	dXSARGS;
	if (items != 1) croak("distance method does not take any arguments");
	point * data = data_from_SV(ST(0));
	XSprePUSH;
	mXPUSHn(sqrt(data->x*data->x + data->y*data->y));
	XSRETURN(1);
}
# Perl-side with type
sub distance_2 {
	my mgpoint $self = shift;
	my double $to_return = 0;
	cblock {
		$to_return = sqrt($self->x*$self->x + $self->y*$self->y);
	}
	return $to_return;
}
# Perl-side without type
sub distance_3 {
	my $self = shift;
	my $to_return;
	cblock {
		point * data = data_from_SV($self);
		sv_setnv($to_return, sqrt(data->x*data->x + data->y*data->y));
	}
	return $to_return;
}

# Perl-side accessor/method with no counterpart in C
# (illustrating that this really is a hashref-backed object).
sub name {
	my $self = shift;
	return $self->{name} || 'no-name' if @_ == 0;
	$self->{name} = $_[0];
}

# Destructor should clean up the allocated struct memory.
csub DESTROY {
	dXSARGS;
	Safefree(data_from_SV(ST(0)));
}

########################################################################
package main;
########################################################################
# Test code

use Test::More;

# Perl-side constructor and methods
my $thing = mgpoint->new;
$thing->set(3, 4);
is($thing->distance_1, 5, 'First distance method returns correct distance');
is($thing->name, 'no-name', 'Default (Perl-side) name works');

$thing->name('Random Point');
is($thing->name, 'Random Point', 'Changing name works');

# Access data from C-side...
cblock {
	point * thing = data_from_SV($thing);
	thing->x = 6;
	thing->y = 8;
}
is($thing->distance_2, 10, 'C-side set works; second distance method returns correct distance');

# Use cisa to make data manipulation code even cleaner
{
	# A typed alias
	my mgpoint $thing2 = $thing;
	cblock {
		$thing2->x = 5;
		$thing2->y = 12;
	}
}
is($thing->distance_3, 13, 'C-side access via typing works; third distance method returns correct distance');

done_testing;
