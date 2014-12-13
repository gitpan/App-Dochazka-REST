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


our $VERSION = 0.352;

1;
__END__


=head1 NAME

App::Dochazka::REST::Docs::Resources - Documentation of REST resources


=head1 DESCRIPTION

This is a POD-only module containing documentation on all the REST resources 
defined under C<config/dispatch>. This module is auto-generated.


=head1 RESOURCES



=head2 Top-level

Miscellaneous resources that don't fit under any specific category.




=head3 /

Display available top-level resources for given HTTP method

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD > *** ACL: passerby ***

This is the toppest of the top-level targets or, if you wish, the 
"root target". If the base UID of your App::Dochazka::REST instance 
is http://dochazka.site:5000 and your username/password are 
"demo/demo", then this resource is triggered by either of the URLs:

    http://demo:demo@dochazka.site:5000
    http://demo:demo@dochazka.site:5000/

In terms of behavior, the "" resource is identical to "help" --
it returns the set of top-level resources available to the user.


=back

=head3 activity

Display available employee resources for given HTTP method

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD employee> *** ACL: passerby ***

Lists activity resources available to the logged-in employee. This is the same
as calling the C<activity/help> resource.


=back

=head3 bugreport

Display the address for reporting bugs in App::Dochazka::REST

=over

*** HTTP: C<GET> *** CLI: C<$METHOD bugreport> *** ACL: passerby ***

Returns a "report_bugs_to" key in the payload, containing the address to
report bugs to.


=back

=head3 dbstatus

Display status of database connection

=over

*** HTTP: C<GET> *** CLI: C<$METHOD dbstatus> *** ACL: inactive ***

This resource checks the employee's database connection and reports on its status.
The result - either "UP" or "DOWN" - will be encapsulated in a payload like this:

    { "dbstatus" : "UP" }

Each employee gets her own database connection when she logs in to Dochazka.
Calling this resource causes the server to execute a 'ping' on the connection.
If the ping test fails, the server will attempt to open a new connection. Only
if this, too, fails will "DOWN" be returned.


=back

=head3 docu

Display on-line Plain Old Documentation (POD) on the resource whose name is provided in the request body (in double-quotes)

=over

*** HTTP: C<POST> *** CLI: C<$METHOD docu $RESOURCE> *** ACL: passerby ***

This resource provides access to App::Dochazka::REST on-line help
documentation. It expects to find a resource (e.g. "employee/eid/:eid"
including the double-quotes, and without leading or trailing slash) in the
request body. It returns a string containing the POD source code of the
resource documentation.


=back

=head3 docu/html

Display on-line HTML documentation on the resource whose name is provided in the request body (in double-quotes)

=over

*** HTTP: C<POST> *** CLI: C<$METHOD docu html $RESOURCE> *** ACL: passerby ***

This resource provides access to App::Dochazka::REST on-line help
documentation. It expects to find a resource (e.g. "employee/eid/:eid"
including the double-quotes, and without leading or trailing slash) in the
request body. It returns HTML source code of the resource documentation.


=back

=head3 echo

Echo the request body

=over

*** HTTP: C<POST> *** CLI: C<$METHOD echo [$JSON]> *** ACL: admin ***

This resource simply takes whatever content body was sent and echoes it
back in the response body.


=back

=head3 employee

Display available employee resources for given HTTP method

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD employee> *** ACL: passerby ***

Lists employee resources available to the logged-in employee. This is the same
as calling the C<activity/help> resource.


=back

=head3 forbidden

A resource that is forbidden to all

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD forbidden> *** ACL: forbidden to all ***

This resource returns 403 Forbidden for all allowed methods, regardless of user.


=back

=head3 help

Display available top-level resources for given HTTP method

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD help> *** ACL: passerby ***

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


=back

=head3 interval

Display available interval resources for given HTTP method

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD employee> *** ACL: passerby ***

Lists interval resources available to the logged-in employee. This is the same
as calling the C<interval/help> resource.


=back

=head3 lock

Display available lock resources for given HTTP method

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD employee> *** ACL: passerby ***

