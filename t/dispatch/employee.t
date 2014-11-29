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
use utf8;

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
# GET
#
# - valid priv strings
foreach my $priv ( qw( 
    passerby
    PASSERBY
    paSsERby
    inactive
    INACTIVE
    inAcTive
    active
    ACTIVE
    actIVe
    admin
    ADMIN
    AdmiN
) ) {
    #diag( "$base/$priv" );
    $status = req( $test, 200, 'root', 'GET', "$base/$priv" );
    is( $status->level, "OK", "GET $base/:priv 2" );
    if( $status->code ne 'DISPATCH_COUNT_EMPLOYEES' ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->code, 'DISPATCH_COUNT_EMPLOYEES', "GET $base/:priv 3" );
    ok( defined $status->payload, "GET $base/:priv 4" );
    ok( exists $status->payload->{'priv'}, "GET $base/:priv 5" );
    is( $status->payload->{'priv'}, lc $priv, "GET $base/:priv 6" );
    ok( exists $status->payload->{'count'}, "GET $base/:priv 7" );
    #
    req( $test, 403, 'demo', 'GET', "$base/$priv" );
}
#
# - invalid priv strings
foreach my $priv (
    'nanaan',
    '%^%#$#',
#    'Žluťoucký kǔň',
    '      dfdf fifty-five sixty-five',
    'passerbies',
    '///adfd/asdf/asdf',
) {
    req( $test, 404, 'root', 'GET', "$base/$priv" );
    req( $test, 404, 'demo', 'GET', "$base/$priv" );
}

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
    dbi_err( $test, 200, 'root', 'POST', $base, '{ "nick": "aaaaazz" }', qr/root employee is immutable/ );
    #

    #
    # DELETE
    #
    $status = req( $test, 405, 'demo', 'DELETE', $base );
    $status = req( $test, 405, 'active', 'DELETE', $base );
    $status = req( $test, 405, 'root', 'DELETE', $base );
}


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
    is( $status->payload->{'schedule'}, undef );
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
    is( $status->payload->{'schedule'}, undef );
    
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
my $mrfu = create_testing_employee( nick => 'mrfu', passhash => 'mrfu' );
my $eid_of_mrfu = $mrfu->eid;
#
# - give Mr. Fu an email address
#diag("--- POST employee/eid (update email)");
req( $test, 403, 'demo', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "salt" : "shake it" }' );
# 
is( $mrfu->nick, 'mrfu' );
req( $test, 403, 'mrfu', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "salt" : "shake it" }' );
# fails because mrfu is a passerby
#
# - make him an inactive 
$status = req( $test, 200, 'root', 'POST', "priv/history/eid/" . $mrfu->eid, <<"EOH" );
{ "priv" : "inactive", "effective" : "2004-01-01" }
EOH
is( $status->level, "OK", 'POST employee/eid 3' );
is( $status->code, "DOCHAZKA_CUD_OK", 'POST employee/eid 3' );
ok( exists $status->payload->{'phid'} );
my $mrfu_phid = $status->payload->{'phid'};
#
# - try the operation again
$status = req( $test, 200, 'mrfu', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "salt" : "shake it" }' );
is( $status->level, "OK", 'POST employee/eid 3' );
is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK', 'POST employee/eid 4' );
is( $status->payload->{'salt'}, 'shake it', 'POST employee/eid 5' );
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
    nick => 'mrsfu', fullname => 'Dragoness', passhash => 'mrfu', salt => 'shake it' );
is_deeply( $mrsfu, $mrsfuprime, 'POST employee/eid 10' );
#
# - update a non-existent EID
#diag("--- POST employee/eid (non-existent EID)");
req( $test, 400, 'demo', 'POST', $base, '{ "eid" : 5442' );
req( $test, 403, 'demo', 'POST', $base, '{ "eid" : 5442 }' );
req( $test, 404, 'root', 'POST', $base, '{ "eid": 534, "nick": "mrfu", "fullname":"Lizard Scale" }' );
#
# - missing EID
req( $test, 400, 'root', 'POST', $base, '{ "long-john": "silber" }' );
#
# - incorrigibly attempt to update totally bogus and invalid EIDs
req( $test, 400, 'root', 'POST', $base, '{ "eid" : }' );
req( $test, 400, 'root', 'POST', $base, '{ "eid" : jj }' );
$status = req( $test, 200, 'root', 'POST', $base, '{ "eid" : "jj" }' );
is( $status->level, "ERR" );
is( $status->code, "DOCHAZKA_DBI_ERR" );
like( $status->text, qr/invalid input syntax for integer/ );
#
# - and give it a bogus parameter (on update, bogus parameters cause REST to
#   vomit 400; on insert, they are ignored)
req( $test, 400, 'root', 'POST', $base, '{ "eid" : 2, "bogus" : "json" }' ); 
#
# - update to existing nick
dbi_err( $test, 200, 'root', 'POST', $base, 
    '{ "eid": ' . $mrfu->eid . ', "nick" : "root" , "fullname":"Tom Wang" }',
    qr/Key \(nick\)=\(root\) already exists/ );
