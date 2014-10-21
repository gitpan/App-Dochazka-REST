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
# test path dispatch
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use App::Dochazka::REST;
use App::Dochazka::REST::Test qw( req_json_demo req_json_root status_from_json );
use Data::Dumper;
use JSON;
use Plack::Test;
use Scalar::Util qw( blessed );
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
ok( blessed $test );

my $res;

# "" resource as demo
$res = $test->request( req_json_demo PUT => '' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
# admin-only resources
ok( not exists $status->payload->{'resources'}->{'echo'} );

# "" resource as root
$res = $test->request( req_json_root PUT => '' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
# additional admin-only resources
ok( exists $status->payload->{'resources'}->{'echo'} );
ok( exists $status->payload->{'resources'}->{'metaparam/:param'} );

# 'help' resource as demo
$res = $test->request( req_json_demo PUT => 'help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
# admin-only resources
ok( not exists $status->payload->{'resources'}->{'echo'} );

# "help" resource as root
$res = $test->request( req_json_root PUT => 'help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
# additional admin-only resources
ok( exists $status->payload->{'resources'}->{'echo'} );
ok( exists $status->payload->{'resources'}->{'metaparam/:param'} );

# "metaparam/:param" resource as demo
$res = $test->request( req_json_demo PUT => 'metaparam/META_DOCHAZKA_UNIT_TESTING' );
is( $res->code, 403 );
is( $res->message, "Forbidden" );

# "metaparam/:param" resource as root
is( $meta->META_DOCHAZKA_UNIT_TESTING, 1 );
$res = $test->request( req_json_root PUT => 'metaparam/META_DOCHAZKA_UNIT_TESTING', 
    undef, '{ "value": "foobar" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_PARAM_SET' );
is( $meta->META_DOCHAZKA_UNIT_TESTING, 'foobar' );
$res = $test->request( req_json_root PUT => 'metaparam/META_DOCHAZKA_UNIT_TESTING', 
    undef, '{ "value": 1 }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $meta->META_DOCHAZKA_UNIT_TESTING, 1 );

# "echo" resource as demo
$res = $test->request( req_json_demo PUT => 'echo' );
is( $res->code, 403 );
is( $res->message, "Forbidden" );

# "echo" resource as root with legal JSON
$res = $test->request( req_json_root 'PUT', 'echo', undef, '{ "username": "foo", "password": "bar" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_PUT_ECHO' );
ok( exists $status->payload->{'username'} );
is( $status->payload->{'username'}, 'foo' );
ok( exists $status->payload->{'password'} );
is( $status->payload->{'password'}, 'bar' );

# 'echo' resource as root with illegal JSON
$res = $test->request( req_json_root 'PUT', 'echo', undef, '{ "username": "foo", "password": "bar"' );
is( $res->code, 400 );

# 'echo' resource as root with empty request body
$res = $test->request( req_json_root 'PUT', 'echo' );
is( $res->code, 200 );
like( $res->content, qr/"payload"\s*:\s*null/ );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_PUT_ECHO' );
ok( exists $status->{'payload'} );
is( $status->payload, undef );

# 'employee' resource as demo
$res = $test->request( req_json_demo 'PUT', 'employee' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# admin-only resources
ok( not exists $status->payload->{'resources'}->{'employee/eid/:eid'} );
ok( not exists $status->payload->{'resources'}->{'employee/nick/:nick'} );

# 'employee' resource as root
$res = $test->request( req_json_root 'PUT', 'employee' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# admin-only resources
ok( exists $status->payload->{'resources'}->{'employee/eid/:eid'} );
ok( exists $status->payload->{'resources'}->{'employee/nick/:nick'} );

# 'privhistory' resource as demo
$res = $test->request( req_json_demo 'PUT', 'privhistory' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );
# admin-only resources
# ...

# 'privhistory' resource as root
$res = $test->request( req_json_root 'PUT', 'privhistory' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );
# admin-only resources
# ...

done_testing;
