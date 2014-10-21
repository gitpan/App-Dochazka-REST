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
use App::CELL::Config;
use App::Dochazka::REST;
use App::Dochazka::REST::Test qw( req_root req_demo status_from_json );
use Data::Dumper;
use JSON;
use Plack::Test;
use Scalar::Util qw( blessed );
use Test::Fatal;
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
$res = $test->request( req_demo GET => '/' );
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

# "" resource as root
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

# "help" resource as demo
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

# "help" resource as root
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

# "bugreport" as demo
$res = $test->request( req_demo GET => 'bugreport' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_BUGREPORT' );
ok( exists $status->payload->{'report_bugs_to'} );

# "version" as demo
$res = $test->request( req_demo GET => 'version' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DOCHAZKA_REST_VERSION' );
ok( exists $status->payload->{'version'} );

# "version" as root
$res = $test->request( req_root GET => 'version' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DOCHAZKA_REST_VERSION' );
ok( exists $status->payload->{'version'} );

# "session" as demo
$res = $test->request( req_demo GET => 'session' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_SESSION_DATA' );
ok( exists $status->payload->{'session'} );
ok( exists $status->payload->{'session_id'} );
#ok( exists $status->payload->{'session'}->{'ip_addr'} );
#ok( exists $status->payload->{'session'}->{'last_seen'} );
#ok( exists $status->payload->{'session'}->{'eid'} );

# "siteparam/:param" as demo (existing parameter)
$res = $test->request( req_demo GET => 'siteparam/DOCHAZKA_APPNAME/' );
is( $res->code, 403 );
is( $res->message, 'Forbidden' );

# "siteparam/:param" as root (existing parameter)
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

# "siteparam/:param" as root (existing parameter without trailing '/')
$res = $test->request( req_root GET => 'siteparam/DOCHAZKA_APPNAME' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );

# "siteparam/:param" as demo (non-existent parameter)
$res = $test->request( req_demo GET => 'siteparam/DOCHEEEHAWHAZKA_appname' );
is( $res->code, 403 );
is( $res->content, 'Forbidden' );

# "siteparam/:param" as root (non-existent parameter)
$res = $test->request( req_root GET => 'siteparam/DOCHEEEHAWHAZKA_appname' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PARAM_NOT_DEFINED' );

# "siteparam/:param" as root (try to use siteparam to access a meta parameter)
$res = $test->request( req_root GET => 'siteparam/META_DOCHAZKA_UNIT_TESTING' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PARAM_NOT_DEFINED' );

# "siteparam/:param" as demo (existent parameter with trailing '/foobar' => invalid resource)
$res = $test->request( req_demo GET => 'siteparam/DOCHAZKA_APPNAME/foobar' );
is( $res->code, 404 );
is( $res->content, 'Not Found' );

# "siteparam/:param" as root (existent parameter with trailing '/foobar' => invalid resource)
$res = $test->request( req_root GET => 'siteparam/DOCHAZKA_APPNAME/foobar' );
is( $res->code, 404 );
is( $res->content, 'Not Found' );

# "metaparam/:param" as root (existing parameter)
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

# "metaparam/:param" as root (existing parameter without trailing '/')
$res = $test->request( req_root GET => 'metaparam/META_DOCHAZKA_UNIT_TESTING' );
is( $res->code, 200 );
is( $status->payload->{name}, 'META_DOCHAZKA_UNIT_TESTING' );
is( $status->payload->{type}, 'meta' );
is( $status->payload->{value}, 1 );

# "metaparam/:param" as demo (bogus parameter)
$res = $test->request( req_demo GET => 'metaparam/DOCHEEEHAWHAZKA_appname' );
is( $res->code, 403 );
is( $res->content, 'Forbidden' );

# "metaparam/:param" as root (bogus parameter)
$res = $test->request( req_root GET => 'metaparam/DOCHEEEHAWHAZKA_appname' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PARAM_NOT_DEFINED' );

# "metaparam/:param" as root (try to use metaparam to access a site parameter)
$res = $test->request( req_root GET => 'metaparam/DOCHAZKA_APPNAME' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_PARAM_NOT_DEFINED' );

# "metaparam/:param" as demo (existent parameter with trailing '/foobar' => invalid resource)
$res = $test->request( req_demo GET => 'metaparam/META_DOCHAZKA_UNIT_TESTING/foobar' );
is( $res->code, 404 );
is( $res->content, 'Not Found' );

# "metaparam/:param" as root (existent parameter with trailing '/foobar' => invalid resource)
$res = $test->request( req_root GET => 'metaparam/META_DOCHAZKA_UNIT_TESTING/foobar' );
is( $res->code, 404 );
is( $res->content, 'Not Found' );

# "employee" as demo
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

# "employee" as root
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
ok( exists $status->payload->{'resources'}->{'employee/:nick'} );
ok( exists $status->payload->{'resources'}->{'employee/count'} );

# "privhistory" as demo
$res = $test->request( req_demo GET => '/privhistory' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );

# "privhistory" as root
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

done_testing;
