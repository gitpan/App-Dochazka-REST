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
use App::Dochazka::REST::dbh qw( $dbh );
use Carp;
use Data::Dumper;
use DBI;
use JSON;
use Params::Validate qw( :all );
use Scalar::Util qw( blessed );
use Storable qw( dclone );
use Try::Tiny;




=head1 NAME

App::Dochazka::REST::Model::Shared - functions shared by several modules within
the data model




=head1 VERSION

Version 0.264

=cut

our $VERSION = '0.264';




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Shared;

    ...




=head1 EXPORTS

This module provides the following exports:

=over 

=item * C<cud> (Create, Update, Delete -- for single-record statements only)

=item * C<decode_schedule_json> function (given JSON string, return corresponding hashref)

=item * C<load> (Load/Fetch/Retrieve -- single-record only)

=item * C<noof> (get total number of records in a data model table)

=item * C<priv_by_eid> 

=item * C<schedule_by_eid>

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( cud decode_schedule_json load noof priv_by_eid schedule_by_eid );




=head1 FUNCTIONS



=head2 make_test_exists

Returns coderef for a function, 'test_exists', that performs a simple
true/false check for existence of a record matching a scalar search key.  The
record must be an exact match (no wildcards).

Takes one argument: a type string C<$t> which is concatenated with the string
'load_by_' to arrive at the name of the function to be called to execute the
search.

The returned function takes a single argument: the search key (a scalar value).
If a record matching the search key is found, the corresponding object
(i.e. a true value) is returned. If such a record does not exist, 'undef' (a
false value) is returned. If there is a DBI error, the error text is logged
and undef is returned.

=cut

sub make_test_exists {

    my ( $t ) = validate_pos( @_, { type => SCALAR } );
    my $pkg = (caller)[0];

    return sub {
        my ( $s_key ) = @_;
        require Try::Tiny;
        my $routine = "load_by_$t";
        my ( $status, $txt );
        $log->debug( "Entered $t" . "_exists with search key $s_key" );
        try {
            no strict 'refs';
            $status = $pkg->$routine( $s_key );
        } catch {
            $txt = "Function " . $pkg . "::test_exists was generated with argument $t, " .
                "so it tried to call $routine, resulting in exception $_";
            $status = $CELL->status_crit( $txt );
        };
        if ( ! defined( $status ) or $status->level eq 'CRIT' ) {
            die $txt;
        }
        $log->debug( "Status is " . Dumper( $status ) );
        return $status->payload if $status->ok;
        return;
    }
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
        attrs => { type => ARRAYREF }, # order of attrs must match SQL statement
    } );

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

               #my $value = defined( $ARGS{'object'}->{$_} )
               #        ? $ARGS{'object'}->{$_}
               #        : 'undef';
               #$log->debug( "cud binding parameter $counter to attribute $_ value $value" );

               $sth->bind_param( $counter, $ARGS{'object'}->{$_} || undef );
            } @{ $ARGS{'attrs'} };
        $sth->execute;
        my $rh = $sth->fetchrow_hashref;
        $log->info( "Statement " . $sth->{'Statement'} . " RETURNING values: " . Dumper( $rh ) );
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

    $status = $CELL->status_ok( 'DOCHAZKA_CUD_OK', payload => $ARGS{'object'} ) if not defined( $status );
    return $status;
}


=head2 decode_schedule_json

Given JSON string representation of the schedule, return corresponding HASHREF.

=cut

sub decode_schedule_json {
    my ( $json_str ) = @_;

    return JSON->new->utf8->canonical(1)->decode( $json_str );
}


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
    my $hr = $dbh->selectrow_hashref( $ARGS{'sql'}, undef, @{ $ARGS{'keys'} } );
    return $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $dbh->errstr ] )
        if $dbh->err;

    # report the result
    return $CELL->status_ok( 'DISPATCH_RECORDS_FOUND', args => [ 1 ],
        payload => $ARGS{'class'}->spawn( %$hr ), count => 1 ) if defined $hr;
    return $CELL->status_notice( 'DISPATCH_NO_RECORDS_FOUND', count => 0 );
}


=head2 noof

Given the name of a data model table, returns the total number of records
in the table.

    activities employees intervals locks privhistory schedhistory
    schedintvls schedules

On failure, returns undef.

=cut

sub noof {
    my ( $table ) = validate_pos( @_, { type => SCALAR } );

    return unless grep { $table eq $_; } qw( activities employees intervals locks
            privhistory schedhistory schedintvls schedules );

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
        { type => SCALAR|UNDEF, optional => 1 } );
    $log->debug( "priv_by_eid: EID is " . (defined( $eid ) ? $eid : 'undef') . " - called from " . (caller)[1] . " line " . (caller)[2] );
    return _st_by_eid( 'priv', $eid, $ts );
}


=head2 schedule_by_eid

