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
    $res = $test->request( req_json_root PUT => $resource, undef, '{ "disabled" : true }' );
    is( $res->code, 200, "Disable Testing Activity 1" );
    $status = status_from_json( $res->content );
    ok( $status->ok, "Disable Testing Activity 2" );
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
# GET
#
$res = $test->request( req_demo GET => "$base" );
is( $res->code, 405, "GET $base 1" );
$res = $test->request( req_active GET => "$base" );
is( $res->code, 405, "GET $base 1" );
$res = $test->request( req_root GET => "$base" );
is( $res->code, 405, "GET $base 2" );

#
# PUT
#
$res = $test->request( req_demo PUT => "$base" );
is( $res->code, 405, "PUT $base 1" );
$res = $test->request( req_active PUT => "$base" );
is( $res->code, 405, "PUT $base 1" );
$res = $test->request( req_root PUT => "$base" );
is( $res->code, 405, "PUT $base 2" );

#
# POST
#

my $foowop = create_testing_activity( code => 'FOOWOP' );
my $aid_of_foowop = $foowop->aid;

# 
# - test if expected behavior behaves as expected (update)
my $activity_obj = '{ "aid" : ' . $aid_of_foowop . ', "long_desc" : "wop wop ng", "remark" : "puppy" }';
$res = $test->request( req_json_demo POST => "$base", undef, $activity_obj );
is( $res->code, 403, "POST $base 1" );
$res = $test->request( req_json_active POST => "$base", undef, $activity_obj );
is( $res->code, 403, "POST $base 2" );
$res = $test->request( req_json_root POST => "$base", undef, $activity_obj );
is( $res->code, 200, "POST $base 3" );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok, "POST $base 4" );
is( $status->code, 'DOCHAZKA_CUD_OK', "POST $base 5" );
is( $status->payload->{'remark'}, 'puppy', "POST $base 6" );
is( $status->payload->{'long_desc'}, 'wop wop ng', "POST $base 7" );
#
# - non-existent AID and also out of range
$activity_obj = '{ "aid" : 3434342342342, "long_desc" : 3434341, "remark" : 34334342 }';
$res = $test->request( req_json_root POST => "$base", undef, $activity_obj );
is( $res->code, 200, "POST $base 7.1" );
is_valid_json( $res->content, "POST $base 7.2" );
$status = status_from_json( $res->content );
is( $status->level, "ERR", "POST $base 7.3" );
is( $status->code, "DOCHAZKA_DBI_ERR", "POST $base 7.4" );
like( $status->text, qr/out of range for type integer/, "POST $base 7.5" );
#
# - non-existent AID
$activity_obj = '{ "aid" : 342342342, "long_desc" : 3434341, "remark" : 34334342 }';
$res = $test->request( req_json_root POST => "$base", undef, $activity_obj );
is( $res->code, 200, "POST $base 7.1" );
is_valid_json( $res->content, "POST $base 7.2" );
$status = status_from_json( $res->content );
is( $status->level, "NOTICE", "POST $base 7.3" );
is( $status->code, "DISPATCH_AID_DOES_NOT_EXIST", "POST $base 7.4" );
#
# - throw a couple curve balls
my $weirded_object = '{ "copious_turds" : 555, "long_desc" : "wang wang wazoo", "disabled" : "f" }';
$res = $test->request( req_json_root POST => "$base", undef, $weirded_object );
is( $res->code, 200, "POST $base 6" );
is_valid_json( $res->content, "POST $base 7" );
$status = status_from_json( $res->content );
is( $status->level, 'ERR', "POST $base 8" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "POST $base 9" );
#
my $no_closing_bracket = '{ "copious_turds" : 555, "long_desc" : "wang wang wazoo", "disabled" : "f"';
$res = $test->request( req_json_root POST => "$base", undef, $no_closing_bracket );
is( $res->code, 400, "POST $base 10" );
#
$weirded_object = '{ "aid" : "!!!!!", "long_desc" : "down it goes" }';
$res = $test->request( req_json_root POST => "$base", undef, $weirded_object );
is( $res->code, 200, "POST $base 11" );
is_valid_json( $res->content, "POST $base 12" );
$status = status_from_json( $res->content );
is( $status->level, 'ERR', "POST $base 13" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "POST $base 14" );
like( $status->text, qr/invalid input syntax for integer/, "POST $base 15" );

