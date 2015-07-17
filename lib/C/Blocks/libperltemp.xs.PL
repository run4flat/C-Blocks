use strict;
use warnings;
use ExtUtils::Embed;
use inc::Alien::TinyCC;
use Devel::CheckLib;
use Config;
use File::Temp ();
use File::Spec;

##########################################
# Serialize the simple perltemp.h header #
##########################################

sub serialize_perltemp_h {
	# Put the cache file in the sharedir
	my $share_file_location = File::Spec->catfile('share', 'perltemp.h.cache');
	return if -f $share_file_location;

	my($perltemp_h_fh, $perltemp_h_file) = File::Temp::tempfile(
		'perltemp_h_XXXXXXXX', SUFFIX => '.c'
	);

	my $header_contents = <<HEADER_CONTENTS;
#include <stddef.h>

/*** memory management ***/
#define Newx(ptr, N_items, type) ptr = perltemp_Newx(N_items * sizeof(type))
#define Newxc(ptr, N_items, type, cast) ptr = (cast)perltemp_Newx(N_items * sizeof(type))
#define Newxz(ptr, N_items, type) ptr = perltemp_Newxz(N_items * sizeof(type))
#define Renew(ptr, N_items, type) ptr = perltemp_Renew(N_items * sizeof(type))
#define Renewc(ptr, N_items, type, cast) ptr = (cast)perltemp_Renew(N_items * sizeof(type))
void * perltemp_Newx(size_t bytes);
void * perltemp_Newxz(size_t bytes);
void * perltemp_Renew(size_t bytes);
void Safefree(void* ptr);

/*** exception handling ***/
void croak(char * message);

HEADER_CONTENTS

	print $perltemp_h_fh $header_contents;
	close $perltemp_h_fh;

	# Build the serialization for this header file
	mkdir 'share';
	system("tcc", '-serialize-symtab='.$share_file_location,
		$perltemp_h_file) == 0
		or die "Unable to serialize the header file\n";
	unlink $perltemp_h_file;
}

########################
# Generate the XS file #
#########################

serialize_perltemp_h;
my $out_filename = $ARGV[0];
open my $out_fh, '>', $out_filename or die "Unable to open $out_filename\n";

print $out_fh <<'XS_FILE';
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include "libtcc.h"

/* Copied directly from C::Blocks.xs */
typedef struct _available_extended_symtab {
	extended_symtab_p exsymtab;
	void * dll;
} available_extended_symtab;

/* The actual function definitions */
void * perltemp_Newx(size_t bytes) {
	void * to_return;
	Newx(to_return, bytes, char);
	return to_return;
}
void * perltemp_Newxz(size_t bytes) {
	void * to_return;
	Newxz(to_return, bytes, char);
	return to_return;
}
void * perltemp_Renew(size_t bytes) {
	void * to_return;
	Renew(to_return, bytes, char);
	return to_return;
}
void perltemp_Safefree(void* ptr) {
	safefree(ptr);
}
void perltemp_croak(char * message) {
	Perl_croak_nocontext("%s", message);
}


MODULE = C::Blocks::libperltemp       PACKAGE = C::Blocks::libperltemp

BOOT:
	/* Get the symtab file location */
	SV * file_location = get_sv("C::Blocks::libperltemp::symtab_file_location", 0);
	if (file_location == NULL) {
		croak("Internal error: could not find $C::Blocks::libperltemp::symtab_file_location");
	}
	
	/* Deserialize the extended symbol table. */
	extended_symtab_p symtab = tcc_deserialize_extended_symtab(SvPVbyte_nolen(file_location));
	
	/*** Borrowed, with slight modification, from Blocks.xs's serialize_symbol_table ***/
	{
		/* Add to my package's cshare space. This code is borrowed from
		 * Blocks.xs's serialize_symbol_table */
		SV * package_lists = get_sv("C::Blocks::libperltemp::__cblocks_extended_symtab_list",
			GV_ADDMULTI | GV_ADD);
		available_extended_symtab new_table;
		new_table.dll = NULL;
		new_table.exsymtab = symtab;
		sv_setpvn_mg(package_lists, (char*)&new_table, sizeof(available_extended_symtab));
		
		/* Store the pointers to the extended symtabs so that it gets cleaned up
		 * when everything is over. */
		AV * extended_symtab_cache = get_av("C::Blocks::__symtab_cache_array", GV_ADDMULTI | GV_ADD);
		av_push(extended_symtab_cache, newSViv(PTR2IV(new_table.exsymtab)));
	}
	
	/* Add all symbols to the exsymtab */
	tcc_set_extended_symbol(symtab, "perltemp_Newx", perltemp_Newx);
	tcc_set_extended_symbol(symtab, "perltemp_Newxz", perltemp_Newxz);
	tcc_set_extended_symbol(symtab, "perltemp_Renew", perltemp_Renew);
	tcc_set_extended_symbol(symtab, "Safefree", perltemp_Safefree);
	tcc_set_extended_symbol(symtab, "croak", perltemp_croak);
	
XS_FILE

close $out_fh;
