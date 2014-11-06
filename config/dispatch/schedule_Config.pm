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

This resource returns a list (array) of all schedules, regardless of thie contents
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
#            GET => '_history_eid', 
#            PUT => '_history_eid',
#            DELETE => '_history_eid',
            GET => 'not_implemented', 
            PUT => 'not_implemented',
            DELETE => 'not_implemented',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin',
        cli => 'schedule history eid $EID [$JSON]',
        description => 'GET: Get entire history of schedule changes for employee with the given EID, PUT: add a record to schedule history of employee, DELETE: delete a schedule record',
        documentation => <<'EOH',
=pod

=over

=item GET

Retrieves the "schedule history", or history of changes in
schedule, of the employee with the given EID.

=item PUT

Adds a record to the schedule history of the given employee. The content
body should contain two properties: "effective" (timestamp) and "sid" (integer).

=item DELETE

Deletes a record from the schedule history of the given employee. The content
body should contain two properties: "effective" (timestamp) and "sid" (integer).

=back
EOH
    },
    'schedule/history/eid/:eid/:tsrange' =>
    {
        target => {
#            GET => '_history_eid', 
            GET => 'not_implemented', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin',
        cli => 'schedule history eid $EID $TSRANGE',
        description => 'Get a slice of history of schedule changes for employee with the given EID',
        documentation => <<'EOH',
=pod

Retrieves a slice (given by the tsrange argument) of the employee's
"schedule history" (history of changes in schedule).
EOH
    },
    'schedule/history/nick/:nick' =>
    { 
        target => {
#            GET => '_history_nick', 
#            PUT => '_history_nick', 
#            DELETE => '_history_nick',
            GET => 'not_implemented', 
            PUT => 'not_implemented',
            DELETE => 'not_implemented',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin',
        cli => 'schedule history nick $NICK [$JSON]',
        description => 'Get entire history of schedule changes for employee with the given nick',
        documentation => <<'EOH',
=pod

=over

=item GET

Retrieves the "schedule history", or history of changes in
schedule, of the employee with the given nick.

=item PUT

Adds a record to the schedule history of the given employee. The content
body should contain two properties: "effective" (timestamp) and "sid" (integer).

=item DELETE

Deletes a record from the schedule history of the given employee. The content
body should contain two properties: "effective" (timestamp) and "sid" (integer).

=back
EOH
    },
    'schedule/history/nick/:nick/:tsrange' =>
    { 
        target => {
#            GET => '_history_nick', 
            GET => 'not_implemented', 
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
#            GET => '_history_self', 
            GET => 'not_implemented', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'active',
        cli => 'schedule history current [$TSRANGE]',
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
#            GET => '_schedule_by_shid',
#            DELETE => '_schedule_by_shid',
            GET => 'not_implemented', 
            DELETE => 'not_implemented', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin',
        cli => 'schedule history shid $SHID',
        description => 'GET or DELETE a schedule record by its SHID',
        documentation => <<'EOH',
=pod

=over

=item GET

Retrieves a schedule history record by its SHID.

=item DELETE

Deletes a schedule history record by its SHID.

=back

(N.B.: to add a schedule history record, use "PUT schedule/history/eid/:eid" or
"PUT schedule/history/nick/:nick")
EOH
    },
    'schedule/intervals' => 
    { 
        target => {
            POST => '_intervals_post',
            DELETE => '_intervals_delete',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin', 
        cli => 'schedule intervals',
        description => 'Insert and delete schedules',
        documentation => <<'EOH',
=pod

Inserts (POST) or deletes (DELETE) a schedule.

=over

=item POST

The request body must contain an array of non-overlapping tsranges (intervals)
that fall within a 168-hour (7-day) period. If successful, the payload will
contain three properties: 'ssid' (containing the SSID assigned to the
intervals), 'intervals' (containing the intervals themselves), and 'schedule'
(containing the intervals converted into the format suitable for insertion into
the 'schedule' table).

If the exact schedule already exists in the database, the POST operation
returns it.  Instead of DISPATCH_SCHEDULE_INSERT_OK, in this case the return
status code will be DISPATCH_SCHEDULE_OK.

=item DELETE

An 'ssid' property must be given as a property in the request body. If found,
the scratch schedule will be deleted in an atomic operation. If the SSID is
found and the delete operation is successful, the status will be "OK".

=back
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
            GET => '_intervals_get',
            POST => '_schedule_post', 
            DELETE => '_intervals_delete',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'admin', 
        cli => 'schedule sid $SID',
        description => 'Retrieve (GET), update (POST) or delete (DELETE) a schedule by its SID',
        documentation => <<'EOH',
=pod

Retrieves (GET), updates (POST), or deletes (DELETE) a schedule by its SID.

=over

=item GET

An integer SID must be given as an URI parameter. If a schedule
with this SID is found, it is returned in the payload.

=item POST

This resource/method provides a way to set (modify) the 'remark' and 'disabled'
fields of a schedule record. Simply provide the properties and their new values
in the request body, e.g.:

    { "remark" : "foobar", "disabled" : "t" }

=item DELETE

An integer SID must be given as an URI parameter. If found, the schedule with
that SID will be deleted in an atomic operation. If the operation is sucessful
the return status will be "OK".

=back
EOH
    },

});
