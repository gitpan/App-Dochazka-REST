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

package App::Dochazka::REST::Model::Shared;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $CELL $log $meta $site );
use App::CELL::Util qw( stringify_args );
use Carp;
use Data::Dumper;
use DBI;
use Params::Validate qw( :all );
use Try::Tiny;

use parent 'App::Dochazka::REST::dbh';



=head1 NAME

App::Dochazka::REST::Model::Shared - functions shared by several modules within
the data model




=head1 VERSION

Version 0.140

=cut

our $VERSION = '0.140';




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Shared;

    ...




=head1 EXPORTS

This module provides the following exports:

=over 

=item * C<load> (Load/Fetch/Retrieve -- single-record only)

=item * C<cud> (Create, Update, Delete -- for single-record statements only)

=item * C<noof> (get total number of records in a data model table)

=item * C<priv_by_eid> 

=item * C<schedule_by_eid>

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( load cud noof priv_by_eid schedule_by_eid );




=head1 FUNCTIONS


=head2 load

Load a database record into a hashref based on a search key. Must be specifically
enabled for the class/table in question. The search key must be an exact match:
this function returns only 1 or 0 records. Call, e.g., like this:

    my $status = load( 
        class => __PACKAGE__, 
        sql => $site->DOCHAZKA_ 
        key => 44 
    ); 

=cut

sub load {
    # get and verify arguments
    my %ARGS = validate( @_, { 
        class => { type => SCALAR }, 
        sql => { type => SCALAR }, 
        keys => { type => ARRAYREF }, 
    } );

    # consult the database; N.B. - select may only return a single record
    my $dbh = __PARENT__->SUPER::dbh;

    my $hr = $dbh->selectrow_hashref( $ARGS{'sql'}, undef, @{ $ARGS{'keys'} } );
    return $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $dbh->errstr ] )
        if $dbh->err;

    # report the result
    return $CELL->status_ok( 'DISPATCH_RECORDS_FOUND', args => [ 1 ],
        payload => $ARGS{'class'}->spawn( %$hr ), count => 1 ) if defined $hr;
    return $CELL->status_ok( 'DISPATCH_NO_RECORDS_FOUND', count => 0 );
}


=head2 cud

** USE FOR SINGLE-RECORD SQL STATEMENTS ONLY **
Attempts to Create, Update, or Delete a single database record. Takes a blessed
reference (activity object or employee object), a SQL statement, and a list of
attributes. Overwrites attributes in the object with the RETURNING list values
received from the database. Returns a status object. Call example:

    $status = cud( object => $self, sql => $sql, attrs => [ @attr ] );

=cut

sub cud {
    my %ARGS = validate( @_, {
        object => { can => [ qw( insert delete ) ] }, 
        sql => { type => SCALAR }, 
        attrs => { type => ARRAYREF } 
    } );

    my $dbh = __PACKAGE__->SUPER::dbh;
    my $status;

    # DBI incantations
    $dbh->{AutoCommit} = 0;
    $dbh->{RaiseError} = 1;

    try {
        local $SIG{__WARN__} = sub {
                die @_;
            };
        my $sth = $dbh->prepare( $ARGS{'sql'} );
        my $counter = 0;
        map {
               $counter += 1;
               $sth->bind_param( $counter, $ARGS{'object'}->{$_} );
            } @{ $ARGS{'attrs'} };
        $sth->execute;
        my $rh = $sth->fetchrow_hashref;
        # populate object with all RETURNING fields 
        map { $ARGS{'object'}->{$_} = $rh->{$_}; } ( keys %$rh );
        $dbh->commit;
    } catch {
        my $errmsg = $_;
        $dbh->rollback;
        if ( not defined( $errmsg ) ) {
            $log->err( '$_ undefined in catch' );
            $errmsg = '<NONE>';
        }
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $errmsg ] );
    };

    $dbh->{AutoCommit} = 1;
    $dbh->{RaiseError} = 0;

    $status = $CELL->status_ok if not defined( $status );
    return $status;
}


=head2 noof

Given a database handle and the name of a data model table, returns the
total number of records in the table.

    activities employees intervals locks privhistory schedhistory
    schedintvls schedules

On failure, returns undef.

=cut

