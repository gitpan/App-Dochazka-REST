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
# basic unit tests for PSGI
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use App::Dochazka::REST qw( $REST );
use Data::Dumper;
use HTTP::Request;
use Plack::Test;
use Scalar::Util qw( blessed );
use Test::JSON;
use Test::More tests => 20;

# create request object with authorization header appended
sub req {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic ZGVtbzpkZW1v' );
    return $r;
}

# initialize App::Dochazka::REST instance
my $status = $REST->init_no_db( site => '/etc/dochazka' );
ok( $status->ok );

# instantiate Plack::Test object
my $test = Plack::Test->create( $REST->{'app'} );
ok( blessed $test );

# path dispatcher tests (numbers in comments correspond to numbers in
# Dispatch.pm)

# 1. /
my $res = $test->request( req GET => '/' );
is_valid_json( $res->content );
like( $res->content, qr/App::Dochazka::REST/ );

# 2. /version
$res = $test->request( req GET => '/verSIOn' );
is_valid_json( $res->content );
like( $res->content, qr/App::Dochazka::REST/ );

# 3. /help
$res = $test->request( req GET => '/HELP' );
is_valid_json( $res->content );
like( $res->content, qr/DISPATCH_HELP/ );

# 4. /site
$res = $test->request( req GET => '/site/DOCHAZKA_APPNAME/' );
is_valid_json( $res->content );
my $match_string = $site->DOCHAZKA_APPNAME;
like( $res->content, qr/$match_string/ );

$res = $test->request( req GET => '/site/DOCHAZKA_APPNAME' );
is_valid_json( $res->content );
like( $res->content, qr/$match_string/ );

$res = $test->request( req GET => '/site/DOCHAZKA_appname' );
is_valid_json( $res->content );
unlike( $res->content, qr/DISPATCH_SITE_UNDEFINED/ );

$res = $test->request( req GET => '/site' );
is_valid_json( $res->content );
like( $res->content, qr/DISPATCH_SITE_MISSING/ );

$res = $test->request( req GET => '/site/' );
is_valid_json( $res->content );
like( $res->content, qr/DISPATCH_SITE_MISSING/ );

$res = $test->request( req GET => '/site/DOCHAZKA_APPNAME/foobar' );
is_valid_json( $res->content );
like( $res->content, qr/\/foobar/ );

