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
use App::CELL qw( $log $meta $site );
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

# 'employee/help' - list employee DELETE resources available to passersby
$res = $test->request( req_json_demo DELETE => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );

# 'employee/help' - list employee DELETE resources available to admins
$res = $test->request( req_json_root DELETE => '/employee/help' );
is( $res->code, 200 );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_DEFAULT' );
ok( exists $status->payload->{'documentation'} );
ok( exists $status->payload->{'resources'} );
ok( exists $status->payload->{'resources'}->{'employee/help'} );

# create a "cannon fodder" employee
$res = $test->request( req_json_root PUT => '/employee/nick/cannonfodder' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
my $cf = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
ok( $cf->eid > 1 );
my $eid_of_cf = $cf->eid;

# get cannonfodder - no problem
$res = $test->request( req_json_root GET => '/employee/nick/cannonfodder' );
is( $res->code, 200 );
$cf = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $cf->eid, $eid_of_cf );
is( $cf->nick, 'cannonfodder' );

# 'employee/eid/:eid' - delete cannonfodder
$res = $test->request( req_json_demo DELETE => '/employee/eid/' . $cf->eid );
is( $res->code, 403 );
$res = $test->request( req_json_root DELETE => '/employee/eid/' . $cf->eid );
is( $res->code, 200 );

# attempt to get cannonfodder - not there anymore
$res = $test->request( req_json_root GET => '/employee/nick/cannonfodder' );
is( $res->code, 404 );

# create another "cannon fodder" employee
$res = $test->request( req_json_root PUT => '/employee/nick/cannonfodder' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->ok );
is( $status->code, 'DISPATCH_EMPLOYEE_INSERT_OK' );
$cf = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
ok( $cf->eid > $eid_of_cf ); # EID will have incremented
$eid_of_cf = $cf->eid;

# get cannonfodder - no problem
$res = $test->request( req_json_root GET => '/employee/nick/cannonfodder' );
is( $res->code, 200 );
$cf = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $cf->eid, $eid_of_cf );
is( $cf->nick, 'cannonfodder' );

# 'employee/nick/:nick' - delete cannonfodder
$res = $test->request( req_json_demo DELETE => '/employee/nick/cannonfodder' );
is( $res->code, 403 );
$res = $test->request( req_json_root DELETE => '/employee/nick/cannonfodder' );
is( $res->code, 200 );

# attempt to get cannonfodder - not there anymore
$res = $test->request( req_json_root GET => '/employee/nick/cannonfodder' );
is( $res->code, 404 );

# attempt to delete 'root the immutable' (won't work)
$res = $test->request( req_json_root DELETE => '/employee/nick/root' );
is( $res->code, 200 );
is_valid_json( $res->content );
$status = status_from_json( $res->content );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, "DOCHAZKA_DBI_ERR" );
like( $status->text, qr/immutable/i );

done_testing;