Lists lock resources available to the logged-in employee. This is the same
as calling the C<lock/help> resource.


=back

=head3 metaparam

Set value of meta configuration parameter

=over

*** HTTP: C<POST> *** CLI: C<$METHOD metaparam $JSON> *** ACL: admin ***

Takes a content body like this:

    { "name" : "$MY_PARAM", "value" : $MY_VALUE }

Regardless of whether $MY_PARAM is an existing metaparam or not, set 
that parameter's value to $MY_VALUE, which can be a scalar, an array,
or a hash.


=back

=head3 metaparam/:param

Display (GET) or set (PUT) meta configuration parameter

=over

*** HTTP: C<GET> *** CLI: C<$METHOD metaparam $PARAM [$JSON]> *** ACL: admin ***

Assuming that the argument C<:param> is the name of an existing meta
parameter, displays the parameter's value and metadata (type, name, file and
line number where it was defined). This resource is available only to users
with C<admin> privileges.


=back

=head3 not_implemented

A resource that will never be implemented

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD not_implemented> *** ACL: passerby ***

Regardless of anything, returns a NOTICE status with status code
DISPATCH_RESOURCE_NOT_IMPLEMENTED


=back

=head3 priv

Display available priv resources for given HTTP method

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD priv> *** ACL: passerby ***

Lists priv resources available to the logged-in employee. This is the same
as calling the C<priv/help> resource.


=back

=head3 schedule

Display available schedule resources for given HTTP method

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD schedule> *** ACL: passerby ***

Lists schedule resources available to the logged-in employee. This is the same
as calling the C<schedule/help> resource.


=back

=head3 session

Display the current session

=over

*** HTTP: C<GET> *** CLI: C<$METHOD session> *** ACL: passerby ***

Dumps the current session data (server-side).


=back

=head3 siteparam/:param

Display site configuration parameter

=over

*** HTTP: C<GET> *** CLI: C<$METHOD siteparam $PARAM> *** ACL: admin ***

Assuming that the argument ":param" is the name of an existing site
parameter, displays the parameter's value and metadata (type, name, file and
line number where it was defined).


=back

=head3 version

Display App::Dochazka::REST version

=over

*** HTTP: C<GET> *** CLI: C<$METHOD version> *** ACL: passerby ***

Shows the L<App::Dochazka::REST> version running on the present instance.


=back

=head3 whoami

Display the current employee (i.e. the one we authenticated with)

=over

*** HTTP: C<GET> *** CLI: C<$METHOD whoami> *** ACL: passerby ***

Displays the profile of the currently logged-in employee (same as
"employee/current")


=back

=head2 Activity

Resources related to activities.




=head3 activity/aid

Update an existing activity object via POST request (AID must be included in request body)

=over

*** HTTP: C<POST> *** CLI: C<$METHOD activity aid> *** ACL: admin ***

Enables existing activity objects to be updated by sending a POST request to
the REST server. Along with the properties to be modified, the request body
must include an 'aid' property, the value of which specifies the AID to be
updated.


=back

=head3 activity/aid/:aid

GET, PUT, or DELETE an activity object by its AID

=over

*** HTTP: C<DELETE> C<PUT> C<GET> *** CLI: C<$METHOD activity aid $AID> *** ACL: DELETE admin, PUT admin, GET active ***

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


=back

=head3 activity/all

Retrieve all activity objects (excluding disabled ones)

=over

*** HTTP: C<GET> *** CLI: C<$METHOD activity all> *** ACL: active ***

Retrieves all activity objects in the database (excluding disabled activities).


=back

=head3 activity/all/disabled

Retrieve all activity objects, including disabled ones

=over

*** HTTP: C<GET> *** CLI: C<$METHOD activity all disabled> *** ACL: admin ***

Retrieves all activity objects in the database (including disabled activities).


=back

=head3 activity/code

Update an existing activity object via POST request (activity code must be included in request body)

=over

*** HTTP: C<POST> *** CLI: C<$METHOD activity aid> *** ACL: admin ***

