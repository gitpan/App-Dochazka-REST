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
use App::Dochazka::REST qw( $REST );
use App::Dochazka::REST::Model::Employee;
use App::Dochazka::REST::Model::Privhistory qw( get_privhistory );
use App::Dochazka::REST::Model::Shared qw( noof );
use App::Dochazka::REST::Util::Timestamp qw( $today $today_ts $yesterday_ts $tomorrow_ts );
use Scalar::Util qw( blessed );
use Test::More;

# plan tests
my $status = $REST->init( sitedir => '/etc/dochazka' );
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
} else {
    plan tests => 36;
}

# get database handle and ping the database just to be sure
my $dbh = $REST->{dbh};
my $rc = $dbh->ping;
is( $rc, 1, "PostgreSQL database is alive" );

# insert a testing employee
my $emp = App::Dochazka::REST::Model::Employee->spawn(
        dbh => $dbh,
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
              dbh => $dbh,
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
$priv->reset;
$status = $priv->load( $emp->eid );
ok( $status->ok, "Load OK" );
is( $priv->eid, $ins_eid );
is( $priv->priv, $ins_priv );
is( $priv->effective, $ins_effective );
is( $priv->remark, $ins_remark );

# spawn a fresh object and try it again
my $priv2 = App::Dochazka::REST::Model::Privhistory->spawn(
              dbh => $dbh,
);
$status = $priv2->load( $emp->eid );
ok( $status->ok, "Load OK" );
is( $priv->eid, $ins_eid );
is( $priv->priv, $ins_priv );
is( $priv->effective, $ins_effective );
is( $priv->remark, $ins_remark );

# get Mr. Priv History's priv level as of yesterday
$priv->reset;
$status = $priv->load( $emp->eid, $yesterday_ts );
ok( $status->not_ok, "This shouldn't return any rows" );
is( $status->level, 'WARN', "It should also trigger a warning" );
is( $emp->priv( $yesterday_ts ), 'passerby' );
is( $emp->priv( $today_ts ), 'active' );

# Get Mr. Privhistory's record again
$priv->reset;
$status = $priv->load( $emp->eid );
ok( $status->ok, "Load OK" );
#diag( Dumper( $priv ) );

# Count of privhistory records should be 2
is( noof( $dbh, "privhistory" ), 2 );

# test get_privhistory
$status = get_privhistory( $dbh, $emp->eid, "[$today_ts, $tomorrow_ts)" );
ok( $status->ok, "Privhistory record found" );
my $ph = $status->payload;
is( scalar @$ph, 1, "One record" );
#diag( Dumper( $ph ) );

# add another record within the range
my $priv3 = App::Dochazka::REST::Model::Privhistory->spawn(
              dbh => $dbh,
              eid => $ins_eid,
              priv => 'passerby',
              effective => "$today 02:00",
              remark => $ins_remark,
          );
is( $priv3->phid, undef, "phid undefined before INSERT" );
$priv3->insert;
diag( $status->text ) if $status->not_ok;
ok( $status->ok, "Post-insert status ok" );
ok( $priv3->phid > 0, "INSERT assigned an phid" );

# test get_privhistory again -- do we get two records?
$status = get_privhistory( $dbh, $emp->eid, "[$today_ts, $tomorrow_ts)" );
ok( $status->ok, "Privhistory record found" );
$ph = $status->payload;
is( scalar @$ph, 2, "Two records" );
#diag( Dumper( $ph ) );

# delete the privhistory records we just inserted
foreach my $priv ( @$ph ) {
    my $phid = $priv->phid;
    $status = $priv->delete;
    ok( $status->ok, "DELETE OK" );
    $priv->reset;
    $status = $priv->load_by_phid( $phid );
    is( $status->level, 'WARN', "No records" );
}

# After deleting all the records we inserted, there should still be
# one left (root's)
is( noof( $dbh, "privhistory" ), 1 );

# Total number of employees should now be 2 (root and Mr. Privhistory)
is( noof( $dbh, 'employees' ), 2 );

# Delete Mr. Privhistory himself, too, to clean up
$status = $emp->delete;
ok( $status->ok );
is( noof( $dbh, 'employees' ), 1 );
