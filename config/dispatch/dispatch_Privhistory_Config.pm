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
# dispatch_Privhistory_Config.pm
#
# Path dispatch configuration file for privhistory resources
# -----------------------------------


# DISPATCH_RESOURCES_PRIVHISTORY
#    Privhistory resources - Dispatch/Privhistory.pm
#    - value is a hash, the keys of which are resource paths
#    - the values of those keys are hashes containing resource metadata
set( 'DISPATCH_RESOURCES_PRIVHISTORY', {

    'privhistory/help' =>
    { 
        target => {
            GET => '_get_default',  # _get_default is the name of a subroutine in 
                                    # the module pointed to by the 'target_module'
                                    # property, below
            POST => '_post_default',
            PUT => '_put_default',
            DELETE => '_delete_default',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Privhistory',
        acl_profile => 'passerby', 
        description => 'Display privhistory resources',
    },
    'privhistory/nick/:nick' =>
    { 
        target => {
            GET => '_get_nick', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Privhistory',
        acl_profile => 'admin',
        description => 'Get entire history of privilege level changes for employee with the given nick',
    },
    'privhistory/nick/:nick/:tsrange' =>
    { 
        target => {
            GET => '_get_nick', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Privhistory',
        acl_profile => 'admin',
        description => 'Get partial history of privilege level changes for employee with the given nick ' . 
                     '(i.e, limit to given tsrange)',
    },
    'privhistory/eid/:eid' =>
    { 
        target => {
            GET => '_get_eid', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Privhistory',
        acl_profile => 'admin',
        description => 'Get entire history of privilege level changes for employee with the given EID',
    },
    'privhistory/eid/:eid/:tsrange' =>
    { 
        target => {
            GET => '_get_eid', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Privhistory',
        acl_profile => 'admin',
        description => 'Get partial history of privilege level changes for employee with the given EID ' . 
                     '(i.e, limit to given tsrange)',
    },
    'privhistory/current' =>
    { 
        target => {
            GET => '_get_current', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Privhistory',
        acl_profile => 'active',
        description => 'Get entire history of privilege level changes for the current employee',
    },
    'privhistory/current/:tsrange' =>
    { 
        target => {
            GET => '_get_current', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Privhistory',
        acl_profile => 'active',
        description => 'Get partial history of privilege level changes for the current employee ' . 
                     '(i.e, limit to given tsrange)',
    },

});
