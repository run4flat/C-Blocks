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
	# Build it
	banner "Building tinycc";
	if ($^O =~ /MSWin/) {
		mkdir 'tinycc';
		chdir 'tinycc-src\\win32';
		system("build-tcc.bat") and die "TCC build failed";
		chdir '..\\..';
		banner "Installing to the local tinycc directory";
		system(qw(xcopy /E tinycc-src\win32 tinycc)) and die "Install failed";
	}
	else {
		chdir 'tinycc-src';
		system("./configure --prefix=$dist_dir --disable-static") and die "TCC configure failed";
		system('make') and die "TCC make failed";
		banner "Installing to the local tinycc directory";
		system(make => 'install') and die "Install failed";
		chdir '..';
	}
}

# Make sure that later require and use statements don't choke
$INC{'Alien/TinyCC.pm'} = $INC{'inc/Alien/TinyCC.pm'};

sub path_setting_string {
	my $message = "***  Be sure to set the LD_LIBRARY_PATH like so:\n";
	# DOS
	if ($^O =~ /MSWin/) {
		$message .= 'PATH=%PATH%;'.$dist_dir;
	}
	elsif ($ENV{SHELL} =~ /csh$/) {
		# C Shell
		$message .= 'setenv LD_LIBRARY_PATH '.libtcc_library_path()
	}
	else {
		# Bourne shell (the default)
		$message .= 'LD_LIBRARY_PATH='.libtcc_library_path().'; export LD_LIBRARY_PATH';
	}
	return $message . "\n";
}

# Make sure we have LD_LIBRARY_PATH available. It seems that setting it
# below doesn't actually work! :-(
my $calling_filename = (caller)[1];
if($calling_filename ne 'Build.PL') {
	if ($^O =~ /MSWin/) {
		# Windows. See if the dist dir is in %PATH%
		die path_setting_string()
			if !$ENV{PATH} or index($ENV{PATH}, libtcc_library_path()) == -1;
	}
	elsif (!$ENV{LD_LIBRARY_PATH} or index($ENV{LD_LIBRARY_PATH}, libtcc_library_path()) == -1)
	{
		die path_setting_string();
	}
}
else {
	print path_setting_string();
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
