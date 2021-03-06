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

package App::Dochazka::REST::Model::Employee;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $CELL $log $meta $site );
use App::Dochazka::REST::LDAP;
use App::Dochazka::REST::Model::Shared qw( cud load load_multiple noof priv_by_eid schedule_by_eid select_single );
use Carp;
use Data::Dumper;
use DBI qw(:sql_types);
use Params::Validate qw( :all );
use Try::Tiny;

# send DBI warnings to the log
$SIG{__WARN__} = sub {
    $log->notice( $_[0] );
};

# we get 'spawn', 'reset', and accessors from parent
use parent 'App::Dochazka::Model::Employee';



=head1 NAME

App::Dochazka::REST::Model::Employee - Employee data model




=head1 VERSION

Version 0.352

=cut

our $VERSION = '0.352';




=head1 SYNOPSIS

Employee data model

    use App::Dochazka::REST::Model::Employee;

    ...



=head1 DESCRIPTION

A description of the employee data model follows.


=head2 Employees in the database

At the database level, C<App::Dochazka::REST> needs to be able to distinguish
one employee from another. This is accomplished by the EID. All the other
fields in the C<employees> table are optional. 

The C<employees> database table is defined as follows:

    CREATE TABLE employees (
        eid       serial PRIMARY KEY,
        nick      varchar(32) UNIQUE NOT NULL,
        sec_id    varchar(64) UNIQUE
        fullname  varchar(96) UNIQUE,
        email     text UNIQUE,
        passhash  text,
        salt      text,
        remark    text,
        stamp     json
    )


=head3 EID

The Employee ID (EID) is Dochazka's principal means of identifying an 
employee. At the site, employees will be known by other means, like their
full name, their username, their user ID, etc. But these can and will
change from time to time. The EID should never, ever change.


=head3 nick

The C<nick> field is intended to be used for storing the employee's username.
While storing each employee's username in the Dochazka database has undeniable
advantages, it is not required - how employees are identified is a matter of
site policy, and internally Dochazka does not use the nick to identify
employees. Should the nick field have a value, however, Dochazka requires that
it be unique.


=head3 sec_id

The secondary ID is an optional unique string identifying the employee.
This could be useful at sites where employees already have a nick (username)
and a numeric ID, for example, and the administrators need to have the 
ability to look up employees by their numeric ID.


=head3 fullname, email

Dochazka does not maintain any history of changes to the C<employees> table. 

The C<full_name> and C<email> fields must also be unique if they have a
value. Dochazka does not check if the email address is valid. 

Depending on how C<App::Dochazka::REST> is configured (see especially the
C<DOCHAZKA_PROFILE_EDITABLE_FIELDS> site parameter), these fields may be
read-only for employees (changeable by admins only), or the employee may be
allowed to maintain their own information.


=head3 passhash, salt

The passhash and salt fields are optional. See L</AUTHENTICATION> for
details.


=head3 remark, stamp

# FIXME



=head2 Employees in the Perl API

Individual employees are represented by "employee objects". All methods and
functions for manipulating these objects are contained in
L<App::Dochazka::REST::Model::Employee>. The most important methods are:

=over

=item * constructor (L<spawn>)

=item * basic accessors (L<eid>, L<sec_id>, L<nick>, L<fullname>, L<email>,
L<passhash>, L<salt>, L<remark>)

=item * L<priv> (privilege "accessor" - but privilege info is not stored in
the object)

=item * L<schedule> (schedule "accessor" - but schedule info is not stored
in the object)

=item * L<reset> (recycles an existing object by setting it to desired state)

=item * L<insert> (inserts object into database)

=item * L<update> (updates database to match the object)

=item * L<delete> (deletes record from database if nothing references it)

=item * L<load_by_eid> (loads a single employee into the object)

=item * L<load_by_nick> (loads a single employee into the object)

=back

L<App::Dochazka::REST::Model::Employee> also exports some convenience
functions:

=over

=item * L<nick_exists> (given a nick, return true/false)

=item * L<eid_exists> (given an EID, return true/false)

=item * L<noof_employees_by_priv> (given a priv level, return number of employees with that priv level)

=back

For basic C<employee> object workflow, see the unit tests in
C<t/004-employee.t>.



=head1 EXPORTS

This module provides the following exports:

=over 

=item L<nick_exists> - function

=item L<eid_exists> - function

=item L<noof_employees_by_priv> - function

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( nick_exists eid_exists noof_employees_by_priv );




=head1 METHODS

The following functions expect to be called as methods on an employee object.

The standard way to create an object containing an existing employee is to use
'load_by_eid' or 'load_by_nick':

    my $status = App::Dochazka::REST::Model::Employee->load_by_nick( 'georg' );
    return $status unless $status->ok;
    my $georg = $status->payload;
    $georg->remark( 'Likes to fly kites' );
    $status = $georg->update;
    return $status unless $status->ok;

... and the like. To insert a new employee, do something like this:

    my $friedrich = App::Dochazka::REST::Model::Employee->spawn( nick => 'friedrich' );
    my $status = $friedrich->insert;
    return $status unless $status->ok;

=head2 priv

Accessor method. Wrapper for App::Dochazka::REST::Model::Shared::priv_by_eid
N.B.: for this method to work, the 'eid' attribute must be populated

=cut

sub priv {
    my $self = shift;
    my ( $conn, $timestamp ) = validate_pos( @_,
       { isa => 'DBIx::Connector' },
       { type => SCALAR, optional => 1 },
    );
    my $return_value = ( $timestamp )
        ? priv_by_eid( $conn, $self->eid, $timestamp )
        : priv_by_eid( $conn, $self->eid );
    return if ref( $return_value );
    return $return_value;
}


