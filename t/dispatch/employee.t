# ************************************************************************* # Copyright (c) 2014, SUSE LLC
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
# - fail 403 as demo
$status = req( $test, 403, 'demo', 'GET', $base );
#
# - succeed as root
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK', "GET $base 2" );
is( $status->code, 'DISPATCH_COUNT_EMPLOYEES', "GET $base 3" );

#
# PUT, POST, DELETE
#
# - fail 405 in all cases
$status = req( $test, 405, 'demo', 'PUT', $base );
$status = req( $test, 405, 'active', 'PUT', $base );
$status = req( $test, 405, 'WOMBAT', 'PUT', $base );
$status = req( $test, 405, 'root', 'PUT', $base );
$status = req( $test, 405, 'demo', 'POST', $base );
$status = req( $test, 405, 'active', 'POST', $base );
$status = req( $test, 405, 'root', 'POST', $base );
$status = req( $test, 405, 'demo', 'DELETE', $base );
$status = req( $test, 405, 'active', 'DELETE', $base );
$status = req( $test, 405, 'root', 'DELETE', $base );


#=============================
# "employee/count/:priv" resource
#=============================
$base = "employee/count";
docu_check($test, "$base/:priv" );
#
# GET employee/count/admin
#
$status = req( $test, 200, 'root', 'GET', "$base/admin" );
is( $status->level, "OK", "GET $base/:priv 2" );
is( $status->code, 'DISPATCH_COUNT_EMPLOYEES', "GET $base/:priv 3" );
ok( defined $status->payload, "GET $base/:priv 4" );
ok( exists $status->payload->{'priv'}, "GET $base/:priv 5" );
is( $status->payload->{'priv'}, 'admin', "GET $base/:priv 6" );
is( $status->payload->{'count'}, 1, "GET $base/:priv 7" );
#
req( $test, 403, 'demo', 'GET', '/employee/count/admin' );

#
# PUT, POST, DELETE
#
# - fail 405 in all cases
$base .= '/admin';
$status = req( $test, 405, 'demo', 'PUT', $base );
$status = req( $test, 405, 'active', 'PUT', $base );
$status = req( $test, 405, 'root', 'PUT', $base );
$status = req( $test, 405, 'demo', 'POST', $base );
$status = req( $test, 405, 'active', 'POST', $base );
$status = req( $test, 405, 'root', 'POST', $base );
$status = req( $test, 405, 'demo', 'DELETE', $base );
$status = req( $test, 405, 'active', 'DELETE', $base );
$status = req( $test, 405, 'root', 'DELETE', $base );


#=============================
# "employee/current" resource
# "employee/self" resource
#=============================

my $ts_eid_inactive = create_inactive_employee( $test );
my $ts_eid_active = create_active_employee( $test );

