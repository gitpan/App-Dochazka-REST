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
use Data::Dumper;
use JSON;
use Params::Validate qw( :all );
use Try::Tiny;




=head1 NAME

App::Dochazka::REST::Model::Shared - functions shared by several modules within
the data model




=head1 VERSION

Version 0.352

=cut

our $VERSION = '0.352';




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Shared;

    ...




=head1 EXPORTS

This module provides the following exports:

=over 

=item * C<cud> (Create, Update, Delete -- for single-record statements only)

=item * C<decode_schedule_json> function (given JSON string, return corresponding hashref)

=item * C<load> (Load/Fetch/Retrieve a single datamodel object)

=item * C<load_multiple> (Load/Fetch/Retrieve multiple datamodel objects)

=item * C<noof> (get total number of records in a data model table)

=item * C<priv_by_eid> 

=item * C<schedule_by_eid>

=item * C<select_single> (run an arbitrary SELECT that returns 0 or 1 records)

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( cud decode_schedule_json load load_multiple noof priv_by_eid schedule_by_eid select_single );




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
        my ( $conn, $s_key ) = @_;
        require Try::Tiny;
        my $routine = "load_by_$t";
        my ( $status, $txt );
        $log->debug( "Entered $t" . "_exists with search key $s_key" );
        try {
            no strict 'refs';
            $status = $pkg->$routine( $conn, $s_key );
        } catch {
            $txt = "Function " . $pkg . "::test_exists was generated with argument $t, " .
                "so it tried to call $routine, resulting in exception $_";
            $status = $CELL->status_crit( $txt );
        };
        if ( ! defined( $status ) or $status->level eq 'CRIT' ) {
            die $txt;
        }
        #$log->debug( "Status is " . Dumper( $status ) );
        return $status->payload if $status->ok;
        return;
    }
}


=head2 cud

Attempts to Create, Update, or Delete a single database record. Takes the
following PARAMHASH:

=over

=item * conn

The L<DBIx::Connector> object with which to gain access to the database.

=item * eid

The EID of the employee originating the request (needed for the audit triggers).

=item * object

The Dochazka datamodel object to be worked on.

=item * sql

The SQL statement to execute (should be INSERT, UPDATE, or DELETE).

=item * attrs

An array reference containing the bind values to be plugged into the SQL
statement.

=back

Returns a status object.

=cut

sub cud {
    my %ARGS = validate( @_, {
        conn => { isa => 'DBIx::Connector' },
        eid => { type => SCALAR },
        object => { can => [ qw( insert delete ) ] }, 
        sql => { type => SCALAR }, 
        attrs => { type => ARRAYREF }, # order of attrs must match SQL statement
    } );

    my $status;

    try {
        local $SIG{__WARN__} = sub {
                die @_;
            };

        # start transaction
        $ARGS{'conn'}->txn( fixup => sub {

            # get DBI db handle
            my $dbh = shift;

            # set the dochazka.eid GUC session parameter
            $dbh->do( $site->SQL_SET_DOCHAZKA_EID_GUC, undef, ( $ARGS{'eid'}+0 ) );

            # prepare the SQL statement and bind parameters
            my $sth = $dbh->prepare( $ARGS{'sql'} );
            my $counter = 0;
            map {
                $counter += 1;
                $sth->bind_param( $counter, $ARGS{'object'}->{$_} || undef );
            } @{ $ARGS{'attrs'} }; 

            # execute the SQL statement
            my $rv = $sth->execute;
            $log->debug( "cud: DBI execute returned " . Dumper( $rv ) );
            if ( $rv == 1 ) {

                # a record was returned; get the values
                my $rh = $sth->fetchrow_hashref;
                $log->info( "Statement " . $sth->{'Statement'} . " RETURNING values: " . Dumper( $rh ) );
                # populate object with all RETURNING fields 
                map { $ARGS{'object'}->{$_} = $rh->{$_}; } ( keys %$rh );

            } elsif ( $rv eq '0E0' ) {

                # no error, but no record returned either
                $status = $CELL->status_notice( 
                    'DOCHAZKA_CUD_NO_RECORDS_AFFECTED', 
                    args => [ $sth->{'Statement'} ] 
                ); 
            } else {

                # non-standard return value
                if ( $rv > 1 ) {
                    $status = $CELL->status_crit( 
                        'DOCHAZKA_CUD_MORE_THAN_ONE_RECORD_AFFECTED', 
                        args => [ $sth->{'Statement'} ] 
                    ); 
                } elsif ( $rv == -1 ) {
                    $status = $CELL->status_err( 
                        'DOCHAZKA_CUD_UNKNOWN_NUMBER_OF_RECORDS_AFFECTED', 
                        args => [ $sth->{'Statement'} ] 
                    ); 
                } else {
                    $status = $CELL->status_crit( 
                        "AAAAAAAAAaaaaahhaAAAAAAAA! I\'m at a loss. I might be having a personal crisis!" 
                    );
                }
                die 'jump to catch';
            }
        } );
    } catch {
        my $errmsg = $_;
        if ( not defined( $errmsg ) ) {
            $log->err( '$_ undefined in catch' );
            $errmsg = '<NONE>';
        }
        if ( not defined( $status ) ) {
            $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $errmsg ] );
        }
    };

    $status = $CELL->status_ok( 'DOCHAZKA_CUD_OK', payload => $ARGS{'object'} ) if not defined( $status );
    return $status;
}


