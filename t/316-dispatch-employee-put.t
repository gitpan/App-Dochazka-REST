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
# test path dispatch
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $log $meta $site );
use App::Dochazka::REST;
use App::Dochazka::REST::Model::Employee;
use App::Dochazka::REST::Test qw( req_json_demo req_json_root status_from_json );
use Data::Dumper;
use JSON;
use Plack::Test;
use Scalar::Util qw( blessed );
use Test::JSON;
use Test::More;

# initialize, connect to database, and set up a testing plan
my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka-rest' );
my $status = $REST->{init_status};
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}
my $app = $REST->{'app'};
$meta->set( 'META_DOCHAZKA_UNIT_TESTING' => 1 );

# instantiate Plack::Test object
my $test = Plack::Test->create( $app );
ok( blessed $test );

my $res;
my @to_be_deleted;

# create a testing employee by cheating a little
my $emp = App::Dochazka::REST::Model::Employee->spawn(
    nick => 'brotherchen',
    email => 'goodbrother@orient.cn',
    fullname => 'Good Brother Chen',
);
ok( blessed( $emp ) );
$status = $emp->insert;
ok( $status->ok, "Brother Chen inserted" );
my $eid_of_brchen = $emp->{eid};
is( $eid_of_brchen, $emp->eid );
push @to_be_deleted, $eid_of_brchen;

# PUT 'employee/eid/:eid' - insufficient priv
$res = $test->request( req_json_demo PUT => "/employee/eid/$eid_of_brchen", undef, 
    '{ "eid": ' . $eid_of_brchen . ', "fullname":"Chen Update Again" }' );
is( $res->code, 403 ); # forbidden

# PUT 'employee/eid/:eid' and be nice about it
$res = $test->request( req_json_demo PUT => "/employee/eid/$eid_of_brchen", undef, 
    '{ "fullname":"Chen Update Again", "salt":"tasty" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root PUT => "/employee/eid/$eid_of_brchen", undef, 
    '{ "fullname":"Chen Update Again", "salt":"tasty" }' );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
my $brchen = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $brchen->eid, $eid_of_brchen );
my $brchenprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_brchen,
    nick => 'brotherchen', email => 'goodbrother@orient.cn', fullname =>
    'Chen Update Again', salt => 'tasty' );
is_deeply( $brchen, $brchenprime );

# PUT 'employee/eid/:eid' and be pathological
# - provide invalid EID in request body
$res = $test->request( req_json_root PUT => "/employee/eid/$eid_of_brchen", undef, 
    '{ "eid": 99999, "fullname":"Chen Update Again" }' );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$brchen = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
isnt( $brchen->eid, 99999 );
is( $brchen->eid, $eid_of_brchen );
$brchenprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_brchen,
    nick => 'brotherchen', email => 'goodbrother@orient.cn', fullname =>
    'Chen Update Again', salt => 'tasty' );
is_deeply( $brchen, $brchenprime );

# - change the nick
$res = $test->request( req_json_demo PUT => "/employee/eid/$eid_of_brchen", undef, '{' );
is( $res->code, 400 ); # malformed
$res = $test->request( req_json_demo PUT => "/employee/eid/$eid_of_brchen", undef, 
    '{ "nick": "mrfu", "fullname":"Lizard Scale" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root PUT => "/employee/eid/$eid_of_brchen", undef, 
    '{ "nick": "mrfu", "fullname":"Lizard Scale", "email":"mrfu@dragon.cn" }' );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
my $mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
isnt( $mrfu->nick, 'brotherchen' );
is( $mrfu->nick, 'mrfu' );
my $mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_brchen,
    nick => 'mrfu', fullname => 'Lizard Scale', email => 'mrfu@dragon.cn',
    salt => 'tasty' );
is_deeply( $mrfu, $mrfuprime );
my $eid_of_mrfu = $mrfu->eid;
is( $eid_of_mrfu, $eid_of_brchen );

# - provide non-existent EID
$res = $test->request( req_json_demo PUT => "/employee/eid/5633", undef, '{' );
is( $res->code, 400 ); # malformed
$res = $test->request( req_json_demo PUT => "/employee/eid/5633", undef, 
    '{ "nick": "mrfu", "fullname":"Lizard Scale" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root PUT => "/employee/eid/5633", undef, 
    '{ "eid": 534, "nick": "mrfu", "fullname":"Lizard Scale" }' );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EID_DOES_NOT_EXIST' );

