use strict;
use warnings;
use ExtUtils::Embed;
use Alien::TinyCCx;
use Devel::CheckLib;
use Config;
use File::Temp ();
use File::Spec;

# With static libperls, I cannot look up symbol names on the fly.
# In order to work on all Perls, these libperl bindings build a
# cached symbol table for perl.h. They then load all pointers to
# the symbols during the BOOT section. Module::Build knows how to
# build XS modules that have access to these symbols, whether
# libperl is static or shared.

##################################################
# Serialize perl.h and get a list of identifiers #
##################################################
# It turns out that lots of identifiers in the various header files
# are declared but are not actually defined. This command uses TCC
# to get the list of declarations, not definitions. We'll have to
# pare down the results next.
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

sub build_identifiers_list {
	open my $in_fh, '<', 'names.txt'
		or die "Unable to open file containing list of global symbols\n";
	
	# Read global symbols
	my @identifiers;
	while (my $line = <$in_fh>) {
		push @identifiers, $1 if $line =~ /(\w+)/;
	}
	
	# Fast screening for compiler and linker error messages
	@identifiers = screen_identifiers(@identifiers);
	
	# Double-check in case the fast screening returned false positives.
	my @to_return;
	my @set_of_maybe_good = [@identifiers];
	while(@set_of_maybe_good) {
		my @curr_set = @{shift @set_of_maybe_good};
		@curr_set = sort @curr_set if @curr_set < 128;
		if (check_identifier(@curr_set)) {
			push @to_return, @curr_set;
		}
		elsif (@curr_set == 1) {
			print "Skipping @curr_set\n";
		}
		else {
			# Three-way split is faster than two-way split. It is equally
			# fast as a four-way split, too, so go for the simpler code.
			# See benchmarks listed below.
			my @mid = splice @curr_set, @curr_set/3;
			my @right = splice @mid, @mid/2;
			unshift @set_of_maybe_good, \@right if @right;
			unshift @set_of_maybe_good, \@mid if @mid;
			unshift @set_of_maybe_good, \@curr_set if @curr_set;
		}
	}
	
	# Clean things up
	close $in_fh;
	unlink 'names.txt';
	return @to_return;
}

######################################
# Windows Dynamics Library Screening #
######################################
# On Linux and Mac, I can identify bad identifiers by attempting to compile
# a source file and examining the output. Unfortunately, linking to bad symbols
# in msvcrt.dll leads to a pop-up window stating "procedure entry point <foo>
# could not be located" and stalls the process until the user closes it! This
# is not useful for screening out bad identifiers. So here we take a more
# active approach. We load the DLLs used in libperl.dll and check that each
# identifier can be found in one of them. This is a little more aggressive than
# I would like, but it's pretty fast and avoids the pop-ups.

my @path = File::Spec->path;
# Searches all folders in the path for the given dll, returning the full path
# if found, and croaking otherwise.
sub find_dll {
	my $dll_to_find = shift;
	for my $dir (@path) {
		my $full = File::Spec->catfile($dir, $dll_to_find);
		return $full if -f $full;
	}
	die "Unable to find full path for $dll_to_find\n";
}

sub dll_screen {
	my @identifiers = @_;
	
	# Figure out the perl dll file
	return @identifiers unless $Config{libperl};
	my $perl_dll = $Config{libperl};
	$perl_dll =~ s/^lib//;
	$perl_dll =~ s/\.a/\.dll/;
	$perl_dll = find_dll($perl_dll);
	
	# Load the perl dll file and scan for dependencies
	my %found_dlls = ($perl_dll => DynaLoader::dl_load_file($perl_dll));
	my @dlls_to_scan = ($perl_dll);
	
	# Build the full list of dlls
	while(@dlls_to_scan) {
		my $dll = shift @dlls_to_scan;
		# Get all dlls that this one depends on
		for my $line (`objdump -x $dll`) {
			if ($line =~ /DLL Name: (\S+)/) {
				my $full_dll = find_dll($1);
				next if exists $found_dlls{$full_dll};
				# Load this one
				$found_dlls{$full_dll} = DynaLoader::dl_load_file($full_dll);
				# Mark it so we look through this one's dependencies
				push @dlls_to_scan, $full_dll;
			}
		}
	}
	
	# Dynaloader has trouble loading some dlls. Whether it's because
	# they're hidden, or because they have a different format, I
	# cannot say. But it doesn't matter, just get rid of them.
	for my $k (keys %found_dlls) {
		delete $found_dlls{$k} if not defined $found_dlls{$k};
	}
	# Figure out which identifiers can be located in one of our dlls
	my @to_return;
	IDENTIFIER: for my $identifier (@identifiers) {
		for my $lib (values %found_dlls) {
			if (DynaLoader::dl_find_symbol($lib, $identifier)) {
				push @to_return, $identifier;
				next IDENTIFIER;
			}
		}
	}
	
	return @to_return;
}

