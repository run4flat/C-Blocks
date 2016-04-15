use strict;
use warnings;

package mgpoint;
{
	use C::Blocks;
	use C::Blocks::PerlAPI;
	use libobjmg;
	use Scalar::Util;
	
	cshare {
		typedef struct point {
			double x;
			double y; /* ;;; */
		} point;
		
		point * new_point(pTHX) {
			#define new_point() new_point(aTHX)
			point * to_return;
			Newx(to_return, 1, point);
			to_return->x = 0;
			to_return->y = 0;
			return to_return;
		}
		
		point * data_from_SV(pTHX_ SV * perl_side) {
			#define data_from_SV(perl_side) data_from_SV(aTHX_ perl_side)
			return xs_object_magic_get_struct_rv(aTHX_ perl_side);
		}
	}

	sub new {
		my $class = shift;
		my $self = bless {}, $class;
		
		cblock {
			point * to_attach = new_point();
			xs_object_magic_attach_struct(aTHX_ SvRV($self), to_attach);
		}
		
		return $self;
	}
	
	sub set {
		my ($self, $x, $y) = @_;
		cblock {
			point * data = data_from_SV($self);
			data->x = SvNV($x);
			data->y = SvNV($y);
		}
	}
	
	sub distance {
		my $self = shift;
		my $to_return;
		cblock {
			point * data = data_from_SV($self);
			sv_setnv($to_return, sqrt(data->x*data->x + data->y*data->y));
		}
		return $to_return;
	}
	
	sub DESTROY {
		my $self = shift;
		cblock {
			Safefree(data_from_SV($self));
		}
	}
	
	# So this can be used as a type
	our $TYPE = 'point *';
	our $INIT = 'data_from_SV';
	sub check_var_types {
		my $class = shift @_;
		$@ = '';
		while (@_) {
			my ($arg_name, $arg) = splice @_, 0, 2;
			$@ .= "$arg_name is not defined\n" and next if not defined $arg;
			$@ .= "$arg_name is not a reference\n" and next if not ref($arg);
			$@ .= "$arg_name is not blessed\n" and next
				if not Scalar::Util::blessed($arg);
			$@ .= "$arg_name is not a mgpoint\n" and next
				unless $arg->isa('mgpoint');
		}
		if ($@ eq '') {
			undef $@;
			return 1;
		}
		return 0;
	}
}

1;
