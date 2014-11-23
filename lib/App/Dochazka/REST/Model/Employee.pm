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
use App::Dochazka::REST::dbh qw( $dbh );
use App::Dochazka::REST::LDAP;
use App::Dochazka::REST::Model::Shared qw( load cud priv_by_eid schedule_by_eid noof );
use Carp;
use Data::Dumper;
use DBI qw(:sql_types);
use Params::Validate qw( :all );
use Try::Tiny;

# we get 'spawn', 'reset', and accessors from parent
use parent 'App::Dochazka::Model::Employee';



=head1 NAME

App::Dochazka::REST::Model::Employee - Employee data model




=head1 VERSION

Version 0.300

=cut

our $VERSION = '0.300';




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
        nick      varchar(32) UNIQUE,
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


=head3 fullname, email

Dochazka does not maintain any history of changes to the C<employees> table. 

The C<full_name> and C<email> fields must also be unique if they have a
value. Dochazka does not check if the email address is valid. 

#
# FIXME: NOT IMPLEMENTED depending on how C<App::Dochazka::REST> is configured,
# these fields may be read-only for employees (changeable by admins only), or
# the employee may be allowed to maintain their own information.


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

=item * basic accessors (L<eid>, L<fullname>, L<nick>, L<email>,
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


=head2 priv

Accessor method. Wrapper for App::Dochazka::REST::Model::Shared::priv_by_eid
N.B.: for this method to work, the 'eid' attribute must be populated

=cut

sub priv {
    my $self = shift;
    my ( $timestamp ) = validate_pos( @_, { type => SCALAR, optional => 1 } );
    $timestamp 
        ? priv_by_eid( $self->eid, $timestamp )
        : priv_by_eid( $self->eid );
}


=head2 schedule

Accessor method. Wrapper for App::Dochazka::REST::Model::Shared::schedule_by_eid
N.B.: for this method to work, the 'eid' attribute must be populated

=cut

sub schedule {
    my $self = shift;
    my ( $timestamp ) = validate_pos( @_, { type => SCALAR, optional => 1 } );
    $timestamp 
        ? schedule_by_eid( $self->eid, $timestamp )
        : schedule_by_eid( $self->eid );
}


=head2 insert

Instance method. Takes the object, as it is, and attempts to insert it into
the database. On success, overwrites object attributes with field values
actually inserted. Returns a status object.

=cut

sub insert {
    my ( $self ) = @_;
    my $status = cud(
        object => $self,
        sql => $site->SQL_EMPLOYEE_INSERT,
        attrs => [ 'fullname', 'nick', 'email', 'passhash', 'salt', 'remark' ],
    );
    return $status->ok
        ? $CELL->status_ok( 'DISPATCH_EMPLOYEE_INSERT_OK', args => [ $self->nick, $self->eid ],
              payload => $status->payload )
        : $status;
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
    my ( $self ) = @_;

    # eid _MUST_ be defined
    return $CELL->status_err( "No EID in object, yet EID needed for UPDATE operation" )
        unless $self->{'eid'};
    my $status = cud(
        object => $self,
        sql => $site->SQL_EMPLOYEE_UPDATE_BY_EID,
        attrs => [ 'fullname', 'nick', 'email', 'passhash', 'salt', 'remark', 'eid' ],
    );
    return $status unless $status->ok;
    return $CELL->status_err( "UPDATE failed (no payload) for unknown reason" ) unless $status->payload;
    $CELL->status_ok( 'DISPATCH_EMPLOYEE_UPDATE_OK', args => [ $self->nick, $self->eid ],
        payload => $status->payload )
}


=head2 delete

Instance method. Assuming the EID really corresponds to the employee to be
deleted, this method will execute the DELETE statement in the database. It
won't succeed if there are any records anywhere in the database that point
to this EID. Returns a status object.

=cut

sub delete {
    my ( $self ) = @_; 

    my $status = cud(
        object => $self,
        sql => $site->SQL_EMPLOYEE_DELETE,
        attrs => [ 'eid' ],
    );
    #$self->reset( eid => $self->eid ) if $status->ok;
    return $status->ok
        ? $CELL->status_ok( 'DISPATCH_EMPLOYEE_DELETE_OK', args => [ $self->nick, $self->eid ] )
        : $status;
}



=head2 load_by_eid

Analogous method to L<App::Dochazka::REST::Model::Activity/"load_by_aid">.

=cut

sub load_by_eid {
    # get and check parameters
    my $self = shift;
    die "Not a method call" unless $self->isa( __PACKAGE__ );
    my ( $eid ) = validate_pos( @_, { type => SCALAR } );
    $log->debug( "Entering " . __PACKAGE__ . "::load_by_eid with argument $eid" );

    return load( 
        class => __PACKAGE__, 
        sql => $site->SQL_EMPLOYEE_SELECT_BY_EID,
        keys => [ $eid ],
    );
}


=head2 load_by_nick

Analogous method to L<App::Dochazka::REST::Model::Activity/"load_by_aid">.

=cut

sub load_by_nick {
    # get and check parameters
    my $self = shift;
    die "Not a method call" unless $self->isa( __PACKAGE__ );
    my ( $nick ) = validate_pos( @_, { type => SCALAR } );
    $log->debug( "Entering " . __PACKAGE__ . "::load_by_nick with argument $nick" );

    return load( 
        class => __PACKAGE__, 
        sql => $site->SQL_EMPLOYEE_SELECT_BY_NICK,
        keys => [ $nick ], 
    );
}




=head1 FUNCTIONS

The following functions are not object methods.


=head2 select_multiple_by_nick

Class method. Select multiple employees by nick. Returns a status object.
If records are found, they will be in the payload (reference to an array of
expurgated employee objects).

=cut

sub select_multiple_by_nick {
    my $class = shift;
    # sk means "search key"
    my ( $sk ) = validate_pos( @_, { type => SCALAR, default => '%' } );

    my $status = {};
    my $sql = $site->SQL_EMPLOYEE_SELECT_MULTIPLE_BY_NICK;

    $dbh->{RaiseError} = 1;
    try {
        local $SIG{__WARN__} = sub {
                die @_;
            };
        my $sth = $dbh->prepare( $sql );
        $sth->execute( $sk );
        $log->debug( "SQL statement executed with search key ->$sk<-" );
        my $result = []; 
        my $counter = 0;
        while( defined( my $tmpres = $sth->fetchrow_hashref() ) ) { 
            $counter += 1;
            my $emp = __PACKAGE__->spawn;
            $emp->reset( %$tmpres );
            push @$result, $emp;
            #$log->info( Dumper( $result ) );
        }   
        $log->debug( "$counter records fetched" );
        #$log->info( Dumper( $result ) );
        if ( $counter > 0 ) { 
            $status = $CELL->status_ok( 'DISPATCH_RECORDS_FOUND',
                args => [ $counter ], payload => { 'result_set' => $result , 
                count => $counter, search_key => $sk } );
        } else {
            $status = $CELL->status_notice( 'DISPATCH_NO_RECORDS_FOUND', 
                payload => { 'result_set' => [], count => $counter, 
                search_key => $sk } );
        }   
    } catch {
        $status => $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ], payload => undef );  
    };  
    $dbh->{RaiseError} = 0;

    $log->debug( Dumper( $status ) );
    return $status;
}



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


=head2 noof

Get number of employees. Argument can be one of the following:

    total admin active inactive passerby

=cut

sub noof_employees_by_priv {
    my ( $priv ) = @_;
    die "Problem with arguments" unless defined $priv;

    if ( $priv eq 'total' ) {
        my $count = noof( 'employees' );
        return $CELL->status_ok( 
            'DISPATCH_COUNT_EMPLOYEES', 
            args => [ $count, $priv ], 
            payload => { count => $count } );
    }

    # if $priv is not one of the "kosher" privlevels, return 'OK' status
    # with code DISPATCH_NO_RECORDS_FOUND to Resource.pm, which triggers a
    # 404
    return $CELL->status_ok( 'DISPATCH_NO_RECORDS_FOUND' ) unless 
        grep { $priv eq $_; } qw( admin active inactive passerby );

    my $sql = $site->SQL_EMPLOYEE_COUNT_BY_PRIV_LEVEL;
    my ( $count ) = $dbh->selectrow_array( $sql, undef, $priv );
    $CELL->status_ok( 'DISPATCH_COUNT_EMPLOYEES', args => [ $count, $priv ], 
        payload => { 'priv' => $priv, 'count' => $count } );
}


=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

