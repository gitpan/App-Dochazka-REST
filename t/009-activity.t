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
# basic unit tests for activities
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use DBI;
use App::Dochazka::REST qw( $REST );
use App::Dochazka::REST::Model::Activity qw( aid_by_code );
use Scalar::Util qw( blessed );
use Test::More;

my $status = $REST->init( sitedir => '/etc/dochazka' );
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
} else {
    plan tests => 46;
}

my $dbh = $REST->{dbh};
my $rc = $dbh->ping;
is( $rc, 1, "PostgreSQL database is alive" );

# spawn activity object
my $act = App::Dochazka::REST::Model::Activity->spawn(
    dbh => $dbh,
    acleid => $site->DOCHAZKA_EID_OF_ROOT,
);

# test existence of initial set of activities
foreach my $actdef ( @{ $site->DOCHAZKA_ACTIVITY_DEFINITIONS } ) {
    $act->reset(
        code => $actdef->{code},
        long_desc => $actdef->{long_desc},
        remark => $actdef->{remark},
    );  
    $status = $act->load_by_code( $actdef->{code} );
    ok( $status->ok );
    is( $act->code, $actdef->{code} );
    is( $act->long_desc, $actdef->{long_desc} );
    is( $act->remark, 'dbinit' );
}

# load the work activity
my $work = App::Dochazka::REST::Model::Activity->spawn(
    dbh => $dbh,
    acleid => $site->DOCHAZKA_EID_OF_ROOT,
);
$status = $work->load_by_code( 'wOrK' );
ok( $status->ok );
ok( $work->aid > 0 );
is( $work->code, 'WORK' );

# get AID of 'WORK' using 'aid_by_code'
my $work_aid = aid_by_code( $dbh, 'WoRk' );
is( $work_aid, $work->aid );

# insert a bogus activity
my $bogus_act = App::Dochazka::REST::Model::Activity->spawn(
    dbh => $dbh,
    acleid => $site->DOCHAZKA_EID_OF_ROOT,
    code => 'boguS',
    long_desc => "A bogus activity that doesn't belong here",
    remark => 'BOGUS ACTIVITY',
);
$status = $bogus_act->insert;
diag( $status->text ) unless $status->ok;
ok( $status->ok );
ok( defined( $bogus_act->aid ) );
ok( $bogus_act->aid > 0 );
# test code accessor method and code_to_upper trigger
is( $bogus_act->code, 'BOGUS' );
is( $bogus_act->long_desc, "A bogus activity that doesn't belong here" );
is( $bogus_act->remark, 'BOGUS ACTIVITY' );

# try to insert the bogus activity again
$status = $bogus_act->insert;
ok( $status->not_ok );

# delete the bogus activity
$status = $bogus_act->delete;
ok( $status->ok );

# attempt to load the bogus activity
$bogus_act->reset;
$status = $bogus_act->load_by_code( 'BOGUS' );
#diag( $status->level . " " . $status->text ) unless $status->ok;
ok( $status->not_ok );

