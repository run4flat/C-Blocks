use strict;
use warnings;
use PDL;
#use Inline 'Pdlpp';

die "You must give at least one input file\n" unless @ARGV;
my $filename = shift;

# Open the file
use PDL::IO::FlexRaw;
my $N_entries = (-s $filename) / length(pack('d', 0));
my ($data_pdl) = mapflex($filename, [{
	Type => 'double', NDims => 1, Dims => [ $N_entries ],
}]);

my $dt = 0.1;

# Construct the frequencies to query
my $N_frequencies = 1000;
my $power = zeros($N_frequencies);
my $frequencies = $power->xlogvals(1e-3, 100);

$data->periodogram($data->sequence * $dt, $frequencies, $power);

use PDL::Graphics::Prima::Simple;
line_plot($frequencies, $power);

__DATA__

__Pdlpp__

pp_def('periodogram',
	Pars => 'data(i); t(i); frequencies(j); [o] power(j)',
	Code => q{
		
		threadloop %{
			loop(j) %{ /* loop over frequencies */
				/* Compute tau for this frequency */
				double om = $frequencies();
				
				/* compute tau */
				double sin_sum = double cos_sum = 0;
				loop(i) %{
					sin_sum += sin(2 * om * $t());
					cos_sum += cos(2 * om * $t());
				%}
				double tau = atan(sin_sum / cos_sum) / 2 / om;
				
				/* compute the power at this frequency */
				sin_sum = cos_sum = 0;
				double cos_sq_sum = double sin_sq_sum = 0;
				double rel_t, sin_t, cos_t;
				loop(i) %{
					rel_t = $t() - tau;
					sin_t = sin(om * rel_t);
					cos_t = cos(om * rel_t);
					sin_sum += $data() * sin_t;
					cos_sum += $data() * cos_t;
					sin_sq_sum += sin_t*sin_t;
					cos_sq_sum += cos_t*cos_t;
				%}
				$power() = (sin_sum*sin_sum / sin_sq_sum + cos_sum*cos_sum / cos_sq_sum) / 2;
				
			%}
		%}
	},
);
