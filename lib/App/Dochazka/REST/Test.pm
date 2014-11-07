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
use Data::Dumper;
use HTTP::Request;
use JSON;
use Test::JSON;
use Test::More;



=head1 NAME

App::Dochazka::REST::Test - Test helper functions





=head1 VERSION

Version 0.253

=cut

our $VERSION = '0.253';





=head1 DESCRIPTION

This module provides helper code for unit tests.

=cut




=head1 EXPORTS

=cut

use Exporter qw( import );
our @EXPORT = qw( req_demo req_active req_root req_json_demo req_json_active req_json_root req_html 
req_bad_creds status_from_json docu_check 
create_testing_employee create_active_employee delete_testing_employee delete_active_employee
create_testing_activity delete_testing_activity
create_testing_schedule delete_testing_schedule );




=head1 FUNCTIONS

=cut

sub _basic_request {
    my ( $auth_header, $args ) = @_;
    my $r = HTTP::Request->new( @$args );
    $r->header( 'Authorization' => "Basic $auth_header" );
    $r->header( 'Accept' => 'application/json' );
    return $r;
}

=head2 req_demo

Construct an HTTP request as 'demo' (passerby priv)

=cut

sub req_demo {
    my @args = @_;
    my $r = _basic_request( 'ZGVtbzpkZW1v', \@args );
    return $r;
}


=head2 req_json_demo

Construct an HTTP request for JSON as 'demo' (passerby priv)

=cut

sub req_json_demo {
    my @args = @_;
    my $r = _basic_request( 'ZGVtbzpkZW1v', \@args );
    $r->header( 'Content-Type' => 'application/json' );  # necessary for POST to work
    return $r;
}


=head2 req_active

Construct an HTTP request as 'active' (passerby priv)

=cut

sub req_active {
    my @args = @_;
    my $r = _basic_request( 'YWN0aXZlOmFjdGl2ZQ==', \@args );
    return $r;
}


=head2 req_json_active

Construct an HTTP request for JSON as 'active' (passerby priv)

=cut

sub req_json_active {
    my @args = @_;
    my $r = _basic_request( 'YWN0aXZlOmFjdGl2ZQ==', \@args );
    $r->header( 'Content-Type' => 'application/json' );  # necessary for POST to work
    return $r;
}


=head2 req_root

Construct an HTTP request as 'root' (admin priv)

=cut

sub req_root {
    my @args = @_;
    my $r = _basic_request( 'cm9vdDppbW11dGFibGU=', \@args );
    return $r;
}


=head2 req_json_root

Construct an HTTP request for JSON as 'demo' (passerby priv)

=cut

sub req_json_root {
    my @args = @_;
    my $r = _basic_request( 'cm9vdDppbW11dGFibGU=', \@args );
    $r->header( 'Content-Type' => 'application/json' );  # necessary for POST to work
    return $r;
}


=head2 req_html

Construct an HTTP request for HTML as 'demo' (passerby priv)

=cut

sub req_html {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic ZGVtbzpkZW1v' );
    $r->header( 'Accept' => 'text/html' );
    return $r;
}


=head2 req_bad_creds

Construct an HTTP request with improper credentials

=cut

sub req_bad_creds {
    my @args = @_;
    my $r = HTTP::Request->new( @args );
    $r->header( 'Authorization' => 'Basic ZGVtbzpibGJvc3Q=' );
    return $r;
}


=head2 status_from_json

Given a JSON string, check if it is valid JSON, blindly convert it into a
Perl hashref, bless it into 'App::CELL::Status', and send it back to caller

=cut

sub status_from_json {
    my ( $json ) = @_;
    bless from_json( $json ), 'App::CELL::Status';
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
    my $res = $test->request( req_json_demo POST  => '/docu', undef, '"'.  $resource . '"' );
    is( $res->code, 200, $tn . ++$t );
    is_valid_json( $res->content, $tn . ++$t );
    my $status = status_from_json( $res->content );
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
    $res = $test->request( req_json_demo POST  => '/docu/html', undef, '"'.  $resource . '"' );
    is( $res->code, 200, $tn . ++$t );
    is_valid_json( $res->content, $tn . ++$t );
    $status = status_from_json( $res->content );
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
        BAIL_OUT( $status->code . " " . $status->text );
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
    my $res = $test->request( req_json_root PUT => "priv/history/eid/$eid_of_active", undef,
        '{ "effective":"1000-01-01", "priv":"active" }' );
    is( $res->code, 200, "Create active employee 1" );
    my $status = status_from_json( $res->content );
    ok( $status->ok, "Create active employee 2" );
    is( $status->code, 'DOCHAZKA_CUD_OK', "Create active employee 3" );
}


=head2 delete_testing_employee

Tests will need to set up and tear down testing employees

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


=head2 delete_active_employee

Delete testing employee with 'active' privilege

=cut

sub delete_active_employee {
    my ( $test ) = @_;
    my ( $res, $status, $ph );

    # get privhistory of 'active'
    $status = get_privhistory( nick => 'active' );
    ok( $status->ok, "Delete active employee 0" );
    $ph = $status->payload->{'history'};

    # delete the privhistory records one by one
    foreach my $phrec ( @$ph ) {
        my $phid = $phrec->{phid};
        $res = $test->request( req_json_root DELETE => "priv/history/phid/$phid" );
        is( $res->code, 200, "Delete active employee 1" );
        $status = status_from_json( $res->content );
        ok( $status->ok, "Delete active employee 2" );
        is( $status->code, 'DOCHAZKA_CUD_OK', "Delete active employee 3" );
    }

    # delete the employee record
    $res = $test->request( req_json_root DELETE => "employee/nick/active" );
    is( $res->code, 200, "Delete active employee 4" );
    $status = status_from_json( $res->content );
    BAIL_OUT($status->text) unless $status->ok;
    ok( $status->ok, "Delete active employee 5" );
    is( $status->code, 'DISPATCH_EMPLOYEE_DELETE_OK', "Delete active employee 6" );

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

    my $intvls = [
        "[2000-01-02 12:30, 2000-01-02 16:30)",
        "[2000-01-02 08:00, 2000-01-02 12:00)",
        "[2000-01-01 12:30, 2000-01-01 16:30)",
        "[2000-01-01 08:00, 2000-01-01 12:00)",
        "[1999-12-31 12:30, 1999-12-31 16:30)",
        "[1999-12-31 08:00, 1999-12-31 12:00)",
    ];
    my $intvls_json = JSON->new->utf8->canonical(1)->encode( $intvls );
    #
    # - request as root 
    my $res = $test->request( req_json_root POST => "schedule/intervals", undef, $intvls_json );
    is( $res->code, 200 );
    is_valid_json( $res->content );
    my $status = status_from_json( $res->content );
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
    my $sched = $status->payload;
    $status = $sched->delete;
    is( $status->level, 'OK', 'delete_testing_schedule 2' );
    return;
}


1;