=head2 decode_schedule_json

Given JSON string representation of the schedule, return corresponding HASHREF.

=cut

sub decode_schedule_json {
    my ( $json_str ) = @_;

    return unless $json_str;
    return JSON->new->utf8->canonical(1)->decode( $json_str );
}


=head2 load

Load a database record into an object based on an SQL statement and a set of
search keys. The search key must be an exact match: this function returns only
1 or 0 records.  Call, e.g., like this:

    my $status = load( 
        conn => $conn,
        class => __PACKAGE__, 
        sql => $site->DOCHAZKA_SQL_SOME_STATEMENT,
        keys => [ 44 ]
    ); 

The status object will be one of the following:

=over

=item * 1 record found

Level C<OK>, code C<DISPATCH_RECORDS_FOUND>, payload: object of type 'class'

=item * 0 records found

Level C<NOTICE>, code C<DISPATCH_NO_RECORDS_FOUND>, payload: none

=item * Database error

Level C<ERR>, code C<DOCHAZKA_DBI_ERR>, text: error message, payload: none

=back

=cut

sub load {
    # get and verify arguments
    my %ARGS = validate( @_, { 
        conn => { isa => 'DBIx::Connector' },
        class => { type => SCALAR }, 
        sql => { type => SCALAR }, 
        keys => { type => ARRAYREF }, 
    } );

    # consult the database; N.B. - select may only return a single record
    my ( $hr, $status );
    try {
        $ARGS{'conn'}->run( fixup => sub {
            $hr = $_->selectrow_hashref( $ARGS{'sql'}, undef, @{ $ARGS{'keys'} } );
        } );
    } catch {
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };

    # report the result
    return $status if $status;
    return $CELL->status_ok( 'DISPATCH_RECORDS_FOUND', args => [ '1' ],
        payload => $ARGS{'class'}->spawn( %$hr ), count => 1 ) if defined $hr;
    return $CELL->status_notice( 'DISPATCH_NO_RECORDS_FOUND', count => 0 );
}


=head2 load_multiple

Load multiple database records based on an SQL statement and a set of search
keys. Example:

    my $status = load_multiple( 
        conn => $conn,
        class => __PACKAGE__, 
        sql => $site->DOCHAZKA_SQL_SOME_STATEMENT,
        keys => [ 'rom%' ] 
    ); 

The return value will be a status object, the payload of which will be an
arrayref containing a set of objects. The objects are constructed by calling
$ARGS{'class'}->spawn

For convenience, a 'count' property will be included in the status object.

=cut

