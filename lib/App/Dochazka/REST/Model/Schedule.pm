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

package App::Dochazka::REST::Model::Schedule;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $CELL $log $meta $site );
use Carp;
use Data::Dumper;
use App::Dochazka::REST::Model::Shared qw( cud );
use DBI;



=head1 NAME

App::Dochazka::REST::Model::Schedule - schedule functions




=head1 VERSION

Version 0.072

=cut

our $VERSION = '0.072';




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Schedule;

    ...


=head1 EXPORTS

This module provides the following exports:

=over 

=item C<get_json>

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( get_json );



=head1 METHODS

=head2 spawn

Constructor. See Employee.pm->spawn for general comments.

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
    *{"reset"} = App::Dochazka::REST::Model::Shared::make_reset( 'sid', 
        'schedule', 'remark' );
}



=head2 Accessor methods

Basic accessor methods for all the fields of Schedule table. These
functions return whatever value happens to be associated with the object,
with no guarantee that it matches the database.

=cut

BEGIN {
    foreach my $subname ( 'sid', 'schedule', 'remark' ) {
        no strict 'refs';
        *{"$subname"} = sub { 
            my ( $self ) = @_; 
            return $self->{$subname};
        }   
    }   
}

=head3 sid

Accessor method.


=head3 schedule

Accessor method.


=head3 remark

Accessor method.



=head2 insert

Instance method. Attempts to INSERT a record into the 'schedules' table.
Field values are taken from the object. Returns a status object.

=cut

sub insert {
    my ( $self ) = @_;

    # if the exact same schedule is already in the database, we
    # don't insert it again
    $self->{sid} = $self->{dbh}->selectrow_array( $site->SQL_SCHEDULES_SELECT_SID, 
                   undef, $self->{schedule} );    
    return $CELL->status_ok( "This schedule has SID " . $self->{sid} ) 
        if defined $self->{sid};
    return $CELL->status_err( $self->{dbh}->errstr ) if $self->{dbh}->err;

    # no exact match found, insert a new record
    my $status = cud(
        $self,
        $site->SQL_SCHEDULES_INSERT,
        ( 'schedule', 'remark' ),
    );
    $log->info( "Inserted new schedule with SID" . $self->{sid} ) if $status->ok;

    return $status;
}



=head1 FUNCTIONS

=head2 get_json

Given a database handle and a SID, queries the database for the JSON
string associated with the SID. Returns undef if not found.

=cut

sub get_json {

    my ( $dbh, $sid ) = @_;

    if (  ( not defined( $dbh ) ) or
          ( not $sid ) or
          ( not $dbh->ping )  ) {
        $CELL->status_err( "Problem with arguments in get_json" );
        return;
    }

    my ( $json) = $dbh->selectrow_array( $site->SQL_SCHEDULES_SELECT_SCHEDULE,
                                         undef,
                                         $sid );
    return $json;
}





=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

