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
# test interval resources
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

# create testing employees with 'active' and 'inactive' privlevels
my $eid_active = create_active_employee( $test );
create_inactive_employee( $test );

# get AID of WORK
$status = req( $test, 200, 'root', 'GET', 'activity/code/WORK' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( $status->{'payload'} );
ok( $status->{'payload'}->{'aid'} );
is( $status->{'payload'}->{'code'}, 'WORK' );
my $aid_of_work = $status->{'payload'}->{'aid'};

# create a testing interval
$status = req( $test, 200, 'root', 'POST', 'interval/new', <<"EOH" );
{ "eid" : $eid_active, "aid" : $aid_of_work, "intvl" : "[2014-10-01 08:00, 2014-10-01 12:00)" }
EOH
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
ok( $status->{'payload'} );
is( $status->{'payload'}->{'aid'}, $aid_of_work );
ok( $status->{'payload'}->{'iid'} );
my $test_iid = $status->{'payload'}->{'iid'};

#=============================
# "interval/eid/:eid/:tsrange" resource
#=============================
my $base = 'interval/eid';
docu_check($test, "$base/:eid/:tsrange");

#
# PUT, POST, DELETE
#
foreach my $method ( qw( PUT POST DELETE ) ) {
    foreach my $user ( 'demo', 'root', 'WAMBLE owdkmdf 5**' ) {
        req( $test, 405, $user, $method, "$base/2/[,)" );
    }
}


#=============================
# "interval/help" resource
#=============================
$base = "interval/help";
docu_check($test, $base);

#
# GET
#
$status = req( $test, 200, 'demo', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'interval/help'} );
ok( ! exists $status->payload->{'resources'}->{'interval/iid'} );
ok( ! exists $status->payload->{'resources'}->{'interval/iid/:iid'} );
#
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 3 );
ok( exists $status->payload->{'resources'}->{'interval/help'} );
ok( ! exists $status->payload->{'resources'}->{'interval/iid'} );  # POST only
ok( exists $status->payload->{'resources'}->{'interval/iid/:iid'} );
#
$status = req( $test, 200, 'active', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 3 );
ok( exists $status->payload->{'resources'}->{'interval/help'} );
ok( ! exists $status->payload->{'resources'}->{'interval/iid'} );  # POST only
ok( exists $status->payload->{'resources'}->{'interval/iid/:iid'} );

#
# PUT
#
$status = req( $test, 200, 'demo', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'interval/help'} );
# 
$status = req( $test, 200, 'root', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
#ok( keys %{ $status->payload->{'resources'} } >= 3 );
ok( exists $status->payload->{'resources'}->{'interval/help'} );

#
# POST
#
$status = req( $test, 200, 'demo', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'interval/help'} );
ok( ! exists $status->payload->{'resources'}->{'interval/iid'} );  # admin only
#
$status = req( $test, 200, 'root', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'interval/help'} );
ok( exists $status->payload->{'resources'}->{'interval/iid'} );  # admin only

#
# DELETE
#
$status = req( $test, 200, 'demo', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'interval/help'} );
#
$status = req( $test, 200, 'root', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 1 );
ok( exists $status->payload->{'resources'}->{'interval/help'} );


#=============================
# "interval/iid" resource
#=============================
$base = 'interval/iid';
docu_check($test, "$base");

#
# GET, PUT
#
foreach my $method ( 'GET', 'PUT' ) {
    foreach my $user ( 'demo', 'active', 'root', 'WOMBAT5', 'WAMBLE owdkmdf 5**' ) {
        req( $test, 405, $user, $method, $base );
    }
}

