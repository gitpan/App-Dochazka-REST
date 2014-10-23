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
# Dochazka-REST
# -----------------------------------
# dispatch_POST_Config.pm
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
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'admin', 
        description => 'Display total count of employees (all privilege levels)',
        documentation => <<'EOH',
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
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'admin', 
        description => 'Display total count of employees with given privilege level',
        documentation => <<'EOH',
Display the number of employees with a given privilege level. Valid
privlevels are: passerby, inactive, active, admin
EOH
    },
    'employee/current' =>
    { 
        target => {
            GET => '_get_current', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'passerby', 
        description => 'Display the current employee (i.e. the one we authenticated with)',
        documentation => <<'EOH',
Display the profile of the currently logged-in employee. The information
is limited to just the employee object itself.
EOH
    },
    'employee/current/priv' =>
    { 
        target => {
            GET => '_get_current_priv', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'passerby', 
        description => 'Display the privilege level of the current employee (i.e. the one we authenticated with)',
        documentation => <<'EOH',
Display the "full profile" of the currently logged-in employee. The
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
        acl_profile => 'admin', 
        description => 'Update existing employee (JSON request body with EID required)',
        documentation => <<'EOH',
This resource provides a way to update employee objects using the
POST method, provided the employee's EID is provided in the content body.
For example:<blockquote>POST employee/eid<br>{ "eid" : 43, "fullname" :
"Foo Bariful" }<br></blockquote>
changes the 'fullname' property of the employee with EID 43 to "Foo
Bariful" (provided such an employee exists).
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
        acl_profile => 'admin', 
        description => 'GET: look up employee by EID (exact match); PUT: update existing employee',
        documentation => <<'EOH',
<p>GET: Looks up employee by EID.  
<p>PUT: Update the "employee profile" (employee object) of the employee with
the given EID. For example:
<blockquote>PUT employee/eid/43<br>{ "fullname" : "Foo Bariful"
}</blockquote>
changes the 'fullname' property of the employee with EID 43 to "Foo
Bariful" (provided such an employee exists). Any 'eid' property provided in
the content body will be ignored.
<p>DELETE: deletes the employee with the given EID (will only work if the EID
exists and nothing in the database refers to it)
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
        description => 'Display available employee resources for given HTTP method',
        documentation => <<'EOH',
Display information on all employee resources available to the logged-in
employee, according to her privlevel.
EOH
    },
    'employee/nick' =>
    {
        target => {
            POST => '_put_post_delete_employee_by_nick',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'admin', 
        description => 'Insert new/update existing employee (JSON request body with nick required)',
        documentation => <<'EOH',
<p>This resource provides a way to insert/update employee objects using the
POST method, provided the employee's nick is provided in the content body.
<p>Consider the following example:
<blockquote>POST employee/nick<br>{ "nick" : "foobar", "fullname" : "Foo
Bariful" }</blockquote>
<p>If an employee "foobar" exists, changes the 'fullname' property of that
employee to "Foo Bariful". On the other hand, if the employee doesn't exist
this HTTP request will cause a new employee profile to be created.
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
        acl_profile => 'admin', 
        description => "GET: look up employee by nick (exact match); PUT: insert new employee or update existing",
        documentation => <<'EOH',
<p>GET: Looks up employee by nick.
<p>PUT: Update the "employee profile" (employee object) of the employee with
the given nick. Consider the following example:
<blockquote>PUT employee/nick/foobar<br>{ "fullname" : "Foo Bariful" }</blockquote>
<p>If the employee with nick "foobar" exists, this changes the "fullname"
property of that employee to "Foo Bariful". If a 'nick' property is
provided in the content body with a different value, the employee's nick
will be changed!
<p>If there is no employee with the given nick, it will be created. In this
case, any 'nick' property in the content body will be ignored.
<p>DELETE: deletes the employee with the given EID (will only work if the EID
exists and nothing in the database refers to it)
EOH
    },

} );

1;
