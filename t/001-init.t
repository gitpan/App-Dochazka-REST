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
use Test::More;

#use App::CELL::Test::LogToFile;
use App::CELL qw( $log $meta $site );
use App::Dochazka::REST;
use Carp;

# initialize but do not connect to database
my $status = App::Dochazka::REST->init_no_db( sitedir => '/etc/dochazka-rest' );
if ( $status->not_ok ) {
    diag( $status->text );
    plan skip_all => "Not configured. Please run the test suite manually after initial site configuration";
}

# connect to postgres database
#$status = App::Dochazka::REST->connect_db_pristine( 
#    dbname => 'postgres',
#    dbuser => $site->DBINIT_CONNECT_USER,
#    dbpass => $site->DBINIT_CONNECT_AUTH,
#);
# die if this doesn't succeed -- no point in continuing
#croak( $status->code . " " . $status->text ) unless $status->ok;

# drop dochazka database if it exists, re-create it
#diag( "reset_db" );
$status = App::Dochazka::REST->reset_db( $site->DOCHAZKA_DBNAME );
diag( "Status: " . $status->code . ' ' . $status->text ) if $status->not_ok;
ok( $status->ok, "Database dropped and re-created" );

# connect to pristine dochazka database
#diag( "connect_db_pristine" );
$status = App::Dochazka::REST->connect_db_pristine( 
    dbname => $site->DOCHAZKA_DBNAME,
    dbuser => $site->DOCHAZKA_DBUSER,
    dbpass => $site->DOCHAZKA_DBPASS,
);
if ( $status->not_ok ) {
    diag( $status->code . ' ' . $status->text );
    BAIL_OUT("Aborting test: could not connect to database");
}
ok( $status->ok, "Now connected to dochazka testing database for initialization" );
my $dbh = $status->payload;
ok( $dbh->ping );

# create tables, triggers, stored procedures, etc.
#diag( "create_tables" );
$status = App::Dochazka::REST->create_tables( $dbh );
diag( "Status: " . $status->code . ' ' . $status->text ) if $status->not_ok;
ok( $status->ok, "Tables created OK" );

# disconnect from db
$dbh->disconnect or die $dbh->errstr;

# reconnect to initialized db (as in production)
#diag( "init" );
my $REST = App::Dochazka::REST->init;
diag( "Status: " . $status->code . ' ' . $status->text ) if $status->not_ok;
ok( $status->ok, "Now connected to dochazka testing database for 'production'" );
ok( $REST->dbh->ping );

# check that 'connect_db' initialized DOCHAZKA_EID_OF_ROOT parameter
my $eid_of_root = $site->DOCHAZKA_EID_OF_ROOT;
#diag( "eid_of_root == $eid_of_root" );
ok( $eid_of_root > 0, "EID of root is $eid_of_root" );

done_testing;
