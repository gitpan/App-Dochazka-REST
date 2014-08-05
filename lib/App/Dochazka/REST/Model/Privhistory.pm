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

package App::Dochazka::REST::Model::Privhistory;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $CELL $log $meta $site );
use Carp;
use Data::Dumper;
use App::Dochazka::REST::Model::Shared qw( load cud );
use DBI;
use Params::Validate qw( :all );
use Try::Tiny;

use parent 'App::Dochazka::REST::dbh';


=head1 NAME

App::Dochazka::REST::Model::Privhistory - privilege history functions




=head1 VERSION

Version 0.140

=cut

our $VERSION = '0.140';




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Privhistory;

    ...



=head1 DESCRIPTION

A description of the privhistory data model follows.


=head2 Privilege levels in the database

=head3 Type

The privilege levels themselves are defined in the C<privilege> enumerated
type:

    CREATE TYPE privilege AS ENUM ('passerby', 'inactive', 'active',
    'admin')


=head3 Table

Employees are associated with privilege levels using a C<privhistory>
table:

    CREATE TABLE IF NOT EXISTS privhistory (
        phid       serial PRIMARY KEY,
        eid        integer REFERENCES employees (eid) NOT NULL,
        priv       privilege NOT NULL;
        effective  timestamp NOT NULL,
        remark     text,
        stamp      json
    );



=head3 Stored procedures

There are also two stored procedures for determining privilege levels:

=over

=item * C<priv_at_timestamp> 
Takes an EID and a timestamp; returns privilege level of that employee as
of the timestamp. If the privilege level cannot be determined for the given
timestamp, defaults to the lowest privilege level ('passerby').

=item * C<current_priv>
Wrapper for C<priv_at_timestamp>. Takes an EID and returns the current
privilege level for that employee.

=back


=head2 Privhistory in the Perl API

When an employee object is loaded (assuming the employee exists), the
employee's current privilege level and schedule are included in the employee
object. No additional object need be created for this. Privhistory objects
are created only when an employee's privilege level changes or when an
employee's privilege history is to be viewed.

In the data model, individual privhistory records are represented by
"privhistory objects". All methods and functions for manipulating these objects
are contained in L<App::Dochazka::REST::Model::Privhistory>. The most important
methods are:

=over

=item * constructor (L<spawn>)

=item * basic accessors (L<phid>, L<eid>, L<priv>, L<effective>, L<remark>)

=item * L<reset> (recycles an existing object by setting it to desired state)

=item * L<load> (loads a single privhistory record)

=item * L<insert> (inserts object into database)

=item * L<delete> (deletes object from database)

=back

For basic C<privhistory> workflow, see C<t/005-privhistory.t>.




=head1 EXPORTS

This module provides the following exports:

=over 

=item L<get_privhistory>

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( get_privhistory );




=head1 METHODS

=head2 spawn

Constructor. See Employee.pm->spawn for general comments.

=cut

BEGIN {
    no strict 'refs';
    *{"spawn"} = App::Dochazka::REST::Model::Shared::make_spawn();
}



=head2 reset

Boilerplate.

=cut

BEGIN {
    no strict 'refs';
    *{"reset"} = App::Dochazka::REST::Model::Shared::make_reset(
        'phid', 'eid', 'priv', 'effective', 'remark' 
    );
}



=head2 Accessor methods

Boilerplate.

=cut

BEGIN {
    foreach my $subname ( 'phid', 'eid', 'priv', 'effective', 'remark') {
        no strict 'refs';
        *{"$subname"} = App::Dochazka::REST::Model::Shared::make_accessor( $subname );
    }   
}

=head3 phid

Accessor method.


=head3 eid

Accessor method.


=head3 priv

Accessor method.


=head3 effective

Accessor method.


=head3 remark

Accessor method.



=head2 load_by_eid

Supposed to be a class method, but in reality we just don't care what the first
argument is.

=cut

sub load_by_eid {
    shift; # discard the first argument
    my ( $eid, $ts ) = validate_pos( @_,
        { type => SCALAR },                # EID
        { type => SCALAR, optional => 1 }, # timestamp
    );
  
    if ( $ts ) {
        return load(
            class => __PACKAGE__,
            sql => $site->SQL_PRIVHISTORY_SELECT_ARBITRARY,
            keys => [ $eid, $ts ],
        );
    }

    return load(
        class => __PACKAGE__,
        sql => $site->SQL_PRIVHISTORY_SELECT_CURRENT,
        keys => [ $eid ],
    );
}


=head2 load_by_phid

Class method.

=cut

sub load_by_phid {
    my $self = shift;
    my ( $phid ) = validate_pos( @_, { type => SCALAR } );

    return load(
        class => __PACKAGE__,
        sql => $site->SQL_PRIVHISTORY_SELECT_BY_PHID,
        keys => [ $phid ],
    );
}


=head2 insert

