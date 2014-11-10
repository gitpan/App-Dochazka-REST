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
# test schedule intervals resources
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

use App::CELL qw( $meta $site );
use App::Dochazka::REST;
use App::Dochazka::REST::Model::Schedintvls;
use App::Dochazka::REST::Model::Schedhistory;
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


#===========================================
# "schedule/intervals" resource
#===========================================
my $base = "schedule/intervals";
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
$status = req( $test, 200, 'root', 'DELETE', $base, "{ \"sid\":$sid }" );
diag( Dumper $status ) unless $status->ok;
is( $status->code, 'DOCHAZKA_CUD_OK' );

# - count should now be zero
$status = req( $test, 404, 'root', 'GET', 'schedule/all/disabled' );


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
