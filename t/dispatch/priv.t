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
my $base = 'priv';
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
ok( exists $status->payload->{'resources'}->{'priv/help'} );
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
$status = req( $test, 200, 'demo', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
#
# - as root
$status = req( $test, 200, 'root', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );

#
# POST
#
# - as demo
$status = req( $test, 200, 'demo', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
# - as root
$status = req( $test, 200, 'root', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
#ok( exists $status->payload->{'resources'}->{'priv/help'} );

#
# DELETE
#
# - as demo
$status = req( $test, 200, 'demo', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
# - as root
$status = req( $test, 200, 'root', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );


#=============================
# "priv/self/?:ts" resource
#=============================
$base = "priv/self";
docu_check($test, "$base/?:ts");
#
# GET
#
$status = req( $test, 200, 'demo', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV" );
ok( defined $status->payload );
ok( exists $status->payload->{'priv'} );
is( $status->payload->{'priv'}, 'passerby' );
#
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV" );
ok( defined $status->payload );
ok( exists $status->payload->{'priv'} );
is( $status->payload->{'priv'}, 'admin' );
#
# - as root, with timestamp (before 1000 A.D. root was a passerby)
$status = req( $test, 200, 'root', 'GET', "$base/999-12-31 23:59" );
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
$status = req( $test, 200, 'root', 'GET', "$base/1000-01-01 00:01" );
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
    req( $test, 405, 'demo', 'PUT', $base );
    req( $test, 405, 'demo', 'POST', $base );
    req( $test, 405, 'demo', 'DELETE', $base );
    #
    req( $test, 405, 'root', 'PUT', $base );
    req( $test, 405, 'root', 'POST', $base );
    req( $test, 405, 'root', 'DELETE', $base );
}


#===========================================
# "priv/eid/:eid/?:ts" resource
#===========================================
$base = "priv/eid";
docu_check($test, "$base/:eid/?:ts");

#
# GET
#
#
# - as demo
req( $test, 403, 'demo', 'GET', "$base/1" );
#
# - as root
$status = req( $test, 200, 'root', 'GET', "$base/1" );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV" );
ok( defined $status->payload );
is_deeply( $status->payload, {
    "priv" => "admin",
    "eid" => "1",
    "nick" => "root"
});
#
# - as root, with timestamp (before 1000 A.D. root was a passerby)
$status = req( $test, 200, 'root', 'GET', "$base/1/999-12-31 23:59" );
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
$status = req( $test, 200, 'root', 'GET', "$base/1/1000-01-01 00:01" );
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
    req( $test, 405, 'demo', 'PUT', $base );
    req( $test, 405, 'demo', 'POST', $base );
    req( $test, 405, 'demo', 'DELETE', $base );
    #
    req( $test, 405, 'root', 'PUT', $base );
    req( $test, 405, 'root', 'POST', $base );
    req( $test, 405, 'root', 'DELETE', $base );
}


#=============================
# "priv/help" resource
#=============================
$base = "priv/help";
docu_check( $test, $base );
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
ok( exists $status->payload->{'resources'}->{'priv/help'} );
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
$status = req( $test, 200, 'demo', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
# - as root
$status = req( $test, 200, 'root', 'PUT', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );

#
# POST
#
# - as demo
$status = req( $test, 200, 'demo', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
# - as root
$status = req( $test, 200, 'root', 'POST', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );

#
# DELETE
#
# - as demo
$status = req( $test, 200, 'demo', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
# - as demo
$status = req( $test, 200, 'root', 'DELETE', $base );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );


#=============================
# "priv/history/self/?:tsrange" resource
#=============================
$base = 'priv/history/self';
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


#===========================================
# "priv/history/eid/:eid" resource
#===========================================
$base = "priv/history/eid";
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
is( $status->code, 'DISPATCH_EID_DOES_NOT_EXIST' );
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
# - we will be inserting a bunch of records so push them onto an array 
#   for easy deletion later
my @ph_to_delete;
# - be nice
my $j = '{ "effective":"1969-04-28 19:15", "priv":"inactive" }';
req( $test, 403, 'demo', 'PUT', "$base/2", $j );
$status = req( $test, 200, 'root', 'PUT', "$base/2", $j );
if ( $status->not_ok ) {
    diag( $status->code . ' ' . $status->text );
}
is( $status->level, 'OK' );
my $pho = $status->payload;
push @ph_to_delete, { eid => $pho->{eid}, phid => $pho->{phid} };
#
# - be pathological
$j = '{ "effective":"1979-05-24", "horse" : "E-Or" }';
req( $test, 403, 'demo', 'PUT', "$base/2", $j );
$status = req( $test, 200, 'root', 'PUT', "$base/2", $j );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PRIVHISTORY_INVALID' );
#
# - addition of privlevel makes the above request less pathological
$j = '{ "effective":"1979-05-24", "horse" : "E-Or", "priv" : "admin" }';
req( $test, 403, 'demo', 'PUT', "$base/2", $j );
$status = req( $test, 200, 'root', 'PUT', "$base/2", $j );
is( $status->level, 'OK' );
$pho = $status->payload;
push @ph_to_delete, { eid => $pho->{eid}, phid => $pho->{phid} };
#
# - oops, we made demo an admin!
$j = '{ "effective":"2000-01-21", "priv" : "passerby" }';
$status = req( $test, 200, 'demo', 'PUT', "$base/2", $j );
is( $status->level, 'OK' );
$pho = $status->payload;
push @ph_to_delete, { eid => $pho->{eid}, phid => $pho->{phid} };

#
# POST
#
req( $test, 405, 'demo', 'POST', "$base/2" );
req( $test, 405, 'active', 'POST', "$base/2" );
req( $test, 405, 'root', 'POST', "$base/2" );

#
# DELETE
#
# - we have some records queued for deletion
foreach my $rec ( @ph_to_delete ) {
    $j = '{ "phid": ' . $rec->{phid} . ' }';
    $status = req( $test, 200, 'root', 'DELETE', "$base/" . $rec->{eid}, $j );
    is( $status->level, 'OK' );
}
@ph_to_delete = ();
    

#===========================================
# "priv/history/eid/:eid/:tsrange" resource
#===========================================
$base = "priv/history/eid";
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
is( $status->code, 'DISPATCH_EID_DOES_NOT_EXIST' );
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


#===========================================
# "priv/history/nick/:nick" resource
#===========================================
$base = "priv/history/nick";
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
is( $status->code, 'DISPATCH_NICK_DOES_NOT_EXIST' );

#
# PUT
#
$j = '{ "effective":"1969-04-27 9:45", "priv":"inactive" }';
req( $test, 403, 'demo', 'PUT', "$base/demo", $j );
$status = req( $test, 200, 'root', 'PUT', "$base/demo", $j );
if ( $status->not_ok ) {
    diag( $status->code . ' ' . $status->text );
}
is( $status->level, 'OK' );
$pho = $status->payload;
push @ph_to_delete, { nick => 'demo', phid => $pho->{phid} };

#
# POST
#
req( $test, 405, 'demo', 'POST', "$base/asdf" );
req( $test, 405, 'root', 'POST', "$base/asdf" );

#
# DELETE
#
# - we have some records queued for deletion
foreach my $rec ( @ph_to_delete ) {
    $j = '{ "phid": ' . $rec->{phid} . ' }';
    $status = req( $test, 200, 'root', 'DELETE', "$base/" .  $rec->{nick}, $j );
    is( $status->level, 'OK' );
}

#===========================================
# "priv/history/nick/:nick/:tsrange" resource
#===========================================
$base = "priv/history/nick";
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
$tsr = '[999-12-31 23:59, 1000-01-01 00:01)';
req( $test, 403, 'demo', 'GET', "$base/humphreybogart/$tsr" );
$status = req( $test, 200, 'root', 'GET', "$base/humphreybogart/$tsr" );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_NICK_DOES_NOT_EXIST' );
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


#===========================================
# "priv/history/phid/:phid" resource
#===========================================
$base = "priv/history/phid";
docu_check($test, "$base/:phid");
#
# preparation
#
# demo is a passerby
$status = req( $test, 200, 'demo', 'GET', "priv/self" );
is( $status->level, 'OK' );
is( $status->payload->{'priv'}, "passerby" );
#
# make demo an 'inactive' user as of 1977-04-27 15:30
$status = req( $test, 200, 'root', 'PUT', "priv/history/nick/demo", 
    '{ "effective":"1977-04-27 15:30", "priv":"inactive" }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
is( $status->payload->{'effective'}, '1977-04-27 15:30:00' );
is( $status->payload->{'priv'}, 'inactive' );
is( $status->payload->{'remark'}, undef );
is( $status->payload->{'eid'}, 2 );
ok( $status->payload->{'phid'} );
my $tphid = $status->payload->{'phid'};
#
# demo is an inactive
$status = req( $test, 200, 'demo', 'GET', "priv/self" );
is( $status->level, 'OK' );
is( $status->payload->{'priv'}, "inactive" );

#
# GET
#
$status = req( $test, 200, 'root', 'GET', "$base/$tphid" );
is( $status->level, 'OK' );
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


#===========================================
# "priv/nick/:nick/?:ts" resource
#===========================================
$base = "priv/nick";
docu_check($test, "$base/:nick/?:ts");
#
# GET
#
req( $test, 403, 'demo', 'GET', "$base/root" );
$status = req( $test, 200, 'root', 'GET', "$base/root" );
is( $status->level, 'OK' );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV" );
ok( defined $status->payload );
is_deeply( $status->payload, {
    "priv" => "admin",
    "eid" => "1",
    "nick" => "root"
});
#
# - as root, with timestamp (before 1000 A.D. root was a passerby)
$status = req( $test, 200, 'root', 'GET', "$base/root/999-12-31 23:59" );
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
$status = req( $test, 200, 'root', 'GET', "$base/root/1000-01-01 00:01" );
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
foreach my $user ( qw( demo root ) ) {
    foreach my $method ( qw( PUT POST DELETE ) ) {
        foreach my $uri ( "$base/root", "$base/root/999-01-01" ) {
            req( $test, 405, $user, $method, $uri );
        }
    }
}

done_testing;