delete_testing_activity( $aid_of_foowop );



#
# DELETE
#
$res = $test->request( req_demo DELETE => "$base" );
is( $res->code, 405, "DELETE $base 1" );
$res = $test->request( req_active DELETE => "$base" );
is( $res->code, 405, "DELETE $base 1" );
$res = $test->request( req_root DELETE => "$base" );
is( $res->code, 405, "DELETE $base 2" );



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
# fail as demo 405
$res = $test->request( req_demo GET => "$base/1" ); # get AID 1
is( $res->code, 403, "GET $base/:aid 0" );
#
# succeed as root AID 1
$res = $test->request( req_active GET => "$base/1" ); # get AID 1
is( $res->code, 200, "GET $base/:aid 1" );
$status = status_from_json( $res->content );
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
$res = $test->request( req_active GET => "$base/jj" );
is( $res->code, 200, "GET $base/:aid 5" );
$status = status_from_json( $res->content );
is( $status->level, 'ERR', "GET $base/:aid 6" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "GET $base/:aid 7" );
like( $status->text, qr/invalid input syntax for integer/, "GET $base/:aid 8" );
#
# fail non-existent AID
$res = $test->request( req_active GET => "$base/444" );
is( $res->code, 200, "GET $base/:aid 9" );
$status = status_from_json( $res->content );
#diag( "$base " . $status->code );
is( $status->level, 'NOTICE', "GET $base/:aid 10" );
is( $status->code, 'DISPATCH_AID_DOES_NOT_EXIST', "GET $base/:aid 11" );
#
# succeed disabled AID
$res = $test->request( req_active GET => "$base/$aid_of_foobar" );
is( $res->code, 200, "GET $base/:aid 12" );
$status = status_from_json( $res->content );
#diag( "$base " . $status->code );
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
$res = $test->request( req_json_active PUT => "$base/$aid_of_foobar", undef, $activity_obj );
is( $res->code, 403, "PUT $base/:aid 1" );
#
# - test with root success
$res = $test->request( req_json_root PUT => "$base/$aid_of_foobar", undef, $activity_obj );
is( $res->code, 200, "PUT $base/:aid 2" );
$status = status_from_json( $res->content );
ok( $status->ok, "PUT $base/:aid 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/:aid 4" );
is( ref( $status->payload ), 'HASH', "PUT $base/:aid 5" );
$foobar = App::Dochazka::REST::Model::Activity->spawn( $status->payload );
is( $foobar->long_desc, "The bar of foo", "PUT $base/:aid 5" );
is( $foobar->remark, "Change is good", "PUT $base/:aid 6" );
ok( $foobar->disabled, "PUT $base/:aid 7" );
#
# - test with root no request body
$res = $test->request( req_json_root PUT => "$base/$aid_of_foobar" );
is( $res->code, 200, "PUT $base/:aid 8" );
$status = status_from_json( $res->content );
is( $status->level, 'ERR', "PUT $base/:aid 9" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "PUT $base/:aid 10" );
#
# - test with root fail invalid JSON
$res = $test->request( req_json_root PUT => "$base/$aid_of_foobar", undef, '{ asdf' );
is( $res->code, 400, "PUT $base/:aid 13" );
#
# - test with root fail invalid AID
$res = $test->request( req_json_root PUT => "$base/asdf", undef, '{ "legal":"json" }' );
is( $res->code, 200, "PUT $base/:aid 14" );
$status = status_from_json( $res->content );
is( $status->level, 'ERR', "PUT $base/:aid 15" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "PUT $base/:aid 16" );
like( $status->text, qr/invalid input syntax for integer/, "PUT $base/:aid 17" );
#
# - with valid JSON that is not what we are expecting
$res = $test->request( req_json_root PUT => "$base/$aid_of_foobar", undef, '0' );
is( $res->code, 200, "PUT $base/:aid 18" );
$status = status_from_json( $res->content );
is( $status->level, 'ERR', "PUT $base/:aid 19" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "PUT $base/:aid 20" );
#
# - with valid JSON that has some bogus properties
$res = $test->request( req_json_root PUT => "$base/$aid_of_foobar", undef, '{ "legal":"json" }' );
is( $res->code, 200, "PUT $base/:aid 21" );
$status = status_from_json( $res->content );
is( $status->level, 'ERR', "PUT $base/:aid 22" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "PUT $base/:aid 23" );

