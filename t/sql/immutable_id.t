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
# some tests to ensure/demonstrate that eid, iid, etc. fields are immutable
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
use App::Dochazka::REST::Util::Timestamp qw( $today $today_ts $yesterday_ts $tomorrow_ts );
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


#======================
# employees.eid field is immutable
#======================

# get EID of demo
my ( $eid_of_demo ) = $dbh->selectrow_array( "SELECT eid FROM employees WHERE nick = 'demo'", undef );
ok( $eid_of_demo > $REST->eid_of_root );

# attempt to change the EID
my $new_eid = 3400;
ok( $eid_of_demo != $new_eid );
test_sql_fail(qr/employees\.eid field is immutable/, <<"SQL");
UPDATE employees SET eid = $new_eid WHERE eid = $eid_of_demo
SQL


#======================
# schedules.sid field is immutable
# schedhistory.shid field is immutable
#======================

# insert a schedule
test_sql_success( 1, <<"SQL" );
INSERT INTO schedules (schedule, disabled) VALUES ( 'test schedule', 'f' )
SQL

# get the sid
my ( $sid ) = $dbh->selectrow_array( "SELECT sid FROM schedules WHERE schedule = 'test schedule'" );
ok( $sid >= 1 ); 

# attempt to change the sid
my $dast_sid = 3400;
ok( $dast_sid != $sid );
test_sql_fail( qr/schedules\.sid field is immutable/, <<"SQL" );
UPDATE schedules SET sid = $dast_sid WHERE sid = $sid
SQL

# insert a schedule history row
test_sql_success( 1, <<"SQL");
INSERT INTO schedhistory ( eid, sid, effective ) VALUES ( $eid_of_demo, $sid, '$today_ts' )
SQL

# get the shid
my ( $shid ) = $dbh->selectrow_array( 
    "SELECT shid FROM schedhistory WHERE eid=$eid_of_demo AND sid=$sid AND effective='" . $today_ts . "'" 
);
ok( $shid >= 1 ); 

# dastardly update
my $dast_shid = 3400;
ok( $dast_shid != $shid );
test_sql_fail( qr/schedhistory\.shid field is immutable/, <<"SQL" );
UPDATE schedhistory SET shid=$dast_shid WHERE shid=$shid
SQL

# delete the testing rows
test_sql_success( 1, <<"SQL" );
DELETE FROM schedhistory WHERE shid=$shid
SQL
test_sql_success( 1, <<"SQL" );
DELETE FROM schedules WHERE sid=$sid
SQL


#======================
# privhistory.phid field is immutable
#======================

# insert a testing privhistory row
test_sql_success( 1, <<"SQL" );
INSERT INTO privhistory (eid, priv, effective) VALUES ($eid_of_demo, 'admin', '$today_ts');
SQL

# get the phid
my ( $phid ) = $dbh->selectrow_array( 
    "SELECT phid FROM privhistory WHERE eid=$eid_of_demo AND priv='admin' AND effective='" . $today_ts . "'" 
);
ok( $phid >= 1 ); 

# attempt dastardly update
my $dast_phid = 3400;
ok( $dast_phid != $phid );
test_sql_fail( qr/privhistory\.phid field is immutable/, <<"SQL" );
UPDATE privhistory SET phid=$dast_phid WHERE phid=$phid
SQL

# delete testing row
test_sql_success( 1, <<"SQL" );
DELETE FROM privhistory WHERE phid=$phid
SQL


#======================
# activities.aid field is immutable
#======================

# get aid of 'WORK'
my ( $aid ) = $dbh->selectrow_array( 
    "SELECT aid FROM activities WHERE code='WORK'"
);
ok( $aid >= 1 ); 

# attempt dastardly update
my $dast_aid = 3400;
ok( $dast_aid != $aid );
test_sql_fail( qr/activities\.aid field is immutable/, <<"SQL" );
UPDATE activities SET aid=$dast_aid WHERE aid=$aid
SQL


#======================
# intervals.iid field is immutable
#======================

# insert a testing intervals row
test_sql_success( 1, <<"SQL" );
INSERT INTO intervals (eid, aid, intvl) VALUES ($eid_of_demo, $aid, '[ $today 08:00, $today 12:00 )');
SQL

# get the iid
my ( $count ) = $dbh->selectrow_array( 
    "SELECT count(*) FROM intervals WHERE eid=$eid_of_demo AND aid=$aid AND intvl && '[ $today 00:00, $today 24:00)'"
);
is( $count, 1 );
my ( $iid ) = $dbh->selectrow_array( 
    "SELECT iid FROM intervals WHERE eid=$eid_of_demo AND aid=$aid AND intvl && '[ $today 00:00, $today 24:00)'"
);
ok( $iid >= 1 ); 

# attempt dastardly update
my $dast_iid = 3400;
ok( $dast_iid != $iid );
test_sql_fail( qr/intervals\.iid field is immutable/, <<"SQL" );
UPDATE intervals SET iid=$dast_iid WHERE iid=$iid
SQL

# delete testing row
test_sql_success( 1, <<"SQL" );
DELETE FROM intervals WHERE iid=$iid
SQL


#======================
# locks.lid field is immutable
#======================

# insert a testing locks row
test_sql_success( 1, <<"SQL" );
INSERT INTO locks (eid, intvl) VALUES ($eid_of_demo, '[ $today 00:00, $today 24:00 )');
SQL

# get the lid
( $count ) = $dbh->selectrow_array( 
    "SELECT count(*) FROM locks WHERE eid=$eid_of_demo AND intvl = '[ $today 00:00, $today 24:00)'"
);
is( $count, 1 );
my ( $lid ) = $dbh->selectrow_array( 
    "SELECT lid FROM locks WHERE eid=$eid_of_demo AND intvl = '[ $today 00:00, $today 24:00)'"
);
ok( $lid >= 1 ); 

# attempt dastardly update
my $dast_lid = 3400;
ok( $dast_lid != $lid );
test_sql_fail( qr/locks\.lid field is immutable/, <<"SQL" );
UPDATE locks SET lid=$dast_lid WHERE lid=$lid
SQL

# delete testing row
test_sql_success( 1, <<"SQL" );
DELETE FROM locks WHERE lid=$lid
SQL


# 
done_testing;
