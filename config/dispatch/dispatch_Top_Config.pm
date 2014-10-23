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
        documentation => <<'EOH',
This is the toppest of the top-level targets or, if you wish, the 
"root target". If the base UID of your App::Dochazka::REST instance 
is http://dochazka.site:5000 and your username/password are 
"demo/demo", then this resource is triggered by either of the URLs:

    http://demo:demo@dochazka.site:5000
    http://demo:demo@dochazka.site:5000/

In terms of behavior, the "" resource is identical to "help" --
it returns the set of top-level resources available to the user.
EOH
    },
    'bugreport' =>
    {
        target => {
            GET => '_get_bugreport',
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        description => 'Display the address for reporting bugs in App::Dochazka::REST',
        documentation => <<'EOH',
Returns a "report_bugs_to" key in the payload, containing the address to
report bugs to.
EOH
    },
    'echo' =>
    {
        target => {
            POST => '_echo', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'admin', 
        description => 'Echo the request body',
        documentation => <<'EOH',
This resource simply takes whatever content body was sent and echoes it
back in the response body.
EOH
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
        documentation => <<'EOH',
Lists employee resources available to the logged-in employee.
EOH
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
        documentation => <<'EOH',
This resource always returns 405 Method Not Allowed, no matter what.
EOH
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
        documentation => <<'EOH',
<p>The purpose of the "help" resource is to give the user an overview of
all the top-level resources available to her, with regard to her privlevel
and the HTTP method being used.
<ul>
<li>If the HTTP method is GET, only resources with GET targets will be
displayed (same applies to other HTTP methods)</li>
<li>If the user's privlevel is 'inactive', only resources whose ACL profile
is 'inactive' or lower (i.e., 'inactive' or 'passerby') will be
displayed</li>
</ul>
<p>The information provided is sent as a JSON string in the HTTP response
body, and includes the resource's name, full URI, ACL profile, and brief
description, as well as a link to the App::Dochazka::REST on-line
documentation.
EOH
    },
    'docu' => 
    { 
        target => {
            POST => '_help_post', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        description => 'Display on-line help documentation on the resource whose name is provided in the request body (in double-quotes)',
        documentation => <<'EOH',
This resource provides access to App::Dochazka::REST on-line help
documentation. It expects to find a resource (e.g. "employee/eid/:eid"
including the double-quotes, and without leading or trailing slash) in the
request body.
EOH
    },
    'metaparam/:param' =>
    { 
        target => {
            GET => '_get_param', 
            PUT => '_put_param',
            DELETE => '_not_implemented',
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'admin', 
        description => 'Display (GET) or set (PUT) meta configuration parameter',
        documentation => <<'EOH',
GET: Assuming that the argument C<:param> is the name of an existing meta
parameter, displays the parameter's value and metadata (type, name, file and
line number where it was defined). This resource is available only to users
with C<admin> privileges.

PUT: Regardless of whether C<:param> is an existing metaparam or not, set 
that parameter's value to the (entire) request body. If the request body
is "123", then the parameter will be set to that value. If it is { "value" :
123 }, then it will be set to that structure.

DELETE: If the argument is an existing metaparam, delete that parameter. 
(NOT IMPLEMENTED)
EOH
    },
    'not_implemented' =>
    { 
        target => {
            GET => '_not_implemented', 
            PUT => '_not_implemented', 
            POST => '_not_implemented', 
            DELETE => '_not_implemented', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        description => 'A resource that will never be implemented',
        documentation => <<'EOH',
Regardless of anything, returns a NOTICE status with status code
DISPATCH_RESOURCE_NOT_IMPLEMENTED
EOH
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
        documentation => <<'EOH',
Lists privhistory resources available to the logged-in employee.
EOH
    },
    'session' =>
    { 
        target => {
            GET => '_get_session', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        description => 'Display the current session',
        documentation => <<'EOH',
Dumps the current session data (server-side).
EOH
    },
    'siteparam/:param' =>
    { 
        target => {
            GET => '_get_param', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'admin', 
        description => 'Display site configuration parameter',
        documentation => <<'EOH',
GET: Assuming that the argument ":param" is the name of an existing site
parameter, displays the parameter's value and metadata (type, name, file and
line number where it was defined). This resource is available only to users
with admin privileges.
EOH
    },
    'version' =>
    { 
        target => {
            GET => '_get_version', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        description => 'Display App::Dochazka::REST version',
        documentation => <<'EOH',
Shows the App::Dochazka::REST version running on the present instance.
EOH
    },
    'whoami' =>
    { 
        target => {
            GET => '_get_current', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'passerby', 
        description => 'Display the current employee (i.e. the one we authenticated with)',
        documentation => <<'EOH',
Displays the profile of the currently logged-in employee (same as
"employee/current")
EOH
    },

});

1;