foreach my $base ( "employee/current", "employee/self" ) {
    docu_check($test, $base);
    #
    # GET employee/current
    #
    $status = req( $test, 200, 'demo', 'GET', $base );
    is( $status->level, 'OK' );
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
    $status = req( $test, 200, 'root', 'GET', $base );
    is( $status->level, 'OK' );
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
    # PUT
    #
    $status = req( $test, 405, 'demo', 'PUT', $base );
    $status = req( $test, 405, 'active', 'PUT', $base );
    $status = req( $test, 405, 'root', 'PUT', $base );
    
    #
    # POST
    #
    # - default configuration is that 'active' and 'inactive' can modify their own passhash and salt fields
    # - demo should *not* be authorized to do this
    req( $test, 403, 'demo', 'POST', $base, '{ "salt":"saltine" }' );
    foreach my $user ( "active", "inactive" ) {
        #
        $status = req( $test, 200, $user, 'POST', $base, '{ "salt":"saltine" }' );
        if ( $status->not_ok ) {
            diag( "$user $base { \"salt\":\"saltine\" }" );
            diag( Dumper $status );
            BAIL_OUT(0);
        }
        is( $status->level, 'OK' );
        is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' ); 
        #
        $status = req( $test, 200, $user, 'POST', $base, '{ "salt":"Megahard Active Saltine" }' );
        is( $status->level, 'OK' );
        is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' ); #
        #
        # - negative test
        req( $test, 400, $user, 'POST', $base, 0 );
        #
        # - change it back to undef
        $status = req( $test, 200, $user, 'POST', $base, '{ "salt": null }' );
        is( $status->level, 'OK' );
        is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' ); #
        #
        # - 'salt' is a permitted field, but 'inactive'/$user employees
        # should not, for example, be allowed to change 'nick'
        req( $test, 403, $user, 'POST', $base, '{ "nick": "wanger" }' );
        #
        # - nor should they be able to change 'email'
        req( $test, 403, $user, 'POST', $base, '{ "email": "5000thbat@cave.com" }' );
    }
    #
    # root can theoretically update any field, but certain fields of its own
    # profile are immutable
    #
    $status = req( $test, 200, 'root', 'POST', $base, '{ "email": "root@rotoroot.com" }' );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
    #
    $status = req( $test, 200, 'root', 'POST', $base, '{ "email": "root@site.org" }' );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
    #
    $status = req( $test, 200, 'root', 'POST', $base, '{ "nick": "aaaaazz" }' );
    is( $status->level, 'ERR' );
    is( $status->code, 'DOCHAZKA_DBI_ERR' );
    like( $status->text, qr/root employee is immutable/ );
    #

    #
    # DELETE
    #
    $status = req( $test, 405, 'demo', 'DELETE', $base );
    $status = req( $test, 405, 'active', 'DELETE', $base );
    $status = req( $test, 405, 'root', 'DELETE', $base );
}

delete_employee_by_nick( $test, 'inactive' );
delete_employee_by_nick( $test, 'active' );


