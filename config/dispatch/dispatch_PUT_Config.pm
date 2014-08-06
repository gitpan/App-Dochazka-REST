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
# dispatch_PUT_Config.pm
#
# Path dispatch configuration file for PUT resources
# -----------------------------------


# DISPATCH_HELP_TOPLEVEL_PUT
#    PUT resources - top level 
set( 'DISPATCH_HELP_TOPLEVEL_PUT', [
    'help', 
    'echo',
    'forbidden', 
    'employee/help',
    'privhistory/help',
] );

# DISPATCH_HELP_EMPLOYEE_PUT
#    PUT resources - employee
set( 'DISPATCH_HELP_EMPLOYEE_PUT', [
    'employee',
    'employee/help',
    'employee/nick',
    'employee/nick/:nick',
    'employee/eid',
    'employee/eid/:eid',
] );

# DISPATCH_HELP_PRIVHISTORY_PUT
#    PUT resources - privhistory
set( 'DISPATCH_HELP_PRIVHISTORY_PUT', [
    'employee',
    'privhistory/help',
] );

# DISPATCH_RESOURCES_PUT
#    PUT resources - Dispatch/Employee.pm
set( 'DISPATCH_RESOURCES_PUT', {

    #
    # TOP-LEVEL PUT RESOURCES
    #
    '' => 
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::_put_default', 
      description => 'Display available top-level resources',
    },
    'echo' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::_put_echo', 
      description => 'Echo the request body',
    },
    'forbidden' =>
    { 
      target => 'App::Dochazka::REST::Dispatch::_put_forbidden',
      description => 'Das ist streng verboten',
    },
    'help' => 
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::_put_default', 
      description => 'Display available top-level resources',
    },
    
    # 
    # EMPLOYEE PUT RESOURCES
    #
    'employee' =>
    {
      acl_profile => 'admin', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_put_default', 
      description => 'Display employee resources',
    },
    'employee/help' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_put_default', 
      description => 'Display employee resources',
    },
    'employee/nick' =>
    {
      acl_profile => 'admin', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_put_employee_body_with_nick_required', 
      description => 'Insert new/update existing employee (JSON request body with nick required)',
    },
    'employee/nick/:nick' =>
    {
      acl_profile => 'admin', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_put_employee_nick_in_path', 
      description => 'Insert new/update existing employee with provided nick ' . 
                     '(JSON request body optional)',
    },
    'employee/eid' =>
    {
      acl_profile => 'admin', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_put_employee_body_with_eid_required', 
      description => 'Update existing employee (JSON request body with EID required)',
    },
    'employee/eid/:eid' =>
    {
      acl_profile => 'admin', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_put_employee_eid_in_path', 
      description => 'Update existing employee with provided EID ' . 
                     '(JSON request body optional)',
    },

    # 
    # PRIVHISTORY PUT RESOURCES
    #
    'privhistory' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Privhistory::_put_default', 
      description => 'Display privhistory resources',
    },
    'privhistory/help' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Privhistory::_put_default', 
      description => 'Display privhistory resources',
    },

} );

1;
