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
# test privhistory resources
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


#=============================
# "priv" resource (again)
#=============================
docu_check($test, "priv");
#
# GET
#
# - as demo
$res = $test->request( req_root GET => '/priv' );
is( $res->code, 200 ); # this returns 500?????
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
ok( scalar keys %{ $status->payload->{'resources'} } > 1 );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
#
# - as root
$res = $test->request( req_root GET => '/priv' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
ok( scalar keys %{ $status->payload->{'resources'} } >= 6 );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
ok( exists $status->payload->{'resources'}->{'priv/history/self/?:tsrange'} );
ok( exists $status->payload->{'resources'}->{'priv/history/nick/:nick'} );
ok( exists $status->payload->{'resources'}->{'priv/history/nick/:nick/:tsrange'} );
ok( exists $status->payload->{'resources'}->{'priv/history/eid/:eid'} );
ok( exists $status->payload->{'resources'}->{'priv/history/eid/:eid/:tsrange'} );

#
# PUT
#
# - as demo
$res = $test->request( req_json_demo PUT => '/priv' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );

#
# POST
#
# - as demo
$res = $test->request( req_json_demo POST => '/priv' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
#ok( exists $status->payload->{'resources'}->{'priv/help'} );

#
# DELETE
#
# - as demo
$res = $test->request( req_json_demo DELETE => '/priv' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );


#=============================
# "priv/self/?:ts" resource
#=============================
docu_check($test, "priv/self/?:ts");
#
# GET
#
$res = $test->request( req_demo GET => "priv/self" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV" );
ok( defined $status->payload );
ok( exists $status->payload->{'priv'} );
is( $status->payload->{'priv'}, 'passerby' );
#
$res = $test->request( req_root GET => "priv/self" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV" );
ok( defined $status->payload );
ok( exists $status->payload->{'priv'} );
is( $status->payload->{'priv'}, 'admin' );
#
# - as root, with timestamp (before 1000 A.D. root was a passerby)
$res = $test->request( req_root GET => "priv/self/999-12-31 23:59" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV_AS_AT" );
is_deeply( $status->payload, {
    timestamp => "999-12-31 23:59",
    nick => "root",
    priv => "passerby",
    eid => "1"
} );
#
# - as root, with timestamp (root became an admin on 1000-01-01 at 00:00)
$res = $test->request( req_root GET => "priv/self/1000-01-01 00:01" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV_AS_AT" );
is_deeply( $status->payload, {
    timestamp => "1000-01-01 00:01",
    nick => "root",
    priv => "admin",
    eid => "1"
} );

#
# PUT, POST, DELETE
#
foreach my $base ( '/priv/self', '/priv/self/999-01-01' ) {
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


#===========================================
# "priv/eid/:eid/?:ts" resource
#===========================================
docu_check($test, "priv/eid/:eid/?:ts");
#
# GET
#
$res = $test->request( req_demo GET => "priv/eid/1" );
is( $res->code, 403 );
$res = $test->request( req_root GET => "priv/eid/1" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV" );
ok( defined $status->payload );
is_deeply( $status->payload, {
    "priv" => "admin",
    "eid" => "1",
    "nick" => "root"
});
#
# - as root, with timestamp (before 1000 A.D. root was a passerby)
$res = $test->request( req_root GET => "priv/eid/1/999-12-31 23:59" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV_AS_AT" );
is_deeply( $status->payload, {
    timestamp => "999-12-31 23:59",
    nick => "root",
    priv => "passerby",
    eid => "1"
} );
#
# - as root, with timestamp (root became an admin on 1000-01-01 at 00:00)
$res = $test->request( req_root GET => "priv/eid/1/1000-01-01 00:01" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV_AS_AT" );
is_deeply( $status->payload, {
    timestamp => "1000-01-01 00:01",
    nick => "root",
    priv => "admin",
    eid => "1"
} );

#
# PUT, POST, DELETE
#
foreach my $base ( '/priv/eid/1', '/priv/eid/1/999-01-01' ) {
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
# "priv/help" resource
#=============================
docu_check($test, "priv/help");
#
# GET
#
# - as demo
$res = $test->request( req_demo GET => '/priv/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
ok( scalar keys %{ $status->payload->{'resources'} } > 1 );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
#
# - as root
$res = $test->request( req_root GET => '/priv/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
ok( scalar keys %{ $status->payload->{'resources'} } >= 6 );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
ok( exists $status->payload->{'resources'}->{'priv/history/self/?:tsrange'} );
ok( exists $status->payload->{'resources'}->{'priv/history/nick/:nick'} );
ok( exists $status->payload->{'resources'}->{'priv/history/nick/:nick/:tsrange'} );
ok( exists $status->payload->{'resources'}->{'priv/history/eid/:eid'} );
ok( exists $status->payload->{'resources'}->{'priv/history/eid/:eid/:tsrange'} );

#
# PUT
#
# - as demo
$res = $test->request( req_json_demo PUT => '/priv/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );

#
# POST
#
# - as demo
$res = $test->request( req_json_demo POST => '/priv/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
#ok( exists $status->payload->{'resources'}->{'priv/help'} );

#
# DELETE
#
# - as demo
$res = $test->request( req_json_demo DELETE => '/priv/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );


#=============================
# "priv/history/self/?:tsrange" resource
#=============================
my $base = 'priv/history/self';
#
# RESOURCE DOCUMENTATION
#
docu_check($test, "$base/?:tsrange");
#
# GET
#
# - auth fail
$res = $test->request( req_demo GET => "$base" );
is( $res->code, 403 );
#
# as root
$res = $test->request( req_root GET => "$base" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
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
$res = $test->request( req_demo GET => "$base/[,)" );
is( $res->code, 403 );
$res = $test->request( req_root GET => "$base/[,)" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
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
$res = $test->request( req_root GET => "$base/[,sdf)" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/invalid input syntax for type timestamp/ );

#
# PUT, POST, DELETE
#
$res = $test->request( req_demo PUT => "$base" );
is( $res->code, 405);
$res = $test->request( req_demo POST => "$base" );
is( $res->code, 405);
$res = $test->request( req_demo DELETE => "$base" );
is( $res->code, 405);
#
$res = $test->request( req_demo PUT => "$base/[,)" );
is( $res->code, 405);
$res = $test->request( req_demo POST => "$base/[,)" );
is( $res->code, 405);
$res = $test->request( req_demo DELETE => "$base/[,)" );
is( $res->code, 405);


#===========================================
# "priv/history/eid/:eid" resource
#===========================================
docu_check($test, "priv/history/eid/:eid");
#
# GET
#
# - root employee
$res = $test->request( req_demo GET => '/priv/history/eid/' .  $site->DOCHAZKA_EID_OF_ROOT );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/priv/history/eid/' .  $site->DOCHAZKA_EID_OF_ROOT );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
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
$res = $test->request( req_demo GET => '/priv/history/eid/4534' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/priv/history/eid/4534' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EID_DOES_NOT_EXIST' );
#
# - invalid EID
$res = $test->request( req_demo GET => '/priv/history/eid/asas' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/priv/history/eid/asas' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/invalid input syntax for integer/ );

#
# PUT
#
# - we will be inserting a bunch of records so push them onto an array 
#   for easy deletion later
my @ph_to_delete;
# - be nice
my $j = '{ "effective":"1969-04-28 19:15", "priv":"inactive" }';
$res = $test->request( req_json_demo PUT => '/priv/history/eid/2', undef, $j );
is( $res->code, 403 );
$res = $test->request( req_json_root PUT => '/priv/history/eid/2', undef, $j );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
if ( $status->not_ok ) {
    diag( $status->code . ' ' . $status->text );
}
is( $status->level, 'OK' );
my $pho = $status->payload;
push @ph_to_delete, { eid => $pho->{eid}, phid => $pho->{phid} };
#
# - be pathological
$j = '{ "effective":"1979-05-24", "horse" : "E-Or" }';
$res = $test->request( req_json_demo PUT => '/priv/history/eid/2', undef, $j );
is( $res->code, 403 );
$res = $test->request( req_json_root PUT => '/priv/history/eid/2', undef, $j );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PRIVHISTORY_INVALID' );
#
# - addition of privlevel makes the above request less pathological
$j = '{ "effective":"1979-05-24", "horse" : "E-Or", "priv" : "admin" }';
$res = $test->request( req_json_demo PUT => '/priv/history/eid/2', undef, $j );
is( $res->code, 403 );
$res = $test->request( req_json_root PUT => '/priv/history/eid/2', undef, $j );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
$pho = $status->payload;
push @ph_to_delete, { eid => $pho->{eid}, phid => $pho->{phid} };
#
# - oops, we made demo an admin!
$j = '{ "effective":"2000-01-21", "priv" : "passerby" }';
$res = $test->request( req_json_demo PUT => '/priv/history/eid/2', undef, $j );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
$pho = $status->payload;
push @ph_to_delete, { eid => $pho->{eid}, phid => $pho->{phid} };

#
# POST
#
my $uri = '/priv/history/eid/2';
$res = $test->request( req_json_demo POST => $uri );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => $uri );
is( $res->code, 405 );

#
# DELETE
#
# - we have some records queued for deletion
foreach my $rec ( @ph_to_delete ) {
    $j = '{ "phid": ' . $rec->{phid} . ' }';
    $res = $test->request( req_json_root DELETE => '/priv/history/eid/' . $rec->{eid}, undef, $j );
    is( $res->code, 200 );
    is_valid_json( $res->content );
    $status = status_from_json( $res->content );
    is( $status->level, 'OK' );
}
@ph_to_delete = ();
    

#===========================================
# "priv/history/eid/:eid/:tsrange" resource
#===========================================
docu_check($test, "priv/history/eid/:eid/:tsrange");
#
# GET
#
# - root employee, with tsrange, records found
$res = $test->request( req_demo GET => '/priv/history/eid/' .  $site->DOCHAZKA_EID_OF_ROOT . 
    '/[999-12-31 23:59, 1000-01-01 00:01)' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/priv/history/eid/' .  $site->DOCHAZKA_EID_OF_ROOT . 
    '/[999-12-31 23:59, 1000-01-01 00:01)' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
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
$uri = '/priv/history/eid/' .  $site->DOCHAZKA_EID_OF_ROOT .
          '/[1999-12-31 23:59, 2000-01-01 00:01)';
$res = $test->request( req_demo GET => $uri );
is( $res->code, 403 );
$res = $test->request( req_root GET => $uri );
is( $res->code, 404 );
#
# - non-existent EID
my $tsr = '[1999-12-31 23:59, 2000-01-01 00:01)';
$res = $test->request( req_demo GET => "/priv/history/eid/4534/$tsr" );
is( $res->code, 403 );
$res = $test->request( req_root GET => "/priv/history/eid/4534/$tsr" );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EID_DOES_NOT_EXIST' );
#
# - invalid EID
$res = $test->request( req_demo GET => '/priv/history/eid/asas/$tsr' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/priv/history/eid/asas/$tsr' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/invalid input syntax for integer/ );

#
# PUT, POST, DELETE
#
$res = $test->request( req_json_demo PUT => $uri );
is( $res->code, 405 );
$res = $test->request( req_json_root PUT => $uri );
is( $res->code, 405 );
$res = $test->request( req_json_demo POST => $uri );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => $uri );
is( $res->code, 405 );
$res = $test->request( req_json_demo DELETE => $uri );
is( $res->code, 405 );
$res = $test->request( req_json_root DELETE => $uri );
is( $res->code, 405 );


#===========================================
# "priv/history/nick/:nick" resource
#===========================================
docu_check($test, "priv/history/nick/:nick");
#
# GET
#
# - root employee
$res = $test->request( req_demo GET => '/priv/history/nick/root' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/priv/history/nick/root' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
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
$res = $test->request( req_demo GET => '/priv/history/nick/humphreybogart' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/priv/history/nick/humphreybogart' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_NICK_DOES_NOT_EXIST' );

#
# PUT
#
$j = '{ "effective":"1969-04-27 9:45", "priv":"inactive" }';
$res = $test->request( req_json_demo PUT => '/priv/history/nick/demo', undef, $j );
is( $res->code, 403 );
$res = $test->request( req_json_root PUT => '/priv/history/nick/demo', undef, $j );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
if ( $status->not_ok ) {
    diag( $status->code . ' ' . $status->text );
}
is( $status->level, 'OK' );
$pho = $status->payload;
push @ph_to_delete, { nick => 'demo', phid => $pho->{phid} };

#
# POST
#
$uri = '/priv/history/nick/asdf';
$res = $test->request( req_json_demo POST => $uri );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => $uri );
is( $res->code, 405 );

#
# DELETE
#
# - we have some records queued for deletion
foreach my $rec ( @ph_to_delete ) {
    $j = '{ "phid": ' . $rec->{phid} . ' }';
    $res = $test->request( req_json_root DELETE => '/priv/history/nick/' .  $rec->{nick}, undef, $j );
    is( $res->code, 200 );
    is_valid_json( $res->content );
    $status = status_from_json( $res->content );
    is( $status->level, 'OK' );
}

#===========================================
# "priv/history/nick/:nick/:tsrange" resource
#===========================================
docu_check($test, "priv/history/nick/:nick/:tsrange");
#
# GET
#
# - root employee, with tsrange, records found
$res = $test->request( req_demo GET => '/priv/history/nick/root/[999-12-31 23:59, 1000-01-01 00:01)' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/priv/history/nick/root/[999-12-31 23:59, 1000-01-01 00:01)' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
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
$tsr = '[999-12-31 23:59, 1000-01-01 00:01)';
$res = $test->request( req_demo GET => "/priv/history/nick/humphreybogart/$tsr" );
is( $res->code, 403 );
$res = $test->request( req_root GET => "/priv/history/nick/humphreybogart/$tsr" );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_NICK_DOES_NOT_EXIST' );
#
# - root employee, with tsrange but no records found
$uri = '/priv/history/nick/root/[1999-12-31 23:59, 2000-01-01 00:01)';
$res = $test->request( req_demo GET => $uri );
is( $res->code, 403 );
$res = $test->request( req_root GET => $uri );
is( $res->code, 404 );

#
# PUT, POST, DELETE
#
$res = $test->request( req_json_demo PUT => $uri );
is( $res->code, 405 );
$res = $test->request( req_json_root PUT => $uri );
is( $res->code, 405 );
$res = $test->request( req_json_demo POST => $uri );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => $uri );
is( $res->code, 405 );
$res = $test->request( req_json_demo DELETE => $uri );
is( $res->code, 405 );
$res = $test->request( req_json_root DELETE => $uri );
is( $res->code, 405 );


#===========================================
# "priv/history/phid/:phid" resource
#===========================================
docu_check($test, "priv/history/phid/:phid");
#
# preparation
#
# demo is a passerby
$res = $test->request( req_demo GET => "priv/self" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->payload->{'priv'}, "passerby" );
#
# make demo an 'inactive' user as of 1977-04-27 15:30
$res = $test->request( req_json_root PUT => "priv/history/nick/demo", undef,
    '{ "effective":"1977-04-27 15:30", "priv":"inactive" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DOCHAZKA_CUD_OK' );
is( $status->payload->{'effective'}, '1977-04-27 15:30:00' );
is( $status->payload->{'priv'}, 'inactive' );
is( $status->payload->{'remark'}, undef );
is( $status->payload->{'eid'}, 2 );
ok( $status->payload->{'phid'} );
my $tphid = $status->payload->{'phid'};
#
# demo is an inactive
$res = $test->request( req_demo GET => "priv/self" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->payload->{'priv'}, "inactive" );

#
# GET
#
$res = $test->request( req_json_root GET => "priv/history/phid/$tphid" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
is_deeply( $status->payload, {
    'remark' => undef,
    'priv' => 'inactive',
    'eid' => 2,
    'phid' => $tphid,
    'effective' => '1977-04-27 15:30:00'
} );

#
# PUT, POST
#
$res = $test->request( req_json_demo PUT => "priv/history/phid/$tphid" );
is( $res->code, 405 );
$res = $test->request( req_json_root PUT => "priv/history/phid/$tphid" );
is( $res->code, 405 );
$res = $test->request( req_json_demo POST => "priv/history/phid/$tphid" );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => "priv/history/phid/$tphid" );
is( $res->code, 405 );

#
# DELETE
#
# delete the privhistory record we created earlier
$res = $test->request( req_json_root DELETE => "priv/history/phid/$tphid" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DOCHAZKA_CUD_OK' );
#
# not there anymore
$res = $test->request( req_json_root GET => "priv/history/phid/$tphid" );
is( $res->code, 404 );
#
# and demo is a passerby again
$res = $test->request( req_demo GET => "priv/self" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->payload->{'priv'}, "passerby" );


#===========================================
# "priv/nick/:nick/?:ts" resource
#===========================================
docu_check($test, "priv/nick/:nick/?:ts");
#
# GET
#
$res = $test->request( req_demo GET => "priv/nick/root" );
is( $res->code, 403 );
$res = $test->request( req_root GET => "priv/nick/root" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV" );
ok( defined $status->payload );
is_deeply( $status->payload, {
    "priv" => "admin",
    "eid" => "1",
    "nick" => "root"
});
#
# - as root, with timestamp (before 1000 A.D. root was a passerby)
$res = $test->request( req_root GET => "priv/nick/root/999-12-31 23:59" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV_AS_AT" );
is_deeply( $status->payload, {
    timestamp => "999-12-31 23:59",
    nick => "root",
    priv => "passerby",
    eid => "1"
} );
#
# - as root, with timestamp (root became an admin on 1000-01-01 at 00:00)
$res = $test->request( req_root GET => "priv/nick/root/1000-01-01 00:01" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV_AS_AT" );
is_deeply( $status->payload, {
    timestamp => "1000-01-01 00:01",
    nick => "root",
    priv => "admin",
    eid => "1"
} );

#
# PUT, POST, DELETE
#
foreach my $base ( '/priv/nick/root', '/priv/nick/root/999-01-01' ) {
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

done_testing;
