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
use App::Dochazka::REST::Test qw( req_root req_demo );
use Data::Dumper;
use Plack::Test;
use Scalar::Util qw( blessed );
use Test::JSON;
use Test::More;


my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka' );
my $status = $REST->{init_status};
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}
my $app = $REST->{'app'};

# instantiate Plack::Test object
my $test = Plack::Test->create( $app );
ok( blessed $test );


# get 'root' employee by nick
my $res = $test->request( req_root GET => '/employee/nick/root' );
is( $res->code, 200 );
is_valid_json( $res->content );
like( $res->content, qr/DISPATCH_RECORDS_FOUND/ );
like( $res->content, qr/Root Immutable/ );

# get 'demo' employee by nick
$res = $test->request( req_root GET => '/employee/nick/demo' );
is( $res->code, 200 );
is_valid_json( $res->content );
like( $res->content, qr/DISPATCH_RECORDS_FOUND/ );
like( $res->content, qr/Demo Employee/ );

# get non-existent employee by nick
$res = $test->request( req_root GET => '/employee/nick/heathledger' );
is( $res->code, 200 );
is_valid_json( $res->content );
like( $res->content, qr/DISPATCH_NO_RECORDS_FOUND/ );

# get 'root' employee by EID
$res = $test->request( req_root GET => '/employee/eid/1' );
is( $res->code, 200 );
is_valid_json( $res->content );
like( $res->content, qr/DISPATCH_RECORDS_FOUND/ );
like( $res->content, qr/Root Immutable/ );

# get 'demo' employee by EID
$res = $test->request( req_root GET => '/employee/eid/2' );
is( $res->code, 200 );
is_valid_json( $res->content );
like( $res->content, qr/DISPATCH_RECORDS_FOUND/ );
like( $res->content, qr/Demo Employee/ );

# get non-existent employee by EID
$res = $test->request( req_root GET => '/employee/eid/53432' );
is( $res->code, 200 );
is_valid_json( $res->content );
like( $res->content, qr/DISPATCH_NO_RECORDS_FOUND/ );

# get current employee as demo
$res = $test->request( req_demo GET => '/employee/current' );
is( $res->code, 200 );
is_valid_json( $res->content );
like( $res->content, qr/Demo Employee/ );

# get current employee as root
$res = $test->request( req_root GET => '/employee/current' );
is( $res->code, 200 );
is_valid_json( $res->content );
like( $res->content, qr/Root Immutable/ );

done_testing;
