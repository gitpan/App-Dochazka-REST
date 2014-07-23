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
use Carp;
use Data::Dumper;
use App::Dochazka::REST::Model::Shared qw( cud priv_by_eid schedule_by_eid );
use DBI qw(:sql_types);




=head1 NAME

App::Dochazka::REST::Model::Employee - Employee data model




=head1 VERSION

Version 0.088

=cut

our $VERSION = '0.088';




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

=item * privilege accessor (L<priv>)

=item * schedule accessor (L<schedule>)

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

=item * L<eid_by_nick> (given a nick, returns EID)

=back

For basic C<employee> object workflow, see the unit tests in
C<t/004-employee.t>.



=head1 EXPORTS

This module provides the following exports:

=over 

=item L<eid_by_nick> - function

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( eid_by_nick );




=head1 METHODS


=head2 spawn

Employee constructor. Does not interact with the database directly, but stores
database handle for later use. Takes PARAMHASH with required parameters: 'dbh'
(database handle) and 'acleid' (EID of he employee initiating the request - for
ACL lookup only;  _not_ the EID of an employee to look up). All subsequent
operations will be carried out with the privileges of that employee, so be sure
to destroy the object when finished with it. Optional parameter: PARAMHASH
containing definitions of any of the attributes listed in the 'reset'
method.

=cut

BEGIN {
    no strict 'refs';
    *{"spawn"} = App::Dochazka::REST::Model::Shared::make_spawn();
}



=head2 reset

Instance method. Resets object, either to its primal state (no arguments)
or to the state given in PARAMHASH.

=cut

BEGIN {
    no strict 'refs';
    *{"reset"} = App::Dochazka::REST::Model::Shared::make_reset( 
        'eid', 'fullname', 'nick', 'email', 'passhash', 'salt', 'remark',
    );
}



=head2 Accessor methods

Basic accessor methods for all the fields of employees table. These
functions return whatever value happens to be associated with the object,
with no guarantee that it matches the database.

=cut

BEGIN {
    foreach my $subname ( 
        'eid', 'fullname', 'nick', 'email', 'passhash', 'salt', 'remark' 
    ) {
        no strict 'refs';
        *{"$subname"} = sub { 
            my ( $self ) = @_; 
            return $self->{$subname};
        }   
    }   
}


=head3 eid

Accessor method.

=head3 email

Accessor method.

=head3 fullname

Accessor method.

=head3 nick

Accessor method.

=head3 passhash

Accessor method.

=head3 salt

Accessor method.

=head3 remark

Accessor method.

=head3 priv

Accessor method. Wrapper for App::Dochazka::REST::Model::Shared::priv_by_eid
N.B.: for this method to work, the 'eid' attribute must be populated

=cut

sub priv {
    my ( $self, $timestamp ) = @_;
    return if ! $self->{eid};
    # no timestamp provided, return current_priv
    if ( ! $timestamp ) { 
        return priv_by_eid( $self->{dbh}, $self->{eid} );
    }
    # timestamp provided, return priv as of that timestamp
    return priv_by_eid( $self->{dbh}, $self->{eid}, $timestamp );
}


=head3 schedule

Accessor method. Wrapper for App::Dochazka::REST::Model::Shared::schedule_by_eid
N.B.: for this method to work, the 'eid' attribute must be populated

=cut

sub schedule {
    my ( $self, $timestamp ) = @_;
    return if ! $self->{eid};
    # no timestamp provided, return current_priv
    if ( ! $timestamp ) { 
        return schedule_by_eid( $self->{dbh}, $self->{eid} );
    }
    # timestamp provided, return priv as of that timestamp
    return schedule_by_eid( $self->{dbh}, $self->{eid}, $timestamp );
}


=head2 insert

Instance method. Takes the object, as it is, and attempts to insert it into
the database. On success, overwrites object attributes with field values
actually inserted. Returns a status object.

=cut

