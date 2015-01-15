package Alien::TinyCC;

use strict;
use warnings;

# Set up the directory where we can find TCC
use Cwd;
use File::Spec;
my $dist_dir = File::Spec->catfile(getcwd, 'tinycc');

sub banner {
	my $message = shift;
	print "\n", '#' x (length($message) + 4), "\n";
	print "# $message #\n";
	print '#' x (length($message) + 4), "\n\n";
}

# Do they have the tinycc source directory?
if (not -d 'tinycc-src') {
	banner "Pulling the tinycc source code from https://github.com/run4flat/tinycc.git";
	system(git => clone => 'https://github.com/run4flat/tinycc.git' => 'tinycc-src')
		and die "Unable to clone the source code for the Tiny C Compiler";
}

# Do they have a tinycc binary directory?
if (not -d 'tinycc') {
	# Build it (make this Windows friendly?)
	chdir 'tinycc-src';
	banner "Building tinycc";
	system("./configure --prefix=$dist_dir --disable-static") and die "TCC configure failed";
	system('make') and die "TCC make failed";
	banner "Installing to the local tinycc directory";
	system(make => 'install') and die "Install failed";
	chdir '..';
}

# Make sure that later require and use statements don't choke
$INC{'Alien/TinyCC.pm'} = $INC{'inc/Alien/TinyCC.pm'};

# Make sure we have LD_LIBRARY_PATH available. It seems that setting it
# below doesn't actually work! :-(
my $calling_filename = (caller)[1];
if($calling_filename ne 'Build.PL'
	and (!$ENV{LD_LIBRARY_PATH} or index($ENV{LD_LIBRARY_PATH}, libtcc_library_path()) == -1))
{
	die '***  Be sure to execute your programs like so:
***  LD_LIBRARY_PATH="' . $dist_dir . "/lib\" perl -Mblib -Mlib=inc $0 @ARGV\n";
}

############################
# Path retrieval functions #
############################

use Env qw( @PATH );
# Find the path to the tcc executable
sub path_to_tcc {
	return $dist_dir if $^O =~ /MSWin/;
	return File::Spec->catdir($dist_dir, 'bin');
}

# Modify the PATH environment variable to include tcc's directory
unshift @PATH, path_to_tcc();

# Find the path to the compiled libraries. Note that this is only applicable
# on Unixish systems; Windows simply uses the %PATH%, which was already
# appropriately set.
sub libtcc_library_path {
	return $dist_dir if $^O =~ /MSWin/;
	return File::Spec->catdir($dist_dir, 'lib');
}

# Add library path on Unixish:
if ($ENV{LD_LIBRARY_PATH}) {
	$ENV{LD_LIBRARY_PATH} = libtcc_library_path() . ':' . $ENV{LD_LIBRARY_PATH};
}
elsif ($^O !~ /MSWin/) {
	$ENV{LD_LIBRARY_PATH} = libtcc_library_path();
}

# Determine path for libtcc.h
sub libtcc_include_path {
	return File::Spec->catdir($dist_dir, 'libtcc') if $^O =~ /MSWin/;
	return File::Spec->catdir($dist_dir, 'include');
}

###########################
# Module::Build Functions #
###########################

sub MB_linker_flags {
	return ('-L' . libtcc_library_path, '-ltcc');
}

# version

1;