######################
# build_test_program #
######################
# The code to test symbols is used in a couple of different places, so I
# extracted it into its own function. This takes a list of identifiers to test
# and constructs the test program to check it. It returns the test file name
# and the system command to perform the compilation. Much of this code is
# copied from Devel::CheckLib.
sub build_test_program {
	my @identifiers = @_;
		# open a temporary file and add the testing material. I use printf
		# because I found that merely accessing the symbol address was not
		# sufficient for making the linker fail. The printf command does
		# not lead to any visible output on the terminal, though, so it's
		# not a problem.
		my($ch, $cfile) = File::Temp::tempfile(
			'func_test_XXXXXXXX', SUFFIX => '.c'
		);
		print $ch <<TEST_CONTENTS;
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
int main(void) {
TEST_CONTENTS
	for my $identifier (@identifiers) {
		print $ch <<CHECK_IDENTIFIER;
			#ifdef $identifier
			#undef $identifier
			#endif
			printf(\"%p\\r                        \\r\", &$identifier);
CHECK_IDENTIFIER
	}
	print $ch "\treturn 0;\n}";
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
	
	return ($cfile, $ofile, $exefile, $sys_cmd);
}

######################
# screen_identifiers #
######################
# Given a list of identifiers, puts all of them in a C file and
# processes the output of compiler and linker errors to remove obvious
# bad ones.
sub screen_identifiers {
	my @identifiers = @_;
	
	# early and aggressive screening on Windows
	@identifiers = dll_screen(@identifiers) if $^O =~ /Win32/;
	
	# Check with the compiler and linker, useful even on Windows for removing
	# deprecated symbols.
	while(1) {
		# Create the test file
		my ($cfile, $ofile, $exefile, $sys_cmd) = build_test_program(@identifiers);
		
		# compile and link, capturing all output
		my @failures = `$sys_cmd 2>&1`;
		
		# Clean up files
		unlink $exefile;
		unlink $ofile;
		unlink $cfile;
		
		# Pick out the failures and scrub them from the list of identifiers
		@failures = map {
			  /undefined reference to `\@?([^\@']+)/ ? ($1)
			: /error: '(.*)' undeclared/ ? ($1)
			: /warning: '(.*)' is deprecated/ ? ($1)
			# Linux
			: /warning: .*`(\w+)'.*is dangerous/ ? ($1)
			: /warning: (\w+) is not implemented/ ? ($1)
			: /warning: `?(\w+)'? is obsolete/ ? ($1)
			: /warning: \W*(\w+)\W* is deprecated/ ? ($1)
			: /error: \W*(\w+)\W* undeclared/ ? ($1)
			# Mac
			: /error: use of undeclared identifier \W(\w+)\W/ ? ($1)
			: /_getdirentries_is_not_available_when_64_bit/ ? ('getdirentries') # weird
			: /"_(\w+)", referenced from/ ? ($1)
			: ()
		} @failures;
		
		# All done if nothing failed
		return @identifiers if @failures == 0;
		
		# Produce a hash of failure strings
		my %is_bad = map {
			$_ => 1,
			(/^_imp__(.*)/ ? ($1 => 1) : ())
		} @failures;
		@identifiers = grep { !$is_bad{$_} } @identifiers;
	}
}

####################
# check_identifier #
####################
# The initial screening process may not remove all troublesome identifiers.
# This function is similar to the screening process, but it actually runs
# the generated C file to make sure everything is accessible at runtime.
sub check_identifier {
	my ($cfile, $ofile, $exefile, $sys_cmd) = build_test_program(@_);
	
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

serialize_perl_h;
my @identifiers = build_identifiers_list;
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
XS_FILE

# Set up the undefs:
for my $id (@identifiers) {
	print $out_fh <<ADD_IDENTIFIER;
		#ifdef $id
		#undef $id
		#endif
ADD_IDENTIFIER
}

print $out_fh <<'XS_FILE';
MODULE = C::Blocks::PerlAPI       PACKAGE = C::Blocks::PerlAPI

BOOT:
	/* Get the symtab file location */
	SV * file_location = get_sv("C::Blocks::PerlAPI::symtab_file_location", 0);
	if (file_location == NULL) {
		croak("Internal error: could not find $C::Blocks::PerlAPI::symtab_file_location");
	}
	
	/* Deserialize the extended symbol table. */
	extended_symtab_p symtab = tcc_deserialize_extended_symtab(SvPVbyte_nolen(file_location));
	
	/*** Borrowed, with slight modification, from Blocks.xs's serialize_symbol_table ***/
	{
		/* Add to my package's cshare space. This code is borrowed from
		 * Blocks.xs's serialize_symbol_table */
		SV * package_lists = get_sv("C::Blocks::PerlAPI::__cblocks_extended_symtab_list",
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

for my $id (@identifiers) {
	print $out_fh <<ADD_IDENTIFIER;
		tcc_set_extended_symbol(symtab, \"$id\", &$id);
ADD_IDENTIFIER
}

close $out_fh;