# 'employee/help' - list employee PUT resources available to passersby
$res = $test->request( req_json_demo PUT => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );

# 'employee/help' - list employee PUT resources available to admins
$res = $test->request( req_json_root PUT => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 3 );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
ok( exists $status->payload->{'resources'}->{'employee/nick/:nick'} );

# 'employee/nick/:nick' - insert and be nice
$res = $test->request( req_json_demo PUT => '/employee/nick/mrsfu', undef, '{' );
is( $res->code, 400 ); # malformed
$res = $test->request( req_json_demo PUT => '/employee/nick/mrsfu', undef, 
    '{ "fullname":"Dragonness" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root PUT => '/employee/nick/mrsfu', undef, 
    '{ "fullname":"Dragonness" }' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
my $mrsfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
my $mrsfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrsfu->eid, 
    nick => 'mrsfu', fullname => 'Dragonness' );
is_deeply( $mrsfu, $mrsfuprime );
push @to_be_deleted, $mrsfu->eid;

# 'employee/nick/:nick' - insert and be pathological
# - provide conflicting 'nick' property in the content body
$res = $test->request( req_json_demo PUT => '/employee/nick/hapless', undef, '{' );
is( $res->code, 400 ); # malformed
$res = $test->request( req_json_demo PUT => '/employee/nick/hapless', undef, 
    '{ "nick":"INVALID", "fullname":"Anders Chen" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root PUT => '/employee/nick/hapless', undef, 
    '{ "nick":"INVALID", "fullname":"Anders Chen" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
my $hapless = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
isnt( $hapless->nick, 'INVALID' );
is( $hapless->nick, 'hapless' );
my $haplessprime = App::Dochazka::REST::Model::Employee->spawn( eid => $hapless->eid, 
    nick => 'hapless', fullname => 'Anders Chen' );
is_deeply( $hapless, $haplessprime );
my $eid_of_hapless = $hapless->eid;
push @to_be_deleted, $eid_of_hapless;

# 'employee/nick/:nick' - update and be nice
$res = $test->request( req_json_root PUT => '/employee/nick/hapless', undef, 
    '{ "fullname":"Chen Update", "salt":"none, please" }' );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$hapless = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $hapless->nick, "hapless" );
is( $hapless->fullname, "Chen Update" );
is( $hapless->salt, "none, please" );
$haplessprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_hapless,
    nick => 'hapless', fullname => 'Chen Update', salt => "none, please" );
is_deeply( $hapless, $haplessprime );

# 'employee/nick/:nick' - update and be nice and also change salt to null
$res = $test->request( req_json_root PUT => '/employee/nick/hapless', undef, 
    '{ "fullname":"Chen Update", "salt":null }' );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$hapless = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $hapless->nick, "hapless" );
is( $hapless->fullname, "Chen Update" );
is( $hapless->salt, undef );
$haplessprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_hapless,
    nick => 'hapless', fullname => 'Chen Update' );
is_deeply( $hapless, $haplessprime );

# 'employee/nick/:nick' - update and be pathological
# - attempt to set a bogus EID
$res = $test->request( req_json_root PUT => '/employee/nick/hapless', undef, 
    '{ "eid": 534, "fullname":"Good Brother Chen", "salt":"" }' );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$hapless = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $hapless->fullname, "Good Brother Chen" );
is( $hapless->eid, $eid_of_hapless );
isnt( $hapless->eid, 534 );
$haplessprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_hapless,
    nick => 'hapless', fullname => 'Good Brother Chen' );
is_deeply( $hapless, $haplessprime );

# - pathologically attempt to change nick to null
$res = $test->request( req_json_root PUT => '/employee/nick/hapless', undef, 
    '{ "nick":null }' );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/violates not-null constraint/ );

# delete what we created
foreach my $eid ( @to_be_deleted ) {
    $status = App::Dochazka::REST::Model::Employee->load_by_eid( $eid );
    ok( $status->ok );
    $status = $status->payload->delete;
    ok( $status->ok );
}

done_testing;
