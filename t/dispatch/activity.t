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
# test activity resources
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

# takes PARAMHASH with either 'aid => ...' or 'code => ...'
sub disable_testing_activity {
    my %PH = @_;
    my $resource;
    if ( $PH{aid} ) {
        $resource = "activity/aid/$PH{aid}";
    } elsif ( $PH{code} ) {
        $resource = "activity/code/$PH{code}";
    }
    $status = req( $test, 200, 'root', 'PUT', $resource, '{ "disabled" : true }' );
    is( $status->level, 'OK', "Disable Testing Activity 2" );
    is( $status->code, 'DOCHAZKA_CUD_OK', "Disable Testing Activity 3" );
    is( ref( $status->payload ), 'HASH', "Disable Testing Activity 4" );
    my $act = $status->payload;
    ok( $act->{aid} > 8, "Disable Testing Activity 5" );
    ok( $act->{disabled}, "Disable Testing Activity 6" );
    return App::Dochazka::REST::Model::Activity->spawn( $act );
}

#
# create a testing employee with 'active' privlevel
#
create_active_employee( $test );


#=============================
# "activity/aid" resource
#=============================
my $base = 'activity/aid';
docu_check($test, "$base");

#
# GET, PUT
#
req( $test, 405, 'demo', 'GET', $base );
req( $test, 405, 'active', 'GET', $base );
req( $test, 405, 'root', 'GET', $base );
req( $test, 405, 'demo', 'PUT', $base );
req( $test, 405, 'active', 'PUT', $base );
req( $test, 405, 'root', 'PUT', $base );

#
# POST
#

my $foowop = create_testing_activity( code => 'FOOWOP' );
my $aid_of_foowop = $foowop->aid;

# 
# - test if expected behavior behaves as expected (update)
my $activity_obj = '{ "aid" : ' . $aid_of_foowop . ', "long_desc" : "wop wop ng", "remark" : "puppy" }';
req( $test, 403, 'demo', 'POST', $base, $activity_obj );
req( $test, 403, 'active', 'POST', $base, $activity_obj );
$status = req( $test, 200, 'root', 'POST', $base, $activity_obj );
is( $status->level, 'OK', "POST $base 4" );
is( $status->code, 'DOCHAZKA_CUD_OK', "POST $base 5" );
is( $status->payload->{'remark'}, 'puppy', "POST $base 6" );
is( $status->payload->{'long_desc'}, 'wop wop ng', "POST $base 7" );
#
# - non-existent AID and also out of range
$activity_obj = '{ "aid" : 3434342342342, "long_desc" : 3434341, "remark" : 34334342 }';
$status = req( $test, 200, 'root', 'POST', $base, $activity_obj );
is( $status->level, "ERR", "POST $base 7.3" );
is( $status->code, "DOCHAZKA_DBI_ERR", "POST $base 7.4" );
like( $status->text, qr/out of range for type integer/, "POST $base 7.5" );
#
# - non-existent AID
$activity_obj = '{ "aid" : 342342342, "long_desc" : 3434341, "remark" : 34334342 }';
$status = req( $test, 200, 'root', 'POST', $base, $activity_obj );
is( $status->level, "NOTICE", "POST $base 7.3" );
is( $status->code, "DISPATCH_AID_DOES_NOT_EXIST", "POST $base 7.4" );
#
# - throw a couple curve balls
my $weirded_object = '{ "copious_turds" : 555, "long_desc" : "wang wang wazoo", "disabled" : "f" }';
$status = req( $test, 200, 'root', 'POST', $base, $weirded_object );
is( $status->level, 'ERR', "POST $base 8" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "POST $base 9" );
#
my $no_closing_bracket = '{ "copious_turds" : 555, "long_desc" : "wang wang wazoo", "disabled" : "f"';
req( $test, 400, 'root', 'POST', $base, $no_closing_bracket );
#
$weirded_object = '{ "aid" : "!!!!!", "long_desc" : "down it goes" }';
$status = req( $test, 200, 'root', 'POST', $base, $weirded_object );
is( $status->level, 'ERR', "POST $base 13" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "POST $base 14" );
like( $status->text, qr/invalid input syntax for integer/, "POST $base 15" );

delete_testing_activity( $aid_of_foowop );



#
# DELETE
#
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'active', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );



#=============================
# "activity/aid/:aid" resource
#=============================
$base = 'activity/aid';
docu_check($test, "$base/:aid");

# insert an activity and disable it here
my $foobar = create_testing_activity( code => 'FOOBAR' );
$foobar = disable_testing_activity( code => $foobar->code );
ok( $foobar->disabled, "$base/:aid testing activity is really disabled 1" );
my $aid_of_foobar = $foobar->aid;

