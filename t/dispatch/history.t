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
# test history (priv/sched) resources:
# - since all the history dispatch logic is shared, most of the tests
#   for 'priv/history/...' and 'schedule/history/...' resources are either
#   identical or very similar, so it makes sense to test them as a unit
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

use App::CELL qw( $meta $site );
use App::Dochazka::REST;
use App::Dochazka::REST::Model::Privhistory;
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

sub delete_history_recs {
    my ( $base, $set ) = @_;
    my $prop = ( $base =~ m/^priv/ ) 
        ? 'phid'
        : 'shid'; 
    my $resource = ( $base =~ m/^priv/ ) 
        ? '/priv/history/phid/'
        : '/schedule/history/shid/';
    foreach my $rec ( @$set ) {
        #diag( "$base deleting " . Dumper $rec );
        $status = req( $test, 200, 'root', 'DELETE', $resource . $rec->{$prop} );
        is( $status->level, 'OK' );
        is( $status->code, 'DOCHAZKA_CUD_OK' );
    }
}

#=============================
# "{priv,schedule}/history/self/?:tsrange" resource
#=============================

# make sure root has some kind of schedule history
my $ts_sid = create_testing_schedule( $test );
$status = req( $test, 200, 'root', 'POST', 'schedule/history/nick/root',
    '{ "effective":"1000-01-01 00:00", "sid":' . $ts_sid . ' }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
ok( exists $status->{payload} );
ok( defined $status->payload );
ok( exists $status->payload->{'shid'} );
ok( defined $status->payload->{'shid'} );
ok( $status->payload->{'shid'} > 0 );
my $root_shid = $status->payload->{'shid'};

my $base;
foreach $base ( 'priv/history/self', 'schedule/history/self' ) {
    docu_check($test, "$base/?:tsrange");
    #
    # GET
    #
    # - auth fail
    req( $test, 403, 'demo', 'GET', $base );
    #
    # as root
    $status = req( $test, 200, 'root', 'GET', $base );
    is( $status->level, 'OK' );
    is( $status->code, "DISPATCH_RECORDS_FOUND" );
    ok( defined $status->payload );
    ok( exists $status->payload->{'eid'} );
    is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
    ok( exists $status->payload->{'history'} );
    is( scalar @{ $status->payload->{'history'} }, 1 );
    is( $status->payload->{'history'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
    ok( exists $status->payload->{'history'}->[0]->{'effective'} );
    #
    # with a valid tsrange
    req( $test, 403, 'demo', 'GET', "$base/[,)" );
    $status = req( $test, 200, 'root', 'GET', "$base/[,)" );
    is( $status->level, 'OK' );
    is( $status->code, "DISPATCH_RECORDS_FOUND" );
    ok( defined $status->payload );
    ok( exists $status->payload->{'eid'} );
    is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
    ok( exists $status->payload->{'history'} );
    is( scalar @{ $status->payload->{'history'} }, 1 );
    is( $status->payload->{'history'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
    ok( exists $status->payload->{'history'}->[0]->{'effective'} );
    #
    # - with invalid tsrange
    $status = req( $test, 200, 'root', 'GET', "$base/[,sdf)" );
    is( $status->level, 'ERR' );
    is( $status->code, 'DOCHAZKA_DBI_ERR' );
    like( $status->text, qr/invalid input syntax for type timestamp/ );
    
    #
    # PUT, POST, DELETE
    #
    req( $test, 405, 'demo', 'PUT', $base );
    req( $test, 405, 'demo', 'POST', $base );
    req( $test, 405, 'demo', 'DELETE', $base );
    #
    req( $test, 405, 'demo', 'PUT', "$base/[,)" );
    req( $test, 405, 'demo', 'POST', "$base/[,)" );
    req( $test, 405, 'demo', 'DELETE', "$base/[,)" );
}


#===========================================
# "{priv,schedule}/history/eid/:eid" resource
#===========================================
foreach $base ( "priv/history/eid", "schedule/history/eid" ) {
    docu_check($test, "$base/:eid");
    #
    # GET
    #
    # - root employee
    req( $test, 403, 'demo', 'GET', $base . '/' . $site->DOCHAZKA_EID_OF_ROOT );
    $status = req( $test, 200, 'root', 'GET', $base . '/' . $site->DOCHAZKA_EID_OF_ROOT );
    is( $status->level, 'OK' );
    is( $status->code, "DISPATCH_RECORDS_FOUND" );
    ok( defined $status->payload );
    ok( exists $status->payload->{'eid'} );
    is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
    ok( exists $status->payload->{'history'} );
    is( scalar @{ $status->payload->{'history'} }, 1 );
    is( $status->payload->{'history'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
    ok( exists $status->payload->{'history'}->[0]->{'effective'} );
    #
    # - non-existent EID
    req( $test, 403, 'demo', 'GET', "$base/4534" );
    $status = req( $test, 200, 'root', 'GET', "$base/4534" );
    is( $status->level, 'ERR' );
    is( $status->code, 'DISPATCH_EMPLOYEE_DOES_NOT_EXIST' );
    
    #
    # - invalid EID
    req( $test, 403, 'demo', 'GET', "$base/asas" );
    $status = req( $test, 200, 'root', 'GET', "$base/asas" );
    is( $status->level, 'ERR' );
    is( $status->code, 'DOCHAZKA_DBI_ERR' );
    like( $status->text, qr/invalid input syntax for integer/ );
    
    #
    # PUT
    #
    req( $test, 405, 'demo', 'PUT', "$base/2" );
    req( $test, 405, 'active', 'PUT', "$base/2" );
    req( $test, 405, 'root', 'PUT', "$base/2" );
    
    #
    # POST
    #
    # - we will be inserting a bunch of records so push them onto an array 
    #   for easy deletion later
    my @history_recs_to_delete;
    # - be nice
    my $j = ( $base =~ m/^priv/ )
        ? '{ "effective":"1969-04-28 19:15", "priv":"inactive" }'
        : '{ "effective":"1969-04-28 19:15", "sid":' . $ts_sid . ' }';

    req( $test, 403, 'demo', 'POST', "$base/2", $j );
    $status = req( $test, 200, 'root', 'POST', "$base/2", $j );
    if ( $status->not_ok ) {
        diag( $status->code . ' ' . $status->text );
    }
    is( $status->level, 'OK' );
    my $pho = $status->payload;
    my $prop = ( $base =~ m/^priv/ ) ? 'phid' : 'shid';
    ok( exists $pho->{$prop}, "$prop exists in payload after POST $base/2" );
    ok( defined $pho->{$prop}, "$prop defined in payload after POST $base/2" );
    push @history_recs_to_delete, { eid => $pho->{eid}, $prop => $pho->{$prop} };
    #
    # - be pathological
    $j = '{ "effective":"1979-05-24", "horse" : "E-Or" }';
    req( $test, 403, 'demo', 'POST', "$base/2", $j );
    $status = req( $test, 200, 'root', 'POST', "$base/2", $j );
    is( $status->level, 'ERR' );
    is( $status->code, 'DOCHAZKA_BAD_INPUT' );
    #
    # - addition of privlevel makes the above request less pathological
    $j = ( $base =~ m/^priv/ )
        ? '{ "effective":"1979-05-24", "horse" : "E-Or", "priv" : "admin" }'
        : '{ "effective":"1979-05-24", "horse" : "E-Or", "sid" : ' . $ts_sid . ' }';
    req( $test, 403, 'demo', 'POST', "$base/2", $j );
    $status = req( $test, 200, 'root', 'POST', "$base/2", $j );
    is( $status->level, 'OK' );
    $pho = $status->payload;
    push @history_recs_to_delete, { eid => $pho->{eid}, $prop => $pho->{$prop} };
    #
    if ( $base =~ m/^priv/ ) {
        # check if demo really is an admin
        $status = req( $test, 200, 'demo', 'GET', "employee/current/priv" );
        is( $status->level, 'OK' );
        is( $status->code, 'DISPATCH_EMPLOYEE_CURRENT_PRIV' );
        ok( exists $status->{'payload'} );
        ok( exists $status->payload->{'priv'} );
        is( $status->payload->{'priv'}, 'admin' );
    }
    
    #
    # DELETE
    #
    req( $test, 405, 'demo', 'DELETE', "$base/2" );
    req( $test, 405, 'active', 'DELETE', "$base/2" );
    req( $test, 405, 'root', 'DELETE', "$base/2" );
    
    # - we have some records queued for deletion
    delete_history_recs( $base, \@history_recs_to_delete );
    @history_recs_to_delete = ();
}
    

#===========================================
# "{priv,schedule}/history/eid/:eid/:tsrange" resource
#===========================================
foreach $base ( "priv/history/eid", "schedule/history/eid" ) {
    docu_check($test, "$base/:eid/:tsrange");
    #
    # GET
    #
    # - root employee, with tsrange, records found
    req( $test, 403, 'demo', 'GET', $base. '/' . $site->DOCHAZKA_EID_OF_ROOT . 
        '/[999-12-31 23:59, 1000-01-01 00:01)' );
    $status = req( $test, 200, 'root', 'GET', $base. '/' . $site->DOCHAZKA_EID_OF_ROOT . 
        '/[999-12-31 23:59, 1000-01-01 00:01)' );
    is( $status->level, 'OK' );
    is( $status->code, "DISPATCH_RECORDS_FOUND" );
    ok( defined $status->payload );
    ok( exists $status->payload->{'eid'} );
    is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
    ok( exists $status->payload->{'history'} );
    is( scalar @{ $status->payload->{'history'} }, 1 );
    is( $status->payload->{'history'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
    ok( exists $status->payload->{'history'}->[0]->{'effective'} );
    #
    # - root employee, with tsrange but no records found
    my $uri = $base . '/' .  $site->DOCHAZKA_EID_OF_ROOT .
              '/[1999-12-31 23:59, 2000-01-01 00:01)';
    req( $test, 403, 'demo', 'GET', $uri );
    req( $test, 404, 'root', 'GET', $uri );
    #
    # - non-existent EID
    my $tsr = '[1999-12-31 23:59, 2000-01-01 00:01)';
    req( $test, 403, 'demo', 'GET', "$base/4534/$tsr" );
    $status = req( $test, 200, 'root', 'GET', "$base/4534/$tsr" );
    is( $status->level, 'ERR' );
    is( $status->code, 'DISPATCH_EMPLOYEE_DOES_NOT_EXIST' );
    #
    # - invalid EID
    req( $test, 403, 'demo', 'GET', "$base/asas/$tsr" );
    $status = req( $test, 200, 'root', 'GET', "$base/asas/$tsr" );
    is( $status->level, 'ERR' );
    is( $status->code, 'DOCHAZKA_DBI_ERR' );
    like( $status->text, qr/invalid input syntax for integer/ );
    
    #
    # PUT, POST, DELETE
    #
    foreach my $user ( qw( demo root ) ) {
        foreach my $method ( qw( PUT POST DELETE ) ) {
            req( $test, 405, $user, $method, "$base/23/[,)" );
        }
    }
}


#===========================================
# "{priv,schedule}/history/nick/:nick" resource
#===========================================
foreach $base ( "priv/history/nick", "schedule/history/nick" ) {
    docu_check($test, "$base/:nick");
    #
    # GET
    #
    # - root employee
    req( $test, 403, 'demo', 'GET', "$base/root" );
    $status = req( $test, 200, 'root', 'GET', "$base/root" );
    is( $status->level, 'OK' );
    is( $status->code, "DISPATCH_RECORDS_FOUND" );
    ok( defined $status->payload );
    ok( exists $status->payload->{'nick'} );
    is( $status->payload->{'nick'}, 'root' );
    ok( exists $status->payload->{'history'} );
    is( scalar @{ $status->payload->{'history'} }, 1 );
    is( $status->payload->{'history'}->[0]->{'eid'}, 1 );
    ok( exists $status->payload->{'history'}->[0]->{'effective'} );
    #
    # - non-existent employee
    req( $test, 403, 'demo', 'GET', "$base/rotoroot" );
    $status = req( $test, 200, 'root', 'GET', "$base/rotoroot" );
    is( $status->level, 'ERR' );
    is( $status->code, 'DISPATCH_EMPLOYEE_DOES_NOT_EXIST' );
    
    #
    # PUT
    #
    req( $test, 405, 'demo', 'PUT', "$base/asdf" );
    req( $test, 405, 'root', 'PUT', "$base/asdf" );
    
    #
    # POST
    #
    my $j = ( $base =~ m/^priv/ ) 
        ? '{ "effective":"1969-04-27 9:45", "priv":"inactive" }'
        : '{ "effective":"1969-04-27 9:45", "sid":' . $ts_sid . ' }';
    req( $test, 403, 'demo', 'POST', "$base/demo", $j );
    $status = req( $test, 200, 'root', 'POST', "$base/demo", $j );
    if ( $status->not_ok ) {
        diag( $status->code . ' ' . $status->text );
    }
    is( $status->level, 'OK' );
    my $pho = $status->payload;
    my $prop = ( $base =~ m/^priv/ ) ? 'phid' : 'shid';
    push my @history_recs_to_delete, { nick => 'demo', $prop => $pho->{$prop} };
    
    #
    # DELETE
    #
    req( $test, 405, 'demo', 'DELETE', "$base/madagascar" );
    req( $test, 405, 'active', 'DELETE', "$base/madagascar" );
    req( $test, 405, 'root', 'DELETE', "$base/madagascar" );
    
    # - we have some records queued for deletion
    delete_history_recs( $base, \@history_recs_to_delete );
    @history_recs_to_delete = ();
}


#===========================================
# "{priv,schedule}/history/nick/:nick/:tsrange" resource
#===========================================
foreach $base ( "priv/history/nick", "schedule/history/nick" ) {
    docu_check($test, "$base/:nick/:tsrange");
    #
    # GET
    #
    # - root employee, with tsrange, records found
    req( $test, 403, 'demo', 'GET', "$base/root/[999-12-31 23:59, 1000-01-01 00:01)" );
    $status = req( $test, 200, 'root', 'GET', "$base/root/[999-12-31 23:59, 1000-01-01 00:01)" );
    is( $status->level, 'OK' );
    is( $status->code, "DISPATCH_RECORDS_FOUND" );
    ok( defined $status->payload );
    ok( exists $status->payload->{'nick'} );
    is( $status->payload->{'nick'}, 'root' );
    ok( exists $status->payload->{'history'} );
    is( scalar @{ $status->payload->{'history'} }, 1 );
    is( $status->payload->{'history'}->[0]->{'eid'}, 1 );
    ok( exists $status->payload->{'history'}->[0]->{'effective'} );
    #
    # - non-existent employee
    my $tsr = '[999-12-31 23:59, 1000-01-01 00:01)';
    req( $test, 403, 'demo', 'GET', "$base/humphreybogart/$tsr" );
    $status = req( $test, 200, 'root', 'GET', "$base/humphreybogart/$tsr" );
    is( $status->level, 'ERR' );
    is( $status->code, 'DISPATCH_EMPLOYEE_DOES_NOT_EXIST' );
    #
    # - root employee, with tsrange but no records found
    req( $test, 403, 'demo', 'GET', "$base/root/[1999-12-31 23:59, 2000-01-01 00:01)" );
    req( $test, 404, 'root', 'GET', "$base/root/[1999-12-31 23:59, 2000-01-01 00:01)" );
    
    #
    # PUT, POST, DELETE
    #
    foreach my $user ( qw( demo root ) ) {
        foreach my $method ( qw( PUT POST DELETE ) ) {
            req( $test, 405, $user, $method, "$base/root/[1999-12-31 23:59, 2000-01-01 00:01)" );
        }
    }
}    


#===========================================
# "priv/history/phid/:phid" resource
# "schedule/history/shid/:shid" resource
#===========================================
foreach $base ( "priv/history/phid", "schedule/history/shid" ) {
    my $prop = ( $base =~ m/^priv/ ) ? 'phid' : 'shid';
    docu_check($test, "$base/:$prop" );
    #
    # preparation
    #
    my $tphid;
    if ( $base =~ m/^priv/ ) {
        # demo is a passerby
        $status = req( $test, 200, 'demo', 'GET', "priv/self" );
        is( $status->level, 'OK' );
        is( $status->payload->{'priv'}, "passerby" );
        #
        # make demo an 'inactive' user as of 1977-04-27 15:30
        $status = req( $test, 200, 'root', 'POST', "priv/history/nick/demo", 
            '{ "effective":"1977-04-27 15:30", "priv":"inactive" }' );
        is( $status->level, 'OK' );
        is( $status->code, 'DOCHAZKA_CUD_OK' );
        is( $status->payload->{'effective'}, '1977-04-27 15:30:00' );
        is( $status->payload->{'priv'}, 'inactive' );
        is( $status->payload->{'remark'}, undef );
        is( $status->payload->{'eid'}, 2 );
        ok( $status->payload->{'phid'} );
        $tphid = $status->payload->{'phid'};
        #
        # demo is an inactive
        $status = req( $test, 200, 'demo', 'GET', "priv/self" );
        is( $status->level, 'OK' );
        is( $status->payload->{'priv'}, "inactive" );
    } else {
        $status = req( $test, 200, 'root', 'POST', 'schedule/history/nick/demo', 
            '{ "effective":"1977-04-27 15:30", "sid":' . $ts_sid . ' }' );
        is( $status->level, 'OK' );
        is( $status->code, 'DOCHAZKA_CUD_OK' );
        $tphid = $status->payload->{'shid'};
    }
        
    
    #
    # GET
    #
    $status = req( $test, 200, 'root', 'GET', "$base/$tphid" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    is_deeply( $status->payload, {
        'remark' => undef,
        ( ( $base =~ m/^priv/ ) ? 'priv' : 'sid' ) => ( ( $base =~ m/^priv/ ) ? 'inactive' : $ts_sid ),
        'eid' => 2,
        $prop => $tphid,
        'effective' => '1977-04-27 15:30:00'
    } );
    
    #
    # PUT, POST
    #
    foreach my $user ( qw( demo root ) ) {
        foreach my $method ( qw( PUT POST ) ) {
            req( $test, 405, $user, $method, "$base/$tphid" );
        }
    }
    
    #
    # DELETE
    #
    # delete the privhistory record we created earlier
    $status = req( $test, 200, 'root', 'DELETE', "$base/$tphid" );
    is( $status->level, "OK" );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    #
    # not there anymore
    req( $test, 404, 'root', 'GET', "$base/$tphid" );
    #
    # and demo is a passerby again
    $status = req( $test, 200, 'demo', 'GET', "priv/self" );
    is( $status->level, 'OK' );
    is( $status->payload->{'priv'}, "passerby" );
} 

# delete the testing root shid and the testing schedule itself
$status = req( $test, 200, 'root', 'DELETE', "/schedule/history/shid/$root_shid" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

delete_testing_schedule( $ts_sid );

done_testing;
