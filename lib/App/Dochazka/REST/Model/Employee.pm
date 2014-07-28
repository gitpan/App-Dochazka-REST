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
use App::Dochazka::REST::Model::Shared qw( cud priv_by_eid schedule_by_eid );
use Carp;
use Data::Dumper;
use Data::Structure::Util qw( unbless );
use DBI qw(:sql_types);
use Scalar::Util qw( blessed );
use Storable qw( dclone );
use Try::Tiny;

use parent 'App::Dochazka::REST::dbh';




=head1 NAME

App::Dochazka::REST::Model::Employee - Employee data model




=head1 VERSION

Version 0.109

=cut

our $VERSION = '0.109';




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
database handle for later use. Takes PARAMHASH with required parameter 'dbh'
(database handle). Optional parameter: PARAMHASH containing definitions of
any of the attributes listed in the 'reset' method.

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
        'priv', 'schedule'
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
        return priv_by_eid( $self->dbh, $self->{eid} );
    }
    # timestamp provided, return priv as of that timestamp
    return priv_by_eid( $self->dbh, $self->{eid}, $timestamp );
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
        return schedule_by_eid( $self->dbh, $self->{eid} );
    }
    # timestamp provided, return priv as of that timestamp
    return schedule_by_eid( $self->dbh, $self->{eid}, $timestamp );
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



=head2 load_by_nick

Attempts to load employee from database, by the nick provided in the
argument list, which must be an exact match. If the employee is found,
it is loaded into a temporary hash. If called as a class method, an
employee object is spawned from the values in the temporary hash. If
called on an existing object, overwrites whatever might have been there
before. 

Returns a status object. On success, the object will be in the payload.

=cut

sub load_by_nick {
    my ( $self, $nick ) = @_;
    my $status = _load( nick => $nick );
    return $status unless $status->code eq 'DISPATCH_RECORDS_FOUND';

    # record was found and is in the payload
    if ( ref $self ) { # class method
        $self->reset( %{ $status->payload } );
        $status->payload( $self );
    } else {             # instance method
        my $newobj = __PACKAGE__->spawn( %{ $status->payload } );
        $status->payload( $newobj );
    }
    return $status;
}


=head2 load_by_eid

Analogous method to L<"load_by_nick">.

=cut

sub load_by_eid {
    my ( $self, $eid ) = @_;
    my $status = _load( eid => $eid );
    return $status unless $status->code eq 'DISPATCH_RECORDS_FOUND';

    # record was found and is in the payload
    if ( ref $self ) { # instance method
        $self->reset( %{ $status->payload } );
        $status->payload( $self );
    } else {           # class method
        my $newobj = __PACKAGE__->spawn( %{ $status->payload } );
        $status->payload( $newobj );
    }
    return $status;
}



=head3 _load

Load employee, by eid or nick, into an existing object, overwriting
whatever was there before. The search key (eid or nick) must be an exact
match: this function returns only 1 or 0 records. Takes one of the two
following PARAMHASHes:

    nick => $nick
    eid => $eid

Returns a status object. On success, the populated hashref will be in
the payload.

=cut

sub _load {
    my ( %ARGS ) = @_;
    my $sql;
    my $dbh = __PACKAGE__->SUPER::dbh;
    my ( $spec ) = keys %ARGS;

    $sql = ($spec eq 'nick')
        ? $site->SQL_EMPLOYEE_SELECT_BY_NICK
        : $site->SQL_EMPLOYEE_SELECT_BY_EID;

    # N.B. - the select can only return a single record
    my $newself = $dbh->selectrow_hashref( $sql, {}, $ARGS{$spec} );
    return $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $dbh->errstr ] ) 
        if $dbh->err;
    return $CELL->status_ok( 'DISPATCH_RECORDS_FOUND', args => [ 1 ],
        payload => $newself, count => 1 ) if defined $newself;
    return $CELL->status_ok( 'DISPATCH_NO_RECORDS_FOUND', count => 0 );
}


=head1 FUNCTIONS

The following functions are not object methods.


=head2 select_multiple_by_nick

Class method. Select multiple employees by nick. Returns a status object.
If records are found, they will be in the payload (reference to an array of
expurgated employee objects).

=cut

sub select_multiple_by_nick {
    my ( $class, $sk ) = @_;        # sk means "search key"
    my $status;

    # get database handle from parent
    my $dbh = __PACKAGE__->SUPER::dbh;
    croak( "Bad database handle" ) unless $dbh->ping;

    # no undefined search key
    $sk = $sk || '%'; 
    
    $log->debug( "Entering select_multiple_by_nick" );
    my $sql = $site->SQL_EMPLOYEE_SELECT_MULTIPLE_BY_NICK;
    $log->debug( "Preparing SQL statement ->$sql<-" );
    my $sth = $dbh->prepare( $sql );
    $log->debug( "SQL statement prepared" );
    $dbh->{RaiseError} = 1;
    try {
        local $SIG{__WARN__} = sub {
                die @_;
            };
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
                args => [ $counter ], payload => $result, count => $counter );
        } else {
            $status = $CELL->status_ok( 'DISPATCH_NO_RECORDS_FOUND', 
                count => $counter );
        }   
    } catch {
        $status => $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ], payload => undef );  
    };  
    $dbh->{RaiseError} = 0;

    $log->debug( Dumper( $status ) );
    return $status;
}


=head2 expurgate

1. make deep copy of the object, 2. unbless it, 3. return it

=cut

sub expurgate {
    my ( $self ) = @_; 
    return unless blessed( $self );

    my $udc;
    try {
        $udc = dclone( $self );
        delete $udc->{'passhash'};
        delete $udc->{'salt'};
        unbless $udc;
    } catch {
        $log->err( "AAAAAAAAHHHHHHH: $_" );
    };

    die "Expurgated employee contains passhash?" if $udc->{'passhash'};
    die "Expurgated employee contains salt?" if $udc->{'salt'};
    return $udc;
}


=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

