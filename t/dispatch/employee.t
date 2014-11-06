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
# test employee resources
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

use App::CELL qw( $log $meta $site );
use App::Dochazka::REST;
use App::Dochazka::REST::Test;
use Data::Dumper;
use JSON;
use Plack::Test;
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

my $res;


#=============================
# "employee/count" resource
#=============================
my $base = 'employee/count';
docu_check($test, $base);
#
# GET employee/count
#
$res = $test->request( req_root GET => $base );
is( $res->code, 200, "GET $base 1" );
$status = status_from_json( $res->content );
ok( $status->ok, "GET $base 2" );
is( $status->code, 'DISPATCH_COUNT_EMPLOYEES', "GET $base 3" );
#
$res = $test->request( req_demo GET => '/employee/count' );
is( $res->code, 403, "GET $base 4" );

#
# PUT, POST, DELETE
#
$res = $test->request( req_json_demo PUT => $base );
is( $res->code, 405, "PUT $base 1" );
$res = $test->request( req_json_root PUT => $base );
is( $res->code, 405, "PUT $base 2" );
$res = $test->request( req_json_demo POST => $base );
is( $res->code, 405, "POST $base 1" );
$res = $test->request( req_json_root POST => $base );
is( $res->code, 405, "POST $base 2" );
$res = $test->request( req_json_demo DELETE => $base );
is( $res->code, 405, "DELETE $base 1" );
$res = $test->request( req_json_root DELETE => $base );
is( $res->code, 405, "DELETE $base 2" );


#=============================
# "employee/count/:priv" resource
#=============================
$base = "employee/count";
docu_check($test, "$base/:priv" );
#
# GET employee/count/admin
#
$res = $test->request( req_root GET => "$base/admin" );
is( $res->code, 200, "GET $base/:priv 1" );
$status = status_from_json( $res->content );
ok( $status->ok, "GET $base/:priv 2" );
is( $status->code, 'DISPATCH_COUNT_EMPLOYEES', "GET $base/:priv 3" );
ok( defined $status->payload, "GET $base/:priv 4" );
ok( exists $status->payload->{'priv'}, "GET $base/:priv 5" );
is( $status->payload->{'priv'}, 'admin', "GET $base/:priv 6" );
is( $status->payload->{'count'}, 1, "GET $base/:priv 7" );
#
$res = $test->request( req_demo GET => '/employee/count/admin' );
is( $res->code, 403, "GET $base/:priv 8" );

#
# PUT, POST, DELETE
#
$res = $test->request( req_json_demo PUT => '/employee/count/admin' );
is( $res->code, 405, "PUT $base/:priv 1" );
$res = $test->request( req_json_root PUT => '/employee/count/admin' );
is( $res->code, 405, "PUT $base/:priv 2" );
$res = $test->request( req_json_demo POST => '/employee/count/admin' );
is( $res->code, 405, "POST $base/:priv 1" );
$res = $test->request( req_json_root POST => '/employee/count/admin' );
is( $res->code, 405, "POST $base/:priv 2" );
$res = $test->request( req_json_demo DELETE => '/employee/count/admin' );
is( $res->code, 405, "DELETE $base/:priv 1" );
$res = $test->request( req_json_root DELETE => '/employee/count/admin' );
is( $res->code, 405, "DELETE $base/:priv 2" );


#=============================
# "employee/current" resource
#=============================
$base = "employee/current";
docu_check($test, $base);
#
# GET employee/current
#
$res = $test->request( req_demo GET => $base );
is( $res->code, 200, "GET $base 1" );
$status = status_from_json( $res->content );
ok( $status->ok, "GET $base 2" );
is( $status->code, 'DISPATCH_EMPLOYEE_CURRENT', "GET $base 3" );
ok( defined $status->payload, "GET $base 4" );
is_deeply( $status->payload, {
    'fullname' => 'Demo Employee',
    'eid' => 2,
    'remark' => 'dbinit',
    'email' => 'demo@dochazka.site',
    'nick' => 'demo',
    'salt' => undef,
    'passhash' => 'demo'
}, "GET $base 5");
#
$res = $test->request( req_root GET => $base );
is( $res->code, 200, "GET $base 6" );
$status = status_from_json( $res->content );
ok( $status->ok, "GET $base 7" );
is( $status->code, 'DISPATCH_EMPLOYEE_CURRENT', "GET $base 8" );
ok( defined $status->payload, "GET $base 9" );
is_deeply( $status->payload, {
    'eid' => 1,
    'nick' => 'root',
    'passhash' => 'immutable',
    'salt' => undef,
    'fullname' => 'Root Immutable',
    'email' => 'root@site.org',
    'remark' => 'dbinit' 
}, "GET $base 10" );

