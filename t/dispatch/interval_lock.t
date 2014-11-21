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
# test interval and lock resources, which are very similar
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

my %idmap = (
    "interval" => "iid",
    "lock" => "lid"
);

# create testing employees with 'active' and 'inactive' privlevels
my $eid_active = create_active_employee( $test );
create_inactive_employee( $test );
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

sub aid_by_code {
    my ( $code ) = @_;
    $status = req( $test, 200, 'root', 'GET', "activity/code/$code" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    ok( $status->{'payload'} );
    ok( $status->{'payload'}->{'aid'} );
    is( $status->{'payload'}->{'code'}, uc( $code ) );
    return $status->{'payload'}->{'aid'};
}

sub create_testing_interval {
    my ( $test ) = @_;
    # get AID of WORK
    my $aid_of_work = aid_by_code( 'WORK' );
    
    # create a testing interval
    $status = req( $test, 200, 'root', 'POST', 'interval/new', <<"EOH" );
{ "eid" : $eid_active, "aid" : $aid_of_work, "intvl" : "[2014-10-01 08:00, 2014-10-01 12:00)" }
EOH
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    ok( $status->{'payload'} );
    is( $status->{'payload'}->{'aid'}, $aid_of_work );
    ok( $status->{'payload'}->{'iid'} );
    return $status->{'payload'}->{'iid'};
}

sub create_testing_lock {
    my ( $test ) = @_;
    
    # create a testing lock
    $status = req( $test, 200, 'root', 'POST', 'lock/new', <<"EOH" );
{ "eid" : $eid_active, "intvl" : "[2014-10-01 00:00, 2014-10-31 24:00)" }
EOH
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    ok( $status->{'payload'} );
    ok( $status->{'payload'}->{'lid'} );
    return $status->{'payload'}->{'lid'};
}

my $test_iid = create_testing_interval( $test );
my $test_lid = create_testing_lock( $test );

#=============================
# "interval/eid/:eid/:tsrange" resource
# "lock/eid/:eid/:tsrange" resource
#=============================
foreach my $il ( qw( interval lock ) ) {
    my $base = "$il/eid";
    docu_check($test, "$base/:eid/:tsrange");
    
    #
    # GET
    #
    # - root has no intervals but these users can't find that out
    foreach my $user ( qw( demo inactive active ) ) {
        req( $test, 403, $user, 'GET', "$base/1/[,)" );
    }
    # - root has no intervals
    req( $test, 404, 'root', 'GET', "$base/1/[,)" );
    # - active has one interval
    $status = req( $test, 200, 'root', 'GET', "$base/$eid_active/[,)" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    is( $status->{'count'}, 1 );
    
    #
    # PUT, POST, DELETE
    #
    foreach my $method ( qw( PUT POST DELETE ) ) {
        foreach my $user ( 'demo', 'root', 'WAMBLE owdkmdf 5**' ) {
            req( $test, 405, $user, $method, "$base/2/[,)" );
        }
    }
}


#=============================
# "interval/help" resource
#=============================
foreach my $il ( qw( interval lock ) ) {
    my $base = "$il/help";
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
    ok( exists $status->payload->{'resources'}->{"$il/help"} );
    ok( ! exists $status->payload->{'resources'}->{"$il/$idmap{$il}"} );
    ok( ! exists $status->payload->{'resources'}->{"$il/$idmap{$il}/:$idmap{$il}"} );
    #
    $status = req( $test, 200, 'root', 'GET', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_DEFAULT' );
    ok( exists $status->payload->{'documentation'} );
    ok( exists $status->payload->{'resources'} );
    ok( keys %{ $status->payload->{'resources'} } >= 3 );
    ok( exists $status->payload->{'resources'}->{"$il/help"} );
    ok( ! exists $status->payload->{'resources'}->{"$il/$idmap{$il}"} );  # POST only
    ok( exists $status->payload->{'resources'}->{"$il/$idmap{$il}/:$idmap{$il}"} );
    #
    $status = req( $test, 200, 'active', 'GET', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_DEFAULT' );
    ok( exists $status->payload->{'documentation'} );
    ok( exists $status->payload->{'resources'} );
    ok( keys %{ $status->payload->{'resources'} } >= 3 );
    ok( exists $status->payload->{'resources'}->{"$il/help"} );
    ok( ! exists $status->payload->{'resources'}->{"$il/$idmap{$il}"} );  # POST only
    ok( exists $status->payload->{'resources'}->{"$il/$idmap{$il}/:$idmap{$il}"} );
    
    #
    # PUT
    #
    $status = req( $test, 200, 'demo', 'PUT', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_DEFAULT' );
    ok( exists $status->payload->{'documentation'} );
    ok( exists $status->payload->{'resources'} );
    ok( keys %{ $status->payload->{'resources'} } >= 1 );
    ok( exists $status->payload->{'resources'}->{"$il/help"} );
    # 
    $status = req( $test, 200, 'root', 'PUT', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_DEFAULT' );
    ok( exists $status->payload->{'documentation'} );
    ok( exists $status->payload->{'resources'} );
    #ok( keys %{ $status->payload->{'resources'} } >= 3 );
    ok( exists $status->payload->{'resources'}->{"$il/help"} );
    
    #
    # POST
    #
    $status = req( $test, 200, 'demo', 'POST', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_DEFAULT' );
    ok( exists $status->payload->{'documentation'} );
    ok( exists $status->payload->{'resources'} );
    ok( keys %{ $status->payload->{'resources'} } >= 1 );
    ok( exists $status->payload->{'resources'}->{"$il/help"} );
    ok( ! exists $status->payload->{'resources'}->{"$il/$idmap{$il}"} );  # admin only
    #
    $status = req( $test, 200, 'root', 'POST', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_DEFAULT' );
    ok( exists $status->payload->{'documentation'} );
    ok( exists $status->payload->{'resources'} );
    ok( keys %{ $status->payload->{'resources'} } >= 1 );
    ok( exists $status->payload->{'resources'}->{"$il/help"} );
    ok( exists $status->payload->{'resources'}->{"$il/$idmap{$il}"} );  # admin only
    
    #
    # DELETE
    #
    $status = req( $test, 200, 'demo', 'DELETE', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_DEFAULT' );
    ok( exists $status->payload->{'documentation'} );
    ok( exists $status->payload->{'resources'} );
    ok( keys %{ $status->payload->{'resources'} } >= 1 );
    ok( exists $status->payload->{'resources'}->{"$il/help"} );
    #
    $status = req( $test, 200, 'root', 'DELETE', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_DEFAULT' );
    ok( exists $status->payload->{'documentation'} );
    ok( exists $status->payload->{'resources'} );
    ok( keys %{ $status->payload->{'resources'} } >= 1 );
    ok( exists $status->payload->{'resources'}->{"$il/help"} );
}


#=============================
# "interval/iid" resource
# "lock/lid" resource
#=============================
foreach my $il ( qw( interval lock ) ) {
    my $base = "$il/$idmap{$il}";
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

    my $test_id = ( $il eq 'interval' ) ? $test_iid : $test_lid;
    # 
    # - test if expected behavior behaves as expected (update)
    my $int_obj = <<"EOH";
{ "$idmap{$il}" : $test_id, "remark" : "Sharpening pencils" }
EOH
    req( $test, 403, 'demo', 'POST', $base, $int_obj );
    req( $test, 403, 'inactive', 'POST', $base, $int_obj );

    if ( $il eq 'interval' ) {
         $status = req( $test, 200, 'active', 'POST', $base, $int_obj );
         if ( $status->not_ok ) {
             diag( Dumper $status );
             BAIL_OUT(0);
         }
         is( $status->level, 'OK', "POST $base 3" );
         is( $status->code, 'DOCHAZKA_CUD_OK', "POST $base 4" );
         is( $status->payload->{'iid'}, $test_iid, "POST $base 5" );
         is( $status->payload->{'remark'}, 'Sharpening pencils', "POST $base 7" );
    } else {
         req( $test, 403, 'active', 'POST', $base, $int_obj );
    }

    #
    # - non-existent ID and also out of range
    $int_obj = <<"EOH";
{ "$idmap{$il}" : 3434342342342, "remark" : 34334342 }
EOH
    $status = req( $test, 200, 'root', 'POST', $base, $int_obj );
    is( $status->level, "ERR", "POST $base 7.3" );
    is( $status->code, "DOCHAZKA_DBI_ERR", "POST $base 7.4" );
    like( $status->text, qr/out of range for type integer/, "POST $base 7.5" );
    #
    # - non-existent ID
    $int_obj = <<"EOH";
{ "$idmap{$il}" : 342342342, "remark" : 34334342 }
EOH
    req( $test, 404, 'root', 'POST', $base, $int_obj );
    #
    # - throw a couple curve balls
    my $weirded_object = '{ "copious_turds" : 555, "long_desc" : "wang wang wazoo", "disabled" : "f" }';
    req( $test, 400, 'root', 'POST', $base, $weirded_object );
    #
    my $no_closing_bracket = '{ "copious_turds" : 555, "long_desc" : "wang wang wazoo", "disabled" : "f"';
    req( $test, 400, 'root', 'POST', $base, $no_closing_bracket );
    #
    $weirded_object = "{ \"$idmap{$il}\" : \"!!!!!\", \"remark\" : \"down it goes\" }";
    $status = req( $test, 200, 'root', 'POST', $base, $weirded_object );
    is( $status->level, 'ERR', "POST $base 13" );
    is( $status->code, 'DOCHAZKA_DBI_ERR', "POST $base 14" );
    like( $status->text, qr/invalid input syntax for integer/, "POST $base 15" );
    #
    # can a different active employee edit active's interval?
    # - let bubba try to edit active's interval
    req( $test, 403, 'bubba', 'POST', "$il/$idmap{$il}", <<"EOH" );
{ "$idmap{$il}" : $test_id, "remark" : "mine" }
EOH
    
    #
    # DELETE
    #
    req( $test, 405, 'demo', 'DELETE', $base );
    req( $test, 405, 'root', 'DELETE', $base );
    req( $test, 405, 'WOMBAT5', 'DELETE', $base );
}


#=============================
# "interval/iid/:iid" resource
# "lock/lid/:lid" resource
#=============================
foreach my $il ( qw( interval lock ) ) {
    my $base = "$il/$idmap{$il}";
    docu_check($test, "$base/:$idmap{$il}");
    
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
    is( $status->payload->{$idmap{$il}}, 1 );
    is( $status->payload->{'eid'}, $eid_active );
    ok( $status->payload->{'intvl'} );
    if ( $il eq 'interval' ) {
        ok( $status->payload->{'aid'} );
        ok( exists $status->payload->{'long_desc'} );
        ok( $status->payload->{'remark'} );
        ok( ! defined $status->payload->{'long_desc'} );
    }
    
    #
    # fail invalid ID
    $status = req( $test, 200, 'active', 'GET', "$base/jj" );
    is( $status->level, 'ERR', "GET $base/:iid 6" );
    is( $status->code, 'DOCHAZKA_DBI_ERR', "GET $base/:iid 7" );
    like( $status->text, qr/invalid input syntax for integer/, "GET $base/:iid 8" );
    #
    # fail non-existent IID
    req( $test, 404, 'active', 'GET', "$base/444" );
    
    my $test_id = ( $il eq 'interval' ) ? $test_iid : $test_lid;

    #
    # PUT
    # 
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
    req( $test, 400, 'root', 'PUT', "$base/$test_id" );
    #
    # - test with root fail invalid JSON
    req( $test, 400, 'root', 'PUT', "$base/$test_id", '{ asdf' );
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
    req( $test, 400, 'root', 'PUT', "$base/$test_id", '0' );
    #
    # - with valid JSON that has some bogus properties
    req( $test, 400, 'root', 'PUT', "$base/$test_id", '{ "legal":"json" }' );
    
    #
    # POST
    #
    req( $test, 405, 'demo', 'POST', "$base/1" );
    req( $test, 405, 'active', 'POST', "$base/1" );
    req( $test, 405, 'root', 'POST', "$base/1" );
    
    #
    # DELETE
    #
    # - first make sure there is something to delete
    $status = undef;
    $status = req( $test, 200, 'root', 'GET', "$base/$test_id" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    ok( $status->{"payload"} );
    is( $status->payload->{$idmap{$il}}, $test_id );

    ## - test with demo fail 403
    #req( $test, 403, 'demo', 'DELETE', "$base/$test_id" );
    ##
    ## - test with active fail 403
    #req( $test, 403, 'active', 'DELETE', "$base/$test_id" );
    #
    # - test with root success
    #diag( "DELETE $base/$test_id" );
    $status = undef;
    $status = req( $test, 200, 'root', 'DELETE', "$base/$test_id" );
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->level, 'OK', "DELETE $base/:iid 3" );
    is( $status->code, 'DOCHAZKA_CUD_OK', "DELETE $base/:iid 4" );
    #
    # - really gone
    req( $test, 404, 'active', 'GET', "$base/$test_id" );
    
    # - test with root fail invalid IID
    $status = req( $test, 200, 'root', 'DELETE', "$base/asd" );
    is( $status->level, 'ERR', "DELETE $base/:iid 8" );
    is( $status->code, 'DOCHAZKA_DBI_ERR', "DELETE $base/:iid 9" );
    like( $status->text, qr/invalid input syntax for integer/, "DELETE $base/:iid 10" );
}

# re-create the testing intervals
$test_iid = create_testing_interval( $test );
$test_lid = create_testing_lock( $test );


#=============================
# "interval/new" resource
#=============================
my $base = 'interval/new';
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
# POST
#
# - instigate a "403 Forbidden"
my $aid_of_work = aid_by_code( 'WORK' );
foreach my $user ( qw( demo inactive ) ) {
    req( $test, 403, $user, 'POST', $base, <<"EOH" );
{ "aid" : $aid_of_work, "intvl" : "[1957-01-02 08:00, 1957-01-03 08:00)" }
EOH
}
# - let active and root create themselves an interval
foreach my $user ( qw( active root ) ) {
    $status = req( $test, 200, $user, 'POST', $base, <<"EOH" );
{ "aid" : $aid_of_work, "intvl" : "[1957-01-02 08:00, 1957-01-03 08:00)" }
EOH
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    ok( $status->{'payload'} );
    ok( $status->{'payload'}->{'iid'} );
    my $iid = $status->payload->{'iid'};

    $status = req( $test, 200, $user, 'DELETE', "/interval/iid/$iid" );
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
}
#
# - as long as all required properties are present, JSON with bogus properties
#   will be accepted for insert operation (bogus properties will be silently ignored)
foreach my $rb ( 
    "{ \"aid\" : $aid_of_work, \"intvl\" : \"[1957-01-02 08:00, 1957-01-02 08:00)\", \"whinger\" : \"me\" }",
    "{ \"aid\" : $aid_of_work, \"intvl\" : \"[1957-01-03 08:00, 1957-01-03 08:00)\", \"horse\" : \"E-Or\" }",
    "{ \"aid\" : $aid_of_work, \"intvl\" : \"[1957-01-04 08:00, 1957-01-04 08:00)\", \"nine dogs\" : [ 1, 9 ] }"
) {
    $status = req( $test, 200, 'root', 'POST', $base, $rb );
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    ok( $status->{'payload'} );
    ok( $status->{'payload'}->{'iid'} );
    my $iid = $status->payload->{'iid'};

    $status = req( $test, 200, 'root', 'DELETE', "/interval/iid/$iid" );
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
}
#
# - required property missing
$status = req( $test, 200, 'root', 'POST', $base, <<"EOH" );
{ "intvl" : "[1957-01-02 08:00, 1957-01-02 08:00)", "whinger" : "me" }
EOH
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PARAMETER_BAD_OR_MISSING' );
#
# - nonsensical JSON
$status = req( $test, 400, 'root', 'POST', $base, 0 );
#
$status = req( $test, 400, 'root', 'POST', $base, '[ 1, 2, [1, 2], { "wombat":"five" } ]' );



#
# DELETE
#
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );
req( $test, 405, 'WOMBAT5', 'DELETE', $base );


#=============================
# "lock/new" resource
#=============================
$base = 'lock/new';
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
# POST
#
# - instigate a "403 Forbidden"
foreach my $user ( qw( demo inactive ) ) {
    req( $test, 403, $user, 'POST', $base, <<"EOH" );
{ "intvl" : "[1957-01-02 00:00, 1957-01-03 24:00)" }
EOH
}
# - let active and root create themselves a lock
foreach my $user ( qw( active root ) ) {
    $status = req( $test, 200, $user, 'POST', $base, <<"EOH" );
{ "intvl" : "[1957-01-02 00:00, 1957-01-03 24:00)" }
EOH
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    ok( $status->{'payload'} );
    ok( $status->{'payload'}->{'lid'} );
    my $lid = $status->payload->{'lid'};

    # and then try to add an intervals that overlap the locked period in various ways
    $status = req( $test, 200, $user, 'POST', 'interval/new', <<"EOH" );
{ "aid" : $aid_of_work, "intvl" : "[1957-01-02 08:00, 1957-01-02 12:00)" }
EOH
    diag( Dumper $status );
    BAIL_OUT(0);
    #is( $status->level, 'ERR' );
    #is( $status->code, 'DISPATCH_INTERVAL_LOCKED' );

    # 'active' can't delete locks so we have to delete them as root
    $status = req( $test, 200, 'root', 'DELETE', "/lock/lid/$lid" );
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
}
#
# - as long as all required properties are present, JSON with bogus properties
#   will be accepted for insert operation (bogus properties will be silently ignored)
foreach my $rb ( 
    "{ \"intvl\" : \"[1957-01-02 00:00, 1957-01-02 24:00)\", \"whinger\" : \"me\" }",
    "{ \"intvl\" : \"[1957-01-03 00:00, 1957-01-03 24:00)\", \"horse\" : \"E-Or\" }",
    "{ \"intvl\" : \"[1957-01-04 00:00, 1957-01-04 24:00)\", \"nine dogs\" : [ 1, 9 ] }"
) {
    $status = req( $test, 200, 'root', 'POST', $base, $rb );
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    ok( $status->{'payload'} );
    ok( $status->{'payload'}->{'lid'} );
    my $lid = $status->payload->{'lid'};

    $status = req( $test, 200, 'root', 'DELETE', "/lock/lid/$lid" );
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
}
#
# - required property missing
$status = req( $test, 200, 'root', 'POST', $base, <<"EOH" );
{ "whinger" : "me" }
EOH
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PARAMETER_BAD_OR_MISSING' );
#
# - nonsensical JSON
$status = req( $test, 400, 'root', 'POST', $base, 0 );
#
$status = req( $test, 400, 'root', 'POST', $base, '[ 1, 2, [1, 2], { "wombat":"five" } ]' );


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
# GET
#
# - these users have no intervals but these users can't find that out
foreach my $user ( qw( demo inactive active ) ) {
    foreach my $nick ( qw( root whanger foobar tsw57 ) ) {
        req( $test, 403, $user, 'GET', "$base/$nick/[,)" );
    }
}
# - root has no intervals
req( $test, 404, 'root', 'GET', "$base/root/[,)" );
# - whinger has no intervals
req( $test, 404, 'root', 'GET', "$base/whinger/[,)" );
# - -1 has no intervals
req( $test, 404, 'root', 'GET', "$base/-1/[,)" );
# - active has one interval
$status = req( $test, 200, 'root', 'GET', "$base/active/[,)" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
is( $status->{'count'}, 1 );

#
# PUT, POST, DELETE
#
foreach my $method ( qw( PUT POST DELETE ) ) {
    foreach my $user ( 'demo', 'root', 'WAMBLE owdkmdf 5**' ) {
        req( $test, 405, $user, $method, "$base/demo/[,)" );
    }
}


#=============================
# "interval/self/:tsrange" resource
# "lock/self/:tsrange" resource
#=============================
foreach my $il ( qw( interval lock ) ) {
    $base = "$il/self";
    docu_check($test, "$base/:tsrange");
    
    #
    # GET
    #
    # - demo is not allowed to see any intervals (even his own)
    req( $test, 403, 'demo', 'GET', "$base/[,)" );
    #
    # - inactive and root don't have any intervals
    foreach my $user ( qw( inactive root ) ) {
        req( $test, 404, $user, 'GET', "$base/[,)" );
    }
    # - active has one interval
    $status = req( $test, 200, 'active', 'GET', "$base/[,)" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    is( $status->{'count'}, 1 );
    
    #
    # PUT, POST, DELETE
    #
    foreach my $method ( qw( PUT POST DELETE ) ) {
        foreach my $user ( 'demo', 'root', 'WAMBLE owdkmdf 5**' ) {
            req( $test, 405, $user, $method, "$base/[,)" );
        }
    }
}
    
# delete the testing interval
$status = req( $test, 200, 'root', 'DELETE', "/interval/iid/$test_iid" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

# delete the testing lock
$status = req( $test, 200, 'root', 'DELETE', "/lock/lid/$test_lid" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );


# delete the testing employees
delete_employee_by_nick( $test, 'active' );
delete_employee_by_nick( $test, 'inactive' );
delete_employee_by_nick( $test, 'bubba' );

    
done_testing;
