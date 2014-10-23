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

# POST 'employee'
$log->notice("--- POST employee");
$res = $test->request( req_json_demo POST => '/employee' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
#ok( exists $status->payload->{'resources'}->{'employee/help'} );

# create a 'mrfu' employee - insufficient privileges
$res = $test->request( req_json_demo PUT => '/employee/nick/mrfu' );
is( $res->code, 403 );

# create a 'mrfu' employee
$res = $test->request( req_json_root PUT => '/employee/nick/mrfu' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->payload->{eid} > 1 );
is( $status->payload->{nick}, 'mrfu' );

# get 'mrfu' employee object by cheating
$status = App::Dochazka::REST::Model::Employee->load_by_nick('mrfu');
ok( $status->ok );
my $mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );

# POST 'employee/eid' - give Mr. Fu a sex change
$log->notice("--- POST employee/eid (update with different nick)");
$res = $test->request( req_json_demo POST => '/employee/eid', undef, 
    '{ "eid": ' . $mrfu->eid . ', "nick" : "mrsfu" , "fullname":"Dragoness" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root POST => '/employee/eid', undef, 
    '{ "eid": ' . $mrfu->eid . ', "nick" : "mrsfu" , "fullname":"Dragoness" }' );
is( $res->code, 200 );
is_valid_json( $res->content, Dumper( $res->content ) );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
my $mrsfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
my $mrsfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrfu->eid,
    nick => 'mrsfu', fullname => 'Dragoness' );
is_deeply( $mrsfu, $mrsfuprime );

# POST 'employee/eid' - update non-existent
$log->notice("--- POST employee/eid (non-existent EID)");
$res = $test->request( req_json_demo POST => "/employee/eid", undef, '{ "eid" : 5442' );
is( $res->code, 400 ); # malformed
$res = $test->request( req_json_demo POST => "/employee/eid", undef, '{ "eid" : 5442 }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root PUT => "/employee/eid", undef, 
    '{ "eid": 534, "nick": "mrfu", "fullname":"Lizard Scale" }' );
is( $res->code, 405 ); # method not allowed
$res = $test->request( req_json_root POST => "/employee/eid", undef, 
    '{ "eid": 534, "nick": "mrfu", "fullname":"Lizard Scale" }' );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EID_DOES_NOT_EXIST' );

# POST 'employee/help' - the same as 1.
$log->notice("--- POST employee/help");
$res = $test->request( req_json_demo POST => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
#ok( exists $status->payload->{'resources'}->{'employee/help'} );

# POST 'employee/nick' - add a new employee with nick in request body
$log->notice("--- POST employee/nick (insert)");
$res = $test->request( req_json_demo POST => '/employee/nick', undef, '{' );
is( $res->code, 400 ); # malformed
$res = $test->request( req_json_demo POST => '/employee/nick', undef, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root POST => '/employee/nick', undef, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale", "email":"mrfu@dragon.cn" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
$mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
my $mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrfu->eid, 
    nick => 'mrfu', fullname => 'Dragon Scale', email => 'mrfu@dragon.cn' );
is_deeply( $mrfu, $mrfuprime );
my $eid_of_mrfu = $mrfu->eid;

# POST 'employee/nick' - update existing employee
$log->notice("--- POST employee/nick (update)");
$res = $test->request( req_json_demo POST => '/employee/nick', undef, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale Update", "email" : "scale@dragon.org" }' );
is( $res->code, 403 ); # forbidden
$res = $test->request( req_json_root POST => '/employee/nick', undef, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale Update", "email" : "scale@dragon.org" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
$mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_mrfu,
    nick => 'mrfu', fullname => 'Dragon Scale Update', email => 'scale@dragon.org' );
is_deeply( $mrfu, $mrfuprime );

done_testing;
