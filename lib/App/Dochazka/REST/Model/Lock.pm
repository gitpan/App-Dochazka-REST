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

package App::Dochazka::REST::Model::Lock;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $CELL $log $meta $site );
use Carp;
use Data::Dumper;
use App::Dochazka::REST::Model::Shared qw( load cud );
use DBI;
use Params::Validate qw( :all );

use parent 'App::Dochazka::REST::dbh';


=head1 NAME

App::Dochazka::REST::Model::Lock - lock data model




=head1 VERSION

Version 0.134

=cut

our $VERSION = '0.134';




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Lock;

    ...


=head1 DESCRIPTION

A description of the lock data model follows.


=head2 Locks in the database

    CREATE TABLE locks (
        lid     serial PRIMARY KEY,
        eid     integer REFERENCES Employees (EID),
        intvl   tsrange NOT NULL,
        remark  text
    )

There is also a stored procedure, C<fully_locked>, that takes an EID
and a tsrange, and returns a boolean value indicating whether or not
that period is fully locked for the given employee.


=head3 Locks in the Perl API

# FIXME: MISSING VERBIAGE




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
    *{"spawn"} = App::Dochazka::REST::Model::Shared::make_spawn();
}



=head2 reset

Boilerplate.

=cut

BEGIN {
    no strict 'refs';
    *{"reset"} = App::Dochazka::REST::Model::Shared::make_reset(
        'lid', 'eid', 'intvl', 'remark'
    );
}



=head2 Accessor methods

Boilerplate.

=cut

BEGIN {
    foreach my $subname ( 'lid', 'eid', 'intvl', 'remark' ) {
        no strict 'refs';
        *{"$subname"} = App::Dochazka::REST::Model::Shared::make_accessor( $subname );
    }   
}

=head3 lid

Accessor method.


=head3 eid

Accessor method.


=head3 intvl

Accessor method.


=head3 remark

Accessor method.



=head2 load_by_lid

Instance method. Given an LID, loads a single lock into the object, rewriting
whatever was there before.  Returns a status object.

=cut

sub load_by_lid {
    my $self = shift;
    my ( $lid ) = validate_pos( @_, { type => SCALAR } );

    return load(
        class => __PACKAGE__,
        sql => $site->SQL_LOCK_SELECT_BY_LID,
        keys => [ $lid ],
    );
}
    


=head2 insert

Instance method. Attempts to INSERT a record. Field values are taken from the
object. Returns a status object.

=cut

sub insert { 
    my ( $self ) = @_;

    my $status = cud( 
        object => $self, 
        sql => $site->SQL_LOCK_INSERT, 
        attrs => [ 'eid', 'intvl', 'remark' ],
    );

    return $status; 
}


=head2 update

Instance method. Attempts to UPDATE a record. Field values are taken from the
object. Returns a status object.

=cut

sub update { 
    my ( $self ) = @_;

    my $status = cud( 
        object => $self, 
        sql => $site->SQL_LOCK_UPDATE, 
        attrs => [ 'eid', 'intvl', 'remark', 'lid' ],
    );

    return $status; 
}


=head2 delete

Instance method. Attempts to DELETE a record. Field values are taken from the
object. Returns a status object.

=cut

sub delete { 
    my ( $self ) = @_;

    my $status = cud( 
        object => $self, 
        sql => $site->SQL_LOCK_DELETE, 
        attrs => [ 'lid' ],
    );
    $self->reset( lid => $self->{lid} ) if $status->ok;

    return $status; 
}




=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;