sub insert {
    my ( $self ) = @_;

    my $status = cud(
        $self,
        $site->SQL_EMPLOYEE_INSERT,
        ('fullname', 'nick', 'email', 'passhash', 'salt', 'remark'),
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
    my ( $self ) = @_;

    my $status = cud(
        $self,
        $site->SQL_EMPLOYEE_UPDATE,
        ('eid', 'fullname', 'nick', 'email', 'passhash', 'salt', 'remark'),
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
    my ( $self ) = @_; 

    my $status = cud(
        $self,
        $site->SQL_EMPLOYEE_DELETE,
        ( 'eid' ),
    );
    $self->reset( eid => $self->eid ) if $status->ok;

    return $status;
}



=head2 load_by_eid

Instance method. Loads employee from database, by EID, into existing
object, overwriting whatever was there before. The EID value given must be
an exact match. Returns a status object.

=cut

sub load_by_eid {
    my ( $self, $eid ) = @_;
    return $self->_load( eid => $eid );
}



=head2 load_by_nick

Instance method. Loads employee from database, by the nick provided in the
argument list, into existing object, overwriting whatever might have been
there before. The nick must be an exact match. Returns a status object.

=cut

sub load_by_nick {
    my ( $self, $nick ) = @_;
    return $self->_load( nick => $nick );
}


=head3 _load

Load employee, by eid or nick, into an existing object, overwriting
whatever was there before. The search key (eid or nick) must be an exact
match: this function returns only 1 or 0 records. Takes one of the two
following PARAMHASHes:

    dbh => $dbh, nick => $nick
    dbh => $dbh, eid => $eid

=cut

sub _load {
    my ( $self, %ARGS ) = @_;
    my $sql;
    my $dbh = $self->{dbh};
    $dbh->ping or die "No dbh";
    $self->reset; # reset object to primal state
    my ( $spec ) = keys %ARGS;

    # check ACL
    $self->{aclpriv} = priv_by_eid( $dbh, $self->{acleid} ) if not defined( $self->{aclpriv} );
    ACL: {
        last ACL if $self->{aclpriv} eq 'admin';
        last ACL if $self->{acleid} == $self->{eid} and ( 
                                $self->{aclpriv} eq 'inactive' or
                                $self->{aclpriv} eq 'active'
                                                        );
        return $CELL->status_err('DOCHAZKA_INSUFFICIENT_PRIV');
    }

    if ( $spec eq 'nick' ) {
        $sql = $site->SQL_EMPLOYEE_SELECT_BY_NICK;
    } else {
        $sql = $site->SQL_EMPLOYEE_SELECT_BY_EID;
    }

    # SELECT statement incantations
    # N.B. - the select can only return a single record
    my $newself = $dbh->selectrow_hashref( $sql, {}, $ARGS{$spec} );
    if ( defined( $newself ) ) {
        foreach my $key ( keys %{ $newself } ) {
            $self->{$key} = $newself->{$key};
        }
        return $CELL->status_ok('DOCHAZKA_RECORDS_FETCHED', args => [1] );
    } elsif ( ! defined( $dbh->err ) ) {
        # nothing found
        return $CELL->status_warn('DOCHAZKA_RECORDS_FETCHED', args => [0] );
    }
    # DBI error
    return $CELL->status_err( $dbh->errstr );
}


=head1 FUNCTIONS

The following functions are not object methods.


=head2 eid_by_nick

** NO ACL CHECK **
Given a database handle and a nick, attempt ot retrieve the
EID corresponding to the nick. Returns EID or undef on failure.

=cut

sub eid_by_nick {
    my ( $dbh, $nick ) = @_;
    croak "Must provide database handle and nick" 
        if ! defined($dbh) or ! defined( $nick );
    my $emp = __PACKAGE__->spawn(
        dbh => $dbh,
        acleid => $site->DOCHAZKA_EID_OF_ROOT,
    );
    my $status = $emp->load_by_nick( $nick );
    return $emp->{eid} if $status->ok;
    return;
}




=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

