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

package App::Dochazka::REST::Model::Schedintvls;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $CELL $log $meta $site );
use Carp;
use Data::Dumper;
use App::Dochazka::REST::Util::Factory;
use DBI;
use JSON;
use Try::Tiny;



=head1 NAME

App::Dochazka::REST::Model::Schedintvls - object class for "scratch schedules"




=head1 VERSION

Version 0.066

=cut

our $VERSION = '0.066';




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Schedintvls;

    ...




=head1 EXPORTS

This module provides the following exports:

=over 

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( );



=head1 METHODS

=head2 spawn

Constructor. See Employee.pm->spawn for general comments.

=cut

BEGIN {
    no strict 'refs';
    *{"spawn"} = App::Dochazka::REST::Util::Factory::make_spawn();
}



=head2 reset

Instance method. Resets object, either to its primal state (no arguments)
or to the state given in PARAMHASH.

=cut

BEGIN {
    no strict 'refs';
    *{"reset"} = App::Dochazka::REST::Util::Factory::make_reset( 
        'scratch_sid', 'intvls' 
    );
}



=head2 populate

Populate the schedintvls object (called automatically by 'reset' method
which is, in turn, called automatically by 'spawn')

=cut

sub populate {
    my ( $self ) = @_;
    #if ( ! $self->{dbh}->ping ) {
    #    $CELL->status_crit( 'DOCHAZKA_DB_NOT_ALIVE' );
    #    croak();
    #} 
    my $ss = _next_scratch_sid( $self->{dbh} );
    $log->debug( "Got next scratch SID: $ss" );
    $self->{scratch_sid} = $ss;
    return;
}



=head2 Accessor methods

Special accessors that do not necessarily correspond to columns in the database
table. These functions return whatever value happens to be associated with the
object, with no guarantee that it matches the database.

=cut

BEGIN {
    foreach my $subname ( 'scratch_sid', 'intvls', 'schedule' ) {
        no strict 'refs';
        *{"$subname"} = sub { 
            my ( $self ) = @_; 
            return $self->{$subname};
        }   
    }   
}

=head3 scratch_sid

Accessor method.


=head3 intvls

Accessor method.


=head3 schedule

Accessor method.



=head2 load

Instance method. Once the scratch intervals are inserted, we have a fully
populated object. This method runs each scratch interval through the stored
procedure 'translate_schedintvl' -- upon success, it creates a new attribute,
C<< $self->{schedule} >>, containing the translated intervals.

=cut

sub load {

    # process arguments
    my ( $self ) = @_;

    # prepare and execute statement
    my $dbh = $self->{dbh};
    my $sth = $dbh->prepare( $site->SQL_SCHEDINTVLS_SELECT );
    $sth->execute( $self->{scratch_sid} );

    # since the statement returns n rows, we use a loop to fetch them
    my $counter = 0;
    my $result = [];
    while( defined( my $tmpres = $sth->fetchrow_hashref() ) ) {
        $result->[$counter] = $tmpres;
        $counter += 1;
    }
    return $CELL->status_err( $sth->errstr) if $sth->err;

    # success: add a new attribute with the translated intervals
    $self->{schedule} = $result;

    return $CELL->status_ok( "Schedule has $counter rows" );
}
    


=head2 insert

Instance method. Attempts to INSERT one or more records (one for each
interval in the 'intvls' attribute) into the 'schedintvls' table.
Field values are taken from the object. Returns a status object.

=cut

sub insert {
    my ( $self ) = @_;
    my $dbh = $self->{dbh};
    my $status;

    # the insert operation needs to take place within a transaction,
    # because all the intervals are inserted in one go

    # setting AutoCommit to 0 starts the transaction
    my $autocommit = $dbh->{AutoCommit};
    $dbh->{AutoCommit} = 0;
    my $raiseerror = $dbh->{RaiseError};
    $dbh->{RaiseError} = 1;

    # the transaction
    try {
        my $sth = $dbh->prepare( $site->SQL_SCHEDINTVLS_INSERT );

        # the next sequence value is already in $self->{scratch_sid}
        $sth->bind_param( 1, $self->{scratch_sid} );

	# the intervals to be inserted are in $self->{intvls} (an arrayref):
	# execute SQL_SCHEDINTVLS_INSERT for each element
        map {
                $log->info( "About to INSERT bogus interval $_" );
                $sth->bind_param( 2, $_ );
                $sth->execute;
            } @{ $self->{intvls} };
        $dbh->commit;
        $status = $CELL->status_ok;
    } catch {
        $dbh->rollback;
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };

    # restore AutoCommit and RaiseError
    $dbh->{AutoCommit} = $autocommit;
    $dbh->{RaiseError} = $raiseerror;

    # done: all green
    return $status;
}



=head2 delete

Instance method. Once we are done with the scratch intervals, they can be deleted.
Returns a status object.

=cut

sub delete {
    my ( $self ) = @_;
    my $result = $self->{dbh}->do( $site->SQL_SCHEDINTVLS_DELETE,
                                   undef,
                                   $self->{scratch_sid} );
    return $CELL->status_err( $self->{dbh}->errstr ) if $self->{dbh}->err;
    return $CELL->status_warn( "No records to delete" ) if $result eq '0E0';
    return $CELL->status_ok( "Deleted $result records for scratch_sid " . $self->{scratch_sid} )
        if defined( $result ) and defined( $self->{scratch_sid} );
    return $CELL->status_not_ok;
}


=head2 json

Instance method. Returns a JSON string representation of the schedule.

=cut

sub json {
    my ( $self ) = @_;

    return JSON->new->utf8->canonical(1)->encode( $self->{schedule} );
}




=head1 FUNCTIONS

=head2 Exported functions



=head2 Non-exported functions

=head3 _next_scratch_sid

Get next value from the scratch_sid_seq sequence

=cut

sub _next_scratch_sid {
    my ( $dbh ) = @_;
    return $dbh->selectrow_array( $site->SQL_SCRATCH_SID, undef );
}




=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

