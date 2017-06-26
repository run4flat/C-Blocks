use strict;
use warnings;

=head1 NAME

SOS05.pm - testing the REAL SOS.pm

=head1 QUESTION

My work from SOS01 to SOS04 informed my creation of C::Blocks::SOS.
This is my first test of that module. This module creates a point class
and implements a few basic functions: vector addition and subtraction,
and magnitude and direction (angle).

=cut

package SOS05;
use C::Blocks;
use C::Blocks::Types qw<float>;
use C::Blocks::PerlAPI;
use C::Blocks::Filter::BlockArrowMethods;
#use C::Blocks::Filter;
use C::Blocks::SOS sub {
	has (x => isa => float);
	has (y => isa => float);
	method (add =>
		returns => 'SOS05',
		expects => ['SOS05' => 'other_point'],
		language => 'C',
	);
	method (subtract =>
		returns => 'SOS05',
		expects => ['SOS05' => 'other_point'],
		language => 'C',
	);
	method (magnitude =>
		returns => float,
		language => 'C',
	);
	method (direction =>
		returns => float,
		language => 'C',
	);
};

cshare {
     ${ SOS05->_declare }
     
     ${ SOS05->_signature('add') } {
		C::Blocks::SOS::Class::new(SOS05, to_return);
		to_return=>set_x(self=>get_x() + other_point=>get_x());
		to_return=>set_y(self=>get_y() + other_point=>get_y());
		return to_return;
	}
	
	${ SOS05->_signature('subtract') } {
		C::Blocks::SOS::Class::new(SOS05, to_return);
		to_return=>set_x(self=>get_x() - other_point=>get_x());
		to_return=>set_y(self=>get_y() - other_point=>get_y());
		return to_return;
	}
	
	${ SOS05->_signature('magnitude') } {
		float x = self=>get_x();
		float y = self=>get_y();
		return sqrt(x*x + y*y); //**
	}
	
	${ SOS05->_signature('direction') } {
		return atan2f(self=>get_y(), self=>get_x());
	}
}

cblock {
     ${ SOS05->_initialize }
}

sub new {
	my $to_return;
	cblock {
		/* Create and attach the object */
		C::Blocks::SOS::Class::new(SOS05, self);
		self=>attach_SV($to_return);
		/* the constructor double-counts the refcount, so backup by 1 */
		self=>refcount_dec();
	}
	return $to_return;
}
1;

=head1 RESULTS

F<sos-05-SOS.pl> verifies that this works. This module uncovered a
couple of bugs in the low-level C::Blocks interpolation block code, as
well as a couple of bugs in SOS. Having resolved them, the code seems
to function!

=cut