#
# POST
#
$res = $test->request( req_json_demo POST => "$base/1" );
is( $res->code, 405, "POST $base/:aid 1" );
$res = $test->request( req_json_active POST => "$base/1" );
is( $res->code, 405, "POST $base/:aid 1" );
$res = $test->request( req_json_root POST => "$base/1" );
is( $res->code, 405, "POST $base/:aid 2" );

#
# DELETE
#
# - test with demo fail 403
$res = $test->request( req_json_demo DELETE => "$base/1" );
is( $res->code, 403, "DELETE $base/:aid 1" );
#
# - test with active fail 403
$res = $test->request( req_json_active DELETE => "$base/1" );
is( $res->code, 403, "DELETE $base/:aid 1" );
#
# - test with root success
#diag( "DELETE $base/$aid_of_foobar" );
$res = $test->request( req_json_root DELETE => "$base/$aid_of_foobar" );
is( $res->code, 200, "DELETE $base/:aid 2" );
$status = status_from_json( $res->content );
ok( $status->ok, "DELETE $base/:aid 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "DELETE $base/:aid 4" );
#
# - really gone
$res = $test->request( req_json_root GET => "$base/$aid_of_foobar" );
is( $res->code, 200, "DELETE $base/:aid 5" );
$status = status_from_json( $res->content );
is( $status->level, 'NOTICE', "DELETE $base/:aid 6" );
is( $status->code, 'DISPATCH_AID_DOES_NOT_EXIST', "DELETE $base/:aid 7" );
#
# - test with root fail invalid AID
$res = $test->request( req_json_root DELETE => "$base/asd" );
is( $res->code, 200, "DELETE $base/:aid 7" );
$status = status_from_json( $res->content );
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
$foobar = disable_testing_activity( code => $foobar->code );
ok( $foobar->disabled, "$base testing activity is really disabled 1" );
$aid_of_foobar = $foobar->aid;

#
# GET
#
$res = $test->request( req_demo GET => $base );
is( $res->code, 403, "GET $base 1.1" );
$res = $test->request( req_root GET => $base );
is( $res->code, 200, "GET $base 1.2" );
$status = status_from_json( $res->content );
#diag( "$base " . $status->code );
ok( $status->ok, "GET $base 2" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "GET $base 3" );
is( $status->{count}, 8, "GET $base 4" );
ok( exists $status->payload->{activities}, "GET $base 5" );
is( scalar @{ $status->payload->{activities} }, 8, "GET $base 6" );
#
# - the disabled activity we just created is not shown
ok( ! scalar( grep { $_->{code} eq 'FOOBAR'; } @{ $status->payload->{activities} } ), "GET $base 7" );

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
# "activity/all/disabled" resource
#=============================
$base = 'activity/all/disabled';
docu_check($test, $base);

#
# GET
#
$res = $test->request( req_root GET => $base );
is( $res->code, 200, "GET $base 1" );
$status = status_from_json( $res->content );
#diag( "$base " . $status->code );
ok( $status->ok, "GET $base 2" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "GET $base 3" );
# count is 9 with disabled FOOBAR activity
is( $status->{count}, 9, "GET $base 4" ); 
ok( exists $status->payload->{activities}, "GET $base 5" );
is( scalar @{ $status->payload->{activities} }, 9, "GET $base 6" );
#
# - test that we get the disabled activity
ok( scalar( grep { $_->{code} eq 'FOOBAR'; } @{ $status->payload->{activities} } ), "GET $base 7" );

#
$res = $test->request( req_demo GET => $base );
is( $res->code, 403, "GET $base 8" );

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

# - delete the disabled testing activity here
delete_testing_activity( $aid_of_foobar );


#=============================
# 'activity/code' resource
#=============================
$base = 'activity/code';
docu_check($test, "$base");

#
# GET
#
$res = $test->request( req_demo GET => "$base" );
is( $res->code, 405, "GET $base 1" );
$res = $test->request( req_active GET => "$base" );
is( $res->code, 405, "GET $base 2" );
$res = $test->request( req_root GET => "$base" );
is( $res->code, 405, "GET $base 3" );

#
# PUT
#
$res = $test->request( req_demo PUT => "$base" );
is( $res->code, 405, "PUT $base 1" );
$res = $test->request( req_active PUT => "$base" );
is( $res->code, 405, "PUT $base 2" );
$res = $test->request( req_root PUT => "$base" );
is( $res->code, 405, "PUT $base 3" );

#
# POST
#
#
# - test if expected behavior behaves as expected (insert)
$activity_obj = '{ "code" : "FOOWANG", "long_desc" : "wang wang wazoo", "disabled" : "f" }';
$res = $test->request( req_json_demo POST => "$base", undef, $activity_obj );
is( $res->code, 403, "POST $base 1" );
$res = $test->request( req_json_active POST => "$base", undef, $activity_obj );
is( $res->code, 403, "POST $base 2" );
$res = $test->request( req_json_root POST => "$base", undef, $activity_obj );
is( $res->code, 200, "POST $base 3" );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok, "POST $base 4" );
is( $status->code, 'DOCHAZKA_CUD_OK', "POST $base 5" );
my $aid_of_foowang = $status->payload->{'aid'};
#
# - test if expected behavior behaves as expected (update)
$activity_obj = '{ "code" : "FOOWANG", "remark" : "this is only a test" }';
$res = $test->request( req_json_demo POST => "$base", undef, $activity_obj );
is( $res->code, 403, "POST $base 1" );
$res = $test->request( req_json_active POST => "$base", undef, $activity_obj );
is( $res->code, 403, "POST $base 2" );
$res = $test->request( req_json_root POST => "$base", undef, $activity_obj );
is( $res->code, 200, "POST $base 3" );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok, "POST $base 4" );
is( $status->code, 'DOCHAZKA_CUD_OK', "POST $base 5" );
is( $status->payload->{'remark'}, 'this is only a test', "POST $base 6" );
is( $status->payload->{'long_desc'}, 'wang wang wazoo', "POST $base 7" );
#
# - throw a couple curve balls
$weirded_object = '{ "copious_turds" : 555, "long_desc" : "wang wang wazoo", "disabled" : "f" }';
$res = $test->request( req_json_root POST => "$base", undef, $weirded_object );
is( $res->code, 200, "POST $base 6" );
is_valid_json( $res->content, "POST $base 7" );
$status = status_from_json( $res->content );
is( $status->level, 'ERR', "POST $base 8" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "POST $base 9" );
#
$no_closing_bracket = '{ "copious_turds" : 555, "long_desc" : "wang wang wazoo", "disabled" : "f"';
$res = $test->request( req_json_root POST => "$base", undef, $no_closing_bracket );
is( $res->code, 400, "POST $base 10" );
#
$weirded_object = '{ "code" : "!!!!!", "long_desc" : "down it goes" }';
$res = $test->request( req_json_root POST => "$base", undef, $weirded_object );
is( $res->code, 200, "POST $base 11" );
is_valid_json( $res->content, "POST $base 12" );
$status = status_from_json( $res->content );
is( $status->level, 'ERR', "POST $base 13" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "POST $base 14" );
like( $status->text, qr/check constraint "kosher_code"/, "POST $base 15" );

