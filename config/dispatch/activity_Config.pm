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
# config/dispatch/activity_Config.pm
#
# Path dispatch configuration file for activity resources
# -----------------------------------


# DISPATCH_RESOURCES_ACTIVITY
#    - value is a hash, the keys of which are resource paths
#    - the values of those keys are hashes containing resource metadata
set( 'DISPATCH_RESOURCES_ACTIVITY', {

    'activity/aid' => 
    {
        target => {
            POST => '_aid',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Activity',
        acl_profile => 'admin', 
        cli => 'activity aid',
        description => 'Update an existing activity object via POST request (AID must be included in request body)',
        documentation => <<'EOH',
=pod

Enables existing activity objects to be updated by sending a POST request to
the REST server. Along with the properties to be modified, the request body
must include an 'aid' property, the value of which specifies the AID to be
updated.
EOH
    },
    'activity/aid/:aid' => 
    {
        target => {
            GET => '_aid',
            PUT => '_aid',
            DELETE => '_aid',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Activity',
        acl_profile => {
            GET => 'active',
            PUT => 'admin',
            DELETE => 'admin',
        },
        cli => 'activity aid $AID',
        validations => {
            'aid' => 'Int',
        },
        description => 'GET, PUT, or DELETE an activity object by its AID',
        documentation => <<'EOH',
=over

=item * GET

Retrieves an activity object by its AID.

=item * PUT

Updates the activity object whose AID is specified by the ':aid' URI parameter.
The fields to be updated and their new values should be sent in the request
body, e.g., like this:

    { "long_desc" : "new description", "disabled" : "f" }

=item * DELETE

Deletes the activity object whose AID is specified by the ':aid' URI parameter.
This will work only if nothing in the database refers to this activity.

=back
EOH
    },
    'activity/all' =>
    {
        target => {
            GET => '_get_all_without_disabled',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Activity',
        acl_profile => 'active', 
        cli => 'activity all',
        description => 'Retrieve all activity objects (excluding disabled ones)',
        documentation => <<'EOH',
=pod

Retrieves all activity objects in the database (excluding disabled activities).
EOH
    },
    'activity/all/disabled' =>
    {
        target => {
            GET => '_get_all_including_disabled',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Activity',
        acl_profile => 'admin', 
        cli => 'activity all disabled',
        description => 'Retrieve all activity objects, including disabled ones',
        documentation => <<'EOH',
=pod

Retrieves all activity objects in the database (including disabled activities).
EOH
    },
    'activity/code' => 
    {
        target => {
            POST => '_code',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Activity',
        acl_profile => 'admin', 
        cli => 'activity aid',
        description => 'Update an existing activity object via POST request (activity code must be included in request body)',
        documentation => <<'EOH',
=pod

This resource enables existing activity objects to be updated, and new
activity objects to be inserted, by sending a POST request to the REST server.
Along with the properties to be modified/inserted, the request body must
include an 'code' property, the value of which specifies the activity to be
updated.  
EOH
    },
    'activity/code/:code' => 
    {
        target => {
            GET => '_code',
            PUT => '_code',
            DELETE => '_code',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Activity',
        acl_profile => {
            GET => 'active',
            PUT => 'admin',
            DELETE => 'admin',
        },
        cli => 'activity code $CODE',
        validations => {
            'code' => qr/^[[:alnum:]_][[:alnum:]_-]+$/,
        },
        description => 'GET, PUT, or DELETE an activity object by its code',
        documentation => <<'EOH',
=over

=item * GET

Retrieves an activity object by its code.

=item * PUT

Inserts new or updates existing activity object whose code is specified by the
':code' URI parameter.  The fields to be updated and their new values should be
sent in the request body, e.g., like this:

    { "long_desc" : "new description", "disabled" : "f" }

=item * DELETE

Deletes an activity object by its code whose code is specified by the ':code'
URI parameter.  This will work only if nothing in the database refers to this
activity.

=back
EOH
    },
    'activity/help' =>
    { 
        target => {
            GET => '_get_default',
            POST => '_post_default',
            PUT => '_put_default', 
            DELETE => '_delete_default', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Activity',
        acl_profile => 'passerby', 
        cli => 'activity help',
        description => 'Display available activity resources for given HTTP method',
        documentation => <<'EOH',
=pod

Displays information on all activity resources available to the logged-in
employee, according to her privlevel.
EOH
    },

});
