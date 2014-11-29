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
#
# basic unit tests for schedules and schedule intervals
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use DBI;
use App::Dochazka::REST;
use App::Dochazka::REST::Model::Employee;
use App::Dochazka::REST::Model::Schedule qw( sid_exists get_schedule_json );
use App::Dochazka::REST::Model::Schedhistory;
use App::Dochazka::REST::Model::Schedintvls;
use App::Dochazka::REST::Model::Shared qw( noof );
use App::Dochazka::REST::Util::Timestamp qw( $today $today_ts $yesterday $tomorrow );
use Scalar::Util qw( blessed );
use Test::JSON;
use Test::More; 

# plan tests

#plan skip_all => "Set DOCHAZKA_TEST_MODEL to activate data model tests" if ! defined $ENV{'DOCHAZKA_TEST_MODEL'};

# initialize (load configuration and connect to database)
my $REST = App::Dochazka::REST->init( sitedir => '/etc/dochazka-rest' );
if ( $REST->{init_status}->not_ok ) {
    plan skip_all => "not configured or server not running";
}

# spawn and insert employee object
is( noof( "employees" ), 2 );

my $emp = App::Dochazka::REST::Model::Employee->spawn(
    nick => 'mrsched',
    remark => 'SCHEDULE TESTING OBJECT',
);
my $status = $emp->insert;
ok( $status->ok, "Schedule testing object inserted" );
ok( $emp->eid > 0, "Schedule testing object has an EID" );

# insert some intervals into the scratch table

# at the beginning, count of schedintvls should be 0
is( noof( 'schedintvls' ), 0 );

# spawn a schedintvls ("scratch schedule") object
my $schedintvls = App::Dochazka::REST::Model::Schedintvls->spawn;
ok( ref($schedintvls), "object is a reference" );
ok( blessed($schedintvls), "object is a blessed reference" );
ok( defined( $schedintvls->{ssid} ), "Scratch SID is defined" ); 
ok( $schedintvls->{ssid} > 0, "Scratch SID is > 0" ); 

# insert a schedule (i.e. a list of schedintvls)
$schedintvls->{intvls} = [
    "[$tomorrow 12:30, $tomorrow 16:30)",
    "[$tomorrow 08:00, $tomorrow 12:00)",
    "[$today 12:30, $today 16:30)",
    "[$today 08:00, $today 12:00)",
    "[$yesterday 12:30, $yesterday 16:30)",
    "[$yesterday 08:00, $yesterday 12:00)",
];

# insert all the schedintvls in one go
$status = $schedintvls->insert;
diag( $status->text ) unless $status->ok;
ok( $status->ok, "OK scratch intervals inserted OK" );
ok( $schedintvls->ssid, "OK there is a scratch SID" );
is( scalar @{ $schedintvls->{intvls} }, 6, "Object now has 6 intervals" );

# after insert, count of schedintvls should be 6
is( noof( 'schedintvls' ), 6 );

# load the schedintvls, translating them as we go
$status = $schedintvls->load;
ok( $status->ok, "OK scratch intervals translated OK" );
is( scalar @{ $schedintvls->{intvls} }, 6, "Still have 6 intervals" );
is( scalar @{ $schedintvls->{schedule} }, 6, "And now have 6 translated intervals as well" );
like( $status->code, qr/6 rows/, "status code says 6 rows" );
like( $status->text, qr/6 rows/, "status code says 6 rows" );
ok( exists $schedintvls->{schedule}->[0]->{high_time}, "Conversion to hash OK" );
is_valid_json( $schedintvls->json );

# Now we can insert the JSON into the schedules table
my $schedule = App::Dochazka::REST::Model::Schedule->spawn(
    schedule => $schedintvls->json,
    remark => 'TESTING',
);
$status = $schedule->insert;
ok( $status->ok, "Schedule insert OK" );
ok( $schedule->sid > 0, "There is an SID" );
is_valid_json( $schedule->schedule );
is( $schedule->remark, 'TESTING' );

