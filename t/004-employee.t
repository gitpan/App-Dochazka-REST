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
use App::Dochazka::REST::Model::Employee qw( eid_by_nick );
use App::Dochazka::REST::Model::Shared qw( noof );
use Scalar::Util qw( blessed );
use Test::More;

my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka' );
my $status = $REST->{init_status};
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
} else {
    plan tests => 58;
}

# test database handle
my $dbh = $REST->{dbh};
my $rc = $dbh->ping;
is( $rc, 1, "PostgreSQL database is alive" );

# spawn an empty employee object
my $emp = App::Dochazka::REST::Model::Employee->spawn;
ok( blessed($emp), "object is blessed" );
is( $emp->{dbh}, $dbh, "database handle is in the object" );

# attempt to load a non-existent nick into the object
$status = $emp->load_by_nick( 'mrfu' ); 
is( $status->level, 'WARN', "Mr. Fu's nick doesn't exist" );

# (root employee is created at dbinit time)
# attempt to load root by nick and test accessors
$status = $emp->load_by_nick( 'root' ); 
diag( $status->text ) unless $status->ok;
ok( $status->ok, "Root employee loaded into object" );
is( $emp->remark, 'IMMUTABLE' );
is( $emp->nick, 'root' );
is( $emp->eid, 1 );
is( $emp->priv, 'admin' );
is( $emp->schedule, '{}' );
is( $emp->email, 'root@site.org' );
is( $emp->fullname, 'El Rooto' );

# get root's priv level and test priv accessor
ok( exists( $emp->{priv} ) );
is( $emp->{priv}, 'admin', "root is an admin" );
is( $emp->priv, 'admin', "root is an admin another way" );

# spawn an employee object
$emp = App::Dochazka::REST::Model::Employee->spawn( 
    nick => 'mrfu',
    fullname => 'Mr. Fu',
    email => 'mrfu@example.com',
);

ok( ref($emp), "object is a reference" );
ok( blessed($emp), "object is a blessed reference" );
is( $emp->{dbh}, $dbh, "database handle is in the object" );

# insert it
$status = $emp->insert();
ok( $status->ok, "Mr. Fu inserted" );
my $eid_of_mrfu = $emp->{eid};

# spawn another object
my $emp2 = App::Dochazka::REST::Model::Employee->spawn;
$status = $emp2->load_by_eid( $eid_of_mrfu );
ok( $status->ok, "load_by_eid returned OK status" );
is( $emp2->{eid}, $eid_of_mrfu, "EID matches that of Mr. Fu" );
is( $emp2->{nick}, 'mrfu', "Nick should be mrfu" );

# spawn Mrs. Fu
$emp = App::Dochazka::REST::Model::Employee->spawn( 
    nick => 'mrsfu',
    email => 'consort@futown.orient.cn',
    fullname => 'Mrs. Fu',
);
ok( blessed( $emp ) );

# insert Mrs. Fu
$status = $emp->insert;
ok( $status->ok, "Mrs. Fu inserted" );
my $eid_of_mrsfu = $emp->{eid};
isnt( $eid_of_mrsfu, $eid_of_mrfu, "Mr. and Mrs. Fu are distinct entities" );

# recycle the object
$status = $emp->reset;
is( $emp->eid, undef );
is( $emp->nick, undef );
is( $emp->fullname, undef );
is( $emp->email, undef );
is( $emp->passhash, undef );
is( $emp->salt, undef );
is( $emp->remark, undef );

# attempt to load a non-existent EID
$status = $emp->load_by_eid(443);
ok( $status->not_ok, "Nick ID 443 does not exist" );

# attempt to load a non-existent nick
$status = $emp->load_by_nick( 'smithfarm' );
ok( $status->not_ok, "Nick smithfarm does not exist" );

# load Mrs. Fu
$status = $emp->load_by_nick( 'mrsfu' );
ok( $status->ok, "Nick mrsfu exists" );
is( $emp->nick, 'mrsfu', "Mrs. Fu's nick is the right string" );

# update Mrs. Fu
$emp->{fullname} = "Mrs. Fu that's Ma'am to you";
$status = $emp->update;
ok( $status->ok, "UPDATE status is OK" );
is( $emp->{fullname}, "Mrs. Fu that's Ma'am to you", "Fullname updated" );
is( $emp->fullname, "Mrs. Fu that's Ma'am to you" );

# test accessors
is( $emp->eid, $emp->{eid}, "accessor: eid" );
is( $emp->fullname, "Mrs. Fu that's Ma'am to you", "accessor: fullname" );
is( $emp->nick, $emp->{nick}, "accessor: nick" );
is( $emp->email, $emp->{email}, "accessor: email" );
is( $emp->passhash, $emp->{passhash}, "accessor: passhash" );
is( $emp->salt, $emp->{salt}, "accessor: salt" );
is( $emp->remark, $emp->{remark}, "accessor: remark" );
is( $emp->priv, $emp->{priv}, "accessor: priv" );
is( $emp->priv, "passerby", "accessor: priv" );

# Employees table should have three records (root, Mrs. Fu, and Mr. Fu)
is( noof( $dbh, 'employees' ), 3 );

# Expurgate Mr. Fu
$status = $emp->load_by_nick( "mrfu" );
ok( $status->ok );
my $fu_eid = $emp->eid;
my $fu_nick = $emp->nick;
my $expurgated_fu = $emp->expurgate;
ok( ! blessed $expurgated_fu );
is( $expurgated_fu->{eid}, $fu_eid );
is( $expurgated_fu->{nick}, $fu_nick );

# delete Mr. and Mrs. Fu
$status = $emp->load_by_nick( "mrsfu" );
ok( $status->ok );
$status = $emp->delete;
ok( $status->ok );
$status = $emp->load_by_nick( "mrfu" );
ok( $status->ok );
$status = $emp->delete;
ok( $status->ok );

# Employees table should now have one record (root)
is( noof( $dbh, 'employees' ), 1 );