delete_testing_activity( $aid_of_foowang );

#
# DELETE
#
$res = $test->request( req_demo DELETE => "$base" );
is( $res->code, 405, "DELETE $base 1" );
$res = $test->request( req_active DELETE => "$base" );
is( $res->code, 405, "DELETE $base 2" );
$res = $test->request( req_root DELETE => "$base" );
is( $res->code, 405, "DELETE $base 3" );




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
$res = $test->request( req_demo GET => "$base/WORK" ); # get code 1
is( $res->code, 403, "GET $base/:code 0" );
# - positive test for WORK activity
$res = $test->request( req_root GET => "$base/WORK" ); # get code 1
is( $res->code, 200, "GET $base/:code 1" );
$status = status_from_json( $res->content );
ok( $status->ok, "GET $base/:code 2" );
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
$res = $test->request( req_root GET => "$base/FOOBAR" );
is( $res->code, 200, "GET $base/:code 4" );
$status = status_from_json( $res->content );
ok( $status->ok, "GET $base/:code 5" );
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
$res = $test->request( req_root GET => "$base/jj" );
is( $res->code, 200, "GET $base/:code 8" );
$status = status_from_json( $res->content );
#diag( "$base " . $status->code );
is( $status->level, 'NOTICE', "GET $base/:code 9" );
is( $status->code, 'DISPATCH_CODE_DOES_NOT_EXIST', "GET $base/:code 10" );
#
# - get an invalid code
$res = $test->request( req_root GET => "$base/!!! !134@@" );
is( $res->code, 200, "GET $base/:code 11" );
$status = status_from_json( $res->content );
#diag( "$base " . $status->code );
is( $status->level, 'NOTICE', "GET $base/:code 12" );
is( $status->code, 'DISPATCH_CODE_DOES_NOT_EXIST', "GET $base/:code 13" );
#