# Attempt to change the 'schedule' field to a bogus string
my $saved_sched_obj = $schedule->clone;
$schedule->schedule( 'BOGUS STRING' );
is( $schedule->schedule, 'BOGUS STRING' );
$status = $schedule->update;
is( $status->level, 'OK' );
my $new_sched_obj = App::Dochazka::REST::Model::Schedule->spawn( $status->payload );
ok( ! $schedule->compare( $saved_sched_obj ) );
ok( $schedule->compare_disabled( $saved_sched_obj ) );

# Attempt to change the 'sid' field
$saved_sched_obj = $schedule->clone;
$schedule->sid( 99943 );
is( $schedule->{sid}, 99943 );
$status = $schedule->update;
is( $status->level, 'NOTICE' );
is( $status->code, 'DOCHAZKA_CUD_NO_RECORDS_AFFECTED' );
ok( ! defined( $status->payload ) );
#is( $status->payload->{sid}, 99943 ); # from the payload it appears that the update worked
# but the value in the database is unchanged - the 'sid' and 'schedule' fields are never updated
$status = App::Dochazka::REST::Model::Schedule->load_by_sid( $saved_sched_obj->sid );
is( $status->level, 'OK' );
is( $status->payload->{sid}, $saved_sched_obj->sid ); # no real change
$schedule = $status->payload;

# in other words, nothing changed

# And now we can delete the schedintvls object and its associated database rows
$status = $schedintvls->delete;
ok( $status->ok, "scratch intervals deleted" );
like( $status->text, qr/6 record/, "Six records deleted" );
is( noof( 'schedintvls' ), 0 );

# Make a bogus schedintvls object and attempt to delete it
my $bogus_intvls = App::Dochazka::REST::Model::Schedintvls->spawn(
);
$status = $bogus_intvls->delete;
is( $status->level, 'WARN', "Could not delete bogus intervals" );

# Attempt to re-insert the same schedule
my $sid_copy = $schedule->sid;        # store a local copy of the SID
my $sched_copy = $schedule->schedule; # store a local copy of the schedule (JSON)
$schedule->reset;		      # reset object to factory settings
$schedule->{schedule} = $sched_copy;  # set up object to "re-insert" the same schedule
is( $schedule->{sid}, undef, "SID Is undefined at this point" );
$status = $schedule->insert;
ok( $status->ok );
is( $schedule->{sid}, $sid_copy );    # SID is unchanged

# attempt to insert the same schedule string in a completely 
# new schedule object
is( noof( 'schedules' ), 1, "schedules row count is 1" );
my $schedule2 = App::Dochazka::REST::Model::Schedule->spawn(
    schedule => $sched_copy,
    remark => 'DUPLICATE',
);
is_valid_json( $schedule2->schedule, "String is valid JSON" );
$status = $schedule2->insert;
ok( $schedule2->sid > 0, "SID was assigned" );
ok( $status->ok, "Schedule insert OK" );
is( $schedule2->sid, $sid_copy, "But SID is the same as before" );
is( noof( 'schedules' ), 1, "schedules row count is still 1" );

# tests for get_schedule_json function
my $json = get_schedule_json( $sid_copy );
is( ref( $json ), 'ARRAY' );
is( get_schedule_json( 994), undef, "Non-existent SID" );

# Now that we finally have the schedule safely in the database,
# we can assign it to the employee (Mr. Sched) by inserting a record 
# in the schedhistory table
my $schedhistory = App::Dochazka::REST::Model::Schedhistory->spawn(
    eid => $emp->{eid},
    sid => $schedule->{sid},
    effective => $today,
    remark => 'TESTING',
);
is( ref( $schedhistory ), 'App::Dochazka::REST::Model::Schedhistory', "schedhistory object is an object" );

# test schedhistory accessors
is( $schedhistory->eid, $emp->{eid} );
is( $schedhistory->sid, $schedule->{sid} );
is( $schedhistory->effective, $today );
is( $schedhistory->remark, 'TESTING' );

