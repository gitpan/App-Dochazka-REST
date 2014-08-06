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
use App::Dochazka::REST::Model::Employee qw( nick_exists eid_exists );
use App::Dochazka::REST::Model::Shared qw( noof );
use Scalar::Util qw( blessed );
use Test::Fatal;
use Test::More;

plan skip_all => "Set DOCHAZKA_TEST_MODEL to activate data model tests" if ! defined $ENV{'DOCHAZKA_TEST_MODEL'};

my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka' );
my $status = $REST->{init_status};
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}

# test some wrong _load function calls
#like( exception { App::Dochazka::REST::Model::Employee::_load( 'eid' => 1, 'nick' => 'hooligan' ); },
#      qr/4 parameters were passed.+but 2 were expected/ );
#like( exception { App::Dochazka::REST::Model::Employee->_load( 'hooligan' ); },
#      qr/not listed in the validation options: App::Dochazka::REST::Model::Employee/ );
#like( exception { App::Dochazka::REST::Model::Employee::_load( ( 1..2 ) ); },
#      qr/not listed in the validation options/ );
#like( exception { App::Dochazka::REST::Model::Employee::_load( 'hooligan' => 'sneaking in' ); },
#      qr/not listed in the validation options: hooligan/ );

# attempt to spawn a hooligan
like( exception { App::Dochazka::REST::Model::Employee->spawn( 'hooligan' => 'sneaking in' ); }, 
      qr/not listed in the validation options: hooligan/ );

# spawn an empty employee object
my $emp = App::Dochazka::REST::Model::Employee->spawn;
ok( ref $emp, "object is a reference" );
ok( blessed $emp, "object is a blessed reference" );

# try to reset in a hooligan-ish manner
like( exception { $emp->reset( 'hooligan' => 'sneaking in' ); }, 
      qr/not listed in the validation options: hooligan/ );

# attempt to load a non-existent nick into the object
$status = $emp->load_by_nick( 'mrfu' ); 
ok( $status->ok );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND', "Mr. Fu's nick doesn't exist" );
is( $status->{'count'}, 0, "Mr. Fu's nick doesn't exist" );
ok( ! ref $status->payload );

# do the same, but as a class method
$status = App::Dochazka::REST::Model::Employee->load_by_nick( 'mrfu' ); 
ok( $status->ok );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND', "Mr. Fu's nick doesn't exist" );
is( $status->{'count'}, 0, "Mr. Fu's nick doesn't exist" );
ok( ! ref $status->payload );

# (root employee is created at dbinit time)

# attempt to load root by nick and test accessors
$status = $emp->load_by_nick( 'root' ); 
is( $status->code, 'DISPATCH_RECORDS_FOUND', "Root employee loaded into object" );
$emp->reset( $status->payload );
is( $emp->remark, 'dbinit' );
is( $emp->nick, 'root' );
is( $emp->eid, 1 );
is( $emp->priv, 'admin' );
is( $emp->schedule, '{}' );
is( $emp->email, 'root@site.org' );
is( $emp->fullname, 'Root Immutable' );
my $eid_of_root = $emp->eid;

# attempt to load root by EID and test accessors
$status = $emp->load_by_eid( $eid_of_root ); 
is( $status->code, 'DISPATCH_RECORDS_FOUND', "Root employee loaded into object" );
$emp = $status->payload;
is( $emp->remark, 'dbinit' );
is( $emp->nick, 'root' );
is( $emp->eid, $eid_of_root );
is( $emp->priv, 'admin' );
is( $emp->schedule, '{}' );
is( $emp->email, 'root@site.org' );
is( $emp->fullname, 'Root Immutable' );

# do the same, but use class method 

