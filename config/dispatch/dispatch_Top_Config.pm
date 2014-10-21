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
# dispatch_Top_Config.pm
#
# Path dispatch configuration file for GET resources
# -----------------------------------


# DISPATCH_RESOURCES_TOP
#    Top-level resources
set( 'DISPATCH_RESOURCES_TOP', {

    '' => 
    { 
        target => {
            GET => '_get_default', 
            POST => '_post_default', 
            PUT => '_put_default', 
            DELETE => '_delete_default', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        description => 'Display available top-level resources for given HTTP method',
    },
    'help' => 
    { 
        target => {
            GET => '_get_default', 
            POST => '_post_default', 
            PUT => '_put_default', 
            DELETE => '_delete_default', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        description => 'Display available top-level resources for given HTTP method',
    },
    'bugreport' =>
    {
        target => {
            GET => '_get_bugreport',
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        description => 'Display the address for reporting bugs in App::Dochazka::REST',
    },
    'echo' =>
    {
        target => {
            POST => '_echo', 
            PUT => '_echo', 
            DELETE => '_echo',
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'admin', 
        description => 'Echo the request body',
    },
    'version' =>
    { 
        target => {
            GET => '_get_version', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        description => 'Display App::Dochazka::REST version',
    },
    'siteparam/:param' =>
    { 
        target => {
            GET => '_get_param', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'admin', 
        description => 'Display site configuration parameter',
    },
    'metaparam/:param' =>
    { 
        target => {
            GET => '_get_param', 
            PUT => '_put_param',
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'admin', 
        description => 'Display (GET) or set (PUT) meta configuration parameter',
    },
    'forbidden' =>
    { 
        target => {
            GET => '_forbidden',
            POST => '_forbidden',
            PUT => '_forbidden',
            DELETE => '_forbidden',
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        description => 'A resource that is forbidden to all',
    },
    'session' =>
    { 
        target => {
            GET => '_get_session', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        description => 'Display the current session',
    },
    'whoami' =>
    { 
        target => {
            GET => '_get_current', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'passerby', 
        description => 'Display the current employee (i.e. the one we authenticated with)',
    },
    'employee' =>
    { 
        target => {
            GET => '_get_default',
            POST => '_post_default',
            PUT => '_put_default', 
            DELETE => '_delete_default', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'passerby', 
        description => 'Display available employee resources for given HTTP method',
    },
    'privhistory' =>
    { 
        target => {
            GET => '_get_default',  
            POST => '_post_default',  
            PUT => '_put_default',  
            DELETE => '_delete_default', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Privhistory',
        acl_profile => 'passerby', 
        description => 'Display available privhistory resources for given HTTP method',
    },

});

1;
