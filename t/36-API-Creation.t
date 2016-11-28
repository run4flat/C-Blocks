use strict;
use warnings;
use Test::More;
use C::Blocks;
use C::Blocks::PerlAPI;

cblock {
	SV * my_sv = newSV(10);
	SvREFCNT_dec(my_sv);
}
BEGIN { pass 'newSV does not cause croak' }

cblock {
	AV * my_av = newAV();
	SvREFCNT_dec(my_av);
}
BEGIN { pass 'newAV does not cause croak' }

cblock {
	HV * my_hv = newHV();
	SvREFCNT_dec(my_hv);
}
BEGIN { pass 'newHV does not cause croak' }

pass 'Script executes without trouble';
done_testing;

