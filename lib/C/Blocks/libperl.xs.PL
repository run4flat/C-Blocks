use strict;
use warnings;
use ExtUtils::Embed;
use inc::Alien::TinyCC;
use Devel::CheckLib;
use Config;
use File::Temp ();
use File::Spec;

##################################################
# Serialize perl.h and get a list of identifiers #
##################################################

sub serialize_perl_h {
	# Put the cache file in the sharedir
	my $share_file_location = File::Spec->catfile('share', 'perl.h.cache');
	return if -f $share_file_location and -f 'names.txt';

	my($perl_h_fh, $perl_h_file) = File::Temp::tempfile(
		'perl_h_XXXXXXXX', SUFFIX => '.c'
	);

	my $header_contents = <<HEADER_CONTENTS;

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

	print $perl_h_fh $header_contents;
	close $perl_h_fh;

	# Construct the compiler arguments
	my $compiler_args = join(' ', ccopts);
	$compiler_args =~ s/\n+//g;
	# tcc doesn't know how to use quotes in -I paths; remove them if found.
	$compiler_args =~ s/-I"([^"]*)"/-I$1/g if $^O =~ /MSWin/;
	# Scrub all linker (-Wl,...) options
	$compiler_args =~ s/-Wl,[^\s]+//g;

	# Add arguments to produce the identifier list and serialization
	mkdir 'share';
	$compiler_args = join(' ', $compiler_args,
		'-dump-identifier-names=names.txt',
		'-serialize-symtab='.$share_file_location,
		$perl_h_file
	);

	# Build the files!
	system("tcc $compiler_args") == 0
		or die "Unable to serialize the header file\n";
	unlink $perl_h_file;
}

#######################################
# Identify which identifiers are good #
#######################################

sub build_names_tested {
	return if -f 'names.tested';
	
	# Make sure we have names.txt to work with
	serialize_perl_h;
	open my $in_fh, '<', 'names.txt'
		or die "Unable to open file containing list of global symbols\n";
	
	# This is the file we will use to store our results
	open my $out_fh, '>', 'names.tested'
		or die "Unable to open tested names file\n";
	
	# Read global symbols
	while (my $line = <$in_fh>) {
		chomp $line;
		my @stuff = split /\s+/, $line;
		my $identifier = shift(@stuff);
		my $type = pop @stuff;
		my %is = map { +$_ => 1 } @stuff;
		my ($XS_code, $check_code);
		if ($type eq 'func') {
			$check_code = "void * tmp = $identifier";
			$XS_code = "\ttcc_set_extended_symbol(symtab, \"$identifier\", $identifier);\n";
		}
		elsif ($type ne 'struct' and $type ne 'pointer' and $type ne 'enum') {
			$check_code = "$type _tmp_$identifier = $identifier";
			$XS_code  = "\t$type _tmp_$identifier = $identifier;\n";
			$XS_code .=  "\ttcc_set_extended_symbol(symtab, \"$identifier\", &_tmp_$identifier);\n";
		}
		else {
			$check_code = "void * tmp = &$identifier";
			$XS_code = "\ttcc_set_extended_symbol(symtab, \"$identifier\", &$identifier);\n";
		}
		
		if (check_identifier ($check_code)) {
			print $out_fh $XS_code;
			print "Adding $identifier\n";
		}
		else {
			print "Skipping $identifier\n";
		}
	}
	
	# Add entries for S_croak_memory_wrap and S_bootstrap_ctype, static
	# functions defined in inline.h
	if (check_identifier("void * tmp = S_croak_memory_wrap")) {
		print $out_fh "\ttcc_set_extended_symbol(symtab, \"S_croak_memory_wrap\", S_croak_memory_wrap);\n";
		print "Manually adding S_croak_memory_wrap\n";
	}
	if (check_identifier("void * tmp = S_bootstrap_ctype")) {
		print $out_fh "\ttcc_set_extended_symbol(symtab, \"S_bootstrap_ctype\", S_bootstrap_ctype);\n";
		print "Manually adding S_bootstrap_ctype\n";
	}

	# Clean things up
	close $in_fh;
	close $out_fh;
	unlink 'names.txt';
}

####################
# check_identifier #
####################
# Some of the identifiers that are identified by tcc are not available,
# for some reason. I'm not sure if they're compiler intrinsics or
# some other thing. To help solve this problem, this function takes a
# string of C code, compiles a small test program linked against libperl,
# and executes the program to make sure that the symbol's usage does not
# cause unexpected termination.
sub check_identifier {
	my $code = shift;
	
	# Much of this code is copied from Devel::CheckLib. I wish I could
	# specify more things when using that module. :-(
	
	# open a temporary file and add the testing material
	my($ch, $cfile) = File::Temp::tempfile(
		'func_test_XXXXXXXX', SUFFIX => '.c'
	);
	print $ch <<TEST_CONTENTS;
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
int main(void) { $code; return 0; }
TEST_CONTENTS
	close $ch;
	
	# Build output filenames
	my $ofile = $cfile;
	$ofile =~ s/\.c$/$Config{_o}/;
	my $exefile = File::Temp::mktemp( 'func_test_XXXXXXXX' ) . $Config{_exe};
	
	# Build the system command arguments
	my $sys_cmd;
	if ( $Config{cc} eq 'cl' ) {                 # Microsoft compiler
		$sys_cmd = join(' ' , $Config{cc}, ccopts, $cfile, "/Fe$exefile", "/link", ldopts);
	}
	elsif($Config{cc} =~ /bcc32(\.exe)?/) {    # Borland
		$sys_cmd = join(' ' , $Config{cc}, ccopts, ldopts, "-o$exefile", $cfile);
	}
	else {                                     # Unix-ish
		$sys_cmd = join(' ' , $Config{cc}, ccopts, $cfile, "-o", $exefile, ldopts);
	}
	$sys_cmd =~ s/\n+//g;
	
	# Compile it
	my $compile_rv = Devel::CheckLib::_quiet_system($sys_cmd);
	my $success = 1 if $compile_rv == 0 and -x $exefile;
	if ($success) {
		# Run it
		my $absexefile = File::Spec->rel2abs($exefile);
		$absexefile = '"'.$absexefile.'"' if $absexefile =~ m/\s/;
		$success = 0 if system($absexefile) != 0;
	}
	
	# Clean up
	Devel::CheckLib::_cleanup_exe($exefile);
	unlink $cfile;
	return $success;
}


########################
# Generate the XS file #
########################

build_names_tested;
open my $in_fh, '<', 'names.tested'
	or die "Unable to open tested names file\n";
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

MODULE = C::Blocks::libperl       PACKAGE = C::Blocks::libperl

BOOT:
	/* Get the symtab file location */
	SV * file_location = get_sv("C::Blocks::libperl::symtab_file_location", 0);
	if (file_location == NULL) {
		croak("Internal error: could not find $C::Blocks::libperl::symtab_file_location");
	}
	
	/* Deserialize the extended symbol table. */
	extended_symtab_p symtab = tcc_deserialize_extended_symtab(SvPVbyte_nolen(file_location));
	
	/*** Borrowed, with slight modification, from Blocks.xs's serialize_symbol_table ***/
	{
		/* Add to my package's cshare space. This code is borrowed from
		 * Blocks.xs's serialize_symbol_table */
		SV * package_lists = get_sv("C::Blocks::libperl::__cblocks_extended_symtab_list",
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
	
XS_FILE

# Copy the contents
print $out_fh (<$in_fh>);

close $out_fh;
close $in_fh;
