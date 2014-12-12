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
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use App::Dochazka::REST::Model::Employee qw( nick_exists eid_exists );
use App::Dochazka::REST::Model::Shared qw( noof );
use App::Dochazka::REST::Test;
use Test::Fatal;
use Test::More;


# initialize, connect to database, and set up a testing plan
my $status = initialize_unit();
plan skip_all => "not configured or server not running" unless $status->ok;


# get initial number of employees
my $noof_employees = noof( $dbix_conn, 'employees' );

# attempt to spawn a hooligan
like( exception { App::Dochazka::REST::Model::Employee->spawn( 'hooligan' => 'sneaking in' ); }, 
      qr/not listed in the validation options: hooligan/ );

# spawn an empty employee object
my $emp = App::Dochazka::REST::Model::Employee->spawn;
is( ref( $emp ), 'App::Dochazka::REST::Model::Employee' );
isa_ok( $emp, 'App::Dochazka::REST::Model::Employee' );

# try to reset in a hooligan-ish manner
like( exception { $emp->reset( 'hooligan' => 'sneaking in' ); }, 
      qr/not listed in the validation options: hooligan/ );

# attempt to load a non-existent nick
$status = App::Dochazka::REST::Model::Employee->load_by_nick( $dbix_conn, 'mrfu' ); 
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND', "Mr. Fu's nick doesn't exist" );
is( $status->{'count'}, 0, "Mr. Fu's nick doesn't exist" );
ok( ! exists $status->{'payload'} );
ok( ! defined( $status->payload ) );

# (root employee is created at dbinit time)
my $eid_of_root = $site->DOCHAZKA_EID_OF_ROOT;

sub test_root_accessors {
    my $emp = shift;
    is( $emp->remark, 'dbinit' );
    is( $emp->sec_id, undef );
    is( $emp->nick, 'root' );
    is( $emp->eid, $eid_of_root );
    is( $emp->priv( $dbix_conn ), 'admin' );
    is( $emp->schedule( $dbix_conn ), undef );
    is( $emp->email, 'root@site.org' );
    is( $emp->fullname, 'Root Immutable' );
}

# attempt to load root by nick and test accessors
$status = App::Dochazka::REST::Model::Employee->load_by_nick( $dbix_conn, 'root' ); 
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "Root employee loaded into object" );
isa_ok( $status->payload, 'App::Dochazka::REST::Model::Employee' );
test_root_accessors( $status->payload );

# attempt to load root by EID and test accessors
$status = App::Dochazka::REST::Model::Employee->load_by_eid( $dbix_conn, $eid_of_root ); 
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "Root employee loaded into object" );
isa_ok( $status->payload, 'App::Dochazka::REST::Model::Employee' );
test_root_accessors( $status->payload );

# get root's priv level and test priv accessor
is( $status->payload->priv( $dbix_conn ), 'admin', "root is an admin" );

# spawn an employee object
$emp = App::Dochazka::REST::Model::Employee->spawn( 
    nick => 'mrfu',
    fullname => 'Mr. Fu',
    email => 'mrfu@example.com',
);
isa_ok( $emp, 'App::Dochazka::REST::Model::Employee' );

# insert it
$status = $emp->insert( $faux_context );
is( $status->level, 'OK', "Mr. Fu inserted" );
my $eid_of_mrfu = $emp->{eid};
#diag( "eid of mrfu is $eid_of_mrfu" );

# nick_exists and eid_exists functions
ok( nick_exists( $dbix_conn, 'mrfu' ) );
ok( nick_exists( $dbix_conn, 'root' ) );
ok( nick_exists( $dbix_conn, 'demo' ) );
ok( eid_exists( $dbix_conn, $eid_of_mrfu ) );  
ok( eid_exists( $dbix_conn, $eid_of_root ) );  
ok( ! nick_exists( $dbix_conn, 'fandango' ) ); 
ok( ! nick_exists( $dbix_conn, 'barbarian' ) ); 
ok( ! eid_exists( $dbix_conn, 1341 ) ); 
ok( ! eid_exists( $dbix_conn, 554 ) ); 

# spawn another object
$status = App::Dochazka::REST::Model::Employee->load_by_eid( $dbix_conn, $eid_of_mrfu );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "load_by_eid returned OK status" );
my $emp2 = $status->payload;
is( $emp2->{eid}, $eid_of_mrfu, "EID matches that of Mr. Fu" );
is( $emp2->{nick}, 'mrfu', "Nick should be mrfu" );

# spawn Mrs. Fu
$emp = App::Dochazka::REST::Model::Employee->spawn( 
    nick => 'mrsfu',
    sec_id => 78923,
    email => 'consort@futown.orient.cn',
    fullname => 'Mrs. Fu',
);
isa_ok( $emp, 'App::Dochazka::REST::Model::Employee' );

