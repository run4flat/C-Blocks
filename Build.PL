use strict;
use warnings;

use File::Spec;
use Module::Build;
use Alien::TinyCCx;

#### --( Make the builder )-- ####

my $build = Module::Build->new(
	module_name => 'C::Blocks',
	license  => 'perl',
	dist_author         => q{David Mertens <dcmertens.perl@gmail.com>},
	configure_requires => {
		'Alien::TinyCCx' => '0.12',
		# meta_merge was added in v 0.28:
		'Module::Build' => 0.28,
	},
	build_requires => {
		'Test::More' => 0.88,
		# For configuration, path to tcc, etc
		'Alien::TinyCCx' => '0.12',
		# For PerlAPI
		'Capture::Tiny' => 0,
		'ExtUtils::CBuilder' => 0,
		'ExtUtils::Config' => 0,
		'ExtUtils::Embed' => 0,
		'ExtUtils::ParseXS' => 3.0,
		'File::Spec' => 0,
		'File::Basename' => 0,
		'File::Temp' => 0,
		'File::Spec' => 0,
		'Test::Warn' => 0,
	},
	requires => {
		'Alien::TinyCCx' => '0.12',
		'File::ShareDir' => 0,
		'File::Spec' => 0,
	},
	c_source => 'src',
	needs_compiler => 1,
	dynamic_config => 1,
	include_dirs => [Alien::TinyCCx->libtcc_include_path, '.', 'src'],
	extra_linker_flags => [Alien::TinyCCx->MB_linker_flags],
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
	add_to_cleanup => [
		'names.txt',
		File::Spec->catfile(qw(share perl.h.cache)),
	],
);

$build->create_build_script;
