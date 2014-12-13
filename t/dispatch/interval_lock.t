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
use App::Dochazka::REST::Test;
use Data::Dumper;
use JSON;
use Plack::Test;
use Test::JSON;
use Test::More;


# initialize, connect to database, and set up a testing plan
my $status = initialize_unit();
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}
my $app = $status->payload;

# instantiate Plack::Test object
my $test = Plack::Test->create( $app );

my $res;

my %idmap = (
    "interval" => "iid",
    "lock" => "lid"
);

# create a testing schedule
my $sid = create_testing_schedule( $test );

# create testing employee 'active' with 'active' privlevel
my $eid_active = create_active_employee( $test );

# give 'active' and 'root' a schedule as of 1957-01-01 00:00
# so these two employees can enter some attendance intervals
my @shid_for_deletion;
foreach my $user ( 'active', 'root' ) {
    $status = req( $test, 200, 'root', 'POST', "schedule/history/nick/$user", <<"EOH" );
{ "sid" : $sid, "effective" : "1957-01-01 00:00" }
EOH
    is( $status->level, "OK" );
    is( $status->code, "DOCHAZKA_CUD_OK" );
    ok( $status->{'payload'} );
    ok( $status->{'payload'}->{'shid'} );
    push @shid_for_deletion, $status->{'payload'}->{'shid'};
    #ok( $status->{'payload'}->{'schedule'} );
}

# create testing employee 'inactive' with 'inactive' privlevel
my $eid_of_inactive = create_inactive_employee( $test );

# create testing employee 'bubba' with 'active' privlevel
my $eid_bubba = create_testing_employee( { nick => 'bubba', password => 'bubba' } )->eid;
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
    if( $status->level ne 'OK' ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
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
{ "eid" : $eid_active, "intvl" : "[2013-06-01 00:00, 2013-06-30 24:00)" }
EOH
    if( $status->level ne 'OK' ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    ok( $status->{'payload'} );
    ok( $status->{'payload'}->{'lid'} );
    return $status->{'payload'}->{'lid'};
}

my $test_iid = create_testing_interval( $test );
my $test_lid = create_testing_lock( $test );

my @failing_tsranges = (
    '[]',
    '{asf}',
    '[2014-01-01: 2015-01-01)',
    'wamble wumble womble',
);

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
    # - tsranges that fail validations clause
    foreach my $tsr ( @failing_tsranges ) {
        foreach my $user ( qw( demo inactive active root ) ) {
            req( $test, 404, $user, 'GET', "$base/1/$tsr" );
        }
    }
    
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
             diag( "MARK foo1" );
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
    dbi_err( $test, 200, 'root', 'POST', $base, $int_obj, qr/out of range for type integer/ );
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
    dbi_err( $test, 200, 'root', 'POST', $base, $weirded_object, qr/invalid input syntax for integer/ );
    #
    # can a different active employee edit active's interval?
    # - let bubba try to edit active's interval
    req( $test, 403, 'bubba', 'POST', "$il/$idmap{$il}", <<"EOH" );
{ "$idmap{$il}" : $test_id, "remark" : "mine" }
EOH
    dbi_err( $test, 200, 'root', 'POST', "$il/$idmap{$il}", <<"EOH", qr/illegal interval/ );
{ "$idmap{$il}" : $test_id, "intvl" : "(-infinity, today)" }
EOH
    
    #
    # - unbounded tsrange
    dbi_err( $test, 200, 'root', 'POST', "$il/$idmap{$il}", 
        "{ \"$idmap{$il}\" : $test_id, \"intvl\" : \"[1957-01-01 00:00,)\" }",
        qr/illegal interval/ );
    
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
    req( $test, 404, 'active', 'GET', "$base/jj" );
    #
    # fail non-existent IID
    req( $test, 404, 'active', 'GET', "$base/444" );
    
    my $test_id = ( $il eq 'interval' ) ? $test_iid : $test_lid;

    #
    # PUT
    # 
    my $int_obj = '{ "remark" : "Change is good" }';
    # - test with demo fail 405
    req( $test, 403, 'demo', 'PUT', "$base/$test_id", $int_obj );
    #
    # - test with root no request body
    req( $test, 400, 'root', 'PUT', "$base/$test_id" );
    #
    # - test with root fail invalid JSON
    req( $test, 400, 'root', 'PUT', "$base/$test_id", '{ asdf' );
    #
    # - test with root fail invalid IID
    req( $test, 405, 'root', 'PUT', "$base/asdf", '{ "legal":"json" }' );
    #
    # - with valid JSON that is not what we are expecting (invalid IID)
    req( $test, 405, 'root', 'PUT', "$base/asdf", '0' );
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
        diag( "MARK foo2" );
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->level, 'OK', "DELETE $base/:iid 3" );
    is( $status->code, 'DOCHAZKA_CUD_OK', "DELETE $base/:iid 4" );
    #
    # - really gone
    req( $test, 404, 'active', 'GET', "$base/$test_id" );
    
    # - test with root fail invalid IID
    req( $test, 404, 'root', 'DELETE', "$base/asd" );
}