$status = App::Dochazka::REST::Model::Employee->load_by_nick( 'root' ); 
diag( $status->text ) unless $status->ok;
ok( $status->ok, "Root employee loaded into object" );
ok( ref $status->payload );
isa_ok( $status->payload, 'App::Dochazka::REST::Model::Employee' );
$emp = $status->payload;
is( $emp->remark, 'dbinit' );
is( $emp->nick, 'root' );
is( $emp->eid, $eid_of_root );
is( $emp->priv, 'admin' );
is( $emp->schedule, '{}' );
is( $emp->email, 'root@site.org' );
is( $emp->fullname, 'Root Immutable' );

$status = App::Dochazka::REST::Model::Employee->load_by_eid( $eid_of_root ); 
diag( $status->text ) unless $status->ok;
ok( $status->ok, "Root employee loaded into object" );
ok( ref $status->payload );
isa_ok( $status->payload, 'App::Dochazka::REST::Model::Employee' );
$emp = $status->payload;
is( $emp->remark, 'dbinit' );
is( $emp->nick, 'root' );
is( $emp->eid, $eid_of_root );
is( $emp->priv, 'admin' );
is( $emp->schedule, '{}' );
is( $emp->email, 'root@site.org' );
is( $emp->fullname, 'Root Immutable' );

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

# insert it
$status = $emp->insert();
ok( $status->ok, "Mr. Fu inserted" );
my $eid_of_mrfu = $emp->{eid};
#diag( "eid of mrfu is $eid_of_mrfu" );

# nick_exists and eid_exists functions
ok( nick_exists( 'mrfu' ) );
ok( eid_exists( $eid_of_mrfu ) );  
ok( ! nick_exists( 'fandango' ) ); 
ok( ! eid_exists( 1341 ) ); 

# spawn another object
$status = App::Dochazka::REST::Model::Employee->load_by_eid( $eid_of_mrfu );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "load_by_eid returned OK status" );
my $emp2 = $status->payload;
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
ok( $status->ok );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND', "Nick ID 443 does not exist" );
is( $status->{'count'}, 0, "Nick ID 443 does not exist" );

# attempt to load a non-existent nick
$status = $emp->load_by_nick( 'smithfarm' );
ok( $status->ok );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND' );
is( $status->{'count'}, 0 );

# load Mrs. Fu
$status = $emp->load_by_nick( 'mrsfu' );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "Nick mrsfu exists" );
$emp = $status->payload;
is( $emp->nick, 'mrsfu', "Mrs. Fu's nick is the right string" );

# update Mrs. Fu
$emp->fullname( "Mrs. Fu that's Ma'am to you" );
is( $emp->fullname, "Mrs. Fu that's Ma'am to you" );
$status = $emp->update;
ok( $status->ok, "UPDATE status is OK" );
# FIXME: re-load into another object and then compare the two objects using is_deeply
$status = App::Dochazka::REST::Model::Employee->load_by_nick( 'mrsfu' );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "Nick mrsfu exists" );
$emp2 = $status->payload;
is_deeply( $emp, $emp2 );

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

# Employees table should have three records (root, demo, Mrs. Fu, and Mr. Fu)
is( noof( 'employees' ), 4 );

# Expurgate Mr. Fu
$status = $emp->load_by_nick( "mrfu" );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
$emp = $status->payload;
my $fu_eid = $emp->eid;
my $fu_nick = $emp->nick;
my $expurgated_fu = $emp->expurgate;
ok( ! blessed $expurgated_fu );
is( $expurgated_fu->{eid}, $fu_eid );
is( $expurgated_fu->{nick}, $fu_nick );

# delete Mr. and Mrs. Fu
$status = $emp->load_by_nick( "mrsfu" );
ok( $status->ok );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
$emp = $status->payload;
$status = $emp->delete;
ok( $status->ok );
$status = $emp->load_by_nick( "mrfu" );
ok( $status->ok );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
$emp = $status->payload;
$status = $emp->delete;
ok( $status->ok );

# Employees table should now have two records (root, demo)
is( noof( 'employees' ), 2 );

done_testing;