$status = undef;
$status = $schedhistory->insert;
ok( $status->ok, "OK schedhistory insert OK" );
ok( defined( $schedhistory->shid), "schedhistory object has shid" );
ok( $schedhistory->shid > 0, "schedhistory object shid is > 0" );
is( $schedhistory->eid, $emp->{eid} );
is( $schedhistory->sid, $schedule->{sid} );
is( $schedhistory->effective, "$today_ts+01" );
is( $schedhistory->remark, 'TESTING' );
is( noof( 'schedhistory' ), 1 );

# do a dastardly deed (insert the same schedhistory row a second time)
my $dastardly_sh = App::Dochazka::REST::Model::Schedhistory->spawn(
    eid => $emp->{eid},
    sid => $schedule->{sid},
    effective => $today,
    remark => 'Dastardly',
);
is( ref( $dastardly_sh ), 'App::Dochazka::REST::Model::Schedhistory', "schedhistory object is an object" );
$status = undef;
$status = $dastardly_sh->insert;
is( $status->level, 'ERR', "OK schedhistory insert OK" );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/duplicate key value violates unique constraint \"schedhistory_eid_effective_key\"/ );

# and now Mr. Sched's employee object should contain the schedule
$status = App::Dochazka::REST::Model::Employee->load_by_eid( $emp->{eid} );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );

# try to load the same schedhistory record into an empty object
my $sh2 = App::Dochazka::REST::Model::Schedhistory->spawn;
ok( blessed( $sh2 ) );
$status = undef;
$status = $sh2->load_by_eid( $emp->eid ); # get the current record
ok( $status->ok );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( ref $status->payload );
ok( $status->payload->isa( 'App::Dochazka::REST::Model::Schedhistory' ) );
$sh2->reset( $status->payload );
is( $sh2->shid, $schedhistory->shid );
is( $sh2->eid, $schedhistory->eid);
is( $sh2->sid, $schedhistory->sid);
is( $sh2->effective, $schedhistory->effective);
is( $sh2->remark, $schedhistory->remark);
# 
# Tomorrow this same schedhistory record will still be valid
$sh2->reset;
$status = $sh2->load_by_eid( $emp->eid, $tomorrow );
ok( $status->ok );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( ref $status->payload );
ok( $status->payload->isa( 'App::Dochazka::REST::Model::Schedhistory' ) );
$sh2->reset( $status->payload );
is( $sh2->shid, $schedhistory->shid );
my $shid_copy = $sh2->shid;
is( $sh2->eid, $schedhistory->eid);
is( $sh2->sid, $schedhistory->sid);
is( $sh2->effective, $schedhistory->effective);
is( $sh2->remark, $schedhistory->remark);

# but it wasn't valid yesterday
$sh2->reset;
$status = $sh2->load_by_eid( $emp->eid, $yesterday );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND' );
is( $sh2->shid, undef );
is( $sh2->eid, undef );
is( $sh2->sid, undef );
is( $sh2->effective, undef );
is( $sh2->remark, undef );

# CLEANUP
# 1. delete the schedhistory record
is( noof( 'schedhistory' ), 1 );
$sh2->{shid} = $shid_copy;
$status = $sh2->delete;
diag( $status->text ) unless $status->ok;
ok( $status->ok );
is( noof( 'schedhistory' ), 0 );

# 2. delete the schedule
is( noof( 'schedules' ), 1 );
ok( sid_exists( $sid_copy ) );
$status = $schedule->load_by_sid( $sid_copy );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
$schedule = $status->payload;
$status = $schedule->delete;
diag( $status->text ) unless $status->ok;
ok( $status->ok );
ok( ! sid_exists( $sid_copy ) );
is( noof( 'schedules' ), 0 );

# 3. delete the employee (Mr. Sched)
is( noof( 'employees' ), 3 );
$status = $emp->delete;
ok( $status->ok );
is( noof( 'employees' ), 2 );

done_testing;