#
# PUT, POST, DELETE
#
$res = $test->request( req_json_demo PUT => $base );
is( $res->code, 405, "PUT $base 1" );
$res = $test->request( req_json_root PUT => $base );
is( $res->code, 405, "PUT $base 2" );
$res = $test->request( req_json_demo POST => $base );
is( $res->code, 405, "POST $base 1" );
$res = $test->request( req_json_root POST => $base );
is( $res->code, 405, "POST $base 2" );
$res = $test->request( req_json_demo DELETE => $base );
is( $res->code, 405, "DELETE $base 1" );
$res = $test->request( req_json_root DELETE => $base );
is( $res->code, 405, "DELETE $base 2" );


#=============================
# "employee/current/priv" resource
#=============================
docu_check($test, "employee/current/priv");
#
# GET employee/current/priv
#
$res = $test->request( req_demo GET => 'employee/current/priv' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
ok( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'priv'} );
ok( exists $status->payload->{'current_emp'} );
is( $status->payload->{'current_emp'}->{'nick'}, 'demo' );
is( $status->payload->{'priv'}, 'passerby' );
#
$res = $test->request( req_root GET => 'employee/current/priv' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
ok( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'priv'} );
ok( exists $status->payload->{'current_emp'} );
is( $status->payload->{'current_emp'}->{'nick'}, 'root' );
is( $status->payload->{'priv'}, 'admin' );

#
# PUT, POST, DELETE
#
$res = $test->request( req_json_demo PUT => 'employee/current/priv' );
is( $res->code, 405 );
$res = $test->request( req_json_root PUT => 'employee/current/priv' );
is( $res->code, 405 );
$res = $test->request( req_json_demo POST => 'employee/current/priv' );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => 'employee/current/priv' );
is( $res->code, 405 );
$res = $test->request( req_json_demo DELETE => 'employee/current/priv' );
is( $res->code, 405 );
$res = $test->request( req_json_root DELETE => 'employee/current/priv' );
is( $res->code, 405 );


#=============================
# "employee/eid" resource
#=============================
docu_check($test, "employee/eid");
#
# GET, PUT employee/eid
#
$res = $test->request( req_json_demo GET => '/employee/eid' );
is( $res->code, 405, 'employee/eid 1' );
$res = $test->request( req_json_root GET => '/employee/eid' );
is( $res->code, 405, 'employee/eid 2' );
$res = $test->request( req_json_demo PUT => '/employee/eid' );
is( $res->code, 405, 'employee/eid 3' );
$res = $test->request( req_json_root PUT => '/employee/eid' );
is( $res->code, 405, 'employee/eid 4' );

#
# POST employee/eid
#
# - create a 'mrfu' employee
my $mrfu = create_testing_employee( nick => 'mrfu' );
my $eid_of_mrfu = $mrfu->eid;
#
# - give Mr. Fu an email address
#diag("--- POST employee/eid (update email)");
$res = $test->request( req_json_demo POST => '/employee/eid', undef, 
    '{ "eid": ' . $mrfu->eid . ', "email" : "mrsfu@dragon.cn" }' );
is( $res->code, 403, 'POST employee/eid 1' );
#
$res = $test->request( req_json_root POST => '/employee/eid', undef, 
    '{ "eid": ' . $mrfu->eid . ', "email" : "mrsfu@dragon.cn" }' );
is_valid_json( $res->content, 'POST employee/eid 2' );
$status = status_from_json( $res->content );
is( $status->level, "OK", 'POST employee/eid 3' );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK', 'POST employee/eid 4' );
is( $status->payload->{'email'}, 'mrsfu@dragon.cn', 'POST employee/eid 5' );
#
# - update to a different nick
#diag("--- POST employee/eid (update with different nick)");
$res = $test->request( req_json_demo POST => '/employee/eid', undef, 
    '{ "eid": ' . $mrfu->eid . ', "nick" : "mrsfu" , "fullname":"Dragoness" }' );
is( $res->code, 403, 'POST employee/eid 6' ); # forbidden
$res = $test->request( req_json_root POST => '/employee/eid', undef, 
    '{ "eid": ' . $mrfu->eid . ', "nick" : "mrsfu" , "fullname":"Dragoness" }' );
