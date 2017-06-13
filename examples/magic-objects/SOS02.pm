use strict;
use warnings;

=head1 NAME

SOS02.pm - adding Perl -> C

=head1 QUESTION

The functionality and reference counting is present for me to make a
C copy of a SOS01 object, but I can't get the C-representation in a
C<cblock> to perform that action! I need to add the ability to retrieve
the C pointer given the C<SV*>. How do I do that?

My solution is to cobble some pieces from XS::Object::Magic (via 
C::Blocks::Object::Magic) to retrieve the data pointer from the
underlying magic hash.

=cut

package SOS02;
use C::Blocks;
use SOS01;
use C::Blocks::PerlAPI;
use C::Blocks::Filter::BlockArrowMethods;

cshare {
	void * SOS01::Magic::obj_ptr_from_SV_ref (pTHX_ SV* sv_ref) {
		entering;
		MAGIC *mg;
		if (!SvROK(sv_ref))
			croak("obj_ptr_from_SV called with non-ref scalar");
		SV * sv = SvRV(sv_ref);

		if (SvTYPE(sv) >= SVt_PVMG) {
			for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic) {
				if ((mg->mg_type == PERL_MAGIC_ext)
					&& (mg->mg_virtual == &SOS01::Magic::Vtable))
				{
					_leaving("SOS02::Magic::obj_ptr_from_HV, returning non-null");
					return mg->mg_ptr;
				}
			}
		}
		_leaving("SOS02::Magic::obj_ptr_from_HV, returning null");
		return NULL;
	}
}

1;

=head1 RESULTS

After learning about the pitfalls of using static global variables, I 
have finally got this thing working.

See F<sos-02-refcount-inc.pl> for specific tests and analysis.

=cut
