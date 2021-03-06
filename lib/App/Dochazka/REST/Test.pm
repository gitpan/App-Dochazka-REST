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

# ------------------------
# Test helper functions module
# ------------------------

package App::Dochazka::REST::Test;

use strict;
use warnings;

use App::CELL qw( $CELL $meta $site );
use App::Dochazka::REST::ConnBank qw( $dbix_conn conn_status );
use App::Dochazka::REST::Dispatch::Employee qw( hash_the_password );
use App::Dochazka::REST::Model::Privhistory qw( get_privhistory );
use App::Dochazka::REST::Model::Schedhistory qw( get_schedhistory );
use App::Dochazka::REST::Model::Shared qw( select_single );
use Authen::Passphrase::SaltedDigest;
use Data::Dumper;
use HTTP::Request::Common qw( GET PUT POST DELETE );
use JSON;
use Params::Validate qw( :all );
use Test::JSON;
use Test::More;
use Try::Tiny;



=head1 NAME

App::Dochazka::REST::Test - Test helper functions





=head1 VERSION

Version 0.352

=cut

our $VERSION = '0.352';





=head1 DESCRIPTION

This module provides helper code for unit tests.

=cut




=head1 EXPORTS

=cut

use Exporter qw( import );
our @EXPORT = qw( 
    initialize_unit $faux_context
    req dbi_err docu_check 
    create_testing_employee create_active_employee create_inactive_employee
    delete_testing_employee delete_employee_by_nick
    create_testing_activity delete_testing_activity
    create_testing_schedule delete_testing_schedule 
    gen_activity gen_employee gen_interval gen_lock
    gen_privhistory gen_schedhistory gen_schedule
    test_sql_success test_sql_failure do_select_single
);




=head1 PACKAGE VARIABLES

=cut

# faux context
our $faux_context;

# dispatch table with references to HTTP::Request::Common functions
my %methods = ( 
    GET => \&GET,
    PUT => \&PUT,
    POST => \&POST,
    DELETE => \&DELETE,
);




=head1 FUNCTIONS

=cut


=head2 initialize_unit

Perform the boilerplate tasks that have to be done at the beginning of every unit
that accesses the REST server and/or the database.

=cut

sub initialize_unit {

    require App::Dochazka::REST;

    my $status = App::Dochazka::REST->init( sitedir => '/etc/dochazka-rest', verbose => 1, debug_mode => 1 );
    return $status unless $status->ok;

    is( $status->level, 'OK' );
    ok( $site->DOCHAZKA_EID_OF_ROOT );
    ok( $site->DOCHAZKA_EID_OF_DEMO );

    $faux_context = { 'dbix_conn' => $dbix_conn, 'current' => { 'eid' => 1 } };
    $meta->set( 'META_DOCHAZKA_UNIT_TESTING' => 1 );

    # get database handle and ping the database just to be sure
    my $rc = conn_status();
    is( $rc, "UP", "PostgreSQL database is alive" );

    return $status;
}


=head2 status_from_json

L<App::Dochazka::REST> is designed to return status objects in the HTTP
response body. These, of course, are sent in JSON format. This simple routine
takes a JSON string and blesses it, thereby converting it back into a status
object.

FIXME: There may be some encoding issues here!

=cut

sub status_from_json {
    my ( $json ) = @_;
    bless from_json( $json ), 'App::CELL::Status';
}


=head2 req

Assemble and process a HTTP request. Takes the following positional arguments:

    * Plack::Test object
    * expected HTTP result code
    * user to authenticate with (can be 'root', 'demo', or 'active')
    * HTTP method
    * resource string
    * optional JSON string

If the HTTP result code is 200, the return value will be a status object, undef
otherwise.

=cut