#
# GET
#
# fail as demo 403
req( $test, 403, 'demo', 'GET', "$base/1" );
#
# succeed as active AID 1
$status = req( $test, 200, 'active', 'GET', "$base/1" );
ok( $status->ok, "GET $base/:aid 2" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "GET $base/:aid 3" );
is_deeply( $status->payload, {
    aid => 1,
    code => 'WORK',
    long_desc => 'Work',
    remark => 'dbinit',
    disabled => 0,
}, "GET $base/:aid 4" );
#
# fail invalid AID
$status = req( $test, 200, 'active', 'GET', "$base/jj" );
is( $status->level, 'ERR', "GET $base/:aid 6" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "GET $base/:aid 7" );
like( $status->text, qr/invalid input syntax for integer/, "GET $base/:aid 8" );
#
# fail non-existent AID
$status = req( $test, 200, 'active', 'GET', "$base/444" );
is( $status->level, 'NOTICE', "GET $base/:aid 10" );
is( $status->code, 'DISPATCH_AID_DOES_NOT_EXIST', "GET $base/:aid 11" );
#
# succeed disabled AID
$status = req( $test, 200, 'active', 'GET', "$base/$aid_of_foobar" );
is( $status->level, 'OK', "GET $base/:aid 13" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "GET $base/:aid 14" );
is_deeply( $status->payload, {
    aid => $aid_of_foobar,
    code => 'FOOBAR',
    long_desc => undef,
    remark => undef,
    disabled => 1,
}, "GET $base/:aid 15" );

#
# PUT
# 
$activity_obj = '{ "code" : "FOOBAR", "long_desc" : "The bar of foo", "remark" : "Change is good" }';
# - test with demo fail 405
req( $test, 403, 'active', 'PUT', "$base/$aid_of_foobar", $activity_obj );
#
# - test with root success
$status = req( $test, 200, 'root', 'PUT', "$base/$aid_of_foobar", $activity_obj );
is( $status->level, 'OK', "PUT $base/:aid 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/:aid 4" );
is( ref( $status->payload ), 'HASH', "PUT $base/:aid 5" );
#
# - make an Activity object out of the payload
$foobar = App::Dochazka::REST::Model::Activity->spawn( $status->payload );
is( $foobar->long_desc, "The bar of foo", "PUT $base/:aid 5" );
is( $foobar->remark, "Change is good", "PUT $base/:aid 6" );
ok( $foobar->disabled, "PUT $base/:aid 7" );
#
# - test with root no request body
$status = req( $test, 200, 'root', 'PUT', "$base/$aid_of_foobar" );
is( $status->level, 'ERR', "PUT $base/:aid 9" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "PUT $base/:aid 10" );
#
# - test with root fail invalid JSON
req( $test, 400, 'root', 'PUT', "$base/$aid_of_foobar", '{ asdf' );
#
# - test with root fail invalid AID
$status = req( $test, 200, 'root', 'PUT', "$base/asdf", '{ "legal":"json" }' );
is( $status->level, 'ERR', "PUT $base/:aid 15" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "PUT $base/:aid 16" );
like( $status->text, qr/invalid input syntax for integer/, "PUT $base/:aid 17" );
#
# - with valid JSON that is not what we are expecting (invalid AID)
$status = req( $test, 200, 'root', 'PUT', "$base/asdf", '0' );
is( $status->level, 'ERR', "PUT $base/:aid 19" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "PUT $base/:aid 16" );
like( $status->text, qr/invalid input syntax for integer/, "PUT $base/:aid 17" );
#
# - with valid JSON that is not what we are expecting (valid AID)
$status = req( $test, 200, 'root', 'PUT', "$base/$aid_of_foobar", '0' );
is( $status->level, 'ERR', "PUT $base/:aid 19" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "PUT $base/:aid 20" );
#
# - with valid JSON that has some bogus properties
$status = req( $test, 200, 'root', 'PUT', "$base/$aid_of_foobar", '{ "legal":"json" }' );
is( $status->level, 'ERR', "PUT $base/:aid 22" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "PUT $base/:aid 23" );

#
# POST
#
req( $test, 405, 'demo', 'POST', "$base/1" );
req( $test, 405, 'active', 'POST', "$base/1" );
req( $test, 405, 'root', 'POST', "$base/1" );