#
# POST
#
# 
# - test if expected behavior behaves as expected (update)
my $int_obj = <<"EOH";
{ "iid" : $test_iid, "long_desc" : "Sharpening pencils" }
EOH
req( $test, 403, 'demo', 'POST', $base, $int_obj );
req( $test, 403, 'inactive', 'POST', $base, $int_obj );
$status = req( $test, 200, 'active', 'POST', $base, $int_obj );
is( $status->level, 'OK', "POST $base 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "POST $base 4" );
is( $status->payload->{'iid'}, $test_iid, "POST $base 5" );
is( $status->payload->{'remark'}, undef, "POST $base 6" );
is( $status->payload->{'long_desc'}, 'Sharpening pencils', "POST $base 7" );
#
# - non-existent IID and also out of range
$int_obj = '{ "iid" : 3434342342342, "long_desc" : 3434341, "remark" : 34334342 }';
$status = req( $test, 200, 'root', 'POST', $base, $int_obj );
is( $status->level, "ERR", "POST $base 7.3" );
is( $status->code, "DOCHAZKA_DBI_ERR", "POST $base 7.4" );
like( $status->text, qr/out of range for type integer/, "POST $base 7.5" );
#
# - non-existent IID
$int_obj = '{ "iid" : 342342342, "long_desc" : 3434341, "remark" : 34334342 }';
$status = req( $test, 200, 'root', 'POST', $base, $int_obj );
is( $status->level, "NOTICE", "POST $base 7.3" );
is( $status->code, "DISPATCH_IID_DOES_NOT_EXIST", "POST $base 7.4" );
#
# - throw a couple curve balls
my $weirded_object = '{ "copious_turds" : 555, "long_desc" : "wang wang wazoo", "disabled" : "f" }';
req( $test, 400, 'root', 'POST', $base, $weirded_object );
#
my $no_closing_bracket = '{ "copious_turds" : 555, "long_desc" : "wang wang wazoo", "disabled" : "f"';
req( $test, 400, 'root', 'POST', $base, $no_closing_bracket );
#
$weirded_object = '{ "iid" : "!!!!!", "long_desc" : "down it goes" }';
$status = req( $test, 200, 'root', 'POST', $base, $weirded_object );
is( $status->level, 'ERR', "POST $base 13" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "POST $base 14" );
like( $status->text, qr/invalid input syntax for integer/, "POST $base 15" );
#
# can a different active employee edit active's interval?
# - create testing employee 'bubba' with active privlevel
my $eid_bubba = create_testing_employee( nick => 'bubba', passhash => 'bubba' )->eid;
$status = req( $test, 200, 'root', 'POST', 'priv/history/nick/bubba', <<"EOH" );
{ "eid" : $eid_bubba, "priv" : "active", "effective" : "1967-06-17 00:00" }
EOH
is( $status->level, "OK" );
is( $status->code, "DOCHAZKA_CUD_OK" );
$status = req( $test, 200, 'root', 'GET', 'priv/nick/bubba' );
is( $status->level, "OK" );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV" );
ok( $status->{'payload'} );
is( $status->{'payload'}->{'priv'}, 'active' );
#
# - let bubba try to edit active's interval
req( $test, 403, 'bubba', 'POST', "interval/iid", <<"EOH" );
{ "iid" : $test_iid, "long_desc" : "And now it belongs to bubba!", "remark" : "mine" }
EOH

#
# DELETE
#
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );
req( $test, 405, 'WOMBAT5', 'DELETE', $base );



#=============================
# "interval/iid/:iid" resource
#=============================
$base = 'interval/iid';
docu_check($test, "$base/:iid");

#
# GET
#
# fail as demo 403
req( $test, 403, 'demo', 'GET', "$base/1" );
#
# succeed as active IID 1
$status = req( $test, 200, 'active', 'GET', "$base/1" );
ok( $status->ok, "GET $base/:iid 2" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "GET $base/:iid 3" );
ok( $status->{'payload'} );
is( $status->payload->{'iid'}, 1 );
ok( $status->payload->{'aid'} );
is( $status->payload->{'eid'}, $eid_active );
ok( $status->payload->{'intvl'} );
ok( $status->payload->{'long_desc'} );

#
# fail invalid IID
$status = req( $test, 200, 'active', 'GET', "$base/jj" );
is( $status->level, 'ERR', "GET $base/:iid 6" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "GET $base/:iid 7" );
like( $status->text, qr/invalid input syntax for integer/, "GET $base/:iid 8" );
#
## fail non-existent IID
$status = req( $test, 200, 'active', 'GET', "$base/444" );
is( $status->level, 'NOTICE', "GET $base/:iid 10" );
is( $status->code, 'DISPATCH_IID_DOES_NOT_EXIST', "GET $base/:iid 11" );

