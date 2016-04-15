use strict;
use warnings;

package mgpoint;
{
	use C::Blocks;
	use C::Blocks::PerlAPI;
	use C::Blocks::Object::Magic;
	use Scalar::Util;
	use Carp qw(croak);
	
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
	sub set {
		my ($self, $x, $y) = @_;
		cblock {
			point * data = data_from_SV($self);
			data->x = SvNV($x);
			data->y = SvNV($y);
		}
	}
	
	# Perl-side method for computing the distance.
	sub distance {
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
	sub DESTROY {
		my $self = shift;
		cblock {
			Safefree(data_from_SV($self));
		}
	}
	
	# So this can be used as a cisa type
	our $TYPE = 'point *';
	our $INIT = 'data_from_SV';
	sub check_var_types {
		my $class = shift @_;
		my $message = '';
		while (@_) {
			my ($arg_name, $arg) = splice @_, 0, 2;
			$message .= "$arg_name is not defined\n" and next if not defined $arg;
			$message .= "$arg_name is not a reference\n" and next if not ref($arg);
			$message .= "$arg_name is not blessed\n" and next
				if not Scalar::Util::blessed($arg);
			$message .= "$arg_name is not a mgpoint\n" and next
				unless $arg->isa('mgpoint');
		}
		if ($message eq '') {
			undef $@;
			return 1;
		}
		chomp $message;
		croak($message);
	}
}

1;