This resource enables existing activity objects to be updated, and new
activity objects to be inserted, by sending a POST request to the REST server.
Along with the properties to be modified/inserted, the request body must
include an 'code' property, the value of which specifies the activity to be
updated.  


=back

=head3 activity/code/:code

GET, PUT, or DELETE an activity object by its code

=over

*** HTTP: C<DELETE> C<PUT> C<GET> *** CLI: C<$METHOD activity code $CODE> *** ACL: DELETE admin, PUT admin, GET active ***

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


=back

=head3 activity/help

Display available activity resources for given HTTP method

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD activity help> *** ACL: passerby ***

Displays information on all activity resources available to the logged-in
employee, according to her privlevel.


=back

=head2 Employee

Resources related to employee profiles.




=head3 employee/count

Display total count of employees (all privilege levels)

=over

*** HTTP: C<GET> *** CLI: C<$METHOD employee count> *** ACL: admin ***

Gets the total number of employees in the database. This includes employees
of all privilege levels, including not only administrators and active
employees, but inactives and passerbies as well. Keep this in mind when
evaluating the number returned.


=back

=head3 employee/count/:priv

Display total count of employees with given privilege level

=over

*** HTTP: C<GET> *** CLI: C<$METHOD employee count $PRIV> *** ACL: admin ***

Gets the number of employees with a given privilege level. Valid
privlevels are: 

=over

=item * passerby

=item * inactive

=item * active

=item * admin

=back


=back

=head3 employee/current

Retrieve (GET) and edit (POST) our own employee profile

=over

*** HTTP: C<POST> C<GET> *** CLI: C<$METHOD employee current> *** ACL: POST inactive, GET passerby ***

=over

=item * GET

Displays the profile of the currently logged-in employee. The information
is limited to just the employee object itself.

=item * POST

Provides a way for an employee to update certain fields of her own employee
profile. Exactly which fields can be updated may differ from site to site
(see the DOCHAZKA_PROFILE_EDITABLE_FIELDS site parameter).

=back


=back

=head3 employee/current/priv

Retrieve our own employee profile, privlevel, and schedule

=over

*** HTTP: C<GET> *** CLI: C<$METHOD employee current priv> *** ACL: passerby ***

Displays the "full profile" of the currently logged-in employee. The
information includes the employee object in the 'current_emp' property and
the employee's privlevel in the 'priv' property.


=back

=head3 employee/eid

Update existing employee (JSON request body with EID required)

=over

*** HTTP: C<POST> *** CLI: C<$METHOD employee eid $JSON> *** ACL: inactive ***

This resource provides a way to update employee objects using the
POST method, provided the employee's EID is provided in the content body.
The properties to be modified should also be included, e.g.:

    { "eid" : 43, "fullname" : "Foo Bariful" }

This would change the 'fullname' property of the employee with EID 43 to "Foo
Bariful" (provided such an employee exists).

ACL note: 'inactive' and 'active' employees can use this resource to modify
their own employee profile. Exactly which fields can be updated may differ from
site to site (see the DOCHAZKA_PROFILE_EDITABLE_FIELDS site parameter).


=back

=head3 employee/eid/:eid

GET: look up employee (exact match); PUT: update existing employee; DELETE: delete employee

=over

*** HTTP: C<DELETE> C<PUT> C<GET> *** CLI: C<$METHOD employee eid $EID [$JSON]> *** ACL: DELETE admin, PUT inactive, GET inactive ***

=over

=item * GET

Retrieves an employee object by its EID.  

=item * PUT

Updates the "employee profile" (employee object) of the employee with
the given EID. For example, if the request body was:

    { "fullname" : "Foo Bariful" }

the request would change the 'fullname' property of the employee with EID 43
(provided such an employee exists) to "Foo Bariful". Any 'eid' property
provided in the content body will be ignored.

ACL note: 'inactive' and 'active' employees can use this resource to modify
their own employee profile. Exactly which fields can be updated may differ from
site to site (see the DOCHAZKA_PROFILE_EDITABLE_FIELDS site parameter).

