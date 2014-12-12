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
# config/dispatch/employee_Config.pm
#
# Path dispatch configuration file for POST resources
# -----------------------------------



# DISPATCH_RESOURCES_EMPLOYEE
#    Employee resources - Dispatch/Employee.pm
#    - value is a hash, the keys of which are resource paths
#    - the values of those keys are hashes containing resource metadata
set( 'DISPATCH_RESOURCES_EMPLOYEE', {

    'employee/count' =>
    { 
        target => {
            GET => '_get_count', 
            #GET => 'not_implemented',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'admin', 
        cli => 'employee count',
        description => 'Display total count of employees (all privilege levels)',
        documentation => <<'EOH',
=pod

Gets the total number of employees in the database. This includes employees
of all privilege levels, including not only administrators and active
employees, but inactives and passerbies as well. Keep this in mind when
evaluating the number returned.
EOH
    },
    'employee/count/:priv' =>
    { 
        target => {
            GET => '_get_count', 
            #GET => 'not_implemented',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'admin', 
        cli => 'employee count $PRIV',
        description => 'Display total count of employees with given privilege level',
        validations => {
            'priv' => qr/^(passerby)|(inactive)|(active)|(admin)$/i,
        },
        documentation => <<'EOH',
=pod

Gets the number of employees with a given privilege level. Valid
privlevels are: 

=over

=item * passerby

=item * inactive

=item * active

=item * admin

=back
EOH
    },
    'employee/current' =>
    { 
        target => {
            GET => '_get_current', 
            POST => '_put_post_delete_employee_by_eid', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => {
            'GET' => 'passerby', 
            'POST' => 'inactive',
        },
        cli => 'employee current',
        description => 'Retrieve (GET) and edit (POST) our own employee profile',
        documentation => <<'EOH',
=pod

=over

=item * GET

Displays the profile of the currently logged-in employee. The information
is limited to just the employee object itself.

=item * POST

Provides a way for an employee to update certain fields of her own employee
profile. Exactly which fields can be updated may differ from site to site
(see the DOCHAZKA_PROFILE_EDITABLE_FIELDS site parameter).

=back
EOH
    },
    'employee/current/priv' =>
    { 
        target => {
            GET => '_get_current_priv', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'passerby', 
        cli => 'employee current priv',
        description => 'Retrieve our own employee profile, privlevel, and schedule', 
        documentation => <<'EOH',
=pod

Displays the "full profile" of the currently logged-in employee. The
information includes the employee object in the 'current_emp' property and
the employee's privlevel in the 'priv' property.
EOH
    },
    'employee/eid' =>
    {
        target => {
            POST => '_put_post_delete_employee_by_eid', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'inactive', 
        cli => 'employee eid $JSON',
        description => 'Update existing employee (JSON request body with EID required)',
        documentation => <<'EOH',
=pod

This resource provides a way to update employee objects using the
POST method, provided the employee's EID is provided in the content body.
The properties to be modified should also be included, e.g.:

    { "eid" : 43, "fullname" : "Foo Bariful" }

This would change the 'fullname' property of the employee with EID 43 to "Foo
Bariful" (provided such an employee exists).

ACL note: 'inactive' and 'active' employees can use this resource to modify
their own employee profile. Exactly which fields can be updated may differ from
site to site (see the DOCHAZKA_PROFILE_EDITABLE_FIELDS site parameter).
EOH
    },
    'employee/eid/:eid' =>
    { 
        target => {
            GET => '_get_eid', 
            PUT => '_put_post_delete_employee_by_eid', 
            DELETE => '_put_post_delete_employee_by_eid', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => {
            GET => 'inactive', 
            PUT => 'inactive',
            DELETE => 'admin',
        },
        cli => 'employee eid $EID [$JSON]',
        validations => {
            eid => 'Int',
        },
        description => 'GET: look up employee (exact match); PUT: update existing employee; DELETE: delete employee',
        documentation => <<'EOH',
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
EOH
    },
    'employee/help' =>
    { 
        target => {
            GET => '_get_default',  # _get_default is the name of a subroutine in the DISPATCH_EMPLOYEE_TARGET_MODULE module
            POST => '_post_default',
            PUT => '_put_default', 
            DELETE => '_delete_default', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'passerby', 
        cli => 'employee help',
        description => 'Display available employee resources for given HTTP method',
        documentation => <<'EOH',
=pod

Displays information on all employee resources available to the logged-in
employee, according to her privlevel.
EOH
    },
    'employee/nick' =>
    {
        target => {
            POST => '_put_post_delete_employee_by_nick',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'inactive', 
        cli => 'employee nick $JSON',
        description => 'Insert new/update existing employee (JSON request body with nick required)',
        documentation => <<'EOH',
=pod

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
EOH
    },
    'employee/nick/:nick' =>
    { 
        target => {
            GET => '_get_nick', 
            PUT => '_put_post_delete_employee_by_nick', 
            DELETE => '_put_post_delete_employee_by_nick', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => {
            GET => 'inactive',
            PUT => 'inactive',
            DELETE => 'admin', 
        },
        cli => 'employee nick $NICK [$JSON]',
        validations => {
            'nick' => qr/^[%[:alnum:]_][%[:alnum:]_-]+$/,
        },
        description => "Retrieves (GET), updates/inserts (PUT), and/or deletes (DELETE) the employee specified by the ':nick' parameter",
        documentation => <<'EOH',
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
EOH
    },
    'employee/self' =>
    { 
        target => {
            GET => '_get_current', 
            POST => '_put_post_delete_employee_by_eid', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => {
            'GET' => 'passerby', 
            'POST' => 'inactive',
        },
        cli => 'employee current',
        description => 'Retrieve (GET) and edit (POST) our own employee profile',
        documentation => <<'EOH',
=pod

=over

=item * GET

Displays the profile of the currently logged-in employee. The information
is limited to just the employee object itself.

=item * POST

Provides a way for an employee to update certain fields of her own employee
profile. Exactly which fields can be updated may differ from site to site
(see the DOCHAZKA_PROFILE_EDITABLE_FIELDS site parameter).

=back
EOH
    },
    'employee/self/priv' =>
    { 
        target => {
            GET => '_get_current_priv', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'passerby', 
        cli => 'employee current priv',
        description => 'Retrieve our own employee profile, privlevel, and schedule', 
        documentation => <<'EOH',
=pod

Displays the "full profile" of the currently logged-in employee. The
information includes the employee object in the 'current_emp' property and
the employee's privlevel in the 'priv' property.
EOH
    },

} );

1;
