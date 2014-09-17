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
use App::Dochazka::REST::Test qw( req_root req_demo status_from_json );
use Data::Dumper;
use Plack::Test;
use Scalar::Util qw( blessed );
use Test::JSON;
use Test::More;


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

# 1. /employee/help as demo
$res = $test->request( req_demo GET => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 2 );
ok( exists $status->payload->{'resources'}->{'employee/help'} );

# 1. /employee/help as root
$res = $test->request( req_root GET => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( keys %{ $status->payload->{'resources'} } >= 6 );
ok( exists $status->payload->{'resources'}->{'employee/help'} );

# 2. /employee/current as demo user
$res = $test->request( req_demo GET => '/employee/current' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
ok( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'demo' );

# 2. /employee/current as root user
$res = $test->request( req_root GET => '/employee/current' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
ok( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'root' );

# 3. /employee/nick/root as root
$res = $test->request( req_root GET => '/employee/nick/root' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
ok( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
my $emp = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( ref $emp, 'App::Dochazka::REST::Model::Employee' );
is( $emp->eid, $site->DOCHAZKA_EID_OF_ROOT );
is( $emp->nick, 'root' );

# 3. /employee/nick/demo as root
$res = $test->request( req_root GET => '/employee/nick/demo' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
ok( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
$emp->reset( %{ $status->payload } );
is( ref $emp, 'App::Dochazka::REST::Model::Employee' );
is( $emp->nick, 'demo' );
my $eid_of_demo = $emp->eid;

# 3. /employee/nick/heathledger
$res = $test->request( req_root GET => '/employee/nick/heathledger' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND' );

# 4. /employee/eid/1
$res = $test->request( req_root GET => '/employee/eid/' . $site->DOCHAZKA_EID_OF_ROOT );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'root' );
ok( exists $status->payload->{'fullname'} );
is( $status->payload->{'fullname'}, 'Root Immutable' );

# 4. /employee/eid/$eid_of_demo
$res = $test->request( req_root GET => "/employee/eid/$eid_of_demo" );
is( $res->code, 200 );
$status = status_from_json( $res->content );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, $eid_of_demo );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'demo' );
ok( exists $status->payload->{'fullname'} );
is( $status->payload->{'fullname'}, 'Demo Employee' );

# 4. /employee/eid/$eid_of_demo as demo
$res = $test->request( req_demo GET => "/employee/eid/$eid_of_demo" );
is( $res->code, 403 );

# 4. /employee/eid/53432
$res = $test->request( req_root GET => '/employee/eid/53432' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND' );

# 4. /employee/eid/53432 as demo
$res = $test->request( req_demo GET => "/employee/eid/53432" );
is( $res->code, 403 );

# 5. /employee/count as root
$res = $test->request( req_root GET => '/employee/count' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_COUNT_EMPLOYEES' );

# 5. /employee/count as demo
$res = $test->request( req_demo GET => '/employee/count' );
is( $res->code, 403 );

# 6. /employee/count/admin
$res = $test->request( req_root GET => '/employee/count/admin' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_COUNT_EMPLOYEES' );
ok( defined $status->payload );
ok( exists $status->payload->{'priv'} );
is( $status->payload->{'priv'}, 'admin' );
is( $status->payload->{'count'}, 1 );

# 6. /employee/count/admin as demo
$res = $test->request( req_demo GET => '/employee/count/admin' );
is( $res->code, 403 );

# 6. /employee/count/inactive
$res = $test->request( req_root GET => '/employee/count/inactive' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_COUNT_EMPLOYEES' );
ok( defined $status->payload );
ok( exists $status->payload->{'priv'} );
is( $status->payload->{'priv'}, 'inactive' );
is( $status->payload->{'count'}, 0 );

# get non-existent privilege employee count as root
$res = $test->request( req_root GET => '/employee/count/inactivepeeplz' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_INVALID_PRIV' );

done_testing;
