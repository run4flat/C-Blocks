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
 print "Pairs are @pairs\n";

 # Assume pairs is ($x1, $y1, $x2, $y2, $x3, $y3, ...)
 # Create a C array of doubles, which is equivalent to an
 # array of points with half as many array elements
 my $points = pack 'd*', @pairs;
 
 # Calculate the average distance to the origin:
 my C::double_t $avg_distance = 0;
 cblock {
     point * points = point_from_SV($points);
     int N_points = av_len(@pairs) / 2 + 0.5;
     int i;
     for (i = 0; i < N_points; i++) {
         $avg_distance += point_distance_from_origin(points + i);
     }
     $avg_distance /= N_points;
 }
 
 print "Average distance to origin is $avg_distance\n";