sub req {
    my ( $test, $code, $user, $method, $resource, $json ) = validate_pos( @_, 1, 1, 1, 1, 1, 0 );

    if ( ref( $test ) ne 'Plack::Test::MockHTTP' ) {
        diag( "Plack::Test::MockHTTP object not passed to 'req' from " . (caller)[1] . " line " . (caller)[2] );
        BAIL_OUT(0);
    }

    # assemble request
    my %pl = (
        Accept => 'application/json',
        Content_Type => 'application/json',
    );
    if ( $json ) {
        $pl{'Content'} = $json;
    } 
    my $r = $methods{$method}->( $resource, %pl ); 

    my $pass;
    if ( $user eq 'root' ) {
        $pass = 'immutable';
    } elsif ( $user eq 'inactive' ) {
        $pass = 'inactive';
    } elsif ( $user eq 'active' ) {
        $pass = 'active';
    } elsif ( $user eq 'demo' ) {
        $pass = 'demo';
    } else {
        #diag( "Unusual user $user - trying password $user" );
        $pass = $user;
    }

    $r->authorization_basic( $user, $pass );

    my $res = $test->request( $r );
    is( $res->code, $code, "$method $resource as $user " . ( $json ? "with $json" : "" ) . " 1" );
    $code += 0;
    return unless $code == 200;
    is_valid_json( $res->content, "$method $resource as $user " . ( $json ? "with $json" : "" ) . " 2" );
    return status_from_json( $res->content );
}


=head2 dbi_err

Wrapper for 'req' intended to eliminate duplicated code on tests that are
expected to return DOCHAZKA_DBI_ERR. In addition to the arguments expected
by 'req', takes one additional argument, which should be:

    qr/error message subtext/

(i.e. a regex quote by which to test the $status->text)

=cut

sub dbi_err {
    my ( $test, $code, $user, $method, $resource, $json, $qr ) = validate_pos( @_, 1, 1, 1, 1, 1, 1, 1 );
    my $status = req( $test, $code, $user, $method, $resource, $json );
    is( $status->level, 'ERR' );
    is( $status->code, 'DOCHAZKA_DBI_ERR' );
    if ( ! ( $status->text =~ $qr ) ) {
        diag( "$user $method $resource\n$json" );
        diag( $status->text . " does not match $qr" );
        BAIL_OUT(0);
    }
    like( $status->text, $qr );
}


=head2 docu_check

Check that the resource has on-line documentation (takes Plack::Test object
and resource name without quotes)

=cut

sub docu_check {
    my ( $test, $resource ) = @_;

    #diag( "Entering " . __PACKAGE__ . "::docu_check with argument $resource" );

    if ( ref( $test ) ne 'Plack::Test::MockHTTP' ) {
        diag( "Plack::Test::MockHTTP object not passed to 'req' from " . (caller)[1] . " line " . (caller)[2] );
        BAIL_OUT(0);
    }

    my $tn = "docu_check $resource ";
    my $t = 0;
    my ( $docustr, $docustr_len );
    #
    # - straight 'docu' resource
    my $status = req( $test, 200, 'demo', 'POST', '/docu', <<"EOH" );
{ "resource" : "$resource" }
EOH
    is( $status->level, 'OK', $tn . ++$t );
    is( $status->code, 'DISPATCH_ONLINE_DOCUMENTATION', $tn . ++$t );
    if ( exists $status->{'payload'} ) {
        ok( exists $status->payload->{'resource'}, $tn . ++$t );
        is( $status->payload->{'resource'}, $resource, $tn . ++$t );
        ok( exists $status->payload->{'documentation'}, $tn . ++$t );
        $docustr = $status->payload->{'documentation'};
        $docustr_len = length( $docustr );
        ok( $docustr_len > 10, $tn . ++$t );
        isnt( $docustr, 'NOT WRITTEN YET', $tn . ++$t );
    }
    #
    # - not a very thorough examination of the 'docu/html' version
    $status = req( $test, 200, 'demo', 'POST', '/docu/html', <<"EOH" );
{ "resource" : "$resource" }
EOH
    is( $status->level, 'OK', $tn . ++$t );
    is( $status->code, 'DISPATCH_ONLINE_DOCUMENTATION', $tn . ++$t );
    if ( exists $status->{'payload'} ) {
        ok( exists $status->payload->{'resource'}, $tn . ++$t );
        is( $status->payload->{'resource'}, $resource, $tn . ++$t );
        ok( exists $status->payload->{'documentation'}, $tn . ++$t );
        $docustr = $status->payload->{'documentation'};
        $docustr_len = length( $docustr );
        ok( $docustr_len > 10, $tn . ++$t );
        isnt( $docustr, 'NOT WRITTEN YET', $tn . ++$t );
    }
}


=head2 create_testing_employee

Tests will need to set up and tear down testing employees

=cut

