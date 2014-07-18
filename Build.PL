use 5.006;
use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'App::Dochazka::REST',
    license             => 'bsd',
    dist_author         => q{Nathan Cutler <ncutler@suse.cz>},
    dist_version_from   => 'lib/App/Dochazka/REST.pm',
    create_license      => 0,
    create_readme       => 1,
    release_status      => 'stable',
    share_dir           => {
        dist => [ 'config' ],
    },
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'App::CELL'     => 0.183,
        'DBD::Pg'       => 0,
        'DBI'           => 0,
        'JSON'          => 0,
    },
    add_to_cleanup     => [ 'App-Dochazka-REST-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