#
# DELETE
#
# - test with demo fail 403
req( $test, 403, 'demo', 'DELETE', "$base/1" );
#
# - test with active fail 403
req( $test, 403, 'active', 'DELETE', "$base/1" );
#
# - test with root success
#diag( "DELETE $base/$aid_of_foobar" );
$status = req( $test, 200, 'root', 'DELETE', "$base/$aid_of_foobar" );
is( $status->level, 'OK', "DELETE $base/:aid 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "DELETE $base/:aid 4" );
#
# - really gone
$status = req( $test, 200, 'active', 'GET', "$base/$aid_of_foobar" );
is( $status->level, 'NOTICE', "DELETE $base/:aid 6" );
is( $status->code, 'DISPATCH_AID_DOES_NOT_EXIST', "DELETE $base/:aid 7" );
#
# - test with root fail invalid AID
$status = req( $test, 200, 'root', 'DELETE', "$base/asd" );
is( $status->level, 'ERR', "DELETE $base/:aid 8" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "DELETE $base/:aid 9" );
like( $status->text, qr/invalid input syntax for integer/, "DELETE $base/:aid 10" );

#=============================
# "activity/all" resource
#=============================
$base = 'activity/all';
docu_check($test, $base);

# insert an activity and disable it here
$foobar = create_testing_activity( code => 'FOOBAR' );
$aid_of_foobar = $foobar->aid;

#
# GET
#
req( $test, 403, 'demo', 'GET', $base );
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK', "GET $base 2" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "GET $base 3" );
is( $status->{count}, 9, "GET $base 4" );
ok( exists $status->{payload}, "GET $base 5" );
is( scalar @{ $status->payload }, 9, "GET $base 6" );
#
# - testing activity is present
ok( scalar( grep { $_->{code} eq 'FOOBAR'; } @{ $status->payload } ), "GET $base 7" );
#
# - disable the testing activity
$foobar = disable_testing_activity( code => $foobar->code );
ok( $foobar->disabled, "$base testing activity is really disabled 1" );
#
# - there is now one less in GET $base payload
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
is( $status->{count}, 8 );
ok( exists $status->{payload} );
is( scalar @{ $status->payload }, 8 );
#
# - and testing activity is absent
ok( ! scalar( grep { $_->{code} eq 'FOOBAR'; } @{ $status->payload } ), "GET $base 7" );

#
# PUT, POST, DELETE
#
req( $test, 405, 'demo', 'PUT', $base );
req( $test, 405, 'active', 'PUT', $base );
req( $test, 405, 'root', 'PUT', $base );
req( $test, 405, 'demo', 'POST', $base );
req( $test, 405, 'active', 'POST', $base );
req( $test, 405, 'root', 'POST', $base );
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'active', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );


#=============================
# "activity/all/disabled" resource
#=============================
$base = 'activity/all/disabled';
docu_check($test, $base);

#
# GET
#
# - fail 403 as demo
req( $test, 403, 'demo', 'GET', $base );
#
# - succeed as root
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK', "GET $base 2" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "GET $base 3" );
# count is 9 with disabled FOOBAR activity
is( $status->{count}, 9, "GET $base 4" ); 
ok( exists $status->{payload}, "GET $base 5" );
is( scalar @{ $status->payload }, 9, "GET $base 6" );
#
# - test that we get the disabled activity
ok( scalar( grep { $_->{code} eq 'FOOBAR'; } @{ $status->payload } ), "GET $base 7" );


#
# PUT, POST, DELETE
#
req( $test, 405, 'demo', 'PUT', $base );
req( $test, 405, 'active', 'PUT', $base );
req( $test, 405, 'root', 'PUT', $base );
req( $test, 405, 'demo', 'POST', $base );
req( $test, 405, 'active', 'POST', $base );
req( $test, 405, 'root', 'POST', $base );
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'active', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );

# - delete the disabled testing activity here
delete_testing_activity( $aid_of_foobar );


#=============================
# 'activity/code' resource
#=============================
$base = 'activity/code';
docu_check($test, "$base");

#
# GET, PUT
#
req( $test, 405, 'demo', 'GET', $base );
req( $test, 405, 'active', 'GET', $base );
req( $test, 405, 'root', 'GET', $base );
req( $test, 405, 'demo', 'PUT', $base );
req( $test, 405, 'active', 'PUT', $base );
req( $test, 405, 'root', 'PUT', $base );