=item * DELETE

Deletes the employee with the given EID (will only work if the EID
exists and nothing in the database refers to it).

=back


=back

=head3 employee/help

Display available employee resources for given HTTP method

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD employee help> *** ACL: passerby ***

Displays information on all employee resources available to the logged-in
employee, according to her privlevel.


=back

=head3 employee/nick

Insert new/update existing employee (JSON request body with nick required)

=over

*** HTTP: C<POST> *** CLI: C<$METHOD employee nick $JSON> *** ACL: inactive ***

This resource provides a way to insert/update employee objects using the
POST method, provided the employee's nick is provided in the content body.

Consider, for example, the following request body:

    { "nick" : "foobar", "fullname" : "Foo Bariful" }

If an employee "foobar" exists, such a request would change the 'fullname'
property of that employee to "Foo Bariful". On the other hand, if the employee
doesn't exist this HTTP request would cause a new employee 'foobar' to be
created.

ACL note: 'inactive' and 'active' employees can use this resource to modify
their own employee profile. Exactly which fields can be updated may differ from
site to site (see the DOCHAZKA_PROFILE_EDITABLE_FIELDS site parameter).


=back

=head3 employee/nick/:nick

Retrieves (GET), updates/inserts (PUT), and/or deletes (DELETE) the employee specified by the ':nick' parameter

=over

*** HTTP: C<DELETE> C<PUT> C<GET> *** CLI: C<$METHOD employee nick $NICK [$JSON]> *** ACL: DELETE admin, PUT inactive, GET admin ***

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

ACL note: 'inactive' and 'active' employees can use this resource to modify
their own employee profile. Exactly which fields can be updated may differ from
site to site (see the DOCHAZKA_PROFILE_EDITABLE_FIELDS site parameter).

=item * DELETE

Deletes an employee (exact match only). This will work only if the
exact nick exists and nothing else in the database refers to the employee
in question.

=back


=back

=head3 employee/self

Retrieve (GET) and edit (POST) our own employee profile

=over

*** HTTP: C<POST> C<GET> *** CLI: C<$METHOD employee current> *** ACL: POST inactive, GET passerby ***

=over

=item * GET

Displays the profile of the currently logged-in employee. The information
is limited to just the employee object itself.

=item * POST

Provides a way for an employee to update certain fields of her own employee
profile. Exactly which fields can be updated may differ from site to site
(see the DOCHAZKA_PROFILE_EDITABLE_FIELDS site parameter).

=back


=back

=head3 employee/self/priv

Retrieve our own employee profile, privlevel, and schedule

=over

*** HTTP: C<GET> *** CLI: C<$METHOD employee current priv> *** ACL: passerby ***

Displays the "full profile" of the currently logged-in employee. The
information includes the employee object in the 'current_emp' property and
the employee's privlevel in the 'priv' property.


=back

=head2 Privilege

Resources related to employee privileges and privhistories.




=head3 priv/eid/:eid/?:ts

Get the present privlevel of arbitrary employee, or with optional timestamp, that employee's privlevel as of that timestamp

=over

*** HTTP: C<GET> *** CLI: C<$METHOD priv eid $EID [$TIMESTAMP]> *** ACL: admin ***

This resource retrieves the privlevel of an arbitrary employee specified by EID.

If no timestamp is given, the present privlevel is retrieved. If a timestamp
is present, the privlevel as of that timestamp is retrieved.


=back

=head3 priv/help

Display priv resources

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD priv help> *** ACL: passerby ***

This resource retrieves a listing of all resources available to the
caller (currently logged-in employee).


=back

=head3 priv/history/eid/:eid

Retrieves entire history of privilege level changes for employee with the given EID (GET); or, with an appropriate content body, adds (POST) a record to employee's privhistory

=over

*** HTTP: C<POST> C<GET> *** CLI: C<$METHOD priv history eid $EID [$JSON]> *** ACL: admin ***

=over

=item * GET

Retrieves the "privhistory", or history of changes in
privilege level, of the employee with the given EID.

=item * POST

