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
use Try::Tiny;

use parent 'App::Dochazka::REST::dbh';



=head1 NAME

App::Dochazka::REST::Model::Schedule - schedule functions




=head1 VERSION

Version 0.117

=cut

our $VERSION = '0.117';




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Schedule;

    ...



=head1 DESCRIPTION

A description of the schedule data model follows.



=head2 Schedules in the database


=head3 Table

Schedules are stored the C<schedules> table. For any given schedule, there is
always only one record in the table -- i.e., individual schedules can be used
for multiple employees. (For example, an organization might have hundreds of
employees on a single, unified schedule.) 

      CREATE TABLE IF NOT EXISTS schedules (
        sid        serial PRIMARY KEY,
        schedule   text UNIQUE NOT NULL,
        remark     text
      );

The value of the 'schedule' field is a JSON array which looks something like this:

    [
        { low_dow:"MON", low_time:"08:00", high_dow:"MON", high_time:"12:00" ],  
        { low_dow:"MON", low_time:"12:30", high_dow:"MON", high_time:"16:30" ],  
        { low_dow:"TUE", low_time:"08:00", high_dow:"TUE", high_time:"12:00" ],  
        { low_dow:"TUE", low_time:"12:30", high_dow:"TUE", high_time:"16:30" ],
        ...
    ]   

Or, to give an example of a more convoluted schedule:

    [   
        { low_dow:"WED", low_time:"22:15", high_dow:"THU", high_time:"03:25" ], 
        { low_dow:"THU", low_time:"05:25", high_dow:"THU", high_time:"09:55" ],
        { low_dow:"SAT", low_time:"19:05", high_dow:"SUN", high_time:"24:00" ] 
    ] 

The intervals in the JSON string must be sorted and the whitespace, etc.
must be consistent in order for the UNIQUE constraint in the 'schedule'
table to work properly. However, these precautions will no longer be
necessary after PostgreSQL 9.4 comes out and the field type is changed to
'jsonb'.


=head3 Process for creating new schedules

It is important to understand how the JSON string introduced in the previous
section is assembled -- or, more generally, how a schedule is created. Essentially,
the schedule is first created in a C<schedintvls> table, with a record for each
time interval in the schedule. This table has triggers and a C<gist> index that 
enforce schedule data integrity so that only a valid schedule can be inserted.
Once the schedule has been successfully built up in C<schedintvls>, it is 
"translated" (using a stored procedure) into a single JSON string, which is
stored in the C<schedules> table. This process is described in more detail below:  

First, if the schedule already exists in the C<schedules> table, nothing
more need be done -- we can skip to L<Schedhistory>

If the schedule we need is not yet in the database, we will have to create it.
This is a three-step process: (1) build up the schedule in the C<schedintvls>
table (sometimes referred to as the "scratch schedule" table); (2) translate
the schedule to form the schedule's JSON representation; (3) insert the JSON
string into the C<schedules> table.

The C<schedintvls>, or "scratch schedule", table:

      CREATE SEQUENCE scratch_sid_seq;

      CREATE TABLE IF NOT EXISTS schedintvls (
          scratch_sid  integer NOT NULL,
          intvl        tsrange NOT NULL,
          EXCLUDE USING gist (scratch_sid WITH =, intvl WITH &&)
      );

As stated above, before the C<schedule> table is touched, a "scratch schedule"
must first be created in the C<schedintvls> table. Although this operation
changes the database, it should be seen as a "dry run". The C<gist> index and
a trigger assure that:

=over

=item * no overlapping entries are entered

=item * all the entries fall within a single 168-hour period

=item * all the times are evenly divisible by five minutes

=back

#
# FIXME: expand the trigger to check for "closed-open" C<< [ ..., ... ) >> tsrange
#

If the schedule is successfully inserted into C<schedintvls>, the next step is
to "translate", or convert, the individual intervals (expressed as tsrange
values) into the four-key hashes described in L<Schedules in the database>,
assemble the JSON string, and insert a new row in C<schedules>. 

To facilitate this conversion, a stored procedure C<translate_schedintvl> was
developed.

Successful insertion into C<schedules> will generate a Schedule ID (SID) for
the schedule, enabling it to be used to make Schedhistory objects.

At this point, the scratch schedule is deleted from the C<schedintvls> table. 


=head2 Schedules in the Perl API


=head3 L<Schedintvls> class

=over 

=item * constructor (L<spawn>)

=item * L<reset> method (recycles an existing object)

=item * basic accessors (L<scratch_sid> and L<remark>)

=item * L<intvls> accessor (arrayref containing all tsrange intervals in schedule) 

=item * L<schedule> accessor (arrayref containing "translated" intervals)

=item * L<load> method (load the object from the database and translate the tsrange intervals)

=item * L<insert> method (insert all the tsrange elements in one go)

=item * L<delete> method (delete all the tsrange elements when we're done with them)

=item * L<json> method (generate JSON string from the translated intervals)

=back

For basic workflow, see C<t/007-schedule.t>.


=head3 C<Schedule> class

=over

=item * constructor (L<spawn>)

=item * L<reset> method (recycles an existing object)

=item * basic accessors (L<sid>, L<schedule>, L<remark>)

=item * L<insert> method (inserts the schedule if it isn't in the database already)

=item * L<delete> method

=item * L<load> method (not implemented yet) 

=item * L<get_json> function (get JSON string associated with a given SID)

=back

For basic workflow, see C<t/007-schedule.t>.




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
    $self->{sid} = $self->dbh->selectrow_array( $site->SQL_SCHEDULES_SELECT_SID, 
                   undef, $self->{schedule} );    
    return $CELL->status_ok( "This schedule has SID " . $self->{sid} ) 
        if defined $self->{sid};
    return $CELL->status_err( $self->dbh->errstr ) if $self->dbh->err;

    # no exact match found, insert a new record
    my $status = cud(
        $self,
        $site->SQL_SCHEDULE_INSERT,
        ( 'schedule', 'remark' ),
    );
    $log->info( "Inserted new schedule with SID" . $self->{sid} ) if $status->ok;

    return $status;
}


=head2 update

There is no update method for schedules. To update a schedule, delete it
and then re-create it (see Spec.pm for a description of how to do this, 
or refer to t/007-schedule.t).


=head2 delete

Instance method. Attempts to DELETE a schedule record. This may succeed
if no other records in the database refer to this schedule.

=cut

sub delete {
    my ( $self ) = @_;

    my $status = cud(
        $self,
        $site->SQL_SCHEDULE_DELETE,
        ( 'sid' ),
    );
    $self->reset( sid => $self->{sid} ) if $status->ok;

    return $status;
}


=head2 load_by_sid

Given a SID, load the schedule into the object. Returns a status value.

=cut

sub load_by_sid {
    my ( $self, $sid ) = @_;
    my $status;

    $self->dbh->{RaiseError} = 1;
    try {
        my $results = $self->dbh->selectrow_hashref( 
            $site->SQL_SCHEDULE_SELECT,
            undef,
            $sid 
        );
        if ( $results ) {
            map { $self->{$_} = $results->{$_}; } ( 'sid', 'schedule', 'remark' );
            $status = $CELL->status_ok( 'DOCHAZKA_RECORDS_FETCHED', 1);
        } else {
            $status = $CELL->status_warn( 'DOCHAZKA_RECORDS_FETCHED', 0 );
        }
    } catch {
        $status = $CELL->status_err( $self->dbh->errstr );
    };
    $self->dbh->{RaiseError} = 0;

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

