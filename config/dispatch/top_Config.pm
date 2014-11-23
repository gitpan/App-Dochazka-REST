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
# config/dispatch/top_Config.pm
#
# Path dispatch configuration file for top-level resources
# -----------------------------------


# DISPATCH_RESOURCES_TOP
#    Top-level resources
set( 'DISPATCH_RESOURCES_TOP', {

    '/' => 
    { 
        target => {
            GET => '_get_default', 
            POST => '_post_default', 
            PUT => '_put_default', 
            DELETE => '_delete_default', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        cli => '',
        description => 'Display available top-level resources for given HTTP method',
        documentation => <<'EOH',
=pod

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
    'activity' =>
    { 
        target => {
            GET => '_get_default',
            POST => '_post_default',
            PUT => '_put_default', 
            DELETE => '_delete_default', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Activity',
        acl_profile => 'passerby', 
        cli => 'employee',
        description => 'Display available employee resources for given HTTP method',
        documentation => <<'EOH',
=pod

Lists activity resources available to the logged-in employee.
EOH
    },
    'bugreport' =>
    {
        target => {
            GET => '_get_bugreport',
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        cli => 'bugreport',
        description => 'Display the address for reporting bugs in App::Dochazka::REST',
        documentation => <<'EOH',
=pod

Returns a "report_bugs_to" key in the payload, containing the address to
report bugs to.
EOH
    },
    'docu' => 
    { 
        target => {
            POST => '_docu', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        cli => 'docu $RESOURCE',
        description => 'Display on-line Plain Old Documentation (POD) on the resource whose name is provided in the request body (in double-quotes)',
        documentation => <<'EOH',
=pod

This resource provides access to App::Dochazka::REST on-line help
documentation. It expects to find a resource (e.g. "employee/eid/:eid"
including the double-quotes, and without leading or trailing slash) in the
request body. It returns a string containing the POD source code of the
resource documentation.
EOH
    },
    'docu/html' => 
    { 
        target => {
            POST => '_docu_html', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        cli => 'docu html $RESOURCE',
        description => 'Display on-line HTML documentation on the resource whose name is provided in the request body (in double-quotes)',
        documentation => <<'EOH',
=pod

This resource provides access to App::Dochazka::REST on-line help
documentation. It expects to find a resource (e.g. "employee/eid/:eid"
including the double-quotes, and without leading or trailing slash) in the
request body. It returns HTML source code of the resource documentation.
EOH
    },
    'echo' =>
    {
        target => {
            POST => '_echo', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'admin', 
        cli => 'echo [$JSON]',
        description => 'Echo the request body',
        documentation => <<'EOH',
=pod

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
        cli => 'employee',
        description => 'Display available employee resources for given HTTP method',
        documentation => <<'EOH',
=pod

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
        acl_profile => undef,
        cli => 'forbidden',
        description => 'A resource that is forbidden to all',
        documentation => <<'EOH',
=pod

This resource returns 403 Forbidden for all allowed methods, regardless of user.
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
        cli => 'help',
        description => 'Display available top-level resources for given HTTP method',
        documentation => <<'EOH',
=pod

The purpose of the "help" resource is to give the user an overview of
all the top-level resources available to her, with regard to her privlevel
and the HTTP method being used.

=over

=item * If the HTTP method is GET, only resources with GET targets will be
displayed (same applies to other HTTP methods)

=item * If the user's privlevel is 'inactive', only resources whose ACL profile
is 'inactive' or lower (i.e., 'inactive' or 'passerby') will be
displayed

=back

The information provided is sent as a JSON string in the HTTP response
body, and includes the resource's name, full URI, ACL profile, and brief
description, as well as a link to the App::Dochazka::REST on-line
documentation.
EOH
    },
    'metaparam' =>
    {
        target => {
            POST => '_param_post', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'admin', 
        cli => 'metaparam $JSON',
        description => 'Set value of meta configuration parameter',
        documentation => <<'EOH',
=pod

Takes a content body like this:

    { "name" : "$MY_PARAM", "value" : $MY_VALUE }

Regardless of whether $MY_PARAM is an existing metaparam or not, set 
that parameter's value to $MY_VALUE, which can be a scalar, an array,
or a hash.
EOH
    },
    'metaparam/:param' =>
    { 
        target => {
            GET => '_param_get', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'admin', 
        cli => 'metaparam $PARAM [$JSON]',
        description => 'Display (GET) or set (PUT) meta configuration parameter',
        documentation => <<'EOH',
=pod

Assuming that the argument C<:param> is the name of an existing meta
parameter, displays the parameter's value and metadata (type, name, file and
line number where it was defined). This resource is available only to users
with C<admin> privileges.
EOH
    },
    'not_implemented' =>
    { 
        target => {
            GET => 'not_implemented', 
            PUT => 'not_implemented', 
            POST => 'not_implemented', 
            DELETE => 'not_implemented', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        cli => 'not_implemented',
        description => 'A resource that will never be implemented',
        documentation => <<'EOH',
=pod

Regardless of anything, returns a NOTICE status with status code
DISPATCH_RESOURCE_NOT_IMPLEMENTED
EOH
    },
    'priv' =>
    { 
        target => {
            GET => '_get_default',  
            POST => '_post_default',  
            PUT => '_put_default',  
            DELETE => '_delete_default', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Priv',
        acl_profile => 'passerby', 
        cli => 'priv',
        description => 'Display available priv resources for given HTTP method',
        documentation => <<'EOH',
=pod

Lists priv resources available to the logged-in employee.
EOH
    },
    'schedule' =>
    { 
        target => {
            GET => '_get_default',
            POST => '_post_default',
            PUT => '_put_default', 
            DELETE => '_delete_default', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Schedule',
        acl_profile => 'passerby', 
        cli => 'schedule',
        description => 'Display available schedule resources for given HTTP method',
        documentation => <<'EOH',
=pod

Lists schedule resources available to the logged-in employee.
EOH
    },
    'session' =>
    { 
        target => {
            GET => '_get_session', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        cli => 'session',
        description => 'Display the current session',
        documentation => <<'EOH',
=pod

Dumps the current session data (server-side).
EOH
    },
    'siteparam/:param' =>
    { 
        target => {
            GET => '_param_get', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'admin', 
        cli => 'siteparam $PARAM',
        description => 'Display site configuration parameter',
        documentation => <<'EOH',
=pod

Assuming that the argument ":param" is the name of an existing site
parameter, displays the parameter's value and metadata (type, name, file and
line number where it was defined).
EOH
    },
    'version' =>
    { 
        target => {
            GET => '_get_version', 
        },
        target_module => 'App::Dochazka::REST::Dispatch',
        acl_profile => 'passerby', 
        cli => 'version',
        description => 'Display App::Dochazka::REST version',
        documentation => <<'EOH',
=pod

Shows the L<App::Dochazka::REST> version running on the present instance.
EOH
    },
    'whoami' =>
    { 
        target => {
            GET => '_get_current', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Employee',
        acl_profile => 'passerby', 
        cli => 'whoami',
        description => 'Display the current employee (i.e. the one we authenticated with)',
        documentation => <<'EOH',
=pod

Displays the profile of the currently logged-in employee (same as
"employee/current")
EOH
    },

});

1;