Instance method. Attempts to INSERT a record into the 'privhistory' table.
Field values are taken from the object. Returns a status object.

=cut

sub insert {
    my ( $self ) = @_;

    my $status = cud(
        object => $self,
        sql => $site->SQL_PRIVHISTORY_INSERT,
        attrs => [ 'eid', 'priv', 'effective', 'remark' ],
    );

    return $status;
}


=head2 update

There is no 'update' method for privhistory records. Instead, delete and
re-recreate.


=head2 delete

Instance method. Deletes the record. Returns status object.

=cut

sub delete {
    my ( $self ) = @_;

    my $status = cud(
        object => $self,
        sql => $site->SQL_PRIVHISTORY_DELETE,
        attrs => [ 'phid' ],
    );
    $self->reset( 'phid' => $self->{phid} ) if $status->ok;

    return $status;
}



=head1 FUNCTIONS

=head2 get_privhistory

Given an EID and an optional tsrange, return the history of privilege level
changes for that employee over the given tsrange, or the entire history if no
tsrange is supplied. Returns a status object where the payload is a reference
to an array of C<privhistory> objects. If nothing is found, the array will be
empty. If there is a DBI error, the payload will be undefined.

=cut

sub get_privhistory {
    validate_pos( @_, 1, 1, 0, 0, 0, 0 );
    my %ARGS = validate( @_, { 
        eid => { type => SCALAR, optional => 1 },
        nick => { type => SCALAR, optional => 1 },
        tsrange => { type => SCALAR, optional => 1 },
    } );

    my $tsr = ( exists $ARGS{'tsrange'} )
        ? $ARGS{'tsrange'}
        : '[,)';
        
    my ( $sql, $sk, $status, $result );
    if ( exists $ARGS{'nick'} ) {
        $sql = $site->SQL_PRIVHISTORY_SELECT_RANGE_BY_NICK;
        $result->{'nick'} = $ARGS{'nick'};
        $sk = $ARGS{'nick'};
    }
    if ( exists $ARGS{'eid'} ) {
        $sql = $site->SQL_PRIVHISTORY_SELECT_RANGE_BY_EID;
        $result->{'eid'} = $ARGS{'eid'};
        $sk = $ARGS{'eid'};
    }
    die "AAAAAAAAAAAHHHHH! Engulfed by the abyss" unless $sk and $sql and $tsr;

    my $dbh = __PACKAGE__->SUPER::dbh;
    my $counter = 0;
    $dbh->{RaiseError} = 1;
    try {
        my $sth = $dbh->prepare( $sql );
        $sth->execute( $sk, $tsr );
        while( defined( my $tmpres = $sth->fetchrow_hashref() ) ) {
            $counter += 1;
            push @{ $result->{'privhistory'} }, $tmpres;
        }
    } catch {
        my $arg = $dbh->err
            ? $dbh->errstr
            : $_;
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $arg ] );
    };
    $dbh->{RaiseError} = 0;
    return $status if defined $status;
    if ( $counter > 0 ) {
        $status = $CELL->status_ok( 'DISPATCH_RECORDS_FOUND', args => 
            [ $counter ], payload => $result, count => $counter );
    } else {
        $result->{'privhistory'} = [];
        $status = $CELL->status_ok( 'DISPATCH_NO_RECORDS_FOUND', 
            payload => $result, count => $counter );
    }
    $dbh->{RaiseError} = 0;
    return $status;
}
  



=head1 EXAMPLES

In this section, some examples are presented to help understand how this
module is used.

=head2 Mr. Moujersky joins the firm

Mr. Moujersky was hired and his first day on the job was 2012-06-04. The
C<privhistory> entry for that might be:

    phid       1037 (automatically assigned by PostgreSQL)
    eid        135 (Mr. Moujersky's Dochazka EID)
    priv       'active'
    effective  '2012-06-04 00:00'


=head2 Mr. Moujersky becomes an administrator

Effective 2013-01-01, Mr. Moujersky was given the additional responsibility
of being a Dochazka administrator for his site.

    phid        1512 (automatically assigned by PostgreSQL)
    eid        135 (Mr. Moujersky's Dochazka EID)
    priv       'admin'
    effective  '2013-01-01 00:00'


=head2 Mr. Moujersky goes on parental leave

In February 2014, Mrs. Moujersky gave birth to a baby boy and effective
2014-07-01 Mr. Moujersky went on parental leave to take care of the
Moujersky's older child over the summer while his wife takes care of the
baby.

    phid        1692 (automatically assigned by PostgreSQL)
    eid        135 (Mr. Moujersky's Dochazka EID)
    priv       'inactive'
    effective  '2014-07-01 00:00'

Note that Dochazka will begin enforcing the new privilege level as of 
C<effective>, and not before. However, if Dochazka's session management
is set up to use LDAP authentication, Mr. Moujersky's access to Dochazka may be
revoked at any time at the LDAP level, effectively shutting him out.




=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

