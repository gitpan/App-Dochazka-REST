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
use Data::Dumper;
use HTTP::Request;
use Plack::Test;
use Scalar::Util qw( blessed );
use Test::JSON;
use Test::More;


# create request object with authorization header appended ('root')
sub req_root {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic cm9vdDppbW11dGFibGU=' );
    $r->header( 'Accept' => 'application/json' );
    return $r;
}

# create request object with authorization header appended ('demo')
sub req_demo {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic ZGVtbzpkZW1v' );
    $r->header( 'Accept' => 'application/json' );
    return $r;
}

my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka' );
my $status = $REST->{init_status};
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}
my $app = $REST->{'app'};

# instantiate Plack::Test object
my $test = Plack::Test->create( $app );
ok( blessed $test );

# 'privhistory' resource
my $res = $test->request( req_demo GET => '/privhistory' );
is( $res->code, 200 );
is_valid_json( $res->content );

$res = $test->request( req_root GET => '/privhistory' );
is( $res->code, 200 );
is_valid_json( $res->content );

# 'privhistory/current' resource - auth fail
$res = $test->request( req_demo GET => '/privhistory/current' );
is( $res->code, 403 );

$res = $test->request( req_root GET => '/privhistory/current' );
is( $res->code, 200 );
is_valid_json( $res->content );
like( $res->content, qr/DISPATCH_RECORDS_FOUND/ );

done_testing;