use strict;
use warnings;

# |||| Bootstrap |||| #
# \/\/           \/\/ #

sub install_local_alien {
	print <<message;
C::Blocks requires the latest git release of Alien::TinyCC.
If you like, I can fetch the latest work, build it in a
subdirectory of this one, and have C::Blocks use that
distribution while building.

message
	print "Would you like me to do that? (y/N) ";
	my $response = <>;
	exit(1) unless $response =~ /^y/i;
	
	system('git clone https://github.com/run4flat/Alien-TinyCC.git');
	chdir 'Alien-TinyCC';
	system('git submodule init');
	system('git submodule update');
	system("$^X Build.PL");
	system("$^X Build");
print <<message;
If you anticipate doing a lot of development with C::Blocks
then it might be simplest to install Alien::TinyCC. If you
do not install Alien::TinyCC, then manually running any
scripts that use C::Blocks (i.e. test scripts) will require
that you invoke them with a special incantation that I will
explain shortly.

message
	print "Would you like me to install Alien::TinyCC? (y/N) ";
	$response = <>;
	if ($response =~ /^y/i) {
		system("$^X Build install");
		chdir '..';
		use File::Path qw(remove_tree);
		remove_tree('Alien-TinyCC') if $response =~ /^y/i;
	}
	else {
		chdir '..';
	}
	exec("$^X Build.PL");  # Start over
}

BEGIN {
	if (-d 'Alien-TinyCC') {
		eval q{ use blib 'Alien-TinyCC' };
		print <<message;
Using the copy of Alien::TinyCC in the like-named sub-
directory. When running stand-alone scripts, be sure to
call them like so:

	perl -Mblib=Alien-TinyCC -Mblib <script-name>

message
	}

	# Bootstrap things to help new developers. Remove this before publishing to
	# CPAN.
	eval q{
		use File::ShareDir;
		1;
	} or do {
		print "You need File::ShareDir in order to install and use Alien::TinyCC. Shall I install it using cpanm? ";
		my $answer = <>;
		if ($answer =~ /^y/i) {
			system('cpanm File::ShareDir');
			exec("$^X Build.PL");  # Start over
		}
		exit(1);
	};
	
	# Make sure we have Alien::TinyCC
	eval q{
		use Alien::TinyCC;
		1;
	} or install_local_alien;
	# Make sure Alien::TinyCC is new enough
	install_local_alien if $Alien::TinyCC::VERSION < 0.05_01;
}

# /\/\           /\/\ #
# |||| Bootstrap |||| #


use Module::Build;
use Alien::TinyCC;

#### --( Make sure we have ppport.h )-- ####

#use Devel::PPPort;
#Devel::PPPort::WriteFile();

#### --( Make the builder )-- ####

my $build = Module::Build->new(
	module_name => 'C::Blocks',
	license  => 'perl',
	dist_author         => q{David Mertens <dcmertens.perl@gmail.com>},
	configure_requires => {
		'Devel::PPPort' => 0,
		'Alien::TinyCC' => '0.05_01',
		# meta_merge was added in v 0.28:
		'Module::Build' => 0.28,
	},
	build_requires => {
		'Test::More' => 0.88,
		'Alien::TinyCC' => '0.05_01',
	},
	requires => {
		'Alien::TinyCC' => '0.05_01',
	},
	needs_compiler => 1,
	dynamic_config => 1,
	include_dirs => [Alien::TinyCC->libtcc_include_path, '.'],
	extra_linker_flags => [Alien::TinyCC->MB_linker_flags],
	meta_merge => {
		resources  => {
			repository => "http://github.com/run4flat/C-Blocks",
			bugtracker => "http://github.com/run4flat/C-Blocks/issues",
		},
		no_index => {
			file      => [ 'README.pod' ],
		},
	},
);

$build->create_build_script;