# re-create the testing intervals
$test_iid = create_testing_interval( $test );
$test_lid = create_testing_lock( $test );


#=============================
# "interval/new" resource ( see below for tests common to both "interval/new" and "lock/new" )
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
        diag( "MARK foo3 $user" );
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
    "{ \"aid\" : $aid_of_work, \"intvl\" : \"[1957-01-02 08:00, 1957-01-02 08:05)\", \"whinger\" : \"me\" }",
    "{ \"aid\" : $aid_of_work, \"intvl\" : \"[1957-01-03 08:00, 1957-01-03 08:05)\", \"horse\" : \"E-Or\" }",
    "{ \"aid\" : $aid_of_work, \"intvl\" : \"[1957-01-04 08:00, 1957-01-04 08:05)\", \"nine dogs\" : [ 1, 9 ] }",
) {
    $status = req( $test, 200, 'root', 'POST', $base, $rb );
    if ( $status->not_ok ) {
        diag( "MARK foo4: $rb");
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
req( $test, 400, 'root', 'POST', $base, <<"EOH" );
{ "intvl" : "[1957-01-02 08:00, 1957-01-02 08:00)", "whinger" : "me" }
EOH
#
# - nonsensical JSON
req( $test, 400, 'root', 'POST', $base, 0 );
#
req( $test, 400, 'root', 'POST', $base, '[ 1, 2, [1, 2], { "wombat":"five" } ]' );

#
# DELETE
#
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );
req( $test, 405, 'WOMBAT5', 'DELETE', $base );


#=============================
# "lock/new" resource (see below for tests common to both "interval/new" and "lock/new" )
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
        diag( "MARK foo5" );
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    ok( $status->{'payload'} );
    ok( $status->{'payload'}->{'lid'} );
    my $lid = $status->payload->{'lid'};

    # and then try to add an intervals that overlap the locked period in various ways
    foreach my $intvl ( 
        '[1957-01-02 08:00, 1957-01-02 12:00)', # completely within the lock interval
        '[1957-01-03 23:00, 1957-01-04 01:00)', # extends past end of lock interval
        '[1957-01-02 08:00, today)',            # -- " -- but with 'today'
        '[1956-12-31 08:00, 1957-01-02 00:05)', # starts before beginning of lock interval
    ) {
        my $status = req( $test, 200, $user, 'POST', 'interval/new', <<"EOH" );
{ "aid" : $aid_of_work, "intvl" : "$intvl" }
EOH
        is( $status->level, 'ERR' );
        is( $status->code, 'DOCHAZKA_DBI_ERR' );
        like( $status->text, qr/interval is locked/i );
    }

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
        diag( "MARK foo6" );
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
#
# create an interval, lock it, and then try to update it and delete it
# 
# - create interval
$status = req( $test, 200, 'root', 'POST', 'interval/new', <<"EOH" );
{ "aid" : $aid_of_work, "intvl" : "[1957-01-02 08:00, 1957-01-03 08:00)" }
EOH
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
my $ti = $status->payload->{'iid'};
# - lock it
$status = req( $test, 200, 'root', 'POST', 'lock/new', <<"EOH" );
{ "intvl" : "[1957-01-01 00:00, 1957-02-01 00:00)" }
EOH
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
my $tl = $status->payload->{'lid'};
# - try to update it
$status = req( $test, 200, 'root', 'PUT', "interval/iid/$ti", <<"EOH" );
{ "long_desc" : "I'm changing this interval even though it's locked!" }
EOH
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/interval is locked/ );
# - try to delete it
$status = req( $test, 200, 'root', 'DELETE', "interval/iid/$ti" );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/interval is locked/ );
# - remove the lock
$status = req( $test, 200, 'root', 'DELETE', "lock/lid/$tl" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
# - now we can delete it
$status = req( $test, 200, 'root', 'DELETE', "interval/iid/$ti" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
#
#
# create a lock over the entire month of August 2014 and try to create
# intervals that might be considered "edge cases"
#
$status = req( $test, 200, 'root', 'POST', 'lock/new', <<"EOH" );
{ "eid" : $eid_active, "intvl" : "[2014-08-01 00:00, 2014-09-01 00:00)" }
EOH
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
my $tlid = $status->payload->{'lid'};
$status = req( $test, 200, 'root', 'GET', "lock/lid/$tlid" );
ok( $status->ok );
#
# - this one will be OK
$status = req( $test, 200, 'active', 'POST', 'interval/new', <<"EOH" );
{ "aid" : $aid_of_work, "eid" : $eid_active, "intvl" : "[2014-07-31 20:00, 2014-08-01 00:00)" }
EOH
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
my $tiid = $status->payload->{'iid'};
$status = req( $test, 200, 'active', 'DELETE', "interval/iid/$tiid" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
req( $test, 404, 'active', 'GET', "interval/iid/$tiid" );
#
# - illegal interval
$status = req( $test, 200, 'active', 'POST', 'interval/new', <<"EOH" );
{ "aid" : $aid_of_work, "eid" : $eid_active, "intvl" : "[2014-07-31 20:00, 2014-08-01 00:00]" }
EOH
is( $status->level, "ERR" );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/illegal interval/ );
#
# - upper bound not evenly divisible by 5 minutes 
$status = req( $test, 200, 'active', 'POST', 'interval/new', <<"EOH" );
{ "aid" : $aid_of_work, "eid" : $eid_active, "intvl" : "[2014-07-31 20:00, 2014-08-01 00:01)" }
EOH
is( $status->level, "ERR" );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/upper and lower bounds of interval must be evenly divisible by 5 minutes/ );
#
# - interval is locked
$status = req( $test, 200, 'active', 'POST', 'interval/new', <<"EOH" );
{ "aid" : $aid_of_work, "eid" : $eid_active, "intvl" : "[2014-07-31 20:00, 2014-08-01 00:05)" }
EOH
is( $status->level, "ERR" );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/interval is locked/ );
#
# now let's try to attack upper bound of lock
#
# - this one looks like it might conflict with the lock's upper bound
# (2014-09-01), but since the upper bound is non-inclusive, the interval will
# be OK
#
$status = req( $test, 200, 'active', 'POST', 'interval/new', <<"EOH" );
{ "aid" : $aid_of_work, "eid" : $eid_active, "intvl" : "[2014-09-01 00:00, 2014-09-01 04:00)" }
EOH
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
$tiid = $status->payload->{'iid'};
$status = req( $test, 200, 'active', 'DELETE', "interval/iid/$tiid" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
req( $test, 404, 'active', 'GET', "interval/iid/$tiid" );
#
# - conclusion: I don't see any way to create an unexpected conflict
#
# CLEANUP: delete the lock
$status = req( $test, 200, 'root', 'DELETE', "lock/lid/$tlid" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
req( $test, 404, 'root', 'GET', "lock/lid/$tlid" );


# have an active user try to create a lock on someone else's attendance
#
req( $test, 403, 'active', 'POST', $base, <<"EOH" );
{ "eid" : $eid_of_inactive, "intvl" : "[1957-02-01 00:00, 1957-03-01 00:00)" }
EOH


#
# DELETE
#
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );
req( $test, 405, 'WOMBAT5', 'DELETE', $base );


#========================
# '/interval/new' resource
# '/lock/new' resource
#
# tests of many pathological intervals
#========================
# - tests common to both 

foreach my $il ( qw( interval lock ) ) {

    # initialize insert tests
    my $insert_base = "$il/new";
    my $insert_part1 = ( $il eq 'interval' ) 
        ? "{ \"aid\" : $aid_of_work, \"intvl\" : "
        : "{ \"intvl\" : ";

    # initialize update tests
    my $test_id = ( $il eq 'interval' ) ? $test_iid : $test_lid;
    my $update_base = "$il/$idmap{$il}/$test_id";
    my $update_part1 = "{ \"$idmap{$il}\" : $test_id, \"intvl\" : ";

    # intervals that trigger 400
    foreach my $i ( 
        'null',    
        '"(-infinity,today)"',
        '"(,infinity)"',
        '"[,)"',
        '"[,today)"',
        '"[today,)"',
        '"[now,)"',
        '"[ 1958-05-27 08:00, 1958-05-27 08:00 )"',
        '"( 1977-10-22 08:00, 1977-10-23 08:00 )"',
        '"[ 1977-10-22 08:00, 1977-10-23 08:00 ]"',
        '"( 1977-10-22 08:00, 1977-10-23 08:00 ]"',
    ) {
        #diag( "$insert_part1$i }" );
        dbi_err( $test, 200, 'root', 'POST', $insert_base, "$insert_part1$i }",
            qr/illegal interval/ );
        dbi_err( $test, 200, 'root', 'PUT', $update_base, "$update_part1$i }",
            qr/illegal interval/ );
    }

    # intervals that trigger DOCHAZKA_DBI_ERR 'malformed range literal'
    foreach my $i (
        '"infinity is my friend"',
        '"[whacko interval)"',
        '"[,now()::timestamp)"',
    ) {
        #diag( "$insert_part1$i }" );
        dbi_err( $test, 200, 'root', 'POST', $insert_base, "$insert_part1$i }",
            qr/malformed range literal/ );
    }

    # intervals that trigger DOCHAZKA_DBI_ERR 'upper and lower bounds (etc.)'
    foreach my $i (
        '"[ 1958-05-27 08:00, 1958-05-27 08:01 )"',
        '"[ 1958-05-27 08:00, 1958-05-27 08:02 )"',
        '"[ 1958-05-27 08:00, 1958-05-27 08:03 )"',
        '"[ 1958-05-27 08:00, 1958-05-27 08:04 )"',
        '"[ 1958-05-27 08:01, 1958-05-27 08:05 )"',
        '"[ 1958-05-27 08:02, 1958-05-27 08:05 )"',
        '"[ 1958-05-27 08:03, 1958-05-27 08:05 )"',
        '"[ 1958-05-27 08:04, 1958-05-27 08:05 )"',
    ) {
        #diag( "$insert_part1$i }" );
        dbi_err( $test, 200, 'root', 'POST', $insert_base, "$insert_part1$i }",
            qr/upper and lower bounds of interval must be evenly divisible by 5 minutes/ );
        dbi_err( $test, 200, 'root', 'PUT', $update_base, "$update_part1$i }",
            qr/upper and lower bounds of interval must be evenly divisible by 5 minutes/ );
    }
}


#=============================
# "interval/nick/:nick/:tsrange" resource
# "lock/nick/:nick/:tsrange" resource
#=============================
foreach my $il ( qw( interval lock ) ) {

    $base = "$il/nick";
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
    # - tsranges that fail validations clause
    foreach my $tsr ( @failing_tsranges ) {
        foreach my $user ( qw( demo inactive active root ) ) {
            req( $test, 404, $user, 'GET', "$base/$user/$tsr" );
        }
    }
}

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
    # - tsranges that fail validations clause
    foreach my $tsr ( @failing_tsranges ) {
        foreach my $user ( qw( demo inactive active root ) ) {
            req( $test, 404, $user, 'GET', "$base/$tsr" );
        }
    }
    
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

# delete the testing schedhistory records
foreach my $shid ( @shid_for_deletion ) {
    $status = req( $test, 200, 'root', 'DELETE', "schedule/history/shid/$shid" );
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    req( $test, 404, 'root', 'GET', "schedule/history/shid/$shid" );
}


#=============================
# "interval/summary/?:qualifiers" resource
#=============================
$base = "interval/summary";
docu_check($test, "$base/?:qualifiers");

#
# PUT, POST, DELETE
#
foreach my $method ( qw( PUT POST DELETE ) ) {
    foreach my $user ( qw( demo inactive active root ) ) {
        req( $test, 405, $user, $method, $base );
    }
}

# delete the testing employees
delete_employee_by_nick( $test, 'active' );
delete_employee_by_nick( $test, 'inactive' );
delete_employee_by_nick( $test, 'bubba' );

# delete the testing schedule
delete_testing_schedule( $sid );
    
done_testing;
