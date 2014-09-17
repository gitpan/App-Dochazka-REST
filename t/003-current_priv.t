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
# some tests to ensure/demonstrate that current_priv stored procedure
# works as advertised
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
use Test::More;


# initialize and connect to database
my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka-rest' );
my $status = $REST->{init_status};

# plan tests
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}

# define helper functions

sub test_sql_success {
    my ( $expected_rv, $sql ) = @_;
    my $rv = $REST->{dbh}->do($sql);
    is( $rv, $expected_rv, "successfully executed $sql" );
}

sub test_sql_fail {
    my ( $expected_err, $sql ) = @_;
    my $rv = $REST->{dbh}->do($sql);
    is( $rv, undef, "DBI returned undef" );
    like( $REST->{dbh}->errstr, $expected_err, "DBI errstr is as expected" );
}


# get database handle and ping the database just to be sure
my $dbh = $REST->{dbh};
my $rc = $dbh->ping;
is( $rc, 1, "PostgreSQL database is alive" );

# get EID of root employee, the hard way, and sanity-test it
my ( $eid_of_root ) = $dbh->selectrow_array( $site->DBINIT_SELECT_EID_OF_ROOT, undef );
is( $eid_of_root, $REST->eid_of_root );

# get root's current privilege level, the hard way
my $priv = $dbh->selectrow_array( "SELECT current_priv($eid_of_root)", undef );
is( $priv, "admin", "root is admin" );

# insert a new employee
test_sql_success(1, <<SQL);
INSERT INTO employees (nick) VALUES ('bubba')
SQL

# get bubba's current privilege level (will be 'passerby' because none
# defined yet)
my $eid_of_bubba = $dbh->selectrow_array( "SELECT eid FROM employees WHERE nick='bubba'", undef );
$priv = $dbh->selectrow_array( "SELECT current_priv($eid_of_bubba)", undef );
is( $priv, "passerby", "bubba is a passerby" );

# get priv level of non-existent employee (will be 'passerby')
$priv = $dbh->selectrow_array( "SELECT current_priv(0)", undef );
is( $priv, "passerby", "non-existent EID 0 is a passerby" );

# get priv level of another non-existent employee (will be 'passerby')
$priv = $dbh->selectrow_array( "SELECT current_priv(44)", undef );
is( $priv, "passerby", "non-existent EID 44 is a passerby" );

# make bubba an admin, but not until the year 3000
test_sql_success(1, <<SQL);
INSERT INTO privhistory (eid, priv, effective) 
VALUES ($eid_of_bubba, 'admin', '3000-01-01')
SQL

# test his current priv level - still passerby
$priv = $dbh->selectrow_array( "SELECT current_priv($eid_of_bubba)", undef );
is( $priv, "passerby", "bubba is still a passerby" );

# test his priv level at 2999-12-31 23:59:59
$priv = $dbh->selectrow_array( "SELECT priv_at_timestamp($eid_of_bubba, '2999-12-31 23:59:59')", undef );
is( $priv, "passerby", "bubba still a passerby" );

# test his priv level at 3001-06-30 14:34
$priv = $dbh->selectrow_array( "SELECT priv_at_timestamp($eid_of_bubba, '3001-06-30 14:34')", undef );
is( $priv, "admin", "bubba finally made admin" );

# attempt to delete his employee record -- FAIL
test_sql_fail(qr/violates foreign key constraint/, <<SQL);
DELETE FROM employees WHERE eid=$eid_of_bubba
SQL

# attempt to change his EID -- FAIL
test_sql_fail(qr/violates foreign key constraint/, <<SQL);
UPDATE employees SET eid=55 WHERE eid=$eid_of_bubba
SQL

# delete bubba privhistory
test_sql_success(1, <<SQL);
DELETE FROM privhistory WHERE eid=$eid_of_bubba
SQL

# delete bubba employee
test_sql_success(1, <<SQL);
DELETE FROM employees WHERE eid=$eid_of_bubba
SQL

done_testing;
