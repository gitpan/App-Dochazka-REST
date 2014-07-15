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

package App::Dochazka::REST::Util::Factory;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $site );
use Carp;
use DBI;




=head1 NAME

App::Dochazka::REST::Util::Factory - date/time-related utilities 




=head1 VERSION

Version 0.066

=cut

our $VERSION = '0.066';




=head1 SYNOPSIS

Date/time-related utilities

    use App::Dochazka::REST::Util::Factory;

    ...



=head1 FUNCTIONS


=head2 priv_by_eid

Given a database handle, an EID, and, optionally, a timestamp, returns the
employee's priv level as of that timestamp, or as of "now" if no timestamp was
given. The priv level will default to 'passerby' if it can't be determined
from the database.

=cut

sub priv_by_eid {
    my ( $dbh, $eid, $ts ) = @_;
    return _st_by_eid( $dbh, 'priv', $eid, $ts );
}


=head2 schedule_by_eid

Given a database handle, an EID, and, optionally, a timestamp, returns the
employee's schedule as of that timestamp, or as of "now" if no timestamp was
given. The schedule will default to '{}' if it can't be determined from the
database.

=cut

sub schedule_by_eid {
    my ( $dbh, $eid, $ts ) = @_;
    return _st_by_eid( $dbh, 'schedule', $eid, $ts );
}


=head3 _st_by_eid 

Function that 'priv_by_eid' and 'schedule_by_eid' are wrappers of.

=cut

sub _st_by_eid {
    my ( $dbh, $st, $eid, $ts ) = @_;
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

Returns a ready-made 'spawn' method. The 'dbh' and 'acleid' attributes are
required, but can be set to the string "TEST" for testing.

=cut

sub make_spawn {
    return sub {
        # process arguments
        my ( $class, @ARGS ) = @_;
        croak "Odd number of arguments in PARAMHASH" if @ARGS and (@ARGS % 2);
        my %ARGS = @ARGS;
        croak "Database handle is undefined" unless defined( $ARGS{dbh} );
        croak "Missing ACL EID in spawn; cannot check ACLs" unless $ARGS{acleid};

        # load required attributes
        my $self = { 
                       dbh     => $ARGS{dbh}, 
                       acleid  => $ARGS{acleid}, 
                   };

        # bless, reset, return
        bless $self, $class;
        $self->reset( %ARGS ); # make sure we have all required attributes
        return $self;
    }
}


=head2 make_reset

Given a reference to a 'populate' subroutine (can be undef) and a list of
attributes, returns a ready-made 'reset' method. The 'dbh' and 'acleid'
attributes are required, but can be set to the string "TEST" for testing.

=cut

sub make_reset {
    my ( @attr ) = @_;
    return sub {
        # process arguments
        my ( $self, @ARGS ) = @_;
        croak "Odd number of arguments in PARAMHASH" if @ARGS and (@ARGS % 2);
        my %ARGS = @ARGS;
        croak "Database handle is undefined" unless defined( $self->{dbh} );
        croak "Missing ACL EID in spawn; cannot check ACLs" unless $self->{acleid};

        # get aclpriv from acleid
        if ( $self->{acleid} ne 'TEST' ) {
            $self->{aclpriv} = priv_by_eid( $self->{dbh}, $self->{acleid} );
        }

        # re-initialize object attributes
        map { $self->{$_} = undef; } @attr;

        # set attributes to run-time values sent in argument list
        map { $self->{$_} = $ARGS{$_}; } @attr;

        # run the populate function, if any
        $self->populate() if $self->can( 'populate' );

        # return a reasonable value for the context
        return;
    }
}



=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