##
# PUT
## 
#$int_obj = '{ "code" : "FOOBAR", "long_desc" : "The bar of foo", "remark" : "Change is good" }';
## - test with demo fail 405
#req( $test, 403, 'active', 'PUT', "$base/$test_iid", $int_obj );
##
## - test with root success
#$status = req( $test, 200, 'root', 'PUT', "$base/$test_iid", $int_obj );
#is( $status->level, 'OK', "PUT $base/:iid 3" );
#is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/:iid 4" );
#is( ref( $status->payload ), 'HASH', "PUT $base/:iid 5" );
##
## - make an Activity object out of the payload
#$foobar = App::Dochazka::REST::Model::Activity->spawn( $status->payload );
#is( $foobar->long_desc, "The bar of foo", "PUT $base/:iid 5" );
#is( $foobar->remark, "Change is good", "PUT $base/:iid 6" );
#ok( $foobar->disabled, "PUT $base/:iid 7" );
#
# - test with root no request body
req( $test, 400, 'root', 'PUT', "$base/$test_iid" );
#
# - test with root fail invalid JSON
req( $test, 400, 'root', 'PUT', "$base/$test_iid", '{ asdf' );
#
# - test with root fail invalid IID
$status = req( $test, 200, 'root', 'PUT', "$base/asdf", '{ "legal":"json" }' );
is( $status->level, 'ERR', "PUT $base/:iid 15" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "PUT $base/:iid 16" );
like( $status->text, qr/invalid input syntax for integer/, "PUT $base/:iid 17" );
#
# - with valid JSON that is not what we are expecting (invalid IID)
$status = req( $test, 200, 'root', 'PUT', "$base/asdf", '0' );
is( $status->level, 'ERR', "PUT $base/:iid 19" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "PUT $base/:iid 16" );
like( $status->text, qr/invalid input syntax for integer/, "PUT $base/:iid 17" );
#
# - with valid JSON that is not what we are expecting (valid IID)
req( $test, 400, 'root', 'PUT', "$base/$test_iid", '0' );
#
# - with valid JSON that has some bogus properties
req( $test, 400, 'root', 'PUT', "$base/$test_iid", '{ "legal":"json" }' );

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
##
## - test with active fail 403
#req( $test, 403, 'active', 'DELETE', "$base/1" );
#
# - test with root success
#diag( "DELETE $base/$test_iid" );
$status = req( $test, 200, 'root', 'DELETE', "$base/$test_iid" );
is( $status->level, 'OK', "DELETE $base/:iid 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "DELETE $base/:iid 4" );
#
# - really gone
$status = req( $test, 200, 'active', 'GET', "$base/$test_iid" );
is( $status->level, 'NOTICE', "DELETE $base/:iid 6" );
is( $status->code, 'DISPATCH_IID_DOES_NOT_EXIST', "DELETE $base/:iid 7" );

# - test with root fail invalid IID
$status = req( $test, 200, 'root', 'DELETE', "$base/asd" );
is( $status->level, 'ERR', "DELETE $base/:iid 8" );
is( $status->code, 'DOCHAZKA_DBI_ERR', "DELETE $base/:iid 9" );
like( $status->text, qr/invalid input syntax for integer/, "DELETE $base/:iid 10" );


# delete the testing employees
delete_employee_by_nick( $test, 'active' );
delete_employee_by_nick( $test, 'inactive' );
delete_employee_by_nick( $test, 'bubba' );


#=============================
# "interval/new" resource
#=============================
$base = 'interval/new';
docu_check($test, $base);

#
# GET, PUT
#
foreach my $method ( 'GET', 'PUT' ) {
    foreach my $user ( 'demo', 'active', 'root', 'WOMBAT5', 'WAMBLE owdkmdf 5**' ) {
        req( $test, 405, $user, $method, $base );
    }
}

#
# DELETE
#
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );
req( $test, 405, 'WOMBAT5', 'DELETE', $base );


#=============================
# "interval/nick/:nick/:tsrange" resource
#=============================
$base = 'interval/nick';
docu_check($test, "$base/:nick/:tsrange");

#
# PUT, POST, DELETE
#
foreach my $method ( qw( PUT POST DELETE ) ) {
    foreach my $user ( 'demo', 'root', 'WAMBLE owdkmdf 5**' ) {
        req( $test, 405, $user, $method, "$base/demo/[,)" );
    }
}


done_testing;
