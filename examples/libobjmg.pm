use strict;
use warnings;
package libobjmg;
{
	use C::Blocks;
	use C::Blocks::PerlAPI;

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

1;
