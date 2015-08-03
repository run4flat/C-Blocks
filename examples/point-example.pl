use strict;
use warnings;
use C::Blocks;
use C::Blocks::PerlAPI;

 clex {
     typedef struct _point_t {
         double x;
         double y;
     } point;
     
     double point_distance_from_origin (point * loc) {
		printf("x is %f, y is %f\n", loc->x, loc->y);
         return sqrt(loc->x * loc->x + loc->y * loc->y);
     }
     
     /* Assume they have an SV packed with a point struct */
     point * _point_from_SV(pTHX_ SV * point_SV) {
         return (point*)SvPV_nolen(point_SV);
     }
	 #define point_from_SV(point_sv) _point_from_SV(aTHX_ point_sv)
 }

 # Generate some synthetic data;
 my @pairs = map { rand() } 1 .. 10;
 print "Pars are @pairs\n";

 # Assume pairs is ($x1, $y1, $x2, $y2, $x3, $y3, ...)
 # Create a C array of doubles, which is equivalent to an
 # array of points with half as many array elements
 my $points = pack 'd*', @pairs;
 my $N_points = @pairs / 2;
 
 # Calculate the average distance to the origin:
 my $avg_distance;
 cblock {
     point * points_data = point_from_SV($points);
     int n_points = SvIV($N_points);
     int i;
     double length_sum = 0;
     for (i = 0; i < n_points; i++) {
         length_sum += point_distance_from_origin(points + i);
     }
     sv_setnv($avg_distance, length_sum / n_points);
 }
 
 print "Average distance to origin is $avg_distance\n";