Adds a record to the privhistory of the given employee. The content
body should contain two properties: "timestamp" and "privlevel".

N.B. It is assumed that privhistories will be built up record-by-record, but
this dispatch target could conceivably support insertion of multiple
privhistory records.

=back

Update note: histories can be updated by adding new records and deleting old
ones. Existing history records cannot be changed. Adds/deletes should be
performed with due care - especially with regard to existing employee
attendance data (if any).


=back

=head3 priv/history/eid/:eid/:tsrange

Get a slice of history of privilege level changes for employee with the given EID

=over

*** HTTP: C<GET> *** CLI: C<$METHOD priv history eid $EID $TSRANGE> *** ACL: admin ***

Retrieves a slice (given by the tsrange argument) of the employee's
"privhistory" (history of changes in privilege level).


=back

=head3 priv/history/nick/:nick

Retrieves entire history of privilege level changes for employee with the given nick (GET); or, with an appropriate content body, adds (PUT) a record to employee's privhistory

=over

*** HTTP: C<POST> C<GET> *** CLI: C<$METHOD priv history nick $NICK [$JSON]> *** ACL: admin ***

=over

=item * GET

Retrieves the "privhistory", or history of changes in
privilege level, of the employee with the given nick.

=item * POST

Adds a record to the privhistory of the given employee. The content
body should contain two properties: "timestamp" and "privlevel".

It is assumed that privhistories will be built up record-by-record, but this
dispatch target could conceivably support insertion of multiple privhistory
records.

=back

Update note: histories can be updated by adding new records and deleting old
ones. Existing history records cannot be changed. Adds/deletes should be
performed with due care - especially with regard to existing employee
attendance data (if any).


=back

=head3 priv/history/nick/:nick/:tsrange

Get partial history of privilege level changes for employee with the given nick (i.e, limit to given tsrange)

=over

*** HTTP: C<GET> *** CLI: C<$METHOD priv history nick $NICK $TSRANGE> *** ACL: admin ***

Retrieves a slice (given by the tsrange argument) of the employee's
"privhistory" (history of changes in privilege level).


=back

=head3 priv/history/phid/:phid

Retrieves (GET) or deletes (DELETE) a single privilege history record by its PHID

=over

*** HTTP: C<DELETE> C<GET> *** CLI: C<$METHOD priv history phid $PHID> *** ACL: admin ***

=over

=item * GET

Retrieves a privhistory record by its PHID.

=item * DELETE

Deletes a privhistory record by its PHID.

=back

(N.B.: history records can be added using POST requests on "priv/history/eid/:eid" or
"priv/history/nick/:nick")


=back

=head3 priv/history/self/?:tsrange

Retrieves privhistory of present employee, with option to limit to :tsrange

=over

*** HTTP: C<GET> *** CLI: C<$METHOD priv history self [$TSRANGE]> *** ACL: inactive ***

This resource retrieves the "privhistory", or history of changes in
privilege level, of the present employee. Optionally, the listing can be
limited to a specific tsrange such as "[2014-01-01, 2014-12-31)".


=back

=head3 priv/nick/:nick/?:ts

Get the present privlevel of arbitrary employee, or with optional timestamp, that employee's privlevel as of that timestamp

=over

*** HTTP: C<GET> *** CLI: C<$METHOD priv nick $NICK [$TIMESTAMP]> *** ACL: admin ***

This resource retrieves the privlevel of an arbitrary employee specified by nick.

If no timestamp is given, the present privlevel is retrieved. If a timestamp
is present, the privlevel as of that timestamp is retrieved.


=back

=head3 priv/self/?:ts

Get the present privlevel of the currently logged-in employee, or with optional timestamp, that employee's privlevel as of that timestamp

=over

*** HTTP: C<GET> *** CLI: C<$METHOD priv self [$TIMESTAMP]> *** ACL: passerby ***

This resource retrieves the privlevel of the caller (currently logged-in employee).

If no timestamp is given, the present privlevel is retrieved. If a timestamp
is present, the privlevel as of that timestamp is retrieved.


