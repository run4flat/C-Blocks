use strict;
use warnings;
use C::Blocks;
use C::Blocks::PerlAPI;

sub load_data {
	my ($filename, $data_ref) = @_;
	open my $in_fh, '<', $filename or die "Unable to open $filename\n";
	local $/;
	$$data_ref = <$in_fh>;
}

# Load A and B
my ($A, $B);
load_data('A.bin', \$A);
load_data('B.bin', \$B);

# Check dimensions
length($A) == length($B) or die "Sizes for A and B differ\n";
my $dim_size = sqrt(length($A) / 8);
$dim_size = int($dim_size) or die "A is not a square matrix\n";

# Allocate room for the result
vec (my $C, length($B) - 1, 8) = 0;

# Use a very simple implementation
cisa C::Blocks::Type::int $m;
cisa C::Blocks::Type::Buffer::double $A, $B, $C;

cblock {
	double * A = (double*)SvPVbyte_nolen($A);
	double * B = (double*)SvPVbyte_nolen($B);
	double * C = (double*)SvPVbyte_nolen($C);
	double * curr;
	int i, j, k;
	for (i = 0; i < $dim_size; i++) {
		for (j = 0; j < $dim_size; j++) {
			curr = C + i + j * $dim_size;
			*curr = 0;
			for (k = 0; k < $dim_size; k++) {
				*curr += A[k + j * $dim_size] * B[i + k * $dim_size];
			}
		}
	}
}
print $C;
