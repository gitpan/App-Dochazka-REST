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

use App::CELL qw( $CELL );
use App::Dochazka::REST::Model::Privhistory qw( get_privhistory );
use App::Dochazka::REST::Model::Schedhistory qw( get_schedhistory );
use Data::Dumper;
use HTTP::Request::Common qw( GET PUT POST DELETE );
use JSON;
use Params::Validate;
use Test::JSON;
use Test::More;



=head1 NAME

App::Dochazka::REST::Test - Test helper functions





=head1 VERSION

Version 0.300

=cut

our $VERSION = '0.300';





=head1 DESCRIPTION

This module provides helper code for unit tests.

=cut




=head1 EXPORTS

=cut

use Exporter qw( import );
our @EXPORT = qw( 
    req dbi_err docu_check 
    create_testing_employee create_active_employee create_inactive_employee
    delete_testing_employee delete_employee_by_nick
    create_testing_activity delete_testing_activity
    create_testing_schedule delete_testing_schedule 
);




=head1 PACKAGE VARIABLES

=cut

# dispatch table with references to HTTP::Request::Common functions
my %methods = ( 
    GET => \&GET,
    PUT => \&PUT,
    POST => \&POST,
    DELETE => \&DELETE,
);




=head1 FUNCTIONS

=cut


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
    like( $status->text, $qr );
}


=head2 docu_check

Check that the resource has on-line documentation (takes Plack::Test object
and resource name without quotes)

=cut

sub docu_check {
    my ( $test, $resource ) = @_;
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
    my %PROPS = @_;  # must be at least nick

    my $emp = App::Dochazka::REST::Model::Employee->spawn( \%PROPS );
    is( ref($emp), 'App::Dochazka::REST::Model::Employee', 'create_testing_employee 1' );
    my $status = $emp->insert;
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->level, "OK", 'create_testing_employee 2' );
    return $status->payload;
}


=head2 create_active_employee

Create testing employee with 'active' privilege

=cut

sub create_active_employee {
    my ( $test ) = @_;
    my $eid_of_active = create_testing_employee( nick => 'active', passhash => 'active' )->{'eid'};
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
    my $eid_of_inactive = create_testing_employee( nick => 'inactive', passhash => 'inactive' )->{'eid'};
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
    my $status = App::Dochazka::REST::Model::Employee->load_by_eid( $eid );
    is( $status->level, 'OK', 'delete_testing_employee 1' );
    my $emp = $status->payload;
    $status = $emp->delete;
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
    $status = get_privhistory( nick => $nick );
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
    $status = get_schedhistory( nick => $nick );
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
    is( $status->code, 'DISPATCH_EMPLOYEE_DELETE_OK', "Delete employee by nick 7" );

    return;
}


=head2 create_testing_activity

Tests will need to set up and tear down testing activities

=cut

sub create_testing_activity {
    my %PROPS = @_;  # must be at least code

    my $act = App::Dochazka::REST::Model::Activity->spawn( \%PROPS );
    is( ref($act), 'App::Dochazka::REST::Model::Activity', 'create_testing_activity 1' );
    my $status = $act->insert;
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
    my $status = App::Dochazka::REST::Model::Activity->load_by_aid( $aid );
    is( $status->level, 'OK', 'delete_testing_activity 1' );
    my $act = $status->payload;
    $status = $act->delete;
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
    my $status = App::Dochazka::REST::Model::Schedule->load_by_sid( $sid );
    is( $status->level, 'OK', 'delete_testing_schedule 1' );
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    my $sched = $status->payload;
    $status = $sched->delete;
    is( $status->level, 'OK', 'delete_testing_schedule 2' );
    if ( $status->not_ok ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    return;
}


1;
