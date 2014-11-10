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

package App::Dochazka::REST::Docs::Resources;

use 5.012;
use strict;
use warnings FATAL => 'all';

use App::Dochazka::REST;


our $VERSION = 0.265;

1;
__END__


=head1 NAME

App::Dochazka::REST::Docs::Resources - Documentation of App::Dochazka::REST resources


=head1 DESCRIPTION

This is a POD-only module containing documentation on all the REST resources 
defined under C<config/dispatch>. This module is auto-generated.



=head1 TOP-LEVEL RESOURCES




=head2 C</>

Display available top-level resources for given HTTP method

This is the toppest of the top-level targets or, if you wish, the 
"root target". If the base UID of your App::Dochazka::REST instance 
is http://dochazka.site:5000 and your username/password are 
"demo/demo", then this resource is triggered by either of the URLs:

    http://demo:demo@dochazka.site:5000
    http://demo:demo@dochazka.site:5000/

In terms of behavior, the "" resource is identical to "help" --
it returns the set of top-level resources available to the user.


=head2 C<activity>

Display available employee resources for given HTTP method

Lists activity resources available to the logged-in employee.


=head2 C<bugreport>

Display the address for reporting bugs in App::Dochazka::REST

Returns a "report_bugs_to" key in the payload, containing the address to
report bugs to.


=head2 C<docu>

Display on-line Plain Old Documentation (POD) on the resource whose name is provided in the request body (in double-quotes)

This resource provides access to App::Dochazka::REST on-line help
documentation. It expects to find a resource (e.g. "employee/eid/:eid"
including the double-quotes, and without leading or trailing slash) in the
request body. It returns a string containing the POD source code of the
resource documentation.


=head2 C<docu/html>

Display on-line HTML documentation on the resource whose name is provided in the request body (in double-quotes)

This resource provides access to App::Dochazka::REST on-line help
documentation. It expects to find a resource (e.g. "employee/eid/:eid"
including the double-quotes, and without leading or trailing slash) in the
request body. It returns HTML source code of the resource documentation.


=head2 C<echo>

Echo the request body

This resource simply takes whatever content body was sent and echoes it
back in the response body.


=head2 C<employee>

Display available employee resources for given HTTP method

Lists employee resources available to the logged-in employee.


=head2 C<forbidden>

A resource that is forbidden to all

This resource always returns 405 Method Not Allowed, no matter what.


=head2 C<help>

Display available top-level resources for given HTTP method

The purpose of the "help" resource is to give the user an overview of
all the top-level resources available to her, with regard to her privlevel
and the HTTP method being used.

=over

=item * If the HTTP method is GET, only resources with GET targets will be
displayed (same applies to other HTTP methods)

=item * If the user's privlevel is 'inactive', only resources whose ACL profile
is 'inactive' or lower (i.e., 'inactive' or 'passerby') will be
displayed

=back

The information provided is sent as a JSON string in the HTTP response
body, and includes the resource's name, full URI, ACL profile, and brief
description, as well as a link to the App::Dochazka::REST on-line
documentation.


=head2 C<metaparam/:param>

Display (GET) or set (PUT) meta configuration parameter

=over 

=item * GET

Assuming that the argument C<:param> is the name of an existing meta
parameter, displays the parameter's value and metadata (type, name, file and
line number where it was defined). This resource is available only to users
with C<admin> privileges.

=item * PUT

Regardless of whether C<:param> is an existing metaparam or not, set 
that parameter's value to the (entire) request body. If the request body
is "123", then the parameter will be set to that value. If it is { "value" :
123 }, then it will be set to that structure.

=item * DELETE

If the argument is an existing metaparam, delete that parameter (NOT IMPLEMENTED)

=back


=head2 C<not_implemented>

A resource that will never be implemented

Regardless of anything, returns a NOTICE status with status code
DISPATCH_RESOURCE_NOT_IMPLEMENTED


=head2 C<priv>

Display available priv resources for given HTTP method

Lists priv resources available to the logged-in employee.


=head2 C<schedule>

Display available schedule resources for given HTTP method

Lists schedule resources available to the logged-in employee.


=head2 C<session>

Display the current session

Dumps the current session data (server-side).


=head2 C<siteparam/:param>

Display site configuration parameter

Assuming that the argument ":param" is the name of an existing site
parameter, displays the parameter's value and metadata (type, name, file and
line number where it was defined).


=head2 C<version>

Display App::Dochazka::REST version

Shows the L<App::Dochazka::REST> version running on the present instance.


=head2 C<whoami>

Display the current employee (i.e. the one we authenticated with)

Displays the profile of the currently logged-in employee (same as
"employee/current")


=head1 ACTIVITY RESOURCES