#
# POST
#
#
# - test if expected behavior behaves as expected (insert)
$activity_obj = '{ "code" : "FOOWANG", "long_desc" : "wang wang wazoo", "disabled" : "f" }';
req( $test, 403, 'demo', 'POST', $base, $activity_obj );
req( $test, 403, 'active', 'POST', $base, $activity_obj );
$status = req( $test, 200, 'root', 'POST', $base, $activity_obj );
is( $status->level, 'OK', "POST $base 4" );
is( $status->code, 'DOCHAZKA_CUD_OK', "POST $base 5" );
my $aid_of_foowang = $status->payload->{'aid'};
#
# - test if expected behavior behaves as expected (update)
$activity_obj = '{ "code" : "FOOWANG", "remark" : "this is only a test" }';
req( $test, 403, 'demo', 'POST', $base, $activity_obj );
req( $test, 403, 'active', 'POST', $base, $activity_obj );
$status = req( $test, 200, 'root', 'POST', $base, $activity_obj );
is( $status->level, 'OK', "POST $base 4" );
is( $status->code, 'DOCHAZKA_CUD_OK', "POST $base 5" );
is( $status->payload->{'remark'}, 'this is only a test', "POST $base 6" );
is( $status->payload->{'long_desc'}, 'wang wang wazoo', "POST $base 7" );
#
# - throw a couple curve balls
$weirded_object = '{ "copious_turds" : 555, "long_desc" : "wang wang wazoo", "disabled" : "f" }';
$status = req( $test, 200, 'root', 'POST', $base, $weirded_object );
is( $status->level, 'ERR', "POST $base 8" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "POST $base 9" );
#
$no_closing_bracket = '{ "copious_turds" : 555, "long_desc" : "wang wang wazoo", "disabled" : "f"';
req( $test, 400, 'root', 'POST', $base, $no_closing_bracket );
#
$weirded_object = '{ "code" : "!!!!!", "long_desc" : "down it goes" }';
$status = req( $test, 200, 'root', 'POST', $base, $weirded_object );
is( $status->level, 'ERR', "POST $base 13" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "POST $base 14" );
like( $status->text, qr/check constraint "kosher_code"/, "POST $base 15" );

delete_testing_activity( $aid_of_foowang );

#
# DELETE
#
foreach my $user ( qw( demo active root ) ) {
    req( $test, 405, $user, 'DELETE', $base ); 
}




#=============================
# 'activity/code/:code' resource
#=============================
$base = 'activity/code';
docu_check($test, "$base/:code");

# insert an activity 
$foobar = create_testing_activity( code => 'FOOBAR', remark => 'bazblat' );
$aid_of_foobar = $foobar->aid;

#
# GET
#
# - insufficient privlevel
req( $test, 403, 'demo', 'GET', "$base/WORK" ); # get code 1
#
# - positive test for WORK activity
$status = req( $test, 200, 'root', 'GET', "$base/WORK" ); # get code 1
is( $status->level, "OK", "GET $base/:code 2" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "GET $base/:code 3" );
is_deeply( $status->payload, {
    aid => 1,
    code => 'WORK',
    long_desc => 'Work',
    remark => 'dbinit',
    disabled => 0,
}, "GET $base/:code 4" );
#
# - positive test with FOOBAR activity we created above
$status = req( $test, 200, 'root', 'GET', "$base/FOOBAR" );
is( $status->level, "OK", "GET $base/:code 5" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "GET $base/:code 6" );
is_deeply( $status->payload, {
    aid => $aid_of_foobar,
    code => 'FOOBAR',
    long_desc => undef,
    remark => 'bazblat',
    disabled => 0,
}, "GET $base/:code 7" );
#
# - get a non-existent code
$status = req( $test, 200, 'root', 'GET', "$base/jj" );
is( $status->level, 'NOTICE', "GET $base/:code 9" );
is( $status->code, 'DISPATCH_CODE_DOES_NOT_EXIST', "GET $base/:code 10" );
#
# - get an invalid code
$status = req( $test, 200, 'root', 'GET', "$base/!!! !134@@" );
is( $status->level, 'NOTICE', "GET $base/:code 12" );
is( $status->code, 'DISPATCH_CODE_DOES_NOT_EXIST', "GET $base/:code 13" );
#

