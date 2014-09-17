# ************************************************************************* 
# Copyright (c) 2014, SUSE LLC
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 
# 3. Neither the name of SUSE LLC nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# ************************************************************************* 
#
# basic unit tests for activities
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use DBI;
use App::Dochazka::REST;
use App::Dochazka::REST::Model::Activity qw( aid_by_code );
use Scalar::Util qw( blessed );
use Test::Fatal;
use Test::More;

# plan tests
plan skip_all => "Set DOCHAZKA_TEST_MODEL to activate data model tests" if ! defined $ENV{'DOCHAZKA_TEST_MODEL'};
my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka-rest' );
my $status = $REST->{init_status};
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}

# spawn two activity objects
my $act = App::Dochazka::REST::Model::Activity->spawn;
isa_ok( $act, 'App::Dochazka::REST::Model::Activity' );
my $act2 = App::Dochazka::REST::Model::Activity->spawn;
isa_ok( $act2, 'App::Dochazka::REST::Model::Activity' );

# test some wrong _load function calls
#like( exception { App::Dochazka::REST::Model::Activity::_load( 'aid' => 1, 'code' => 'hooligan' ); },
#      qr/4 parameters were passed.+but 2 were expected/ );
#like( exception { App::Dochazka::REST::Model::Activity->_load( 'hooligan' ); },
#      qr/not listed in the validation options: App::Dochazka::REST::Model::Activity/ );
#like( exception { App::Dochazka::REST::Model::Activity::_load( ( 1..2 ) ); },
#      qr/not listed in the validation options/ );
#like( exception { App::Dochazka::REST::Model::Activity::_load( 'hooligan' => 'sneaking in' ); },
#      qr/not listed in the validation options: hooligan/ );

# test existence of initial set of activities
foreach my $actdef ( @{ $site->DOCHAZKA_ACTIVITY_DEFINITIONS } ) {
    $act->reset(
        code => $actdef->{code},
        long_desc => $actdef->{long_desc},
        remark => $actdef->{remark},
    );  
    $act2->reset;
    $status = $act->load_by_code( $actdef->{code} );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    $act = $status->payload;
    is( $act->code, $actdef->{code} );
    is( $act->long_desc, $actdef->{long_desc} );
    is( $act->remark, 'dbinit' );
    $status = $act2->load_by_aid( $act->aid );
    ok( $status->ok );
}

# test some bad parameters
like( exception { $act2->load_by_aid( undef ) }, 
      qr/not one of the allowed types/ );
like( exception { $act2->load_by_code( undef ) }, 
      qr/not one of the allowed types/ );
like( exception { App::Dochazka::REST::Model::Activity->load_by_aid( undef ) }, 
      qr/not one of the allowed types/ );
like( exception { App::Dochazka::REST::Model::Activity->load_by_code( undef ) }, 
      qr/not one of the allowed types/ );

# load the work activity
$status = App::Dochazka::REST::Model::Activity->load_by_code( 'wOrK' );
ok( $status->ok );
my $work = $status->payload;
ok( $work->aid > 0 );
is( $work->code, 'WORK' );

# get AID of 'WORK' using 'aid_by_code'
my $work_aid = aid_by_code( 'WoRk' );
is( $work_aid, $work->aid );
like ( exception { $work_aid = aid_by_code( ( 1..6 ) ); },
       qr/but 1 was expected/ );

# insert a bogus activity
my $bogus_act = App::Dochazka::REST::Model::Activity->spawn(
    code => 'boguS',
    long_desc => 'An activity',
    remark => 'ACTIVITY',
);
$status = $bogus_act->insert;
diag( $status->text ) unless $status->ok;
ok( $status->ok );
ok( defined( $bogus_act->aid ) );
ok( $bogus_act->aid > 0 );
# test code accessor method and code_to_upper trigger
is( $bogus_act->code, 'BOGUS' );
is( $bogus_act->long_desc, "An activity" );
is( $bogus_act->remark, 'ACTIVITY' );

# try to insert the bogus activity again
$status = $bogus_act->insert;
ok( $status->not_ok );

# update the bogus activity
$bogus_act->{code} = "bogosITYVille";
$bogus_act->{long_desc} = "A bogus activity that doesn't belong here";
$bogus_act->{remark} = "BOGUS ACTIVITY";
$status = $bogus_act->update;
ok( $status->ok );
# test accessors
is( $bogus_act->code, 'BOGOSITYVILLE' );
is( $bogus_act->long_desc, "A bogus activity that doesn't belong here" );
is( $bogus_act->remark, 'BOGUS ACTIVITY' );

# load it and compare it
my $ba2 = App::Dochazka::REST::Model::Activity->spawn;
ok( blessed( $ba2 ) );
$status = $ba2->load_by_code( $bogus_act->code );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
$ba2 = $status->payload;
is( $ba2->code, 'BOGOSITYVILLE' );
is( $ba2->long_desc, "A bogus activity that doesn't belong here" );
is( $ba2->remark, 'BOGUS ACTIVITY' );

# CLEANUP: delete the bogus activity
$status = $bogus_act->delete;
ok( $status->ok );

# attempt to load the bogus activity
$bogus_act->reset;
$status = $bogus_act->load_by_code( 'BOGUS' );
ok( $status->code, 'DISPATCH_NO_RECORDS_FOUND' );
is( $status->{'count'}, 0 );

done_testing;
