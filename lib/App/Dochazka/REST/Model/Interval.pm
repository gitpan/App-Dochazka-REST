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

package App::Dochazka::REST::Model::Interval;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $CELL $log $meta $site );
#use App::Dochazka::REST::dbh qw( $dbh );
use Carp;
use Data::Dumper;
use App::Dochazka::REST::Model::Shared qw( cud load load_multiple );
use DBI;
use Params::Validate qw( :all );

# we get 'spawn', 'reset', and accessors from parent
use parent 'App::Dochazka::Model::Interval';



=head1 NAME

App::Dochazka::REST::Model::Interval - activity intervals data model




=head1 VERSION

Version 0.322

=cut

our $VERSION = '0.322';




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Interval;

    ...


=head1 DESCRIPTION

A description of the activity interval data model follows.


=head2 Intervals in the database

Activity intervals are stored in the C<intervals> database table, which has
the following structure:

    CREATE TABLE intervals (
       iid         serial PRIMARY KEY,
       eid         integer REFERENCES employees (eid) NOT NULL,
       aid         integer REFERENCES activities (aid) NOT NULL,
       intvl       tsrange NOT NULL,
       long_desc   text,
       remark      text,
       EXCLUDE USING gist (eid WITH =, intvl WITH &&)
    );

Note the use of the C<tsrange> operator introduced in PostgreSQL 9.2.

In addition to the Interval ID (C<iid>), which is assigned by PostgreSQL,
the Employee ID (C<eid>), and the Activity ID (C<aid>), which are provided
by the client, an interval can optionally have a long description
(C<long_desc>), which is the employee's description of what she did during
the interval, and an admin remark (C<remark>).


=head2 Intervals in the Perl API

In the data model, individual activity intervals (records in the
C<intervals> table) are represented by "interval objects". All methods
and functions for manipulating these objects are contained in this module.
The most important methods are:

=over

=item * constructor (L<spawn>)

=item * basic accessors (L<iid>, L<eid>, L<aid>, L<intvl>, L<long_desc>,
L<remark>)

=item * L<reset> (recycles an existing object by setting it to desired
state)

=item * L<insert> (inserts object into database)

=item * L<delete> (deletes object from database)

=back

For basic activity interval workflow, see C<t/010-interval.t>.




=head1 EXPORTS

This module provides the following exports:

=over 

=item * L<iid_exists> (boolean function)

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( iid_exists );



=head1 METHODS


=head2 load_by_iid

Boilerplate.

=cut

sub load_by_iid {
    my $self = shift;
    my ( $iid ) = validate_pos( @_, { type => SCALAR } );

    return load( 
        class => __PACKAGE__, 
        sql => $site->SQL_INTERVAL_SELECT_BY_IID,
        keys => [ $iid ],
    );
}
    

=head2 insert

Instance method. Attempts to INSERT a record.
Field values are taken from the object. Returns a status object.

=cut

sub insert {
    my ( $self ) = @_;

    # FIXME: here is where we should check if the interval falls within
    # reasonable temporal limits. The upper limit is "now() + DOCHAZKA_MAX_FUTURE_DAYS";
    # the lower limit is  . . . (is there a lower limit?)

    # FIXME: this is also where we check if the interval conflicts with
    # a lock.

    my $status = cud( 
        object => $self,
        sql => $site->SQL_INTERVAL_INSERT,
        attrs => [ 'eid', 'aid', 'intvl', 'long_desc', 'remark' ],
    );

    return $status;
}


=head2 update

Instance method. Attempts to UPDATE a record.
Field values are taken from the object. Returns a status object.

=cut

sub update {
    my ( $self ) = @_;

    return $CELL->status_crit( 'DOCHAZKA_ID_MISSING_IN_UPDATE' ) unless $self->{'iid'};
    my $status = cud( 
        object => $self,
        sql => $site->SQL_INTERVAL_UPDATE,
        attrs => [ qw( eid aid intvl long_desc remark iid ) ],
    );

    return $status;
}


=head2 delete

Instance method. Attempts to DELETE a record.
Field values are taken from the object. Returns a status object.

=cut

sub delete {
    my ( $self ) = @_;

    my $status = cud( 
        object => $self,
        sql => $site->SQL_INTERVAL_DELETE,
        attrs => [ 'iid' ],
    );
    $self->reset( iid => $self->{iid} ) if $status->ok;

    return $status;
}



=head1 FUNCTIONS


=head2 iid_exists

Boolean function

=cut

BEGIN {
    no strict 'refs';
    *{'iid_exists'} = App::Dochazka::REST::Model::Shared::make_test_exists( 'iid' );
}

=head2 fetch_by_eid_and_tsrange

Boilerplate.

=cut

sub fetch_by_eid_and_tsrange {
    my ( $eid, $tsrange ) = @_;

    return load_multiple(
        class => __PACKAGE__,
        sql => $site->SQL_INTERVAL_SELECT_BY_EID_AND_TSRANGE,
        keys => [ $eid, $tsrange ],
    );
}


=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