#=============================
# "employee/current/priv" resource
# "employee/self/priv" resource
#=============================
foreach my $base ( "employee/current/priv", "employee/self/priv" ) {
    docu_check($test, "employee/current/priv");
    #
    # GET employee/current/priv
    #
    $status = req( $test, 200, 'demo', 'GET', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_CURRENT_PRIV' );
    ok( defined $status->payload );
    ok( exists $status->payload->{'priv'} );
    ok( exists $status->payload->{'schedule'} );
    ok( exists $status->payload->{'current_emp'} );
    is( $status->payload->{'current_emp'}->{'nick'}, 'demo' );
    is( $status->payload->{'priv'}, 'passerby' );
    is_deeply( $status->payload->{'schedule'}, {} );
    #
    $status = req( $test, 200, 'root', 'GET', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_CURRENT_PRIV' );
    ok( defined $status->payload );
    ok( exists $status->payload->{'priv'} );
    ok( exists $status->payload->{'schedule'} );
    ok( exists $status->payload->{'current_emp'} );
    is( $status->payload->{'current_emp'}->{'nick'}, 'root' );
    is( $status->payload->{'priv'}, 'admin' );
    is_deeply( $status->payload->{'schedule'}, {} );
    
    #
    # PUT, POST, DELETE
    #
    $status = req( $test, 405, 'demo', 'PUT', $base );
    $status = req( $test, 405, 'active', 'PUT', $base );
    $status = req( $test, 405, 'root', 'PUT', $base );
    $status = req( $test, 405, 'demo', 'POST', $base );
    $status = req( $test, 405, 'active', 'POST', $base );
    $status = req( $test, 405, 'root', 'POST', $base );
    $status = req( $test, 405, 'demo', 'DELETE', $base );
    $status = req( $test, 405, 'active', 'DELETE', $base );
    $status = req( $test, 405, 'root', 'DELETE', $base );
}
    
    
#=============================
# "employee/eid" resource
#=============================
$base = "employee/eid";
docu_check($test, "employee/eid");
#
# GET, PUT
#
$status = req( $test, 405, 'demo', 'GET', $base );
$status = req( $test, 405, 'active', 'GET', $base );
$status = req( $test, 405, 'root', 'GET', $base );
$status = req( $test, 405, 'demo', 'PUT', $base );
$status = req( $test, 405, 'active', 'PUT', $base );
$status = req( $test, 405, 'root', 'PUT', $base );

#
# POST
#
# - create a 'mrfu' employee
my $mrfu = create_testing_employee( nick => 'mrfu' );
my $eid_of_mrfu = $mrfu->eid;
#
# - give Mr. Fu an email address
#diag("--- POST employee/eid (update email)");
req( $test, 403, 'demo', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "email" : "mrsfu@dragon.cn" }' );
#
$status = req( $test, 200, 'root', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "email" : "mrsfu@dragon.cn" }' );
is( $status->level, "OK", 'POST employee/eid 3' );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK', 'POST employee/eid 4' );
is( $status->payload->{'email'}, 'mrsfu@dragon.cn', 'POST employee/eid 5' );
#
# - update to a different nick
#diag("--- POST employee/eid (update with different nick)");
req( $test, 403, 'demo', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "nick" : "mrsfu" , "fullname":"Dragoness" }' );
#
$status = req( $test, 200, 'root', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "nick" : "mrsfu" , "fullname":"Dragoness" }' );
is( $status->level, 'OK', 'POST employee/eid 8' );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK', 'POST employee/eid 9' );
my $mrsfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
my $mrsfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrfu->eid,
    nick => 'mrsfu', fullname => 'Dragoness', email => 'mrsfu@dragon.cn' );
is_deeply( $mrsfu, $mrsfuprime, 'POST employee/eid 10' );
#
# - update a non-existent EID
#diag("--- POST employee/eid (non-existent EID)");
req( $test, 400, 'demo', 'POST', $base, '{ "eid" : 5442' );
req( $test, 403, 'demo', 'POST', $base, '{ "eid" : 5442 }' );
$status = req( $test, 200, 'root', 'POST', $base, '{ "eid": 534, "nick": "mrfu", "fullname":"Lizard Scale" }' );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EMPLOYEE_DOES_NOT_EXIST' );
like( $status->text, qr/no employee with EID 534/ );
#
# - missing EID
$status = req( $test, 200, 'root', 'POST', $base, '{ "long-john": "silber" }' );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PARAMETER_BAD_OR_MISSING' );
#
# - incorrigibly attempt to update totally bogus and invalid EIDs
req( $test, 400, 'root', 'POST', $base, '{ "eid" : }' );
req( $test, 400, 'root', 'POST', $base, '{ "eid" : jj }' );
$status = req( $test, 200, 'root', 'POST', $base, '{ "eid" : "jj" }' );
is( $status->level, "ERR" );
is( $status->code, "DISPATCH_PARAMETER_BAD_OR_MISSING" );
#
# - and give it a bogus parameter (on update, bogus parameters cause REST to
#   vomit 400; on insert, they are ignored)
req( $test, 400, 'root', 'POST', $base, '{ "eid" : 2, "bogus" : "json" }' ); 
#
# - update to existing nick
$status = req( $test, 200, 'root', 'POST', $base, 
    '{ "eid": ' . $mrfu->eid . ', "nick" : "root" , "fullname":"Tom Wang" }' );
is( $status->level, "ERR" );
is( $status->code, "DOCHAZKA_DBI_ERR" );
#
# - update nick to null
$status = req( $test, 200, 'root', 'POST', $base, 
    '{ "eid": ' . $mrfu->eid . ', "nick" : null  }' );
is( $status->level, "ERR" );
is( $status->code, "DOCHAZKA_DBI_ERR" );
like( $status->text, qr/null value in column "nick" violates not-null constraint/ );

# delete the testing user
delete_testing_employee( $eid_of_mrfu );

#
# DELETE 
#
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'active', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );


#=============================
# "employee/eid/:eid" resource
#=============================
$base = 'employee/eid';
docu_check($test, "$base/:eid");

