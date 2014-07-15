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
use App::Dochazka::REST::Model::Shared qw( cud );
use App::Dochazka::REST::Util::Factory;
use DBI;



=head1 NAME

App::Dochazka::REST::Model::Privhistory - Employee privilege history functions




=head1 VERSION

Version 0.066

=cut

our $VERSION = '0.066';




=head1 SYNOPSIS

Employee privilege history functions

    use App::Dochazka::REST::Model::Privhistory;

    ...


=head1 EXPORTS

This module provides the following exports:

=over 

=item C<get_privhistory>

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
    *{"spawn"} = App::Dochazka::REST::Util::Factory::make_spawn();
}



=head2 reset

Instance method. Resets object, either to its primal state (no arguments)
or to the state given in PARAMHASH.

=cut

BEGIN {
    no strict 'refs';
    *{"reset"} = App::Dochazka::REST::Util::Factory::make_reset(
        'int_id', 'eid', 'priv', 'effective', 'remark' 
    );
}



=head2 Accessor methods

Basic accessor methods for all the fields of privhistory table. These
functions return whatever value happens to be associated with the object,
with no guarantee that it matches the database.

=cut

BEGIN {
    foreach my $subname ( 'int_id', 'eid', 'priv', 'effective', 'remark') {
        no strict 'refs';
        *{"$subname"} = sub { 
            my ( $self ) = @_; 
            return $self->{$subname};
        }   
    }   
}

=head3 int_id

Accessor method.


=head3 eid

Accessor method.


=head3 priv

Accessor method.


=head3 effective

Accessor method.


=head3 remark

Accessor method.



=head2 load

Instance method. Given an EID, and, optionally, a timestamp, loads a single
privhistory record into the object, rewriting whatever was there before.
Returns a status object.

=cut

sub load {
    my ( $self, $eid, $ts ) = @_;
    my $dbh = $self->{dbh};
    my @attrs = ( 'int_id', 'eid', 'priv', 'effective', 'remark' );
    my ( $sql, $result );
    if ( $ts ) {
        # timestamp given
        $sql = $site->SQL_PRIVHISTORY_SELECT_ARBITRARY;
        $result = $dbh->selectrow_hashref( $sql, undef, $eid, $ts );
    } else {
        # no timestamp - use 'now'
        $sql = $site->SQL_PRIVHISTORY_SELECT_CURRENT;
        $result = $dbh->selectrow_hashref( $sql, undef, $eid );
    }
    if ( defined $result ) {
        map { $self->{$_} = $result->{$_}; } keys %$result;
        return $CELL->status_ok('DOCHAZKA_RECORDS_FETCHED', args => [1] );
    } elsif ( ! defined( $dbh->err ) ) {
        # nothing found
        return $CELL->status_warn('DOCHAZKA_RECORDS_FETCHED', args => [0] );
    }
    # DBI error
    return $CELL->status_err( $dbh->errstr );
}
    


=head2 insert

Instance method. Attempts to INSERT a record into the 'privhistory' table.
Field values are taken from the object. Returns a status object.

=cut

sub insert {
    my ( $self ) = @_;

    my $status = cud(
        $self,
        $site->SQL_PRIVHISTORY_INSERT,
        ( 'eid', 'priv', 'effective', 'remark' ),
    );

    return $status;
}


=head2 delete

Instance method. Deletes the record. Returns status object.

=cut

sub delete {
    my ( $self ) = @_;

    my $status = cud(
        $self,
        $site->SQL_PRIVHISTORY_DELETE,
        ( 'int_id' ),
    );
    $self->reset( 'int_id' => $self->{int_id} ) if $status->ok;

    return $status;
}



=head1 FUNCTIONS

=head2 get_privhistory

Given a database handle, an EID, and an optional tsrange, return the
history of privilege level changes for that employee over the given
tsrange, or the entire history if no tsrange is supplied. The history is
returned as a reference to an array of C<privhistory> objects. Returns
undef if nothing is found.

=cut

# FIXME: implement
sub get_privhistory {
}




=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