=back

=head2 Schedule

Resources related to employee schedules and schedhistories.




=head3 schedule/all

Retrieves (GET) all non-disabled schedules

=over

*** HTTP: C<GET> *** CLI: C<$METHOD schedule all> *** ACL: admin ***

This resource returns a list (array) of all schedules for which the 'disabled' field has
either not been set or has been set to 'false'.


=back

=head3 schedule/all/disabled

Retrieves (GET) all schedules (disabled and non-disabled)

=over

*** HTTP: C<GET> *** CLI: C<$METHOD schedule all disabled> *** ACL: admin ***

This resource returns a list (array) of all schedules, regardless of the contents
of the 'disabled' field.


=back

=head3 schedule/eid/:eid/?:ts

Get the current schedule of arbitrary employee, or with optional timestamp, that employee's schedule as of that timestamp

=over

*** HTTP: C<GET> *** CLI: C<$METHOD schedule eid $EID [$TIMESTAMP]> *** ACL: admin ***

This resource retrieves the schedule of an arbitrary employee specified by EID.

If no timestamp is given, the current schedule is retrieved. If a timestamp
is present, the schedule as of that timestamp is retrieved.


=back

=head3 schedule/help

Display schedule resources

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD schedule help> *** ACL: passerby ***

This resource retrieves a listing of all schedule resources available to the
caller (currently logged-in employee).


=back

=head3 schedule/history/eid/:eid

Retrieves (GET) entire history of schedule changes for employee with the given EID; adds (POST) a record to schedule history of employee

=over

*** HTTP: C<POST> C<GET> *** CLI: C<$METHOD schedule history eid $EID [$JSON]> *** ACL: admin ***

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


=back

=head3 schedule/history/eid/:eid/:tsrange

Retrieves a slice of history of schedule changes for employee with the given EID

=over

*** HTTP: C<GET> *** CLI: C<$METHOD schedule history eid $EID $TSRANGE> *** ACL: admin ***

Retrieves a slice (given by the tsrange argument) of the employee's
"schedule history" (history of changes in schedule). 


=back

=head3 schedule/history/nick/:nick

Retrieves (GET) entire history of schedule changes for employee with the given nick; adds (POST) a record to schedule history of employee

=over

*** HTTP: C<POST> C<GET> *** CLI: C<$METHOD schedule history nick $NICK [$JSON]> *** ACL: admin ***

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


=back

=head3 schedule/history/nick/:nick/:tsrange

Get partial history of schedule changes for employee with the given nick (i.e, limit to given tsrange)

=over

*** HTTP: C<GET> *** CLI: C<$METHOD schedule history nick $NICK $TSRANGE> *** ACL: admin ***

Retrieves a slice (given by the tsrange argument) of the employee's
"schedule history" (history of changes in schedule).


=back

=head3 schedule/history/self/?:tsrange

Get schedule history of current employee, with option to limit to :tsrange

=over

*** HTTP: C<GET> *** CLI: C<$METHOD schedule history self [$TSRANGE]> *** ACL: inactive ***

This resource retrieves the "schedule history", or history of changes in
schedule, of the current employee. Optionally, the listing can be
limited to a specific tsrange such as "[2014-01-01, 2014-12-31)".


=back

=head3 schedule/history/shid/:shid

GET or DELETE a schedule record by its SHID

=over

*** HTTP: C<DELETE> C<GET> *** CLI: C<$METHOD schedule history shid $SHID> *** ACL: admin ***

=over

=item * GET

Retrieves a schedule history record by its SHID.

=item * DELETE

Deletes a schedule history record by its SHID.

=back

(N.B.: history records can be added using POST requests on "priv/history/eid/:eid" or
"priv/history/nick/:nick")


=back

=head3 schedule/new

Insert schedules

=over

*** HTTP: C<POST> *** CLI: C<$METHOD schedule new $JSON> *** ACL: admin ***

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


=back

=head3 schedule/nick/:nick/?:ts

Get the current schedule of arbitrary employee, or with optional timestamp, that employee's schedule as of that timestamp

