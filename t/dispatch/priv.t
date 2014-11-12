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
# test priv (non-history) resources
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

sub delete_ph_recs {
    my ( $set ) = @_;
    foreach my $rec ( @$set ) {
        $status = req( $test, 200, 'root', 'DELETE', "/priv/history/phid/" . $rec->{phid} );
        is( $status->level, 'OK' );
        is( $status->code, 'DOCHAZKA_CUD_OK' );
    }
}

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