Given an EID, and, optionally, a timestamp, returns the employee's schedule
as of that timestamp, or as of "now" if no timestamp was given. The
schedule will default to '{}' if it can't be determined from the database.

=cut

sub schedule_by_eid {
    my ( $eid, $ts ) = validate_pos( @_, { type => SCALAR },
        { type => SCALAR|UNDEF, optional => 1 } );
    return _st_by_eid( 'schedule', $eid, $ts );
}


=head3 _st_by_eid 

Function that 'priv_by_eid' and 'schedule_by_eid' are wrappers of.

=cut

sub _st_by_eid {
    my ( $st, $eid, $ts ) = @_;
    my ( $sql, $row );
    $log->debug( "Entering _st_by_eid with \$st == $st" );
    if ( $ts ) {
        # timestamp given
        if ( $st eq 'priv' ) {
            $sql = $site->SQL_EMPLOYEE_PRIV_AT_TIMESTAMP;
        } elsif ( $st eq 'schedule' ) {
            $sql = $site->SQL_EMPLOYEE_SCHEDULE_AT_TIMESTAMP;
        } 
        ( $row ) = $dbh->selectrow_array( $sql, undef, $eid, $ts );
    } else {
        # no timestamp given
        if ( $st eq 'priv' ) {
            $sql = $site->SQL_EMPLOYEE_CURRENT_PRIV;
        } elsif ( $st eq 'schedule' ) {
            $sql = $site->SQL_EMPLOYEE_CURRENT_SCHEDULE;
        } 
        $log->debug("About to run SQL statement $sql with parameter $eid - called from " . (caller)[1] . " line " . (caller)[2] );
        ( $row ) = $dbh->selectrow_array( $sql, undef, $eid );
    }
    return $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $dbh->errstr ] )
        if $dbh->err;
    $row = decode_schedule_json( $row ) if $st eq 'schedule';
    return $row;
}


=head2 get_history

Takes a SCALAR argument, which can be either 'priv' or 'schedule', followed by
a PARAMHASH which can have one or more of the properties 'eid', 'nick', and
'tsrange'.

At least one of { 'eid', 'nick' } must be specified. If both are specified,
the employee is determined according to 'eid'.

The function returns the history of privilege level or schedule changes for
that employee over the given tsrange, or the entire history if no tsrange is
supplied. 

The return value will always be an L<App::CELL::Status|status> object.

Upon success, the payload will be a reference to an array of history
objects. If nothing is found, the array will be empty. If there is a DBI error,
the payload will be undefined.

=cut

sub get_history {
    my $t = shift;
    validate_pos( @_, 1, 1, 0, 0, 0, 0 );
    my %ARGS = validate( @_, { 
        eid => { type => SCALAR, optional => 1 },
        nick => { type => SCALAR, optional => 1 },
        tsrange => { type => SCALAR, optional => 1 },
    } );

    $log->debug("Entering get_history for $t");

    my ( $sql, $sk, $status, $result, $tsr );
    if ( exists $ARGS{'nick'} ) {
        $sql = ($t eq 'priv') 
            ? $site->SQL_PRIVHISTORY_SELECT_RANGE_BY_NICK
            : $site->SQL_SCHEDHISTORY_SELECT_RANGE_BY_NICK;
        $result->{'nick'} = $ARGS{'nick'};
        $result->{'eid'} = $ARGS{'eid'} if exists $ARGS{'eid'};
        $sk = $ARGS{'nick'};
    }
    if ( exists $ARGS{'eid'} ) {
        $sql = ($t eq 'priv') 
            ? $site->SQL_PRIVHISTORY_SELECT_RANGE_BY_EID
            : $site->SQL_SCHEDHISTORY_SELECT_RANGE_BY_EID;
        $result->{'eid'} = $ARGS{'eid'};
        $result->{'nick'} = $ARGS{'nick'} if exists $ARGS{'nick'};
        $sk = $ARGS{'eid'};
    }
    $log->debug("sql == $sql");
    $tsr = ( exists $ARGS{'tsrange'} )
        ? $ARGS{'tsrange'}
        : '[,)';
    $result->{'tsrange'} = $tsr;
    $log->debug("tsrange == $tsr");

    die "AAAAAAAAAAAHHHHH! Engulfed by the abyss" unless $sk and $sql and $tsr;

    my $counter = 0;
    $dbh->{RaiseError} = 1;
    try {
        my $sth = $dbh->prepare( $sql );
        $sth->execute( $sk, $tsr );
        while( defined( my $tmpres = $sth->fetchrow_hashref() ) ) {
            $counter += 1;
            push @{ $result->{'history'} }, $tmpres;
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
        $result->{'history'} = [];
        $status = $CELL->status_notice( 'DISPATCH_NO_RECORDS_FOUND', 
            payload => $result, count => $counter );
    }
    $dbh->{RaiseError} = 0;
    return $status;
}



=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

