use strict;
use warnings;
 use C::Blocks;
 use C::Blocks::Types qw(double double_array Int);
 
 # Generate some synthetic data;
 my @data = map { rand() } 1 .. 10;
 print "data are @data\n";

 # Pack this data into a C array
 my double_array $points = pack 'd*', @data;
 
 # Calculate the rms (root mean square)
 my double $rms = 0;
 cblock {
     for (int i = 0; i < length_$points; i++) {
         $rms += $points[i]*$points[i];
     }
     $rms = sqrt($rms / length_$points);
 }
 
 print "data rms is $rms\n";
 
 # Note that Int is capitalized, unlike the other type names
 my Int $foo = 4;
 cblock {
     printf("$foo is %d\n", $foo);
 }
