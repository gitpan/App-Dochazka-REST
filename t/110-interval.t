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
# basic unit tests for activity intervals
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use DBI;
use App::Dochazka::REST;
use App::Dochazka::REST::Model::Employee;
use App::Dochazka::REST::Model::Interval;
use App::Dochazka::REST::Model::Shared qw( noof );
use App::Dochazka::REST::Util::Timestamp qw( $today $yesterday $tomorrow tsrange_equal );
use Scalar::Util qw( blessed );
use Test::More;

# plan tests
plan skip_all => "Set DOCHAZKA_TEST_MODEL to activate data model tests" if ! defined $ENV{'DOCHAZKA_TEST_MODEL'};
my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka-rest' );
my $status = $REST->{init_status};
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}

# spawn interval object
my $int = App::Dochazka::REST::Model::Interval->spawn;
ok( blessed( $int ) );

# to insert an interval, we need an employee and an activity

# insert Mr. Sched
my $emp = App::Dochazka::REST::Model::Employee->spawn(
    nick => 'mrsched',
);
$status = $emp->insert;
diag( $status->text ) unless $status->ok;
ok( $status->ok );
ok( $emp->eid > 0 );
is( noof( 'employees'), 3 );

# load 'WORK'
$status = App::Dochazka::REST::Model::Activity->load_by_code( 'work' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
my $work = $status->payload;
ok( $work->aid > 0 );

# Load up the object
$int->{eid} = $emp->eid;
$int->{aid} = $work->aid;
my $intvl = "[$today 08:00, $today 12:00)";
$int->{intvl} = $intvl;
$int->{long_desc} = 'Pencil pushing';
$int->{remark} = 'TEST INTERVAL';
is( $int->iid, undef );

# Insert the interval
$status = $int->insert;
diag( $status->code . " " . $status->text ) unless $status->ok;
ok( $status->ok );
ok( $int->iid > 0 );
my $saved_iid = $int->iid;

# test accessors
ok( $int->iid > 0 );
is( $int->eid, $emp->eid );
is( $int->aid, $work->aid );
ok( tsrange_equal( $int->intvl, $intvl ) );
is( $int->long_desc, 'Pencil pushing' );
is( $int->remark, 'TEST INTERVAL' );

# load_by_iid
$status = App::Dochazka::REST::Model::Interval->load_by_iid( $saved_iid );
diag( $status->text ) unless $status->ok;
ok( $status->ok );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
my $newint = $status->payload;
is( $newint->long_desc, "Pencil pushing" );

# CLEANUP:
# 1. delete the interval
is( noof( 'intervals' ), 1 );
$status = $int->delete;
ok( $status->ok );
is( noof( 'intervals' ), 0 );

# 2. delete Mr. Sched
is( noof( 'employees' ), 3 );
$status = $emp->delete;
ok( $status->ok );
is( noof( 'employees' ), 2 );

done_testing;