#
# PUT
# 
$activity_obj = '{ "code" : "FOOBAR", "long_desc" : "baz waz wazoo", "remark" : "Full of it", "disabled" : "f" }';
# - test with demo fail 405
$res = $test->request( req_json_demo PUT => "$base/FOOBAR", undef, $activity_obj );
is( $res->code, 403, "PUT $base/:code 1" );
#
# - test with root success
$res = $test->request( req_json_root PUT => "$base/FOOBAR", undef, $activity_obj );
is( $res->code, 200, "PUT $base/:code 2" );
$status = status_from_json( $res->content );
ok( $status->ok, "PUT $base/:code 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/:code 4" );
#
# - test without any content body
$res = $test->request( req_json_demo PUT => "$base/FOOBAR" );
is( $res->code, 403, "PUT $base/:code 5" );
#
# - test with root no request body
$res = $test->request( req_json_root PUT => "$base/FOOBAR" );
is( $res->code, 200, "PUT $base/:aid 9" );
$status = status_from_json( $res->content );
is( $status->level, 'ERR', "PUT $base/:aid 10" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "PUT $base/:aid 11" );
#
# - test with root fail invalid JSON
$res = $test->request( req_json_root PUT => "$base/$aid_of_foobar", undef, '{ asdf' );
is( $res->code, 400, "PUT $base/:aid 12" );
#
# - test with root fail invalid code
$res = $test->request( req_json_root PUT => "$base/!!!!", undef, '{ "legal":"json" }' );
is( $res->code, 200, "PUT $base/:aid 13" );
$status = status_from_json( $res->content );
is( $status->level, 'ERR', "PUT $base/:aid 14" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "PUT $base/:aid 15" );
#
# - with valid JSON that is not what we are expecting
$res = $test->request( req_json_root PUT => "$base/FOOBAR", undef, '0' );
is( $res->code, 200, "PUT $base/:aid 17" );
$status = status_from_json( $res->content );
is( $status->level, 'ERR', "PUT $base/:aid 18" );
is( $status->code, 'DOCHAZKA_BAD_INPUT', "PUT $base/:aid 19" );
#
# - update with combination of valid and invalid properties
$res = $test->request( req_json_root PUT => "$base/FOOBAR", undef,
    '{ "nick":"FOOBAR", "remark":"Nothing much", "sister":"willy\'s" }' );
