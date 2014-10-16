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
    },
    'employee/:nick' =>
    { 
        target => {
            GET => '_get_nick', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'admin', 
        description => "Shortcut for employee/nick/:nick (GET/HEAD only)"
    },
    'employee/nick' =>
    {
        target => {
            POST => '_post_employee_body_with_nick_required',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'admin', 
        description => 'Insert new/update existing employee (JSON request body with nick required)',
    },
    'employee/nick/:nick' =>
    { 
        target => {
            GET => '_get_nick', 
            PUT => '_put_employee_nick_in_path', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'admin', 
        description => "GET: look up employee by nick (exact match); PUT: insert new employee or update existing"
    },
    'employee/eid' =>
    {
        target => {
            POST => '_post_employee_body_with_eid_required', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'admin', 
        description => 'Update existing employee (JSON request body with EID required)',
    },
    'employee/eid/:eid' =>
    { 
        target => {
            GET => '_get_eid', 
            PUT => '_put_employee_eid_in_path', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'admin', 
        description => 'GET: look up employee by EID (exact match); PUT: update existing employee',
    },
    'employee/current' =>
    { 
        target => {
            GET => '_get_current', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'passerby', 
        description => 'Display the current employee (i.e. the one we authenticated with)',
    },
    'employee/count' =>
    { 
        target => {
            GET => '_get_count', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'admin', 
        description => 'Display total count of employees (all privilege levels)',
    },
    'employee/count/:priv' =>
    { 
        target => {
            GET => '_get_count', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'admin', 
        description => 'Display total count of employees with given privilege level',
    },

} );

1;
