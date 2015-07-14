use strict;
use warnings;
package C::Blocks::libobjmg;
{
	use C::Blocks;
	use C::Blocks::libperl;  # for croak and memory stuff

	cshare {
		STATIC MGVTBL null_mg_vtbl = {
			NULL, /* get */
			NULL, /* set */
			NULL, /* len */
			NULL, /* clear */
			NULL, /* free */
		#if MGf_COPY
			NULL, /* copy */
		#endif /* MGf_COPY */
		#if MGf_DUP
			NULL, /* dup */
		#endif /* MGf_DUP */
		#if MGf_LOCAL
			NULL, /* local */
		#endif /* MGf_LOCAL */
		};

		void xs_object_magic_attach_struct (pTHX_ SV *sv, void *ptr) {
			sv_magicext(sv, NULL, PERL_MAGIC_ext, &null_mg_vtbl, ptr, 0 );
		}

		SV *xs_object_magic_create (pTHX_ void *ptr, HV *stash) {
			HV *hv = newHV();
			SV *obj = newRV_noinc((SV *)hv);

			sv_bless(obj, stash);

			xs_object_magic_attach_struct(aTHX_ (SV *)hv, ptr);

			return obj;
		}

		STATIC MAGIC *xs_object_magic_get_mg (pTHX_ SV *sv) {
			MAGIC *mg;

			if (SvTYPE(sv) >= SVt_PVMG) {
				for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic) {
					if (
						(mg->mg_type == PERL_MAGIC_ext)
							&&
						(mg->mg_virtual == &null_mg_vtbl)
					) {
						return mg;
					}
				}
			}

			return NULL;
		}

		void *xs_object_magic_get_struct (pTHX_ SV *sv) {
			MAGIC *mg = xs_object_magic_get_mg(aTHX_ sv);

			if ( mg )
				return mg->mg_ptr;
			else
				return NULL;
		}

		void *xs_object_magic_get_struct_rv_pretty (pTHX_ SV *sv, const char *name) {
			if ( sv && SvROK(sv) ) {
				MAGIC *mg = xs_object_magic_get_mg(aTHX_ SvRV(sv));

				if ( mg )
					return mg->mg_ptr;
				else
					croak("%s does not have a struct associated with it", name);
			} else {
				croak("%s is not a reference", name);
			}
		}

		void *xs_object_magic_get_struct_rv (pTHX_ SV *sv) {
			return xs_object_magic_get_struct_rv_pretty(aTHX_ sv, "argument");
		}
	}
}

package My::Point;
{
	use C::Blocks;
	use C::Blocks::libperl;
	BEGIN { C::Blocks::libobjmg->import }

	cshare {
		typedef struct {
			double x;
			double y; /* ;;; */
		} point;
		
		point * new_point(pTHX) {
			#define new_point() new_point(aTHX)
			point * to_return;
			Newx(to_return, 1, point);
			to_return->x = 0;
			to_return->y = 0;
			return to_return;
		}
		
		point * data_from_SV(pTHX_ SV * perl_side) {
			#define data_from_SV(perl_side) data_from_SV(aTHX_ perl_side)
			return xs_object_magic_get_struct_rv(aTHX_ perl_side);
		}
	}

	sub new {
		my $class = shift;
		my $self = bless {}, $class;
		
		cblock {
			point * to_attach = new_point();
			xs_object_magic_attach_struct(aTHX_ SvRV($self), to_attach);
		}
		
		return $self;
	}
	
	sub set {
		my ($self, $x, $y) = @_;
		cblock {
			point * data = data_from_SV($self);
			data->x = SvNV($x);
			data->y = SvNV($y);
		}
	}
	
	sub distance {
		my $self = shift;
		my $to_return;
		cblock {
			point * data = data_from_SV($self);
			sv_setnv($to_return, sqrt(data->x*data->x + data->y*data->y));
		}
		return $to_return;
	}
	
	sub DESTROY {
		my $self = shift;
		cblock {
			Safefree(data_from_SV($self));
		}
	}
}

package main;
my $thing = My::Point->new;
$thing->set(3, 4);
print "Distance is ", $thing->distance, "\n";