sub create_testing_employee {
    my ( $PROPS ) = validate_pos( @_,
        { type => HASHREF },
    );

    hash_the_password( $PROPS );

    my $emp = App::Dochazka::REST::Model::Employee->spawn( $PROPS );
    is( ref($emp), 'App::Dochazka::REST::Model::Employee', 'create_testing_employee 1' );

    my $status = $emp->insert( $faux_context );
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }

    is( $status->level, "OK", 'create_testing_employee 2' );
    is( ref( $status->payload ), 'App::Dochazka::REST::Model::Employee' );
    return $status->payload;
}


=head2 create_active_employee

Create testing employee with 'active' privilege

=cut

sub create_active_employee {
    my ( $test ) = @_;
    my $eid_of_active = create_testing_employee( { nick => 'active', password => 'active' } )->{'eid'};
    my $status = req( $test, 200, 'root', 'POST', "priv/history/eid/$eid_of_active", 
        '{ "effective":"1000-01-01", "priv":"active" }' );
    ok( $status->ok, "Create active employee 2" );
    is( $status->code, 'DOCHAZKA_CUD_OK', "Create active employee 3" );
    return $eid_of_active;
}


=head2 create_inactive_employee

Create testing employee with 'active' privilege

=cut

sub create_inactive_employee {
    my ( $test ) = @_;
    my $eid_of_inactive = create_testing_employee( { nick => 'inactive', password => 'inactive' } )->{'eid'};
    my $status = req( $test, 200, 'root', 'POST', "priv/history/eid/$eid_of_inactive", 
        '{ "effective":"1000-01-01", "priv":"inactive" }' );
    ok( $status->ok, "Create inactive employee 2" );
    is( $status->code, 'DOCHAZKA_CUD_OK', "Create inactive employee 3" );
    return $eid_of_inactive;
}


=head2 delete_testing_employee

Tests will need to set up and tear down testing employees (takes EID)

=cut

sub delete_testing_employee {
    my $eid = shift;  
    my $status = App::Dochazka::REST::Model::Employee->load_by_eid( $dbix_conn, $eid );
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->level, 'OK', 'delete_testing_employee 1' );
    my $emp = $status->payload;
    $status = $emp->delete( $faux_context );
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->level, 'OK', 'delete_testing_employee 2' );
    return;
}


=head2 delete_employee_by_nick

Delete testing employee (takes Plack::Test object and nick)

=cut

sub delete_employee_by_nick {
    my ( $test, $nick ) = @_;
    my ( $res, $status );

    # get and delete privhistory
    $status = get_privhistory( $faux_context, nick => $nick );
    if ( $status->level eq 'OK' and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
        my $ph = $status->payload->{'history'};
        # delete the privhistory records one by one
        foreach my $phrec ( @$ph ) {
            my $phid = $phrec->{phid};
            $status = req( $test, 200, 'root', 'DELETE', "priv/history/phid/$phid" );
            ok( $status->ok, "Delete employee by nick 2" );
            is( $status->code, 'DOCHAZKA_CUD_OK', "Delete employee by nick 3" );
        }
    } else {
        diag( "Unexpected return value from get_privhistory: " . Dumper( $status ) );
        BAIL_OUT(0);
    }

    # get and delete schedhistory
    $status = get_schedhistory( $faux_context, nick => $nick );
    if ( $status->level eq 'OK' and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
        my $sh = $status->payload->{'history'};
        # delete the schedhistory records one by one
        foreach my $shrec ( @$sh ) {
            my $shid = $shrec->{shid};
            $status = req( $test, 200, 'root', 'DELETE', "schedule/history/shid/$shid" );
            ok( $status->ok, "Delete employee by nick 5" );
            is( $status->code, 'DOCHAZKA_CUD_OK', "Delete employee by nick 5" );
        }
    } elsif ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
        ok( 1, "$nick has no schedule history" );
    } else {
        diag( "Unexpected return value from get_schedhistory: " . Dumper( $status ) );
        BAIL_OUT(0);
    }

    # delete the employee record
    $status = req( $test, 200, 'root', 'DELETE', "employee/nick/$nick" );
    BAIL_OUT($status->text) unless $status->ok;
    is( $status->level, 'OK', "Delete employee by nick 6" );
    is( $status->code, 'DOCHAZKA_CUD_OK', "Delete employee by nick 7" );

    return;
}


