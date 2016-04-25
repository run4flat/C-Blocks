# Generates the test matrices for the benchmark

use strict;
use warnings;
use PDL;
use PDL::IO::FastRaw;

my $size = shift || 200;

my $template = zeros($size, $size);
($template->grandom * 20)->short->double->writefraw('A.bin');
($template->grandom * 20)->short->double->writefraw('B.bin');

