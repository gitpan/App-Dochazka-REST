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

package App::Dochazka::REST::Docs::Workflow;

use 5.012;
use strict;
use warnings FATAL => 'all';


our $VERSION = 0.292;

1;
__END__


=head1 NAME

App::Dochazka::REST::Docs::Workflow - Documentation of REST workflow


=head1 DESCRIPTION

This is a POD-only module containing documentation describing standard Dochazka
workflow scenarios and the REST resources used therein.

It is intended to be used in the functional testing process.

=head1 WORKFLOW SCENARIOS

The workflow scenarios are divided into sections according to the privlevel of
the logged-in employee doing the "work" - i.e., interacting with the Dochazka
REST server.

The workflow scenarios are presented in order of increasing privilege.
Employees with higher privilege can perform all the workflow scenarios
available to those of lower privilege.


=head2 passerby

Passerby is the default privlevel. In other words, employees without any
privhistory entries will automatically be assigned this privlevel.

Passerby employees (which need not be "employees" in a legal sense) can engage
in the following workflows:

=head3 Login

If LDAP authentication is enabled and C<DOCHAZKA_LDAP_AUTOCREATE> is set, a new
passerby employee will be created whenever an as-yet unseen employee logs in
(authenticates herself to the REST server). Otherwise, a passerby employee can
log in only if an administrator has created the corresponding employee profile.

=head3 Explore available resources 

Any logged-in employee is free to explore available resources. The starting
point for such exploration can be C<GET /> (i.e. a GET request for the
top-level resource), which is the same as C<GET /help>. The information
returned is specific to the HTTP method used, so for PUT resources one needs to
use C<PUT /> (or C<PUT /help>), etc.

Only accessible resources are displayed. For example, a passerby employee will
not see admin resources. A few resources (e.g. C<activity/aid/:aid>), have
different ACL profiles depending on which HTTP method is used.

=head3 Retrieve one's own employee profile

Using C<GET employee/current>, any employee can view her own employee profile.
The payload is a valid employee object.

Alternatively, C<GET employee/current/priv> can be used, in which case the
employee's current privilege level and schedule are returned along with the
employee object.

=head3 Retrieve one's own current schedule/privlevel

Using C<GET /priv/self/?:ts> and C<GET /schedule/self/?:ts>, any employee 
can retrieve her own current privlevel and schedule. By including a timestamp
she can also retrieve her privlevel and schedule as of any arbitrary date/time.


=head2 inactive

The inactive privlevel is intended for employees who are not currently
attending work, but are expected to resume doing so at some point in the
future: employees on maternity leave, sabbatical, etc.

Though such employees might not be expected to even log in to Dochazka, 
if they happen to do so they can engage in the following workflows (in addition
to the passerby workflows described in the previous section).

=head3 Retrieve one's own schedule/privilege history

Employee schedules and privlevels change over time. To ensure that historical
attendance data is always associated with the schedule and privlevel in effect
at the time the attendance took place, all changes to employee schedules and
privlevels are recorded in a "history table". 

Employees with privlevel 'inactive' or higher are authorized to view (retrieve)
their privilege/schedule histories using the C<schedule/history/self/?:tsrange>
and C<priv/history/self/?:tsrange> resources.

=head3 Edit one's own employee profile (certain fields)

Inactive employees are authorized to edit certain fields of their employee
profile (e.g., to change their password or correct the spelling of their full
name, etc.). These fields are configurable via the DOCHAZKA_PROFILE_EDITABLE_FIELDS site
parameter.


=head2 active

=head3 Add new attendance intervals

Active employees can add new attendance data ("intervals") subject to the
following limitations: (a), the date must not be locked, (b), the date must
be no later than the end of the current month and, (c), the interval must
not overlap with an existing interval.

    Example 1: Employee 'pepik' tries to insert an attendance interval
               [1985-04-27 08:00, 1985-04-27 12:00) but there is a 
	       lock in place for that date. In such a case, the lock would have
               to be removed by an administrator, or 'pepik' would be out of luck.

    Example 2: Today's date is 2014-10-22 and 'pepik' attempts to insert
               an attendance interval [2014-11-07 08:00, 2014-11-07 08:30) -
	       this will not be possible until 2014-11-01..

New attendance data is added via POST requests on C<interval/new>.

=head3 Retrieve list of non-disabled activities

Since attendance data must be associated with a valid activity, active employees
are authorized to retrieve the entire list of non-disabled activities using
a GET request on the C<activity/all> resource.

=head3 Retrieve one's own past attendance data

Active employees can retrieve (view) their own past attendance data.

=head3 Look up disabled activities

Since past attendance data can refer to activities that have since been disabled,
active employees are authorized to look up activities (including disabled
ones) by code or AID using GET requests on C<activity/aid/:aid> and
C<activity/code/:code>.

=head3 Edit one's own employee profile (certain fields)

Depending on the exact setting of the DOCHAZKA_PROFILE_EDITABLE_FIELDS site
parameter, active employees may be authorized to edit more fields than inactive
employees.


=head2 admin

=head3 Edit any employee's profile

Administrators can edit any employee's profile. The only limitation is that the
EID cannot be changed.

=head3 

=head1 AUTHOR

Nathan Cutler C<ncutler@suse.cz>

=cut
