use strict;
use warnings;

#######################################################
# TEMPORARY BOOTSTRAPPING TO HELP BRING DEVELOPERS ON #
#######################################################
use inc::Alien::TinyCC;
# Also uncomment Alien::TinyCC requirements below!!!!!!!!!!
###########################################################
# END TEMPORARY BOOTSTRAPPING TO HELP BRING DEVELOPERS ON #
###########################################################

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
#		'Alien::TinyCC' => '0.05_01',
		# meta_merge was added in v 0.28:
		'Module::Build' => 0.28,
	},
	build_requires => {
		'Test::More' => 0.88,
#		'Alien::TinyCC' => '0.05_01',
	},
#	requires => {
#		'Alien::TinyCC' => '0.05_01',
#	},
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
	share_dir => 'share',
);

$build->create_build_script;
