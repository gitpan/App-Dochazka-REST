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
# tests for Resource.pm
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $log $meta $site );
use App::CELL::Status;
use App::Dochazka::REST;
use App::Dochazka::REST::Resource;
use App::Dochazka::REST::Test qw( req_json_demo req_html req_bad_creds );
use Data::Dumper;
use JSON;
use Plack::Test;
use Scalar::Util qw( blessed );
use Test::Fatal;
use Test::JSON;
use Test::More;

$log->info( "Entering t/301-resource.t" );

# initialize 
my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka-rest', verbose => 1, debug_mode => 1 );
my $status = $REST->{init_status};
if ( $status->not_ok ) { 
    plan skip_all => "not configured or server not running";
}
my $app = $REST->{'app'};
$meta->set( 'META_DOCHAZKA_UNIT_TESTING' => 1 );

# instantiate Plack::Test object
my $test = Plack::Test->create( $app );
isa_ok( $test, 'Plack::Test::MockHTTP' );

my ( $res, $json );

# the very basic-est request (200)
$res = $test->request( req_json_demo GET => '/' );
is( $res->code, 200 );

# a too-long request (414)
$res = $test->request( req_json_demo GET => '/' x 1001 );
#diag( "code is " . $res->code );
is( $res->code, 414 );
is( $res->content, 'Request-URI Too Large' );

# request for HTML
$res = $test->request( req_html GET => '/' );
is( $res->code, 200 );
like( $res->content, qr/<html>/ );

# request with bad credentials (401)
$res = $test->request( req_bad_creds GET => '/' );
is( $res->code, 401 );
is( $res->content, 'Unauthorized' );

# request that doesn't pass ACL check (403)
$res = $test->request( req_json_demo GET => '/forbidden' );
is( $res->code, 403 );
is( $res->content, 'Forbidden' );

# GET request for non-existent resource (404)
$res = $test->request( req_json_demo GET => '/HEE HAW!!!/non-existent/resource' );
is( $res->code, 404 );
is( $res->content, 'Not Found' );

# PUT request for non-existent resource (405)
$res = $test->request( req_json_demo PUT => '/HEE HAW!!!/non-existent/resource' );
is( $res->code, 405 );
is( $res->content, 'Method Not Allowed' );

# POST request for non-existent resource (404)
$res = $test->request( req_json_demo POST => '/HEE HAW!!!/non-existent/resource' );
is( $res->code, 404 );
is( $res->content, 'Not Found' );

# DELETE request on non-existent resource (404)
$res = $test->request( req_json_demo DELETE => '/HEE HAW!!!/non-existent/resource' );
is( $res->code, 404 );
is( $res->content, 'Not Found' );

# test argument validation in '_push_onto_context' method
like( exception { App::Dochazka::REST::Resource::_push_onto_context( undef, 'DUMMY2' ); },
      qr/not one of the allowed types: hashref/ );
like( exception { App::Dochazka::REST::Resource::_push_onto_context( undef, {}, ( 3..12 ) ); },
      qr/but 1 was expected/ );
like( exception { App::Dochazka::REST::Resource::_push_onto_context(); },
      qr/0 parameters were passed.+but 1 was expected/ );

# test if we can get the context
my $resource_self = bless {}, 'App::Dochazka::REST::Resource';
is( $resource_self->context, undef );
$resource_self->context( { 'bubba' => 'BAAAA' } );
is( $resource_self->context->{'bubba'}, 'BAAAA' );

done_testing;