#
# GET employee/eid/:eid
#
# - with EID == 1
$status = req( $test, 200, 'root', 'GET', "$base/" . $site->DOCHAZKA_EID_OF_ROOT );
is( $status->level, 'OK' );
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
$status = req( $test, 200, 'root', 'GET', "$base/2" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, 2 );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'demo' );
ok( exists $status->payload->{'fullname'} );
is( $status->payload->{'fullname'}, 'Demo Employee' );
# 
req( $test, 403, 'demo', 'GET', "$base/2" );
#
req( $test, 404, 'root', 'GET', "$base/53432" );
#
req( $test, 403, 'demo', 'GET', "$base/53432" );


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
req( $test, 403, 'demo', 'PUT', "$base/$eid_of_brchen",
    '{ "eid": ' . $eid_of_brchen . ', "fullname":"Chen Update Again" }' );
#
# - be nice
req( $test, 403, 'demo', 'PUT', "$base/$eid_of_brchen",
    '{ "fullname":"Chen Update Again", "salt":"tasty" }' );
$status = req( $test, 200, 'root', 'PUT', "$base/$eid_of_brchen",
    '{ "fullname":"Chen Update Again", "salt":"tasty" }' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
my $brchen = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $brchen->eid, $eid_of_brchen );
my $brchenprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_brchen,
    nick => 'brotherchen', email => 'goodbrother@orient.cn', fullname =>
    'Chen Update Again', salt => 'tasty' );
is_deeply( $brchen, $brchenprime );
# 
# - provide invalid EID in request body
$status = req( $test, 200, 'root', 'PUT', "$base/$eid_of_brchen",
    '{ "eid": 99999, "fullname":"Chen Update Again 2" }' );
is( $status->level, 'OK' );
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
req( $test, 400, 'demo', 'PUT', "$base/$eid_of_brchen", '{' );
req( $test, 403, 'demo', 'PUT', "$base/$eid_of_brchen", '{ "nick": "mrfu", "fullname":"Lizard Scale" }' );
$status = req( $test, 200, 'root', 'PUT', "$base/$eid_of_brchen",
    '{ "nick": "mrfu", "fullname":"Lizard Scale", "email":"mrfu@dragon.cn" }' );
is( $status->level, 'OK' );
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
req( $test, 400, 'demo', 'PUT', "$base/5633", '{' );
req( $test, 403, 'demo', 'PUT', "$base/5633",
    '{ "nick": "mrfu", "fullname":"Lizard Scale" }' );
$status = req( $test, 200, 'root', 'PUT', "$base/5633",
    '{ "eid": 534, "nick": "mrfu", "fullname":"Lizard Scale" }' );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EMPLOYEE_DOES_NOT_EXIST' );
#
# - with valid JSON that is not what we are expecting
req( $test, 400, 'root', 'PUT', "$base/2", 0 );
# - another kind of bogus JSON
req( $test, 400, 'root', 'PUT', "$base/2", '{ "legal" : "json" }' );

#
# delete the testing user
delete_testing_employee( $eid_of_brchen );

#
# POST employee/eid/:eid
#
req( $test, 405, 'demo', 'POST', "$base/2" );
req( $test, 405, 'active', 'POST', "$base/2" );
req( $test, 405, 'root', 'POST', "$base/2" );

#
# DELETE employee/eid/:eid
#
# create a "cannon fodder" employee
my $cf = create_testing_employee( nick => 'cannonfodder' );
my $eid_of_cf = $cf->eid;

