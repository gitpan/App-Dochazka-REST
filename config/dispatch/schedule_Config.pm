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

# -----------------------------------
# App::Dochazka::REST
# -----------------------------------
# config/dispatch/schedule_Config.pm
#
# Path dispatch configuration file for schedule  resources
# -----------------------------------


# DISPATCH_RESOURCES_SCHEDULE
#    - value is a hash, the keys of which are resource paths
#    - the values of those keys are hashes containing resource metadata
set( 'DISPATCH_RESOURCES_SCHEDULE', {

    'schedule/all' => 
    { 
        target => {
            GET => 'schedule_all',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin', 
        cli => 'schedule all',
        description => 'Retrieves (GET) all non-disabled schedules',
        documentation => <<'EOH',
=pod

This resource returns a list (array) of all schedules for which the 'disabled' field has
either not been set or has been set to 'false'.
EOH
    },
    'schedule/all/disabled' => 
    { 
        target => {
            GET => 'schedule_all_disabled',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin', 
        cli => 'schedule all disabled',
        description => 'Retrieves (GET) all schedules (disabled and non-disabled)',
        documentation => <<'EOH',
=pod

This resource returns a list (array) of all schedules, regardless of the contents
of the 'disabled' field.
EOH
    },
    'schedule/eid/:eid/?:ts' => 
    { 
        target => {
            GET => '_current_schedule',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin', 
        cli => 'schedule eid $EID [$TIMESTAMP]',
        description => 'Get the current schedule of arbitrary employee, or with optional timestamp, that employee\'s schedule as of that timestamp',
        documentation => <<'EOH',
=pod

This resource retrieves the schedule of an arbitrary employee specified by EID.

If no timestamp is given, the current schedule is retrieved. If a timestamp
is present, the schedule as of that timestamp is retrieved.
EOH
    },
    'schedule/help' =>
    { 
        target => {
            GET => '_get_default',
            POST => '_post_default',
            PUT => '_put_default',
            DELETE => '_delete_default',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'passerby', 
        cli => 'schedule help',
        description => 'Display schedule resources',
        documentation => <<'EOH',
=pod

This resource retrieves a listing of all schedule resources available to the
caller (currently logged-in employee).
EOH
    },
    'schedule/history/eid/:eid' =>
   { 
        target => {
            GET => '_history_eid', 
            POST => '_history_eid',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin',
        cli => 'schedule history eid $EID [$JSON]',
        description => 'Retrieves (GET) entire history of schedule changes for employee with the given EID; adds (POST) a record to schedule history of employee',
        documentation => <<'EOH',
=pod

=over

=item * GET

Retrieves the "schedule history", or history of changes in
schedule, of the employee with the given EID.

=item * POST

Adds a record to the schedule history of the given employee. The content
body should contain two properties: "effective" (timestamp) and "sid" (integer).

=back

Update note: histories can be updated by adding new records and deleting old
ones. Existing history records cannot be changed. Adds/deletes should be
performed with due care - especially with regard to existing employee
attendance data (if any).
EOH
    },
    'schedule/history/eid/:eid/:tsrange' =>
    {
        target => {
            GET => '_history_eid', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin',
        cli => 'schedule history eid $EID $TSRANGE',
        description => 'Retrieves a slice of history of schedule changes for employee with the given EID',
        documentation => <<'EOH',
=pod

Retrieves a slice (given by the tsrange argument) of the employee's
"schedule history" (history of changes in schedule). 
EOH
    },
    'schedule/history/nick/:nick' =>
    { 
        target => {
            GET => '_history_nick', 
            POST => '_history_nick', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin',
        cli => 'schedule history nick $NICK [$JSON]',
        description => 'Retrieves (GET) entire history of schedule changes for employee with the given nick; adds (POST) a record to schedule history of employee',
        documentation => <<'EOH',
=pod

=over

=item * GET

Retrieves the "schedule history", or history of changes in
schedule, of the employee with the given nick.

=item * POST

Adds a record to the schedule history of the given employee. The content
body should contain two properties: "effective" (timestamp) and "sid" (integer).

=back

Update note: histories can be updated by adding new records and deleting old
ones. Existing history records cannot be changed. Adds/deletes should be
performed with due care - especially with regard to existing employee
attendance data (if any).
EOH
    },
    'schedule/history/nick/:nick/:tsrange' =>
    { 
        target => {
            GET => '_history_nick', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin',
        cli => 'schedule history nick $NICK $TSRANGE',
        description => 'Get partial history of schedule changes for employee with the given nick ' . 
                     '(i.e, limit to given tsrange)',
        documentation => <<'EOH',
=pod

Retrieves a slice (given by the tsrange argument) of the employee's
"schedule history" (history of changes in schedule).
EOH
    },
    'schedule/history/self/?:tsrange' =>
    { 
        target => {
            GET => '_history_self', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'inactive',
        cli => 'schedule history self [$TSRANGE]',
        description => 'Get schedule history of current employee, with option to limit to :tsrange',
        documentation => <<'EOH',
=pod

This resource retrieves the "schedule history", or history of changes in
schedule, of the current employee. Optionally, the listing can be
limited to a specific tsrange such as "[2014-01-01, 2014-12-31)".
EOH
    },
    'schedule/history/shid/:shid' => 
    {
        target => {
            GET => '_sched_by_shid',
            DELETE => '_sched_by_shid',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin',
        cli => 'schedule history shid $SHID',
        description => 'GET or DELETE a schedule record by its SHID',
        documentation => <<'EOH',
=pod

=over

=item * GET

Retrieves a schedule history record by its SHID.

=item * DELETE

Deletes a schedule history record by its SHID.

=back

(N.B.: history records can be added using POST requests on "priv/history/eid/:eid" or
"priv/history/nick/:nick")
EOH
    },
    'schedule/new' => 
    { 
        target => {
            POST => '_intervals_post',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin', 
        cli => 'schedule new $JSON',
        description => 'Insert schedules',
        documentation => <<'EOH',
=pod

Given a set of intervals, all of which must fall within a single contiguous
168-hour (7-day) period, this resource performs all actions necessary to either
create a new schedule from those intervals or verify that an equivalent
schedule already exists.

Sample JSON:

    { "schedule" : [
        "[2014-09-22 08:00, 2014-09-22 12:00)",
        "[2014-09-22 12:30, 2014-09-22 16:30)",
        "[2014-09-23 08:00, 2014-09-23 12:00)",
        "[2014-09-23 12:30, 2014-09-23 16:30)",
        "[2014-09-24 08:00, 2014-09-24 12:00)",
        "[2014-09-24 12:30, 2014-09-24 16:30)",
        "[2014-09-25 08:00, 2014-09-25 12:00)",
        "[2014-09-25 12:30, 2014-09-25 16:30)"
    ] }

Read on for details:

First, a set of scratch intervals is created in the 'schedintvls' table.
If this succeeds, an INSERT operation is used to create a new record in the
'schedule' table. This operation has two possible successful outcomes 
depending on whether such a schedule already existed in the database, or not.
The status codes for these outcomes are DISPATCH_SCHEDULE_OK and
DISPATCH_SCHEDULE_INSERT_OK, respectively.

In both cases, the underlying scratch intervals are deleted automatically.
(All operations on the 'schedintlvs' table are supposed to be hidden from 
Dochazka clients.) 

Note that many sets of intervals can map to a single schedule (the conversion
process is only interested in the day of the week), so this resource may return
DISPATCH_SCHEDULE_OK more often than you think.

Whether or not the exact schedule existed already, if the underlying database
operation is successful the payload will contain three properties: 'sid' (the
SID assigned to the schedule containing the intervals), 'intervals' (the
intervals themselves), and 'schedule' (the intervals as they appear after being
converted into the format suitable for insertion into the 'schedule' table).

N.B. At present there is no way to just check for the existence of a schedule
corresponding to a given set of intervals. 
EOH
    },
    'schedule/nick/:nick/?:ts' => 
    { 
        target => {
            GET => '_current_schedule',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin', 
        cli => 'schedule nick $NICK [$TIMESTAMP]',
        description => 'Get the current schedule of arbitrary employee, or with optional timestamp, that employee\'s schedule as of that timestamp',
        documentation => <<'EOH',
=pod

This resource retrieves the schedule of an arbitrary employee specified by nick.

If no timestamp is given, the current schedule is retrieved. If a timestamp
is present, the schedule as of that timestamp is retrieved.
EOH
    },
    'schedule/self/?:ts' => 
    { 
        target => {
            GET => '_current_schedule',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'passerby', 
        cli => 'schedule current [$TIMESTAMP]',
        description => 'Get the current schedule of the currently logged-in employee, or with optional timestamp, that employee\'s schedule as of that timestamp',
        documentation => <<'EOH',
=pod

This resource retrieves the schedule of the caller (currently logged-in employee).

If no timestamp is given, the current schedule is retrieved. If a timestamp
is present, the schedule as of that timestamp is retrieved.
EOH
    },
    'schedule/sid/:sid' => 
    { 
        target => {
            GET => '_schedule_get',
            POST => '_schedule_post', 
            DELETE => '_schedule_delete',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin', 
        cli => 'schedule sid $SID',
        description => 'Retrieves, updates, or deletes a schedule by its SID',
        documentation => <<'EOH',
=pod

=over

=item * GET

An integer SID must be given as an URI parameter. If a schedule
with this SID is found, it is returned in the payload.

=item * POST

This resource/method provides a way to set (modify) the 'remark' and 'disabled'
fields of a schedule record. Simply provide the properties and their new values
in the request body, e.g.:

    { "remark" : "foobar", "disabled" : "t" }

=item * DELETE

An integer SID must be given as an URI parameter. If found, the schedule with
that SID will be deleted in an atomic operation. If the operation is sucessful
the return status will be "OK".

=back
EOH
    },

});
