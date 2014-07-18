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

package App::Dochazka::REST::Model::Schedhistory;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $CELL $log $meta $site );
use Carp;
use Data::Dumper;
use App::Dochazka::REST::Model::Shared qw( cud );
use DBI;



=head1 NAME

App::Dochazka::REST::Model::Schedhistory - schedule history functions




=head1 VERSION

Version 0.076

=cut

our $VERSION = '0.076';




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Schedhistory;

    ...



=head1 DESCRIPTION

A description of the schedhistory data model follows.


=head2 Schedhistory in the database

=head3 Table

Once we know the SID of the schedule we would like to assign to a given
employee, it is time to insert a record into the C<schedhistory> table:

      CREATE TABLE IF NOT EXISTS schedhistory (
        int_id     serial PRIMARY KEY,
        eid        integer REFERENCES employees (eid) NOT NULL,
        sid        integer REFERENCES schedules (sid) NOT NULL,
        effective  timestamp NOT NULL,
        remark     text,
        stamp      json
      );

=head3 Stored procedures

This table also includes two stored procedures -- C<schedule_at_timestamp> and
C<current_schedule> -- which will return an employee's schedule as of a given
date/time and as of 'now', respectively. For the procedure definitions, see
C<dbinit_Config.pm>

See also L<When history changes take effect>.


=head2 Schedhistory in the Perl API

=over

=item * constructor (L<spawn>)

=item * L<reset> method (recycles an existing object)

=item * basic accessors (L<int_id>, L<eid>, L<sid>, L<effective>, L<remark>)

=item * L<load> method (load schedhistory record from EID and optional timestamp)

=item * L<insert> method (straightforward)

=item * L<delete> method (straightforward) -- not tested yet # FIXME

=back

For basic workflow, see C<t/007-schedule.t>.




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

Instance method. Resets object, either to its primal state (no arguments)
or to the state given in PARAMHASH.

=cut

BEGIN {
    no strict 'refs';
    *{"reset"} = App::Dochazka::REST::Model::Shared::make_reset(
        'int_id', 'eid', 'sid', 'effective', 'remark' 
    );
}



=head2 Accessor methods

Basic accessor methods for all the fields of Schedhistory table. These
functions return whatever value happens to be associated with the object,
with no guarantee that it matches the database.

=cut

BEGIN {
    foreach my $subname ( 'int_id', 'eid', 'sid', 'effective', 'remark') {
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


=head3 sid

Accessor method.


=head3 effective

Accessor method.


=head3 remark

Accessor method.



=head2 load

Instance method. Given an EID, and, optionally, a timestamp, loads a single
Schedhistory record into the object, rewriting whatever was there before.
Returns a status object.

=cut

sub load {
    my ( $self, $eid, $ts ) = @_;
    my $dbh = $self->{dbh};
    my @attrs = ( 'int_id', 'eid', 'sid', 'effective', 'remark' );
    my ( $sql, $result );
    if ( $ts ) {
        # timestamp given
        $sql = $site->SQL_SCHEDHISTORY_SELECT_ARBITRARY;
        $result = $dbh->selectrow_hashref( $sql, undef, $eid, $ts );
    } else {
        # no timestamp - use 'now'
        $sql = $site->SQL_SCHEDHISTORY_SELECT_CURRENT;
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

Instance method. Attempts to INSERT a record into the 'Schedhistory' table.
Field values are taken from the object. Returns a status object.

=cut

# FIXME: use cud
sub insert {
    my ( $self ) = @_;

    my $status = cud(
        $self,
        $site->SQL_SCHEDHISTORY_INSERT,
        ( 'eid', 'sid', 'effective', 'remark' ),
    );

    return $status;
}


=head2 update

There is no update method for schedhistory records. Instead, delete and
re-create.


=head2 delete

Instance method. Deletes the record. Returns status object.

=cut

sub delete {
    my ( $self ) = @_;

    my $status = cud(
        $self,
        $site->SQL_SCHEDHISTORY_DELETE,
        ( 'int_id' ),
    );
    $self->reset( 'int_id' => $self->{int_id} ) if $status->ok;

    return $status;
}




=head1 EXAMPLES

In this section, some examples are presented to give an idea of how this
module is used.


=head2 Sam Wallace joins the firm

Let's say Sam's initial schedule is 09:00-17:00, Monday to Friday. To
reflect that, the C<schedintvls> table might contain the following intervals
for C<< sid = 9 >>

    '[2014-06-02 09:00, 2014-06-02 17:00)'
    '[2014-06-03 09:00, 2014-06-03 17:00)'
    '[2014-06-04 09:00, 2014-06-04 17:00)'
    '[2014-06-05 09:00, 2014-06-05 17:00)'
    '[2014-06-06 09:00, 2014-06-06 17:00)'

and the C<schedhistory> table would contain a record like this:

    sid       848 (automatically assigned by PostgreSQL)
    eid       39 (Sam's Dochazka EID)
    sid       9
    effective '2014-06-04 00:00'

(This is a straightfoward example.)


=head2 Sam goes on night shift

A few months later, Sam gets assigned to the night shift. A new
C<schedhistory> record is added:

    int_id     1215 (automatically assigned by PostgreSQL)
    eid        39 (Sam's Dochazka EID)
    sid        17 (link to Sam's new weekly work schedule)
    effective  '2014-11-17 12:00'

And the schedule intervals for C<< sid = 17 >> could be:

    '[2014-06-02 23:00, 2014-06-03 07:00)'
    '[2014-06-03 23:00, 2014-06-04 07:00)'
    '[2014-06-04 23:00, 2014-06-05 07:00)'
    '[2014-06-05 23:00, 2014-06-06 07:00)'
    '[2014-06-06 23:00, 2014-06-07 07:00)'
    
(Remember: the date part in this case designates the day of the week)




=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;



