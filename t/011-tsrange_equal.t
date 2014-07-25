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
# unit tests demonstrating how to compare two tsrange strings for equality
# using App::Dochazka::REST::Util::Timestamp::tsrange_equal
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
use App::Dochazka::REST::Util::Timestamp qw( tsrange_equal );
use Scalar::Util qw( blessed );
use Test::More;

# plan tests
plan skip_all => "Set DOCHAZKA_TEST_MODEL to activate data model tests" if ! defined $ENV{'DOCHAZKA_TEST_MODEL'};
my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka' );
if ( $REST->{init_status}->not_ok ) {
    plan skip_all => "not configured or server not running";
} else {
    plan tests => 8;
}
my $status;

my $dbh = $REST->{dbh};
my $rc = $dbh->ping;
is( $rc, 1, "PostgreSQL database is alive" );

my $intvl1 = '[2014-07-15 08:00, 2014-07-15 12:00)';
ok( tsrange_equal( $dbh, $intvl1, '[2014-07-15 8:0, 2014-07-15 12:0)' ) );
ok( ! tsrange_equal( $dbh, $intvl1, '[2014-07-15 8:01, 2014-07-15 12:0)' ) );
ok( ! tsrange_equal( $dbh, $intvl1, '[2014-07-15 08:00, 2014-07-15 12:00]' ) );
my $intvl2 = '["2014-07-15 08:00", "2014-07-15 12:00")';
ok( tsrange_equal( $dbh, $intvl1, $intvl2) );
ok( tsrange_equal( $dbh, $intvl2, '[2014-07-15 8:0   , "2014-07-15 12:0")' ) );
ok( ! tsrange_equal( $dbh, $intvl2, '[2014-07-15 08:01, 2014-07-15 12:00)' ) );
ok( ! tsrange_equal( $dbh, $intvl2, '[2014-07-15 08:00, 2014-07-15 12:00]' ) );
