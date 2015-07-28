=head1 NAME

prima-lib-ellipse.pl - testing how C::Blocks handles the C interface to the Prima GUI toolkit

=head1 TO RUN

In order to get the proper paths for C<use>ing libprima, be sure to invoke
this script from the distribution's root directory. It should look
something like this:

 perl -Mblib examples/prima-lib-ellispe.pl

=cut

use strict;
use warnings;
use Prima qw(Application);
use C::Blocks;

# Declared elsewhere in the current folder
use examples::libprima;

# Create the globals.
clex {
	#define N_POINTS 500
	Point points_to_plot[N_POINTS];
	double A, B;
}

# Initialize the constants
cblock {
	A = 40;
	B = 20;
}

my ($x, $y) = (1, 0);

my $main = Prima::MainWindow-> new( text => 'Ellipse Animation',
	buffered => 1,
	onPaint => sub {
		my ($self, $canvas) = @_;
		return $self->repaint if $self->get_paint_state != 1;
		$self->clear;
		my $rotation = atan2($y - 250, $x - 250);
		cblock {
			Handle widget_handle = gimme_the_mate($self);
			/* Draw an ellipse tilted toward the mouse. Thanks to
			 * http://www.uwgb.edu/dutchs/Geometry/HTMLCanvas/ObliqueEllipses5.HTM
			 * for the formula. */
			int i;
			double theta, theta_inc, theta_0, sin_theta_0, cos_theta_0;
			
			/* get the rotation, set the per-step theta increment */
			theta_0 = SvNV($rotation);
			theta_inc = 2 * M_PI / N_POINTS;
			sin_theta_0 = sin(theta_0);
			cos_theta_0 = cos(theta_0);
			
			/* Build the set of points */
			for (i = 0; i < N_POINTS; i++) {
				theta = i*theta_inc;
				points_to_plot[i].x = 250 + A * cos(theta)*cos_theta_0
					- B * sin(theta)*sin_theta_0;
				points_to_plot[i].y = 250 + A * cos(theta)*sin_theta_0  /* === */
					+ B * sin(theta)*cos_theta_0;
			}
			apc_gp_fill_poly (widget_handle, N_POINTS, points_to_plot);
		}
	},
	onMouseMove => sub {
		(my $self, undef, $x, $y) = @_;
		$self->notify('Paint');
	},
);

Prima->run;
