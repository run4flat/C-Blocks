use strict;
use warnings;
use C::Blocks;
use C::Blocks::Types qw(double double_array Int);

 # Generate some synthetic data;
 my @data = map { rand() } 1 .. 10;
 print "data are @data\n";

 # Assume pairs is ($x1, $y1, $x2, $y2, $x3, $y3, ...)
 # Create a C array of doubles, which is equivalent to an
 # array of points with half as many array elements
 my double_array $points = pack 'd*', @data;
 
 # Calculate the average distance to the origin:
 my double $rms = 0;
 cblock {
     int i;
     for (i = 0; i < array_length($points); i++) {
         $rms += $points[i]*$points[i];
     }
     $rms = sqrt($rms / array_length($points));
 }
 
 print "data rms is $rms\n";
 
 my Int $foo = 4;
 cblock {
     printf("$foo is %d\n", $foo);
 }
 
 print "int(5.4) is ", int(5.4), "\n";
