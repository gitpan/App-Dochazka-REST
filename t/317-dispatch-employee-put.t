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

# 1. 'employee/help' - list employee PUT resources available to passersby
$res = $test->request( req_json_demo PUT => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );

# 1. 'employee/help' - list employee PUT resources available to admins
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

# 2. 'employee/nick' - add a new employee with nick in request body
$res = $test->request( req_json_demo POST => '/employee/nick', undef, '{' );
is( $res->code, 400 ); # malformed
$res = $test->request( req_json_demo POST => '/employee/nick', undef, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root POST => '/employee/nick', undef, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
my $mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
my $mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrfu->eid, 
    nick => 'mrfu', fullname => 'Dragon Scale' );
is_deeply( $mrfu, $mrfuprime );
my $eid_of_mrfu = $mrfu->eid;

# 2. 'employee/nick' - update existing employee
$res = $test->request( req_json_demo POST => '/employee/nick', undef, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale Update", "email" : "mrfu@dragon.org" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root POST => '/employee/nick', undef, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale Update", "email" : "mrfu@dragon.org" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
$mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_mrfu,
    nick => 'mrfu', fullname => 'Dragon Scale Update', email => 'mrfu@dragon.org' );
is_deeply( $mrfu, $mrfuprime );

# 3. 'employee/nick/:nick' - add new employee
$res = $test->request( req_json_demo PUT => '/employee/nick/brotherchen', undef, '{' );
is( $res->code, 400 ); # malformed
$res = $test->request( req_json_demo PUT => '/employee/nick/brotherchen', undef, 
    '{ "nick":"brotherchen", "fullname":"Anders Chen" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root PUT => '/employee/nick/brotherchen', undef, 
    '{ "nick":"brotherchen", "fullname":"Anders Chen" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
my $brchen = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
my $brchenprime = App::Dochazka::REST::Model::Employee->spawn( eid => $brchen->eid, 
    nick => 'brotherchen', fullname => 'Anders Chen' );
is_deeply( $brchen, $brchenprime );
my $eid_of_brchen = $brchen->eid;

# 3. 'employee/nick/:nick' - update existing employee
$res = $test->request( req_json_demo PUT => '/employee/nick/brotherchen', undef, '{' );
is( $res->code, 400 ); # malformed
$res = $test->request( req_json_demo PUT => '/employee/nick/brotherchen', undef, 
    '{ "fullname":"Chen Update" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root PUT => '/employee/nick/brotherchen', undef, 
    '{ "eid": 534, "fullname":"Chen Update" }' );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$brchen = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
$brchenprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_brchen,
    nick => 'brotherchen', fullname => 'Chen Update' );
is_deeply( $brchen, $brchenprime );

# 4. 'employee/eid' - update existing employee
$res = $test->request( req_json_demo PUT => "/employee/eid/$eid_of_brchen", undef, 
    '{ "eid": ' . $eid_of_brchen . ', "fullname":"Chen Update Again" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root PUT => "/employee/eid/$eid_of_brchen", undef, 
    '{ "eid": ' . $eid_of_brchen . ', "fullname":"Chen Update Again" }' );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$brchen = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
$brchenprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_brchen,
    nick => 'brotherchen', fullname => 'Chen Update Again' );
is_deeply( $brchen, $brchenprime );

# 5. 'employee/eid/:eid' - update existing employee
$res = $test->request( req_json_demo PUT => "/employee/eid/$eid_of_mrfu", undef, '{' );
is( $res->code, 400 ); # malformed
$res = $test->request( req_json_demo PUT => "/employee/eid/$eid_of_mrfu", undef, 
    '{ "nick": "mrfu", "fullname":"Lizard Scale" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root PUT => "/employee/eid/$eid_of_mrfu", undef, 
    '{ "eid": 534, "nick": "mrfu", "fullname":"Lizard Scale" }' );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
$mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_mrfu,
    nick => 'mrfu', fullname => 'Lizard Scale', email => 'mrfu@dragon.org' );
is_deeply( $mrfu, $mrfuprime );

# 5. 'employee/eid/:eid' - update non-existent
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

done_testing;