=over

*** HTTP: C<GET> *** CLI: C<$METHOD schedule nick $NICK [$TIMESTAMP]> *** ACL: admin ***

This resource retrieves the schedule of an arbitrary employee specified by nick.

If no timestamp is given, the current schedule is retrieved. If a timestamp
is present, the schedule as of that timestamp is retrieved.


=back

=head3 schedule/self/?:ts

Get the current schedule of the currently logged-in employee, or with optional timestamp, that employee's schedule as of that timestamp

=over

*** HTTP: C<GET> *** CLI: C<$METHOD schedule current [$TIMESTAMP]> *** ACL: passerby ***

This resource retrieves the schedule of the caller (currently logged-in employee).

If no timestamp is given, the current schedule is retrieved. If a timestamp
is present, the schedule as of that timestamp is retrieved.


=back

=head3 schedule/sid/:sid

Retrieves, updates, or deletes a schedule by its SID

=over

*** HTTP: C<DELETE> C<POST> C<GET> *** CLI: C<$METHOD schedule sid $SID> *** ACL: admin ***

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


=back

=head2 Interval

Resources related to attendance intervals




=head3 interval/eid/:eid/:tsrange

Retrieve an arbitrary employee's intervals over the given tsrange

=over

*** HTTP: C<GET> *** CLI: C<$METHOD interval eid $EID $TSRANGE> *** ACL: admin ***

With this resource, administrators can retrieve any employee's intervals 
over a given tsrange. 

There are no syntactical limitations on the tsrange, but if too many records would
be fetched, the return status will be C<DISPATCH_TOO_MANY_RECORDS_FOUND>.


=back

=head3 interval/help

Display available interval resources for given HTTP method

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD interval help> *** ACL: passerby ***

Displays information on all interval resources available to the logged-in
employee, according to her privlevel.


=back

=head3 interval/iid

Update an existing interval object via POST request (iid must be included in request body)

=over

*** HTTP: C<POST> *** CLI: C<$METHOD interval iid $JSON> *** ACL: active ***

Enables existing interval objects to be updated by sending a POST request to
the REST server. Along with the properties to be modified, the request body
must include an 'iid' property, the value of which specifies the iid to be
updated.


=back

=head3 interval/iid/:iid

GET, PUT, or DELETE an interval object by its iid

=over

*** HTTP: C<DELETE> C<PUT> C<GET> *** CLI: C<$METHOD interval iid $iid [$JSON]> *** ACL: DELETE active, PUT active, GET active ***

=over

=item * GET

Retrieves an interval object by its iid.

=item * PUT

Updates the interval object whose iid is specified by the ':iid' URI parameter.
The fields to be updated and their new values should be sent in the request
body, e.g., like this:

    { "eid" : 34, "aid" : 1, "intvl" : '[ 2014-11-18 08:00, 2014-11-18 12:00 )' }

=item * DELETE

Deletes the interval object whose iid is specified by the ':iid' URI parameter.
As long as the interval does not overlap with a lock interval, the delete operation
will probably work as expected.

=back

ACL note: 'active' employees can update/delete only their own unlocked intervals.


=back

=head3 interval/new

Add a new attendance data interval

=over

*** HTTP: C<POST> *** CLI: C<$METHOD interval new $JSON> *** ACL: active ***

This is the resource by which employees add new attendance data to the
database. It takes a request body containing, at the very least, C<aid> and
C<intvl> properties. Additionally, it can contain C<long_desc>, while
administrators can also specify C<eid> and C<remark>.


=back

=head3 interval/nick/:nick/:tsrange

Retrieve an arbitrary employee's intervals over the given tsrange

=over

*** HTTP: C<GET> *** CLI: C<$METHOD interval nick $NICK $TSRANGE> *** ACL: admin ***

With this resource, administrators can retrieve any employee's intervals 
over a given tsrange. 

There are no syntactical limitations on the tsrange, but if too many records would
be fetched, the return status will be C<DISPATCH_TOO_MANY_RECORDS_FOUND>.


=back

