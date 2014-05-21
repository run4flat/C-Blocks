use strict;
use warnings;

# |||| Bootstrap |||| #
# \/\/           \/\/ #

BEGIN {
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
	} or do {
		print "Looks like you don't have Alien::TinyCC. Would you like me to install it for you using cpanm? ";
		my $answer = <>;
		if ($answer =~ /^y/i) {
			system('cpanm https://github.com/run4flat/Alien-TinyCC.git');
			exec("$^X Build.PL");  # Start over
		}
		exit(1);
	};
	if ($Alien::TinyCC::VERSION < 0.05_01) {
		print "Your version of Alien::TinyCC is too old. Shall I update it using cpanm? ";
		my $answer = <>;
		if ($answer =~ /^y/i) {
			system('cpanm https://github.com/run4flat/Alien-TinyCC.git');
			exec("$^X Build.PL");  # Start over
		}
		exit(1);
	}
}

# /\/\           /\/\ #
# |||| Bootstrap |||| #


use Module::Build;
use Alien::TinyCC;

#### --( Make sure we have ppport.h )-- ####

use Devel::PPPort;
Devel::PPPort::WriteFile();

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
