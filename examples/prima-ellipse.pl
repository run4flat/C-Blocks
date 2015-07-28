=head1 NAME

primatest.pl - testing how C::Blocks handles the C interface to the Prima GUI toolkit

=cut

use strict;
use warnings;
use blib;
use Prima qw(Application);
use Prima::Config;
use ExtUtils::Embed;

use C::Blocks;

# Link to the Prima library:
BEGIN {
	# Utilize ExtUtils::Embed to get some build info
	$C::Blocks::compiler_options = join(' ', $Prima::Config::Config{inc}, ccopts);
	
	# tcc doesn't know how to use quotes in -I paths; remove them if found.
	$C::Blocks::compiler_options =~ s/-I"([^"]*)"/-I$1/g if $^O =~ /MSWin/;
	
	# Set the Prima library
	$C::Blocks::library_to_link = $Prima::Config::Config{dlname};
}
clex {
	#include <apricot.h>
	#include <generic/Drawable.h>
}

# Create the globals. These must be declared in a separate block because
# the previous block is linked to a library, which will be checked for
# symbols instead of the compiler context. So, create a new context:
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
