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
use App::Dochazka::REST::Model::Privhistory qw( get_privhistory );
use App::Dochazka::REST::Model::Shared qw( noof );
use App::Dochazka::REST::Util::Timestamp qw( $today $today_ts $yesterday_ts $tomorrow_ts );
use Scalar::Util qw( blessed );
use Test::More;

# plan tests

plan skip_all => "Set DOCHAZKA_TEST_MODEL to activate data model tests" if ! defined $ENV{'DOCHAZKA_TEST_MODEL'};

my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka' );
my $status = $REST->{init_status};
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}

# insert a testing employee
my $emp = App::Dochazka::REST::Model::Employee->spawn(
        nick => 'mrprivhistory',
   );
$status = $emp->insert;
ok( $status->ok, "Inserted Mr. Privhistory" );

# assign an initial privilege level to the employee
my $ins_eid = $emp->eid;
my $ins_priv = 'active';
my $ins_effective = $today_ts;
my $ins_remark = 'TESTING';
my $priv = App::Dochazka::REST::Model::Privhistory->spawn(
              eid => $ins_eid,
              priv => $ins_priv,
              effective => $ins_effective,
              remark => $ins_remark,
          );
is( $priv->phid, undef, "phid undefined before INSERT" );
$priv->insert;
diag( $status->text ) if $status->not_ok;
ok( $status->ok, "Post-insert status ok" );
ok( $priv->phid > 0, "INSERT assigned an phid" );

# get the entire privhistory record just inserted
$status = $priv->load_by_eid( $emp->eid );
ok( $status->ok, "No DBI error" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "Record loaded" );
$priv->reset( $status->payload );
is( $priv->eid, $ins_eid );
is( $priv->priv, $ins_priv );
is( $priv->effective, $ins_effective );
is( $priv->remark, $ins_remark );

# spawn a fresh object and try it again
$status = App::Dochazka::REST::Model::Privhistory->load_by_eid( $emp->eid );
ok( $status->ok, "No DBI error" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "Record loaded" );
my $priv2 = $status->payload;
is( $priv2->eid, $ins_eid );
is( $priv2->priv, $ins_priv );
is( $priv2->effective, $ins_effective );
is( $priv2->remark, $ins_remark );

# get Mr. Priv History's priv level as of yesterday
$status = App::Dochazka::REST::Model::Privhistory->load_by_eid( $emp->eid, $yesterday_ts );
ok( $status->ok, "No DBI error" );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND', "Shouldn't return any rows" );
is( $emp->priv( $yesterday_ts ), 'passerby' );
is( $emp->priv( $today_ts ), 'active' );

# Get Mr. Privhistory's record again
$status = App::Dochazka::REST::Model::Privhistory->load_by_eid( $emp->eid );
ok( $status->ok, "No DBI error" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "Record loaded" );
$priv->reset( $status->payload );
#diag( Dumper( $priv ) );

# Count of privhistory records should be 2
is( noof(  "privhistory" ), 2 );

# test get_privhistory
$status = get_privhistory( $emp->eid, "[$today_ts, $tomorrow_ts)" );
ok( $status->ok, "Privhistory record found" );
my $ph = $status->payload->{'privhistory'};
is( scalar @$ph, 1, "One record" );

# backwards tsrange triggers DBI error
$status = get_privhistory( $emp->eid, "[$tomorrow_ts, $today_ts)" );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR', "backwards tsrange triggers DBI error" );

# add another record within the range
my $priv3 = App::Dochazka::REST::Model::Privhistory->spawn(
              eid => $ins_eid,
              priv => 'passerby',
              effective => "$today 02:00",
              remark => $ins_remark,
          );
is( $priv3->phid, undef, "phid undefined before INSERT" );
$status = $priv3->insert;
diag( $status->text ) if $status->not_ok;
ok( $status->ok, "Post-insert status ok" );
ok( $priv3->phid > 0, "INSERT assigned an phid" );

# test get_privhistory again -- do we get two records?
$status = get_privhistory( $emp->eid, "[$today_ts, $tomorrow_ts)" );
ok( $status->ok, "Privhistory record found" );
$ph = $status->payload->{'privhistory'};
is( scalar @$ph, 2, "Two records" );
#diag( Dumper( $ph ) );

# delete the privhistory records we just inserted
foreach my $priv ( @$ph ) {
    my $phid = $priv->phid;
    $status = $priv->delete;
    ok( $status->ok, "DELETE OK" );
    $priv->reset;
    $status = $priv->load_by_phid( $phid );
    is( $status->code, 'DISPATCH_NO_RECORDS_FOUND' );
}

# After deleting all the records we inserted, there should still be
# one left (root's)
is( noof( "privhistory" ), 1 );

# Total number of employees should now be 2 (root, demo and Mr. Privhistory)
is( noof( 'employees' ), 3 );

# Delete Mr. Privhistory himself, too, to clean up
$status = $emp->delete;
ok( $status->ok );
is( noof( 'employees' ), 2 );

done_testing;