sub load_multiple {
    # get and verify arguments
    my %ARGS = validate( @_, { 
        conn => { isa => 'DBIx::Connector' },
        class => { type => SCALAR }, 
        sql => { type => SCALAR }, 
        keys => { type => ARRAYREF }, 
    } );
    $log->debug( "Entering " . __PACKAGE__ . "::load_multiple" );

    my $status;
    my $results = [];
    try {
        $ARGS{'conn'}->run( fixup => sub {
            my $sth = $_->prepare( $ARGS{'sql'} );
            my $bc = 0;
            map {
                $bc += 1;
                $sth->bind_param( $bc, $_ || undef );
            } @{ $ARGS{'keys'} };
            $sth->execute();
            # assuming they are objects, spawn them and push them onto @results
            while( defined( my $tmpres = $sth->fetchrow_hashref() ) ) {
                push @$results, $ARGS{'class'}->spawn( $tmpres );
            }
        } );
    } catch {
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    return $status if defined $status;

    my $counter = scalar @$results;
    $status = ( $counter )
        ? $CELL->status_ok( 'DISPATCH_RECORDS_FOUND', 
            args => [ $counter ], payload => $results, count => $counter )
        : $CELL->status_notice( 'DISPATCH_NO_RECORDS_FOUND',
            payload => $results, count => $counter );
    $log->debug( Dumper $status );
    return $status;
}


=head2 noof

Given a L<DBIx::Connector> object and the name of a data model table, returns
the total number of records in the table.

    activities employees intervals locks privhistory schedhistory
    schedintvls schedules

On failure, returns undef.

=cut

sub noof {
    my ( $conn, $table ) = validate_pos( @_, 
        { isa => 'DBIx::Connector' },
        { type => SCALAR } 
    );

    return unless grep { $table eq $_; } qw( activities employees intervals locks
            privhistory schedhistory schedintvls schedules );

    my $count;
    try {
        $conn->run( fixup => sub {
            ( $count ) = $_->selectrow_array( "SELECT count(*) FROM $table" );
        } );
    } catch {
        $CELL->status_crit( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    return $count;
}


=head2 priv_by_eid

Given an EID, and, optionally, a timestamp, returns the employee's priv
level as of that timestamp, or as of "now" if no timestamp was given. The
priv level will default to 'passerby' if it can't be determined from the
database.

=cut

sub priv_by_eid {
    my ( $conn, $eid, $ts ) = validate_pos( @_, 
        { isa => 'DBIx::Connector' },
        { type => SCALAR },
        { type => SCALAR|UNDEF, optional => 1 } 
    );
    #$log->debug( "priv_by_eid: EID is " . (defined( $eid ) ? $eid : 'undef') . " - called from " . (caller)[1] . " line " . (caller)[2] );
    return _st_by_eid( $conn, 'priv', $eid, $ts );
}


=head2 schedule_by_eid

Given an EID, and, optionally, a timestamp, returns the employee's schedule
as of that timestamp, or as of "now" if no timestamp was given.

=cut

sub schedule_by_eid {
    my ( $conn, $eid, $ts ) = validate_pos( @_, 
        { isa => 'DBIx::Connector' },
        { type => SCALAR },
        { type => SCALAR|UNDEF, optional => 1 },
    );
    return _st_by_eid( $conn, 'schedule', $eid, $ts );
}


=head3 _st_by_eid 

Function that 'priv_by_eid' and 'schedule_by_eid' are wrappers of.

=cut

sub _st_by_eid {
    my ( $conn, $st, $eid, $ts ) = @_;
    my ( @args, $sql, $row );
    $log->debug( "Entering _st_by_eid with \$st == $st, \$eid == $eid, \$ts == " . ( $ts || '<NONE>' ) );
    if ( $ts ) {
        # timestamp given
        if ( $st eq 'priv' ) {
            $sql = $site->SQL_EMPLOYEE_PRIV_AT_TIMESTAMP;
        } elsif ( $st eq 'schedule' ) {
            $sql = $site->SQL_EMPLOYEE_SCHEDULE_AT_TIMESTAMP;
        } 
        @args = ( $sql, undef, $eid, $ts );
    } else {
        # no timestamp given
        if ( $st eq 'priv' ) {
            $sql = $site->SQL_EMPLOYEE_CURRENT_PRIV;
        } elsif ( $st eq 'schedule' ) {
            $sql = $site->SQL_EMPLOYEE_CURRENT_SCHEDULE;
        } 
        @args = ( $sql, undef, $eid );
    }

    $log->debug("About to run SQL statement $sql with parameter $eid - " . 
                " called from " . (caller)[1] . " line " . (caller)[2] );

    my $status;
    try {
        $conn->run( fixup => sub {
            ( $row ) = $_->selectrow_array( @args );
        } );
    } catch {
        $log->debug( 'Encountered DBI error' );
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    return $status if $status;

    $row = decode_schedule_json( $row ) if $st eq 'schedule';

    $log->debug( "_st_by_eid success; returning payload " . Dumper( $row ) );
    return $row;
}


=head2 select_single

Given a L<DBIx::Connector> object in the 'conn' property, a SELECT statement in
the 'sql' property and, in the 'keys' property, an arrayref containing a list
of scalar values to plug into the SELECT statement, run a C<selectrow_array>
and return the resulting list.

Returns a standard status object (see C<load> routine, above, for description).

=cut

sub select_single {
    my %ARGS = validate( @_, { 
        conn => { isa => 'DBIx::Connector' },
        sql => { type => SCALAR },
        keys => { type => ARRAYREF },
    } );
    my ( $status, @results );
    try {
        $ARGS{'conn'}->run( fixup => sub {
            @results = $_->selectrow_array( $ARGS{'sql'}, undef, @{ $ARGS{'keys'} } );
        } );
        my $count = scalar @results;
        $status = ( $count )
            ? $CELL->status_ok( 'DISPATCH_RECORDS_FOUND', 
                args => [ $count ], count => $count, payload => \@results )
            : $CELL->status_notice( 'DISPATCH_NO_RECORDS_FOUND' );
    } catch {
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    die "AAAAHAHAAHAAAAAAGGGH! " . __PACKAGE__ . "::select_single" unless $status;
    return $status;
}


=head2 get_history

This function takes a number of arguments. The first two are (1) a
L<DBIx::Connector> object and (2) a SCALAR argument, which can be either 'priv'
or 'schedule'. 

Following these there is a PARAMHASH which can have one or more of the
properties 'eid', 'nick', and 'tsrange'. At least one of { 'eid', 'nick' } must
be specified. If both are specified, the employee is determined according to
'eid'.

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
    my $conn = shift;
    validate_pos( @_, 1, 1, 0, 0, 0, 0 );
    my %ARGS = validate( @_, { 
        eid => { type => SCALAR, optional => 1 },
        nick => { type => SCALAR, optional => 1 },
        tsrange => { type => SCALAR|UNDEF, optional => 1 },
    } );

    $log->debug("Entering get_history for $t - arguments: " . Dumper( \%ARGS ) );

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
    $tsr = ( $ARGS{'tsrange'} )
        ? $ARGS{'tsrange'}
        : '[,)';
    $result->{'tsrange'} = $tsr;
    $log->debug("tsrange == $tsr");

    die "AAAAAAAAAAAHHHHH! Engulfed by the abyss" unless $sk and $sql and $tsr;

    $result->{'history'} = [];
    try {
        $conn->run( fixup => sub {
            my $sth = $_->prepare( $sql );
            $sth->execute( $sk, $tsr );
            while( defined( my $tmpres = $sth->fetchrow_hashref() ) ) {
                push @{ $result->{'history'} }, $tmpres;
            }
        } );
    } catch {
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    return $status if defined $status;

    my $counter = scalar @{ $result->{'history'} };
    return ( $counter ) 
        ? $CELL->status_ok( 'DISPATCH_RECORDS_FOUND', 
            args => [ $counter ], payload => $result, count => $counter ) 
        : $CELL->status_notice( 'DISPATCH_NO_RECORDS_FOUND', 
            payload => $result, count => $counter );
}



=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