#
# - update nick to null
dbi_err( $test, 200, 'root', 'POST', $base, 
    '{ "eid": ' . $mrfu->eid . ', "nick" : null  }',
    qr/null value in column "nick" violates not-null constraint/ );

# 
# - inactive and active users get a little piece of the action, too:
#   they can operate on themselves (certain fields), but not on, e.g., Mr. Fu
foreach my $user ( qw( demo inactive active ) ) {
    req( $test, 403, $user, 'POST', $base, <<"EOH" );
{ "eid" : $eid_of_mrfu, "passhash" : "HAHAHAHA" }
EOH
}
foreach my $user ( qw( demo inactive active ) ) {
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    is( ref( $status->payload ), 'HASH' );
    my $eid = $status->payload->{'eid'};
    req( $test, 403, $user, 'POST', $base, <<"EOH" );
{ "eid" : $eid, "nick" : "tHE gREAT fABULATOR" }
EOH
}
foreach my $user ( qw( inactive active ) ) {
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    is( ref( $status->payload ), 'HASH' );
    my $eid = $status->payload->{'eid'};
    $status = req( $test, 200, $user, 'POST', $base, <<"EOH" );
{ "eid" : $eid, "salt" : "tHE gREAT fABULATOR" }
EOH
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    is( ref( $status->payload ), 'HASH' );
    is( $status->payload->{'salt'}, "tHE gREAT fABULATOR" );
}


# delete the testing user
# 1. first delete his privhistory entry
$status = req( $test, 200, 'root', 'DELETE', "priv/history/phid/$mrfu_phid" );
ok( $status->ok );
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

my @invalid_eids = (
    '342j',
    '**12',
    ' 1', 
    'fenestre',
    '1234/123/124/',
);