=head2 create_testing_activity

Tests will need to set up and tear down testing activities

=cut

sub create_testing_activity {
    my %PROPS = @_;  # must be at least code

    my $act = App::Dochazka::REST::Model::Activity->spawn( \%PROPS );
    is( ref($act), 'App::Dochazka::REST::Model::Activity', 'create_testing_activity 1' );
    my $status = $act->insert( $faux_context );
    if ( $status->not_ok ) {
        BAIL_OUT( $status->code . " " . $status->text );
    }
    is( $status->level, "OK", 'create_testing_activity 2' );
    return $status->payload;
}


=head2 delete_testing_activity

Tests will need to set up and tear down testing activities

=cut

sub delete_testing_activity {
    my $aid = shift;

    my $status = App::Dochazka::REST::Model::Activity->load_by_aid( $dbix_conn, $aid );
    is( $status->level, 'OK', 'delete_testing_activity 1' );
    my $act = $status->payload;
    $status = $act->delete( $faux_context );
    is( $status->level, 'OK', 'delete_testing_activity 2' );
    return;
}


=head2 create_testing_schedule

Tests will need to set up and tear down testing schedules. Takes a Plack::Test
object as its only argument.

=cut

sub create_testing_schedule {
    my ( $test ) = @_;

    my $intvls = { "schedule" => [
        "[2000-01-02 12:30, 2000-01-02 16:30)",
        "[2000-01-02 08:00, 2000-01-02 12:00)",
        "[2000-01-01 12:30, 2000-01-01 16:30)",
        "[2000-01-01 08:00, 2000-01-01 12:00)",
        "[1999-12-31 12:30, 1999-12-31 16:30)",
        "[1999-12-31 08:00, 1999-12-31 12:00)",
    ] };
    my $intvls_json = JSON->new->utf8->canonical(1)->encode( $intvls );
    #
    # - request as root 
    my $status = req( $test, 200, 'root', 'POST', "schedule/new", $intvls_json );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_SCHEDULE_INSERT_OK' );
    ok( exists $status->{'payload'} );
    ok( exists $status->payload->{'sid'} );

    return $status->payload->{'sid'};
}


=head2 delete_testing_schedule

Tests will need to set up and tear down testing schedule. Takes a SID as its
only argument.

=cut

sub delete_testing_schedule {
    my ( $sid ) = @_;

    my $status = App::Dochazka::REST::Model::Schedule->load_by_sid( $dbix_conn, $sid );
    is( $status->level, 'OK', 'delete_testing_schedule 1' );
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    my $sched = $status->payload;
    $status = $sched->delete( $faux_context );
    is( $status->level, 'OK', 'delete_testing_schedule 2' );
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    return;
}


#
# functions to perform class-specific 'create' and 'retrieve' actions
#

sub gen_activity {
    my $dis = shift;
    my $code = 'FOOBAR';

    if ( $dis eq 'create' ) {

        # create 'FOOBAR' activity
        my $act = App::Dochazka::REST::Model::Activity->spawn( code => $code );
        my $status = $act->insert( $faux_context );
        if( $status->level ne 'OK' ) {
            diag( Dumper $status );
            BAIL_OUT(0);
        }
        is( $status->level, 'OK' );
        $act = $status->payload;
        is( $act->code, $code );
        ok( $act->aid > 5 );
        return $act;

    } elsif ( $dis eq 'retrieve' ) {

        my $status = App::Dochazka::REST::Model::Activity->load_by_code( $dbix_conn, $code );
        return $status;

    } elsif ( $dis eq 'delete' ) {

        my $status = App::Dochazka::REST::Model::Activity->load_by_code( $dbix_conn, $code );
        is( $status->level, 'OK' );
        my $act = $status->payload;
        $status = $act->delete( $faux_context );
        is( $status->level, 'OK' );
        return;
        
    }
    diag( "gen_activity: AAAAAAHHHHH@@@!! \$dis " . Dumper( $dis ) );
    BAIL_OUT(0);
}