# 'employee/eid/:eid' - delete cannonfodder
req( $test, 403, 'demo', 'DELETE', "$base/$eid_of_cf" );
req( $test, 401, 'active', 'DELETE', "$base/$eid_of_cf" ); # 401 because 'active' doesn't exist
$status = req( $test, 200, 'root', 'DELETE', "$base/$eid_of_cf" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_DELETE_OK' );

# attempt to get cannonfodder - not there anymore
req( $test, 403, 'demo', 'GET', "$base/$eid_of_cf" );
req( $test, 404, 'root', 'GET', "$base/$eid_of_cf" );

# create another "cannon fodder" employee
$cf = create_testing_employee( nick => 'cannonfodder' );
ok( $cf->eid > $eid_of_cf ); # EID will have incremented
$eid_of_cf = $cf->eid;

# delete the sucker
req( $test, 403, 'demo', 'DELETE', '/employee/nick/cannonfodder' );
$status = req( $test, 200, 'root', 'DELETE', '/employee/nick/cannonfodder' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_DELETE_OK' );

# attempt to get cannonfodder - not there anymore
req( $test, 403, 'demo', 'GET',  "$base/$eid_of_cf" );
req( $test, 404, 'root', 'GET',  "$base/$eid_of_cf" );

# attempt to delete 'root the immutable' (won't work)
$status = req( $test, 200, 'root', 'DELETE', "$base/1" );
is( $status->level, 'ERR' );
is( $status->code, "DOCHAZKA_DBI_ERR" );
like( $status->text, qr/immutable/i );


#=============================
# "employee/help" resource
#=============================
$base = "employee/help";
docu_check($test, "employee/help");
#
# GET
#
$status = req( $test, 200, 'demo', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 2 );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
#
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 6 );
ok( exists $status->payload->{'resources'}->{'employee/help'} );

#
# PUT
#
$status = req( $test, 200, 'demo', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# 
$status = req( $test, 200, 'root', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 3 );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
ok( exists $status->payload->{'resources'}->{'employee/nick/:nick'} );

#
# POST
#
$status = req( $test, 200, 'demo', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
#
$status = req( $test, 200, 'root', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );

#
# DELETE
#
$status = req( $test, 200, 'demo', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
#
$status = req( $test, 200, 'demo', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );


#=============================
# "employee/nick" resource
#=============================
$base = "employee/nick";
docu_check($test, "employee/nick");
#
# GET, PUT employee/nick
#
req( $test, 405, 'demo', 'GET', $base );
req( $test, 405, 'root', 'GET', $base );
req( $test, 405, 'demo', 'PUT', $base );
req( $test, 405, 'root', 'PUT', $base );

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
req( $test, 403, 'demo', 'POST', $base, $j );
#
$status = req( $test, 200, 'root', 'POST', $base, $j );
is( $status->level, "OK" );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
is( $status->payload->{'email'}, 'mrsfu@dragon.cn' );
#
# - non-existent nick (insert new employee)
#diag("--- POST employee/nick (non-existent nick)");
req( $test, 400, 'demo', 'POST', $base, 
    '{ "nick" : 5442' );
req( $test, 403, 'demo', 'POST', $base, 
    '{ "nick" : 5442 }' );
#
# - attempt to insert new employee with bogus "eid" property
$status = req( $test, 200, 'root', 'POST', $base,
    '{ "eid": 534, "nick": "mrfutra", "fullname":"Rovnou do futer" }' );
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
req( $test, 400, 'demo', 'POST', $base, '{' );
req( $test, 403, 'demo', 'POST', $base, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale" }' );
$status = req( $test, 200, 'root', 'POST', $base, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale", "email":"mrfu@dragon.cn" }' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
$mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
$mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrfu->eid, 
    nick => 'mrfu', fullname => 'Dragon Scale', email => 'mrfu@dragon.cn' );
is_deeply( $mrfu, $mrfuprime );
$eid_of_mrfu = $mrfu->eid;
#
# - and give it valid, yet bogus JSON (unknown nick - insert)
$status = req( $test, 200, 'root', 'POST', $base, 
    '{ "nick" : "wombat", "bogus" : "json" }' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
my $eid_of_wombat = $status->payload->{'eid'};
#
#
# - get wombat
$status = req( $test, 200, 'root', 'GET', '/employee/nick/wombat' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
my $wombat_emp = App::Dochazka::REST::Model::Employee->spawn( $status->payload );

# - and give it valid, yet bogus JSON -- update has nothing to do
$status = req( $test, 200, 'root', 'POST', $base, 
    '{ "nick" : "wombat", "bogus" : "json" }' );
is( $status->level, "OK" );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' ); # after bogus param is
      # eliminated, update has nothing to do, but it carries out the update
      # operation anyway
my $updated_wombat = App::Dochazka::REST::Model::Employee->spawn( $status->payload );
is_deeply( $wombat_emp, $updated_wombat );

#
delete_testing_employee( $eid_of_wombat );


# - update existing employee
#diag("--- POST employee/nick (update)");
req( $test, 403, 'demo', 'POST', $base, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale Update", "email" : "scale@dragon.org" }' );
$status = req( $test, 200, 'root', 'POST', $base, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale Update", "email" : "scale@dragon.org" }' );
is( $status->level, "OK" );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
$mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_mrfu,
    nick => 'mrfu', fullname => 'Dragon Scale Update', email => 'scale@dragon.org' );
is_deeply( $mrfu, $mrfuprime );
#
# - create a bogus user with a bogus property
$status = req( $test, 200, 'root', 'POST', $base, 
    '{ "nick":"bogus", "wago":"svorka", "fullname":"bogus user" }' );
is( $status->level, "OK" );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
my $eid_of_bogus = $status->payload->{'eid'};

map { delete_testing_employee( $_ ); } ( $eid_of_mrfu, $eid_of_bogus );

#
# DELETE employee/nick
#
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );


#=============================
# "employee/nick/:nick" resource
#=============================
$base = "employee/nick";
docu_check($test, "employee/nick/:nick");
#
# GET employee/nick/:nick
#
# - with nick == 'root'
$status = req( $test, 200, 'root', 'GET', "$base/root" );
is( $status->level, "OK" );
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
$status = req( $test, 200, 'root', 'GET', "$base/demo" );
is( $status->level, "OK" );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, 2 );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'demo' );
ok( exists $status->payload->{'fullname'} );
is( $status->payload->{'fullname'}, 'Demo Employee' );
# 
req( $test, 403, 'demo', 'GET', "$base/demo" );
req( $test, 404, 'root', 'GET', "$base/53432" );
req( $test, 403, 'demo', 'GET', "$base/53432" );
req( $test, 404, 'root', 'GET', "$base/heathledger" );
# 
# this one triggers "wide character in print" warnings
#req( $test, 404, 'root', 'GET', "$base/" . uri_escape_utf8('/employee/nick//////áěěoěščqwšáščšýš..-...-...-..-.00') );

# 
# PUT employee/nick/:nick
#
# - insert and be nice
req( $test, 400, 'demo', 'PUT', "$base/mrsfu", '{' );
req( $test, 403, 'demo', 'PUT', "$base/mrsfu", 
    '{ "fullname":"Dragonness" }' );
$status = req( $test, 200, 'root', 'PUT', "$base/mrsfu", 
    '{ "fullname":"Dragonness" }' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
$mrsfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
$mrsfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrsfu->eid, 
    nick => 'mrsfu', fullname => 'Dragonness' );
is_deeply( $mrsfu, $mrsfuprime );
my $eid_of_mrsfu = $mrsfu->eid;

# - insert and be pathological
# - provide conflicting 'nick' property in the content body
req( $test, 400, 'demo', 'PUT', "$base/hapless", '{' );
req( $test, 403, 'demo', 'PUT', "$base/hapless", 
    '{ "nick":"INVALID", "fullname":"Anders Chen" }' );
$status = req( $test, 200, 'root', 'PUT', "$base/hapless", 
    '{ "nick":"INVALID", "fullname":"Anders Chen" }' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
my $hapless = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
isnt( $hapless->nick, 'INVALID' );
is( $hapless->nick, 'hapless' );
my $haplessprime = App::Dochazka::REST::Model::Employee->spawn( eid => $hapless->eid, 
    nick => 'hapless', fullname => 'Anders Chen' );
is_deeply( $hapless, $haplessprime );
my $eid_of_hapless = $hapless->eid;

# - update and be nice
$status = req( $test, 200, 'root', 'PUT', "$base/hapless", 
    '{ "fullname":"Chen Update", "salt":"none, please" }' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$hapless = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $hapless->nick, "hapless" );
is( $hapless->fullname, "Chen Update" );
is( $hapless->salt, "none, please" );
$haplessprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_hapless,
    nick => 'hapless', fullname => 'Chen Update', salt => "none, please" );
is_deeply( $hapless, $haplessprime );

# - update and be nice and also change salt to null
$status = req( $test, 200, 'root', 'PUT', "$base/hapless", 
    '{ "fullname":"Chen Update", "salt":null }' );
is( $status->level, 'OK' );
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
$status = req( $test, 200, 'root', 'PUT', "$base/hapless",
    '{ "eid": 534, "fullname":"Good Brother Chen", "salt":"" }' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
$hapless = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $hapless->fullname, "Good Brother Chen" );
is( $hapless->eid, $eid_of_hapless );
isnt( $hapless->eid, 534 );
$haplessprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_hapless,
    nick => 'hapless', fullname => 'Good Brother Chen' );
is_deeply( $hapless, $haplessprime );

# - pathologically attempt to change nick to null
$status = req( $test, 200, 'root', 'PUT', "$base/hapless",
    '{ "nick":null }' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/violates not-null constraint/ );

# - feed it more bogusness
req( $test, 400, 'root', 'PUT', "$base/hapless", '{ "legal" : "json" }' );

# 
delete_testing_employee( $eid_of_mrsfu );
delete_testing_employee( $eid_of_hapless );

#
# POST employee/nick:nick
#
req( $test, 405, 'demo', 'POST', "$base/root" );
req( $test, 405, 'root', 'POST', "$base/root" );

#
# DELETE employee/nick/:nick
#
# create a "cannon fodder" employee
$cf = create_testing_employee( nick => 'cannonfodder' );
ok( $cf->eid > 1 );
$eid_of_cf = $cf->eid;

# get cannonfodder - no problem
$status = req( $test, 200, 'root', 'GET', "$base/cannonfodder" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );

# 'employee/nick/:nick' - delete cannonfodder
req( $test, 403, 'demo', 'DELETE', $base . "/" . $cf->nick );
$status = req( $test, 200, 'root', 'DELETE', $base . "/" . $cf->nick );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_DELETE_OK' );

# attempt to get cannonfodder - not there anymore
req( $test, 404, 'root', 'GET', "$base/cannonfodder" );

# attempt to get in a different way
$status = App::Dochazka::REST::Model::Employee->load_by_nick( 'cannonfodder' );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND' );

# create another "cannon fodder" employee
$cf = create_testing_employee( nick => 'cannonfodder' );
ok( $cf->eid > $eid_of_cf ); # EID will have incremented
$eid_of_cf = $cf->eid;

# get cannonfodder - again, no problem
$status = req( $test, 200, 'root', 'GET', "$base/cannonfodder" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );

# - delete with a typo
req( $test, 403, 'demo', 'DELETE', "$base/cannonfoddertypo" );
$status = req( $test, 200, 'root', 'DELETE', "$base/cannonfoddertypo" );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_NICK_DOES_NOT_EXIST' );

# attempt to get cannonfodder - still there
$status = req( $test, 200, 'root', 'GET', "$base/cannonfodder" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );

delete_testing_employee( $eid_of_cf );

# attempt to delete 'root the immutable' (won't work)
$status = req( $test, 200, 'root', 'DELETE', "$base/root" );
is( $status->level, 'ERR' );
is( $status->code, "DOCHAZKA_DBI_ERR" );
like( $status->text, qr/immutable/i );

done_testing;
