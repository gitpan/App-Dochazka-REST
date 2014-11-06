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
# test schedule resources
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

use App::CELL qw( $meta $site );
use App::Dochazka::REST;
use App::Dochazka::REST::Model::Schedhistory;
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
# "schedule" resource (again)
#=============================
my $base = "schedule";
docu_check($test, $base);
#
# GET
#
# - as demo
$res = $test->request( req_root GET => $base );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
ok( scalar keys %{ $status->payload->{'resources'} } > 1 );
#
# - as root
$res = $test->request( req_root GET => $base );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
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
$res = $test->request( req_json_demo PUT => $base );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );

#
# POST
#
# - as demo
$res = $test->request( req_json_demo POST => $base );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
#ok( exists $status->payload->{'resources'}->{'schedule/help'} );

#
# DELETE
#
# - as demo
$res = $test->request( req_json_demo DELETE => $base );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'schedule/help'} );


#===========================================
# "schedule/all" resource
#===========================================
$base = "schedule/all";
docu_check($test, $base);

create_testing_schedule( $test );

#
# GET
#
$res = $test->request( req_json_demo GET => $base );
is( $res->code, 403 ); # FORBIDDEN
$res = $test->request( req_json_root GET => $base );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
is( $status->{'count'}, 1 );
ok( exists $status->payload->[0]->{'sid'} );
ok( $status->payload->[0]->{'sid'} > 0 );
my $ts_sid = $status->payload->[0]->{'sid'};


#
# PUT, POST, DELETE
#
$res = $test->request( req_json_demo PUT => $base );
is( $res->code, 405 );
$res = $test->request( req_json_root PUT => $base );
is( $res->code, 405 );
$res = $test->request( req_json_demo POST => $base );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => $base );
is( $res->code, 405 );
$res = $test->request( req_json_demo DELETE => $base );
is( $res->code, 405 );
$res = $test->request( req_json_root DELETE => $base );
is( $res->code, 405 );



#===========================================
# "schedule/all/disabled" resource
#===========================================
$base = "schedule/all/disabled";
docu_check($test, $base);

#
# GET
#
$res = $test->request( req_json_demo GET => $base );
is( $res->code, 403 ); # FORBIDDEN
$res = $test->request( req_json_root GET => $base );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
is( $status->{'count'}, 1 );

#
# PUT, POST, DELETE
#
$res = $test->request( req_json_demo PUT => $base );
is( $res->code, 405 );
$res = $test->request( req_json_root PUT => $base );
is( $res->code, 405 );
$res = $test->request( req_json_demo POST => $base );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => $base );
is( $res->code, 405 );
$res = $test->request( req_json_demo DELETE => $base );
is( $res->code, 405 );
$res = $test->request( req_json_root DELETE => $base );
is( $res->code, 405 );