is( $res->code, 200, 'POST employee/eid 7' );
is_valid_json( $res->content, 'POST employee/eid 7 and a half' );
$status = status_from_json( $res->content );
ok( $status->ok, 'POST employee/eid 8' );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK', 'POST employee/eid 9' );
my $mrsfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
my $mrsfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrfu->eid,
    nick => 'mrsfu', fullname => 'Dragoness', email => 'mrsfu@dragon.cn' );
is_deeply( $mrsfu, $mrsfuprime, 'POST employee/eid 10' );
#
# - update a non-existent EID
#diag("--- POST employee/eid (non-existent EID)");
$res = $test->request( req_json_demo POST => "/employee/eid", undef, '{ "eid" : 5442' );
is( $res->code, 400, 'POST employee/eid 11' ); # malformed
$res = $test->request( req_json_demo POST => "/employee/eid", undef, '{ "eid" : 5442 }' );
is( $res->code, 403, 'POST employee/eid 12' ); # forbidden
$res = $test->request( req_json_root PUT => "/employee/eid", undef, 
    '{ "eid": 534, "nick": "mrfu", "fullname":"Lizard Scale" }' );
is( $res->code, 405, 'POST employee/eid 13' ); # method not allowed
$res = $test->request( req_json_root POST => "/employee/eid", undef, 
    '{ "eid": 534, "nick": "mrfu", "fullname":"Lizard Scale" }' );
is_valid_json( $res->content, 'POST employee/eid 14' );
$status = status_from_json( $res->content );
ok( $status->not_ok, 'POST employee/eid 15' );
is( $status->level, 'ERR', 'POST employee/eid 16' );
is( $status->code, 'DISPATCH_EID_DOES_NOT_EXIST', 'POST employee/eid 17' );
#
# - missing EID
$res = $test->request( req_json_root POST => "/employee/eid", undef, '{ "long-john": "silber" }' );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PARAMETER_BAD_OR_MISSING' );
#
# - incorrigibly attempt to update totally bogus and invalid EIDs
$res = $test->request( req_json_root POST => "/employee/eid", undef,
    '{ "eid" : }' );
is( $res->code, 400 );
$res = $test->request( req_json_root POST => "/employee/eid", undef,
    '{ "eid" : jj }' );
is( $res->code, 400 );
$res = $test->request( req_json_root POST => "/employee/eid", undef,
    '{ "eid" : "jj" }' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, "ERR" );
is( $status->code, "DISPATCH_PARAMETER_BAD_OR_MISSING" );
#
# - and give it a bogus parameter (on update, bogus parameters cause REST to
#   return DOCHAZKA_BAD_INPUT; on insert, they are ignored)
$res = $test->request( req_json_root POST => "/employee/eid", undef, '{ "eid" :
2, "bogus" : "json" }' ); is( $res->code, 200 ); is_valid_json( $res->content
); $status = status_from_json( $res->content ); is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_BAD_INPUT' );
#
# - update to existing nick
$res = $test->request( req_json_root POST => '/employee/eid', undef, 
    '{ "eid": ' . $mrfu->eid . ', "nick" : "root" , "fullname":"Tom Wang" }' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, "ERR" );
is( $status->code, "DOCHAZKA_DBI_ERR" );

# delete the testing user
delete_testing_employee( $eid_of_mrfu );

#
# DELETE employee/eid
#
$res = $test->request( req_json_demo DELETE => '/employee/eid' );
is( $res->code, 405 );
$res = $test->request( req_json_root DELETE => '/employee/eid' );
is( $res->code, 405 );


#=============================
# "employee/eid/:eid" resource
#=============================
docu_check($test, "employee/eid/:eid");

#
# GET employee/eid/:eid
#
# - with EID == 1
$res = $test->request( req_root GET => '/employee/eid/' . $site->DOCHAZKA_EID_OF_ROOT );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'root' );
ok( exists $status->payload->{'fullname'} );
is( $status->payload->{'fullname'}, 'Root Immutable' );
#
# - with EID == 2 (demo)
$res = $test->request( req_root GET => "/employee/eid/2" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, 2 );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'demo' );
ok( exists $status->payload->{'fullname'} );
is( $status->payload->{'fullname'}, 'Demo Employee' );
# 
$res = $test->request( req_demo GET => "/employee/eid/2" );
is( $res->code, 403 );
#
$res = $test->request( req_root GET => '/employee/eid/53432' );
is( $res->code, 404 );
#
$res = $test->request( req_demo GET => "/employee/eid/53432" );
is( $res->code, 403 );


