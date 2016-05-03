use strict;
use warnings;
use Alien::TinyCCx;
use Capture::Tiny qw(capture_merged);
use Config;
use ExtUtils::CBuilder;
use ExtUtils::Config;
use ExtUtils::Embed;
use File::Basename;
use File::Spec;
use File::Temp ();
use Module::Build;

my $tempdir = File::Temp::tempdir(CLEANUP => 1);
my $xs_counter = 1;
my %prelinking = map { $_ => 1 } qw/MSWin32 VMS aix/;
my @path = File::Spec->path;

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
	# tcc does not like the -arch compiler option
	$compiler_args =~ s/-arch\s+\w+//g;
	
	# GCC Statement Expressions (also called brace groups) give tcc
	# trouble. I should be able to turn those off by defining
#	$compiler_args .= ' -DPERL_GCC_BRACE_GROUPS_FORBIDDEN';  # doesn't work... why?
	# but that doesn't work. So instead I just turn off debugging. It's
	# not the greatest solution, but it seems like it gets things to
	# work.
	$compiler_args =~ s/\s*-DDEBUGGING//;
	# System perl on Debian includes the -DDEBIAN, which causes a
	# similar issue:
	$compiler_args =~ s/\s*-DDEBIAN//;

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
	Module::Build->current->add_to_cleanup($share_file_location);
	Module::Build->current->add_to_cleanup('names.txt');
}

################################################
# Extract identifier names from the tcc output #
################################################

sub build_identifiers_list {
	open my $in_fh, '<', 'names.txt'
		or die "Unable to open file containing list of global symbols\n";
	
	# Read global symbols
	my @identifiers;
	while (my $line = <$in_fh>) {
		push @identifiers, $1 if $line =~ /(\w+)/;
	}
	
	close $in_fh;
	return @identifiers;
}

########################
# Generate the XS file #
########################
print "Creating $ARGV[0]\n";

serialize_perl_h;
my @identifiers = build_identifiers_list;

# early and aggressive screening on Windows
@identifiers = dll_screen(@identifiers) if $^O =~ /Win32/;
# Fast pass screening
@identifiers = executable_screen(@identifiers);
# Slower but more exact screening
@identifiers = xs_screen(@identifiers);
# Final brute-force screening, useful for the compilers that emit
# errors and warnings for which I have not written regexes
@identifiers = brute_force_screen(@identifiers);

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

########################################################################
#                         Testing functions                            #
########################################################################
# This section contains my functions for checking sets of identifiers.
# Generally speaking, the fast methods tend to have more false positives
# and the slowest method has no false positives.

# The three approaches include
# 1) scanning the symbol lists of dlls (Windows-specific)
# 2) building an executable and scanning the compiler and linker output
#    for error messages, and
# 3) Building a test XS module and loading it with DynaLoader, again
#    scanning the output for specific error messages.

#####################################
# Windows Dynamic Library Screening #
#####################################
# On Linux and Mac, I can identify bad identifiers by attempting to compile
# a source file and examining the output. Unfortunately, linking to bad symbols
# in msvcrt.dll leads to a pop-up window stating "procedure entry point <foo>
# could not be located" and stalls the process until the user closes it! This
# is not useful for screening out bad identifiers. So here we take a more
# active approach. We load the DLLs used in libperl.dll and check that each
# identifier can be found in one of them. This is a little more aggressive than
# I would like, but I know of no other method to avoid the pop-ups.

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
		if ($identifier =~ /^S_/) {
			# Mark this as kept for now; it'll get screened out later
			# if necessary.
			push @to_return, $identifier;
			next IDENTIFIER;
		}
		for my $lib (values %found_dlls) {
			if (DynaLoader::dl_find_symbol($lib, $identifier)) {
				push @to_return, $identifier;
				next IDENTIFIER;
			}
		}
	}
	
	return @to_return;
}

