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
# config/dispatch/lock_Config.pm
#
# Path dispatch configuration file for lock resources
# -----------------------------------


# DISPATCH_RESOURCES_LOCK
#    - value is a hash, the keys of which are resource paths
#    - the values of those keys are hashes containing resource metadata
set( 'DISPATCH_RESOURCES_LOCK', {

    'lock/eid/:eid/:tsrange' => 
    {
        target => {
            GET => 'fetch_by_eid',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Shared',
        acl_profile => 'admin', 
        cli => 'lock eid $EID $TSRANGE',
        description => 'Retrieve an arbitrary employee\'s locks over the given tsrange',
        documentation => <<'EOH',
=pod

With this resource, administrators can retrieve any employee's locks 
over a given tsrange. 

There are no syntactical limitations on the tsrange, but if too many records would
be fetched, the return status will be C<DISPATCH_TOO_MANY_RECORDS_FOUND>.
EOH
    },
    'lock/help' =>
    { 
        target => {
            GET => '_get_default',
            POST => '_post_default',
            PUT => '_put_default', 
            DELETE => '_delete_default', 
        },
        target_module => 'App::Dochazka::REST::Dispatch::Lock',
        acl_profile => 'passerby', 
        cli => 'lock help',
        description => 'Display available lock resources for given HTTP method',
        documentation => <<'EOH',
=pod

Displays information on all lock resources available to the logged-in
employee, according to her privlevel.
EOH
    },
    'lock/lid' => 
    {
        target => {
            POST => 'iid_lid',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Shared',
        acl_profile => 'admin', 
        cli => 'lock lid $JSON',
        description => 'Update an existing lock object via POST request (lid must be included in request body)',
        documentation => <<'EOH',
=pod

Enables existing lock objects to be updated by sending a POST request to
the REST server. Along with the properties to be modified, the request body
must include an 'lid' property, the value of which specifies the lid to be
updated.
EOH
    },
    'lock/lid/:lid' => 
    {
        target => {
            GET => 'iid_lid',
            PUT => 'iid_lid',
            DELETE => 'iid_lid',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Shared',
        acl_profile => {
            GET => 'active',
            PUT => 'admin',
            DELETE => 'admin',
        },
        cli => 'lock lid $lid [$JSON]',
        description => 'GET, PUT, or DELETE an lock object by its lid',
        documentation => <<'EOH',
=over

=item * GET

Retrieves an lock object by its lid.

=item * PUT

Updates the lock object whose lid is specified by the ':lid' URI parameter.
The fields to be updated and their new values should be sent in the request
body, e.g., like this:

    { "eid" : 34, "intvl" : '[ 2014-11-18 00:00, 2014-11-18 24:00 )' }

=item * DELETE

Deletes the lock object whose lid is specified by the ':lid' URI parameter.

=back

ACL note: 'active' employees can view only their own locks, and of course
admin privilege is required to modify or remove a lock.
EOH
    },
    'lock/new' => 
    {
        target => {
            POST => '_new',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Lock',
        acl_profile => 'active', 
        cli => 'lock new $JSON',
        description => 'Add a new attendance data lock',
        documentation => <<'EOH',
=pod

This is the resource by which the attendance data entered by an employee 
for a given time period can be "locked" to prevent any subsequent
modifications.  It takes a request body containing, at the very least, an
C<intvl> property specifying the tsrange to lock. Additionally, administrators
can specify C<remark> and C<eid> properties.
EOH
    },
    'lock/nick/:nick/:tsrange' => 
    {
        target => {
            GET => 'fetch_by_nick',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Shared',
        acl_profile => 'admin', 
        cli => 'lock nick $NICK $TSRANGE',
        description => 'Retrieve an arbitrary employee\'s locks over the given tsrange',
        documentation => <<'EOH',
=pod

With this resource, administrators can retrieve any employee's locks 
over a given tsrange. 

There are no syntactical limitations on the tsrange, but if too many records would
be fetched, the return status will be C<DISPATCH_TOO_MANY_RECORDS_FOUND>.
EOH
    },
    'lock/self/:tsrange' => 
    {
        target => {
            GET => 'fetch_own',
        },
        target_module => 'App::Dochazka::REST::Dispatch::Shared',
        acl_profile => 'inactive', 
        cli => 'lock self $TSRANGE',
        description => 'Retrieve one\'s own locks over the given tsrange',
        documentation => <<'EOH',
=pod

With this resource, employees can retrieve their own attendance locks 
over a given tsrange. 

There are no syntactical limitations on the tsrange, but if too many records would
be fetched, the return status will be C<DISPATCH_TOO_MANY_RECORDS_FOUND>.
EOH
    },

});
