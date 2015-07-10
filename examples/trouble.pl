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
	double points_to_plot[1000];
	double A, B;
}

# Initialize the constants
cblock {
	A = 20;
	B = 40;
}

my ($x, $y) = (1, 0);

my $main = Prima::MainWindow-> new( text => 'Hello world',
	onPaint => sub {
		my ($self, $canvas) = @_;
		$self->clear;
		my $rotation = atan2($y, $x);
		cblock {
			Handle widget_handle = gimme_the_mate($self);
			/* Draw an ellipse tilted toward the mouse. Thanks to
			 * http://www.uwgb.edu/dutchs/Geometry/HTMLCanvas/ObliqueEllipses5.HTM
			 * for the formula. */
			int i;
			double theta, theta_inc, theta_0, sin_theta_0, cos_theta_0;
			
			/* get the rotation, set the per-step theta increment */
			theta_0 = SvNV($rotation);
			theta_inc = M_PI / 250.0;
			sin_theta_0 = sin(theta_0);
			cos_theta_0 = cos(theta_0);
			
			/* Build the set of points */
			for (i = 0; i < 500; i++) {
				theta = i*theta_inc;
				points_to_plot[2*i] = A * cos(theta)*cos_theta_0
					- B * sin(theta)*sin_theta_0;
				points_to_plot[2*i + 1] = A * cos(theta)*sin_theta_0
					+ B * sin(theta)*cos_theta_0;
			}
			apc_gp_fill_poly (widget_handle, 500, points_to_plot);
		}
	},
	onMouseMove => sub {
		($self, undef, $x, $y) = @_;
		$self->notify('Paint');
	},
);

Prima->run;
