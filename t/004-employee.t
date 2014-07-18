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
use App::Dochazka::REST::Model::Employee qw( eid_by_nick );
use Scalar::Util qw( blessed );
use Test::More;

my $status = $REST->init( sitedir => '/etc/dochazka' );
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
} else {
    plan tests => 47;
}

# test database handle
my $dbh = $REST->{dbh};
my $rc = $dbh->ping;
is( $rc, 1, "PostgreSQL database is alive" );

# spawn an empty employee object
my $emp = App::Dochazka::REST::Model::Employee->spawn( 
    dbh => $dbh,
    acleid => $site->DOCHAZKA_EID_OF_ROOT, 
);
ok( blessed($emp), "object is blessed" );
is( $emp->{dbh}, $dbh, "database handle is in the object" );
ok( exists( $emp->{acleid} ) );
ok( $emp->{acleid} > 0, "There is an ACL EID" );

# attempt to load a non-existent nick into the object
$status = $emp->load_by_nick( 'mrfu' ); 
is( $status->level, 'WARN', "Mr. Fu's nick doesn't exist" );

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

$status = $emp->load_by_nick( 'bubba' );
ok( $status->ok, "employee bubba loaded into object" );
my $eid_of_bubba = $emp->{eid};

# compare it with the EID from eid_by_nick
ok( $dbh->ping, "Database handle is valid" );
is( $eid_of_bubba, eid_by_nick( $dbh, 'bubba' ), "Bubba EID match" );

# get bubba's priv level
is( $emp->{priv}, 'passerby', "bubba is a passerby" );

$status = $emp->load_by_eid( $eid_of_bubba );
ok( $status->ok, "employee bubba loaded into object" );

# spawn an employee object
$emp = App::Dochazka::REST::Model::Employee->spawn( 
    dbh => $dbh,
    acleid => $site->DOCHAZKA_EID_OF_ROOT, 
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
my $emp2 = App::Dochazka::REST::Model::Employee->spawn( 
    dbh => $dbh,
    acleid => $site->DOCHAZKA_EID_OF_ROOT, 
);
$status = $emp2->load_by_eid( $eid_of_mrfu );
ok( $status->ok, "load_by_eid returned OK status" );
is( $emp2->{eid}, $eid_of_mrfu, "EID matches that of Mr. Fu" );
is( $emp2->{nick}, 'mrfu', "Nick should be mrfu" );

# spawn Mrs. Fu
$emp = App::Dochazka::REST::Model::Employee->spawn( 
    dbh => $dbh,
    acleid => $site->DOCHAZKA_EID_OF_ROOT, 
    nick => 'mrsfu',
    email => 'consort@futown.orient.cn',
    fullname => 'Mrs. Fu',
);
$status = $emp->insert;
ok( $status->ok, "Mrs. Fu inserted" );
my $eid_of_mrsfu = $emp->{eid};
#diag( Dumper( $emp ) );

# recycle the same object
$status = $emp->load_by_eid(443);
ok( $status->not_ok, "Nick ID 443 does not exist" );
$status = $emp->load_by_nick( 'smithfarm' );
ok( $status->not_ok, "Nick smithfarm does not exist" );
$status = $emp->load_by_nick( 'bubba' );
$eid_of_bubba = undef;
ok( $status->ok, "bubba exists" );
$eid_of_bubba = $emp->{eid};
is( $emp->{priv}, 'passerby', "Bubba is just a passerby" );
is( $emp->{eid}, $eid_of_bubba, "EID matches" );
$status = $emp->load_by_nick( 'mrsfu' );
ok( $status->ok, "Nick mrsfu exists" );
#is( $emp->{nick}, 'mrsfu', "Mrs. Fu's nick is the right string" );

# update Mrs. Fu
$emp->{fullname} = "Mrs. Fu that's Ma'am to you";
$status = $emp->update;
ok( $status->ok, "UPDATE status is OK" );
is( $emp->{fullname}, "Mrs. Fu that's Ma'am to you", "Fullname updated" );

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
