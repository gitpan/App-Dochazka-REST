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
# unit tests for scratch schedules
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
use App::Dochazka::REST::Model::Schedhistory;
use App::Dochazka::REST::Model::Schedintvls;
use App::Dochazka::REST::Model::Shared qw( noof );
#use App::Dochazka::REST::Util::Timestamp qw( $today $yesterday $tomorrow );
use Scalar::Util qw( blessed );
use Test::More;

# plan tests
plan skip_all => "Set DOCHAZKA_TEST_MODEL to activate data model tests" if ! defined $ENV{'DOCHAZKA_TEST_MODEL'};
my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka' );
if ( $REST->{init_status}->not_ok ) {
    plan skip_all => "not configured or server not running";
}

my $dbh = $REST->{dbh};
my $status;

my $rc = $dbh->ping;
is( $rc, 1, "PostgreSQL database is alive" );

# spawn a schedintvls object
my $sto = App::Dochazka::REST::Model::Schedintvls->spawn(
    dbh => $dbh,
);
ok( blessed $sto );
ok( $sto->scratch_sid > 0 );

# attempt to insert bogus intervals individually
my $bogus_intvls = [
        [ "[)" ],
        [ "[,)" ],
        [ "(2014-07-14 09:00, 2014-07-14 17:05)" ],
        [ "[2014-07-14 09:00, 2014-07-14 17:05]" ],
	[ "[,2014-07-14 17:00)" ],
        [ "[2014-07-14 17:15,)" ],
        [ "[2014-07-14 09:00, 2014-07-14 17:07)" ],
        [ "[2014-07-14 08:57, 2014-07-14 17:05)" ],
        [ "[2014-07-14 06:43, 2014-07-14 25:00)" ],
    ];
map {
        $sto->{intvls} = $_;
        $status = $sto->insert;
        #diag( $status->level . ' ' . $status->text );
        is( $status->level, 'ERR' ); 
    } @$bogus_intvls;

# check that no records made it into the database
is( noof( $dbh, 'schedintvls' ), 0 );

# attempt to slip in a bogus interval by hiding it among normal intervals
$bogus_intvls = [
        "[)",
        "[,)",
        "(2014-07-14 09:00, 2014-07-14 17:05)",
        "[2014-07-14 09:00, 2014-07-14 17:05]",
	"[,2014-07-14 17:00)",
        "[2014-07-14 17:15,)",
        "[2014-07-14 09:00, 2014-07-14 17:07)",
        "[2014-07-14 08:57, 2014-07-14 17:05)",
        "[2014-07-14 06:43, 2014-07-14 25:00)",
    ];
map {
        $sto->{intvls} = [
            "[2014-07-14 10:00, 2014-07-14 10:15)",
            "[2014-07-14 10:15, 2014-07-14 10:30)",
            $_,
            "[2014-07-14 11:15, 2014-07-14 11:30)",
            "[2014-07-14 11:30, 2014-07-14 11:45)",
        ];
        $status = $sto->insert;
        is( $status->level, 'ERR' );
        is( noof( $dbh, 'schedintvls' ), 0 );
     } @$bogus_intvls;

# CLEANUP: none as this unit test doesn't change the database

done_testing;
