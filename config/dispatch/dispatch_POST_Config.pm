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


# DISPATCH_HELP_TOPLEVEL_POST
#    POST resources - top level 
set( 'DISPATCH_HELP_TOPLEVEL_POST', [
    'help', 
    'echo',
    'forbidden', 
    'employee',
    'privhistory',
] );

# DISPATCH_HELP_EMPLOYEE_POST
#    POST resources - employee
set( 'DISPATCH_HELP_EMPLOYEE_POST', [
    'employee/help',
] );

# DISPATCH_HELP_PRIVHISTORY_POST
#    POST resources - privhistory
set( 'DISPATCH_HELP_PRIVHISTORY_POST', [
    'privhistory/help',
] );

# DISPATCH_RESOURCES_POST
#    POST resources - Dispatch/Employee.pm
set( 'DISPATCH_RESOURCES_POST', {

    #
    # TOP-LEVEL POST RESOURCES
    #
    '' => 
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::_post_default', 
      description => 'Display available top-level POST resources',
    },
    'echo' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::_post_echo', 
      description => 'Echo the request body',
    },
    'forbidden' =>
    { 
      target => 'App::Dochazka::REST::Dispatch::_post_forbidden',
      description => 'Das ist streng verboten',
    },
    'help' => 
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::_post_default', 
      description => 'Display available top-level POST resources',
    },
    
    # 
    # EMPLOYEE POST RESOURCES
    #
    'employee' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_post_default', 
      description => 'Display employee POST resources',
    },
    'employee/help' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Employee::_post_default', 
      description => 'Display employee POST resources',
    },

    # 
    # PRIVHISTORY POST RESOURCES
    #
    'privhistory' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Privhistory::_post_default', 
      description => 'Display privhistory POST resources',
    },
    'privhistory/help' =>
    { 
      acl_profile => 'passerby', 
      target => 'App::Dochazka::REST::Dispatch::Privhistory::_post_default', 
      description => 'Display privhistory POST resources',
    },

} );

1;