#===========================================
# "schedule/eid/:eid/?:ts" resource
#===========================================
$base = "schedule/eid";
docu_check($test, "$base/:eid/?:ts");
#
# GET
#
#
# - root has no schedule
$res = $test->request( req_demo GET => "$base/1" );
is( $res->code, 403 );
$res = $test->request( req_root GET => "$base/1" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE" );
ok( defined $status->payload );
is_deeply( $status->payload, {
    "schedule" => {},
    "eid" => 1,
    "nick" => "root"
});
#
# - as root, with timestamp (before 1000 A.D. root was a passerby, but this is irrelevant for schedules)
$res = $test->request( req_root GET => "$base/1/999-12-31 23:59" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
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
$res = $test->request( req_root GET => "$base/1/1000-01-01 00:01" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
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
foreach my $baz ( '/schedule/eid/1', '/schedule/eid/1/999-01-01' ) {
    $res = $test->request( req_demo PUT => "$baz" );
    is( $res->code, 405);
    $res = $test->request( req_demo POST => "$baz" );
    is( $res->code, 405);
    $res = $test->request( req_demo DELETE => "$baz" );
    is( $res->code, 405);
    #
    $res = $test->request( req_root PUT => "$baz" );
    is( $res->code, 405);
    $res = $test->request( req_root POST => "$baz" );
    is( $res->code, 405);
    $res = $test->request( req_root DELETE => "$baz" );
    is( $res->code, 405);
}


#=============================
# "schedule/help" resource
#=============================
$base = 'schedule/help';
docu_check($test, "$base");
#
# GET
#
# - as demo
$res = $test->request( req_demo GET => $base );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
ok( scalar keys %{ $status->payload->{'resources'} } > 1 );
#
# - as root
$res = $test->request( req_root GET => $base );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
ok( scalar keys %{ $status->payload->{'resources'} } >= 6 );
ok( exists $status->payload->{'resources'}->{$base} );
ok( exists $status->payload->{'resources'}->{'schedule/history/self/?:tsrange'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/nick/:nick'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/nick/:nick/:tsrange'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/eid/:eid'} );
ok( exists $status->payload->{'resources'}->{'schedule/history/eid/:eid/:tsrange'} );

#
# PUT
#
# - as demo
$res = $test->request( req_json_demo PUT => $base );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{$base} );

#
# POST
#
# - as demo
$res = $test->request( req_json_demo POST => $base );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
#ok( exists $status->payload->{'resources'}->{$base} );

#
# DELETE
#
# - as demo
$res = $test->request( req_json_demo DELETE => $base );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{$base} );



##=============================
## "schedule/history/self/?:tsrange" resource
##=============================
#$base = 'schedule/history/self';
##
## RESOURCE DOCUMENTATION
##
#docu_check($test, "$base/?:tsrange");
##
## GET
##
## - auth fail
#$res = $test->request( req_demo GET => $base );
#is( $res->code, 403 );
##
## as root
#$res = $test->request( req_root GET => $base );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->ok );
#is( $status->code, "DISPATCH_RECORDS_FOUND" );
#ok( defined $status->payload );
#ok( exists $status->payload->{'eid'} );
#is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
#ok( exists $status->payload->{'history'} );
#is( scalar @{ $status->payload->{'history'} }, 1 );
#is( $status->payload->{'history'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
#ok( exists $status->payload->{'history'}->[0]->{'effective'} );
##
## with a valid tsrange
#$res = $test->request( req_demo GET => "$base/[,)" );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => "$base/[,)" );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->ok );
#is( $status->code, "DISPATCH_RECORDS_FOUND" );
#ok( defined $status->payload );
#ok( exists $status->payload->{'eid'} );
#is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
#ok( exists $status->payload->{'history'} );
#is( scalar @{ $status->payload->{'history'} }, 1 );
#is( $status->payload->{'history'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
#ok( exists $status->payload->{'history'}->[0]->{'effective'} );
##
## - with invalid tsrange
#$res = $test->request( req_root GET => "$base/[,sdf)" );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->not_ok );
#is( $status->level, 'ERR' );
#is( $status->code, 'DOCHAZKA_DBI_ERR' );
#like( $status->text, qr/invalid input syntax for type timestamp/ );
#
##
## PUT, POST, DELETE
##
#$res = $test->request( req_demo PUT => $base );
#is( $res->code, 405);
#$res = $test->request( req_demo POST => $base );
#is( $res->code, 405);
#$res = $test->request( req_demo DELETE => $base );
#is( $res->code, 405);
##
#$res = $test->request( req_demo PUT => "$base/[,)" );
#is( $res->code, 405);
#$res = $test->request( req_demo POST => "$base/[,)" );
#is( $res->code, 405);
#$res = $test->request( req_demo DELETE => "$base/[,)" );
#is( $res->code, 405);


##===========================================
## "schedule/history/eid/:eid" resource
##===========================================
#$base = "schedule/history/eid";
#docu_check($test, "$base/:eid");
##
## GET
##
## - root employee
#$res = $test->request( req_demo GET => $base . $site->DOCHAZKA_EID_OF_ROOT );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => $base . $site->DOCHAZKA_EID_OF_ROOT );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->ok );
#is( $status->code, "DISPATCH_RECORDS_FOUND" );
#ok( defined $status->payload );
#ok( exists $status->payload->{'eid'} );
#is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
#ok( exists $status->payload->{'history'} );
#is( scalar @{ $status->payload->{'history'} }, 1 );
#is( $status->payload->{'history'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
#ok( exists $status->payload->{'history'}->[0]->{'effective'} );
##
## - non-existent EID
#$res = $test->request( req_demo GET => "$base/4534" );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => "$base/4534" );
#is( $res->code, 200 );
#is_valid_json( $res->content );
#$status = status_from_json( $res->content );
#is( $status->level, 'ERR' );
#is( $status->code, 'DISPATCH_EID_DOES_NOT_EXIST' );
##
## - invalid EID
#$res = $test->request( req_demo GET => "$base/asas" );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => "$base/asas" );
#is( $res->code, 200 );
#is_valid_json( $res->content );
#$status = status_from_json( $res->content );
#is( $status->level, 'ERR' );
#is( $status->code, 'DOCHAZKA_DBI_ERR' );
#like( $status->text, qr/invalid input syntax for integer/ );
#
##
## PUT
##
## - we will be inserting a bunch of records so push them onto an array 
##   for easy deletion later
#my @ph_to_delete;
## - be nice
#my $j = '{ "effective":"1969-04-28 19:15", "priv":"inactive" }';
#$res = $test->request( req_json_demo PUT => "$base/2", undef, $j );
#is( $res->code, 403 );
#$res = $test->request( req_json_root PUT => "$base/2", undef, $j );
#is( $res->code, 200 );
#is_valid_json( $res->content );
#$status = status_from_json( $res->content );
#if ( $status->not_ok ) {
#    diag( $status->code . ' ' . $status->text );
#}
#is( $status->level, 'OK' );
#my $pho = $status->payload;
#push @ph_to_delete, { eid => $pho->{eid}, phid => $pho->{phid} };
##
## - be pathological
#$j = '{ "effective":"1979-05-24", "horse" : "E-Or" }';
#$res = $test->request( req_json_demo PUT => "$base/2", undef, $j );
#is( $res->code, 403 );
#$res = $test->request( req_json_root PUT => "$base/2", undef, $j );
#is( $res->code, 200 );
#is_valid_json( $res->content );
#$status = status_from_json( $res->content );
#is( $status->level, 'ERR' );
#is( $status->code, 'DISPATCH_PRIVHISTORY_INVALID' );
##
## - addition of privlevel makes the above request less pathological
#$j = '{ "effective":"1979-05-24", "horse" : "E-Or", "priv" : "admin" }';
#$res = $test->request( req_json_demo PUT => "$base/2", undef, $j );
#is( $res->code, 403 );
#$res = $test->request( req_json_root PUT => "$base/2", undef, $j );
#is( $res->code, 200 );
#is_valid_json( $res->content );
#$status = status_from_json( $res->content );
#is( $status->level, 'OK' );
#$pho = $status->payload;
#push @ph_to_delete, { eid => $pho->{eid}, phid => $pho->{phid} };
##
## - oops, we made demo an admin!
#$j = '{ "effective":"2000-01-21", "priv" : "passerby" }';
#$res = $test->request( req_json_demo PUT => "$base/2", undef, $j );
#is( $res->code, 200 );
#is_valid_json( $res->content );
#$status = status_from_json( $res->content );
#is( $status->level, 'OK' );
#$pho = $status->payload;
#push @ph_to_delete, { eid => $pho->{eid}, phid => $pho->{phid} };
#
##
## POST
##
#my $uri = "$base/2";
#$res = $test->request( req_json_demo POST => $uri );
#is( $res->code, 405 );
#$res = $test->request( req_json_root POST => $uri );
#is( $res->code, 405 );
#
##
## DELETE
##
## - we have some records queued for deletion
#foreach my $rec ( @ph_to_delete ) {
#    $j = '{ "phid": ' . $rec->{phid} . ' }';
#    $res = $test->request( req_json_root DELETE => $base . $rec->{eid}, undef, $j );
#    is( $res->code, 200 );
#    is_valid_json( $res->content );
#    $status = status_from_json( $res->content );
#    is( $status->level, 'OK' );
#}
#@ph_to_delete = ();
    

##===========================================
## "schedule/history/eid/:eid/:tsrange" resource
##===========================================
#$base = "schedule/history/eid";
#docu_check($test, "$base/:eid/:tsrange");
##
## GET
##
## - root employee, with tsrange, records found
#$res = $test->request( req_demo GET => $base . $site->DOCHAZKA_EID_OF_ROOT . 
#    '/[999-12-31 23:59, 1000-01-01 00:01)' );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => $base . $site->DOCHAZKA_EID_OF_ROOT . 
#    '/[999-12-31 23:59, 1000-01-01 00:01)' );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->ok );
#is( $status->code, "DISPATCH_RECORDS_FOUND" );
#ok( defined $status->payload );
#ok( exists $status->payload->{'eid'} );
#is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
#ok( exists $status->payload->{'history'} );
#is( scalar @{ $status->payload->{'history'} }, 1 );
#is( $status->payload->{'history'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
#ok( exists $status->payload->{'history'}->[0]->{'effective'} );
##
## - root employee, with tsrange but no records found
#$uri = $base . $site->DOCHAZKA_EID_OF_ROOT .
#          '/[1999-12-31 23:59, 2000-01-01 00:01)';
#$res = $test->request( req_demo GET => $uri );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => $uri );
#is( $res->code, 404 );
##
## - non-existent EID
#my $tsr = '[1999-12-31 23:59, 2000-01-01 00:01)';
#$res = $test->request( req_demo GET => "$base/4534/$tsr" );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => "$base/4534/$tsr" );
#is( $res->code, 200 );
#is_valid_json( $res->content );
#$status = status_from_json( $res->content );
#is( $status->level, 'ERR' );
#is( $status->code, 'DISPATCH_EID_DOES_NOT_EXIST' );
##
## - invalid EID
#$res = $test->request( req_demo GET => "$base/asas/$tsr" );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => "$base/asas/$tsr" );
#is( $res->code, 200 );
#is_valid_json( $res->content );
#$status = status_from_json( $res->content );
#is( $status->level, 'ERR' );
#is( $status->code, 'DOCHAZKA_DBI_ERR' );
#like( $status->text, qr/invalid input syntax for integer/ );
#
##
## PUT, POST, DELETE
##
#$res = $test->request( req_json_demo PUT => $uri );
#is( $res->code, 405 );
#$res = $test->request( req_json_root PUT => $uri );
#is( $res->code, 405 );
#$res = $test->request( req_json_demo POST => $uri );
#is( $res->code, 405 );
#$res = $test->request( req_json_root POST => $uri );
#is( $res->code, 405 );
#$res = $test->request( req_json_demo DELETE => $uri );
#is( $res->code, 405 );
#$res = $test->request( req_json_root DELETE => $uri );
#is( $res->code, 405 );


##===========================================
## "schedule/history/nick/:nick" resource
##===========================================
#$base = "schedule/history/nick"
#docu_check($test, "$base/:nick");
##
## GET
##
## - root employee
#$res = $test->request( req_demo GET => "$base/root" );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => "$base/root" );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->ok );
#is( $status->code, "DISPATCH_RECORDS_FOUND" );
#ok( defined $status->payload );
#ok( exists $status->payload->{'nick'} );
#is( $status->payload->{'nick'}, 'root' );
#ok( exists $status->payload->{'history'} );
#is( scalar @{ $status->payload->{'history'} }, 1 );
#is( $status->payload->{'history'}->[0]->{'eid'}, 1 );
#ok( exists $status->payload->{'history'}->[0]->{'effective'} );
##
## - non-existent employee
#$res = $test->request( req_demo GET => "$base/humphreybogart" );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => "$base/humphreybogart" );
#is( $res->code, 200 );
#is_valid_json( $res->content );
#$status = status_from_json( $res->content );
#is( $status->level, 'ERR' );
#is( $status->code, 'DISPATCH_NICK_DOES_NOT_EXIST' );
#
##
## PUT
##
#$j = '{ "effective":"1969-04-27 9:45", "priv":"inactive" }';
#$res = $test->request( req_json_demo PUT => "$base/demo', undef, $j );
#is( $res->code, 403 );
#$res = $test->request( req_json_root PUT => "$base/demo', undef, $j );
#is( $res->code, 200 );
#is_valid_json( $res->content );
#$status = status_from_json( $res->content );
#if ( $status->not_ok ) {
#    diag( $status->code . ' ' . $status->text );
#}
#is( $status->level, 'OK' );
#$pho = $status->payload;
#push @ph_to_delete, { nick => 'demo', phid => $pho->{phid} };
#
##
## POST
##
#$uri = "$base/asdf";
#$res = $test->request( req_json_demo POST => $uri );
#is( $res->code, 405 );
#$res = $test->request( req_json_root POST => $uri );
#is( $res->code, 405 );
#
##
## DELETE
##
## - we have some records queued for deletion
#foreach my $rec ( @ph_to_delete ) {
#    $j = '{ "phid": ' . $rec->{phid} . ' }';
#    $res = $test->request( req_json_root DELETE => $base . $rec->{nick}, undef, $j );
#    is( $res->code, 200 );
#    is_valid_json( $res->content );
#    $status = status_from_json( $res->content );
#    is( $status->level, 'OK' );
#}

##===========================================
## "schedule/history/nick/:nick/:tsrange" resource
##===========================================
#docu_check($test, "$base/:nick/:tsrange");
##
## GET
##
## - root employee, with tsrange, records found
#$res = $test->request( req_demo GET => "$base/root/[999-12-31 23:59, 1000-01-01 00:01)" );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => "$base/root/[999-12-31 23:59, 1000-01-01 00:01)' );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->ok );
#is( $status->code, "DISPATCH_RECORDS_FOUND" );
#ok( defined $status->payload );
#ok( exists $status->payload->{'nick'} );
#is( $status->payload->{'nick'}, 'root' );
#ok( exists $status->payload->{'history'} );
#is( scalar @{ $status->payload->{'history'} }, 1 );
#is( $status->payload->{'history'}->[0]->{'eid'}, 1 );
#ok( exists $status->payload->{'history'}->[0]->{'effective'} );
##
## - non-existent employee
#$tsr = '[999-12-31 23:59, 1000-01-01 00:01)';
#$res = $test->request( req_demo GET => "$base/humphreybogart/$tsr" );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => "$base/humphreybogart/$tsr" );
#is( $res->code, 200 );
#is_valid_json( $res->content );
#$status = status_from_json( $res->content );
#is( $status->level, 'ERR' );
#is( $status->code, 'DISPATCH_NICK_DOES_NOT_EXIST' );
##
## - root employee, with tsrange but no records found
#$uri = "$base/root/[1999-12-31 23:59, 2000-01-01 00:01)";
#$res = $test->request( req_demo GET => $uri );
#is( $res->code, 403 );
#$res = $test->request( req_root GET => $uri );
#is( $res->code, 404 );
#
##
## PUT, POST, DELETE
##
#$res = $test->request( req_json_demo PUT => $uri );
#is( $res->code, 405 );
#$res = $test->request( req_json_root PUT => $uri );
#is( $res->code, 405 );
#$res = $test->request( req_json_demo POST => $uri );
#is( $res->code, 405 );
#$res = $test->request( req_json_root POST => $uri );
#is( $res->code, 405 );
#$res = $test->request( req_json_demo DELETE => $uri );
#is( $res->code, 405 );
#$res = $test->request( req_json_root DELETE => $uri );
#is( $res->code, 405 );


##===========================================
## "schedule/history/phid/:phid" resource
##===========================================
#$base = "schedule/history/phid"
#docu_check($test, "$base/:phid");
##
## preparation
##
## demo is a passerby
#$res = $test->request( req_demo GET => "priv/self" );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->ok );
#is( $status->payload->{'priv'}, "passerby" );
##
## make demo an 'inactive' user as of 1977-04-27 15:30
#$res = $test->request( req_json_root PUT => "priv/history/nick/demo", undef,
#    '{ "effective":"1977-04-27 15:30", "priv":"inactive" }' );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->ok );
#is( $status->code, 'DOCHAZKA_CUD_OK' );
#is( $status->payload->{'effective'}, '1977-04-27 15:30:00' );
#is( $status->payload->{'priv'}, 'inactive' );
#is( $status->payload->{'remark'}, undef );
#is( $status->payload->{'eid'}, 2 );
#ok( $status->payload->{'phid'} );
#my $tphid = $status->payload->{'phid'};
##
## demo is an inactive
#$res = $test->request( req_demo GET => "priv/self" );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->ok );
#is( $status->payload->{'priv'}, "inactive" );
#
##
## GET
##
#$res = $test->request( req_json_root GET => "$base/$tphid" );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->ok );
#is( $status->code, 'DISPATCH_RECORDS_FOUND' );
#is_deeply( $status->payload, {
#    'remark' => undef,
#    'priv' => 'inactive',
#    'eid' => 2,
#    'phid' => $tphid,
#    'effective' => '1977-04-27 15:30:00'
#} );
#
##
## PUT, POST
##
#$res = $test->request( req_json_demo PUT => "$base/$tphid" );
#is( $res->code, 405 );
#$res = $test->request( req_json_root PUT => "$base/$tphid" );
#is( $res->code, 405 );
#$res = $test->request( req_json_demo POST => "$base/$tphid" );
#is( $res->code, 405 );
#$res = $test->request( req_json_root POST => "$base/$tphid" );
#is( $res->code, 405 );
#
##
## DELETE
##
## delete the privhistory record we created earlier
#$res = $test->request( req_json_root DELETE => "$base/$tphid" );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->ok );
#is( $status->code, 'DOCHAZKA_CUD_OK' );
##
## not there anymore
#$res = $test->request( req_json_root GET => "$base/$tphid" );
#is( $res->code, 404 );
##
## and demo is a passerby again
#$res = $test->request( req_demo GET => "priv/self" );
#is( $res->code, 200 );
#$status = status_from_json( $res->content );
#ok( $status->ok );
#is( $status->payload->{'priv'}, "passerby" );


#===========================================
# "schedule/nick/:nick/?:ts" resource
#===========================================
$base = "schedule/nick";
docu_check($test, "$base/:nick/?:ts");
#
# GET
#
$res = $test->request( req_demo GET => "$base/root" );
is( $res->code, 403 );
$res = $test->request( req_root GET => "$base/root" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE" );
ok( defined $status->payload );
is_deeply( $status->payload, {
    "schedule" => {},
    "eid" => 1,
    "nick" => "root"
});
#
# - as root, with timestamp (before 1000 A.D. root was a passerby)
$res = $test->request( req_root GET => "$base/root/999-12-31 23:59" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
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
$res = $test->request( req_root GET => "$base/root/1000-01-01 00:01" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
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
foreach my $base ( "$base/root", "$base/999-01-01" ) {
    $res = $test->request( req_demo PUT => "$base" );
    is( $res->code, 405);
    $res = $test->request( req_demo POST => "$base" );
    is( $res->code, 405);
    $res = $test->request( req_demo DELETE => "$base" );
    is( $res->code, 405);
    #
    $res = $test->request( req_root PUT => "$base" );
    is( $res->code, 405);
    $res = $test->request( req_root POST => "$base" );
    is( $res->code, 405);
    $res = $test->request( req_root DELETE => "$base" );
    is( $res->code, 405);
}


#=============================
# "schedule/self/?:ts" resource
#=============================
$base = "schedule/self";
docu_check($test, "$base/?:ts");
#
# GET
#
$res = $test->request( req_demo GET => $base );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE" );
ok( defined $status->payload );
ok( exists $status->payload->{'schedule'} );
#
$res = $test->request( req_root GET => "$base" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE" );
ok( defined $status->payload );
ok( exists $status->payload->{'schedule'} );
#
# - as root, with timestamp (before 1000 A.D. root was a passerby)
$res = $test->request( req_root GET => "$base/999-12-31 23:59" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE_AS_AT" );
#is_deeply( $status->payload, {
#    timestamp => "999-12-31 23:59",
#    nick => "root",
#    priv => "passerby",
#} );
#
# - as root, with timestamp (root became an admin on 1000-01-01 at 00:00)
$res = $test->request( req_root GET => "$base/1000-01-01 00:01" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_SCHEDULE_AS_AT" );
#is_deeply( $status->payload, {
#    timestamp => "1000-01-01 00:01",
#    nick => "root",
#    priv => "admin",
#    eid => "1"
#} );

#
# PUT, POST, DELETE
#
foreach my $baz ( '/schedule/self', '/schedule/self/999-01-01' ) {
    $res = $test->request( req_demo PUT => "$baz" );
    is( $res->code, 405);
    $res = $test->request( req_demo POST => "$baz" );
    is( $res->code, 405);
    $res = $test->request( req_demo DELETE => "$baz" );
    is( $res->code, 405);
    #
    $res = $test->request( req_root PUT => "$baz" );
    is( $res->code, 405);
    $res = $test->request( req_root POST => "$baz" );
    is( $res->code, 405);
    $res = $test->request( req_root DELETE => "$baz" );
    is( $res->code, 405);
}

delete_testing_schedule( $ts_sid );

done_testing;
