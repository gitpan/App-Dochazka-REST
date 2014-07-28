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

package App::Dochazka::REST::Model::Activity;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $CELL $log $meta $site );
use Carp;
use Data::Dumper;
use App::Dochazka::REST::Model::Shared qw( cud priv_by_eid );
use DBI;

use parent 'App::Dochazka::REST::dbh';



=head1 NAME

App::Dochazka::REST::Model::Activity - activity data model




=head1 VERSION

Version 0.106

=cut

our $VERSION = '0.106';




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Activity;

    ...


=head1 DATA MODEL

=head2 Activities in the database 


   CREATE TABLE activities (
       aid        serial PRIMARY KEY,
       code       varchar(32) UNIQUE NOT NULL,
       long_desc  text,
       remark     text
   )

Activity codes will always be in ALL CAPS thanks to a trigger (entitled 
C<code_to_upper>) that runs the PostgreSQL C<upper> function on the code
before every INSERT and UPDATE on this table.



=head2 Activities in the Perl API

=over

=item * constructor (L<spawn>)

=item * basic accessors (L<aid>, L<code>, L<long_desc>, L<remark>)

=item * L<reset> (recycles an existing object by setting it to desired state)

=item * L<insert> (inserts object into database)

=item * L<update> (updates database to match the object)

=item * L<delete> (deletes record from database if nothing references it)

=item * L<load_by_aid> (loads a single employee into the object)

=item * L<load_by_code> (loads a single employee into the object)

=back

L<App::Dochazka::REST::Model::Activity> also exports some convenience
functions:

=over

=item * L<aid_by_code> (given a code, returns AID)

=back

For basic C<activity> object workflow, see the unit tests in
C<t/008-activity.t>.



=head1 EXPORTS

This module provides the following exports:

=over 

=item C<aid_by_code> - function

=back

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( aid_by_code );




=head1 METHODS


=head2 spawn

Activity constructor. For details, see Employee.pm->spawn.

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
    *{"reset"} = App::Dochazka::REST::Model::Shared::make_reset( 
        'aid', 'code', 'long_desc', 'remark',
    );
}



=head2 Accessor methods

Basic accessor methods for all the fields of employees table. These
functions return whatever value happens to be associated with the object,
with no guarantee that it matches the database.

=cut

BEGIN {
    foreach my $subname ( 
        'aid', 'code', 'long_desc', 'remark',
    ) {
        no strict 'refs';
        *{"$subname"} = sub { 
            my ( $self ) = @_; 
            return $self->{$subname};
        }   
    }   
}


=head3 aid

Accessor method.

=head3 code

Accessor method.

=head3 long_desc

Accessor method.

=head3 remark

Accessor method.

=head2 insert

Instance method. Takes the object, as it is, and attempts to insert it into
the database. On success, overwrites object attributes with field values
actually inserted. Returns a status object.

=cut

sub insert {
    my ( $self ) = @_;

    my $status = cud(
        $self,
        $site->SQL_ACTIVITY_INSERT,
        ( 'code', 'long_desc', 'remark' ),
    );

    return $status;
}


=head2 update

Instance method. Assuming that the object has been prepared, i.e. the AID
corresponds to the activity to be updated and the attributes have been
changed as desired, this function runs the actual UPDATE, hopefully
bringing the database into line with the object. Overwrites all the
object's attributes with the values actually written to the database.
Returns status object.

=cut

sub update {
    my ( $self ) = @_;

    my $status = cud(
        $self,
        $site->SQL_ACTIVITY_UPDATE,
        ( 'code', 'long_desc', 'remark', 'aid'),
    );

    return $status;
}


=head2 delete

Instance method. Assuming the AID really corresponds to the activity to be
deleted, this method will execute the DELETE statement in the database. It
won't succeed if the activity has any intervals associated with it. Returns
a status object.

=cut

sub delete {
    my ( $self ) = @_;

    my $status = cud(
        $self,
        $site->SQL_ACTIVITY_DELETE,
        ( 'aid' ),
    );
    $self->reset( aid => $self->{aid} ) if $status->ok;

    return $status;
}


=head2 load_by_aid

Instance method. Loads activity from database, by AID, into existing
object, overwriting whatever was there before. The AID value given must be
an exact match. Returns a status object.

=cut

sub load_by_aid {
    my ( $self, $aid ) = @_;
    return $self->_load( aid => $aid );
}



=head2 load_by_code

Instance method. Loads activity from database, by the code provided in the
argument list, into existing object, overwriting whatever might have been
there before. The code must be an exact match. Returns a status object.

=cut

sub load_by_code {
    my ( $self, $code ) = @_;
    return $self->_load( code => $code );
}


=head3 _load

Load activity, by aid or code, into an existing object, overwriting
whatever was there before. The search key (aid or code) must be an exact
match: this function returns only 1 or 0 records. Takes one of the two
following PARAMHASHes:

    dbh => $dbh, code => $code
    dbh => $dbh, aid => $aid

=cut

sub _load {
    my ( $self, %ARGS ) = @_;
    my $sql;
    my $dbh = $self->dbh;
    $dbh->ping or die "No dbh";
    $self->reset; # reset object to primal state
    my ( $spec ) = keys %ARGS;

    if ( $spec eq 'code' ) {
        $sql = $site->SQL_ACTIVITY_SELECT_BY_CODE;
    } else {
        $sql = $site->SQL_ACTIVITY_SELECT_BY_AID;
    }

    # DBI incantations
    # N.B. - the select can only return a single record
    my $newself = $dbh->selectrow_hashref( $sql, {}, $ARGS{$spec} );
    if ( defined( $newself ) ) {
        foreach my $key ( keys %{ $newself } ) {
            $self->{$key} = $newself->{$key};
        }
        return $CELL->status_ok('DOCHAZKA_RECORDS_FETCHED', args => [1] );
    } elsif ( ! defined( $dbh->err ) ) {
        # nothing found
        return $CELL->status_warn('DOCHAZKA_RECORDS_FETCHED', args => [0] );
    }
    # DBI error
    return $CELL->status_err( $dbh->errstr );
}


=head1 FUNCTIONS

The following functions are not object methods.


=head2 aid_by_code

Given a database handle and a code, attempt ot retrieve the
AID corresponding to the code. Returns AID or undef on failure.

=cut

sub aid_by_code {
    my ( $dbh, $code ) = @_;
    croak "Must provide database handle and code" 
        if ! defined($dbh) or ! defined( $code );
    my $act = __PACKAGE__->spawn(
        dbh => $dbh,
    );
    my $status = $act->load_by_code( $code );
    return $act->{aid} if $status->ok;
    return;
}




=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

