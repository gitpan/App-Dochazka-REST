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
use HTTP::Request;
use Plack::Test;
use Scalar::Util qw( blessed );
use Test::JSON;
use Test::More;

$meta->set( 'META_DOCHAZKA_UNIT_TESTING' => 1 );

# initialize
my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka-rest' );
my $status = $REST->{init_status};
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}
my $app = $REST->{'app'};

# instantiate Plack::Test object
my $test = Plack::Test->create( $app );
ok( blessed $test );

my $res;

# 1. privhistory/help as demo
$res = $test->request( req_demo GET => '/privhistory/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
is( scalar keys %{ $status->payload->{'resources'} }, 1 );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );

# 1. privhistory/help as root
$res = $test->request( req_root GET => '/privhistory/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( defined $status->payload );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
is( ref $status->payload->{'resources'}, 'HASH' );
ok( scalar keys %{ $status->payload->{'resources'} } >= 6 );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );
ok( exists $status->payload->{'resources'}->{'privhistory/current'} );
ok( exists $status->payload->{'resources'}->{'privhistory/nick/:nick'} );
ok( exists $status->payload->{'resources'}->{'privhistory/nick/:nick/:tsrange'} );
ok( exists $status->payload->{'resources'}->{'privhistory/eid/:eid'} );
ok( exists $status->payload->{'resources'}->{'privhistory/eid/:eid/:tsrange'} );
ok( exists $status->payload->{'resources'}->{'privhistory/help'} );

# 2. 'privhistory/current' resource - auth fail
$res = $test->request( req_demo GET => '/privhistory/current' );
is( $res->code, 403 );

# 2. 'privhistory/current' resource as root
$res = $test->request( req_root GET => '/privhistory/current' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'privhistory'} );
is( scalar @{ $status->payload->{'privhistory'} }, 1 );
is( $status->payload->{'privhistory'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'privhistory'}->[0]->{'effective'} );

# 3. 'privhistory/current/:tsrange' resource
$res = $test->request( req_demo GET => '/privhistory/current/[,)' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/privhistory/current/[,)' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'privhistory'} );
is( scalar @{ $status->payload->{'privhistory'} }, 1 );
is( $status->payload->{'privhistory'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'privhistory'}->[0]->{'effective'} );

# 3. 'privhistory/current/:tsrange' resource with invalid tsrange
$res = $test->request( req_root GET => '/privhistory/current/[,sdf)' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/invalid input syntax for type timestamp/ );

# 4. 'privhistory/nick/:nick'  with non-existent nick
$res = $test->request( req_demo GET => '/privhistory/nick/asdf' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/privhistory/nick/asdf' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, "DISPATCH_NICK_DOES_NOT_EXIST" );

# 5. 'privhistory/nick/root'
$res = $test->request( req_demo GET => '/privhistory/nick/root' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/privhistory/nick/root' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
ok( defined $status->payload );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'root' );
ok( exists $status->payload->{'privhistory'} );
is( scalar @{ $status->payload->{'privhistory'} }, 1 );
is( $status->payload->{'privhistory'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'privhistory'}->[0]->{'effective'} );

# 5. 'privhistory/nick/root/:tsrange' with privhistory record in range
$res = $test->request( req_demo GET => '/privhistory/nick/root/[999-12-31 23:59, 1000-01-01 00:01)' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/privhistory/nick/root/[999-12-31 23:59, 1000-01-01 00:01)' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
ok( defined $status->payload );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'root' );
ok( exists $status->payload->{'privhistory'} );
is( scalar @{ $status->payload->{'privhistory'} }, 1 );
is( $status->payload->{'privhistory'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'privhistory'}->[0]->{'effective'} );

# 5. 'privhistory/nick/root/:tsrange' -- empty range
$res = $test->request( req_demo GET => '/privhistory/nick/root/[1999-12-31 23:59, 2000-01-01 00:01)' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/privhistory/nick/root/[1999-12-31 23:59, 2000-01-01 00:01)' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_NO_RECORDS_FOUND" );
ok( defined $status->payload );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'root' );
ok( defined $status->payload->{'privhistory'} );
is_deeply( $status->payload->{'privhistory'}, [] );

# 6. 'privhistory/eid/$eid_of_root'
$res = $test->request( req_demo GET => '/privhistory/eid/' .  $site->DOCHAZKA_EID_OF_ROOT );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/privhistory/eid/' .  $site->DOCHAZKA_EID_OF_ROOT );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'privhistory'} );
is( scalar @{ $status->payload->{'privhistory'} }, 1 );
is( $status->payload->{'privhistory'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'privhistory'}->[0]->{'effective'} );

# 6. 'privhistory/eid/1/:tsrange' with privhistory record in range
$res = $test->request( req_demo GET => '/privhistory/eid/' .  $site->DOCHAZKA_EID_OF_ROOT . 
    '/[999-12-31 23:59, 1000-01-01 00:01)' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/privhistory/eid/' .  $site->DOCHAZKA_EID_OF_ROOT . 
    '/[999-12-31 23:59, 1000-01-01 00:01)' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_RECORDS_FOUND" );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'privhistory'} );
is( scalar @{ $status->payload->{'privhistory'} }, 1 );
is( $status->payload->{'privhistory'}->[0]->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'privhistory'}->[0]->{'effective'} );

# 5. 'privhistory/nick/root/:tsrange' -- empty range
$res = $test->request( req_demo GET => '/privhistory/eid/' .  $site->DOCHAZKA_EID_OF_ROOT . 
    '/[1999-12-31 23:59, 2000-01-01 00:01)' );
is( $res->code, 403 );
$res = $test->request( req_root GET => '/privhistory/eid/' .  $site->DOCHAZKA_EID_OF_ROOT . 
    '/[1999-12-31 23:59, 2000-01-01 00:01)' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, "DISPATCH_NO_RECORDS_FOUND" );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( defined $status->payload->{'privhistory'} );
is_deeply( $status->payload->{'privhistory'}, [] );

done_testing;