sub gen_employee {
    my $dis = shift;
    my $nick = 'bubbaTheCat';

    if ( $dis eq 'create' ) {

        # create bubbaTheCat employee
        my $emp = App::Dochazka::REST::Model::Employee->spawn( nick => $nick );
        my $status = $emp->insert( $faux_context );
        is( $status->level, 'OK' );
        $emp = $status->payload;
        is( $emp->nick, $nick );
        ok( $emp->eid > 2 );  # root is 1, demo is 2
        return $emp;

    } elsif ( $dis eq 'retrieve' ) {

        my $status = App::Dochazka::REST::Model::Employee->load_by_nick( $dbix_conn, $nick );
        return $status;

    } elsif ( $dis eq 'delete' ) {

        my $status = App::Dochazka::REST::Model::Employee->load_by_nick( $dbix_conn, $nick );
        is( $status->level, 'OK' );
        my $emp = $status->payload;
        $status = $emp->delete( $faux_context );
        is( $status->level, 'OK' );
        return;
        
    }
    diag( "gen_employee: AAAAAAHHHHH@@@!! \$dis " . Dumper( $dis ) );
    BAIL_OUT(0);
}

sub gen_interval {
    my $dis = shift;
    if ( $dis eq 'create' ) {

    } elsif ( $dis eq 'retrieve' ) {

    }
    diag( "gen_interval: AAAAAAHHHHH@@@!! \$dis " . Dumper( $dis ) );
    BAIL_OUT(0);
}

sub gen_lock {
    my $dis = shift;
    if ( $dis eq 'create' ) {

    } elsif ( $dis eq 'retrieve' ) {

    } elsif ( $dis eq 'delete' ) {
    
    }
    diag( "gen_lock: AAAAAAHHHHH@@@!! \$dis " . Dumper( $dis ) );
    BAIL_OUT(0);
}

sub gen_privhistory {
    my $dis = shift;
    if ( $dis eq 'create' ) {

    } elsif ( $dis eq 'retrieve' ) {

    } elsif ( $dis eq 'delete' ) {
    
    }
    diag( "gen_privhistory: AAAAAAHHHHH@@@!! \$dis " . Dumper( $dis ) );
    BAIL_OUT(0);
}

sub gen_schedhistory {
    my $dis = shift;
    if ( $dis eq 'create' ) {

    } elsif ( $dis eq 'retrieve' ) {
    
    } elsif ( $dis eq 'delete' ) {
    
    }
    diag( "gen_schedhistory: AAAAAAHHHHH@@@!! \$dis " . Dumper( $dis ) );
    BAIL_OUT(0);
}

sub gen_schedule {
    my $dis = shift;
    if ( $dis eq 'create' ) {

    } elsif ( $dis eq 'retrieve' ) {

    } elsif ( $dis eq 'delete' ) {
    
    }
    diag( "gen_schedule: AAAAAAHHHHH@@@!! \$dis " . Dumper( $dis ) );
    BAIL_OUT(0);
}

sub test_sql_success {
    my ( $conn, $expected_rv, $sql ) = @_;
    my ( $rv, $errstr );
    try {
        $conn->run( fixup => sub {
            $rv = $_->do($sql);
        });
    } catch {
        $errstr = $_;
    };
    if ( $errstr ) {
        diag( "Unexpected error in test_sql_success: $errstr" );
        diag( "Called from " . (caller)[1] . " line " . (caller)[2] );
        BAIL_OUT(0);
    }
    is( $rv, $expected_rv, "successfully executed $sql" );
}

sub test_sql_failure {
    my ( $conn, $expected_err, $sql ) = @_;
    my ( $rv, $errstr );
    try {
        $conn->run( fixup => sub {
            $rv = $_->do($sql);
        });
    } catch {
        $errstr = $_;
    };
    is( $rv, undef, "DBI returned undef" );
    like( $errstr, $expected_err, "DBI errstr is as expected" );
}

sub do_select_single {
    my ( $conn, $sql, @keys ) = @_;
    #diag( "do_select_single: connection OK" ) if ref( $conn ) eq 'DBIx::Connector';
    #diag( "do_select_single: SQL statement is $sql" ) if $sql;
    #diag( "do_select_single: keys are ", join(', ', @keys) ) if @keys;
    my $status = select_single( conn => $conn, sql => $sql, keys => \@keys );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    ok( $status->payload );
    is( ref( $status->payload ), 'ARRAY' );
    return @{ $status->payload };
}
    
1;