#
# PUT
# 
$activity_obj = '{ "code" : "FOOBAR", "long_desc" : "baz waz wazoo", "remark" : "Full of it", "disabled" : "f" }';
# - test with demo fail 403
req( $test, 403, 'demo', 'PUT', "$base/FOOBAR", $activity_obj );
req( $test, 403, 'active', 'PUT', "$base/FOOBAR", $activity_obj );
#
# - test with root success
$status = req( $test, 200, 'root', 'PUT', "$base/FOOBAR", $activity_obj );
is( $status->level, "OK", "PUT $base/:code 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/:code 4" );
#
# - test without any content body
req( $test, 403, 'demo', 'PUT', "$base/FOOBAR" );
req( $test, 403, 'active', 'PUT', "$base/FOOBAR" );
#
# - test as root no request body
$status = req( $test, 200, 'root', 'PUT', "$base/FOOBAR" );
is( $status->level, 'ERR', "PUT $base/:aid 10" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "PUT $base/:aid 11" );
#
# - test as root fail invalid JSON
req( $test, 400, 'root', 'PUT', "$base/$aid_of_foobar", '{ asdf' );
#
# - test as root fail invalid code
$status = req( $test, 200, 'root', 'PUT', "$base/!!!!", '{ "legal":"json" }' );
is( $status->level, 'ERR', "PUT $base/:aid 14" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "PUT $base/:aid 15" );
#
# - with valid JSON that is not what we are expecting
$status = req( $test, 200, 'root', 'PUT', "$base/FOOBAR", '0' );
is( $status->level, 'ERR', "PUT $base/:aid 18" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "PUT $base/:aid 19" );
#
# - update with combination of valid and invalid properties
$status = req( $test, 200, 'root', 'PUT', "$base/FOOBAR", 
    '{ "nick":"FOOBAR", "remark":"Nothing much", "sister":"willy\'s" }' );
is( $status->level, 'OK', "PUT $base/:aid 21" );
is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/:aid 22" );
is( $status->payload->{'remark'}, "Nothing much", "PUT $base/:aid 23" );
ok( ! exists( $status->payload->{'nick'} ), "PUT $base/:aid 24" );
ok( ! exists( $status->payload->{'sister'} ), "PUT $base/:aid 25" );
#
# - insert with combination of valid and invalid properties
$status = req( $test, 200, 'root', 'PUT', "$base/FOOBARPUS", 
    '{ "nick":"FOOBAR", "remark":"Nothing much", "sister":"willy\'s" }' );
is( $status->level, 'OK', "PUT $base/:aid 27" );
is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/:aid 28" );
is( $status->payload->{'remark'}, "Nothing much", "PUT $base/:aid 29" );
ok( ! exists( $status->payload->{'nick'} ), "PUT $base/:aid 30" );
ok( ! exists( $status->payload->{'sister'} ), "PUT $base/:aid 31" );

#
# POST
#
req( $test, 405, 'demo', 'POST', "$base/WORK" );
req( $test, 405, 'active', 'POST', "$base/WORK" );
req( $test, 405, 'root', 'POST', "$base/WORK" );

#
# DELETE
#
# - test with demo fail 403
req( $test, 403, 'demo', 'DELETE', "$base/1" );
#
# - test with root success
#diag( "DELETE $base/FOOBAR" );
$status = req( $test, 200, 'root', 'DELETE', "$base/FOOBAR" );
is( $status->level, 'OK', "DELETE $base/FOOBAR 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "DELETE $base/FOOBAR 4" );
#
# - really gone
$status = req( $test, 200, 'root', 'GET', "$base/FOOBAR" );
is( $status->level, 'NOTICE', "DELETE $base/FOOBAR 6" );
is( $status->code, 'DISPATCH_CODE_DOES_NOT_EXIST', "DELETE $base/FOOBAR 7" );
#
# - test with root fail invalid code
$status = req( $test, 200, 'root', 'DELETE', "$base/!!!" );
is( $status->level, 'NOTICE', "DELETE $base/FOOBAR 8" );
#diag( $status->code . " " . $status->text );
is( $status->code, 'DISPATCH_CODE_DOES_NOT_EXIST', "DELETE $base/FOOBAR 9" );
#
# - go ahead and delete FOOBARPUS, too
$status = req( $test, 200, 'root', 'DELETE', "$base/foobarpus" );
is( $status->level, 'OK', "DELETE $base/foobarpus 2" );
is( $status->code, 'DOCHAZKA_CUD_OK', "DELETE $base/foobarpus 3" );

delete_active_employee( $test );


#=============================
# "activity/help" resource
#=============================
$base = "activity/help";
docu_check($test, "activity/help");
#
# GET
#
$status = req( $test, 200, 'demo', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );
#
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 3 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );

#
# PUT
#
$status = req( $test, 200, 'demo', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );
# 
$status = req( $test, 200, 'root', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
#ok( keys %{ $status->payload->{'resources'} } >= 3 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );

#
# POST
#
$status = req( $test, 200, 'demo', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );
#
$status = req( $test, 200, 'root', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );

#
# DELETE
#
$status = req( $test, 200, 'demo', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );
#
$status = req( $test, 200, 'root', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );

done_testing;