####################################
# Executable compilation screening #
####################################
# The first pass (possibly after the dll screening given above) is to
# try to compile an executable using ExtUtils::CBuilder. Output from the
# compiler and linker, including deprecation warnings, are checked and
# used to pare down the identifier list. This is preferred to the
# DynaLoader approach because at least some linkers out there will
# report all bad symbols, whereas DynaLoader fails on the first bad
# symbol and requires recompilation for each symbol.
sub executable_source_code {
	my @identifiers = @_;
	# open a temporary file and add the testing material. I use printf
	# because I found that merely accessing the symbol address was not
	# sufficient for making the linker fail. The printf command does
	# not lead to any visible output on the terminal, though, so it's
	# not a problem.
	my($ch, $cfile) = File::Temp::tempfile(DIR => $tempdir, UNLINK => 1,
		SUFFIX => '.c',
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
			printf(\"%p\\n\", &$identifier);
CHECK_IDENTIFIER
	}
	print $ch "\treturn 0;\n}";
	close $ch;
	
	return $cfile;
}

# Processes the warnings and/or errors from the compiler and/or linker
# to pick out bad identifiers. Returns a hash whose keys are the failed
# identifiers
sub create_is_bad_hash {
	# Pick out the failed identifiers from the list of warnings or errors
	my @failed_identifiers = map {
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
		# DynaLoader
		: /undefined symbol:\s*(\S+)/ ? ($1)
		: ()
	} @_;
	# Construct and return hash of identifier names to screen
	return map {
		$_ => 1,
		(/^_imp__(.*)/ ? ($1 => 1) : ())
	} @failed_identifiers;
}

#####################
# executable_screen #
#####################
# Given a list of identifiers, puts all of them in a C file and
# processes the output of compiler and linker errors to remove obvious
# bad ones. This fails to link on Debian systems unless the system has
# libperl-dev, or this is being installed on a custom perl (or perlbrew)
# environment. Brute-force will work, but is much slower.
sub executable_screen {
	my @identifiers = @_;
	
	while(1) {
		print "Using executable screen to check ", 0+@identifiers, " identifiers\n";
		# Create the test file
		my $cfile = executable_source_code(@identifiers);
		
		# Get the compiler output when invoked with ExtUtils::CBuilder
		my ($merged_output) = capture_merged {
			my $builder = ExtUtils::CBuilder->new;
			
			# Primary diagnostics come from the compiler output, not
			# death notes. Eval and discard.
			my $ofile = eval { $builder->compile(source => $cfile,
				extra_compiler_flags => ccopts) };
			return if $@;
			
			# Next try to link and see if we have trouble
			my (@exec_files) = eval { $builder->link_executable(objects => $ofile,
				extra_linker_flags => ldopts) };
			unlink $ofile;
			return if $@;
			
			# Cleanup and return success
			unlink $_ foreach @exec_files;
		};
		unlink $cfile;
		
		my @failures = split /\n/, $merged_output;
		my %is_bad = create_is_bad_hash(@failures);
		return @identifiers if keys (%is_bad) == 0;
		
		# Screen out the bad ones and try again
		@identifiers = grep { !$is_bad{$_} } @identifiers;
	}
}

#########################################
# Full XS DynaLoader Compilation Screen #
#########################################
# Even with the executable screen above, some identifiers seem to make
# it through. If I try to link to them in the generated xs file, I will
# have linker errors. The process given below emulates, as closely as
# possible, the process that Perl itself will use when loading PerlAPI.

##################
# xs_source_code #
##################
# This takes a package and list of identifiers to test and constructs
# the test code to check it, returning the c file name. Much of this
# code is copied from ExtUtils::HasCompiler.
sub xs_source_code {
	my ($package, @identifiers) = @_;
	
	my($ch, $cfile) = File::Temp::tempfile(DIR => $tempdir, UNLINK => 1,
		SUFFIX => '.c',
	);
	my $basename = basename($cfile, '.c');
	print $ch <<'TEST_CONTENTS' or die "Could not print initial contents of C test file\n";
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifndef PERL_UNUSED_VAR
#define PERL_UNUSED_VAR(var)
#endif
 
XS(exported) {
#ifdef dVAR
	dVAR;
#endif
	dXSARGS;

	PERL_UNUSED_VAR(cv); /* -W */
	PERL_UNUSED_VAR(items); /* -W */
	char buffer[1000];
TEST_CONTENTS

	# use sprintf: even optimizing compilers won't optimize that away
	for my $identifier (@identifiers) {
		print $ch <<CHECK_IDENTIFIER or die "Could not include identifier $identifier in C test file\n"
			#ifdef $identifier
			#undef $identifier
			#endif
			sprintf(buffer, "%p", &$identifier);
CHECK_IDENTIFIER
	}

		print $ch <<TEST_CONTENTS or die "Could not print final part of C test file\n";
        XSRETURN_IV(42);
}

#ifndef XS_EXTERNAL
#define XS_EXTERNAL(foo) XS(foo)
#endif
 
/* we don't want to mess with .def files on mingw */
#if defined(WIN32) && defined(__GNUC__)
#  define EXPORT __declspec(dllexport)
#else
#  define EXPORT
#endif

EXPORT XS_EXTERNAL(boot_$basename) {
#ifdef dVAR
	dVAR;
#endif
	dXSARGS;

	PERL_UNUSED_VAR(cv); /* -W */
	PERL_UNUSED_VAR(items); /* -W */

	newXS("${package}::exported", exported, __FILE__);
}
TEST_CONTENTS
	close $ch or die "Could not close C test file\n";
	
	return $cfile;
}

##################
# xs_screen_once #
##################
# Follow ExtUtils::HasCompiler to see if our module builds, links, and
# loads. Returns a success indicator and a scalar with the build text.
# This is used by both the xs_screen and the brute_force screen.
sub xs_screen_once {
	my (@identifiers) = @_;
	print "Using DynaLoader screen to check ", 0+@identifiers, " identifiers\n";
	my $config = ExtUtils::Config->new;
	
	my $shortname = '_Loadable' . $xs_counter++;
	my $package = "Identifier::Probe::$shortname";
	my $source_name = xs_source_code($package, @identifiers);
	my $basename = basename($source_name, '.c');
	
	my $abs_basename = File::Spec->catfile($tempdir, $basename);
	my $object_file = $abs_basename . $config->get('_o');
	my $loadable_object = $abs_basename . '.' . $config->get('dlext');
	my $incdir = File::Spec->catdir($config->get('archlibexp'), 'CORE');
	
	my ($cc, $ccflags, $optimize, $cccdlflags, $ld, $ldflags, $lddlflags, $libperl, $perllibs) = map { $config->get($_) } qw/cc ccflags optimize cccdlflags ld ldflags lddlflags libperl perllibs/;
	
	if ($prelinking{$^O}) {
		require ExtUtils::Mksymlists;
		capture_merged {
			ExtUtils::Mksymlists::Mksymlists(NAME => $basename, FILE => $abs_basename, IMPORTS => {});
		};
	}
	my @commands;
	if ($^O eq 'MSWin32' && $cc =~ /^cl/) {
		push @commands, qq{$cc $ccflags $cccdlflags $optimize /I "$incdir" /c $source_name /Fo$object_file};
		push @commands, qq{$ld $object_file $lddlflags $libperl $perllibs /out:$loadable_object /def:$abs_basename.def /pdb:$abs_basename.pdb};
	}
	elsif ($^O eq 'VMS') {
		# Mksymlists is only the beginning of the story.
		open my $opt_fh, '>>', "$abs_basename.opt" or die "Couldn't append to '$abs_basename.opt'";
		print $opt_fh "PerlShr/Share\n";
		close $opt_fh;

		my $incdirs = $ccflags =~ s{ /inc[^=]+ (?:=)+ (?:\()? ( [^\/\)]* ) }{}xi ? "$1,$incdir" : $incdir;
		push @commands, qq{$cc $ccflags $optimize /include=($incdirs) $cccdlflags $source_name /obj=$object_file};
		push @commands, qq{$ld $ldflags $lddlflags=$loadable_object $object_file,$abs_basename.opt/OPTIONS,${incdir}perlshr_attr.opt/OPTIONS' $perllibs};
	}
	else {
		my @extra;
		if ($^O eq 'MSWin32') {
			push @extra, "$abs_basename.def";
			push @extra, '-l' . ($libperl =~ /lib([^.]+)\./)[0];
		}
		elsif ($^O eq 'cygwin') {
			push @extra, catfile($incdir, $config->get('useshrplib') ? 'libperl.dll.a' : 'libperl.a');
		}
		elsif ($^O eq 'aix') {
			$lddlflags =~ s/\Q$(BASEEXT)\E/$abs_basename/;
			$lddlflags =~ s/\Q$(PERL_INC)\E/$incdir/;
		}
		push @commands, qq{$cc $ccflags $optimize "-I$incdir" $cccdlflags -c $source_name -o $object_file};
		push @commands, qq{$cc $optimize $object_file -o $loadable_object $lddlflags @extra $perllibs};
	}
	
	my $build_text = '';
	my $success = 1;
	for my $command (@commands) {
		(my $to_add, $success) = capture_merged {
			return ((system $command) == 0);
		};
		$build_text .= $to_add;
		return (0, $build_text) unless $success;
	}

	require DynaLoader;
	local @DynaLoader::dl_require_symbols = "boot_$basename";
	my $handle = DynaLoader::dl_load_file($loadable_object, 0);
	return (0, $build_text . DynaLoader::dl_error()) unless $handle;
	
	my $symbol = DynaLoader::dl_find_symbol($handle, "boot_$basename") or die "Couldn't find boot symbol for $basename";
	my $compilet = do {
		no warnings 'redefine';
		DynaLoader::dl_install_xsub('__ANON__::__ANON__', $symbol, $source_name);
	};
	my $ret = eval { $compilet->(); $package->exported } or carp $@;
	delete $Identifier::Probe::{"$shortname\::"};
	eval { DynaLoader::dl_unload_file($handle) } or carp $@;
	return (defined $ret && $ret == 42, $build_text);
}

#############
# xs_screen #
#############
# Given a list of identifiers, puts all of them in a C file and
# processes the output of compiler and linker errors to remove obvious
# bad ones.
sub xs_screen {
	my @identifiers = @_;
	
	while(1) {
		my (undef, $merged_output) = xs_screen_once(@identifiers);

		my @failures = split /\n/, $merged_output;
		my %is_bad = create_is_bad_hash(@failures);
		return @identifiers if keys (%is_bad) == 0;
		
		my $N_identifiers = 0+@identifiers;
		
		# Screen out the bad ones and try again
		@identifiers = grep { !$is_bad{$_} } @identifiers;
		
		if (@identifiers == $N_identifiers) {
			print "Reportedly bad identifier(s) ", join(', ', keys(%is_bad)),
				" were not find them in identifier list\n";
			return @identifiers;
		}
	}
}


#########################
# Brute force screening #
#########################
# All of the above screening mechanisms are 
sub brute_force_screen {
	my @identifiers = @_;
	print "Beginning brute-force screening\n";
	
	# This brute-force screening process is based on xs_screening, but
	# uses binary search to remove offending identifiers regardless of
	# the error messages. This method always works, but is exceedingly
	# slow for a large number of identifiers.
	my @to_return;
	my @set_of_maybe_good = [@identifiers];
	while(@set_of_maybe_good) {
		my @curr_set = @{shift @set_of_maybe_good};
		@curr_set = sort @curr_set if @curr_set < 128;
		my ($is_good) = xs_screen_once(@curr_set);
		if ($is_good) {
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
	
	return @to_return;
}
