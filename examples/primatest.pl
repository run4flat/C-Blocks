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
}

my ($x, $y) = (1, 0);
my ($N_x, $N_y) = (30, 30);

Prima::MainWindow-> new( text => 'C::Blocks',
#	buffer => 1,
	onPaint => sub {
		my ($self, $canvas) = @_;
		return $self->repaint if $self->get_paint_state != 1;
		$self->clear;
		cblock {
Point points_to_plot[200];
int x_pt, y_pt, C_N_x, C_N_y;
double A_rad, B_rad;
A_rad = SvNV($A);
B_rad = SvNV($B);
x_pt = SvIV($x);
y_pt = SvIV($y);
C_N_x = SvIV($N_x);
C_N_y = SvIV($N_y);

			Handle widget_handle = gimme_the_mate($self);
			/* Draw an ellipse tilted toward the mouse. Thanks to
			 * http://www.uwgb.edu/dutchs/Geometry/HTMLCanvas/ObliqueEllipses5.HTM
			 * for the formula. */
			int i, j, k;
			double theta, theta_inc, theta_0, sin_theta_0, cos_theta_0;
			
			/* set the per-step theta increment */
			theta_inc = M_PI / 100;
			
			/* Iterate through the number of x and y ellipses to draw */
			for (i = 0; i < C_N_x; i++) {
				int x_pos = ...
				for (j = 0; j < C_N_y; j++) {
					theta_0 = SvNV($rotation);
					sin_theta_0 = sin(theta_0);
					cos_theta_0 = cos(theta_0);
					
					/* Build the set of points */
					for (i = 0; i < 200; i++) {
						theta = i*theta_inc;
						points_to_plot[i].x = 250 + A_rad * cos(theta)*cos_theta_0
							- B_rad * sin(theta)*sin_theta_0;
						points_to_plot[i].y = 250 + A_rad * cos(theta)*sin_theta_0 /* === syntax hilite :-( */
							+ B_rad * sin(theta)*cos_theta_0;
					}
					apc_gp_fill_poly (widget_handle, C_N_points, points_to_plot);
				}
			}
		}
	},
	onMouseMove => sub {
		(my $self, undef, $x, $y) = @_;
		$self->notify('Paint');
	},
);

my @points;
my $pi = 2*atan2(1, 0);

Prima::MainWindow-> new( text => 'Pure Perl',
	onPaint => sub {
		my ($self, $canvas) = @_;
		return $self->repaint if $self->get_paint_state != 1;
		$self->clear;
		
		# Some pre-calculations
		my $rotation = atan2($y - 250, $x - 250);
		my $sin_theta_0 = sin($rotation);
		my $cos_theta_0 = cos($rotation);
		my $theta_inc = $pi / $N_points * 2;
		
		for my $i (0 .. $N_points - 1) {
			my $theta = $i * $theta_inc;
			$points[2*$i] = 250 + $A * cos($theta)*$cos_theta_0
				- $B * sin($theta)*$sin_theta_0;
			$points[2*$i+1] = 250 + $A * cos($theta)*$sin_theta_0
				+ $B * sin($theta)*$cos_theta_0;
				
		}
		
		$self->fillpoly(\@points);
	},
	onMouseMove => sub {
		(my $self, undef, $x, $y) = @_;
		$self->notify('Paint');
	},
);

Prima->run;
