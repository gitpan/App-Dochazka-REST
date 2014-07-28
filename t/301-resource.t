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
use App::CELL qw( $meta $site );
use App::Dochazka::REST;
use App::Dochazka::REST::Resource;
use Data::Dumper;
use HTTP::Request;
use Plack::Test;
use Scalar::Util qw( blessed );
use Test::JSON;
use Test::More;

sub req_json {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic ZGVtbzpkZW1v' );
    $r->header( 'Accept' => 'application/json' );
    return $r;
}

sub req_html {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic ZGVtbzpkZW1v' );
    $r->header( 'Accept' => 'text/html' );
    return $r;
}

sub req_bad_creds {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic ZGVtbzpibGJvc3Q=' );
    return $r;
}


# initialize 
my $REST = App::Dochazka::REST->init( site => '/etc/dochazka' );
my $status = $REST->{init_status};
if ( $status->not_ok ) { 
    plan skip_all => "not configured or server not running";
}
my $app = $REST->{'app'};

# instantiate Plack::Test object
my $test = Plack::Test->create( $app );
ok( blessed $test );

# the very basic-est request (200)
my $res = $test->request( req_json GET => '/' );
is( $res->code, 200 );
is_valid_json( $res->content );
like( $res->content, qr/App::Dochazka::REST/ );

# a too-long request (414)
$res = $test->request( req_json GET => '/' x 1001 );
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
$res = $test->request( req_json GET => '/forbidden' );
is( $res->code, 403 );
is( $res->content, 'Forbidden' );

# request for non-existent resource
$res = $test->request( req_json GET => '/HEE HAW!!!/non-existent/resource' );
is( $res->code, 404 );
is( $res->content, 'Not Found' );

done_testing;