=head3 interval/self/:tsrange

Retrieve one's own intervals over the given tsrange

=over

*** HTTP: C<GET> *** CLI: C<$METHOD interval self $TSRANGE> *** ACL: inactive ***

With this resource, employees can retrieve their own attendance intervals 
over a given tsrange. 

There are no syntactical limitations on the tsrange, but if too many records would
be fetched, the return status will be C<DISPATCH_TOO_MANY_RECORDS_FOUND>.


=back

=head2 Lock

Resources related to lock intervals




=head3 lock/eid/:eid/:tsrange

Retrieve an arbitrary employee's locks over the given tsrange

=over

*** HTTP: C<GET> *** CLI: C<$METHOD lock eid $EID $TSRANGE> *** ACL: admin ***

With this resource, administrators can retrieve any employee's locks 
over a given tsrange. 

There are no syntactical limitations on the tsrange, but if too many records would
be fetched, the return status will be C<DISPATCH_TOO_MANY_RECORDS_FOUND>.


=back

=head3 lock/help

Display available lock resources for given HTTP method

=over

*** HTTP: C<DELETE> C<POST> C<PUT> C<GET> *** CLI: C<$METHOD lock help> *** ACL: passerby ***

Displays information on all lock resources available to the logged-in
employee, according to her privlevel.


=back

=head3 lock/lid

Update an existing lock object via POST request (lid must be included in request body)

=over

*** HTTP: C<POST> *** CLI: C<$METHOD lock lid $JSON> *** ACL: admin ***

Enables existing lock objects to be updated by sending a POST request to
the REST server. Along with the properties to be modified, the request body
must include an 'lid' property, the value of which specifies the lid to be
updated.


=back

=head3 lock/lid/:lid

GET, PUT, or DELETE an lock object by its lid

=over

*** HTTP: C<DELETE> C<PUT> C<GET> *** CLI: C<$METHOD lock lid $lid [$JSON]> *** ACL: DELETE admin, PUT admin, GET active ***

=over

=item * GET

Retrieves an lock object by its lid.

=item * PUT

Updates the lock object whose lid is specified by the ':lid' URI parameter.
The fields to be updated and their new values should be sent in the request
body, e.g., like this:

    { "eid" : 34, "intvl" : '[ 2014-11-18 00:00, 2014-11-18 24:00 )' }

=item * DELETE

Deletes the lock object whose lid is specified by the ':lid' URI parameter.

=back

ACL note: 'active' employees can view only their own locks, and of course
admin privilege is required to modify or remove a lock.


=back

=head3 lock/new

Add a new attendance data lock

=over

*** HTTP: C<POST> *** CLI: C<$METHOD lock new $JSON> *** ACL: active ***

This is the resource by which the attendance data entered by an employee 
for a given time period can be "locked" to prevent any subsequent
modifications.  It takes a request body containing, at the very least, an
C<intvl> property specifying the tsrange to lock. Additionally, administrators
can specify C<remark> and C<eid> properties.


=back

=head3 lock/nick/:nick/:tsrange

Retrieve an arbitrary employee's locks over the given tsrange

=over

*** HTTP: C<GET> *** CLI: C<$METHOD lock nick $NICK $TSRANGE> *** ACL: admin ***

With this resource, administrators can retrieve any employee's locks 
over a given tsrange. 

There are no syntactical limitations on the tsrange, but if too many records would
be fetched, the return status will be C<DISPATCH_TOO_MANY_RECORDS_FOUND>.


=back

=head3 lock/self/:tsrange

Retrieve one's own locks over the given tsrange

=over

*** HTTP: C<GET> *** CLI: C<$METHOD lock self $TSRANGE> *** ACL: inactive ***

With this resource, employees can retrieve their own attendance locks 
over a given tsrange. 

There are no syntactical limitations on the tsrange, but if too many records would
be fetched, the return status will be C<DISPATCH_TOO_MANY_RECORDS_FOUND>.


=back


=head1 AUTHOR

Nathan Cutler C<ncutler@suse.cz>

=cut
