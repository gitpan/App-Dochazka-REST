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
    script_files        => [
        'bin/dochazka-rest',
    ],
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Plack::Test' => 0,
        'Test::More'  => 0,
        'Test::JSON'  => 0,
    },
    requires => {
        'App::CELL'     => 0.194,
        'DBD::Pg'       => 0,
        'DBI'           => 0,
        'JSON'          => 0,
        'Plack::Runner' => 0,
        'Web::Machine'  => 0.15,
    },
    add_to_cleanup     => [ 'App-Dochazka-REST-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
