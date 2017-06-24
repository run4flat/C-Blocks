use strict;
use warnings;
use C::Blocks;

sub get_mem_usage {
	my $info = `ps -q $$ aux`;
	$info =~ /\n\S+\s+\S+\s+\S+\s+\S+\s+(\d+)/
		or die "Unable to get memory!\n";
	return $1;
}
my $mem = get_mem_usage;
print "Initial memory consumption: $mem\n";

my $limit = shift (@ARGV) || 100;
for my $iterations (1 .. $limit) {
	eval q{
		cblock {
			int i = 0;
			i++;
		}
	};
	if ($iterations % 100 == 0) {
		$mem = get_mem_usage;
		print "Memory consumption: $mem\n";
	}
}
