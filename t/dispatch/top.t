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
use App::Dochazka::REST::Test qw( req_root req_json_root req_demo req_json_demo status_from_json docu_check );
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
# "" resource
#=============================
docu_check($test, "");
# GET ""
# - as demo
$res = $test->request( req_demo GET => '/' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{''} );
ok( exists $status->payload->{'resources'}->{'bugreport'} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'privhistory'} );
ok( exists $status->payload->{'resources'}->{'session'} );
ok( exists $status->payload->{'resources'}->{'version'} );
ok( exists $status->payload->{'resources'}->{'whoami'} );
#
# - as root
$res = $test->request( req_root GET => '/' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{''} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'method'} );
# passerby resources
ok( exists $status->payload->{'resources'}->{''} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'version'} );
ok( exists $status->payload->{'resources'}->{'session'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'privhistory'} );
# plus admin-only resources
ok( exists $status->payload->{'resources'}->{'metaparam/:param'} );
ok( exists $status->payload->{'resources'}->{'siteparam/:param'} );
#
# PUT ""
# - as demo
$res = $test->request( req_json_root PUT => '' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'help'} );
#
# PUT "" 
# - as root
$res = $test->request( req_json_root PUT => '' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'help'} );
# additional admin-only resources
ok( exists $status->payload->{'resources'}->{'metaparam/:param'} );
#
# POST "" 
# - as demo
$res = $test->request( req_json_demo POST => '' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{''} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'privhistory'} );
ok( not exists $status->payload->{'resources'}->{'metaparam/:param'} );
#
# POST "" 
# - as root
$res = $test->request( req_json_root POST => '' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{''} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'privhistory'} );
ok( not exists $status->payload->{'resources'}->{'metaparam/:param'} );
# additional admin-only resources
ok( exists $status->payload->{'resources'}->{'echo'} );
#
# DELETE "" 
# - as demo
$res = $test->request( req_json_demo DELETE => '' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
# admin-only resources
ok( not exists $status->payload->{'resources'}->{'echo'} );
#
# DELETE "" - as root
$res = $test->request( req_json_root DELETE => '' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
# additional admin-only resources
# ...


#=============================
# "bugreport" resource
#=============================
docu_check($test, "bugreport");
# GET bugreport
# - as demo
$res = $test->request( req_demo GET => 'bugreport' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_BUGREPORT' );
ok( exists $status->payload->{'report_bugs_to'} );
# - as root
$res = $test->request( req_root GET => 'bugreport' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_BUGREPORT' );
ok( exists $status->payload->{'report_bugs_to'} );
#
# PUT bugreport
$res = $test->request( req_json_demo PUT => 'bugreport' );
is( $res->code, 405 );
$res = $test->request( req_json_root PUT => 'bugreport' );
is( $res->code, 405 );
#
# POST bugreport
$res = $test->request( req_json_demo POST => 'bugreport' );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => 'bugreport' );
is( $res->code, 405 );
#
# DELETE bugreport
$res = $test->request( req_json_demo DELETE => 'bugreport' );
is( $res->code, 405 );
$res = $test->request( req_json_root DELETE => 'bugreport' );
is( $res->code, 405 );


#=============================
# "docu" resource
#=============================
docu_check($test, "docu");
#
# GET docu
#
$res = $test->request( req_demo GET => 'docu' );
is( $res->code, 405 );
$res = $test->request( req_root GET => 'docu' );
is( $res->code, 405 );
#
# PUT docu
#
$res = $test->request( req_json_demo PUT => 'docu' );
is( $res->code, 405 );
$res = $test->request( req_json_root PUT => 'docu' );
is( $res->code, 405 );
#
# POST docu
#
# - be nice
$res = $test->request( req_json_demo POST => 'docu', undef, '"echo"' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
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
$res = $test->request( req_json_demo POST => 'docu', undef, '"metaparam/:param"' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_ONLINE_DOCUMENTATION' );
ok( exists $status->payload->{'resource'} );
is( $status->payload->{'resource'}, 'metaparam/:param' );
ok( exists $status->payload->{'documentation'} );
ok( length( $status->payload->{'documentation'} ) > 10 );
isnt( $status->payload->{'documentation'}, $docustr, "We are not getting the same string over and over again" );
isnt( $docustr_len, length( $status->payload->{'documentation'} ), "We are not getting the same string over and over again" );
#
# - ask nicely for documentation of the "" resource
$res = $test->request( req_json_demo POST => 'docu', undef, '""' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_ONLINE_DOCUMENTATION' );
ok( exists $status->payload->{'resource'} );
is( $status->payload->{'resource'}, '' );
ok( exists $status->payload->{'documentation'} );
ok( length( $status->payload->{'documentation'} ) > 10 );
isnt( $status->payload->{'documentation'}, $docustr, "We are not getting the same string over and over again" );
isnt( $docustr_len, length( $status->payload->{'documentation'} ), "We are not getting the same string over and over again" );
#
# - be nice but not careful (non-existent resource)
$res = $test->request( req_json_demo POST => 'docu', undef, '"echop"' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_BAD_RESOURCE' );
#
# - be pathological (invalid JSON)
$res = $test->request( req_json_demo POST => 'docu', undef, 'bare, unquoted string will never pass for JSON' );
is( $res->code, 400 );
$res = $test->request( req_json_demo POST => 'docu', undef, '[ 1, 2' );
is( $res->code, 400 );
#
# DELETE docu
#
$res = $test->request( req_json_demo DELETE => 'docu' );
is( $res->code, 405 );
$res = $test->request( req_json_root DELETE => 'docu' );
is( $res->code, 405 );

#=============================
# "echo" resource
#=============================
docu_check($test, "echo");
#
# GET echo
$res = $test->request( req_demo GET => 'echo' );
is( $res->code, 405 );
$res = $test->request( req_root GET => 'echo' );
is( $res->code, 405 );
#
# PUT echo
$res = $test->request( req_json_demo PUT => 'echo' );
is( $res->code, 405 );
$res = $test->request( req_json_root PUT => 'echo' );
is( $res->code, 405 );
#
# POST echo
# - as root with legal JSON
$res = $test->request( req_json_root 'POST', 'echo', undef, '{ "username": "foo", "password": "bar" }' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_POST_ECHO' );
ok( exists $status->payload->{'username'} );
is( $status->payload->{'username'}, 'foo' );
ok( exists $status->payload->{'password'} );
is( $status->payload->{'password'}, 'bar' );
#
# - with illegal JSON
$res = $test->request( req_json_root 'POST', 'echo', undef, '{ "username": "foo", "password": "bar"' );
is( $res->code, 400 );
#
# - with empty request body, as demo
$res = $test->request( req_json_demo POST => 'echo' );
is( $res->code, 403 ); # Forbidden
#
# - with empty request body
$res = $test->request( req_json_root 'POST', 'echo' );
is( $res->code, 200 );
like( $res->content, qr/"payload"\s*:\s*null/ );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_POST_ECHO' );
ok( exists $status->{'payload'} );
is( $status->payload, undef );
#
# DELETE echo
$res = $test->request( req_json_demo DELETE => 'echo' );
is( $res->code, 405 );
$res = $test->request( req_json_root DELETE => 'echo' );
is( $res->code, 405 );


#=============================
# "employee" resource
#=============================
docu_check($test, "employee");
#
# GET employee
# - as demo
$res = $test->request( req_demo GET => '/employee' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/current'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
#
# GET employee 
# - as root
$res = $test->request( req_root GET => '/employee' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
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
$res = $test->request( req_json_demo 'PUT', 'employee' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# admin-only resources
ok( not exists $status->payload->{'resources'}->{'employee/eid/:eid'} );
ok( not exists $status->payload->{'resources'}->{'employee/nick/:nick'} );
#
# - as root
$res = $test->request( req_json_root 'PUT', 'employee' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# admin-only resources
ok( exists $status->payload->{'resources'}->{'employee/eid/:eid'} );
ok( exists $status->payload->{'resources'}->{'employee/nick/:nick'} );
#
# POST employee
# - as demo
$res = $test->request( req_json_demo 'POST', 'employee' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'method'} );
is( $status->payload->{'method'}, 'POST' );
#
# - as root
$res = $test->request( req_json_root 'POST', 'employee' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
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
$res = $test->request( req_json_demo 'DELETE', 'employee' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# admin-only resources
ok( not exists $status->payload->{'resources'}->{'employee/eid/:eid'} );
ok( not exists $status->payload->{'resources'}->{'employee/nick/:nick'} );
#
# - as root
$res = $test->request( req_json_root 'DELETE', 'employee' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'employee/help'} );
# admin-only resources
# ...


#=============================
# "forbidden" resource
#=============================
docu_check($test, "forbidden");
#
# GET forbidden
$res = $test->request( req_demo GET => 'forbidden' );
is( $res->code, 403 );
$res = $test->request( req_root GET => 'forbidden' );
is( $res->code, 403 );
#
# PUT forbidden
$res = $test->request( req_json_demo PUT => 'forbidden' );
is( $res->code, 403 );
$res = $test->request( req_json_root PUT => 'forbidden' );
is( $res->code, 403 );
#
# POST forbidden
$res = $test->request( req_json_demo POST => 'forbidden' );
is( $res->code, 403 );
$res = $test->request( req_json_root POST => 'forbidden' );
is( $res->code, 403 );
#
# DELETE forbidden
$res = $test->request( req_json_demo DELETE => 'forbidden' );
is( $res->code, 403 );
$res = $test->request( req_json_root DELETE => 'forbidden' );
is( $res->code, 403 );


#=============================
# "help" resource
#=============================
docu_check($test, "help");
#
# GET help
# - as demo
$res = $test->request( req_demo GET => 'help' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{''} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'version'} );
ok( exists $status->payload->{'resources'}->{'whoami'} );
ok( exists $status->payload->{'resources'}->{'session'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'privhistory'} );
#
# GET help 
# - as root
$res = $test->request( req_root GET => 'help' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{''} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'method'} );
# passerby resources
ok( exists $status->payload->{'resources'}->{''} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'version'} );
ok( exists $status->payload->{'resources'}->{'session'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'privhistory'} );
# plus admin-only resources
ok( exists $status->payload->{'resources'}->{'metaparam/:param'} );
ok( exists $status->payload->{'resources'}->{'siteparam/:param'} );
#
# PUT help 
# - as demo
$res = $test->request( req_json_demo PUT => 'help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
# admin-only resources
ok( not exists $status->payload->{'resources'}->{'echo'} );
#
# - as root
$res = $test->request( req_json_root PUT => 'help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
# additional admin-only resources
ok( exists $status->payload->{'resources'}->{'metaparam/:param'} );
#
# POST help
# - as demo
$res = $test->request( req_json_demo POST => 'help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{''} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'privhistory'} );
ok( not exists $status->payload->{'resources'}->{'metaparam/:param'} );
#
# - as root
$res = $test->request( req_json_root POST => 'help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{''} );
ok( exists $status->payload->{'resources'}->{'help'} );
ok( exists $status->payload->{'resources'}->{'employee'} );
ok( exists $status->payload->{'resources'}->{'privhistory'} );
ok( not exists $status->payload->{'resources'}->{'metaparam/:param'} );
# additional admin-only resources
ok( exists $status->payload->{'resources'}->{'echo'} );
#
# DELETE help
# - as demo
$res = $test->request( req_json_demo DELETE => 'help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
# admin-only resources
# ...
#
# - as root
$res = $test->request( req_json_root DELETE => 'help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
# additional admin-only resources
# ...


#=============================
# "metaparam/:param" resource
#=============================
docu_check($test, "metaparam/:param");
#
# GET metaparam/:param
# - as root, existent parameter
$res = $test->request( req_root GET => 'metaparam/META_DOCHAZKA_UNIT_TESTING/' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_PARAM_FOUND' );
ok( exists $status->payload->{name} );
is( $status->payload->{name}, 'META_DOCHAZKA_UNIT_TESTING' );
ok( exists $status->payload->{type} );
is( $status->payload->{type}, 'meta' );
ok( exists $status->payload->{value} );
is( $status->payload->{value}, 1 );
#
# - as root, existent parameter without trailing '/'
$res = $test->request( req_root GET => 'metaparam/META_DOCHAZKA_UNIT_TESTING' );
is( $res->code, 200 );
is( $status->payload->{name}, 'META_DOCHAZKA_UNIT_TESTING' );
is( $status->payload->{type}, 'meta' );
is( $status->payload->{value}, 1 );
#
# - as demo, bogus parameter
$res = $test->request( req_demo GET => 'metaparam/DOCHEEEHAWHAZKA_appname' );
is( $res->code, 403 );
is( $res->content, 'Forbidden' );
#
# - as root, bogus parameter
$res = $test->request( req_root GET => 'metaparam/DOCHEEEHAWHAZKA_appname' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PARAM_NOT_DEFINED' );
#
# - as root, try to use metaparam to access a site parameter
$res = $test->request( req_root GET => 'metaparam/DOCHAZKA_APPNAME' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PARAM_NOT_DEFINED' );
#
# - as demo, existent parameter with trailing '/foobar' => invalid resource
$res = $test->request( req_demo GET => 'metaparam/META_DOCHAZKA_UNIT_TESTING/foobar' );
is( $res->code, 404 );
is( $res->content, 'Not Found' );
#
# - as root, existent parameter with trailing '/foobar' => invalid resource
$res = $test->request( req_root GET => 'metaparam/META_DOCHAZKA_UNIT_TESTING/foobar' );
is( $res->code, 404 );
is( $res->content, 'Not Found' );

#
# PUT metaparam/:param
#
$res = $test->request( req_json_demo PUT => 'metaparam/META_DOCHAZKA_UNIT_TESTING' );
is( $res->code, 403 );
is( $res->message, "Forbidden" );
# 
is( $meta->META_DOCHAZKA_UNIT_TESTING, 1 );
$res = $test->request( req_json_root PUT => 'metaparam/META_DOCHAZKA_UNIT_TESTING', 
    undef, '"foobar"' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_PARAM_SET' );
is( $meta->META_DOCHAZKA_UNIT_TESTING, 'foobar' );
$res = $test->request( req_json_root PUT => 'metaparam/META_DOCHAZKA_UNIT_TESTING', 
    undef, '1' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $meta->META_DOCHAZKA_UNIT_TESTING, 1 );

#
# POST metaparam/:param
#
$res = $test->request( req_json_demo POST => 'metaparam/foobar' );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => 'metaparam/foobar' );
is( $res->code, 405 );

#
# DELETE metaparam/:param
#
# (not implemented yet)
$res = $test->request( req_json_root DELETE => 'metaparam/foobar' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_RESOURCE_NOT_IMPLEMENTED' );
my $hr = $status->payload;
ok( exists $hr->{'resource'} );
is( $hr->{'resource'}, '/metaparam/foobar' );


#=============================
# "not_implemented" resource
#=============================
docu_check($test, "not_implemented");
#
# GET not_implemented
#
$res = $test->request( req_demo GET => 'not_implemented' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_RESOURCE_NOT_IMPLEMENTED' );
#
$res = $test->request( req_root GET => 'not_implemented' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_RESOURCE_NOT_IMPLEMENTED' );
#
# PUT not_implemented
#
$res = $test->request( req_json_demo PUT => 'not_implemented' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_RESOURCE_NOT_IMPLEMENTED' );
#
$res = $test->request( req_json_root PUT => 'not_implemented' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_RESOURCE_NOT_IMPLEMENTED' );
#
# POST not_implemented
#
$res = $test->request( req_json_demo POST => 'not_implemented' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_RESOURCE_NOT_IMPLEMENTED' );
#
$res = $test->request( req_json_root POST => 'not_implemented' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_RESOURCE_NOT_IMPLEMENTED' );
#
# DELETE not_implemented
#
$res = $test->request( req_json_demo DELETE => 'not_implemented' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_RESOURCE_NOT_IMPLEMENTED' );
#
$res = $test->request( req_json_root DELETE => 'not_implemented' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_RESOURCE_NOT_IMPLEMENTED' );


#=============================
# "privhistory" resource
#=============================
docu_check($test, "privhistory");
#
# GET privhistory
#
$res = $test->request( req_demo GET => '/privhistory' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );
# 
$res = $test->request( req_root GET => '/privhistory' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );
# additional admin-level resources
ok( exists $status->payload->{'resources'}->{'privhistory/eid/:eid/:tsrange'} );
ok( exists $status->payload->{'resources'}->{'privhistory/current/:tsrange'} );
ok( exists $status->payload->{'resources'}->{'privhistory/eid/:eid'} );
ok( exists $status->payload->{'resources'}->{'privhistory/nick/:nick'} );
ok( exists $status->payload->{'resources'}->{'privhistory/nick/:nick/:tsrange'} );
ok( exists $status->payload->{'resources'}->{'privhistory/current'} );
#
# PUT privhistory
#
$res = $test->request( req_json_demo 'PUT', 'privhistory' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );
# admin-only resources
# ...
#
$res = $test->request( req_json_root 'PUT', 'privhistory' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );
# admin-only resources
# ...
#
# POST privhistory
#
$res = $test->request( req_json_demo 'POST', 'privhistory' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'method'} );
is( $status->payload->{'method'}, 'POST' );
#
$res = $test->request( req_json_root 'POST', 'privhistory' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'method'} );
is( $status->payload->{'method'}, 'POST' );
# additional admin-only resources
# none yet
#
# DELETE privhistory
#
$res = $test->request( req_json_demo 'DELETE', 'privhistory' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );
# admin-only resources
# ...
#
$res = $test->request( req_json_root 'DELETE', 'privhistory' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );
# admin-only resources
# ...


#=============================
# "session" resource
#=============================
docu_check($test, "session");
#
# GET session
#
$res = $test->request( req_demo GET => 'session' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_SESSION_DATA' );
ok( exists $status->payload->{'session'} );
ok( exists $status->payload->{'session_id'} );
# N.B.: no session data when running via Plack::Test
#ok( exists $status->payload->{'session'}->{'ip_addr'} );
#ok( exists $status->payload->{'session'}->{'last_seen'} );
#ok( exists $status->payload->{'session'}->{'eid'} );
#
# PUT, POST, DELETE session
#
$res = $test->request( req_demo PUT => 'session' );
is( $res->code, 405 );
$res = $test->request( req_demo POST => 'session' );
is( $res->code, 405 );
$res = $test->request( req_demo DELETE => 'session' );
is( $res->code, 405 );
$res = $test->request( req_root PUT => 'session' );
is( $res->code, 405 );
$res = $test->request( req_root POST => 'session' );
is( $res->code, 405 );
$res = $test->request( req_root DELETE => 'session' );
is( $res->code, 405 );


#=============================
# "siteparam/:param" resource
#=============================
docu_check($test, "siteparam/:param");
#
# GET siteparam/:param
# - as demo (existing parameter)
$res = $test->request( req_demo GET => 'siteparam/DOCHAZKA_APPNAME/' );
is( $res->code, 403 );
is( $res->message, 'Forbidden' );
#
# - as root (existing parameter)
$res = $test->request( req_root GET => 'siteparam/DOCHAZKA_APPNAME/' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_PARAM_FOUND' );
ok( exists $status->payload->{name} );
is( $status->payload->{name}, 'DOCHAZKA_APPNAME' );
ok( exists $status->payload->{type} );
is( $status->payload->{type}, 'site' );
ok( exists $status->payload->{value} );
is( $status->payload->{value}, $site->DOCHAZKA_APPNAME );
#
# - as root (existing parameter without trailing '/')
$res = $test->request( req_root GET => 'siteparam/DOCHAZKA_APPNAME' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
#
# - as demo (non-existent parameter)
$res = $test->request( req_demo GET => 'siteparam/DOCHEEEHAWHAZKA_appname' );
is( $res->code, 403 );
is( $res->content, 'Forbidden' );
#
# - as root (non-existent parameter)
$res = $test->request( req_root GET => 'siteparam/DOCHEEEHAWHAZKA_appname' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PARAM_NOT_DEFINED' );
#
# - as root (try to use siteparam to access a meta parameter)
$res = $test->request( req_root GET => 'siteparam/META_DOCHAZKA_UNIT_TESTING' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PARAM_NOT_DEFINED' );
#
# - as demo (existent parameter with trailing '/foobar' => invalid resource)
$res = $test->request( req_demo GET => 'siteparam/DOCHAZKA_APPNAME/foobar' );
is( $res->code, 404 );
is( $res->content, 'Not Found' );
#
# - as root (existent parameter with trailing '/foobar' => invalid resource)
$res = $test->request( req_root GET => 'siteparam/DOCHAZKA_APPNAME/foobar' );
is( $res->code, 404 );
is( $res->content, 'Not Found' );

# PUT siteparam/:param
$res = $test->request( req_json_demo PUT => 'siteparam/bubba' );
is( $res->code, 405 );
$res = $test->request( req_json_root PUT => 'siteparam/bubba' );
is( $res->code, 405 );

#
# POST siteparam/:param
#
$res = $test->request( req_json_demo POST => 'siteparam/foobar' );
is( $res->code, 405 );
$res = $test->request( req_json_root POST => 'siteparam/foobar' );
is( $res->code, 405 );

#
# DELETE siteparam/:param
#
$res = $test->request( req_json_demo DELETE => 'siteparam/foobar' );
is( $res->code, 405 );
$res = $test->request( req_json_root DELETE => 'siteparam/foobar' );
is( $res->code, 405 );


#=============================
# "version" resource
#=============================
docu_check($test, "version");
#
# GET version
#
$res = $test->request( req_demo GET => 'version' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DOCHAZKA_REST_VERSION' );
ok( exists $status->payload->{'version'} );
#
$res = $test->request( req_root GET => 'version' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DOCHAZKA_REST_VERSION' );
ok( exists $status->payload->{'version'} );
#
# PUT, POST, DELETE version
#
$res = $test->request( req_demo PUT => 'version' );
is( $res->code, 405 );
$res = $test->request( req_demo POST => 'version' );
is( $res->code, 405 );
$res = $test->request( req_demo DELETE => 'version' );
is( $res->code, 405 );
$res = $test->request( req_root PUT => 'version' );
is( $res->code, 405 );
$res = $test->request( req_root POST => 'version' );
is( $res->code, 405 );
$res = $test->request( req_root DELETE => 'version' );
is( $res->code, 405 );


#=============================
# "whoami" resource
#=============================
docu_check($test, "whoami");
#
# GET whoami
$res = $test->request( req_demo GET => 'whoami' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
ok( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
ok( exists $status->payload->{'nick'} );
ok( not exists $status->payload->{'priv'} );
is( $status->payload->{'nick'}, 'demo' );
#
$res = $test->request( req_root GET => 'whoami' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
ok( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
ok( exists $status->payload->{'nick'} );
ok( not exists $status->payload->{'priv'} );
is( $status->payload->{'nick'}, 'root' );
#
# PUT, POST, DELETE whoami
#
$res = $test->request( req_demo PUT => 'whoami' );
is( $res->code, 405 );
$res = $test->request( req_demo POST => 'whoami' );
is( $res->code, 405 );
$res = $test->request( req_demo DELETE => 'whoami' );
is( $res->code, 405 );
$res = $test->request( req_root PUT => 'whoami' );
is( $res->code, 405 );
$res = $test->request( req_root POST => 'whoami' );
is( $res->code, 405 );
$res = $test->request( req_root DELETE => 'whoami' );
is( $res->code, 405 );

done_testing;
