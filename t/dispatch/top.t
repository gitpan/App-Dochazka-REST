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
# test top-level resources
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

use App::CELL qw( $meta $site );
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


#=============================
# "/" resource
#=============================
docu_check($test, "/");
# GET ""
# - as demo
$status = req( $test, 200, 'demo', 'GET', '/' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'/'} );
ok( exists $status->payload->{'resources'}->{'bugreport'} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'priv'} );
ok( exists $status->payload->{'resources'}->{'session'} );
ok( exists $status->payload->{'resources'}->{'version'} );
ok( exists $status->payload->{'resources'}->{'whoami'} );
#
# - as root
$status = req( $test, 200, 'root', 'GET', '/' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'/'} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'method'} );
# passerby resources
ok( exists $status->payload->{'resources'}->{'/'} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'version'} );
ok( exists $status->payload->{'resources'}->{'session'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'priv'} );
# plus admin-only resources
ok( exists $status->payload->{'resources'}->{'metaparam/:param'} );
ok( exists $status->payload->{'resources'}->{'siteparam/:param'} );
#
# PUT ""
# - as demo
$status = req( $test, 200, 'demo', 'PUT', '/' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'help'} );
#
# PUT "" 
# - as root
$status = req( $test, 200, 'root', 'PUT', '/' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'help'} );
#
# POST "" 
# - as demo
$status = req( $test, 200, 'demo', 'POST', '/' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'/'} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'priv'} );
ok( not exists $status->payload->{'resources'}->{'metaparam'} );
#
# POST "" 
# - as root
$status = req( $test, 200, 'root', 'POST', '/' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'/'} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'priv'} );
ok( exists $status->payload->{'resources'}->{'metaparam'} );
# additional admin-only resources
ok( exists $status->payload->{'resources'}->{'echo'} );
#
# DELETE "" 
# - as demo
$status = req( $test, 200, 'demo', 'DELETE', '/' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
# admin-only resources
ok( not exists $status->payload->{'resources'}->{'echo'} );
#
# DELETE "" - as root
$status = req( $test, 200, 'root', 'DELETE', '/' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
# additional admin-only resources
# ...


#=============================
# "bugreport" resource
#=============================
docu_check($test, "bugreport");
# GET bugreport
# - as demo
$status = req( $test, 200, 'demo', 'GET', 'bugreport' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_BUGREPORT' );
ok( exists $status->payload->{'report_bugs_to'} );
# - as root
$status = req( $test, 200, 'root', 'GET', 'bugreport' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_BUGREPORT' );
ok( exists $status->payload->{'report_bugs_to'} );
#
# PUT bugreport
req( $test, 405, 'demo', 'PUT', 'bugreport' );
req( $test, 405, 'root', 'PUT', 'bugreport' );
#
# POST bugreport
req( $test, 405, 'demo', 'PUT', 'bugreport' );
req( $test, 405, 'root', 'PUT', 'bugreport' );
#
# DELETE bugreport
req( $test, 405, 'demo', 'DELETE', 'bugreport' );
req( $test, 405, 'root', 'DELETE', 'bugreport' );


#=============================
# "docu" resource
#=============================
#=============================
# "docu/html" resource
#=============================
foreach my $base ( 'docu', 'docu/html' ) {
    docu_check($test, $base);
    #
    # GET docu
    #
    req( $test, 405, 'demo', 'GET', $base );
    req( $test, 405, 'root', 'GET', $base );
    #
    # PUT docu
    #
    req( $test, 405, 'demo', 'PUT', $base );
    req( $test, 405, 'root', 'PUT', $base );
    #
    # POST docu
    #
    # - be nice
    $status = req( $test, 200, 'demo', 'POST', $base, '{ "resource" : "echo" }' );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_ONLINE_DOCUMENTATION' );
    ok( exists $status->payload->{'resource'} );
    is( $status->payload->{'resource'}, 'echo' );
    ok( exists $status->payload->{'documentation'} );
    my $docustr = $status->payload->{'documentation'};
    my $docustr_len = length( $docustr );
    ok( $docustr_len > 10 );
    like( $docustr, qr/echoes/ );
    #
    # - ask nicely for documentation of a slightly more complicated resource
    $status = req( $test, 200, 'demo', 'POST', $base, '{ "resource" : "metaparam/:param" }' );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_ONLINE_DOCUMENTATION' );
    ok( exists $status->payload->{'resource'} );
    is( $status->payload->{'resource'}, 'metaparam/:param' );
    ok( exists $status->payload->{'documentation'} );
    ok( length( $status->payload->{'documentation'} ) > 10 );
    isnt( $status->payload->{'documentation'}, $docustr, "We are not getting the same string over and over again" );
    isnt( $docustr_len, length( $status->payload->{'documentation'} ), "We are not getting the same string over and over again" );
    #
    # - ask nicely for documentation of the "/" resource
    $status = req( $test, 200, 'demo', 'POST', $base, '{ "resource" : "/" }' );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_ONLINE_DOCUMENTATION' );
    ok( exists $status->payload->{'resource'} );
    is( $status->payload->{'resource'}, '/' );
    ok( exists $status->payload->{'documentation'} );
    ok( length( $status->payload->{'documentation'} ) > 10 );
    isnt( $status->payload->{'documentation'}, $docustr, "We are not getting the same string over and over again" );
    isnt( $docustr_len, length( $status->payload->{'documentation'} ), "We are not getting the same string over and over again" );
    #
    # - be nice but not careful (non-existent resource)
    $status = req( $test, 200, 'demo', 'POST', $base, '{ "resource" : "echop" }' );
    is( $status->level, 'ERR' ); is( $status->code, 'DISPATCH_BAD_RESOURCE' );
    #
    # - be pathological (invalid JSON)
    req( $test, 400, 'demo', 'POST', $base, 'bare, unquoted string will never pass for JSON' );
    req( $test, 400, 'demo', 'POST', $base, '[ 1, 2' );
    #
    # DELETE docu
    #
    req( $test, 405, 'demo', 'DELETE', $base );
    req( $test, 405, 'root', 'DELETE', $base );
}
    

#=============================
# "echo" resource
#=============================
docu_check($test, "echo");
#
# GET echo
$status = req( $test, 405, 'demo', 'GET', 'echo' );
$status = req( $test, 405, 'root', 'GET', 'echo' );
#
# PUT echo
$status = req( $test, 405, 'demo', 'PUT', 'echo' );
$status = req( $test, 405, 'root', 'PUT', 'echo' );
#
# POST echo
# - as root with legal JSON
$status = req( $test, 200, 'root', 'POST', 'echo', '{ "username": "foo", "password": "bar" }' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_POST_ECHO' );
ok( exists $status->payload->{'username'} );
is( $status->payload->{'username'}, 'foo' );
ok( exists $status->payload->{'password'} );
is( $status->payload->{'password'}, 'bar' );
#
# - with illegal JSON
$status = req( $test, 400, 'root', 'POST', 'echo', '{ "username": "foo", "password": "bar"' );
#
# - with empty request body, as demo
$status = req( $test, 403, 'demo', 'POST', 'echo' );
#
# - with empty request body
$status = req( $test, 200, 'root', 'POST', 'echo' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_POST_ECHO' );
ok( exists $status->{'payload'} );
is( $status->payload, undef );
#
# DELETE echo
$status = req( $test, 405, 'demo', 'DELETE', 'echo' );
$status = req( $test, 405, 'root', 'DELETE', 'echo' );


#=============================
# "employee" resource
#=============================
docu_check($test, "employee");
#
# GET employee
# - as demo
$status = req( $test, 200, 'demo', 'GET', '/employee' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/current'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
#
# GET employee 
# - as root
$status = req( $test, 200, 'root', 'GET', '/employee' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/current'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# additional admin-level resources
ok( exists $status->payload->{'resources'}->{'employee/count/:priv'} );
ok( exists $status->payload->{'resources'}->{'employee/nick/:nick'} );
ok( exists $status->payload->{'resources'}->{'employee/eid/:eid'} );
ok( exists $status->payload->{'resources'}->{'employee/count'} );
#
# PUT employee
# - as demo
$status = req( $test, 200, 'demo', 'PUT', 'employee' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# admin-only resources
ok( not exists $status->payload->{'resources'}->{'employee/eid/:eid'} );
ok( not exists $status->payload->{'resources'}->{'employee/nick/:nick'} );
#
# - as root
$status = req( $test, 200, 'root', 'PUT', 'employee' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# admin-only resources
ok( exists $status->payload->{'resources'}->{'employee/eid/:eid'} );
ok( exists $status->payload->{'resources'}->{'employee/nick/:nick'} );
#
# POST employee
# - as demo
$status = req( $test, 200, 'demo', 'POST', 'employee' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'method'} );
is( $status->payload->{'method'}, 'POST' );
#
# - as root
$status = req( $test, 200, 'root', 'POST', 'employee' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'method'} );
is( $status->payload->{'method'}, 'POST' );
# additional admin-only resources
ok( exists $status->payload->{'resources'}->{'employee/eid'} );
ok( exists $status->payload->{'resources'}->{'employee/nick'} );
#
# DELETE employee
# - as demo
$status = req( $test, 200, 'demo', 'DELETE', 'employee' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# admin-only resources
ok( not exists $status->payload->{'resources'}->{'employee/eid/:eid'} );
ok( not exists $status->payload->{'resources'}->{'employee/nick/:nick'} );
#
# - as root
$status = req( $test, 200, 'root', 'DELETE', 'employee' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# admin-only resources
# ...


#=============================
# "forbidden" resource
#=============================
docu_check($test, "forbidden");
foreach my $user ( qw( demo root ) ) {
    foreach my $method ( qw( GET PUT POST DELETE ) ) {
        $status = req( $test, 403, 'demo', 'GET', 'forbidden' );
    }
}


#=============================
# "help" resource
#=============================
docu_check($test, "help");
#
# GET help
# - as demo
$status = req( $test, 200, 'demo', 'GET', 'help' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'/'} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'version'} );
ok( exists $status->payload->{'resources'}->{'whoami'} );
ok( exists $status->payload->{'resources'}->{'session'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'priv'} );
#
# GET help 
# - as root
$status = req( $test, 200, 'root', 'GET', 'help' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'/'} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'method'} );
# passerby resources
ok( exists $status->payload->{'resources'}->{'/'} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'version'} );
ok( exists $status->payload->{'resources'}->{'session'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'priv'} );
# plus admin-only resources
ok( exists $status->payload->{'resources'}->{'metaparam/:param'} );
ok( exists $status->payload->{'resources'}->{'siteparam/:param'} );
#
# PUT help 
# - as demo
$status = req( $test, 200, 'demo', 'PUT', 'help' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
# admin-only resources
ok( not exists $status->payload->{'resources'}->{'echo'} );
#
# - as root
$status = req( $test, 200, 'root', 'PUT', 'help' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
# additional admin-only resources
ok( not exists $status->payload->{'resources'}->{'metaparam/:param'} );
#
# POST help
# - as demo
$status = req( $test, 200, 'demo', 'POST', 'help' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'/'} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'priv'} );
ok( not exists $status->payload->{'resources'}->{'metaparam'} );
#
# - as root
$status = req( $test, 200, 'root', 'POST', 'help' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'/'} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'priv'} );
ok( exists $status->payload->{'resources'}->{'metaparam'} );
# additional admin-only resources
ok( exists $status->payload->{'resources'}->{'echo'} );
#
# DELETE help
# - as demo
$status = req( $test, 200, 'demo', 'DELETE', 'help' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
# admin-only resources
# ...
#
# - as root
$status = req( $test, 200, 'root', 'DELETE', 'help' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
# additional admin-only resources
# ...


#=============================
# "metaparam" resource
#=============================
docu_check($test, "metaparam");
#

#
# POST
# 
is( $meta->META_DOCHAZKA_UNIT_TESTING, 1 );

$status = req( $test, 200, 'root', 'POST', 'metaparam', <<"EOH");
{ "name" : "META_DOCHAZKA_UNIT_TESTING", "value" : "foobar" }
EOH

is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_PARAM_SET' );
is( $meta->META_DOCHAZKA_UNIT_TESTING, 'foobar' );

$status = req( $test, 200, 'root', 'POST', 'metaparam', <<"EOH");
{ "name" : "META_DOCHAZKA_UNIT_TESTING", "value" : 1 }
EOH

is( $status->level, 'OK' );
is( $meta->META_DOCHAZKA_UNIT_TESTING, 1 );


#=============================
# "metaparam/:param" resource
# "siteparam/:param" resource
#=============================

#
# GET
#

# non-existent and otherwise bogus parameters
foreach my $base ( qw( metaparam siteparam ) ) {
    docu_check($test, "$base/:param");
    foreach my $user ( qw( demo root ) ) {
        # these are bogus in that the resource does not exist
        req( $test, 404, $user, 'GET', "$base/META_DOCHAZKA_UNIT_TESTING/foobar" );
        req( $test, 404, $user, 'GET', "$base//////1/1/234/20" );
    }
    my $mapping = { "demo" => 403, "root" => 404 };
    foreach my $user ( qw( demo root ) ) {
        # these are bogus in that the parameter does not exist
        req( $test, $mapping->{$user}, $user, 'GET', "$base/DOCHEEEHAWHAZKA_appname" );
        req( $test, $mapping->{$user}, $user, 'GET', "$base/{}" );
        req( $test, $mapping->{$user}, $user, 'GET', "$base/-1" );
        req( $test, $mapping->{$user}, $user, 'GET', "$base/0" );
        req( $test, $mapping->{$user}, $user, 'GET', "$base/" . '\b\b\o\o\g\\' );
        req( $test, $mapping->{$user}, $user, 'GET', "$base/" . '\b\b\o\o\\' );
        req( $test, $mapping->{$user}, $user, 'GET', "$base/**0" );
        req( $test, $mapping->{$user}, $user, 'GET', "$base/}lieutenant" );
        req( $test, $mapping->{$user}, $user, 'GET', "$base/<HEAD><tail><body>&nbsp;" );
    }
}

# metaparam-specific tests
#
# - try to use metaparam to access a site parameter
req( $test, 404, 'root', 'GET', "metaparam/DOCHAZKA_APPNAME" );
# - as root, existent parameter
$status = req( $test, 200, 'root', 'GET', 'metaparam/META_DOCHAZKA_UNIT_TESTING/' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_PARAM_FOUND' );
ok( exists $status->payload->{name} );
is( $status->payload->{name}, 'META_DOCHAZKA_UNIT_TESTING' );
ok( exists $status->payload->{type} );
is( $status->payload->{type}, 'meta' );
ok( exists $status->payload->{value} );
is( $status->payload->{value}, 1 );
#
# - as root, existent parameter without trailing '/'
$status = req( $test, 200, 'root', 'GET', 'metaparam/META_DOCHAZKA_UNIT_TESTING' );
is( $status->level, 'OK' );
is( $status->payload->{name}, 'META_DOCHAZKA_UNIT_TESTING' );
is( $status->payload->{type}, 'meta' );
is( $status->payload->{value}, 1 );
#
#
# PUT, POST, DELETE
#
foreach my $base ( qw( metaparam siteparam ) ) {
    foreach my $user ( qw( demo root ) ) {
        foreach my $method ( qw( PUT POST DELETE ) ) {
            req( $test, 405, $user, $method, 'metaparam/META_DOCHAZKA_UNIT_TESTING' );
        }
    }
}


#=============================
# "not_implemented" resource
#=============================
docu_check($test, "not_implemented");
#
foreach my $user ( qw( root demo ) ) {
    foreach my $method ( qw( GET PUT POST DELETE ) ) {
        $status = req( $test, 200, $user, $method, 'not_implemented' );
        is( $status->level, 'NOTICE' );
        is( $status->code, 'DISPATCH_RESOURCE_NOT_IMPLEMENTED' );
    }
}


#=============================
# "priv" resource
#=============================
docu_check($test, "priv");
#
# GET priv
#
$status = req( $test, 200, 'demo', 'GET', '/priv' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
# 
$status = req( $test, 200, 'root', 'GET', '/priv' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
# additional admin-level resources
ok( exists $status->payload->{'resources'}->{'priv/self/?:ts'} );
ok( exists $status->payload->{'resources'}->{'priv/eid/:eid/?:ts'} );
ok( exists $status->payload->{'resources'}->{'priv/nick/:nick/?:ts'} );
ok( exists $status->payload->{'resources'}->{'priv/history/self/?:tsrange'} );
ok( exists $status->payload->{'resources'}->{'priv/history/eid/:eid'} );
ok( exists $status->payload->{'resources'}->{'priv/history/eid/:eid/:tsrange'} );
ok( exists $status->payload->{'resources'}->{'priv/history/nick/:nick'} );
ok( exists $status->payload->{'resources'}->{'priv/history/nick/:nick/:tsrange'} );
#
# PUT priv
#
$status = req( $test, 200, 'demo', 'PUT', 'priv' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
# admin-only resources
# ...
#
$status = req( $test, 200, 'root', 'PUT', 'priv' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
# admin-only resources
# ...
#
# POST priv
#
$status = req( $test, 200, 'demo', 'POST', 'priv' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'method'} );
is( $status->payload->{'method'}, 'POST' );
#
$status = req( $test, 200, 'root', 'POST', 'priv' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'method'} );
is( $status->payload->{'method'}, 'POST' );
# additional admin-only resources
# none yet
#
# DELETE priv
#
$status = req( $test, 200, 'demo', 'DELETE', 'priv' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
# admin-only resources
# ...
#
$status = req( $test, 200, 'root', 'DELETE', 'priv' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'priv/help'} );
# admin-only resources
# ...


#=============================
# "session" resource
#=============================
docu_check($test, "session");
#
# GET session
#
$status = req( $test, 200, 'demo', 'GET', 'session' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_SESSION_DATA' );
ok( exists $status->payload->{'session'} );
ok( exists $status->payload->{'session_id'} );
# N.B.: no session data when running via Plack::Test
#ok( exists $status->payload->{'session'}->{'ip_addr'} );
#ok( exists $status->payload->{'session'}->{'last_seen'} );
#ok( exists $status->payload->{'session'}->{'eid'} );
#
# PUT, POST, DELETE
#
foreach my $user ( qw( demo root ) ) {
    foreach my $method ( qw( PUT POST DELETE ) ) {
        $status = req( $test, 405, $user, $method, 'session' );
    }
}


#=============================
# "siteparam/:param" resource
#=============================
# - (only tests not covered under metaparam, above)

#
# GET
# - as demo (existing parameter)
req( $test, 403, 'demo', 'GET', 'siteparam/DOCHAZKA_APPNAME/' );
#
# - as root (existing parameter)
$status = req( $test, 200, 'root', 'GET', 'siteparam/DOCHAZKA_APPNAME/' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_PARAM_FOUND' );
ok( exists $status->payload->{name} );
is( $status->payload->{name}, 'DOCHAZKA_APPNAME' );
ok( exists $status->payload->{type} );
is( $status->payload->{type}, 'site' );
ok( exists $status->payload->{value} );
is( $status->payload->{value}, $site->DOCHAZKA_APPNAME );
#
# - as root (existing parameter without trailing '/')
$status = req( $test, 200, 'root', 'GET', 'siteparam/DOCHAZKA_APPNAME' );
is( $status->level, 'OK' );
#
# - as root (try to use siteparam to access a meta parameter)
req( $test, 404, 'root', 'GET', 'siteparam/META_DOCHAZKA_UNIT_TESTING' );


#=============================
# "version" resource
#=============================
docu_check($test, "version");
#
# GET version
#
$status = req( $test, 200, 'demo', 'GET', 'version' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DOCHAZKA_REST_VERSION' );
ok( exists $status->payload->{'version'} );
#
$status = req( $test, 200, 'root', 'GET', 'version' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_DOCHAZKA_REST_VERSION' );
ok( exists $status->payload->{'version'} );
#
# PUT, POST, DELETE version
#
foreach my $user ( qw( demo root ) ) {
    foreach my $method ( qw( PUT POST DELETE ) ) {
        $status = req( $test, 405, $user, $method, 'version' );
    }
}


#=============================
# "whoami" resource
#=============================
docu_check($test, "whoami");
#
# GET whoami
$status = req( $test, 200, 'demo', 'GET', 'whoami' );
is( $status->level, 'OK' );
ok( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
ok( exists $status->payload->{'nick'} );
ok( not exists $status->payload->{'priv'} );
is( $status->payload->{'nick'}, 'demo' );
#
$status = req( $test, 200, 'root', 'GET', 'whoami' );
is( $status->level, 'OK' );
ok( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
ok( exists $status->payload->{'nick'} );
ok( not exists $status->payload->{'priv'} );
is( $status->payload->{'nick'}, 'root' );
#
# PUT, POST, DELETE whoami
#
foreach my $user ( qw( demo root ) ) {
    foreach my $method ( qw( PUT POST DELETE ) ) {
        $status = req( $test, 405, $user, $method, 'whoami' );
    }
}

done_testing;
