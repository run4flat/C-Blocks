use strict;
use warnings;

my %to_plot;
while (<>) {
	if (/N = (\d+)/) {
		$to_plot{N} ||= [];
		push @{$to_plot{N}}, $1;
	}
	elsif (/^\s*(\w+): (\d+\.\d+(e-\d+)?)/) {
		$to_plot{$1} ||= [];
		push @{$to_plot{$1}}, $2;
	}
}

use PDL;
use PDL::Graphics::Prima::Simple;
my $xs = pdl($to_plot{N});
my %plot_args;
for my $column (keys %to_plot) {
	next if $column eq 'N';
	$plot_args{-$column} = ds::Pair($xs, pdl($to_plot{$column}),
		plotType => ppair::Lines);
}
plot(%plot_args,
	x => {
		label => '$N_{rand}$',
		scaling => sc::Log,
	},
	y => {
		label => 'Time (s)',
		scaling => sc::Log
	}
);