=head2 C<activity/aid>

Update an existing activity object via POST request (AID must be included in request body)

Enables existing activity objects to be updated by sending a POST request to
the REST server. Along with the properties to be modified, the request body
must include an 'aid' property, the value of which specifies the AID to be
updated.


=head2 C<activity/aid/:aid>

GET, PUT, or DELETE an activity object by its AID

=over

=item * GET

Retrieves an activity object by its AID.

=item * PUT

Updates the activity object whose AID is specified by the ':aid' URI parameter.
The fields to be updated and their new values should be sent in the request
body, e.g., like this:

    { "long_desc" : "new description", "disabled" : "f" }

=item * DELETE

Deletes the activity object whose AID is specified by the ':aid' URI parameter.
This will work only if nothing in the database refers to this activity.

=back


=head2 C<activity/all>

Retrieve all activity objects (excluding disabled ones)

Retrieves all activity objects in the database (excluding disabled activities).


=head2 C<activity/all/disabled>

Retrieve all activity objects, including disabled ones

Retrieves all activity objects in the database (including disabled activities).


=head2 C<activity/code>

Update an existing activity object via POST request (activity code must be included in request body)

This resource enables existing activity objects to be updated, and new
activity objects to be inserted, by sending a POST request to the REST server.
Along with the properties to be modified/inserted, the request body must
include an 'code' property, the value of which specifies the activity to be
updated.  


=head2 C<activity/code/:code>

GET, PUT, or DELETE an activity object by its code

=over

=item * GET

Retrieves an activity object by its code.

=item * PUT

Inserts new or updates existing activity object whose code is specified by the
':code' URI parameter.  The fields to be updated and their new values should be
sent in the request body, e.g., like this:

    { "long_desc" : "new description", "disabled" : "f" }

=item * DELETE

Deletes an activity object by its code whose code is specified by the ':code'
URI parameter.  This will work only if nothing in the database refers to this
activity.

=back


=head2 C<activity/help>

Display available activity resources for given HTTP method

Displays information on all activity resources available to the logged-in
employee, according to her privlevel.


=head1 EMPLOYEE RESOURCES




=head2 C<employee/count>

Display total count of employees (all privilege levels)

Gets the total number of employees in the database. This includes employees
of all privilege levels, including not only administrators and active
employees, but inactives and passerbies as well. Keep this in mind when
evaluating the number returned.


=head2 C<employee/count/:priv>

Display total count of employees with given privilege level

Gets the number of employees with a given privilege level. Valid
privlevels are: 

=over

=item * passerby

=item * inactive

=item * active

=item * admin

=back


=head2 C<employee/current>

Display the current employee (i.e. the one we authenticated with)

Displays the profile of the currently logged-in employee. The information
is limited to just the employee object itself.


=head2 C<employee/current/priv>

Display the privilege level of the current employee (i.e. the one we authenticated with)

Displays the "full profile" of the currently logged-in employee. The
information includes the employee object in the 'current_emp' property and
the employee's privlevel in the 'priv' property.


=head2 C<employee/eid>

Update existing employee (JSON request body with EID required)

This resource provides a way to update employee objects using the
POST method, provided the employee's EID is provided in the content body.
The properties to be modified should also be included, e.g.:

    { "eid" : 43, "fullname" : "Foo Bariful" }

This would change the 'fullname' property of the employee with EID 43 to "Foo
Bariful" (provided such an employee exists).


=head2 C<employee/eid/:eid>

GET: look up employee (exact match); PUT: update existing employee; DELETE: delete employee

=over

=item * GET

Retrieves an employee object by its EID.  

=item * PUT

Updates the "employee profile" (employee object) of the employee with
the given EID. For example, if the request body was:

    { "fullname" : "Foo Bariful" }

the reques would changesthe 'fullname' property of the employee with EID 43 to "Foo
Bariful" (provided such an employee exists). Any 'eid' property provided in
the content body will be ignored.

=item * DELETE

Deletes the employee with the given EID (will only work if the EID
exists and nothing in the database refers to it).

=back


=head2 C<employee/help>

Display available employee resources for given HTTP method

Displays information on all employee resources available to the logged-in
employee, according to her privlevel.


=head2 C<employee/nick>

Insert new/update existing employee (JSON request body with nick required)

This resource provides a way to insert/update employee objects using the
POST method, provided the employee's nick is provided in the content body.

Consider, for example, the following request body:

    { "nick" : "foobar", "fullname" : "Foo Bariful" }

If an employee "foobar" exists, such a request would change the 'fullname'
property of that employee to "Foo Bariful". On the other hand, if the employee
doesn't exist this HTTP request would cause a new employee 'foobar' to be
created.