=head2 schedule

Accessor method. Wrapper for App::Dochazka::REST::Model::Shared::schedule_by_eid
N.B.: for this method to work, the 'eid' attribute must be populated

=cut

sub schedule {
    my $self = shift;
    my ( $conn, $timestamp ) = validate_pos( @_,
       { isa => 'DBIx::Connector' },
       { type => SCALAR, optional => 1 },
    );
    my $return_value = ( $timestamp )
        ? schedule_by_eid( $conn, $self->eid, $timestamp )
        : schedule_by_eid( $conn, $self->eid );
    return if ref( $return_value );
    return $return_value;
}


=head2 insert

Instance method. Takes the object, as it is, and attempts to insert it into
the database. On success, overwrites object attributes with field values
actually inserted. Returns a status object.

=cut

sub insert {
    my $self = shift;
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    my $status = cud(
        conn => $context->{'dbix_conn'},
        eid => $context->{'current'}->{'eid'},
        object => $self,
        sql => $site->SQL_EMPLOYEE_INSERT,
        attrs => [ 'sec_id', 'nick', 'fullname', 'email', 'passhash', 'salt', 'remark' ],
    );
    return $status;
}


=head2 update

Instance method. Assuming that the object has been prepared, i.e. the EID
corresponds to the employee to be updated and the attributes have been
changed as desired, this function runs the actual UPDATE, hopefully
bringing the database into line with the object. Overwrites all the
object's attributes with the values actually written to the database.
Returns status object.

=cut

sub update {
    my $self = shift;
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    return $CELL->status_err( 'DOCHAZKA_MALFORMED_400' ) unless $self->{'eid'};

    my $status = cud(
        conn => $context->{'dbix_conn'},
        eid => $context->{'current'}->{'eid'},
        object => $self,
        sql => $site->SQL_EMPLOYEE_UPDATE_BY_EID,
        attrs => [ 'sec_id', 'nick', 'fullname', 'email', 'passhash', 'salt', 'remark', 'eid' ],
    );
    return $status;
}


=head2 delete

Instance method. Assuming the EID really corresponds to the employee to be
deleted, this method will execute the DELETE statement in the database. It
won't succeed if there are any records anywhere in the database that point
to this EID. Returns a status object.

=cut

sub delete {
    my $self = shift;
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    my $status = cud(
        conn => $context->{'dbix_conn'},
        eid => $context->{'current'}->{'eid'},
        object => $self,
        sql => $site->SQL_EMPLOYEE_DELETE,
        attrs => [ 'eid' ],
    );
    #$self->reset( eid => $self->eid ) if $status->ok;
    return $status;
}



=head2 load_by_eid

Analogous method to L<App::Dochazka::REST::Model::Activity/"load_by_aid">.

=cut

sub load_by_eid {
    my $self = shift;
    my ( $conn, $eid ) = validate_pos( @_, 
        { isa => 'DBIx::Connector' },
        { type => SCALAR },
    );
    $log->debug( "Entering " . __PACKAGE__ . "::load_by_eid with argument $eid" );

    return load( 
        conn => $conn,
        class => __PACKAGE__, 
        sql => $site->SQL_EMPLOYEE_SELECT_BY_EID,
        keys => [ $eid ],
    );
}


=head2 load_by_nick

Analogous method to L<App::Dochazka::REST::Model::Activity/"load_by_aid">.

=cut

sub load_by_nick {
    my $self = shift;
    my ( $conn, $nick ) = validate_pos( @_, 
        { isa => 'DBIx::Connector' },
        { type => SCALAR },
    );
    $log->debug( "Entering " . __PACKAGE__ . "::load_by_nick with argument $nick" );

    return load( 
        conn => $conn,
        class => __PACKAGE__, 
        sql => $site->SQL_EMPLOYEE_SELECT_BY_NICK,
        keys => [ $nick ], 
    );
}




=head1 FUNCTIONS

The following functions are not object methods.



=head1 EXPORTED FUNCTIONS

The following functions are exported and are not called as methods.


=head2 nick_exists

See C<exists> routine in L<App::Dochazka::REST::Model::Shared>


=head2 eid_exists

See C<exists> routine in L<App::Dochazka::REST::Model::Shared>

=cut

BEGIN {
    no strict 'refs';
    *{"eid_exists"} = App::Dochazka::REST::Model::Shared::make_test_exists( 'eid' );
    *{"nick_exists"} = App::Dochazka::REST::Model::Shared::make_test_exists( 'nick' );
}


=head2 noof_employees_by_priv

Get number of employees. Argument can be one of the following:

    total admin active inactive passerby

=cut

sub noof_employees_by_priv {
    my ( $conn, $priv ) = validate_pos( @_,
        { isa => 'DBIx::Connector' },
        { type => SCALAR },
    );

    if ( $priv eq 'total' ) {
        my $count = noof( $conn, 'employees' );
        return $CELL->status_ok( 
            'DISPATCH_COUNT_EMPLOYEES', 
            args => [ $count, $priv ], 
            payload => { count => $count } );
    }

    return $CELL->status_err( 'DOCHAZKA_NOT_FOUND_404' ) unless 
        $priv =~ m/^(passerby)|(inactive)|(active)|(admin)$/i;

    my $sql = $site->SQL_EMPLOYEE_COUNT_BY_PRIV_LEVEL;
    my ( $count ) = select_single( conn => $conn, sql => $sql, keys => [ $priv ] );
    $count += 0;
    $CELL->status_ok( 'DISPATCH_COUNT_EMPLOYEES', args => [ $count, $priv ], 
        payload => { 'priv' => $priv, 'count' => $count } );
}



=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

