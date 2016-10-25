use strict;
use warnings;
use C::Blocks;
use C::Blocks::PerlAPI;

 # Generate some synthetic data;
 my @data = map { rand() } 1 .. 10;
 print "data are @data\n";

 # Assume pairs is ($x1, $y1, $x2, $y2, $x3, $y3, ...)
 # Create a C array of doubles, which is equivalent to an
 # array of points with half as many array elements
 my C::pdouble_t $points = pack 'd*', @data;
 
 # Calculate the average distance to the origin:
 my C::double_t $rms = 0;
 cblock {
     int i;
     for (i = 0; i < SvBUFFER_LENGTH($points); i++) {
         $rms += $points[i]*$points[i];
     }
     $rms = sqrt($rms / SvBUFFER_LENGTH($points));
 }
 
 print "data rms is $rms\n";
