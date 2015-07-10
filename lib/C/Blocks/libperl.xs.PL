# Here's what needs to happen:
# 1) Add a compiler switch to tcc that lets me specify the output filename for
#    serialized extended symbol tables. DONE
# 2) Add a compiler switch to tcc that lets me specify the output filename for
#    a list of global identifier names. DONE
# 3) Compile a text file with the headers below, saving the serialized extended
#    symbol table and the list of global identifiers
# 4) Create an XS file with a BOOT section that loads the serialized table,
#    adds the global identifiers, and pushes the extended symbol table onto the
#    Perl exsymtab collection.

use strict;
use warnings;
use ExtUtils::Embed;
use inc::Alien::TinyCC;

##################################################
# Serialize perl.h and get a list of identifiers #
##################################################

open my $out_fh, '>', 'temp.c' or die "Unable to open temp.c\n";
print $out_fh <<HEADER_CONTENTS;

#ifdef PERL_DARWIN
	typedef unsigned short __uint16_t, uint16_t;
	typedef unsigned int __uint32_t, uint32_t;
	typedef unsigned long __uint64_t, uint64_t;
#elif defined WIN32
	#define __C89_NAMELESS __extension__
	#define __MINGW_EXTENSION __extension__
	typedef long uid_t;
	typedef long gid_t;
#endif

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

HEADER_CONTENTS

close $out_fh;

END {
#	unlink 'temp.c';
}

# Construct the compiler arguments
my $compiler_args = join(' ', ccopts);
$compiler_args =~ s/\n+//g;
# tcc doesn't know how to use quotes in -I paths; remove them if found.
$compiler_args =~ s/-I"([^"]*)"/-I$1/g if $^O =~ /MSWin/;
# Scrub all linker (-Wl,...) options
$compiler_args =~ s/-Wl,[^\s]+//g;

# Add arguments to produce the identifier list and serialization
$compiler_args = join(' ', $compiler_args,
	'-dump-identifier-names=names.txt',
	'-serialize-symtab=perl.h.cache',
	'temp.c'
);

print "About to run: tcc $compiler_args\n";

# Build the files!
system("tcc $compiler_args") == 0 or die "Unable to compile header file\n";

########################
# Generate the XS file #
########################

my $out_filename = $ARGV[0];
open $out_fh, '>', $out_filename or die "Unable to open $out_filename\n";

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

MODULE = C::Blocks::libperl       PACKAGE = C::Blocks::libperl

BOOT:
	/* Deserialize the extended symbol table. */
	extended_symtab_p symtab = tcc_deserialize_extended_symtab("perl.h.cache");
	
	/*** Borrowed, with slight modification, from Blocks.xs's serialize_symbol_table ***/
	{
		/* Add to my package's cshare space. This code is borrowed from
		 * Blocks.xs's serialize_symbol_table */
		SV * package_lists = get_sv("C::Blocks::libperl::__cblocks_extended_symtab_list");
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
	
XS_FILE

# Add global symbols
open my $in_fh, '<', 'names.txt'
	or die "Unable to open file containing list of global symbols\n";
while (my $line = <$in_fh>) {
	chomp $line;
	my @stuff = split /\s+/, $line;
	my $identifier = shift(@stuff);
	my $type = pop @stuff;
	my %is = map { +$_ => 1 } @stuff;
	if ($type ne 'func' and $type ne 'struct' and $is{static}) {
		print $out_fh "\t$type _tmp_$identifier = $identifier;\n";
		print $out_fh "\ttcc_set_extended_symbol(symtab, \"$identifier\", &_tmp_$identifier);\n";
	}
	else {
		print $out_fh "\ttcc_set_extended_symbol(symtab, \"$identifier\", &$identifier);\n";
	}
}