#
# PUT employee/eid/:eid
#
# create a testing employee by cheating a little
my $emp = create_testing_employee(
    nick => 'brotherchen',
    email => 'goodbrother@orient.cn',
    fullname => 'Good Brother Chen',
);
my $eid_of_brchen = $emp->{eid};
is( $eid_of_brchen, $emp->eid );
#
# - insufficient priv
$res = $test->request( req_json_demo PUT => "/employee/eid/$eid_of_brchen", undef, 
    '{ "eid": ' . $eid_of_brchen . ', "fullname":"Chen Update Again" }' );
is( $res->code, 403 ); # forbidden
#
# - be nice
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
# 
# - provide invalid EID in request body
$res = $test->request( req_json_root PUT => "/employee/eid/$eid_of_brchen", undef, 
    '{ "eid": 99999, "fullname":"Chen Update Again 2" }' );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$brchen = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
isnt( $brchen->eid, 99999 );
is( $brchen->eid, $eid_of_brchen );
$brchenprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_brchen,
    nick => 'brotherchen', email => 'goodbrother@orient.cn', fullname =>
    'Chen Update Again 2', salt => 'tasty' );
is_deeply( $brchen, $brchenprime );
#
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
$mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
isnt( $mrfu->nick, 'brotherchen' );
is( $mrfu->nick, 'mrfu' );
my $mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_brchen,
    nick => 'mrfu', fullname => 'Lizard Scale', email => 'mrfu@dragon.cn',
    salt => 'tasty' );
is_deeply( $mrfu, $mrfuprime );
$eid_of_mrfu = $mrfu->eid;
is( $eid_of_mrfu, $eid_of_brchen );
#
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
#
# - with valid JSON that is not what we are expecting
$res = $test->request( req_json_root PUT => "/employee/eid/2", undef, '0' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_BAD_INPUT' );
#
# - another kind of bogus JSON
$res = $test->request( req_json_root PUT => "/employee/eid/2", undef, '{ "legal" : "json" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_BAD_INPUT' );

#
# delete the testing user
delete_testing_employee( $eid_of_brchen );

#
# POST employee/eid/:eid
#
$res = $test->request( req_json_demo POST => '/employee/eid/:eid' );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => '/employee/eid/:eid' );
is( $res->code, 405 );

#
# DELETE employee/eid/:eid
#
# create a "cannon fodder" employee
my $cf = create_testing_employee( nick => 'cannonfodder' );
my $eid_of_cf = $cf->eid;

# 'employee/eid/:eid' - delete cannonfodder
$res = $test->request( req_json_demo DELETE => '/employee/eid/' . $cf->eid );
is( $res->code, 403 );
$res = $test->request( req_json_root DELETE => '/employee/eid/' . $cf->eid );
is( $res->code, 200 );

# attempt to get cannonfodder - not there anymore
$res = $test->request( req_json_demo GET => "/employee/eid/$eid_of_cf" );
is( $res->code, 403 );
$res = $test->request( req_json_root GET => "/employee/eid/$eid_of_cf" );
is( $res->code, 404 );

# create another "cannon fodder" employee
$cf = create_testing_employee( nick => 'cannonfodder' );
ok( $cf->eid > $eid_of_cf ); # EID will have incremented
$eid_of_cf = $cf->eid;

# delete the sucker
$res = $test->request( req_json_demo DELETE => '/employee/nick/cannonfodder' );
is( $res->code, 403 );
$res = $test->request( req_json_root DELETE => '/employee/nick/cannonfodder' );
is( $res->code, 200 );

# attempt to get cannonfodder - not there anymore
$res = $test->request( req_json_demo GET => "/employee/eid/$eid_of_cf" );
is( $res->code, 403 );
$res = $test->request( req_json_root GET => "/employee/eid/$eid_of_cf" );
is( $res->code, 404 );

# attempt to delete 'root the immutable' (won't work)
$res = $test->request( req_json_root DELETE => '/employee/eid/1' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, "DOCHAZKA_DBI_ERR" );
like( $status->text, qr/immutable/i );


