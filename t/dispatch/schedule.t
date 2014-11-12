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
# test schedule (non-history) resources
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

use App::CELL qw( $meta $site );
use App::Dochazka::REST;
use App::Dochazka::REST::Model::Schedhistory;
use App::Dochazka::REST::Model::Schedule qw( sid_exists );
use App::Dochazka::REST::Test;
use App::Dochazka::REST::Util::Timestamp qw( $today $today_ts $yesterday $tomorrow );
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
# "schedule" resource (again)
#=============================
my $base = "schedule";
docu_check($test, $base);
#
# GET
#
# - as demo
$status = req( $test, 200, 'demo', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
ok( scalar keys %{ $status->payload->{'resources'} } > 1 );
#
# - as root
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
ok( scalar keys %{ $status->payload->{'resources'} } >= 6 );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/self/?:tsrange'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/nick/:nick'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/nick/:nick/:tsrange'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/eid/:eid'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/eid/:eid/:tsrange'} );

#
# PUT
#
# - as demo
$status = req( $test, 200, 'demo', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );
# - as root
$status = req( $test, 200, 'root', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );

#
# POST
#
# - as demo
$status = req( $test, 200, 'demo', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );
# - as root
$status = req( $test, 200, 'root', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );

#
# DELETE
#
# - as demo
$status = req( $test, 200, 'demo', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );
# - as root
$status = req( $test, 200, 'root', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );


#===========================================
# "schedule/all" resource
#===========================================
$base = "schedule/all";
docu_check($test, $base);

my $ts_sid = create_testing_schedule( $test );

#
# GET
#
req( $test, 403, 'demo', 'GET', $base );
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
is( $status->{'count'}, 1 );
ok( exists $status->payload->[0]->{'sid'} );
ok( $status->payload->[0]->{'sid'} > 0 );
is( $ts_sid, $status->payload->[0]->{'sid'} );

#
# add six more schedules to the pot
#
my @sid_range;
foreach my $day ( 3..10 ) {
    my $intvls = [ 
        "[2000-01-" . ( $day + 1 ) . " 12:30, 2000-01-" . ( $day + 1 ) . " 16:30)",
        "[2000-01-" . ( $day + 1 ) . " 08:00, 2000-01-" . ( $day + 1 ) . " 12:00)",
        "[2000-01-" . ( $day ) . " 12:30, 2000-01-" . ( $day ) . " 16:30)",
        "[2000-01-" . ( $day ) . " 08:00, 2000-01-" . ( $day ) . " 12:00)",
        "[2000-01-" . ( $day - 1 ) . " 12:30, 2000-01-" . ( $day - 1 ) . " 16:30)",
        "[2000-01-" . ( $day - 1 ) . " 08:00, 2000-01-" . ( $day - 1 ) . " 12:00)",
    ];  
    my $intvls_json = JSON->new->utf8->canonical(1)->encode( $intvls );
    #   
    # - request as root 
    my $status = req( $test, 200, 'root', 'POST', "schedule/intervals", $intvls_json );
    is( $status->level, 'OK' );
    ok( $status->code eq 'DISPATCH_SCHEDULE_INSERT_OK' or $status->code eq 'DISPATCH_SCHEDULE_OK' );
    ok( exists $status->{'payload'} );
    ok( exists $status->payload->{'sid'} );
    my $sid = $status->payload->{'sid'};
    ok( sid_exists( $sid ) );
    push @sid_range, $sid;
}
#
# test a non-existent SID
ok( ! sid_exists( 53434 ), "non-existent SID" );
#
# now we get seven
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
is( $status->{'count'}, 7 );
#
# disable one at random
$status = req( $test, 200, 'root', 'POST', "schedule/sid/" . $sid_range[3], '{ "disabled":true }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
#
# now we get only six
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
is( $status->{'count'}, 6 );

#
# PUT, POST, DELETE
#
foreach my $user ( qw( demo root ) ) {
    foreach my $method ( qw( PUT POST DELETE ) ) {
        req( $test, 405, $user, $method, $base );
    }
}

#===========================================
# "schedule/all/disabled" resource
#===========================================
$base = "schedule/all/disabled";
docu_check($test, $base);

#
# GET
#
req( $test, 403, 'demo', 'GET', $base );
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
is( $status->{'count'}, 7 );

# 
# delete two schedules
#
my $counter = 0;
foreach my $sid ( @sid_range[0..1] ) {
    $counter += 1;
    $status = req( $test, 200, 'root', 'DELETE', "schedule/sid/$sid" );
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
}
is( $counter, 2 );

#
# now only 4 when disabled are not counted
#
$status = req( $test, 200, 'root', 'GET', 'schedule/all' );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
is( $status->{'count'}, 4 );

#
# the total number has dropped from 7 to 5
#
req( $test, 403, 'demo', 'GET', $base );
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
is( $status->{'count'}, 5 );

#
# delete them
#
my $obj = App::Dochazka::REST::Model::Schedule->spawn;
foreach my $schedule ( @{ $status->payload } ) {
    $obj->reset( $schedule );
    ok( sid_exists( $obj->sid ) );
    $status = req( $test, 200, 'root', 'DELETE', "schedule/sid/" . $obj->sid );
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    ok( ! sid_exists( $obj->sid ) );
}

# 
# total number is now zero
#
$status = req( $test, 404, 'root', 'GET', $base );

#
# PUT, POST, DELETE
#
foreach my $user ( qw( demo root ) ) {
    foreach my $method ( qw( PUT POST DELETE ) ) {
        req( $test, 405, $user, $method, $base );
    }
}

#delete_testing_schedule( $ts_sid );


#===========================================
# "schedule/eid/:eid/?:ts" resource
#===========================================
$base = "schedule/eid";
docu_check($test, "$base/:eid/?:ts");

$ts_sid = create_testing_schedule( $test );

#
# GET
#
#
# - root has no schedule
req( $test, 403, 'demo', 'GET', "$base/1" );
$status = req( $test, 200, 'root', 'GET', "$base/1" );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE" );
ok( defined $status->payload );
is_deeply( $status->payload, {
    "schedule" => {},
    "eid" => 1,
    "nick" => "root"
});
#
# - as root, with timestamp (before 1000 A.D. root was a passerby, but this is irrelevant for schedules)
$status = req( $test, 200, 'root', 'GET', "$base/1/999-12-31 23:59" );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE_AS_AT" );
is_deeply( $status->payload, {
    timestamp => "999-12-31 23:59",
    nick => "root",
    schedule => {},
    eid => 1
} );
#
# - as root, with timestamp (root became an admin on 1000-01-01 at 00:00, but this is irrelevant for schedules)
$status = req( $test, 200, 'root', 'GET', "$base/1/1000-01-01 00:01" );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE_AS_AT" );
is_deeply( $status->payload, {
    timestamp => "1000-01-01 00:01",
    nick => "root",
    schedule => {},
    eid => 1
} );

#
# PUT, POST, DELETE
#
foreach my $user ( qw( demo root ) ) {
    foreach my $method ( qw( PUT POST DELETE ) ) {
        foreach my $baz ( "$base/1", "$base/1/999-01-01" ) {
            req( $test, 405, $user, $method, $baz );
        }
    }
}

delete_testing_schedule( $ts_sid );


#=============================
# "schedule/help" resource
#=============================
$base = 'schedule/help';
docu_check($test, "$base");
#
# GET
#
# - as demo
$status = req( $test, 200, 'demo', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
ok( scalar keys %{ $status->payload->{'resources'} } > 1 );
#
# - as root
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
ok( scalar keys %{ $status->payload->{'resources'} } >= 6 );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/self/?:tsrange'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/nick/:nick'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/nick/:nick/:tsrange'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/eid/:eid'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/eid/:eid/:tsrange'} );

#
# PUT
#
# - as demo
$status = req( $test, 200, 'demo', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );
# - as root
$status = req( $test, 200, 'root', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );

#
# POST
#
# - as demo
$status = req( $test, 200, 'demo', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );
# - as root
$status = req( $test, 200, 'root', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );

#
# DELETE
#
# - as demo
$status = req( $test, 200, 'demo', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );
# - as root
$status = req( $test, 200, 'root', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );


#===========================================
# "schedule/intervals" resource
#===========================================
$base = "schedule/intervals";
docu_check( $test, $base );

#
# GET, PUT
#
req( $test, 405, 'demo', 'GET', $base );
req( $test, 405, 'root', 'GET', $base );
req( $test, 405, 'demo', 'PUT', $base );
req( $test, 405, 'root', 'PUT', $base );

# test typical workflow for this resource
#
# - set up an array of schedule intervals for testing
my $intvls = [
    "[$tomorrow 12:30, $tomorrow 16:30)",
    "[$tomorrow 08:00, $tomorrow 12:00)",
    "[$today 12:30, $today 16:30)",
    "[$today 08:00, $today 12:00)",
    "[$yesterday 12:30, $yesterday 16:30)",
    "[$yesterday 08:00, $yesterday 12:00)",
];
my $intvls_json = JSON->new->utf8->canonical(1)->encode( $intvls );
#

# - request as demo will fail with 403
req( $test, 403, 'demo', 'POST', $base, $intvls_json );

# - request as root with no request body will return DISPATCH_SCHEDINTVLS_MISSING
$status = req( $test, 200, 'root', 'POST', $base );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_SCHEDINTVLS_MISSING' );

# - request as root 
$status = req( $test, 200, 'root', 'POST', $base, $intvls_json );
diag( Dumper $status ) unless $status->ok;
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_SCHEDULE_INSERT_OK' );
ok( exists $status->{'payload'} );
ok( exists $status->payload->{'sid'} );
my $sid = $status->payload->{'sid'};

# - request the same schedule - code should change to DISPATCH_SCHEDULE_OK
$status = req( $test, 200, 'root', 'POST', $base, $intvls_json );
diag( Dumper $status ) unless $status->ok;
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_SCHEDULE_OK' );
ok( exists $status->{'payload'} );
ok( exists $status->payload->{'sid'} );
is( $status->payload->{'sid'}, $sid );

# - and now delete the schedules record (schedintvls records are already gone)
$status = req( $test, 200, 'root', 'DELETE', "schedule/sid/$sid" );
diag( Dumper $status ) unless $status->ok;
is( $status->code, 'DOCHAZKA_CUD_OK' );

# - count should now be zero
$status = req( $test, 404, 'root', 'GET', 'schedule/all/disabled' );


#===========================================
# "schedule/nick/:nick/?:ts" resource
#===========================================
$base = "schedule/nick";
docu_check($test, "$base/:nick/?:ts");
#
# GET
#
req( $test, 403, 'demo', 'GET', "$base/root" );
$status = req( $test, 200, 'root', 'GET', "$base/root" );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE" );
ok( defined $status->payload );
is_deeply( $status->payload, {
    "schedule" => {},
    "eid" => 1,
    "nick" => "root"
});
#
# - as root, with timestamp (before 1000 A.D. root was a passerby)
$status = req( $test, 200, 'root', 'GET', "$base/root/999-12-31 23:59" );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE_AS_AT" );
is_deeply( $status->payload, {
    timestamp => "999-12-31 23:59",
    nick => "root",
    schedule => {},
    eid => 1
} );
#
# - as root, with timestamp (root became an admin on 1000-01-01 at 00:00)
$status = req( $test, 200, 'root', 'GET', "$base/root/1000-01-01 00:01" );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE_AS_AT" );
is_deeply( $status->payload, {
    timestamp => "1000-01-01 00:01",
    nick => "root",
    schedule => {},
    eid => 1
} );

#
# PUT, POST, DELETE
#
foreach my $user ( qw( demo root ) ) {
    foreach my $method ( qw( PUT POST DELETE ) ) {
        foreach my $baz ( "$base/root", "$base/root/999-01-01" ) {
            req( $test, 405, $user, $method, $baz );
        }
    }
}



#=============================
# "schedule/self/?:ts" resource
#=============================
$base = "schedule/self";
docu_check($test, "$base/?:ts");
#
# GET
#
$status = req( $test, 200, 'demo', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE" );
ok( defined $status->payload );
ok( exists $status->payload->{'schedule'} );
#
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE" );
ok( defined $status->payload );
ok( exists $status->payload->{'schedule'} );
#
# - as root, with timestamp (before 1000 A.D. root was a passerby)
$status = req( $test, 200, 'root', 'GET', "$base/999-12-31 23:59" );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE_AS_AT" );
foreach my $key ( qw( timestamp eid nick schedule ) ) {
    ok( exists( $status->payload->{$key} ) );
}
#
# - as root, with timestamp (root became an admin on 1000-01-01 at 00:00)
$status = req( $test, 200, 'root', 'GET', "$base/1000-01-01 00:01" );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE_AS_AT" );
foreach my $key ( qw( timestamp eid nick schedule ) ) {
    ok( exists( $status->payload->{$key} ) );
}

#
# PUT, POST, DELETE
#
foreach my $user ( qw( demo root ) ) {
    foreach my $method ( qw( PUT POST DELETE ) ) {
        foreach my $baz ( $base, "$base/999-01-01" ) {
            req( $test, 405, $user, $method, $baz );
        }
    }
}


#===========================================
# "schedule/sid/:sid" resource
#===========================================
$base = 'schedule/sid';
docu_check( $test, "$base/:sid" );

$sid = create_testing_schedule( $test );

#
# GET
#
$status = req( $test, 200, 'root', 'GET', "$base/$sid" );
diag( Dumper $status ) unless $status->ok;
#diag( Dumper $status );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
is( $status->payload->{'disabled'}, 0 );
is( $status->payload->{'remark'}, undef );
is( $status->payload->{'schedule'}, '[{"high_dow":"FRI","high_time":"12:00","low_dow":"FRI","low_time":"08:00"},{"high_dow":"FRI","high_time":"16:30","low_dow":"FRI","low_time":"12:30"},{"high_dow":"SAT","high_time":"12:00","low_dow":"SAT","low_time":"08:00"},{"high_dow":"SAT","high_time":"16:30","low_dow":"SAT","low_time":"12:30"},{"high_dow":"SUN","high_time":"12:00","low_dow":"SUN","low_time":"08:00"},{"high_dow":"SUN","high_time":"16:30","low_dow":"SUN","low_time":"12:30"}]' );
ok( $status->payload->{'sid'} > 0 );
is( $status->payload->{'sid'}, $sid );

#
# PUT
#
req( $test, 405, 'demo', 'PUT', "$base/1" );
req( $test, 405, 'root', 'PUT', "$base/1" );

#
# POST
#
# - add a remark to the schedule
req( $test, 403, 'demo', 'POST', "$base/$sid" );
$status = req( $test, 200, 'root', 'POST', "$base/$sid", '{ "remark" : "foobar" }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
ok( exists( $status->{'payload'} ) );
ok( defined( $status->payload ) );
ok( exists( $status->{'payload'}->{'remark'} ) );
ok( defined( $status->{'payload'}->{'remark'} ) );
is( $status->{'payload'}->{'remark'}, "foobar" );
#
# verify with GET
$status = req( $test, 200, 'root', 'GET', "$base/$sid" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
is( $status->payload->{'remark'}, 'foobar' );
#
# - disable the schedule in the wrong way
$status = req( $test, 200, 'root', 'POST', "$base/$sid", '{ "pebble" : [1,2,3], "disabled":"hoogar" }' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/invalid input syntax for type boolean/ );
#
# - disable the schedule in the right way
$status = req( $test, 200, 'root', 'POST', "$base/$sid", '{ "pebble" : [1,2,3], "disabled":true }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );


#
# DELETE
#
# - delete the testing schedule 
$status = req( $test, 200, 'root', 'DELETE', "$base/$sid" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );


done_testing;
