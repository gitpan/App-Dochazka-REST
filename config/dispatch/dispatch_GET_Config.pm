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
# dispatch_GET_Config.pm
#
# Path dispatch configuration file for GET resources
# -----------------------------------


# DISPATCH_HELP_TOPLEVEL_GET
#    GET resources - top level 
set( 'DISPATCH_HELP_TOPLEVEL_GET', [
    'help', 
    'version', 
    'siteparam/:param', 
    'forbidden', 
    'whoami',
    'employee',
    'privhistory',
] );

# DISPATCH_HELP_EMPLOYEE_GET
#    GET resources - employee
set( 'DISPATCH_HELP_EMPLOYEE_GET', [
    'employee/help',
    'employee/nick/:param',
    'employee/eid/:param',
    'employee/current',
    'employee/count',
    'employee/count/:priv',
] );

# DISPATCH_HELP_PRIVHISTORY_GET
#    GET resources - privlevel
set( 'DISPATCH_HELP_PRIVHISTORY_GET', [
    'privhistory/help',
    'privhistory/nick/:nick',
    'privhistory/nick/:nick/:tsrange',
    'privhistory/eid/:eid',
    'privhistory/eid/:eid/:tsrange',
    'privhistory/current',
    'privhistory/current/:tsrange',
] );

# DISPATCH_RESOURCES_GET
#    GET resources - Dispatch/Employee.pm
set( 'DISPATCH_RESOURCES_GET', {

    #
    # TOP-LEVEL GET RESOURCES
    #
    '' => 
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::_get_default', 
      description => 'Display available top-level resources',
    },
    'help' => 
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::_get_default', 
      description => 'Display available top-level resources',
    },
    'version' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::_get_default', 
      description => 'Display App::Dochazka::REST version',
    },
    'siteparam/:param' =>
    { 
      acl_profile => 'admin', 
      target => 'App::Dochazka::REST::Dispatch::_get_site_param', 
      description => 'Show value of a site configuration parameter',
    },
    'forbidden' =>
    { 
      target => 'App::Dochazka::REST::Dispatch::_get_forbidden',
      description => 'A resource that is forbidden to all',
    },
    'whoami' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_get_current', 
      description => 'Display the current employee (i.e. the one we authenticated with)',
    },
    
    # 
    # EMPLOYEE GET RESOURCES
    #
    'employee' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_get_default', 
      description => 'Display employee resources',
    },
    'employee/help' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_get_default', 
      description => 'Display employee resources',
    },
    'employee/nick/:param' =>
    { 
      acl_profile => 'admin', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_get_nick', 
      description => "Search for employees by nick (uses SQL 'LIKE')",
    },
    'employee/eid/:param' =>
    { 
      acl_profile => 'admin', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_get_eid', 
      description => 'Look up employee by EID',
    },
    'employee/current' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_get_current', 
      description => 'Display the current employee (i.e. the one we authenticated with)',
    },
    'employee/count' =>
    { 
      acl_profile => 'admin', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_get_count', 
      description => 'Display total count of employees (all privilege levels)',
    },
    'employee/count/:priv' =>
    { 
      acl_profile => 'admin', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_get_count', 
      description => 'Display total count of employees with given privilege level',
    },

    # 
    # PRIVHISTORY GET RESOURCES
    #
    'privhistory' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Privhistory::_get_default', 
      description => 'Display privhistory resources',
    },
    'privhistory/help' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Privhistory::_get_default', 
      description => 'Display privhistory resources',
    },
    'privhistory/nick/:nick' =>
    { 
      acl_profile => 'admin',
      target => 'App::Dochazka::REST::Dispatch::Privhistory::_get_nick', 
      description => 'Get entire history of privilege level changes for employee with the given nick',
    },
    'privhistory/nick/:nick/:tsrange' =>
    { 
      acl_profile => 'admin',
      target => 'App::Dochazka::REST::Dispatch::Privhistory::_get_nick', 
      description => 'Get partial history of privilege level changes for employee with the given nick ' . 
                     '(i.e, limit to given tsrange)',
    },
    'privhistory/eid/:eid' =>
    { 
      acl_profile => 'admin',
      target => 'App::Dochazka::REST::Dispatch::Privhistory::_get_eid', 
      description => 'Get entire history of privilege level changes for employee with the given EID',
    },
    'privhistory/eid/:eid/:tsrange' =>
    { 
      acl_profile => 'admin',
      target => 'App::Dochazka::REST::Dispatch::Privhistory::_get_eid', 
      description => 'Get partial history of privilege level changes for employee with the given EID ' . 
                     '(i.e, limit to given tsrange)',
    },
    'privhistory/current' =>
    { 
      acl_profile => 'active',
      target => 'App::Dochazka::REST::Dispatch::Privhistory::_get_current', 
      description => 'Get entire history of privilege level changes for the current employee',
    },
    'privhistory/current/:tsrange' =>
    { 
      acl_profile => 'active',
      target => 'App::Dochazka::REST::Dispatch::Privhistory::_get_current', 
      description => 'Get partial history of privilege level changes for the current employee ' . 
                     '(i.e, limit to given tsrange)',
    },

} );

1;