#
# GET
#
#
# - normal usage: get employee with nick [0], eid [2], fullname [3] as employee
#   with nick [1]
foreach my $params (
    [ 'root', 'root', $site->DOCHAZKA_EID_OF_ROOT, 'Root Immutable' ],
    [ 'demo', 'root', 2, 'Demo Employee' ],
    [ 'active', 'root', $ts_eid_active, undef ],
    [ 'active', 'active', $ts_eid_active, undef ],
    [ 'inactive', 'root', $ts_eid_inactive, undef ],
) {
    $status = req( $test, 200, $params->[1], 'GET', "$base/" . $params->[2] );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    ok( defined $status->payload );
    ok( exists $status->payload->{'eid'} );
    is( $status->payload->{'eid'}, $params->[2] );
    ok( exists $status->payload->{'nick'} );
    is( $status->payload->{'nick'}, $params->[0] );
    ok( exists $status->payload->{'fullname'} );
    is( $status->payload->{'fullname'}, $params->[3] );
}
# 
req( $test, 403, 'demo', 'GET', "$base/2" );
#
req( $test, 404, 'root', 'GET', "$base/53432" );
#
req( $test, 403, 'demo', 'GET', "$base/53432" );
#
# - invalid EIDs caught by Path::Router validations clause
foreach my $eid ( @invalid_eids ) {
    foreach my $user ( qw( root demo ) ) {
        req( $test, 404, $user, 'GET', "$base/$eid" );
    }
}
#
# as demonstrated above, an active employee can see his own profile using this
# resource -- demonstrate it again
$status = req( $test, 200, 'active', 'GET', "$base/$ts_eid_active" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
#
# an 'inactive' employee can do the same
$status = req( $test, 200, 'inactive', 'GET', "$base/$ts_eid_inactive" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
#
# but this does not work for demo, whose privlevel is 'passerby'
req( $test, 403, 'demo', 'GET', "$base/2" );  # EID 2 is 'demo'
#
# or for unknown users
req( $test, 401, 'unknown', 'GET', "$base/2" );  # EID 2 is 'demo'
#
# and non-administrators cannot use this resource to look at other employees
foreach my $user ( qw( active inactive demo ) ) {
    req( $test, 403, $user, 'GET', "$base/1" );
}

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
req( $test, 404, 'root', 'PUT', "$base/5633",
    '{ "eid": 534, "nick": "mrfu", "fullname":"Lizard Scale" }' );
#
# - with valid JSON that is not what we are expecting
req( $test, 400, 'root', 'PUT', "$base/2", 0 );
# - another kind of bogus JSON
req( $test, 400, 'root', 'PUT', "$base/2", '{ "legal" : "json" }' );
#
# - invalid EIDs caught by Path::Router validations clause
foreach my $eid ( @invalid_eids ) {
    foreach my $user ( qw( root demo ) ) {
        req( $test, 405, $user, 'PUT', "$base/$eid" );
    }
}

# 
# - inactive and active users get a little piece of the action, too:
#   they can operate on themselves (certain fields), but not on, e.g., Mr. Fu
foreach my $user ( qw( demo inactive active ) ) {
    req( $test, 403, $user, 'PUT', "$base/$eid_of_mrfu", <<"EOH" );
{ "passhash" : "HAHAHAHA" }
EOH
}
foreach my $user ( qw( demo inactive active ) ) {
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    is( ref( $status->payload ), 'HASH' );
    my $eid = $status->payload->{'eid'};
    req( $test, 403, $user, 'PUT', "$base/$eid", <<"EOH" );
{ "nick" : "tHE gREAT fABULATOR" }
EOH
}
foreach my $user ( qw( inactive active ) ) {
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    is( ref( $status->payload ), 'HASH' );
    my $eid = $status->payload->{'eid'};
    $status = req( $test, 200, $user, 'PUT', "$base/$eid", <<"EOH" );
{ "salt" : "tHE gREAT fABULATOR" }
EOH
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    is( ref( $status->payload ), 'HASH' );
    is( $status->payload->{'salt'}, "tHE gREAT fABULATOR" );
}


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
#
# 'employee/eid/:eid' - delete cannonfodder
req( $test, 403, 'demo', 'DELETE', "$base/$eid_of_cf" );
req( $test, 403, 'active', 'DELETE', "$base/$eid_of_cf" ); 
req( $test, 401, 'unknown', 'DELETE', "$base/$eid_of_cf" ); # 401 because 'unknown' doesn't exist
$status = req( $test, 200, 'root', 'DELETE', "$base/$eid_of_cf" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_DELETE_OK' );
#
# attempt to get cannonfodder - not there anymore
req( $test, 403, 'demo', 'GET', "$base/$eid_of_cf" );
req( $test, 404, 'root', 'GET', "$base/$eid_of_cf" );
#
# create another "cannon fodder" employee
$cf = create_testing_employee( nick => 'cannonfodder' );
ok( $cf->eid > $eid_of_cf ); # EID will have incremented
$eid_of_cf = $cf->eid;
#
# delete the sucker
req( $test, 403, 'demo', 'DELETE', '/employee/nick/cannonfodder' );
$status = req( $test, 200, 'root', 'DELETE', '/employee/nick/cannonfodder' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_DELETE_OK' );
#
# attempt to get cannonfodder - not there anymore
req( $test, 403, 'demo', 'GET',  "$base/$eid_of_cf" );
req( $test, 404, 'root', 'GET',  "$base/$eid_of_cf" );
#
# attempt to delete 'root the immutable' (won't work)
dbi_err( $test, 200, 'root', 'DELETE', "$base/1", undef, qr/immutable/i );
#
# - invalid EIDs caught by Path::Router validations clause
foreach my $eid ( @invalid_eids ) {
    foreach my $user ( qw( root demo ) ) {
        req( $test, 404, $user, 'GET', "$base/$eid" );
    }
}


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

# 
# - inactive and active users get a little piece of the action, too:
#   they can operate on themselves (certain fields), but not on, e.g., Mr. Fu
foreach my $user ( qw( demo inactive active ) ) {
    foreach my $target ( qw( mrfu wombat unknown ) ) {
        req( $test, 403, $user, 'POST', "$base", <<"EOH" );
{ "nick" : "$target", "passhash" : "HAHAHAHA" }
EOH
    }
}
foreach my $user ( qw( inactive active ) ) {
    $status = req( $test, 200, $user, 'POST', "$base", <<"EOH" );
{ "nick" : "$user", "salt" : "tHE gREAT wOMBAT" }
EOH
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    is( ref( $status->payload ), 'HASH' );
    is( $status->payload->{'salt'}, "tHE gREAT wOMBAT" );
}

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
dbi_err( $test, 200, 'root', 'PUT', "$base/hapless",
    '{ "nick":null }', qr/violates not-null constraint/ );

# - feed it more bogusness
req( $test, 400, 'root', 'PUT', "$base/hapless", '{ "legal" : "json" }' );

# 
# - inactive and active users get a little piece of the action, too:
#   they can operate on themselves (certain fields), but not on, e.g., Mrs. Fu or Hapless
foreach my $user ( qw( demo inactive active ) ) {
    foreach my $target ( qw( mrsfu hapless unknown ) ) {
        req( $test, 403, $user, 'PUT', "$base/$target", <<"EOH" );
{ "passhash" : "HAHAHAHA" }
EOH
    }
}
foreach my $user ( qw( inactive active ) ) {
    $status = req( $test, 200, $user, 'PUT', "$base/$user", <<"EOH" );
{ "salt" : "tHE gREAT wOMBAT" }
EOH
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_UPDATE_OK' );
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    is( ref( $status->payload ), 'HASH' );
    is( $status->payload->{'salt'}, "tHE gREAT wOMBAT" );
}

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

# - delete with a typo (non-existent nick)
req( $test, 403, 'demo', 'DELETE', "$base/cannonfoddertypo" );
req( $test, 204, 'root', 'DELETE', "$base/cannonfoddertypo" );

# attempt to get cannonfodder - still there
$status = req( $test, 200, 'root', 'GET', "$base/cannonfodder" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );

delete_testing_employee( $eid_of_cf );

# attempt to delete 'root the immutable' (won't work)
dbi_err( $test, 200, 'root', 'DELETE', "$base/root", undef, qr/immutable/i );

delete_employee_by_nick( $test, 'inactive' );
delete_employee_by_nick( $test, 'active' );

done_testing;