=head2 C<employee/nick/:nick>

Retrieves (GET), updates/inserts (PUT), and/or deletes (DELETE) the employee specified by the ':nick' parameter

=over

=item * GET

Retrieves employee object(s) by exact match or % wildcard. For example:

    GET employee/nick/foobar

would look for an employee whose nick is 'foobar'. Another example:

    GET employee/nick/foo%

would return a list of employees whose nick starts with 'foo'.

=item * PUT

Inserts a new employee or updates an existing one (exact match only).
If a 'nick' property is provided in the content body and its value is
different from the nick provided in the URI, the employee's nick will be
changed to the value provided in the content body.

=item * DELETE

Deletes an employee (exact match only). This will work only if the
exact nick exists and nothing else in the database refers to the employee
in question.

=back


=head1 PRIVILEGE RESOURCES




=head2 C<priv/eid/:eid/?:ts>

Get the present privlevel of arbitrary employee, or with optional timestamp, that employee's privlevel as of that timestamp

This resource retrieves the privlevel of an arbitrary employee specified by EID.

If no timestamp is given, the present privlevel is retrieved. If a timestamp
is present, the privlevel as of that timestamp is retrieved.


=head2 C<priv/help>

Display priv resources

This resource retrieves a listing of all resources available to the
caller (currently logged-in employee).


=head2 C<priv/history/eid/:eid>

Retrieves entire history of privilege level changes for employee with the given EID (GET); or, with an appropriate content body, adds (PUT) or deletes (DELETE) a record to employee's privhistory

=over

=item * GET

Retrieves the "privhistory", or history of changes in
privilege level, of the employee with the given EID.

=item * PUT

Adds a record to the privhistory of the given employee. The content
body should contain two properties: "timestamp" and "privlevel".

=item * DELETE

Deletes a record from the privhistory of the given employee. The content
body should contain two properties: "timestamp" and "privlevel".

=back


=head2 C<priv/history/eid/:eid/:tsrange>

Get a slice of history of privilege level changes for employee with the given EID

Retrieves a slice (given by the tsrange argument) of the employee's
"privhistory" (history of changes in privilege level).


=head2 C<priv/history/nick/:nick>

Retrieves entire history of privilege level changes for employee with the given nick (GET); or, with an appropriate content body, adds (PUT) or deletes (DELETE) a record to employee's privhistory

=over

=item * GET

Retrieves the "privhistory", or history of changes in
privilege level, of the employee with the given nick.

=item * PUT

Adds a record to the privhistory of the given employee. The content
body should contain two properties: "timestamp" and "privlevel".

=item * DELETE

Deletes a record from the privhistory of the given employee. The content
body should contain two properties: "timestamp" and "privlevel".

=back


=head2 C<priv/history/nick/:nick/:tsrange>

Get partial history of privilege level changes for employee with the given nick (i.e, limit to given tsrange)

Retrieves a slice (given by the tsrange argument) of the employee's
"privhistory" (history of changes in privilege level).


=head2 C<priv/history/phid/:phid>

Retrieves (GET) or deletes (DELETE) a single privilege history record by its PHID

=over

=item * GET

Retrieves a privhistory record by its PHID.

=item * DELETE

Deletes a privhistory record by its PHID.

=back

(N.B.: to add a privhistory record, use "PUT priv/history/eid/:eid" or
"PUT priv/history/nick/:nick")


=head2 C<priv/history/self/?:tsrange>

Retrieves privhistory of present employee, with option to limit to :tsrange

This resource retrieves the "privhistory", or history of changes in
privilege level, of the present employee. Optionally, the listing can be
limited to a specific tsrange such as "[2014-01-01, 2014-12-31)".


=head2 C<priv/nick/:nick/?:ts>

Get the present privlevel of arbitrary employee, or with optional timestamp, that employee's privlevel as of that timestamp

This resource retrieves the privlevel of an arbitrary employee specified by nick.

If no timestamp is given, the present privlevel is retrieved. If a timestamp
is present, the privlevel as of that timestamp is retrieved.


=head2 C<priv/self/?:ts>

Get the present privlevel of the currently logged-in employee, or with optional timestamp, that employee's privlevel as of that timestamp

This resource retrieves the privlevel of the caller (currently logged-in employee).

If no timestamp is given, the present privlevel is retrieved. If a timestamp
is present, the privlevel as of that timestamp is retrieved.


=head1 SCHEDULE RESOURCES




=head2 C<schedule/all>

Retrieves (GET) all non-disabled schedules

This resource returns a list (array) of all schedules for which the 'disabled' field has
either not been set or has been set to 'false'.


=head2 C<schedule/all/disabled>