#=============================
# "employee/help" resource
#=============================
docu_check($test, "employee/help");
#
# GET
#
$res = $test->request( req_demo GET => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 2 );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
#
$res = $test->request( req_root GET => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 6 );
ok( exists $status->payload->{'resources'}->{'employee/help'} );

#
# PUT
#
$res = $test->request( req_json_demo PUT => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# 
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

#
# POST
#
$res = $test->request( req_json_demo POST => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
#ok( exists $status->payload->{'resources'}->{'employee/help'} );

#
# DELETE
#
$res = $test->request( req_json_demo DELETE => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
#
$res = $test->request( req_json_root DELETE => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );


#=============================
# "employee/nick" resource
#=============================
docu_check($test, "employee/nick");
#
# GET, PUT employee/nick
#
$res = $test->request( req_json_demo GET => '/employee/nick' );
is( $res->code, 405 );
$res = $test->request( req_json_root GET => '/employee/nick' );
is( $res->code, 405 );
$res = $test->request( req_json_demo PUT => '/employee/nick' );
is( $res->code, 405 );
$res = $test->request( req_json_root PUT => '/employee/nick' );
is( $res->code, 405 );

#
# POST employee/nick
#
# - create a 'mrfu' employee
$mrfu = create_testing_employee( nick => 'mrfu' );
my $nick_of_mrfu = $mrfu->nick;
$eid_of_mrfu = $mrfu->eid;
#
# - give Mr. Fu an email address
#diag("--- POST employee/nick (update email)");
my $j = '{ "nick": "' . $nick_of_mrfu . '", "email" : "mrsfu@dragon.cn" }';
$res = $test->request( req_json_demo POST => '/employee/nick', undef, $j );
is( $res->code, 403 );
#
$res = $test->request( req_json_root POST => '/employee/nick', undef, $j );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, "OK" );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
is( $status->payload->{'email'}, 'mrsfu@dragon.cn' );
#
# - non-existent nick (insert new employee)
#diag("--- POST employee/nick (non-existent nick)");
$res = $test->request( req_json_demo POST => "/employee/nick", undef, 
    '{ "nick" : 5442' );
is( $res->code, 400 ); # malformed
$res = $test->request( req_json_demo POST => "/employee/nick", undef, 
    '{ "nick" : 5442 }' );
is( $res->code, 403 ); # forbidden
#
# - attempt to insert new employee with bogus "eid" property
$res = $test->request( req_json_root POST => "/employee/nick", undef, 
    '{ "eid": 534, "nick": "mrfutra", "fullname":"Rovnou do futer" }' );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
is( $status->payload->{'nick'}, 'mrfutra' );
is( $status->payload->{'fullname'}, 'Rovnou do futer' );
isnt( $status->payload->{'eid'}, 534 );
my $eid_of_mrfutra = $status->payload->{'eid'};
#
# delete the testing user
delete_testing_employee( $eid_of_mrfu );
delete_testing_employee( $eid_of_mrfutra );

# - add a new employee with nick in request body
#diag("--- POST employee/nick (insert)");
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
$mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrfu->eid, 
    nick => 'mrfu', fullname => 'Dragon Scale', email => 'mrfu@dragon.cn' );
is_deeply( $mrfu, $mrfuprime );
$eid_of_mrfu = $mrfu->eid;
#
# - and give it valid, yet bogus JSON (unknown nick - insert)
$res = $test->request( req_json_root POST => "/employee/nick", undef,
    '{ "nick" : "wombat", "bogus" : "json" }' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
my $eid_of_wombat = $status->payload->{'eid'};
#
# - and give it valid, yet bogus JSON (known nick - update)
$res = $test->request( req_json_root POST => "/employee/nick", undef,
    '{ "nick" : "wombat", "bogus" : "json" }' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, "ERR" );
is( $status->code, 'DOCHAZKA_BAD_INPUT' ); # after bogus param is eliminated, update has nothing to do
#
delete_testing_employee( $eid_of_wombat );


# - update existing employee
#diag("--- POST employee/nick (update)");
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
#
# - create a bogus user with a bogus property
$res = $test->request( req_json_root POST => '/employee/nick', undef, 
    '{ "nick":"bogus", "wago":"svorka", "fullname":"bogus user" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
my $eid_of_bogus = $status->payload->{'eid'};

map { delete_testing_employee( $_ ); } ( $eid_of_mrfu, $eid_of_bogus );

#
# DELETE employee/nick
#
$res = $test->request( req_json_demo DELETE => '/employee/nick' );
is( $res->code, 405 );
$res = $test->request( req_json_root DELETE => '/employee/nick' );
is( $res->code, 405 );


#=============================
# "employee/nick/:nick" resource
#=============================
docu_check($test, "employee/nick/:nick");
#
# GET employee/nick/:nick
#
# - with nick == 'root'
$res = $test->request( req_root GET => '/employee/nick/root' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'root' );
ok( exists $status->payload->{'fullname'} );
is( $status->payload->{'fullname'}, 'Root Immutable' );
#
# - with nick == 'demo'
$res = $test->request( req_root GET => "/employee/nick/demo" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, 2 );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'demo' );
ok( exists $status->payload->{'fullname'} );
is( $status->payload->{'fullname'}, 'Demo Employee' );
# 
$res = $test->request( req_demo GET => "/employee/nick/demo" );
is( $res->code, 403 );
#
$res = $test->request( req_root GET => '/employee/nick/53432' );
is( $res->code, 404 );
#
$res = $test->request( req_demo GET => "/employee/nick/53432" );
is( $res->code, 403 );
# 
$res = $test->request( req_root GET => '/employee/nick/heathledger' );
is( $res->code, 404 );
# 
# this one triggers "wide character in print" warnings
#$res = $test->request( req_root GET => uri_escape_utf8('/employee/nick//////áěěoěščqwšáščšýš..-...-...-..-.00') );
#is( $res->code, 404 );

# 
# PUT employee/nick/:nick
#
# - insert and be nice
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
$mrsfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
$mrsfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrsfu->eid, 
    nick => 'mrsfu', fullname => 'Dragonness' );
is_deeply( $mrsfu, $mrsfuprime );
my $eid_of_mrsfu = $mrsfu->eid;

# - insert and be pathological
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

# - update and be nice
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

# - update and be nice and also change salt to null
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

# - update and be pathological
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

# - feed it more bogusness
$res = $test->request( req_json_root PUT => "/employee/eid/2", undef, '{ "legal" : "json" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
# FIXME: WIP

# 
delete_testing_employee( $eid_of_mrsfu );
delete_testing_employee( $eid_of_hapless );

#
# POST employee/nick:nick
#
$res = $test->request( req_json_demo POST => '/employee/nick/:nick' );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => '/employee/nick/:nick' );
is( $res->code, 405 );

#
# DELETE employee/nick/:nick
#
# create a "cannon fodder" employee
$cf = create_testing_employee( nick => 'cannonfodder' );
ok( $cf->eid > 1 );
$eid_of_cf = $cf->eid;

# get cannonfodder - no problem
$res = $test->request( req_json_root GET => '/employee/nick/cannonfodder' );
is( $res->code, 200 );

# 'employee/nick/:nick' - delete cannonfodder
$res = $test->request( req_json_demo DELETE => '/employee/nick/' . $cf->nick );
is( $res->code, 403 );
$res = $test->request( req_json_root DELETE => '/employee/nick/' . $cf->nick );
is( $res->code, 200 );

# attempt to get cannonfodder - not there anymore
$res = $test->request( req_json_root GET => '/employee/nick/cannonfodder' );
is( $res->code, 404 );

# attempt to get in a different way
$status = App::Dochazka::REST::Model::Employee->load_by_nick( 'cannonfodder' );
ok( $status->ok );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND' );

# create another "cannon fodder" employee
$cf = create_testing_employee( nick => 'cannonfodder' );
ok( $cf->eid > $eid_of_cf ); # EID will have incremented
$eid_of_cf = $cf->eid;

# get cannonfodder - again, no problem
$res = $test->request( req_json_root GET => '/employee/nick/cannonfodder' );
is( $res->code, 200 );

# - delete with a typo
$res = $test->request( req_json_demo DELETE => '/employee/nick/cannonfoddertypo' );
is( $res->code, 403 );
$res = $test->request( req_json_root DELETE => '/employee/nick/cannonfoddertypo' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_NICK_DOES_NOT_EXIST' );

# attempt to get cannonfodder - still there
$res = $test->request( req_json_root GET => '/employee/nick/cannonfodder' );
is( $res->code, 200 );
delete_testing_employee( $eid_of_cf );

# attempt to delete 'root the immutable' (won't work)
$res = $test->request( req_json_root DELETE => '/employee/nick/root' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, "DOCHAZKA_DBI_ERR" );
like( $status->text, qr/immutable/i );

done_testing;