sub noof {
    my ( $table ) = validate_pos( @_, { type => SCALAR } );

    return unless grep { $table eq $_; } qw( activities employees intervals locks
            privhistory schedhistory schedintvls schedules );

    my $dbh = __PACKAGE__->SUPER::dbh;

    my ( $result ) = $dbh->selectrow_array( "SELECT count(*) FROM $table" );
    return $result;
}



=head2 priv_by_eid

Given an EID, and, optionally, a timestamp, returns the employee's priv
level as of that timestamp, or as of "now" if no timestamp was given. The
priv level will default to 'passerby' if it can't be determined from the
database.

=cut

sub priv_by_eid {
    my ( $eid, $ts ) = validate_pos( @_, { type => SCALAR },
        { type => SCALAR, optional => 1 } );
    return _st_by_eid( 'priv', $eid, $ts );
}


=head2 schedule_by_eid

Given an EID, and, optionally, a timestamp, returns the employee's schedule
as of that timestamp, or as of "now" if no timestamp was given. The
schedule will default to '{}' if it can't be determined from the database.

=cut

sub schedule_by_eid {
    my ( $eid, $ts ) = validate_pos( @_, { type => SCALAR },
        { type => SCALAR, optional => 1 } );
    return _st_by_eid( 'schedule', $eid, $ts );
}


=head3 _st_by_eid 

Function that 'priv_by_eid' and 'schedule_by_eid' are wrappers of.

=cut

sub _st_by_eid {
    my ( $st, $eid, $ts ) = @_;
    my $dbh = __PACKAGE__->SUPER::dbh;
    my $sql;
    if ( $ts ) {
        # timestamp given
        if ( $st eq 'priv' ) {
            $sql = $site->SQL_EMPLOYEE_PRIV_AT_TIMESTAMP;
        } elsif ( $st eq 'schedule' ) {
            $sql = $site->SQL_EMPLOYEE_SCHEDULE_AT_TIMESTAMP;
        } 
        ( $st ) = $dbh->selectrow_array( $sql, undef, $eid, $ts );
    } else {
        # no timestamp given
        if ( $st eq 'priv' ) {
            $sql = $site->SQL_EMPLOYEE_CURRENT_PRIV;
        } elsif ( $st eq 'schedule' ) {
            $sql = $site->SQL_EMPLOYEE_CURRENT_SCHEDULE;
        } 
        ( $st ) = $dbh->selectrow_array( $sql, undef, $eid );
    }
    return $st;
}



=head2 make_spawn

Returns a ready-made 'spawn' method. 

=cut

sub make_spawn {
    return sub {
        # process arguments
        my ( $class, @ARGS ) = @_;
        croak "Odd number of arguments (" . scalar @ARGS . ") in PARAMHASH: " . stringify_args( @ARGS ) if @ARGS and (@ARGS % 2);
        my %ARGS = @ARGS;

        # bless, reset, return
        my $self = bless {}, $class;
        $self->reset( %ARGS ); # make sure we have all required attributes
        return $self;
    }
}


=head2 make_reset

Given a list of attributes, returns a ready-made 'reset' method. 

=cut

sub make_reset {

    # take a list consisting of the names of attributes that the 'reset'
    # method will accept -- these must all be scalars
    my ( @attr ) = validate_pos( @_, map { { type => SCALAR }; } @_ );

    # construct the validation specification for the 'reset' routine:
    # 1. 'reset' will take named parameters _only_
    # 2. only the values from @attr will be accepted as parameters
    # 3. all parameters are optional
    my $val_spec;
    map { $val_spec->{$_} = 0; } @attr;
    
    return sub {
        # process arguments
        my $self = shift;
        confess "Not an instance method call" unless ref $self;
        my %ARGS = validate( @_, $val_spec ) if @_ and defined $_[0];

        # set attributes to run-time values sent in argument list
        map { $self->{$_} = $ARGS{$_}; } @attr;

        # run the populate function, if any
        $self->populate() if $self->can( 'populate' );

        # return an appropriate throw-away value
        return;
    }
}


=head2 make_accessor

Returns a ready-made accessor.

=cut

sub make_accessor {
    my ( $subname ) = @_;
    sub {
        my $self = shift;
        validate_pos( @_, { type => SCALAR, optional => 1 } );
        $self->{$subname} = shift if @_;
        return $self->{$subname};
    };
}




=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