Retrieves (GET) all schedules (disabled and non-disabled)

This resource returns a list (array) of all schedules, regardless of thie contents
of the 'disabled' field.


=head2 C<schedule/eid/:eid/?:ts>

Get the current schedule of arbitrary employee, or with optional timestamp, that employee's schedule as of that timestamp

This resource retrieves the schedule of an arbitrary employee specified by EID.

If no timestamp is given, the current schedule is retrieved. If a timestamp
is present, the schedule as of that timestamp is retrieved.


=head2 C<schedule/help>

Display schedule resources

This resource retrieves a listing of all schedule resources available to the
caller (currently logged-in employee).


=head2 C<schedule/history/eid/:eid>

GET: Get entire history of schedule changes for employee with the given EID, PUT: add a record to schedule history of employee, DELETE: delete a schedule record

=over

=item * GET

Retrieves the "schedule history", or history of changes in
schedule, of the employee with the given EID.

=item * PUT

Adds a record to the schedule history of the given employee. The content
body should contain two properties: "effective" (timestamp) and "sid" (integer).

=item * DELETE

Deletes a record from the schedule history of the given employee. The content
body should contain two properties: "effective" (timestamp) and "sid" (integer).

=back


=head2 C<schedule/history/eid/:eid/:tsrange>

Get a slice of history of schedule changes for employee with the given EID

Retrieves a slice (given by the tsrange argument) of the employee's
"schedule history" (history of changes in schedule).


=head2 C<schedule/history/nick/:nick>

Get entire history of schedule changes for employee with the given nick

=over

=item * GET

Retrieves the "schedule history", or history of changes in
schedule, of the employee with the given nick.

=item * PUT

Adds a record to the schedule history of the given employee. The content
body should contain two properties: "effective" (timestamp) and "sid" (integer).

=item * DELETE

Deletes a record from the schedule history of the given employee. The content
body should contain two properties: "effective" (timestamp) and "sid" (integer).

=back


=head2 C<schedule/history/nick/:nick/:tsrange>

Get partial history of schedule changes for employee with the given nick (i.e, limit to given tsrange)

Retrieves a slice (given by the tsrange argument) of the employee's
"schedule history" (history of changes in schedule).


=head2 C<schedule/history/self/?:tsrange>

Get schedule history of current employee, with option to limit to :tsrange

This resource retrieves the "schedule history", or history of changes in
schedule, of the current employee. Optionally, the listing can be
limited to a specific tsrange such as "[2014-01-01, 2014-12-31)".


=head2 C<schedule/history/shid/:shid>

GET or DELETE a schedule record by its SHID

=over

=item * GET

Retrieves a schedule history record by its SHID.

=item * DELETE

Deletes a schedule history record by its SHID.

=back

(N.B.: to add a schedule history record, use "PUT schedule/history/eid/:eid" or
"PUT schedule/history/nick/:nick")


=head2 C<schedule/intervals>

Insert and delete schedules

Inserts (POST) or deletes (DELETE) a schedule.

=over

=item * POST

The request body must contain an array of non-overlapping tsranges (intervals)
that fall within a 168-hour (7-day) period. If successful, the payload will
contain three properties: 'ssid' (containing the SSID assigned to the
intervals), 'intervals' (containing the intervals themselves), and 'schedule'
(containing the intervals converted into the format suitable for insertion into
the 'schedule' table).

If the exact schedule already exists in the database, the POST operation
returns it.  Instead of DISPATCH_SCHEDULE_INSERT_OK, in this case the return
status code will be DISPATCH_SCHEDULE_OK.

=item * DELETE

An 'ssid' property must be given as a property in the request body. If found,
the scratch schedule will be deleted in an atomic operation. If the SSID is
found and the delete operation is successful, the status will be "OK".

=back


=head2 C<schedule/nick/:nick/?:ts>

Get the current schedule of arbitrary employee, or with optional timestamp, that employee's schedule as of that timestamp

This resource retrieves the schedule of an arbitrary employee specified by nick.

If no timestamp is given, the current schedule is retrieved. If a timestamp
is present, the schedule as of that timestamp is retrieved.


=head2 C<schedule/self/?:ts>

Get the current schedule of the currently logged-in employee, or with optional timestamp, that employee's schedule as of that timestamp

This resource retrieves the schedule of the caller (currently logged-in employee).

If no timestamp is given, the current schedule is retrieved. If a timestamp
is present, the schedule as of that timestamp is retrieved.


=head2 C<schedule/sid/:sid>

Retrieve (GET), update (POST) or delete (DELETE) a schedule by its SID

Retrieves (GET), updates (POST), or deletes (DELETE) a schedule by its SID.

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



=cut
