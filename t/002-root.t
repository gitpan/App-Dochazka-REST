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
# some tests to ensure/demonstrate that the root employee is immutable
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

my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka' );
my $status = $REST->{init_status};
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}

my $dbh = $REST->{dbh};
my $rc = $dbh->ping;
is( $rc, 1, "PostgreSQL database is alive" );

my $autocommit = $dbh->{AutoCommit};
$dbh->{AutoCommit} = 1;

# get EID of root employee
my $eid_of_root = $dbh->selectrow_array( $site->DBINIT_SELECT_EID_OF_ROOT );
my $test = $site->DOCHAZKA_EID_OF_ROOT;
is( $test, $eid_of_root, "EID of root is correct" );
is( $eid_of_root, 1, "EID of root is 1" );
is( $eid_of_root, $REST->eid_of_root );

sub test_sql_fail {
    my ( $expected_err, $sql ) = @_;
    my $rv = $dbh->do($sql);
    is( $rv, undef, "DBI returned undef" );
    like( $dbh->errstr, $expected_err, "DBI errstr is as expected" );
}

# attempt to insert a new root employee
#diag( 'attempt to insert a new root employee' );
test_sql_fail(qr/duplicate key value/, <<SQL);
INSERT INTO employees (eid) VALUES ($eid_of_root)
SQL

# attempt to insert a new root employee in another way
#diag( 'attempt to insert a new root employee in another way' );
test_sql_fail(qr/duplicate key value/, <<SQL);
INSERT INTO employees (nick) VALUES ('root')
SQL

# attempt to change EID of root employee -- FAIL
#diag( "attempt to change EID of root employee" );
test_sql_fail(qr/violates foreign key constraint/, <<SQL);
UPDATE employees SET eid=55 WHERE eid=$eid_of_root
SQL

# attempt to change nick of root employee -- FAIL
#diag( 'attempt to change nick of root employee' );
test_sql_fail(qr/root employee is immutable/, <<SQL);
UPDATE employees SET nick = 'Bubba' WHERE eid=$eid_of_root
SQL

# we _can_ change fullname of root employee, though not recommended to do so
#diag( 'change fullname of root employee' );
#my $rv = $dbh->do( <<SQL , undef, 'El Rooto', $eid_of_root ) or die( $dbh->errstr );
#UPDATE employees SET fullname=? WHERE eid=?
#SQL
#is( $rv, 1, "root employee's email changed" );

# and we _can_ change the email of root employee -- a site might want to
# send email to root
#diag( 'change email of root employee' );
#$rv = $dbh->do( <<SQL , undef, 'root@site.org', $eid_of_root ) or die( $dbh->errstr );
#UPDATE employees SET email=? WHERE eid=?
#SQL
#is( $rv, 1, "root employee's email changed" );

# and we _can_, of course, change root's passhash and salt
#diag( 'change root passhash' );
my $rv = $dbh->do( <<SQL , undef, '$1$iT4NN7aG$EPzMy7jnV3w.rFZ/HLSu21', 'O+i0Ssyc', $eid_of_root ) or die( $dbh->errstr );
UPDATE employees SET passhash=?, salt=? WHERE eid=?
SQL
is( $rv, 1, "root employee's passhash and salt changed" );

# change it back
$rv = $dbh->do( <<SQL , undef, 'immutable', undef, $eid_of_root ) or die( $dbh->errstr );
UPDATE employees SET passhash=?, salt=? WHERE eid=?
SQL
is( $rv, 1, "root employee's passhash and salt changed back the way they were before" );

# attempt to delete the root employee
#diag( 'attempt to delete the root employee' );
test_sql_fail(qr/root employee is immutable/, <<SQL);
DELETE FROM employees WHERE eid=$eid_of_root
SQL

# attempt to change root's nick in another way -- FAIL
#diag( 'attempt to update the root employee in another way' );
test_sql_fail(qr/root employee is immutable/, <<SQL);
UPDATE employees SET nick = 'Bubba' WHERE nick='root'
SQL

# attempt to delete the root employee in another way -- FAIL
test_sql_fail(qr/root employee is immutable/, <<SQL);
DELETE FROM employees WHERE nick='root'
SQL

# attempt to insert a second privhistory row for root employee -- FAIL
test_sql_fail(qr/root employee is immutable/, <<SQL);
INSERT INTO privhistory (eid, priv, effective)
VALUES ($eid_of_root, 'passerby', '2000-01-01')
SQL

# attempt to change root's single privhistory row -- FAIL
test_sql_fail(qr/root employee is immutable/, <<SQL);
UPDATE privhistory SET priv='passerby' WHERE eid=$eid_of_root
SQL

# attempt to delete root's single privhistory row -- FAIL
test_sql_fail(qr/root employee is immutable/, <<SQL);
DELETE FROM privhistory WHERE eid=$eid_of_root
SQL

$dbh->{AutoCommit} = $autocommit;

done_testing;