is( $res->code, 200, "PUT $base/:aid 20" );
$status = status_from_json( $res->content );
is( $status->level, 'OK', "PUT $base/:aid 21" );
is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/:aid 22" );
is( $status->payload->{'remark'}, "Nothing much", "PUT $base/:aid 23" );
ok( ! exists( $status->payload->{'nick'} ), "PUT $base/:aid 24" );
ok( ! exists( $status->payload->{'sister'} ), "PUT $base/:aid 25" );
#
# - insert with combination of valid and invalid properties
$res = $test->request( req_json_root PUT => "$base/FOOBARPUS", undef,
    '{ "nick":"FOOBAR", "remark":"Nothing much", "sister":"willy\'s" }' );
is( $res->code, 200, "PUT $base/:aid 26" );
$status = status_from_json( $res->content );
is( $status->level, 'OK', "PUT $base/:aid 27" );
is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/:aid 28" );
is( $status->payload->{'remark'}, "Nothing much", "PUT $base/:aid 29" );
ok( ! exists( $status->payload->{'nick'} ), "PUT $base/:aid 30" );
ok( ! exists( $status->payload->{'sister'} ), "PUT $base/:aid 31" );

#
# POST
#
$res = $test->request( req_json_demo POST => "$base/WORK" );
is( $res->code, 405, "POST $base 1" );
$res = $test->request( req_json_root POST => "$base/WORK" );
is( $res->code, 405, "POST $base 2" );

#
# DELETE
#
# - test with demo fail 403
$res = $test->request( req_json_demo DELETE => "$base/1" );
is( $res->code, 403, "DELETE $base/FOOBAR 1" );
#
# - test with root success
#diag( "DELETE $base/FOOBAR" );
$res = $test->request( req_json_root DELETE => "$base/FOOBAR" );
is( $res->code, 200, "DELETE $base/FOOBAR 2" );
$status = status_from_json( $res->content );
ok( $status->ok, "DELETE $base/FOOBAR 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "DELETE $base/FOOBAR 4" );
#
# - really gone
$res = $test->request( req_json_root GET => "$base/FOOBAR" );
is( $res->code, 200, "DELETE $base/FOOBAR 5" );
$status = status_from_json( $res->content );
is( $status->level, 'NOTICE', "DELETE $base/FOOBAR 6" );
is( $status->code, 'DISPATCH_CODE_DOES_NOT_EXIST', "DELETE $base/FOOBAR 7" );
#
# - test with root fail invalid code
$res = $test->request( req_json_root DELETE => "$base/!!!" );
is( $res->code, 200, "DELETE $base/FOOBAR 7" );
$status = status_from_json( $res->content );
is( $status->level, 'NOTICE', "DELETE $base/FOOBAR 8" );
#diag( $status->code . " " . $status->text );
is( $status->code, 'DISPATCH_CODE_DOES_NOT_EXIST', "DELETE $base/FOOBAR 9" );
#
# - go ahead and delete FOOBARPUS, too
$res = $test->request( req_json_root DELETE => "$base/foobarpus" );
is( $res->code, 200, "DELETE $base/foobarpus 1" );
$status = status_from_json( $res->content );
ok( $status->ok, "DELETE $base/foobarpus 2" );
is( $status->code, 'DOCHAZKA_CUD_OK', "DELETE $base/foobarpus 3" );

delete_active_employee( $test );


#=============================
# "activity/help" resource
#=============================
docu_check($test, "activity/help");
#
# GET
#
$res = $test->request( req_demo GET => '/activity/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );
#
$res = $test->request( req_root GET => '/activity/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 3 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );

#
# PUT
#
$res = $test->request( req_json_demo PUT => '/activity/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );
# 
$res = $test->request( req_json_root PUT => '/activity/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
#ok( keys %{ $status->payload->{'resources'} } >= 3 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );

#
# POST
#
$res = $test->request( req_json_demo POST => '/activity/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );

#
# DELETE
#
$res = $test->request( req_json_demo DELETE => '/activity/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );
#
$res = $test->request( req_json_root DELETE => '/activity/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'activity/help'} );

done_testing;