# insert Mrs. Fu
$status = $emp->insert( $faux_context );
ok( $status->ok, "Mrs. Fu inserted" );
my $eid_of_mrsfu = $emp->{eid};
isnt( $eid_of_mrsfu, $eid_of_mrfu, "Mr. and Mrs. Fu are distinct entities" );

# recycle the object
$status = $emp->reset;
foreach my $prop ( App::Dochazka::REST::Model::Employee->attrs ) {
    is( $emp->get( $prop), undef );
}

# attempt to load a non-existent EID
$status = $emp->load_by_eid( $dbix_conn, 443 );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND', "Nick ID 443 does not exist" );
is( $status->{'count'}, 0, "Nick ID 443 does not exist" );

# attempt to load a non-existent nick
$status = $emp->load_by_nick( $dbix_conn, 'smithfarm' );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND' );
is( $status->{'count'}, 0 );

# load Mrs. Fu
$status = $emp->load_by_nick( $dbix_conn, 'mrsfu' );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "Nick mrsfu exists" );
$emp = $status->payload;
is( $emp->nick, 'mrsfu', "Mrs. Fu's nick is the right string" );
is( $emp->sec_id, 78923, "Mrs. Fu's secondary ID is the right string" );

# update Mrs. Fu
$emp->fullname( "Mrs. Fu that's Ma'am to you" );
is( $emp->fullname, "Mrs. Fu that's Ma'am to you" );
$status = $emp->update( $faux_context );
ok( $status->ok, "UPDATE status is OK" );
$status = App::Dochazka::REST::Model::Employee->load_by_nick( $dbix_conn, 'mrsfu' );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "Nick mrsfu exists" );
$emp2 = $status->payload;
is_deeply( $emp, $emp2 );

# pathologically change Mrs. Fu's nick to null
$emp->{'nick'} = undef;
$status = $emp->update( $faux_context );
ok( $status->not_ok );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );

# attempt to change Mrs. Fu's EID
my $saved_eid = $emp->eid;
ok( $saved_eid > 1 );
$emp->eid( 34342 );
is( $emp->eid, 34342 );
ok( $saved_eid != $emp->eid );
$status = $emp->update( $faux_context );
is( $status->level, 'NOTICE' );
is( $status->code, 'DOCHAZKA_CUD_NO_RECORDS_AFFECTED' );

# reload from saved eid
$status = App::Dochazka::REST::Model::Employee->load_by_eid( $dbix_conn, $saved_eid );
is( $status->level, "OK" );
$emp = $status->payload;
is( $emp->eid, $saved_eid );

# test accessors
is( $emp->eid, $emp->{eid}, "accessor: eid" );
is( $emp->fullname, "Mrs. Fu that's Ma'am to you", "accessor: fullname" );
is( $emp->nick, $emp->{nick}, "accessor: nick" );
is( $emp->email, $emp->{email}, "accessor: email" );
is( $emp->passhash, $emp->{passhash}, "accessor: passhash" );
is( $emp->salt, $emp->{salt}, "accessor: salt" );
is( $emp->remark, $emp->{remark}, "accessor: remark" );
my $priv_of_mrsfu = $emp->priv( $dbix_conn );
is( $priv_of_mrsfu, "passerby", "accessor: priv" );
is( $emp->priv( $dbix_conn ), $priv_of_mrsfu, "accessor: priv" );

# Employees table should have three records (root, demo, Mrs. Fu, and Mr. Fu)
is( noof( $dbix_conn, 'employees' ), 4 );

# Expurgate Mr. Fu
$status = $emp->load_by_nick( $dbix_conn, "mrfu" );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
$emp = $status->payload;
my $fu_eid = $emp->eid;
my $fu_nick = $emp->nick;
my $expurgated_fu = $emp->TO_JSON;
is( ref( $expurgated_fu ), 'HASH' );
is( $expurgated_fu->{eid}, $fu_eid );
is( $expurgated_fu->{nick}, $fu_nick );

# delete Mr. and Mrs. Fu
$status = $emp->load_by_nick( $dbix_conn, "mrsfu" );
ok( $status->ok );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
$emp = $status->payload;
$status = $emp->delete( $faux_context );
ok( $status->ok );
$status = $emp->load_by_nick( $dbix_conn, "mrfu" );
ok( $status->ok );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
$emp = $status->payload;
$status = $emp->delete( $faux_context );
ok( $status->ok );

# Employees table should now have the same number of records as at the beginning
is( noof( $dbix_conn, 'employees' ), $noof_employees );

done_testing;
